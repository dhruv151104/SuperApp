const hre = require("hardhat");

async function main() {
  const CONTRACT_ADDRESS = "0x3DCF2211a2CFE6e2D748f0EA8E3caa047c5ac0d8";

  const ProductTraceability = await hre.ethers.getContractAt(
    "ProductTraceability",
    CONTRACT_ADDRESS
  );

  const productId = "PROD-001";

  const [id, manufacturer, history] =
    await ProductTraceability.getProduct(productId);

  console.log("Product ID:", id);
  console.log("Manufacturer:", manufacturer);
  console.log("History:");

  history.forEach((hop, index) => {
    console.log(`  Step ${index + 1}`);
    console.log("   Role:", hop.role === 0 ? "Manufacturer" : "Retailer");
    console.log("   Actor:", hop.actor);
    console.log("   Location:", hop.location);
    console.log("   Time:", new Date(Number(hop.timestamp) * 1000).toString());
  });
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
