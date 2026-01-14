const hre = require("hardhat");

async function main() {
  const CONTRACT_ADDRESS = "0x3DCF2211a2CFE6e2D748f0EA8E3caa047c5ac0d8";

  const ProductTraceability = await hre.ethers.getContractAt(
    "ProductTraceability",
    CONTRACT_ADDRESS
  );

  const productId = "PROD-001";
  const location = "Factory Unit - Mumbai";

  console.log("Creating product:", productId);

  const tx = await ProductTraceability.createProduct(productId, location);
  await tx.wait();

  console.log("Product created successfully");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
