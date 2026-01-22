const { GoogleGenerativeAI } = require("@google/generative-ai");
const fs = require("fs");

// Initialize the API Client with the API Key
const genAI = new GoogleGenerativeAI(process.env.GEMINI_API_KEY);

// Helper function to convert local file to Generative Part
function fileToGenerativePart(path, mimeType) {
  return {
    inlineData: {
      data: Buffer.from(fs.readFileSync(path)).toString("base64"),
      mimeType,
    },
  };
}

/**
 * Analyzes an image for damage.
 * @param {string} imagePath 
 * @param {string} [productName] - Optional (used for fallback simulation)
 */
/**
 * Analyzes an image for damage, optionally comparing against a reference.
 * @param {string} imagePath - The current image to analyze.
 * @param {string} [productName] - Optional context.
 * @param {string} [referenceImagePath] - Optional path to the original/manufacturer image.
 */
async function analyzeImageCondition(imagePath, productName, referenceImagePath) {
  try {
    if (!process.env.GEMINI_API_KEY) {
        throw new Error("No GEMINI_API_KEY found in environment variables");
    }

    const model = genAI.getGenerativeModel({ model: "gemini-2.0-flash" });
    const parts = [];

    // 1. Current Image (Always present)
    parts.push(fileToGenerativePart(imagePath, "image/jpeg"));

    let prompt = "";
    
    if (referenceImagePath && fs.existsSync(referenceImagePath)) {
       // 2. Reference Image
       parts.unshift(fileToGenerativePart(referenceImagePath, "image/jpeg")); // Ref first
       
       prompt = `
         You are a Supply Chain Quality Assurance Expert.
         Image 1: ORIGINAL REFERENCE (Mint Condition).
         Image 2: CURRENT STATUS (To be verified).

         COMPARE Image 2 against Image 1.
         1. Does the product match the reference (Shape, Color, Labeling)?
         2. Has the condition degraded? (Damage, spoilage, tampering).
         
         Return strictly JSON: { 
            "isDamaged": boolean, 
            "reason": "concise explanation of any MISMATCH or DAMAGE found. precise details." 
         }
       `;
       console.log("[Vision] Comparative Analysis Mode (Ref + Current)");
    } else {
       // Single Image Mode
       prompt = `
         You are an automated Quality Assurance bot.
         Analyze this image of a product/package (${productName || "unknown item"}).
         Check for:
         1. Physical Damage (Crushed, torn, wet, broken box).
         2. Spoilage/Discoloration (Rotting, mold, strange colors).

         Return strictly JSON: { "isDamaged": boolean, "reason": "concise string explaining the specific damage or color issue found" }
       `;
       console.log("[Vision] Single Image Analysis Mode");
    }
    
    parts.push(prompt);

    console.log("[Vision] Sending request to Google Gemini...");
    const result = await model.generateContent(parts);
    const response = await result.response;
    const text = response.text();
    
    console.log("[Vision] Success! Response:", text);

    const cleanJson = text.replace(/```json/g, "").replace(/```/g, "").trim();
    return JSON.parse(cleanJson);

  } catch (err) {
    console.error("[Vision] API Failed:", err.message);
    
    // Fallback Simulation
    const name = (productName || "").toLowerCase();
    const isDamaged = name.includes("damage") || name.includes("broken");
    return {
        isDamaged: isDamaged,
        reason: isDamaged 
            ? "Damage detected (Simulation Fallback)" 
            : "Verified Intact (Simulation Fallback)"
    };
  }
}

module.exports = { analyzeImageCondition };
