/**
 * Auto-generate UI designs and upload to Cloudflare R2.
 *
 * Single screen mode (default): picks random missing templates one by one.
 * Pack mode (--pack <style>): generates all 7 foundation screens for one
 *   style, so they share the same design system like a real app.
 *
 *   node auto-generate.js                          one screen, OpenCode
 *   node auto-generate.js --count 5                5 random screens
 *   node auto-generate.js --provider codex         use Codex instead
 *   node auto-generate.js --pack neon-cyber         full Neon Cyber pack
 *   node auto-generate.js --pack random             random incomplete pack
 *   node auto-generate.js --loop                    keep generating forever
 *   node auto-generate.js --loop --interval 60      one screen every 60s
 *   node auto-generate.js --platform web            only web designs
 *   node auto-generate.js --platform mobile         only mobile designs
 */
import fs from 'node:fs/promises';
import path from 'node:path';
import { chromium } from 'playwright';

import { buildCatalog, buildPacks, STYLES, PACK_SCREENS } from './templates.js';
import { generateHtml, createClient } from './generate.js';
import { VIEWPORT, WEB_VIEWPORT, OUT_DIR } from './shoot.js';

const API_URL = process.env.MASTUI_API_URL || 'https://mastui-api.sanjeev-yadav1201.workers.dev';
const ADMIN_SECRET = process.env.ADMIN_SECRET || '';

function parseArgs(argv) {
  const args = {
    count: 1,
    provider: 'opencode',
    loop: false,
    interval: 120,
    platform: null, // null = all, 'mobile' | 'web'
    pack: null, // null = single mode, 'random' or style id = pack mode
  };
  for (let i = 2; i < argv.length; i++) {
    const arg = argv[i];
    if (arg === '--count') args.count = Number(argv[++i]) || 1;
    else if (arg === '--provider') args.provider = argv[++i];
    else if (arg === '--loop') args.loop = true;
    else if (arg === '--interval') args.interval = Number(argv[++i]) || 120;
    else if (arg === '--pack') args.pack = argv[++i] ?? 'random';
    else if (arg === '--platform') args.platform = argv[++i];
  }
  if (args.platform && !['mobile', 'web'].includes(args.platform)) {
    throw new Error(`unknown platform: ${args.platform} (expected mobile | web)`);
  }
  return args;
}

/** Fetch existing design IDs from the Worker catalog. */
async function fetchRemoteCatalog() {
  try {
    const res = await fetch(`${API_URL}/catalog`, { signal: AbortSignal.timeout(8000) });
    if (!res.ok) return { ids: new Set(), packs: {} };
    const data = await res.json();
    const ids = new Set(data.map((d) => d.id));
    const packs = {};
    for (const d of data) {
      if (d.packId) {
        (packs[d.packId] ??= []).push(d.id);
      }
    }
    return { ids, packs };
  } catch {
    return { ids: new Set(), packs: {} };
  }
}

/** Screenshot HTML and return PNG buffer. */
async function screenshotHtml(browser, html, { platform = 'mobile' } = {}) {
  const viewport = platform === 'web' ? WEB_VIEWPORT : VIEWPORT;
  const scale = platform === 'web' ? 2 : 3;
  const dir = await fs.mkdtemp(path.join(await fs.mkdtemp(OUT_DIR), 'auto-'));
  const htmlPath = path.join(dir, 'design.html');
  await fs.writeFile(htmlPath, html, 'utf8');

  const page = await browser.newPage({ viewport, deviceScaleFactor: scale });
  try {
    await page.goto(`file://${htmlPath.replace(/\\/g, '/')}`, { waitUntil: 'load' });
    await page.waitForTimeout(200);
    return await page.screenshot({ type: 'png' });
  } finally {
    await page.close();
    await fs.rm(dir, { recursive: true, force: true }).catch(() => {});
  }
}

