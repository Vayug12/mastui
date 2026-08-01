/**
 * Static site generator for MastUI.
 *
 * Fetches the live catalog from the Worker and writes one HTML file per
 * design, per style pack and per category into `dist/`. Cloudflare Pages
 * serves `dist/prompts/<id>/index.html` at `/prompts/<id>` with no config.
 *
 *   npm run build          build against the live catalog
 *   npm run build -- --local   build against ../assets/catalog.json (offline)
 *
 * The domain is never written here — it comes from ../shared/config.js.
 */

import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

import { API_URL, SITE_URL, siteUrl, designImageUrl } from '../shared/config.js';
import {
  designPage,
  packPage,
  categoryPage,
  homePage,
  slugify,
} from './templates.js';

const ROOT = path.dirname(fileURLToPath(import.meta.url));
const DIST = path.join(ROOT, 'dist');
const REPO = path.join(ROOT, '..');

/** How many single screens the home page renders server-side. */
const HOME_SINGLES = 48;
/** Sibling designs shown at the bottom of a design page. */
const RELATED_COUNT = 6;

async function loadCatalog({ local }) {
  if (!local) {
    try {
      const res = await fetch(`${API_URL}/catalog`, {
        signal: AbortSignal.timeout(30_000),
      });
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      const data = await res.json();
      console.log(`✓ fetched ${data.length} designs from the Worker`);
      return data;
    } catch (err) {
      console.warn(`! live catalog unavailable (${err.message}) — using the bundled copy`);
    }
  }

  const raw = await fs.readFile(path.join(REPO, 'assets', 'catalog.json'), 'utf8');
  const data = Object.values(JSON.parse(raw));
  console.log(`✓ loaded ${data.length} designs from assets/catalog.json`);
  return data;
}

/**
 * Normalizes a catalog entry. Older entries predate `platforms`, and the
 * bundled copy has no `imageUrl` — both are filled in here so templates never
 * have to care where the data came from.
 */
function normalize(entry) {
  const platforms = Array.isArray(entry.platforms)
    ? entry.platforms.filter((p) => p === 'mobile' || p === 'web')
    : [];
  return {
    id: entry.id,
    title: entry.title,
    category: entry.category,
    prompt: entry.prompt,
    styleTags: Array.isArray(entry.styleTags) ? entry.styleTags : [],
    platforms: platforms.length ? platforms : ['mobile'],
    packId: entry.packId ?? null,
    packName: entry.packName ?? null,
    order: Number(entry.order) || 0,
    imageUrl: entry.imageUrl || designImageUrl(entry.id),
  };
}

/** Assigns each design a unique, readable slug (falls back to `-2`, `-3`… on title collisions). */
function assignSlugs(designs) {
  const seen = new Map();
  for (const d of designs) {
    const base = slugify(d.title);
    const n = (seen.get(base) || 0) + 1;
    seen.set(base, n);
    d.slug = n === 1 ? base : `${base}-${n}`;
  }
}

/** Groups pack screens into packs, keeping each pack's designed screen order. */
function groupPacks(designs) {
  const byPack = new Map();
  for (const d of designs) {
    if (!d.packId) continue;
    if (!byPack.has(d.packId)) byPack.set(d.packId, []);
    byPack.get(d.packId).push(d);
  }

  return [...byPack.entries()].map(([id, screens]) => {
    screens.sort((a, b) => a.order - b.order);
    return {
      id,
      name: screens[0].packName || id,
      screens,
      tags: screens[0].styleTags,
      // The Home screen makes the most legible cover; fall back to the first.
      cover: screens.find((s) => s.category === 'Home') || screens[0],
    };
  });
}

async function writePage(routePath, html) {
  const dir = path.join(DIST, routePath);
  await fs.mkdir(dir, { recursive: true });
  await fs.writeFile(path.join(dir, 'index.html'), html, 'utf8');
}

