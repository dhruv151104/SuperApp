
const { ethers } = require("ethers");
const path = require('path');
require("dotenv").config({ path: path.resolve(__dirname, '../.env') });

async function checkBalance() {
  try {
    const provider = new ethers.JsonRpcProvider(process.env.SEPOLIA_RPC_URL);
    let privateKey = process.env.PRIVATE_KEY;
    if (!privateKey.startsWith("0x")) {
      privateKey = "0x" + privateKey;
    }
    const wallet = new ethers.Wallet(privateKey, provider);
    const balance = await provider.getBalance(wallet.address);
    // Fixed: ethers.formatEther is the method in v6, utils.formatEther was v5. 
    // Checking package.json... "ethers": "^6.13.0".
    const balanceInEth = ethers.formatEther(balance);
    
    console.log(`Address: ${wallet.address}`);
    console.log(`Balance: ${balanceInEth} Sepolia ETH`);
  } catch (error) {
    console.error("Error checking balance:", error);
  }
}

checkBalance();