/** Upload one design to Worker API with retry. */
async function uploadToWorker(item, pngBuffer, packMeta, { retries = 3, delay = 2000 } = {}) {
  if (!ADMIN_SECRET) throw new Error('ADMIN_SECRET env not set');

  for (let attempt = 1; attempt <= retries; attempt++) {
    const blob = new Blob([pngBuffer], { type: 'image/png' });
    const formData = new FormData();
    formData.append('image', blob, `${item.id}.png`);
    formData.append('metadata', JSON.stringify({
      id: item.id,
      title: item.title,
      category: item.category,
      platforms: item.platforms ?? ['mobile'],
      styleTags: item.styleTags ?? [],
      prompt: item.prompt,
      ...packMeta,
    }));

    try {
      const res = await fetch(`${API_URL}/admin/upload`, {
        method: 'POST',
        headers: { 'X-Admin-Secret': ADMIN_SECRET },
        body: formData,
      });
      const data = await res.json().catch(() => ({}));
      if (!res.ok) throw new Error(data.error || `HTTP ${res.status}`);
      return data;
    } catch (err) {
      if (attempt === retries) throw err;
      console.log(`    attempt ${attempt} failed: ${err.message} — retrying in ${delay / 1000}s...`);
      await new Promise((r) => setTimeout(r, delay));
    }
  }
}

/** Generate one random missing single screen. */
async function generateSingle(args, browser, client, remote, allTemplates) {
  const missing = allTemplates.filter((t) => !remote.ids.has(t.id));
  if (missing.length === 0) return false;

  const item = missing[Math.floor(Math.random() * missing.length)];
  const platform = item.platforms?.[0] ?? 'mobile';
  console.log(`\n  [single] ${item.id} — ${item.title} (${platform})`);

  const { html } = await generateHtml(client, item, args.provider);
  console.log(`  html: ${html.length} chars`);

  const png = await screenshotHtml(browser, html, { platform });
  console.log(`  screenshot: ${png.length} bytes`);

  const result = await uploadToWorker(item, png, {});
  console.log(`  uploaded: ${result.imageUrl}`);
  remote.ids.add(item.id);
  return true;
}

/** Generate a full pack (all 7 screens in one style). */
async function generatePack(args, browser, client, remote, styleId) {
  const allPacks = buildPacks();
  const pack = allPacks.find((p) => p.id === styleId);
  if (!pack) {
    console.error(`  unknown style: ${styleId}`);
    console.log(`  available: ${allPacks.map((p) => p.id).join(', ')}`);
    return false;
  }

  const existingInPack = remote.packs[pack.id] ?? [];
  let missing = pack.screens.filter((s) => !remote.ids.has(s.id));
  if (args.platform) {
    missing = missing.filter((s) => s.platforms.includes(args.platform));
  }
  if (missing.length === 0) {
    console.log(`  pack "${pack.name}" already complete (${existingInPack.length} screens) — skipping`);
    return true;
  }

  console.log(`\n  [pack] ${pack.name} — ${missing.length}/${pack.screens.length} screens to generate`);
  const packMeta = { packId: pack.id, packName: pack.name };

  // Generate anchor screen first (no reference)
  const anchor = missing[0];
  const anchorPlatform = anchor.platforms?.[0] ?? 'mobile';
  console.log(`  → ${anchor.category} (anchor, ${anchorPlatform})`);
  const { html: anchorHtml } = await generateHtml(client, anchor, args.provider);
  const anchorPng = await screenshotHtml(browser, anchorHtml, { platform: anchorPlatform });
  await uploadToWorker(anchor, anchorPng, { ...packMeta, order: anchor.order });
  console.log(`    uploaded ✓`);
  remote.ids.add(anchor.id);

  // Generate remaining screens using anchor as reference
  for (const screen of missing.slice(1)) {
    const screenPlatform = screen.platforms?.[0] ?? 'mobile';
    console.log(`  → ${screen.category} (${screenPlatform})`);
    try {
      const { html } = await generateHtml(client, screen, args.provider, {
        referenceHtml: anchorHtml,
      });
      const png = await screenshotHtml(browser, html, { platform: screenPlatform });
      await uploadToWorker(screen, png, { ...packMeta, order: screen.order });
      console.log(`    uploaded ✓`);
      remote.ids.add(screen.id);
    } catch (err) {
      console.error(`    FAILED: ${err.message}`);
    }
  }
  return true;
}

