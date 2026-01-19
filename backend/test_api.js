const { spawn } = require('child_process');
const http = require('http');

const PORT = 4000; // Default fallback

console.log("Starting backend server for testing...");
const server = spawn('node', ['src/index.js'], { 
  cwd: __dirname,
  env: { ...process.env, PORT: PORT.toString(), MONGODB_URI: "mongodb://localhost:27017/product_traceability_test" } 
});

server.stdout.on('data', (data) => {
  console.log(`[server]: ${data}`);
  if (data.toString().includes(`Listening on port ${PORT}`)) {
    runTests();
  }
});

server.stderr.on('data', (data) => {
  console.error(`[server err]: ${data}`);
});

function runTests() {
  console.log("Server started. Running tests...");
  
  const req = http.get(`http://localhost:${PORT}/health`, (res) => {
    let data = '';
    res.on('data', (chunk) => data += chunk);
    res.on('end', () => {
      console.log(`GET /health: ${res.statusCode} ${data}`);
      if (res.statusCode === 200 && JSON.parse(data).ok === true) {
        console.log("✅ Health check passed");
        cleanup(0);
      } else {
        console.error("❌ Health check failed");
        cleanup(1);
      }
    });
  });

  req.on('error', (err) => {
    console.error(`❌ Request failed: ${err.message}`);
    cleanup(1);
  });
}

function cleanup(code) {
  server.kill();
  process.exit(code);
}

// Timeout
setTimeout(() => {
  console.error("❌ Test timed out");
  cleanup(1);
}, 15000);
