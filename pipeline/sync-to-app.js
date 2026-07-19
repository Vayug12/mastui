/**
 * Bridge: Cloudflare R2 catalog -> the Flutter app's bundled assets.
 *
 *   node sync-to-app.js
 *
 * Fetches the published catalog from the Worker API and copies every design
 * image into ../assets/designs/<id>.png, then writes ../assets/catalog.json
 * so the app shows real content instead of placeholders.
 *
 * This is the local preview path — bundled assets ship inside the APK, so adding
 * screens this way needs a Play Store update. Once the Cloudflare Worker + R2 are
 * live the app fetches new screens over the air and this bundle becomes just the
 * offline starter set.
 */
import fs from 'node:fs/promises';
import path from 'node:path';

const APP_ROOT = path.join(import.meta.dirname, '..');
const ASSET_DIR = path.join(APP_ROOT, 'assets', 'designs');
const CATALOG_DEST = path.join(APP_ROOT, 'assets', 'catalog.json');

const API_URL = process.env.MASTUI_API_URL || 'https://mastui-api.sanjeev-yadav1201.workers.dev';

// Fetch catalog from Worker API (R2)
console.log('  fetching catalog from Worker API...');
const res = await fetch(`${API_URL}/catalog`, { signal: AbortSignal.timeout(15000) });
if (!res.ok) {
  console.error(`  failed to fetch catalog: HTTP ${res.status}`);
  process.exit(1);
}
const catalog = await res.json();
console.log(`  ${catalog.length} designs on server`);

if (catalog.length === 0) {
  console.error('  no designs found — upload some first');
  process.exit(1);
}

await fs.rm(ASSET_DIR, { recursive: true, force: true });
await fs.mkdir(ASSET_DIR, { recursive: true });

const bundled = [];
let downloaded = 0;
let failed = 0;

for (const item of catalog) {
  const imageUrl = item.imageUrl || `${API_URL}/designs/${item.id}.png`;
  const destPath = path.join(ASSET_DIR, `${item.id}.png`);

  try {
    const imgRes = await fetch(imageUrl, { signal: AbortSignal.timeout(10000) });
    if (!imgRes.ok) throw new Error(`HTTP ${imgRes.status}`);
    const buffer = Buffer.from(await imgRes.arrayBuffer());
    await fs.writeFile(destPath, buffer);
    downloaded++;
  } catch (err) {
    console.error(`  FAIL  ${item.id}: ${err.message}`);
    failed++;
    continue;
  }

  bundled.push({
    id: item.id,
    title: item.title,
    category: item.category,
    platforms: Array.isArray(item.platforms) && item.platforms.length > 0
        ? item.platforms
        : ['mobile'],
    styleTags: item.styleTags,
    prompt: item.prompt,
    ...(item.packId ? { packId: item.packId, packName: item.packName, order: item.order } : {}),
    imageAsset: `assets/designs/${item.id}.png`,
  });
}

await fs.writeFile(CATALOG_DEST, JSON.stringify(bundled, null, 2), 'utf8');

const categories = [...new Set(bundled.map((b) => b.category))];
console.log(`\nsynced ${bundled.length} designs (${downloaded} ok, ${failed} failed) across ${categories.length} categories`);
console.log(`  ${CATALOG_DEST}`);
console.log(`\nnow run:  flutter run`);
