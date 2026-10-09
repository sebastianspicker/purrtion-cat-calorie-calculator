import { createServer } from 'node:http';
import { readFile, stat, realpath } from 'node:fs/promises';
import { existsSync } from 'node:fs';
import { resolve, sep, extname, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
const root = resolve(dirname(fileURLToPath(import.meta.url)), '../dist/web');
const mime = { '.html': 'text/html; charset=utf-8', '.js': 'text/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8', '.css': 'text/css; charset=utf-8', '.svg': 'image/svg+xml', '.png': 'image/png',
  '.woff2': 'font/woff2', '.txt': 'text/plain; charset=utf-8', '.md': 'text/markdown; charset=utf-8' };
export function serve() {
  if (!existsSync(resolve(root, 'index.html'))) throw new Error('Build the website first: npm run build');
  const port = Number(process.env.PORT ?? 5173); const host = process.env.HOST ?? '127.0.0.1';
  if (!Number.isInteger(port) || port < 1 || port > 65535) throw new Error('PORT must be between 1 and 65535');
  const server = createServer(async (req, res) => {
    res.setHeader('X-Content-Type-Options', 'nosniff');
    res.setHeader('Referrer-Policy', 'no-referrer');
    res.setHeader('Cache-Control', 'no-store');
    res.setHeader('Content-Security-Policy', "default-src 'self'; script-src 'self'; style-src 'self'; img-src 'self'; font-src 'self'; connect-src 'self'; object-src 'none'; base-uri 'self'; frame-ancestors 'none'; form-action 'none'");
    if (!['GET', 'HEAD'].includes(req.method ?? '')) { res.writeHead(405, { Allow: 'GET, HEAD' }); res.end(); return; }
    let path;
    try {
      const pathname = decodeURIComponent(new URL(req.url ?? '/', 'http://localhost').pathname);
      path = resolve(root, `.${pathname.endsWith('/') ? `${pathname}index.html` : pathname}`);
      if (!path.startsWith(root + sep)) { res.writeHead(403); res.end('Forbidden'); return; }
    } catch { res.writeHead(400); res.end('Bad request'); return; }
    try {
      const resolved = await realpath(path);
      if (!resolved.startsWith(root + sep) || !(await stat(resolved)).isFile()) { res.writeHead(404); res.end('Not found'); return; }
      const body = await readFile(resolved);
      res.writeHead(200, { 'Content-Type': mime[extname(resolved)] ?? 'application/octet-stream', 'Content-Length': body.length });
      res.end(req.method === 'HEAD' ? undefined : body);
    } catch { res.writeHead(404); res.end('Not found'); }
  });
  server.on('error', error => { console.error(error.message); process.exitCode = 1; });
  server.listen(port, host, () => console.log(`Purrtion: http://${host}:${port} (Ctrl+C to stop)`));
  return server;
}
if (process.argv[1] === fileURLToPath(import.meta.url)) serve();