async function copyStatic() {
  await fs.cp(path.join(ROOT, 'static'), DIST, { recursive: true });

  // Reuse the app's existing icon rather than maintaining a second one.
  const icon = path.join(REPO, 'images', 'logo_square.png');
  try {
    await fs.copyFile(icon, path.join(DIST, 'favicon.png'));
  } catch {
    console.warn('! images/logo_square.png not found — site has no favicon');
  }
}

function sitemap(urls) {
  const today = new Date().toISOString().slice(0, 10);
  const entries = urls
    .map(
      ({ loc, priority }) => `  <url>
    <loc>${siteUrl(loc)}</loc>
    <lastmod>${today}</lastmod>
    <priority>${priority}</priority>
  </url>`
    )
    .join('\n');

  return `<?xml version="1.0" encoding="UTF-8"?>
<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
${entries}
</urlset>`;
}

async function build() {
  const local = process.argv.includes('--local');

  const raw = await loadCatalog({ local });
  const designs = raw.map(normalize);
  assignSlugs(designs);
  const packs = groupPacks(designs);
  const singles = designs.filter((d) => !d.packId);

  const byCategory = new Map();
  for (const d of designs) {
    if (!byCategory.has(d.category)) byCategory.set(d.category, []);
    byCategory.get(d.category).push(d);
  }
  const categories = [...byCategory.keys()].sort();

  await fs.rm(DIST, { recursive: true, force: true });
  await fs.mkdir(DIST, { recursive: true });
  await copyStatic();

  const urls = [{ loc: '/', priority: '1.0' }];

  // ── One page per design ────────────────────────────────────────────────
  const packById = new Map(packs.map((p) => [p.id, p]));
  for (const design of designs) {
    const related = (byCategory.get(design.category) || [])
      .filter((d) => d.id !== design.id)
      .slice(0, RELATED_COUNT);

    await writePage(
      path.join('prompts', design.slug),
      designPage(design, { pack: design.packId ? packById.get(design.packId) : null, related })
    );
    urls.push({ loc: `/prompts/${design.slug}/`, priority: '0.8' });
  }

  // ── One page per style pack ────────────────────────────────────────────
  for (const pack of packs) {
    await writePage(path.join('packs', pack.id), packPage(pack));
    urls.push({ loc: `/packs/${pack.id}/`, priority: '0.9' });
  }

  // ── One page per category ──────────────────────────────────────────────
  for (const [category, items] of byCategory) {
    const slug = slugify(category);
    await writePage(path.join('category', slug), categoryPage(category, items));
    urls.push({ loc: `/category/${slug}/`, priority: '0.7' });
  }

  // ── Home ───────────────────────────────────────────────────────────────
  await fs.writeFile(
    path.join(DIST, 'index.html'),
    homePage({
      packs,
      designs: singles.slice(0, HOME_SINGLES),
      categories,
      total: designs.length,
    }),
    'utf8'
  );

  // ── Search index ───────────────────────────────────────────────────────
  // Prompts are omitted on purpose: search never matches on them and shipping
  // 1,186 full prompts would inflate this file past a megabyte.
  const index = designs.map((d) => ({
    i: d.id,
    t: d.title,
    c: d.category,
    g: d.styleTags,
    p: d.platforms,
    u: d.imageUrl,
    k: d.packId,
  }));
  await fs.writeFile(path.join(DIST, 'index.json'), JSON.stringify(index), 'utf8');

  // ── Crawler files ──────────────────────────────────────────────────────
  await fs.writeFile(path.join(DIST, 'sitemap.xml'), sitemap(urls), 'utf8');
  await fs.writeFile(
    path.join(DIST, 'robots.txt'),
    `User-agent: *\nAllow: /\n\nSitemap: ${siteUrl('/sitemap.xml')}\n`,
    'utf8'
  );

  console.log(`\n✓ built ${urls.length} pages into web/dist`);
  console.log(`  ${designs.length} designs · ${packs.length} packs · ${categories.length} categories`);
  console.log(`  canonical host: ${SITE_URL}`);
  console.log(`\n  Preview:  npx serve web/dist`);
}

build().catch((err) => {
  console.error(err);
  process.exit(1);
});
