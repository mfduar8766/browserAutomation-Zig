process.title = 'example-ui-app';
import http from 'http';
import fs from 'fs';
import path from 'node:path';

const server = http.createServer((req, res) => {
  const __dirname = path.dirname(new URL(import.meta.url).pathname);
  const filePath = path.join(__dirname, 'index.html');
  fs.readFile(filePath, (err, content) => {
    if (err) {
      res.writeHead(500, { 'Content-Type': 'text/plain' });
      res.end('Error loading the HTML file.');
    } else {
      res.writeHead(200, { 'Content-Type': 'text/html' });
      res.end(content);
    }
  });
});

server.listen(3000, '127.0.0.1', () =>
  console.log(`Server listening on http://127.0.0.1:3000`)
);
