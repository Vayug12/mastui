/**
 * Lightweight render server for the admin panel.
 * Accepts HTML, screenshots it with Playwright, returns PNG.
 *
 *   node render-server.js          starts on http://localhost:3000
 */
import http from 'node:http';
import { chromium } from 'playwright';

const PORT = Number(process.env.PORT ?? 3000);
const VIEWPORT = { width: 390, height: 844 };

async function screenshotHtml(html) {
  const browser = await chromium.launch();
  try {
    const page = await browser.newPage({ viewport: VIEWPORT, deviceScaleFactor: 3 });
    await page.setContent(html, { waitUntil: 'load' });
    await page.waitForTimeout(200);
    return await page.screenshot({ type: 'png' });
  } finally {
    await browser.close();
  }
}

const server = http.createServer(async (req, res) => {
  // CORS
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    res.writeHead(204);
    res.end();
    return;
  }

  if (req.method === 'POST' && req.url === '/render') {
    let body = '';
    for await (const chunk of req) body += chunk;

    try {
      const { html } = JSON.parse(body);
      if (!html) {
        res.writeHead(400, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ error: 'Missing html field' }));
        return;
      }

      console.log(`  rendering ${html.length} chars...`);
      const png = await screenshotHtml(html);
      console.log(`  done (${png.length} bytes)`);

      res.writeHead(200, { 'Content-Type': 'image/png' });
      res.end(png);
    } catch (err) {
      console.error('  error:', err.message);
      res.writeHead(500, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ error: err.message }));
    }
    return;
  }

  res.writeHead(404, { 'Content-Type': 'text/plain' });
  res.end('Not found');
});

server.listen(PORT, () => {
  console.log(`\n  Render server running on http://localhost:${PORT}`);
  console.log(`  POST /render { html } -> PNG screenshot\n`);
});
