const express = require("express");
const router = express.Router();
const { Product } = require("./models"); 

router.get("/dashboard", async (req, res) => {
  try {
    
    const manufacturerWallet = req.user.walletAddress;
    
    // Total Products minted by THIS manufacturer
    const totalProducts = await Product.countDocuments({ manufacturer: manufacturerWallet });
    
    // In Transit: Products by this manufacturer with > 1 hop
    const productsInTransit = await Product.countDocuments({ 
      manufacturer: manufacturerWallet,
      "hops.1": { $exists: true } 
    });
    
    // Retailers Reached: Count distinct locations in hops where role is Retailer
    const retailerStats = await Product.aggregate([
       { $match: { manufacturer: manufacturerWallet } },
       { $unwind: "$hops" },
       { $match: { "hops.role": "Retailer" } },
       { $group: { _id: "$hops.location" } },
       { $count: "count" }
    ]);
    const retailersReached = retailerStats.length > 0 ? retailerStats[0].count : 0;

    // Recent Activity (Last 5 modified products by this manufacturer)
    const recentActivity = await Product.find({ manufacturer: manufacturerWallet })
      .sort({ updatedAt: -1 })
      .limit(5)
      .select("productId productName hops");

    res.json({
      totalProducts,
      productsInTransit,
      retailersReached,
      recentActivity
    });
  } catch (err) {
    console.error("[Analytics] Error:", err);
    res.status(500).json({ error: "Failed to fetch analytics" });
  }
});

router.get("/partners", async (req, res) => {
  try {
    const manufacturerWallet = req.user.walletAddress;

    const partners = await Product.aggregate([
       // 1. Find manufacturer's products
       { $match: { manufacturer: manufacturerWallet } },
       // 2. Unwind hops to analyze each step
       { $unwind: "$hops" },
       // 3. Filter for Retailer hops only
       { $match: { "hops.role": "Retailer" } },
       // 4. Group by Retailer Wallet (Actor)
       { $group: { 
           _id: "$hops.actor", 
           volume: { $sum: 1 },
           lastActive: { $max: "$hops.timestamp" }
         } 
       },
       // 5. Join with Users collection to get profile info
       {
         $lookup: {
           from: "users",
           localField: "_id",
           foreignField: "walletAddress",
           as: "userInfo"
         }
       },
       // 6. Flatten user info
       { $unwind: { path: "$userInfo", preserveNullAndEmptyArrays: true } },
       // 7. Project final fields
       {
         $project: {
           walletAddress: "$_id",
           companyName: { $ifNull: ["$userInfo.companyName", "Unregistered Entity"] },
           contactPerson: "$userInfo.contactPerson",
           contactPhone: "$userInfo.contactPhone",
           registeredLocation: "$userInfo.registeredLocation",
           volume: 1,
           lastActive: 1
         }
       },
       { $sort: { volume: -1 } }
    ]);

    res.json(partners);
  } catch (err) {
    console.error("[Analytics] Partners Error:", err);
    res.status(500).json({ error: "Failed to fetch partners" });
  }
});

module.exports = router;
