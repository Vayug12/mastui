/**
 * HTML templates for the static site.
 *
 * Every page is plain server-rendered HTML — no framework, no hydration. That
 * is deliberate: the whole point of per-design URLs is that a crawler sees the
 * prompt without executing anything.
 *
 * Internal links are always relative so that changing SITE_URL never requires
 * touching a template.
 */

import {
  API_URL,
  SITE_NAME,
  SITE_TAGLINE,
  SITE_DESCRIPTION,
  PLAY_STORE_URL,
  CHROME_STORE_URL,
  siteUrl,
} from '../shared/config.js';

/** Escapes text destined for HTML body or attribute content. */
export function esc(value) {
  return String(value ?? '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

/** URL-safe slug for category paths. */
export function slugify(value) {
  return String(value)
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-|-$/g, '');
}

/** First sentence or so of a prompt, for meta descriptions. */
function summarize(prompt, max = 155) {
  const flat = prompt.replace(/\s+/g, ' ').trim();
  if (flat.length <= max) return flat;
  const cut = flat.slice(0, max);
  return `${cut.slice(0, cut.lastIndexOf(' '))}…`;
}

/**
 * @param {object} page
 * @param {string} page.title      full <title>
 * @param {string} page.description meta description
 * @param {string} page.path       site-absolute path, e.g. `/prompts/foo/`
 * @param {string} [page.image]    absolute og:image URL
 * @param {string} [page.jsonLd]   serialized structured data
 * @param {string} page.body       page markup
 */
export function layout(page) {
  const canonical = siteUrl(page.path);
  return `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${esc(page.title)}</title>
<meta name="description" content="${esc(page.description)}">
<link rel="canonical" href="${esc(canonical)}">
<meta property="og:type" content="website">
<meta property="og:site_name" content="${esc(SITE_NAME)}">
<meta property="og:title" content="${esc(page.title)}">
<meta property="og:description" content="${esc(page.description)}">
<meta property="og:url" content="${esc(canonical)}">
${page.image ? `<meta property="og:image" content="${esc(page.image)}">` : ''}
<meta name="twitter:card" content="${page.image ? 'summary_large_image' : 'summary'}">
<link rel="icon" href="/favicon.png">
<link rel="stylesheet" href="/styles.css">
<meta name="mastui:api" content="${esc(API_URL)}">
${page.jsonLd ? `<script type="application/ld+json">${page.jsonLd}</script>` : ''}
</head>
<body>
<header class="site-header">
  <a class="brand" href="/">${esc(SITE_NAME)}</a>
  <nav>
    <a href="/#packs">Style packs</a>
    <a href="/#browse">Browse</a>
    ${CHROME_STORE_URL ? `<a class="cta" href="${esc(CHROME_STORE_URL)}">Add to Chrome</a>` : ''}
  </nav>
</header>
<main>
${page.body}
</main>
<footer class="site-footer">
  <p>${esc(SITE_NAME)} — ${esc(SITE_TAGLINE)}. Free, no sign-up.</p>
  <p class="links">
    ${CHROME_STORE_URL ? `<a href="${esc(CHROME_STORE_URL)}">Chrome extension</a>` : ''}
    <a href="${esc(PLAY_STORE_URL)}">Android app</a>
  </p>
</footer>
<script src="/app.js" type="module"></script>
</body>
</html>`;
}

/** A grid tile linking to a design or a pack. */
function card({ href, image, title, subtitle }) {
  return `<a class="card" href="${esc(href)}">
  <img src="${esc(image)}" alt="${esc(title)}" loading="lazy" decoding="async" width="360" height="640">
  <span class="card-meta"><strong>${esc(title)}</strong><em>${esc(subtitle)}</em></span>
</a>`;
}

export function designCard(design) {
  return card({
    href: `/prompts/${design.slug}/`,
    image: design.imageUrl,
    title: design.title,
    subtitle: design.category,
  });
}

export function packCard(pack) {
  return card({
    href: `/packs/${pack.id}/`,
    image: pack.cover.imageUrl,
    title: pack.name,
    subtitle: `${pack.screens.length} matching screens`,
  });
}

/** The copy-to-clipboard prompt block, shared by design and pack pages. */
function promptBlock(design) {
  return `<div class="prompt" data-design-id="${esc(design.id)}" data-category="${esc(design.category)}">
  <div class="prompt-head">
    <h2>Prompt</h2>
    <button type="button" class="copy-btn" data-copy>Copy prompt</button>
  </div>
  <pre data-prompt-text>${esc(design.prompt)}</pre>
</div>`;
}

export function designPage(design, { pack, related }) {
  const title = `${design.title} — UI prompt for Lovable, v0 & Cursor | ${SITE_NAME}`;
  const description = summarize(
    `${design.title} (${design.category}). Copy-paste UI prompt: ${design.prompt}`
  );
  const tags = design.styleTags.map((t) => `<li>${esc(t)}</li>`).join('');

  const jsonLd = JSON.stringify({
    '@context': 'https://schema.org',
    '@type': 'CreativeWork',
    name: design.title,
    description: summarize(design.prompt, 300),
    image: design.imageUrl,
    url: siteUrl(`/prompts/${design.slug}/`),
    genre: design.category,
    keywords: design.styleTags.join(', '),
    isAccessibleForFree: true,
  });

  const body = `<article class="detail">
  <nav class="crumbs">
    <a href="/">Home</a> ›
    <a href="/category/${esc(slugify(design.category))}/">${esc(design.category)}</a> ›
    <span>${esc(design.title)}</span>
  </nav>

  <div class="detail-grid">
    <figure class="shot">
      <img src="${esc(design.imageUrl)}" alt="${esc(design.title)} — ${esc(design.category)} screen"
           width="720" height="1280" decoding="async">
    </figure>

    <div class="detail-body">
      <h1>${esc(design.title)}</h1>
      <p class="lede">A ready-to-paste ${esc(design.category.toLowerCase())} screen prompt for
      ${design.platforms.includes('web') ? 'web' : 'mobile'} apps. Paste it into Lovable, v0,
      Cursor, Bolt or Claude and you get this interface back.</p>

      <ul class="tags">${tags}</ul>

      ${promptBlock(design)}

      ${
        pack
          ? `<p class="pack-note">Part of the <a href="/packs/${esc(pack.id)}/">${esc(pack.name)}</a>
             style pack — ${pack.screens.length} screens that share one palette and type scale,
             so a whole app stays consistent.</p>`
          : ''
      }

      <div class="howto">
        <h2>How to use it</h2>
        <ol>
          <li>Copy the prompt above.</li>
          <li>Paste it into your AI coding tool.</li>
          <li>Add your own product details — screen name, real copy, data fields.</li>
          <li>Attach the screenshot too. Vision models match a design far more closely when they can see it.</li>
        </ol>
      </div>
    </div>
  </div>

  ${
    related.length
      ? `<section class="related">
           <h2>More ${esc(design.category)} prompts</h2>
           <div class="grid">${related.map(designCard).join('\n')}</div>
         </section>`
      : ''
  }
</article>`;

  return layout({
    title,
    description,
    path: `/prompts/${design.slug}/`,
    image: design.imageUrl,
    jsonLd,
    body,
  });
}

export function packPage(pack) {
  const title = `${pack.name} — ${pack.screens.length} matching UI screens & prompts | ${SITE_NAME}`;
  const description = `${pack.name}: ${pack.screens.length} UI screens that share one palette, type scale and component set. Copy each prompt into Lovable, v0 or Cursor to build a consistent app.`;

  const jsonLd = JSON.stringify({
    '@context': 'https://schema.org',
    '@type': 'Collection',
    name: pack.name,
    description,
    url: siteUrl(`/packs/${pack.id}/`),
    hasPart: pack.screens.map((s) => ({
      '@type': 'CreativeWork',
      name: s.title,
      url: siteUrl(`/prompts/${s.slug}/`),
      image: s.imageUrl,
    })),
  });

  const body = `<article class="detail">
  <nav class="crumbs"><a href="/">Home</a> › <span>${esc(pack.name)}</span></nav>

  <header class="pack-head">
    <h1>${esc(pack.name)}</h1>
    <p class="lede">${pack.screens.length} screens in one consistent style. Same palette, same
    type scale, same components — so the app you build reads as one product instead of
    ${pack.screens.length} unrelated pages.</p>
    <ul class="tags">${pack.tags.map((t) => `<li>${esc(t)}</li>`).join('')}</ul>
  </header>

  <section class="pack-screens">
    ${pack.screens
      .map(
        (screen) => `<div class="pack-screen">
      <figure class="shot">
        <a href="/prompts/${esc(screen.slug)}/">
          <img src="${esc(screen.imageUrl)}" alt="${esc(screen.title)}"
               loading="lazy" decoding="async" width="720" height="1280">
        </a>
      </figure>
      <div class="pack-screen-body">
        <h2><a href="/prompts/${esc(screen.slug)}/">${esc(screen.title)}</a></h2>
        <p class="muted">${esc(screen.category)}</p>
        ${promptBlock(screen)}
      </div>
    </div>`
      )
      .join('\n')}
  </section>
</article>`;

  return layout({
    title,
    description,
    path: `/packs/${pack.id}/`,
    image: pack.cover.imageUrl,
    jsonLd,
    body,
  });
}

export function categoryPage(category, designs) {
  const slug = slugify(category);
  const title = `${category} UI design prompts for AI coding tools | ${SITE_NAME}`;
  const description = `${designs.length} free ${category.toLowerCase()} screen prompts you can paste into Lovable, v0, Cursor or Bolt. Each one comes with the rendered screenshot.`;

  const body = `<section class="listing">
  <nav class="crumbs"><a href="/">Home</a> › <span>${esc(category)}</span></nav>
  <h1>${esc(category)} UI prompts</h1>
  <p class="lede">${designs.length} ${esc(category.toLowerCase())} screens with copy-paste prompts.</p>
  <div class="grid">${designs.map(designCard).join('\n')}</div>
</section>`;

  return layout({ title, description, path: `/category/${slug}/`, body });
}

export function homePage({ packs, designs, categories, total }) {
  const title = `${SITE_NAME} — ${SITE_TAGLINE}`;
  const jsonLd = JSON.stringify({
    '@context': 'https://schema.org',
    '@type': 'WebSite',
    name: SITE_NAME,
    description: SITE_DESCRIPTION,
    url: siteUrl('/'),
  });

  const body = `<section class="hero">
  <h1>UI prompts that make AI-built apps look designed</h1>
  <p class="lede">${total} ready-to-paste prompts, each with the screen it produces. Copy one into
  Lovable, v0, Cursor, Bolt or Claude. Free, no sign-up.</p>
  ${CHROME_STORE_URL ? `<a class="cta big" href="${esc(CHROME_STORE_URL)}">Add to Chrome — it's free</a>` : ''}
</section>

<section class="filters" id="browse">
  <input type="search" id="q" placeholder="Search — dark dashboard, glass login, minimal chat…"
         autocomplete="off" aria-label="Search prompts">
  <div class="chips" id="chips">
    <button class="chip is-active" data-category="All">All</button>
    ${categories.map((c) => `<button class="chip" data-category="${esc(c)}">${esc(c)}</button>`).join('')}
  </div>
</section>

<section id="packs">
  <h2>Style packs</h2>
  <p class="muted">One style, ${packs[0]?.screens.length ?? 7} matching screens — build a whole app that looks consistent.</p>
  <div class="grid">${packs.map(packCard).join('\n')}</div>
</section>

<section id="single">
  <h2>Single screens</h2>
  <div class="grid" id="results">${designs.map(designCard).join('\n')}</div>
  <button type="button" id="more" class="more-btn">Show more</button>
</section>

<section class="browse-categories">
  <h2>Browse by screen</h2>
  <ul class="cat-links">
    ${categories.map((c) => `<li><a href="/category/${esc(slugify(c))}/">${esc(c)} prompts</a></li>`).join('')}
  </ul>
</section>`;

  return layout({
    title,
    description: SITE_DESCRIPTION,
    path: '/',
    jsonLd,
    body,
  });
}
