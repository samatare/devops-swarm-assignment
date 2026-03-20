const http = require("http");
const fs = require("fs");

function readSecret(name) {
  try { return fs.readFileSync(`/run/secrets/${name}`, "utf8").trim(); }
  catch { return "not-mounted"; }
}

const server = http.createServer((req, res) => {
  if (req.url === "/health") {
    res.writeHead(200);
    res.end("OK");
    return;
  }
  res.writeHead(200, { "Content-Type": "application/json" });
  res.end(JSON.stringify({
    service: "backend-api",
    status: "running",
    hostname: require("os").hostname(),
    path: req.url,
    db_host: process.env.DB_HOST || "not-set",
    db_user: readSecret("db_user"),
    secrets_mounted: fs.existsSync("/run/secrets/db_password")
  }, null, 2));
});
server.listen(3000, () => console.log("Backend API running on port 3000"));
