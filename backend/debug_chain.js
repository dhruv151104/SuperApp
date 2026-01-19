const { ethers } = require("ethers");

async function check() {
  const provider = new ethers.JsonRpcProvider("http://127.0.0.1:8545");
  const address = "0x5FbDB2315678afecb367f032d93F642f64180aa3";
  
  console.log(`Checking address: ${address}`);
  const code = await provider.getCode(address);
  console.log(`Code length: ${code.length}`);
  
  if (code === '0x') {
      console.error("CRITICAL: No code at this address! It is an EOA.");
  } else {
      console.log("Contract code found.");
  }

  // Check the last few blocks/txs
  const blockNumber = await provider.getBlockNumber();
  console.log(`Current Block: ${blockNumber}`);
}

check();