/** Find a random incomplete pack. */
function pickIncompletePack(remote) {
  const allPacks = buildPacks();
  const incomplete = allPacks.filter((p) => {
    const existingCount = p.screens.filter((s) => remote.ids.has(s.id)).length;
    return existingCount < p.screens.length;
  });
  if (incomplete.length === 0) return null;
  return incomplete[Math.floor(Math.random() * incomplete.length)];
}

async function cleanupOrphanDirs() {
  try {
    const entries = await fs.readdir(OUT_DIR, { withFileTypes: true });
    for (const e of entries) {
      if (e.isDirectory() && e.name.startsWith('out')) {
        const full = path.join(OUT_DIR, e.name);
        const inside = await fs.readdir(full).catch(() => []);
        if (inside.length === 0) {
          await fs.rm(full, { recursive: true, force: true }).catch(() => {});
        }
      }
    }
  } catch {}
}

async function main() {
  const args = parseArgs(process.argv);
  await cleanupOrphanDirs();
  const mode = args.pack ? `pack (${args.pack})` : 'single';
  const platformFilter = args.platform ? ` [${args.platform}]` : '';
  console.log(`\n  MastUI Auto-Generate`);
  console.log(`  mode: ${mode}${platformFilter} | provider: ${args.provider}`);
  console.log(`  api: ${API_URL}\n`);

  if (!ADMIN_SECRET) {
    console.error('  Set ADMIN_SECRET env first:\n    $env:ADMIN_SECRET = "your-secret"');
    process.exit(1);
  }

  const client = createClient(args.provider);
  const browser = await chromium.launch();
  let generated = 0;
  let failed = 0;

  try {
    console.log('  fetching remote catalog...');
    const remote = await fetchRemoteCatalog();
    console.log(`  ${remote.ids.size} designs on server, ${Object.keys(remote.packs).length} packs`);

    let allSingleTemplates = buildCatalog();
    if (args.platform) {
      allSingleTemplates = allSingleTemplates.filter((t) => t.platforms.includes(args.platform));
    }
    console.log(`  ${allSingleTemplates.length} single templates | ${buildPacks().length} packs available\n`);

    if (args.loop) {
      console.log(`  continuous mode (interval: ${args.interval}s) — Ctrl+C to stop\n`);
      while (true) {
        try {
          let ok;
          if (args.pack) {
            const styleId = args.pack === 'random' ? pickIncompletePack(remote)?.id : args.pack;
            if (!styleId) { console.log('  all packs complete!'); break; }
            ok = await generatePack(args, browser, client, remote, styleId);
          } else {
            ok = await generateSingle(args, browser, client, remote, allSingleTemplates);
          }
          if (ok) generated++; else break;
        } catch (err) {
          failed++;
          console.error(`  FAILED: ${err.message}`);
        }
        console.log(`  stats: ${generated} ok / ${failed} failed`);
        if (args.count && generated >= args.count) break;
        await new Promise((r) => setTimeout(r, args.interval * 1000));
      }
    } else {
      for (let i = 0; i < args.count; i++) {
        try {
          let ok;
          if (args.pack) {
            const styleId = args.pack === 'random' ? pickIncompletePack(remote)?.id : args.pack;
            if (!styleId) { console.log('  all packs complete!'); break; }
            ok = await generatePack(args, browser, client, remote, styleId);
          } else {
            ok = await generateSingle(args, browser, client, remote, allSingleTemplates);
          }
          if (ok) generated++; else break;
        } catch (err) {
          failed++;
          console.error(`  FAILED: ${err.message}`);
        }
      }
      console.log(`\n  done: ${generated} generated, ${failed} failed`);
    }
  } finally {
    await browser.close();
  }


}

await main();
