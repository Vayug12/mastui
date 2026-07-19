import { chromium } from 'playwright';
import fs from 'node:fs/promises';
import path from 'node:path';

export const VIEWPORT = { width: 390, height: 844 };
export const WEB_VIEWPORT = { width: 1440, height: 900 };
export const OUT_DIR = path.join(import.meta.dirname, 'out');

/**
 * Screenshot one HTML file at a given viewport, returning the PNG buffer.
 */
export async function shootOne(page, htmlPath, imagePath) {
  await page.goto(`file://${htmlPath.replace(/\\/g, '/')}`, { waitUntil: 'load' });
  await page.waitForTimeout(150); // let fonts/layout settle
  await page.screenshot({ path: imagePath });
}

/**
 * Screenshot every out/<id>/design.html that exists, writing image.png beside it.
 * Reads metadata.json to determine the correct viewport per item.
 */
export async function shootAll({ only = null, platforms = null } = {}) {
  const entries = await fs.readdir(OUT_DIR, { withFileTypes: true }).catch(() => []);
  const ids = entries
    .filter((e) => e.isDirectory())
    .map((e) => e.name)
    .filter((id) => !only || only.includes(id));

  if (ids.length === 0) {
    console.log('nothing to shoot — run `npm run generate` first');
    return [];
  }

  const browser = await chromium.launch();

  const shot = [];
  try {
    for (const id of ids) {
      const htmlPath = path.join(OUT_DIR, id, 'design.html');
      const metaPath = path.join(OUT_DIR, id, 'metadata.json');
      const imagePath = path.join(OUT_DIR, id, 'image.png');

      // Read metadata to determine target platform
      let itemPlatform = 'mobile';
      try {
        const meta = JSON.parse(await fs.readFile(metaPath, 'utf8'));
        if (Array.isArray(meta.platforms) && meta.platforms.length > 0) {
          itemPlatform = meta.platforms[0];
        }
      } catch { /* no metadata, default to mobile */ }

      // If caller filtered by platform, skip designs that don't match
      if (platforms && !platforms.includes(itemPlatform)) continue;

      const isWeb = itemPlatform === 'web';
      const viewport = isWeb ? WEB_VIEWPORT : VIEWPORT;
      const scale = isWeb ? 2 : 3;

      try {
        const page = await browser.newPage({ viewport, deviceScaleFactor: scale });
        try {
          await shootOne(page, htmlPath, imagePath);
          console.log(`  shot  ${id} (${itemPlatform})`);
          shot.push(id);
        } finally {
          await page.close();
        }
      } catch (err) {
        console.error(`  FAIL  ${id}: ${err.message}`);
      }
    }
  } finally {
    await browser.close();
  }

  console.log(`\nscreenshots: ${shot.length}/${ids.length}`);
  return shot;
}

if (import.meta.filename === process.argv[1]) {
  await shootAll();
}
