const mongoose = require("mongoose");
const dotenv = require("dotenv");
dotenv.config();

const { ProductHistory } = require("./src/models");

const MONGODB_URI = process.env.MONGODB_URI || "mongodb://localhost:27017/product_traceability";

async function reset() {
  try {
    await mongoose.connect(MONGODB_URI);
    console.log("[reset] Connected to MongoDB");

    const result = await ProductHistory.deleteMany({});
    console.log(`[reset] Deleted ${result.deletedCount} product history records.`);

  } catch (err) {
    console.error(err);
  } finally {
    await mongoose.disconnect();
    process.exit(0);
  }
}

reset();
