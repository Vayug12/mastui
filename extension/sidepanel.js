/**
 * Side panel controller.
 *
 * Three views live in one document — browse, one design, and screenshot to
 * prompt — because a panel this narrow should never make the user navigate.
 */

import { API_URL, SITE_URL } from './config.js';

const PAGE = 24;
/** The catalog changes at most daily, so a stale read costs nothing. */
const CATALOG_TTL_MS = 6 * 60 * 60 * 1000;

const $ = (id) => document.getElementById(id);

const views = {
  browse: $('browse-view'),
  detail: $('detail-view'),
  capture: $('capture-view'),
};

function show(name) {
  for (const [key, el] of Object.entries(views)) el.hidden = key !== name;
}

function setStatus(el, message, isError = false) {
  el.textContent = message;
  el.classList.toggle('error', isError);
}

async function copy(text) {
  await navigator.clipboard.writeText(text);
}

/** Asks the service worker to type a prompt into the page in front of the user. */
async function insertIntoPage(prompt, statusEl) {
  setStatus(statusEl, 'Inserting…');
  const res = await chrome.runtime.sendMessage({ type: 'insert', prompt });
  if (res?.error) {
    setStatus(statusEl, `${res.error} Copy it instead.`, true);
    return;
  }
  setStatus(statusEl, 'Inserted into the page ✓');
}

// ── Catalog ─────────────────────────────────────────────────────────────

let catalog = [];
let matches = [];
let shown = 0;
let category = 'All';

async function loadCatalog() {
  const { catalogCache } = await chrome.storage.local.get('catalogCache');
  if (catalogCache && Date.now() - catalogCache.at < CATALOG_TTL_MS) {
    return catalogCache.data;
  }

  const res = await fetch(`${API_URL}/catalog`);
  if (!res.ok) throw new Error(`Could not load designs (${res.status})`);
  const data = await res.json();
  await chrome.storage.local.set({ catalogCache: { at: Date.now(), data } });
  return data;
}

function tile(design) {
  const el = document.createElement('div');
  el.className = 'card';
  el.innerHTML = `<img src="${design.imageUrl}" alt="" loading="lazy">
    <span>${design.title}</span>`;
  el.addEventListener('click', () => openDetail(design));
  return el;
}

function render(reset) {
  const results = $('results');
  if (reset) {
    results.innerHTML = '';
    shown = 0;
  }

  const next = matches.slice(shown, shown + PAGE);
  for (const design of next) results.append(tile(design));
  shown += next.length;

  $('more').hidden = shown >= matches.length;
  setStatus(
    $('status'),
    matches.length ? `${matches.length} designs` : 'No matches — try another word.'
  );
}

function applyFilters() {
  const q = $('q').value.trim().toLowerCase();
  matches = catalog.filter((d) => {
    if (category !== 'All' && d.category !== category) return false;
    if (!q) return true;
    return (
      d.title.toLowerCase().includes(q) ||
      d.category.toLowerCase().includes(q) ||
      (d.styleTags || []).some((t) => t.toLowerCase().includes(q))
    );
  });
  render(true);
}

function buildChips() {
  const categories = ['All', ...new Set(catalog.map((d) => d.category))].sort(
    (a, b) => (a === 'All' ? -1 : b === 'All' ? 1 : a.localeCompare(b))
  );

  const container = $('chips');
  container.innerHTML = '';
  for (const name of categories) {
    const chip = document.createElement('button');
    chip.className = `chip${name === 'All' ? ' is-active' : ''}`;
    chip.textContent = name;
    chip.addEventListener('click', () => {
      container
        .querySelectorAll('.chip')
        .forEach((c) => c.classList.toggle('is-active', c === chip));
      category = name;
      applyFilters();
    });
    container.append(chip);
  }
}

// ── Detail view ─────────────────────────────────────────────────────────

let current = null;

function openDetail(design) {
  current = design;
  $('detail-image').src = design.imageUrl;
  $('detail-title').textContent = design.title;
  $('detail-meta').textContent = [design.category, ...(design.styleTags || [])].join(' · ');
  $('detail-prompt').textContent = design.prompt;
  setStatus($('detail-status'), '');
  show('detail');
  track(design.id, 'view', design.category);
}

$('back').addEventListener('click', () => show('browse'));

$('copy').addEventListener('click', async () => {
  await copy(current.prompt);
  setStatus($('detail-status'), 'Copied ✓');
  track(current.id, 'copy', current.category);
});

$('insert').addEventListener('click', async () => {
  await insertIntoPage(current.prompt, $('detail-status'));
  track(current.id, 'copy', current.category);
});

