const express = require("express");
const router = express.Router();
const { getProduct } = require("../services/blockchain.service");

router.get("/:productId", async (req, res) => {
  try {
    const { productId } = req.params;

    const product = await getProduct(productId);

    res.json({
      success: true,
      data: product,
    });
  } catch (err) {
    res.status(404).json({
      success: false,
      message: "Product not found on blockchain",
    });
  }
});

module.exports = router;
