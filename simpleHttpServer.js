const http = require('http');
const fs = require('fs');
const path = require('path');
const url = require('url');

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
    // Handle API: /getPrice
    else if (req.url.startsWith('/getPrice')) {
        handleGetPrice(req, res);
    }
    // Handle API: /getPriceAll
    else if (req.url.startsWith('/getPriceAll')) {
        handleGetPriceAll(req, res);
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

// Handle /getPrice API
function handleGetPrice(req, res) {
    const parsedUrl = url.parse(req.url, true);
    const query = parsedUrl.query;
    
    console.log('getPrice request:', query);
    
    // 模拟数据 - 如果有数据库，可以在这里查询数据库
    const mockData = {
        type: 1,
        price: 75000,
        upDateTime: '2026-03-07 14:30:00',
        creatDate: new Date().getTime()
    };
    
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify(mockData));
}

// Handle /getPriceAll API
function handleGetPriceAll(req, res) {
    const parsedUrl = url.parse(req.url, true);
    const query = parsedUrl.query;
    
    console.log('getPriceAll request:', query);
    
    // 获取分页参数
    const num = query.pageSize ? parseInt(query.pageSize) : 10;
    const pageNo = query.pageNo ? parseInt(query.pageNo) : 0;
    const skip = pageNo * num;
    
    // 模拟数据 - 如果有数据库，可以在这里查询数据库
    const mockData = [];
    for (let i = 0; i < num; i++) {
        mockData.push({
            type: i % 2,
            price: 75000 + i * 100,
            upDateTime: '2026-03-07 14:30:00',
            creatDate: new Date().getTime() - i * 3600000
        });
    }
    
    const total = 100;
    const lastPageNum = Math.ceil(total / num);
    
    const page = {
        page_no: pageNo + 1,
        page_size: num,
        total: total,
        lastPageNum: lastPageNum,
        data: mockData
    };
    
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify(page));
}

server.listen(PORT, () => {
    console.log(`Server running at http://localhost:${PORT}/`);
    console.log('Available files:');
    console.log('- http://localhost:3000/ (index.html)');
    console.log('- http://localhost:3000/test.html');
    console.log('- http://localhost:3000/getPrice');
    console.log('- http://localhost:3000/getPriceAll');
});