function track(designId, event, category) {
  fetch(`${API_URL}/analytics/event`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ designId, event, category }),
  }).catch(() => {});
}

// ── Screenshot → prompt ─────────────────────────────────────────────────

let captureDataUrl = null;
let generated = null;
let platform = 'web';

/** Stable per-install id. The Worker meters its daily allowance against it. */
async function deviceId() {
  const { deviceId } = await chrome.storage.local.get('deviceId');
  if (deviceId) return deviceId;
  // The Worker validates /^[A-Za-z0-9_-]{8,64}$/, hence stripping the dashes.
  const id = crypto.randomUUID().replace(/-/g, '');
  await chrome.storage.local.set({ deviceId: id });
  return id;
}

function setCapture(dataUrl) {
  captureDataUrl = dataUrl;
  const img = $('capture-image');
  img.src = dataUrl;
  img.hidden = false;
  $('generate').disabled = false;
  $('capture-prompt').hidden = true;
  $('capture-actions').hidden = true;
  setStatus($('capture-status'), '');
}

async function captureTab() {
  setStatus($('capture-status'), 'Capturing…');
  const res = await chrome.runtime.sendMessage({ type: 'capture' });
  if (res?.error) {
    setStatus(
      $('capture-status'),
      'Chrome blocked the capture. Right-click the page → "Capture this page for a MastUI prompt", or paste an image with Ctrl+V.',
      true
    );
    return;
  }
  setCapture(res.dataUrl);
}

$('capture').addEventListener('click', () => {
  show('capture');
  captureTab();
});
$('capture-again').addEventListener('click', captureTab);
$('capture-back').addEventListener('click', () => show('browse'));

$('platform-chips').addEventListener('click', (e) => {
  const chip = e.target.closest('.chip');
  if (!chip) return;
  $('platform-chips')
    .querySelectorAll('.chip')
    .forEach((c) => c.classList.toggle('is-active', c === chip));
  platform = chip.dataset.platform;
});

// Pasting a screenshot is the fallback whenever tab capture is unavailable —
// on chrome:// pages, the Web Store, and PDF viewers.
document.addEventListener('paste', (e) => {
  const item = [...(e.clipboardData?.items || [])].find((i) =>
    i.type.startsWith('image/')
  );
  if (!item) return;

  const reader = new FileReader();
  reader.onload = () => {
    show('capture');
    setCapture(reader.result);
  };
  reader.readAsDataURL(item.getAsFile());
});

$('generate').addEventListener('click', async () => {
  if (!captureDataUrl) return;

  const btn = $('generate');
  btn.disabled = true;
  setStatus($('capture-status'), 'Reading screenshot…');

  try {
    const blob = await (await fetch(captureDataUrl)).blob();
    const form = new FormData();
    form.append('image', blob, 'capture.png');
    form.append('platform', platform);

    const res = await fetch(`${API_URL}/generate-prompt`, {
      method: 'POST',
      headers: { 'X-Device-Id': await deviceId() },
      body: form,
    });
    const body = await res.json().catch(() => null);

    if (!res.ok) {
      throw new Error(body?.error || 'Could not generate a prompt right now.');
    }

    generated = body.prompt;
    $('capture-prompt').textContent = generated;
    $('capture-prompt').hidden = false;
    $('capture-actions').hidden = false;
    setStatus(
      $('capture-status'),
      body.isPro ? 'Pro — unlimited' : `${body.remaining} free generations left today`
    );
  } catch (err) {
    setStatus($('capture-status'), err.message, true);
  } finally {
    btn.disabled = false;
  }
});

$('capture-copy').addEventListener('click', async () => {
  await copy(generated);
  setStatus($('capture-status'), 'Copied ✓');
});

$('capture-insert').addEventListener('click', () =>
  insertIntoPage(generated, $('capture-status'))
);

// ── Boot ────────────────────────────────────────────────────────────────

$('q').addEventListener('input', () => {
  clearTimeout($('q').dataset.timer);
  $('q').dataset.timer = setTimeout(applyFilters, 160);
});
$('more').addEventListener('click', () => render(false));

// Both surfaces read the same constant, so a domain change lands in one edit.
$('site-link').href = SITE_URL;

(async () => {
  try {
    catalog = await loadCatalog();
    buildChips();
    applyFilters();
  } catch (err) {
    setStatus($('status'), `${err.message} — check your connection.`, true);
  }

  // A context-menu capture opens the panel and leaves the shot waiting here.
  const { pendingCapture } = await chrome.storage.session.get('pendingCapture');
  if (pendingCapture?.dataUrl) {
    show('capture');
    setCapture(pendingCapture.dataUrl);
    await chrome.storage.session.remove('pendingCapture');
  }
})();
