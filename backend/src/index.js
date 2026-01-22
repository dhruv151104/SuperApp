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
const multer = require("multer");
const path = require("path");
const { analyzeImageCondition } = require("./services/visionDetection");

// Multer Config
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    cb(null, "uploads/");
  },
  filename: (req, file, cb) => {
    // Unique filename: timestamp-random.jpg
    const uniqueSuffix = Date.now() + "-" + Math.round(Math.random() * 1e9);
    cb(null, uniqueSuffix + path.extname(file.originalname));
  },
});
const upload = multer({ storage: storage });

function generateProductId() {
  // Example: PROD-2026-8f3a2c
  const random = crypto.randomBytes(3).toString("hex");
  return `PROD-${new Date().getFullYear()}-${random}`;
}

const app = express();
app.use(cors());
app.use(express.json());
app.use(morgan("dev"));
app.use("/uploads", express.static("uploads")); // Serve images

const PORT = process.env.PORT || 4000;
const MONGODB_URI =
  process.env.MONGODB_URI || "mongodb://localhost:27017/product_traceability";

const analyticsRouter = require("./analytics");
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
const { ProductHistory, User } = require("./models");

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
    const { email, password, role, walletAddress, companyName, registeredLocation, licenseId, businessType, contactPerson, contactPhone } = req.body;

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
      businessType,
      contactPerson,
      contactPhone
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
      contactPerson: user.contactPerson,
      contactPhone: user.contactPhone,
      walletAddress: user.walletAddress,
      licenseId: user.licenseId
    });
  } catch (err) {
    res.status(500).json({ error: "Login failed" });
  }
});

app.get("/user/history", authMiddleware(), async (req, res) => {
  try {
    const { walletAddress, role } = req.user;
    let query = {};

    if (role === "Manufacturer") {
      // Products minted by this manufacturer
      query = { manufacturer: walletAddress };
    } else if (role === "Retailer") {
      // Products where this retailer appears in hops
      query = { "hops.actor": walletAddress };
    } else {
      // Consumer or other - maybe just show nothing or their specific actions if we tracked them
      // For now, return empty
      return res.json([]);
    }

    const history = await ProductHistory.find(query)
      .sort({ createdAt: -1 })
      .select("productId productName status createdAt hops"); // Select fields needed for list

    // Format for frontend
    const formatted = history.map(p => ({
       productId: p.productId,
       productName: p.productName || "Unnamed Product",
       status: p.status,
       date: p.createdAt,
       // If retailer, maybe show when they scanned it?
       // For simplicity, just return the product metadata
    }));

    res.json(formatted);
  } catch (err) {
    console.error("[History] Error:", err);
    res.status(500).json({ error: "Failed to fetch history" });
  }
});


// Healthcheck
app.get("/health", (req, res) => {
  res.json({ ok: true });
});

app.use("/analytics", authMiddleware("Manufacturer"), analyticsRouter);

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

