// 投稿用ビルド（build/store）をローカルで配信して、ヘッドレスの Chromium で開き、スクショを撮る
// 使い方: node webcheck.mjs <配信するフォルダ> <出力png> [クリックするか: click]
import { createRequire } from 'module';
import http from 'http';
import fs from 'fs';
import path from 'path';
const require = createRequire('C:/Users/PC_User/projects/onepiece-card-sim/package.json');
const { chromium } = require('playwright-core');
const [root, out, act] = process.argv.slice(2);
const types = { '.html': 'text/html', '.js': 'application/javascript', '.wasm': 'application/wasm', '.pck': 'application/octet-stream', '.png': 'image/png' };
const server = http.createServer((req, res) => {
  const f = path.join(root, decodeURIComponent(req.url.split('?')[0]).replace(/^\//, '') || 'index.html');
  fs.readFile(f, (e, d) => {
    if (e) { res.writeHead(404); return res.end(); }
    res.writeHead(200, { 'Content-Type': types[path.extname(f)] || 'application/octet-stream', 'Content-Length': d.length });
    res.end(d);
  });
}).listen(8097, '127.0.0.1');
const browser = await chromium.launch({ executablePath: 'C:/Users/PC_User/AppData/Local/ms-playwright/chromium-1243/chrome-win64/chrome.exe', headless: true, args: ['--use-angle=swiftshader', '--enable-unsafe-swiftshader'] });
const page = await browser.newPage({ viewport: { width: 450, height: 800 } });
const logs = [];
page.on('console', m => logs.push(m.type() + ': ' + m.text()));
page.on('pageerror', e => logs.push('pageerror: ' + e.message));
await page.goto('http://127.0.0.1:8097/index.html');
await page.waitForTimeout(40000);
if (act === 'click') {  // タイトルの「はじめる」あたり → 棚の材料2つ → 煮る
  for (const [x, y] of [[225, 428], [45, 181], [105, 181], [225, 710]]) { await page.mouse.click(x, y); await page.waitForTimeout(1500); }
  await page.waitForTimeout(2500);
}
await page.screenshot({ path: out });
console.log(logs.filter(l => !l.startsWith('debug')).slice(-15).join('\n'));
await browser.close();
server.close();
