"use strict";

const { detectFraud } = require("../services/fraudDetection");

console.log("=== Testing Fraud Detection Logic ===");

// Scenario 1: Normal Travel
// Mumbai to Pune (~150km) in 3 hours
const hop1 = {
    location: "19.0760, 72.8777", // Mumbai
    timestamp: 1700000000 // T=0
};
const hop2Location = "18.5204, 73.8567"; // Pune
const hop2Time = 1700000000 + (3 * 3600); // T+3 hours

console.log("\nTest 1: Normal Travel (Mumbai -> Pune, 3h)");
const flags1 = detectFraud(hop1, hop2Location, hop2Time);
console.log("Flags:", flags1);
if (flags1.length === 0) console.log("PASS: No fraud detected.");
else console.log("FAIL: False positive.");


// Scenario 2: Impossible Travel
// Mumbai to London (~7200km) in 1 hour
const hop3Location = "51.5074, -0.1278"; // London
const hop3Time = 1700000000 + (1 * 3600); // T+1 hour

console.log("\nTest 2: Impossible Travel (Mumbai -> London, 1h)");
const flags2 = detectFraud(hop1, hop3Location, hop3Time);
console.log("Flags:", flags2);
if (flags2.includes("IMPOSSIBLE_TRAVEL")) console.log("PASS: Fraud detected.");
else console.log("FAIL: Fraud NOT detected.");

// Scenario 3: Simultaneous Scan
// Mumbai -> Pune in 1 minute
const hop4Time = 1700000000 + 60; // T+1 min

console.log("\nTest 3: Simultaneous Scan (Mumbai -> Pune, 1 min)");
const flags3 = detectFraud(hop1, hop2Location, hop4Time);
console.log("Flags:", flags3);
if (flags3.includes("SIMULTANEOUS_SCAN")) console.log("PASS: Fraud detected.");
else console.log("FAIL: Fraud NOT detected.");
