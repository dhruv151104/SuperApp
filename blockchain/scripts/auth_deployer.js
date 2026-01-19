const hre = require("hardhat");

async function main() {
  const [deployer] = await hre.ethers.getSigners();
  console.log("Authorizing deployer:", deployer.address);

  // Load deployed contract (address from .env or config, but we can just use the one we know)
  const contractAddress = "0x3DCF2211a2CFE6e2D748f0EA8E3caa047c5ac0d8";
  const Contract = await hre.ethers.getContractFactory("ProductTraceability");
  const contract = Contract.attach(contractAddress);

  // Set Manufacturer
  console.log("Setting Manufacturer role...");
  const tx1 = await contract.setManufacturer(deployer.address, true);
  await tx1.wait();
  console.log("Manufacturer Role Granted");

  // Set Retailer
  console.log("Setting Retailer role...");
  const tx2 = await contract.setRetailer(deployer.address, true);
  await tx2.wait();
  console.log("Retailer Role Granted");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
