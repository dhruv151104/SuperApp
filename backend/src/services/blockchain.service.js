const { ethers } = require("ethers");
require("dotenv").config();

// Read-only provider (no private key)
const provider = new ethers.JsonRpcProvider(process.env.SEPOLIA_RPC_URL);

// Import ABI (copy from Hardhat artifacts)
const ProductTraceabilityABI =
  require("../../blockchain/artifacts/contracts/ProductTraceability.sol/ProductTraceability.json").abi;

const contractAddress = process.env.PRODUCT_TRACEABILITY_CONTRACT;

// Read-only contract instance
const contract = new ethers.Contract(
  contractAddress,
  ProductTraceabilityABI,
  provider
);

async function getProduct(productId) {
  const [id, manufacturer, history] = await contract.getProduct(productId);

  return {
    productId: id,
    manufacturer,
    history: history.map((hop) => ({
      role: hop.role === 0 ? "MANUFACTURER" : "RETAILER",
      actor: hop.actor,
      location: hop.location,
      timestamp: Number(hop.timestamp),
    })),
  };
}

module.exports = {
  getProduct,
};
