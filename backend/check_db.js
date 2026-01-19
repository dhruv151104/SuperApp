const mongoose = require("mongoose");
const dotenv = require("dotenv");
dotenv.config();

const { ProductHistory } = require("./src/models");

const MONGODB_URI = process.env.MONGODB_URI || "mongodb://localhost:27017/product_traceability";

async function check() {
  try {
    await mongoose.connect(MONGODB_URI);
    const count = await ProductHistory.countDocuments({});
    console.log(`[check] ProductHistory count: ${count}`);
    
    if (count > 0) {
        const items = await ProductHistory.find({}).select("productId productName");
        console.log("Items found:", items);
    }

  } catch (err) {
    console.error(err);
  } finally {
    await mongoose.disconnect();
    process.exit(0);
  }
}

check();
