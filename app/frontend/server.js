const http = require("http");
const server = http.createServer((req, res) => {
  res.writeHead(200, { "Content-Type": "text/html" });
  res.end(`
    <html>
    <head><title>Frontend App</title></head>
    <body>
      <h1>Frontend Application</h1>
      <p>Running on Docker Swarm</p>
      <p>Backend API: <a href="/api">/api</a></p>
      <p>Hostname: ${require("os").hostname()}</p>
    </body>
    </html>
  `);
});
server.listen(3000, () => console.log("Frontend running on port 3000"));
