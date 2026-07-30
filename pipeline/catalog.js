/**
 * Builds metadata.json + catalog.json for every out/<id>/design.html that exists,
 * by matching the folder name back to its entry in templates.js.
 *
 * Use this when design.html was authored directly (in a Claude Code session)
 * rather than produced by generate.js — no API key needed.
 *
 *   node catalog.js
 */
import fs from 'node:fs/promises';
import path from 'node:path';

import { buildCatalog, buildPacks, STYLES } from './templates.js';
import { OUT_DIR } from './shoot.js';

const items = new Map(
  [...buildCatalog(), ...buildPacks().flatMap((pack) => pack.screens)].map((item) => [item.id, item]),
);
const paletteSpecs = new Map(
  STYLES.flatMap((style) => style.palettes.map((p) => [`${style.id}:${p.id}`, p])),
);

/**
 * The prompt promises a palette; the screenshot must deliver it. Flag any design.html
 * that uses hex codes from a *different* palette of the same style — the failure mode
 * is a user copying a prompt that can't reproduce what they saw.
 */
function paletteMismatch(html, item) {
  const style =
    STYLES.find((s) => s.id === item.styleId) ?? STYLES.find((s) => item.id.endsWith(`-${s.id}`));
  if (!style || style.palettes.length < 2) return null;

  const hexesOf = (p) => new Set((p.spec.match(/#[0-9A-Fa-f]{6}/g) ?? []).map((h) => h.toUpperCase()));
  const used = new Set((html.match(/#[0-9A-Fa-f]{6}/g) ?? []).map((h) => h.toUpperCase()));
  const all = style.palettes.map((p) => ({ id: p.id, hexes: hexesOf(p) }));

  const mine = all.find((p) => p.id === item.palette);
  if (!mine) return null;

  // Only hexes unique within this style are evidence — a shade shared by two
  // sibling palettes proves nothing about which one the design followed.
  const exclusive = (target) =>
    [...target.hexes].filter((h) => all.every((p) => p.id === target.id || !p.hexes.has(h)));

  const foreign = all
    .filter((p) => p.id !== item.palette)
    .map((p) => ({ id: p.id, hits: exclusive(p).filter((h) => used.has(h)) }))
    .filter((p) => p.hits.length > 0)
    .sort((a, b) => b.hits.length - a.hits.length);

  if (foreign.length > 0) {
    return `uses ${foreign[0].hits.join(' ')} from sibling palette "${foreign[0].id}", prompt says "${item.palette}"`;
  }

  const own = exclusive(mine);
  if (own.length > 0 && !own.some((h) => used.has(h))) {
    return `uses none of the "${item.palette}" colors (${own.join(' ')})`;
  }
  return null;
}

const dirs = await fs.readdir(OUT_DIR, { withFileTypes: true }).catch(() => []);
const catalog = [];
const unknown = [];
const mismatches = [];

for (const dir of dirs.filter((d) => d.isDirectory())) {
  const id = dir.name;
  const hasHtml = await fs
    .access(path.join(OUT_DIR, id, 'design.html'))
    .then(() => true, () => false);
  if (!hasHtml) continue;

  const item = items.get(id);
  if (!item) {
    unknown.push(id);
    continue;
  }

  const html = await fs.readFile(path.join(OUT_DIR, id, 'design.html'), 'utf8');
  const mismatch = paletteMismatch(html, item);
  if (mismatch) {
    mismatches.push(`${id}: ${mismatch}`);
  }

  const meta = {
    id: item.id,
    title: item.title,
    category: item.category,
    platforms: item.platforms ?? ['mobile'],
    styleTags: item.styleTags,
    palette: item.palette,
    prompt: item.prompt,
    ...(item.fontFamily ? { fontFamily: item.fontFamily } : {}),
    ...(item.packId ? { packId: item.packId, packName: item.packName, order: item.order } : {}),
  };
  await fs.writeFile(path.join(OUT_DIR, id, 'metadata.json'), JSON.stringify(meta, null, 2), 'utf8');

  const hasImage = await fs
    .access(path.join(OUT_DIR, id, 'image.png'))
    .then(() => true, () => false);

  catalog.push({ ...meta, image: `${id}/image.png`, shot: hasImage });
  const platformTag = meta.platforms?.includes('web') ? ' [web]' : '';
  console.log(`  ${hasImage ? 'ok  ' : 'todo'}  ${id}${platformTag}`);
}

await fs.writeFile(path.join(OUT_DIR, 'catalog.json'), JSON.stringify(catalog, null, 2), 'utf8');

console.log(`\ncatalog.json: ${catalog.length} entries (${catalog.filter((c) => c.shot).length} screenshotted)`);
if (unknown.length > 0) {
  console.log(`unknown folders (no matching template id): ${unknown.join(', ')}`);
}
if (mismatches.length > 0) {
  console.log(`\nPALETTE MISMATCH — prompt and screenshot disagree:`);
  for (const m of mismatches) console.log(`  ${m}`);
  process.exitCode = 1;
}
