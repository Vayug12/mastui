/**
 * MastUI content pipeline.
 *
 * Style packs (the product: one style, 7 consistent foundation screens):
 *   node run.js --packs --plan           list every pack and its screens
 *   node run.js --packs --limit 1        generate one pack — anchor screen first,
 *                                        the rest copy its design system
 *   node run.js --packs --style soft-dark  only one pack
 *
 * Legacy single-screen catalog (kept for regenerating old items):
 *   node run.js --plan                   list every prompt the catalog would produce
 *   node run.js --limit 10               generate + screenshot the first 10
 *   node run.js --category Login         only one category
 *
 * Platform filtering:
 *   node run.js --platform mobile        only mobile designs
 *   node run.js --platform web           only web designs
 *   node run.js                          both mobile and web (default)
 *
 * Common flags:
 *   --provider codex       claude (default, API key) | claude-code | codex | opencode
 *   --no-shoot             generate HTML but skip screenshots
 *   --force                regenerate items that already exist
 *
 * Output per item:  out/<id>/design.html, out/<id>/image.png, out/<id>/metadata.json
 * Plus a combined   out/catalog.json  ready for the Cloudflare upload step.
 */
import fs from 'node:fs/promises';
import path from 'node:path';

import { buildCatalog, buildPacks, CATEGORIES, STYLES } from './templates.js';
import { createClient, generateHtml, PROVIDERS } from './generate.js';
import { shootAll, OUT_DIR } from './shoot.js';

const CONCURRENCY = Number(process.env.MASTUI_CONCURRENCY ?? 3);

function parseArgs(argv) {
  const args = {
    plan: false,
    packs: false,
    shoot: true,
    force: false,
    limit: null,
    category: null,
    style: null,
    platform: null, // null = all, 'mobile' | 'web'
    provider: process.env.MASTUI_PROVIDER ?? 'claude',
  };
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (arg === '--plan') args.plan = true;
    else if (arg === '--packs') args.packs = true;
    else if (arg === '--no-shoot') args.shoot = false;
    else if (arg === '--force') args.force = true;
    else if (arg === '--limit') args.limit = Number(argv[++i]);
    else if (arg === '--category') args.category = argv[++i];
    else if (arg === '--style') args.style = argv[++i];
    else if (arg === '--platform') args.platform = argv[++i];
    else if (arg === '--provider') args.provider = argv[++i];
  }
  if (!PROVIDERS.includes(args.provider)) {
    throw new Error(`unknown provider: ${args.provider} (expected ${PROVIDERS.join(' | ')})`);
  }
  if (args.platform && !['mobile', 'web'].includes(args.platform)) {
    throw new Error(`unknown platform: ${args.platform} (expected mobile | web)`);
  }
  if (args.packs && args.category) {
    throw new Error('--category applies to the legacy catalog only; packs are selected with --style');
  }
  return args;
}

function selectCatalog(args) {
  const categories = args.category
    ? CATEGORIES.filter((c) => c.name.toLowerCase() === args.category.toLowerCase())
    : CATEGORIES;
  const styles = args.style ? STYLES.filter((s) => s.id === args.style) : STYLES;

  if (categories.length === 0) throw new Error(`unknown category: ${args.category}`);
  if (styles.length === 0) throw new Error(`unknown style: ${args.style}`);

  let items = buildCatalog({ categories, styles });
  if (args.platform) {
    items = items.filter((item) => item.platforms.includes(args.platform));
  }
  return args.limit ? items.slice(0, args.limit) : items;
}

/** In packs mode --limit counts packs, not screens — one pack is the unit users think in. */
function selectPacks(args) {
  const styles = args.style ? STYLES.filter((s) => s.id === args.style) : STYLES;
  if (styles.length === 0) throw new Error(`unknown style: ${args.style}`);
  let packs = buildPacks({ styles });
  if (args.platform) {
    packs = packs.map((pack) => ({
      ...pack,
      screens: pack.screens.filter((s) => s.platforms.includes(args.platform)),
    })).filter((pack) => pack.screens.length > 0);
  }
  return args.limit ? packs.slice(0, args.limit) : packs;
}

async function exists(file) {
  return fs.access(file).then(() => true, () => false);
}

/** Run `worker` over `items` with a fixed number of parallel slots. */
async function pool(items, size, worker) {
  const queue = [...items];
  const runners = Array.from({ length: Math.min(size, queue.length) }, async () => {
    while (queue.length > 0) {
      await worker(queue.shift());
    }
  });
  await Promise.all(runners);
}

function itemMeta(item) {
  return {
    id: item.id,
    title: item.title,
    category: item.category,
    platforms: item.platforms ?? ['mobile'],
    styleTags: item.styleTags,
    palette: item.palette,
    prompt: item.prompt,
    ...(item.packId ? { packId: item.packId, packName: item.packName, order: item.order } : {}),
  };
}

function platformTag(item) {
  return item.platforms?.includes('web') ? ' [web]' : '';
}

async function writeItem(item, html) {
  const dir = path.join(OUT_DIR, item.id);
  await fs.mkdir(dir, { recursive: true });
  await fs.writeFile(path.join(dir, 'design.html'), html, 'utf8');
  await fs.writeFile(path.join(dir, 'metadata.json'), JSON.stringify(itemMeta(item), null, 2), 'utf8');
}

