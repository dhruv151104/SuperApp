require('dotenv').config({ path: './.env' });
const { GoogleGenerativeAI } = require("@google/generative-ai");

async function listModels() {
  const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);
  
  const modelsToTest = [
    "gemini-2.0-flash", // The one that exists for this user!
    "gemini-1.5-flash",
    "gemini-pro-vision",
    "gemini-1.5-pro"
  ];

  console.log("Checking available models...");

  for (const modelName of modelsToTest) {
      try {
         const model = genAI.getGenerativeModel({ model: modelName });
         // Simple text prompt to check existence (even if vision model, usually replies to text)
         // For vision models, we might need image, but let's try text first or empty generation
         process.stdout.write(`Testing ${modelName}... `);
         
         if (modelName.includes("vision")) {
             // Skip text-only test for vision-only models (old ones)
             // But gemini-pro-vision supports text+image.
             // We can just try to instantiate. SDK doesn't validate until call.
             // We will try a call.
             await model.generateContent("Hello"); 
         } else {
             await model.generateContent("Hello");
         }
         console.log("✅ WORKS!");
      } catch (e) {
         if (e.message.includes("404")) {
             console.log("❌ Not Found");
         } else if (e.message.includes("Image")) {
             // If it complains about missing image, then the MODEL EXISTS!
             console.log("✅ WORKS! (Exists, just needs image)");
         } else {
             console.log(`❌ Error: ${e.message.split('\n')[0]}`);
         }
      }
  }
}

listModels();