// DEBUG: Force wipe history
app.delete("/admin/nuke", async (req, res) => {
  try {
     await ProductHistory.deleteMany({});
     console.log("[Nuke] DB wiped via API");
     res.json({ success: true, message: "DB wiped" });
  } catch(e) {
     res.status(500).json({ error: e.message });
  }
});

    app.post("/product", authMiddleware("Manufacturer"), upload.single("image"), async (req, res) => {
  console.log("[createProduct] Request received. user:", req.user.walletAddress, "flags:", req.body.flags);
  try {
    const { location, flags, productName } = req.body;
    const file = req.file;

    if (!location) {
      return res.status(400).json({ error: "location is required" });
    }

    if (!contract) {
      return res.status(500).json({ error: "Contract not configured" });
    }

    // Vision Analysis
    let visionResult = null;
    let imageUrl = null;
    
    // Parse flags safely
    let parsedFlags = [];
    if (Array.isArray(flags)) {
      parsedFlags = flags;
    } else if (typeof flags === 'string') {
       try {
         parsedFlags = JSON.parse(flags);
         if (!Array.isArray(parsedFlags)) parsedFlags = [parsedFlags]; // handle single string "flag"
       } catch (e) {
         parsedFlags = [flags];
       }
    }
    
    let manufacturerFlags = [...parsedFlags];

    if (file) {
       console.log("[createProduct] Image uploaded:", file.path);
       imageUrl = file.path;
       const analysis = await analyzeImageCondition(file.path, productName);
       console.log("[createProduct] Vision Analysis:", analysis);
       
       visionResult = analysis;
       if (analysis.isDamaged) {
          manufacturerFlags.push("DAMAGED_AT_SOURCE");
       } else {
          // ensure initial state is clean?
       }
    }

    // Generate product ID
    const productId = generateProductId();
    console.log("[createProduct] Generated ID:", productId);

    // Call blockchain (manufacturer action)
    console.log("[createProduct] Sending tx to blockchain...");
    const tx = await contract.createProduct(productId, location);
    console.log("[createProduct] Tx sent:", tx.hash);
    
    // Wait for confirmation OR timeout after 30s (Increased from 15s)
    try {
      await Promise.race([
        tx.wait(),
        new Promise((_, reject) => setTimeout(() => reject(new Error("Mining timed out")), 30000))
      ]);
      console.log("[createProduct] Tx confirmed");
      
      // Attribution: ONLY Save to local DB if mining confirmed
      await ProductHistory.create({
        productId,
        productName: productName || "Unnamed Product",
        manufacturer: req.user.walletAddress, 
        status: "Active",
        imageUrl: imageUrl, 
        visionResult: visionResult,
        hops: [{
          role: "Manufacturer",
          actor: req.user.walletAddress,
          location: location,
          timestamp: Math.floor(Date.now() / 1000),
          flags: manufacturerFlags,
          imageUrl: imageUrl, // Manufacturer hop also has image
          visionResult: visionResult
        }]
      });
      console.log("[createProduct] DB entry created");

    } catch (e) {
      console.error("[createProduct] Mining failed or timed out:", e.message);
      return res.status(500).json({ error: "Blockchain transaction failed. Please try again." });
    }

    // Generate QR code (base64)
    const qrDataUrl = await QRCode.toDataURL(productId);

    res.json({
      success: true,
      productId,
      qrCode: qrDataUrl, // frontend can render <img src=...>
      txHash: tx.hash,
      visionResult
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
      let hopImage = null;
      let hopVision = null;

      if (history && history.hops && history.hops[index]) {
         realActor = history.hops[index].actor; 
         hopFlags = history.hops[index].flags || [];
         hopImage = history.hops[index].imageUrl;
         hopVision = history.hops[index].visionResult;
      }
      
      const actorName = await getName(realActor);
      
      return {
        role: Number(h[0]) === 0 ? "Manufacturer" : "Retailer",
        actor: realActor,
        actorName: actorName,
        location: h[2],
        timestamp: Number(h[3].toString()),
        flags: hopFlags,
        imageUrl: hopImage,
        visionResult: hopVision
      };
    }));
    
    // Prefer DB manufacturer
    let realManufacturer = manufacturer;
    let manufacturerImage = null;
    let manufacturerVision = null;
    if (history) {
       realManufacturer = history.manufacturer || manufacturer;
       manufacturerImage = history.imageUrl;
       manufacturerVision = history.visionResult;
    }
    const manufacturerName = await getName(realManufacturer);
    
    res.json({
      productId: idOnChain,
      productName: history ? history.productName : "Unknown Product",
      manufacturer: realManufacturer,
      manufacturerName,
      imageUrl: manufacturerImage,
      visionResult: manufacturerVision,
      hops: formattedHops,
    });
  } catch (err) {
    console.error(err);
    
    // Self-Healing
    if (err.code === 'BAD_DATA' || err.message.includes('reverted') || err.message.includes('call revert exception')) {
       console.warn(`[Self-Healing] Detected ghost record for ${productId}. Deleting from DB.`);
       await ProductHistory.deleteOne({ productId });
       return res.status(404).json({ error: "Product not found on blockchain (Ghost record removed)" });
    }

    res
      .status(500)
      .json({ error: "Failed to fetch product", details: err.message });
  }
});

