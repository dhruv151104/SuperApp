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
    flags: [String] // New field
  },
  { _id: false }
);

// ... existing productHistorySchema ...

// ...



// ...

// Format Hops in getProduct


// ...



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
    companyName: String,
    registeredLocation: String,
    licenseId: String,
    businessType: String,
  },
  { collection: "users" }
);

const User = mongoose.model("User", userSchema);

function authMiddleware(requiredRole = null) {
  return async (req, res, next) => {
    console.log("[Auth] Checking token for role:", requiredRole);
    const authHeader = req.headers.authorization;
    if (!authHeader) {
      console.log("[Auth] Missing header");
      return res.status(401).json({ error: "Missing Authorization header" });
    }

    const token = authHeader.split(" ")[1];
    if (!token) {
        console.log("[Auth] Invalid token format");
        return res.status(401).json({ error: "Invalid token format" });
    }

    try {
      const decoded = jwt.verify(token, process.env.JWT_SECRET);
      req.user = decoded;
      console.log("[Auth] Token verified. decoded:", decoded);

      if (requiredRole && decoded.role !== requiredRole) {
        console.log("[Auth] Role mismatch. Required:", requiredRole, "Got:", decoded.role);
        return res.status(403).json({ error: "Forbidden: role mismatch" });
      }

      console.log("[Auth] Success. Calling next()");
      next();
    } catch (err) {
      console.log("[Auth] Verification failed:", err.message);
      return res.status(401).json({ error: "Invalid or expired token" });
    }
  };
}

app.post("/auth/register", async (req, res) => {
  try {
    const { email, password, role, walletAddress, companyName, registeredLocation, licenseId, businessType } = req.body;

    if (!email || !password || !role || !walletAddress) {
      return res.status(400).json({ error: "All fields required" });
    }

    const passwordHash = await bcrypt.hash(password, 10);

    // FIX: If mobile app sends placeholder, generate a unique address to ensure attribution works
    let finalWalletAddress = walletAddress;
    if (!walletAddress || walletAddress === '0x0000000000000000000000000000000000000000') {
      finalWalletAddress = ethers.Wallet.createRandom().address;
    }

    const user = await User.create({
      email,
      passwordHash,
      role,
      walletAddress: finalWalletAddress,
      companyName,
      registeredLocation,
      licenseId,
      businessType
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
      companyName: user.companyName,
      registeredLocation: user.registeredLocation,
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
  console.log("[createProduct] Request received. user:", req.user.walletAddress, "flags:", req.body.flags);
  try {
    const { location, flags } = req.body;

    if (!location) {
      return res.status(400).json({ error: "location is required" });
    }

    if (!contract) {
      return res.status(500).json({ error: "Contract not configured" });
    }

    // Generate product ID
    const productId = generateProductId();
    console.log("[createProduct] Generated ID:", productId);

    // Call blockchain (manufacturer action)
    console.log("[createProduct] Sending tx to blockchain...");
    const tx = await contract.createProduct(productId, location);
    console.log("[createProduct] Tx sent:", tx.hash);
    
    // Wait for confirmation OR timeout after 15s
    try {
      await Promise.race([
        tx.wait(),
        new Promise((_, reject) => setTimeout(() => reject(new Error("Mining timed out")), 15000))
      ]);
      console.log("[createProduct] Tx confirmed");
    } catch (e) {
      console.warn("[createProduct] Mining took too long or failed:", e.message);
      // We proceed anyway since the tx was broadcast. 
      // The frontend will get the txHash and can check status later if needed.
    }

    // Attribution: Save to local DB so we know WHO did it (since chain says "Server")
    await ProductHistory.create({
      productId,
      manufacturer: req.user.walletAddress, // Store User's wallet
      status: "Active",
      hops: [{
        role: "Manufacturer",
        actor: req.user.walletAddress,
        location: location,
        timestamp: Math.floor(Date.now() / 1000),
        flags: flags || []
      }]
    });
    console.log("[createProduct] DB entry created");

    // Generate QR code (base64)
    const qrDataUrl = await QRCode.toDataURL(productId);

    res.json({
      success: true,
      productId,
      qrCode: qrDataUrl, // frontend can render <img src=...>
      txHash: tx.hash,
    });
    console.log("[createProduct] Response sent");
  } catch (err) {
    console.error("[createProduct] Error:", err);
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

    // Attribution: Fetch from local DB
    const history = await ProductHistory.findOne({ productId });

    // Helper to get name
    const getName = async (addr) => {
       const u = await User.findOne({ walletAddress: addr });
       return u ? u.companyName : "Unknown";
    };

    // Map numeric role to string and build response
    const formattedHops = await Promise.all(hops.map(async (h, index) => {
      const actorAddress = h[1];
      
      // Prefer DB attribution if available for this index
      let realActor = actorAddress; // fallback
      let hopFlags = [];
      if (history && history.hops && history.hops[index]) {
         realActor = history.hops[index].actor; 
         hopFlags = history.hops[index].flags || [];
      }
      
      const actorName = await getName(realActor);
      
      return {
        role: Number(h[0]) === 0 ? "Manufacturer" : "Retailer",
        actor: realActor,
        actorName: actorName,
        location: h[2],
        timestamp: Number(h[3].toString()),
        flags: hopFlags
      };
    }));
    
    // Prefer DB manufacturer
    let realManufacturer = manufacturer;
    if (history && history.manufacturer) {
       realManufacturer = history.manufacturer;
    }
    const manufacturerName = await getName(realManufacturer);
    
    res.json({
      productId: idOnChain,
      manufacturer: realManufacturer,
      manufacturerName,
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
    const { location, flags } = req.body;

    if (!location) {
      return res.status(400).json({ error: "location is required" });
    }

    if (!contract) {
      return res.status(500).json({ error: "Contract not configured" });
    }

    const tx = await contract.addRetailerHop(productId, location);
    console.log("[retailerHop] Tx sent:", tx.hash);

    // Wait for confirmation OR timeout after 15s
    try {
      await Promise.race([
        tx.wait(),
        new Promise((_, reject) => setTimeout(() => reject(new Error("Mining timed out")), 15000))
      ]);
      console.log("[retailerHop] Tx confirmed");
    } catch (e) {
       console.warn("[retailerHop] Mining timeout:", e.message);
    }

    // Attribution: Push to local DB
    await ProductHistory.updateOne(
      { productId },
      { 
        $push: { 
          hops: {
            role: "Retailer",
            actor: req.user.walletAddress,
            location: location,
            timestamp: Math.floor(Date.now() / 1000),
            flags: flags || []
          } 
        } 
      }
    );

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
