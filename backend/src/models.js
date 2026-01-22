const mongoose = require("mongoose");

const hopSchema = new mongoose.Schema(
  {
    productId: { type: String, index: true },
    role: { type: String, enum: ["Manufacturer", "Retailer"] },
    actor: String,
    location: String,
    timestamp: Number,
    flags: [String],
    imageUrl: String,
    visionResult: {
       isDamaged: Boolean,
       reason: String
    }
  },
  { _id: false }
);

// Product History Schema
const productHistorySchema = new mongoose.Schema(
  {
    productId: { type: String, unique: true, index: true },
    productName: String, // New field for human-readable name
    manufacturer: String,
    status: { type: String, enum: ["Active", "Completed"] }, // Active = In Transit, Completed = Sold/End
    hops: [hopSchema],
    imageUrl: String, // Manufacturer image
    visionResult: {
       isDamaged: Boolean,
       reason: String
    },
    createdAt: { type: Date, default: Date.now },
  },
  { collection: "product_history" }
);

const ProductHistory = mongoose.model("ProductHistory", productHistorySchema);

// User Schema
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
    contactPerson: String,
    contactPhone: String,
  },
  { collection: "users" }
);

const User = mongoose.model("User", userSchema);

module.exports = {
  ProductHistory,
  User,
  // Note: Previous code referenced "Product" model in analytics.js but defined "ProductHistory".
  // I will aliased ProductHistory as Product for compatibility or consistency.
  Product: ProductHistory 
};