const { detectFraud } = require("./services/fraudDetection");

app.post("/product/:id/retailer-hop", authMiddleware("Retailer"), upload.single("image"), async (req, res) => {
  try {
    const productId = req.params.id;
    // multipart/form-data sends fields as strings. flags might need parsing if sent as JSON string, but usually simple fields work.
    // If client sends flags as array in multipart, multer handles it? simplified: client will send 'location' string.
    let { location, flags: clientFlags } = req.body; 
    const file = req.file;

    if (!location) {
      return res.status(400).json({ error: "location is required" });
    }

    if (!contract) {
      return res.status(500).json({ error: "Contract not configured" });
    }
    
    // Parse flags if string (common in multipart)
    if (typeof clientFlags === 'string') {
        try { clientFlags = JSON.parse(clientFlags); } catch(e) { clientFlags = [clientFlags]; }
    }

    // 0. Fetch history first (Needed for Vision Context & Fraud Detection)
    let history = await ProductHistory.findOne({ productId });
    const productName = history ? history.productName : "Unknown";

    // 1. Vision Analysis
    let visionResult = null;
    let imageUrl = null;
    let visionFlags = [];

    if (file) {
       console.log("[retailerHop] Image uploaded:", file.path);
       imageUrl = file.path;
       const analysis = await analyzeImageCondition(file.path, productName);
       console.log("[retailerHop] Vision Analysis:", analysis);
       
       visionResult = analysis;
       if (analysis.isDamaged) {
          visionFlags.push("DAMAGED: " + analysis.reason);
       }
    }


    // 2. Fraud Detection (Impossible Travel)
    let fraudFlags = [];
    
    // If not in DB, we might fetching from chain, but for fraud detection rely on DB for speed
    if (history && history.hops && history.hops.length > 0) {
       const previousHop = history.hops[history.hops.length - 1]; // Last hop
       // New timestamp is "now"
       const currentTimestamp = Math.floor(Date.now() / 1000);
       
       fraudFlags = detectFraud(previousHop, location, currentTimestamp);
    }
    
    // Merge backend flags with any client flags (if any)
    const finalFlags = [...(clientFlags || []), ...fraudFlags, ...visionFlags];

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
            flags: finalFlags,
            imageUrl: imageUrl, 
            visionResult: visionResult
          } 
        } 
      }
    );

    res.json({
      success: true,
      productId,
      location,
      flags: finalFlags,
      visionResult,
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

// Standalone Analysis Endpoint (No Blockchain/DB storage)
// Useful for Consumers to "Check" a product before buying, or for testing.
app.post("/analyze", upload.single("image"), async (req, res) => {
  try {
    const file = req.file;
    const productName = req.body.productName || ""; 
    const productId = req.body.productId;

    if (!file) {
      return res.status(400).json({ error: "Image file required" });
    }

    let referenceImage = null;
    if (productId) {
       const history = await ProductHistory.findOne({ productId });
       if (history && history.imageUrl) {
          console.log("[Analyze] Found Reference Image for Comparison:", history.imageUrl);
          referenceImage = history.imageUrl;
       }
    }

    console.log(`[Analyze] Analysis Request. Product: ${productName}, ID: ${productId}, HasRef: ${!!referenceImage}`);
    const analysis = await analyzeImageCondition(file.path, productName, referenceImage);
    
    res.json({
      success: true,
      result: analysis
    });
  } catch(err) {
    console.error("[Analyze] Error:", err.message);
    res.status(500).json({ error: "Analysis failed" });
  }
});

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
