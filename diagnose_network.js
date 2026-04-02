const net = require('net');

const HOST = '192.168.1.34';
const PORT = 4000;

console.log(`--- Connectivity Check (${HOST}:${PORT}) ---`);
const client = new net.Socket();
client.setTimeout(2000); // 2s timeout

client.connect(PORT, HOST, function() {
	console.log(`Connected to backend on ${HOST}:${PORT}`);
	client.destroy();
});

client.on('error', function(err) {
	console.log(`Failed to connect to backend on ${HOST}:${PORT}: ` + err.message);
});

client.on('timeout', function() {
	console.log('Connection timed out');
	client.destroy();
});