async function writeCatalog(done) {
  const catalog = done.map((item) => ({ ...itemMeta(item), image: `${item.id}/image.png` }));
  await fs.writeFile(path.join(OUT_DIR, 'catalog.json'), JSON.stringify(catalog, null, 2), 'utf8');
  console.log(`\ncatalog.json written with ${catalog.length} entries`);
}

async function generatePacks(args) {
  const packs = selectPacks(args);
  const total = packs.reduce((n, p) => n + p.screens.length, 0);

  if (args.plan) {
    for (const pack of packs) {
      console.log(`\n=== ${pack.id} — ${pack.name} [palette: ${pack.palette.name}] ===`);
      for (const screen of pack.screens) console.log(`  ${screen.id} — ${screen.category}`);
    }
    console.log(`\n${packs.length} packs x ${packs[0]?.screens.length ?? 0} screens = ${total} items`);
    return;
  }

  const client = createClient(args.provider);
  await fs.mkdir(OUT_DIR, { recursive: true });
  console.log(
    `generating ${packs.length} packs (${total} screens) with ${args.provider} (concurrency ${CONCURRENCY})…\n`,
  );

  const done = [];
  const failed = [];

  // Packs run in parallel; screens inside a pack run in sequence because
  // every screen after the anchor needs the anchor's HTML as its reference.
  await pool(packs, CONCURRENCY, async (pack) => {
    const [anchor, ...rest] = pack.screens;
    const anchorPath = path.join(OUT_DIR, anchor.id, 'design.html');
    let referenceHtml;

    if (!args.force && (await exists(anchorPath))) {
      referenceHtml = await fs.readFile(anchorPath, 'utf8');
      console.log(`  skip  ${anchor.id} (exists — use --force to regenerate)`);
      done.push(anchor);
    } else {
      try {
        const { html } = await generateHtml(client, anchor, args.provider);
        await writeItem(anchor, html);
        referenceHtml = html;
        done.push(anchor);
        console.log(`  ok    ${anchor.id}${platformTag(anchor)} (anchor)`);
      } catch (err) {
        failed.push({ id: anchor.id, error: err.message });
        console.error(`  FAIL  ${anchor.id}: ${err.message} — skipping the rest of pack ${pack.id}`);
        return;
      }
    }

    for (const item of rest) {
      const htmlPath = path.join(OUT_DIR, item.id, 'design.html');
      if (!args.force && (await exists(htmlPath))) {
        console.log(`  skip  ${item.id} (exists — use --force to regenerate)`);
        done.push(item);
        continue;
      }
      try {
        const { html } = await generateHtml(client, item, args.provider, { referenceHtml });
        await writeItem(item, html);
        done.push(item);
        console.log(`  ok    ${item.id}${platformTag(item)}`);
      } catch (err) {
        failed.push({ id: item.id, error: err.message });
        console.error(`  FAIL  ${item.id}: ${err.message}`);
      }
    }
  });

  console.log(`\ngenerated: ${done.length}/${total}`);
  if (failed.length > 0) {
    console.log(`failed: ${failed.map((f) => f.id).join(', ')}`);
  }

  if (args.shoot && done.length > 0) {
    console.log(`\nscreenshotting…`);
    await shootAll({ only: done.map((d) => d.id) });
  }

  await writeCatalog(done);
}

async function generateSingles(args) {
  const items = selectCatalog(args);

  if (args.plan) {
    for (const item of items) {
      console.log(`\n=== ${item.id} — ${item.title} [${item.category}] ===\n${item.prompt}`);
    }
    console.log(`\n${items.length} items across ${CATEGORIES.length} categories x ${STYLES.length} styles`);
    return;
  }

  const client = createClient(args.provider);
  await fs.mkdir(OUT_DIR, { recursive: true });

  console.log(`generating ${items.length} screens with ${args.provider} (concurrency ${CONCURRENCY})…\n`);
  const done = [];
  const failed = [];
  let inputTokens = 0;
  let outputTokens = 0;

  await pool(items, CONCURRENCY, async (item) => {
    const htmlPath = path.join(OUT_DIR, item.id, 'design.html');

    if (!args.force && (await exists(htmlPath))) {
      console.log(`  skip  ${item.id} (exists — use --force to regenerate)`);
      done.push(item);
      return;
    }

    try {
      const { html, usage } = await generateHtml(client, item, args.provider);
      await writeItem(item, html);
      inputTokens += usage.input_tokens ?? 0;
      outputTokens += usage.output_tokens ?? 0;
      done.push(item);
      console.log(`  ok    ${item.id}${platformTag(item)}`);
    } catch (err) {
      failed.push({ id: item.id, error: err.message });
      console.error(`  FAIL  ${item.id}: ${err.message}`);
    }
  });

  const tokens = args.provider === 'claude' ? `   tokens: ${inputTokens} in / ${outputTokens} out` : '';
  console.log(`\ngenerated: ${done.length}/${items.length}${tokens}`);
  if (failed.length > 0) {
    console.log(`failed: ${failed.map((f) => f.id).join(', ')}`);
  }

  if (args.shoot && done.length > 0) {
    console.log(`\nscreenshotting…`);
    await shootAll({ only: done.map((d) => d.id) });
  }

  await writeCatalog(done);
}

const args = parseArgs(process.argv.slice(2));
await (args.packs ? generatePacks(args) : generateSingles(args));
