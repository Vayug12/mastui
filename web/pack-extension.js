/**
 * Prepares the extension for Chrome Web Store upload.
 *
 *   1. Copies shared/config.js into extension/config.js, so the panel and the
 *      site can never drift onto different hosts.
 *   2. Copies the app icon in as the extension icon.
 *   3. Zips extension/ to web/dist/mastui-extension.zip.
 *
 * Run `npm run pack` after any edit to shared/config.js.
 */

import fs from 'node:fs/promises';
import path from 'node:path';
import { execFile } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { promisify } from 'node:util';

const run = promisify(execFile);

const ROOT = path.dirname(fileURLToPath(import.meta.url));
const REPO = path.join(ROOT, '..');
const EXT = path.join(REPO, 'extension');
const OUT = path.join(ROOT, 'dist', 'mastui-extension.zip');

const GENERATED_HEADER = `/**
 * GENERATED FILE — do not edit.
 * Source: shared/config.js · regenerate with \`npm run pack\`.
 */
`;

async function syncConfig() {
  const source = await fs.readFile(path.join(REPO, 'shared', 'config.js'), 'utf8');
  await fs.writeFile(path.join(EXT, 'config.js'), GENERATED_HEADER + source, 'utf8');
  console.log('✓ extension/config.js synced from shared/config.js');
}

async function syncIcon() {
  try {
    await fs.copyFile(
      path.join(REPO, 'images', 'logo_square.png'),
      path.join(EXT, 'icon128.png')
    );
    console.log('✓ extension/icon128.png synced from images/logo_square.png');
  } catch {
    console.warn('! images/logo_square.png not found — add extension/icon128.png by hand');
  }
}

/**
 * Zips via PowerShell on Windows and `zip` elsewhere, so this works without
 * pulling in an archiver dependency.
 *
 * Every extension file must stay flat in extension/. Windows' Compress-Archive
 * writes nested entries with backslashes, which the ZIP spec forbids and the
 * Web Store can fail to read — keeping the folder flat sidesteps it entirely.
 */
async function zip() {
  await fs.mkdir(path.dirname(OUT), { recursive: true });
  await fs.rm(OUT, { force: true });

  if (process.platform === 'win32') {
    await run('powershell', [
      '-NoProfile',
      '-Command',
      `Compress-Archive -Path '${EXT}\\*' -DestinationPath '${OUT}' -Force`,
    ]);
  } else {
    await run('zip', ['-r', '-q', OUT, '.'], { cwd: EXT });
  }

  const { size } = await fs.stat(OUT);
  console.log(`✓ ${path.relative(REPO, OUT)} (${(size / 1024).toFixed(0)} KB)`);
}

async function main() {
  await syncConfig();
  await syncIcon();
  await zip();
  console.log('\nUpload that zip at https://chrome.google.com/webstore/devconsole');
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
