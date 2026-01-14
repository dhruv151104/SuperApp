const hre = require("hardhat");

async function main() {
  const CONTRACT_ADDRESS = "0x3DCF2211a2CFE6e2D748f0EA8E3caa047c5ac0d8";

  const ProductTraceability = await hre.ethers.getContractAt(
    "ProductTraceability",
    CONTRACT_ADDRESS
  );

  const productId = "PROD-001";
  const retailerLocation = "Retail Store - Pune";

  console.log("Adding retailer hop...");

  const tx = await ProductTraceability.addRetailerHop(
    productId,
    retailerLocation
  );
  await tx.wait();

  console.log("Retailer hop added");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
