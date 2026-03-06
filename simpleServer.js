const express = require('express');
const app = express();

// Serve static files from the public directory
app.use('/public', express.static('public'));

// Serve index.html at the root
app.get('/', (req, res) => {
    res.sendFile(__dirname + "/" + "index.html");
});

// Start the server
const server = app.listen(3000, () => {
    const host = server.address().address;
    const port = server.address().port;
    console.log("Server running at http://%s:%s", host, port);
});