"use strict";

const express = require("express");
const morgan = require("morgan");
const cors = require("cors");
const dotenv = require("dotenv");
const mongoose = require("mongoose");
const { ethers } = require("ethers");
const bcrypt = require("bcryptjs");
const jwt = require("jsonwebtoken");

dotenv.config();

const QRCode = require("qrcode");
const crypto = require("crypto");

function generateProductId() {
  // Example: PROD-2026-8f3a2c
  const random = crypto.randomBytes(3).toString("hex");
  return `PROD-${new Date().getFullYear()}-${random}`;
}

const app = express();
app.use(cors());
app.use(express.json());
app.use(morgan("dev"));

const PORT = process.env.PORT || 4000;
const MONGODB_URI =
  process.env.MONGODB_URI || "mongodb://localhost:27017/product_traceability";
const SEPOLIA_RPC_URL = process.env.SEPOLIA_RPC_URL || "";
const PRODUCT_TRACEABILITY_CONTRACT =
  process.env.PRODUCT_TRACEABILITY_CONTRACT || "";
const PRIVATE_KEY = process.env.PRIVATE_KEY || "";

// Minimal ABI for interacting with ProductTraceability
const ProductTraceabilityABI =
  require("../../blockchain/artifacts/contracts/ProductTraceability.sol/ProductTraceability.json").abi;


// Ethers setup (read/write as contract owner)
let provider;
let ownerWallet;
let contract;

function initBlockchain() {
  if (!SEPOLIA_RPC_URL || !PRODUCT_TRACEABILITY_CONTRACT || !PRIVATE_KEY) {
    console.warn(
      "[blockchain] SEPOLIA_RPC_URL / PRODUCT_TRACEABILITY_CONTRACT / PRIVATE_KEY not fully configured. Blockchain methods will fail."
    );
    return;
  }

  provider = new ethers.JsonRpcProvider(SEPOLIA_RPC_URL);
  ownerWallet = new ethers.Wallet(PRIVATE_KEY, provider);
  contract = new ethers.Contract(
    PRODUCT_TRACEABILITY_CONTRACT,
    ProductTraceabilityABI,
    ownerWallet
  );
}

// MongoDB models
const hopSchema = new mongoose.Schema(
  {
    productId: { type: String, index: true },
    role: { type: String, enum: ["Manufacturer", "Retailer"] },
    actor: String,
    location: String,
    timestamp: Number,
  },
  { _id: false }
);

const productHistorySchema = new mongoose.Schema(
  {
    productId: { type: String, unique: true, index: true },
    manufacturer: String,
    status: { type: String, enum: ["Active", "Completed"] },
    hops: [hopSchema],
    createdAt: { type: Date, default: Date.now },
  },
  { collection: "product_history" }
);

const ProductHistory = mongoose.model("ProductHistory", productHistorySchema);


const userSchema = new mongoose.Schema(
  {
    email: { type: String, unique: true, required: true },
    passwordHash: { type: String, required: true },
    role: {
      type: String,
      enum: ["Manufacturer", "Retailer"],
      required: true,
    },
    walletAddress: { type: String, required: true },
  },
  { collection: "users" }
);

const User = mongoose.model("User", userSchema);

function authMiddleware(requiredRole = null) {
  return async (req, res, next) => {
    const authHeader = req.headers.authorization;
    if (!authHeader)
      return res.status(401).json({ error: "Missing Authorization header" });

    const token = authHeader.split(" ")[1];
    if (!token) return res.status(401).json({ error: "Invalid token format" });

    try {
      const decoded = jwt.verify(token, process.env.JWT_SECRET);
      req.user = decoded;

      if (requiredRole && decoded.role !== requiredRole) {
        return res.status(403).json({ error: "Forbidden: role mismatch" });
      }

      next();
    } catch (err) {
      return res.status(401).json({ error: "Invalid or expired token" });
    }
  };
}

app.post("/auth/register", async (req, res) => {
  try {
    const { email, password, role, walletAddress } = req.body;

    if (!email || !password || !role || !walletAddress) {
      return res.status(400).json({ error: "All fields required" });
    }

    const passwordHash = await bcrypt.hash(password, 10);

    const user = await User.create({
      email,
      passwordHash,
      role,
      walletAddress,
    });

    res.json({ success: true, userId: user._id });
  } catch (err) {
    res.status(500).json({ error: "User registration failed" });
  }
});

