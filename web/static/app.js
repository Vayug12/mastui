/**
 * Site behaviour: copy buttons everywhere, search + filtering on the home page.
 *
 * Every page works without this file — it only adds convenience on top of
 * server-rendered HTML. The API host comes from the <meta name="mastui:api">
 * tag the build injects, so no URL is hardcoded here.
 */

const API = document.querySelector('meta[name="mastui:api"]')?.content ?? '';

/** Fire-and-forget analytics. A failed beacon must never break the page. */
function track(designId, event, category) {
  if (!API || !designId) return;
  fetch(`${API}/analytics/event`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ designId, event, category }),
    keepalive: true,
  }).catch(() => {});
}

// ── Copy buttons ────────────────────────────────────────────────────────

document.addEventListener('click', async (e) => {
  const btn = e.target.closest('[data-copy]');
  if (!btn) return;

  const block = btn.closest('.prompt');
  const text = block?.querySelector('[data-prompt-text]')?.textContent;
  if (!text) return;

  try {
    await navigator.clipboard.writeText(text);
  } catch {
    // Older browsers and non-secure contexts have no clipboard API.
    const ta = document.createElement('textarea');
    ta.value = text;
    ta.style.position = 'fixed';
    ta.style.opacity = '0';
    document.body.append(ta);
    ta.select();
    document.execCommand('copy');
    ta.remove();
  }

  const original = btn.textContent;
  btn.textContent = 'Copied ✓';
  btn.classList.add('is-done');
  setTimeout(() => {
    btn.textContent = original;
    btn.classList.remove('is-done');
  }, 1600);

  track(block.dataset.designId, 'copy', block.dataset.category);
});

// A design page view is worth counting; a grid impression is not.
const detailPrompt = document.querySelector('.detail .prompt');
if (detailPrompt) {
  track(detailPrompt.dataset.designId, 'view', detailPrompt.dataset.category);
}

// ── Home: search + category filter ──────────────────────────────────────

const search = document.getElementById('q');
const results = document.getElementById('results');

if (search && results) {
  const chips = [...document.querySelectorAll('.chip')];
  const moreBtn = document.getElementById('more');
  const packsSection = document.getElementById('packs');
  const singlesHeading = document.querySelector('#single h2');
  const PAGE = 48;

  let index = null;
  let matches = [];
  let shown = 0;
  let category = 'All';

  /** Loaded once, on first interaction — the home page must not wait for it. */
  async function ensureIndex() {
    if (index) return index;
    const res = await fetch('/index.json');
    index = await res.json();
    return index;
  }

  function tile(d) {
    return `<a class="card" href="/prompts/${d.i}/">
  <img src="${d.u}" alt="${d.t}" loading="lazy" decoding="async" width="360" height="640">
  <span class="card-meta"><strong>${d.t}</strong><em>${d.c}</em></span>
</a>`;
  }

  function render(reset) {
    if (reset) {
      shown = 0;
      results.innerHTML = '';
    }
    const next = matches.slice(shown, shown + PAGE);
    results.insertAdjacentHTML('beforeend', next.map(tile).join(''));
    shown += next.length;
    moreBtn.hidden = shown >= matches.length;

    if (singlesHeading) {
      singlesHeading.textContent =
        matches.length === index.length ? 'Single screens' : `${matches.length} results`;
    }
  }

  async function apply() {
    const q = search.value.trim().toLowerCase();
    const all = await ensureIndex();

    // With no query and no category the page falls back to its static markup,
    // which is what search engines and first-time visitors should see.
    if (!q && category === 'All') {
      matches = all.filter((d) => !d.k);
      if (packsSection) packsSection.hidden = false;
      render(true);
      return;
    }

    if (packsSection) packsSection.hidden = Boolean(q);

    matches = all.filter((d) => {
      if (category !== 'All' && d.c !== category) return false;
      if (!q) return true;
      return (
        d.t.toLowerCase().includes(q) ||
        d.c.toLowerCase().includes(q) ||
        d.g.some((t) => t.toLowerCase().includes(q)) ||
        d.p.some((p) => p.includes(q))
      );
    });
    render(true);
  }

  let debounce;
  search.addEventListener('input', () => {
    clearTimeout(debounce);
    debounce = setTimeout(apply, 180);
  });

  chips.forEach((chip) => {
    chip.addEventListener('click', () => {
      chips.forEach((c) => c.classList.toggle('is-active', c === chip));
      category = chip.dataset.category;
      apply();
    });
  });

  moreBtn?.addEventListener('click', () => render(false));
}
