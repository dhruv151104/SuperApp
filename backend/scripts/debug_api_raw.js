require('dotenv').config({ path: './.env' });

async function debugRaw() {
    const key = process.env.GEMINI_API_KEY;
    const url = `https://generativelanguage.googleapis.com/v1beta/models?key=${key}`;

    console.log("Fetching: " + url.replace(key, "HIDDEN_KEY"));

    try {
        const response = await fetch(url);
        const data = await response.json();

        if (!response.ok) {
            console.log("\n❌ HTTP Error: " + response.status);
            console.log("Details:", JSON.stringify(data, null, 2));
        } else {
            console.log("\n✅ Success! API is working.");
            console.log(`Found ${data.models ? data.models.length : 0} models.`);
            if (data.models) {
                console.log("Available Models:");
                data.models.forEach(m => console.log(" - " + m.name));
            }
        }
    } catch (e) {
        console.log("Network Error:", e.message);
    }
}

debugRaw();
