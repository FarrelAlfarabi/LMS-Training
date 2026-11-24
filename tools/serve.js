// Static server with single page app fallback, for local checks.
const http = require('http'), fs = require('fs'), path = require('path');
const root = path.resolve(process.argv[2]), port = +process.argv[3] || 8080;
const types = { '.html': 'text/html', '.js': 'text/javascript', '.mjs': 'text/javascript', '.json': 'application/json', '.wasm': 'application/wasm', '.mp4': 'video/mp4', '.pdf': 'application/pdf', '.ttf': 'font/ttf', '.otf': 'font/otf', '.png': 'image/png', '.css': 'text/css' };
http.createServer((req, res) => {
  let p = path.join(root, decodeURIComponent(req.url.split('?')[0]));
  if (!p.startsWith(root) || !fs.existsSync(p) || fs.statSync(p).isDirectory()) p = path.join(root, 'index.html');
  const stat = fs.statSync(p), type = types[path.extname(p)] || 'application/octet-stream';
  const range = req.headers.range;
  if (range) {
    const [s, e] = range.replace('bytes=', '').split('-'); const start = +s, end = e ? +e : stat.size - 1;
    res.writeHead(206, { 'Content-Type': type, 'Content-Range': `bytes ${start}-${end}/${stat.size}`, 'Accept-Ranges': 'bytes', 'Content-Length': end - start + 1 });
    return fs.createReadStream(p, { start, end }).pipe(res);
  }
  res.writeHead(200, { 'Content-Type': type, 'Content-Length': stat.size, 'Accept-Ranges': 'bytes' });
  fs.createReadStream(p).pipe(res);
}).listen(port, () => console.log('serving', root, port));