app.post("/auth/login", async (req, res) => {
  try {
    const { email, password } = req.body;

    const user = await User.findOne({ email });
    if (!user) return res.status(401).json({ error: "Invalid credentials" });

    const ok = await bcrypt.compare(password, user.passwordHash);
    if (!ok) return res.status(401).json({ error: "Invalid credentials" });

    const token = jwt.sign(
      {
        userId: user._id,
        role: user.role,
        walletAddress: user.walletAddress,
      },
      process.env.JWT_SECRET,
      { expiresIn: "2h" }
    );

    res.json({
      success: true,
      token,
      role: user.role,
    });
  } catch (err) {
    res.status(500).json({ error: "Login failed" });
  }
});


// Healthcheck
app.get("/health", (req, res) => {
  res.json({ ok: true });
});

// Admin endpoints: allowlist management
app.post("/admin/manufacturers", async (req, res) => {
  try {
    const { address, allowed } = req.body;
    if (!contract)
      return res.status(500).json({ error: "Contract not configured" });
    if (!address || typeof allowed !== "boolean") {
      return res.status(400).json({ error: "address and allowed required" });
    }
    const tx = await contract.setManufacturer(address, allowed);
    await tx.wait();
    res.json({ txHash: tx.hash });
  } catch (err) {
    console.error(err);
    res
      .status(500)
      .json({ error: "Failed to set manufacturer", details: err.message });
  }
});

app.post("/admin/retailers", async (req, res) => {
  try {
    const { address, allowed } = req.body;
    if (!contract)
      return res.status(500).json({ error: "Contract not configured" });
    if (!address || typeof allowed !== "boolean") {
      return res.status(400).json({ error: "address and allowed required" });
    }
    const tx = await contract.setRetailer(address, allowed);
    await tx.wait();
    res.json({ txHash: tx.hash });
  } catch (err) {
    console.error(err);
    res
      .status(500)
      .json({ error: "Failed to set retailer", details: err.message });
  }
});

app.post("/product",authMiddleware("Manufacturer"), async (req, res) => {
  try {
    const { location } = req.body;

    if (!location) {
      return res.status(400).json({ error: "location is required" });
    }

    if (!contract) {
      return res.status(500).json({ error: "Contract not configured" });
    }

    // Generate product ID
    const productId = generateProductId();

    // Call blockchain (manufacturer action)
    const tx = await contract.createProduct(productId, location);
    await tx.wait();

    // Generate QR code (base64)
    const qrDataUrl = await QRCode.toDataURL(productId);

    res.json({
      success: true,
      productId,
      qrCode: qrDataUrl, // frontend can render <img src=...>
      txHash: tx.hash,
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({
      error: "Failed to create product",
      details: err.message,
    });
  }
});


// Product read endpoint
app.get("/product/:id", async (req, res) => {
  const productId = req.params.id;
  try {
    if (!contract)
      return res.status(500).json({ error: "Contract not configured" });

    const [idOnChain, manufacturer, hops] = await contract.getProduct(
      productId
    );

    // Map numeric role to string and build response
    const formattedHops = hops.map((h) => ({
      role: Number(h[0]) === 0 ? "Manufacturer" : "Retailer",
      actor: h[1],
      location: h[2],
      timestamp: Number(h[3].toString()),
    }));
    
    
    res.json({
      productId: idOnChain,
      manufacturer,
      hops: formattedHops,
    });
  } catch (err) {
    console.error(err);
    res
      .status(500)
      .json({ error: "Failed to fetch product", details: err.message });
  }
});

app.post("/product/:id/retailer-hop",authMiddleware("Retailer"), async (req, res) => {
  try {
    const productId = req.params.id;
    const { location } = req.body;

    if (!location) {
      return res.status(400).json({ error: "location is required" });
    }

    if (!contract) {
      return res.status(500).json({ error: "Contract not configured" });
    }

    const tx = await contract.addRetailerHop(productId, location);
    await tx.wait();

    res.json({
      success: true,
      productId,
      location,
      txHash: tx.hash,
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({
      error: "Failed to add retailer hop",
      details: err.message,
    });
  }
});


// Complete product endpoint
// app.post("/product/:id/complete", async (req, res) => {
//   const productId = req.params.id;
//   try {
//     if (!contract)
//       return res.status(500).json({ error: "Contract not configured" });
//     const tx = await contract.completeProduct(productId);
//     await tx.wait();
//     res.json({ txHash: tx.hash });
//   } catch (err) {
//     console.error(err);
//     res
//       .status(500)
//       .json({ error: "Failed to complete product", details: err.message });
//   }
// });

// Start server after DB + blockchain init

async function start() {
  try {
    await mongoose.connect(MONGODB_URI);
    console.log("[mongo] Connected");

    initBlockchain();

    app.listen(PORT, () => {
      console.log(`[server] Listening on port ${PORT}`);
    });
  } catch (err) {
    console.error("[startup] Failed to start server", err);
    process.exit(1);
  }
}

start();
