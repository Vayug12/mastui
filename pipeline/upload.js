/**
 * Upload pipeline/out/ to Cloudflare R2 via wrangler CLI.
 *
 *   node upload.js              upload everything
 *   node upload.js --dry-run    list files without uploading
 *   node upload.js --clean      upload then delete local out/ folder
 */
import fs from 'node:fs/promises';
import path from 'node:path';
import { execSync } from 'node:child_process';

import { OUT_DIR } from './shoot.js';

const BUCKET = 'mastui-catalog';
const DRY_RUN = process.argv.includes('--dry-run');
const CLEAN = process.argv.includes('--clean');

function r2Put(localPath, remoteKey) {
  const ct = remoteKey.endsWith('.json') ? 'application/json' : 'image/png';
  const cmd = `wrangler r2 object put "${BUCKET}/${remoteKey}" --file "${localPath}" --content-type "${ct}" --remote`;
  console.log(`    > ${cmd}`);
  execSync(cmd, { stdio: 'pipe', cwd: OUT_DIR });
}

async function main() {
  const catalogPath = path.join(OUT_DIR, 'catalog.json');
  let catalog;
  try {
    catalog = JSON.parse(await fs.readFile(catalogPath, 'utf8'));
  } catch {
    console.error('No catalog.json found. Run `node catalog.js` first.');
    process.exit(1);
  }

  const toUpload = catalog.filter((item) => item.image || item.shot);
  console.log(`Found ${toUpload.length} designs to upload.\n`);

  if (DRY_RUN) {
    console.log('Dry run - files that would be uploaded:');
    console.log(`  catalog.json`);
    for (const item of shot) {
      console.log(`  designs/${item.id}.png`);
    }
    return;
  }

  let uploaded = 0;
  let failed = 0;

  // Upload catalog.json
  try {
    r2Put(catalogPath, 'catalog.json');
    console.log('  ok  catalog.json');
    uploaded++;
  } catch (err) {
    console.error('  FAIL catalog.json:', err.message);
    failed++;
  }

  // Upload each design PNG
  for (const item of toUpload) {
    const imgPath = path.join(OUT_DIR, item.image);
    try {
      r2Put(imgPath, `designs/${item.id}.png`);
      console.log(`  ok  ${item.id}.png`);
      uploaded++;
    } catch (err) {
      console.error(`  FAIL ${item.id}.png:`, err.message);
      failed++;
    }
  }

  console.log(`\nUploaded: ${uploaded}  Failed: ${failed}`);

  if (CLEAN && uploaded > 0) {
    console.log('\nCleaning local output...');
    await fs.rm(OUT_DIR, { recursive: true, force: true });
    console.log('  removed pipeline/out/');
  }

  if (uploaded > 0) {
    console.log('\nNext: cd worker && wrangler deploy');
  }
}

await main();
