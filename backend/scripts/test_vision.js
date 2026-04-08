const { analyzeImageCondition } = require("../src/services/visionDetection");
const fs = require("fs");
const path = require("path");

async function run() {
  require("dotenv").config({ path: path.resolve(__dirname, "../.env") });
  
  // Create a 1x1 pixel base64 image
  const dummyBase64 = "data:image/jpeg;base64,/9j/4AAQSkZJRgABAQEASABIAAD/2wBDAP//////////////////////////////////////////////////////////////////////////////////////wgALCAABAAEBAREA/8QAFBABAAAAAAAAAAAAAAAAAAAAAP/aAAgBAQABPxA=";
  
  console.log("Running Single Image...");
  const res1 = await analyzeImageCondition(dummyBase64, "Test");
  console.log("Single res:", res1);
  
  console.log("Running Comparative Image...");
  try {
     const res2 = await analyzeImageCondition(dummyBase64, "Test", dummyBase64);
     console.log("Comparative res:", res2);
  } catch(e) {
     console.error("Comparative failed outside:", e);
  }
}

run();
