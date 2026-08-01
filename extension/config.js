/**
 * GENERATED FILE — do not edit.
 * Source: shared/config.js · regenerate with `npm run pack`.
 */
/**
 * MastUI — single source of truth for every URL the project points at.
 *
 * ─────────────────────────────────────────────────────────────────────────
 *  BUYING A DOMAIN LATER? Change SITE_URL below. That is the only edit.
 *  Then run:  npm run build   (regenerates the site)
 *             npm run pack    (regenerates extension/config.js + the zip)
 * ─────────────────────────────────────────────────────────────────────────
 *
 * Nothing else in the codebase may hardcode a host. Pages link to each other
 * with relative paths, so SITE_URL is only ever needed for the absolute URLs
 * that crawlers require: canonical, og:url, sitemap.xml and JSON-LD.
 *
 * This file is consumed by Node (web/build.js) and copied verbatim into the
 * extension by web/pack-extension.js, so it must stay free of Node-only APIs.
 */

// `process` does not exist inside a browser or extension, hence the guard.
const env = (typeof process !== 'undefined' && process.env) || {};

/** Where the public site lives. No trailing slash. */
export const SITE_URL = env.SITE_URL || 'https://mastui.pages.dev';

/** The Cloudflare Worker serving the catalog, images and prompt generator. */
export const API_URL =
  env.API_URL || 'https://mastui-api.sanjeev-yadav1201.workers.dev';

/** Play Store listing, linked from the site footer and the side panel. */
export const PLAY_STORE_URL =
  env.PLAY_STORE_URL ||
  'https://play.google.com/store/apps/details?id=app.mastui';

/**
 * Chrome Web Store listing. Empty until the extension is published — the site
 * hides its install button while this is blank rather than linking nowhere.
 */
export const CHROME_STORE_URL = env.CHROME_STORE_URL || '';

export const SITE_NAME = 'MastUI';
export const SITE_TAGLINE = 'UI design prompts for AI coding tools';
export const SITE_DESCRIPTION =
  'A free library of production-ready UI design prompts. Copy one into Lovable, ' +
  'v0, Cursor or Bolt and get an interface that actually looks designed.';

/** Every AI tool the extension can paste a prompt straight into. */
export const AI_TOOL_HOSTS = [
  'lovable.dev',
  'v0.app',
  'bolt.new',
  'claude.ai',
  'chatgpt.com',
];

/** Absolute URL for a site path. `path` must start with a slash. */
export function siteUrl(path = '/') {
  return `${SITE_URL}${path}`;
}

/** Absolute URL for a design's rendered screenshot. */
export function designImageUrl(id) {
  return `${API_URL}/designs/${id}.png`;
}
