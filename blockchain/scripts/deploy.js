const hre = require("hardhat");

async function main() {
  const [deployer] = await hre.ethers.getSigners();

  console.log("Deploying ProductTraceability with account:", deployer.address);
  console.log(
    "Deployer balance:",
    (await deployer.provider.getBalance(deployer.address)).toString()
  );

  const Contract = await hre.ethers.getContractFactory("ProductTraceability");
  const contract = await Contract.deploy();
  await contract.waitForDeployment();

  const address = await contract.getAddress();
  console.log("ProductTraceability deployed to:", address);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});

