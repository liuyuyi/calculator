const http = require('http');
const fs = require('fs');
const path = require('path');

const server = http.createServer((req, res) => {
    console.log('Request received:', req.url);
    
    // Handle root path
    if (req.url === '/') {
        const filePath = path.join(__dirname, 'index.html');
        serveFile(filePath, 'text/html', res);
    } 
    // Handle HTML files in root directory
    else if (req.url.endsWith('.html')) {
        const filePath = path.join(__dirname, req.url.substring(1)); // Remove leading slash
        serveFile(filePath, 'text/html', res);
    }
    // Handle static files from public directory
    else {
        // If the request starts with /public, remove it before joining with the public directory
        let staticPath = req.url;
        if (staticPath.startsWith('/public')) {
            staticPath = staticPath.substring('/public'.length);
        }
        const filePath = path.join(__dirname, 'public', staticPath);
        // Determine content type based on file extension
        let contentType = 'text/plain';
        if (filePath.endsWith('.js')) contentType = 'application/javascript';
        if (filePath.endsWith('.css')) contentType = 'text/css';
        if (filePath.endsWith('.jpg') || filePath.endsWith('.jpeg')) contentType = 'image/jpeg';
        if (filePath.endsWith('.png')) contentType = 'image/png';
        
        serveFile(filePath, contentType, res);
    }
});

// Helper function to serve files
function serveFile(filePath, contentType, res) {
    fs.readFile(filePath, (err, content) => {
        if (err) {
            console.error('Error reading file:', filePath, err);
            res.writeHead(404);
            res.end('File not found');
        } else {
            console.log('Serving file:', filePath);
            res.writeHead(200, { 'Content-Type': contentType });
            res.end(content);
        }
    });
}

const PORT = process.env.PORT || 3000;
server.listen(PORT, () => {
    console.log(`Server running at http://localhost:${PORT}/`);
    console.log('Available files:');
    console.log('- http://localhost:3000/ (index.html)');
    console.log('- http://localhost:3000/test.html');
});