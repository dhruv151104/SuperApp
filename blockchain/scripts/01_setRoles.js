const hre = require("hardhat");

async function main() {
  const CONTRACT_ADDRESS = "0x3DCF2211a2CFE6e2D748f0EA8E3caa047c5ac0d8";

  const [deployer] = await hre.ethers.getSigners();
  console.log("Using account:", deployer.address);

  const ProductTraceability = await hre.ethers.getContractAt(
    "ProductTraceability",
    CONTRACT_ADDRESS
  );

  // For demo: use deployer as both manufacturer & retailer
  const manufacturer = deployer.address;
  const retailer = deployer.address;

  console.log("Setting manufacturer...");
  const tx1 = await ProductTraceability.setManufacturer(manufacturer, true);
  await tx1.wait();
  console.log("Manufacturer registered");

  console.log("Setting retailer...");
  const tx2 = await ProductTraceability.setRetailer(retailer, true);
  await tx2.wait();
  console.log("Retailer registered");

  console.log("Roles setup complete");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
