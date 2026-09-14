import { existsSync, createReadStream, statSync } from "node:fs";
import { createServer } from "node:http";
import { dirname, extname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const distDir = resolve(__dirname, "..", "dist");
const port = parseInt(process.env.PORT || "3000", 10);

const mimeTypes = {
  ".html": "text/html; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".json": "application/json; charset=utf-8",
  ".webmanifest": "application/manifest+json; charset=utf-8",
  ".png": "image/png",
  ".jpg": "image/jpeg",
  ".svg": "image/svg+xml",
  ".ico": "image/x-icon",
  ".txt": "text/plain; charset=utf-8",
  ".xml": "application/xml; charset=utf-8"
};

const server = createServer((req, res) => {
  const urlPath = decodeURI(req.url.split("?")[0]);
  let filePath = join(distDir, urlPath);

  // Soporte para URLs limpias con o sin slash final
  if (existsSync(filePath) && statSync(filePath).isDirectory()) {
    filePath = join(filePath, "index.html");
  } else if (!existsSync(filePath) && existsSync(`${filePath}.html`)) {
    filePath = `${filePath}.html`;
  } else if (!existsSync(filePath) && existsSync(join(filePath, "index.html"))) {
    filePath = join(filePath, "index.html");
  }

  if (!existsSync(filePath) || statSync(filePath).isDirectory()) {
    res.writeHead(404, { "Content-Type": "text/html; charset=utf-8" });
    res.end("<h1>404 No Encontrado</h1><p>La página solicitada no existe.</p><p><a href='/'>Volver al inicio</a></p>");
    return;
  }

  const ext = extname(filePath).toLowerCase();
  const contentType = mimeTypes[ext] || "application/octet-stream";

  res.writeHead(200, {
    "Content-Type": contentType,
    "Cache-Control": "no-cache"
  });

  createReadStream(filePath).pipe(res);
});

server.listen(port, () => {
  console.log(`\n🚀 Servidor de desarrollo CasiListo Web corriendo en:`);
  console.log(`👉 http://localhost:${port}/`);
  console.log(`👉 http://localhost:${port}/privacy/`);
  console.log(`👉 http://localhost:${port}/support/\n`);
  console.log("Presiona Ctrl+C para detener el servidor.\n");
});
