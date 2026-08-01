/**
 * MastUI API Worker.
 *
 * Routes:
 *   GET    /, /catalog                 serve the published catalog
 *   GET    /designs/:id.png            serve a design screenshot
 *   POST   /admin/upload               upload or replace a design
 *   DELETE /admin/designs/:id          permanently remove a design
 *   POST   /analytics/event            track view / copy events
 *   POST   /analytics/feedback         submit user feedback
 *   POST   /generate-prompt            build a prompt from a user's screenshot
 *   GET    /admin/analytics            aggregated analytics (admin)
 *   GET    /admin/feedback             all feedback entries (admin)
 */
export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const path = url.pathname;
    const origin = url.origin;

    const corsHeaders = {
      'Access-Control-Allow-Origin': env.CORS_ORIGIN || '*',
      'Access-Control-Allow-Methods': 'GET, POST, DELETE, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, X-Admin-Secret',
      'Access-Control-Max-Age': '86400',
    };

    if (request.method === 'OPTIONS') {
      return new Response(null, { headers: corsHeaders });
    }

    try {
      if (path === '/admin/upload' && request.method === 'POST') {
        if (!isAdminAuthorized(request, env)) {
          return json({ error: 'Unauthorized' }, 401, corsHeaders);
        }

        const formData = await request.formData();
        const imageFile = formData.get('image');
        const metadataRaw = formData.get('metadata');
        if (!imageFile || !metadataRaw) {
          return json({ error: 'Missing image or metadata' }, 400, corsHeaders);
        }

        let metadata;
        try {
          metadata = JSON.parse(metadataRaw);
        } catch {
          return json({ error: 'Invalid metadata JSON' }, 400, corsHeaders);
        }

        const { title, category, platforms, styleTags, prompt, id: providedId, packId, packName, order } = metadata;
        if (!title || !category || !prompt) {
          return json({ error: 'Missing required fields: title, category, prompt' }, 400, corsHeaders);
        }

        const normalizedPlatforms = normalizePlatforms(platforms);
        if (!normalizedPlatforms) {
          return json({ error: 'platforms must be a non-empty array containing only mobile or web' }, 400, corsHeaders);
        }

        const id = providedId || title
          .toLowerCase()
          .replace(/[^a-z0-9]+/g, '-')
          .replace(/^-|-$/g, '');
        if (!id) {
          return json({ error: 'Title must include at least one letter or number' }, 400, corsHeaders);
        }

        await env.mastui_catalog.put(`designs/${id}.png`, await imageFile.arrayBuffer(), {
          httpMetadata: { contentType: 'image/png' },
        });

        const catalog = await loadCatalog(env);
        const newEntry = {
          id,
          title,
          category,
          platforms: normalizedPlatforms,
          styleTags: Array.isArray(styleTags) ? styleTags : [],
          prompt,
          ...(packId ? { packId, packName: packName || packId, order: order ?? 0 } : {}),
        };

        // Re-uploading the same title replaces its old card rather than making
        // duplicate catalog entries that reference the same R2 image.
        const updatedCatalog = [...catalog.filter((item) => item.id !== id), newEntry];
        await saveCatalog(env, updatedCatalog);

        return json({ ...newEntry, imageUrl: `${origin}/designs/${id}.png` }, 200, corsHeaders);
      }

      const deleteMatch = path.match(/^\/admin\/designs\/([a-z0-9]+(?:-[a-z0-9]+)*)$/);
      if (deleteMatch && request.method === 'DELETE') {
        if (!isAdminAuthorized(request, env)) {
          return json({ error: 'Unauthorized' }, 401, corsHeaders);
        }

        const id = deleteMatch[1];
        const catalog = await loadCatalog(env);
        const remaining = catalog.filter((item) => item.id !== id);
        if (remaining.length === catalog.length) {
          return json({ error: 'Design not found' }, 404, corsHeaders);
        }

        // Update the visible catalog before the image delete. If the latter
        // needs a retry, users still cannot discover the rejected design.
        await saveCatalog(env, remaining);
        await env.mastui_catalog.delete(`designs/${id}.png`);

        return json({ deleted: true, id }, 200, corsHeaders);
      }

      // ── Analytics: track view / copy / download / dwell / search events ──
      if (path === '/analytics/event' && request.method === 'POST') {
        const body = await request.json().catch(() => null);
        const validEvents = ['view', 'copy', 'download', 'dwell', 'search'];
        if (!body || !body.designId || !body.event || !validEvents.includes(body.event)) {
          return json({ error: 'Missing designId or invalid event' }, 400, corsHeaders);
        }
        const { designId, event, category, seconds, query } = body;
        const date = new Date().toISOString().slice(0, 10); // YYYY-MM-DD

        // Handle search events separately — no per-design stats needed
        if (event === 'search' && query) {
          const searches = await loadJSON(env, 'analytics/searches.json', { queries: {}, daily: {} });
          const qKey = query.toLowerCase();
          if (!searches.queries[qKey]) searches.queries[qKey] = { query: qKey, count: 0 };
          searches.queries[qKey].count += 1;
          const dayKey = `${date}:${qKey}`;
          if (!searches.daily[dayKey]) searches.daily[dayKey] = { query: qKey, date, count: 0 };
          searches.daily[dayKey].count += 1;
          await saveJSON(env, 'analytics/searches.json', searches);
          return json({ ok: true }, 200, corsHeaders);
        }

        const stats = await loadJSON(env, 'analytics/stats.json', {});
        if (!stats[designId]) stats[designId] = { views: 0, copies: 0, downloads: 0, totalDwell: 0, dwellCount: 0, category: category || 'Unknown' };
        if (category) stats[designId].category = category;
        if (event === 'view') stats[designId].views += 1;
        if (event === 'copy') stats[designId].copies += 1;
        if (event === 'download') stats[designId].downloads = (stats[designId].downloads || 0) + 1;
        if (event === 'dwell' && typeof seconds === 'number' && seconds > 0) {
          stats[designId].totalDwell = (stats[designId].totalDwell || 0) + seconds;
          stats[designId].dwellCount = (stats[designId].dwellCount || 0) + 1;
        }

        // Daily breakdown
        const daily = await loadJSON(env, 'analytics/daily.json', {});
        const dayKey = `${date}:${designId}`;
        if (!daily[dayKey]) daily[dayKey] = { designId, date, views: 0, copies: 0, downloads: 0, totalDwell: 0, dwellCount: 0, category: category || 'Unknown' };
        if (category) daily[dayKey].category = category;
        if (event === 'view') daily[dayKey].views += 1;
        if (event === 'copy') daily[dayKey].copies += 1;
        if (event === 'download') daily[dayKey].downloads = (daily[dayKey].downloads || 0) + 1;
        if (event === 'dwell' && typeof seconds === 'number' && seconds > 0) {
          daily[dayKey].totalDwell = (daily[dayKey].totalDwell || 0) + seconds;
          daily[dayKey].dwellCount = (daily[dayKey].dwellCount || 0) + 1;
        }

        await saveJSON(env, 'analytics/stats.json', stats);
        await saveJSON(env, 'analytics/daily.json', daily);

        return json({ ok: true }, 200, corsHeaders);
      }

      // ── Analytics: submit feedback ───────────────────────────────────
      if (path === '/analytics/feedback' && request.method === 'POST') {
        const body = await request.json().catch(() => null);
        if (!body || !body.designId || !body.message) {
          return json({ error: 'Missing designId or message' }, 400, corsHeaders);
        }
        const entry = {
          id: crypto.randomUUID(),
          designId: body.designId,
          category: body.category || 'Unknown',
          rating: body.rating || null,
          message: body.message,
          timestamp: new Date().toISOString(),
        };

        const feedback = await loadJSON(env, 'analytics/feedback.json', []);
        feedback.unshift(entry); // newest first
        // Keep last 500 entries
        if (feedback.length > 500) feedback.length = 500;
        await saveJSON(env, 'analytics/feedback.json', feedback);

        return json({ ok: true, id: entry.id }, 200, corsHeaders);
      }

      // ── Generate a prompt from a user-uploaded UI screenshot ─────────
      if (path === '/generate-prompt' && request.method === 'POST') {
        return await handleGeneratePrompt(request, env, corsHeaders);
      }

      // ── Admin: aggregated analytics ──────────────────────────────────
      if (path === '/admin/analytics' && request.method === 'GET') {
        if (!isAdminAuthorized(request, env)) {
          return json({ error: 'Unauthorized' }, 401, corsHeaders);
        }
        const stats = await loadJSON(env, 'analytics/stats.json', {});
        const daily = await loadJSON(env, 'analytics/daily.json', {});
        const searchData = await loadJSON(env, 'analytics/searches.json', { queries: {}, daily: {} });

        // Category aggregation
        const byCategory = {};
        for (const [, data] of Object.entries(stats)) {
          const cat = data.category || 'Unknown';
          if (!byCategory[cat]) byCategory[cat] = { views: 0, copies: 0, downloads: 0, totalDwell: 0, dwellCount: 0 };
          byCategory[cat].views += data.views;
          byCategory[cat].copies += data.copies;
          byCategory[cat].downloads += data.downloads || 0;
          byCategory[cat].totalDwell += data.totalDwell || 0;
          byCategory[cat].dwellCount += data.dwellCount || 0;
        }

        // Top searches
        const topSearches = Object.values(searchData.queries || {})
          .sort((a, b) => b.count - a.count)
          .slice(0, 50);

        return json({ designs: stats, byCategory, daily, topSearches }, 200, corsHeaders);
      }

      // ── Admin: feedback list ─────────────────────────────────────────
      if (path === '/admin/feedback' && request.method === 'GET') {
        if (!isAdminAuthorized(request, env)) {
          return json({ error: 'Unauthorized' }, 401, corsHeaders);
        }
        const feedback = await loadJSON(env, 'analytics/feedback.json', []);
        return json(feedback, 200, corsHeaders);
      }

      if (path === '/' || path === '/catalog') {
        const catalog = await loadCatalog(env);
        const enriched = catalog.map((item) => ({
          ...item,
          // Older R2 entries predate this field, so keep them filterable.
          platforms: normalizePlatforms(item.platforms) ?? ['mobile'],
          imageUrl: `${origin}/designs/${item.id}.png`,
        }));

        return json(enriched, 200, {
          ...corsHeaders,
          // Do not serve stale catalog entries after an admin removes one.
          'Cache-Control': 'no-store',
        });
      }

      const designMatch = path.match(/^\/designs\/([a-z0-9]+(?:-[a-z0-9]+)*)\.png$/);
      if (designMatch && request.method === 'GET') {
        const obj = await env.mastui_catalog.get(`designs/${designMatch[1]}.png`);
        if (!obj) {
          return new Response('Design not found', { status: 404, headers: corsHeaders });
        }

        return new Response(obj.body, {
          headers: {
            ...corsHeaders,
            'Content-Type': 'image/png',
            // A deleted screenshot must not remain accessible from an old cache.
            'Cache-Control': 'no-store',
            'ETag': obj.httpEtag,
          },
        });
      }

      return new Response('Not found', { status: 404, headers: corsHeaders });
    } catch (err) {
      console.error('Worker error:', err);
      return json({ error: 'Internal error' }, 500, corsHeaders);
    }
  },
};

// ── Prompt generation from a user screenshot ───────────────────────────

const VISION_MODEL = '@cf/meta/llama-3.2-11b-vision-instruct';

/** Per-device daily caps. Workers AI's free Neuron allocation is shared by
 *  every user of the app, so no single device may drain it — not even a
 *  paying one, hence the Pro cap being high rather than absent. */
const FREE_DAILY_LIMIT = 4;
const PRO_DAILY_LIMIT = 50;

/** Must match `RevenueCatService.proEntitlementId` in the app. */
const PRO_ENTITLEMENT_ID = 'mast_ui_pro';

const MAX_UPLOAD_BYTES = 4 * 1024 * 1024;

const UPLOAD_EXTENSIONS = {
  'image/png': 'png',
  'image/jpeg': 'jpg',
  'image/webp': 'webp',
};

const PROMPT_OPENING = 'Act as a frontend developer with 15 years of experience.';

const PROMPT_CLOSING =
  'I want the exact same UI — aim for 95-99% visual similarity with the reference. ' +
  'Do not add, remove or restyle anything beyond what is described above. ' +
  'Use realistic content, not placeholder text. Keep animations smooth (200ms ease-out).';

async function handleGeneratePrompt(request, env, corsHeaders) {
  const deviceId = (request.headers.get('X-Device-Id') || '').trim();
  if (!/^[A-Za-z0-9_-]{8,64}$/.test(deviceId)) {
    return json({ error: 'Missing or malformed X-Device-Id' }, 400, corsHeaders);
  }

  const form = await request.formData().catch(() => null);
  const image = form?.get('image');
  if (!image || typeof image === 'string') {
    return json({ error: 'Missing image' }, 400, corsHeaders);
  }

  const extension = UPLOAD_EXTENSIONS[image.type];
  if (!extension) {
    return json({ error: 'Image must be a PNG, JPEG or WebP' }, 415, corsHeaders);
  }
  if (image.size > MAX_UPLOAD_BYTES) {
    return json({ error: 'Image must be under 4 MB' }, 413, corsHeaders);
  }

  const platform = form.get('platform') === 'web' ? 'web' : 'mobile';

  // Entitlement is checked against RevenueCat rather than trusted from a
  // client header, which anyone could set to unlock the higher cap.
  const isPro = await isProSubscriber(env, request.headers.get('X-RC-User-Id'));
  const limit = isPro ? PRO_DAILY_LIMIT : FREE_DAILY_LIMIT;

  // Reserved up front so a burst of parallel requests cannot each read the
  // same pre-increment count and all pass the check.
  const reservation = await reserveDailyQuota(env, deviceId, limit);
  if (!reservation.allowed) {
    return json(
      {
        error: isPro
          ? `Daily limit reached — ${limit} prompts per day.`
          : `You've used your ${limit} free prompts for today.`,
        remaining: 0,
        limit,
        isPro,
        // Tells the app whether upgrading actually helps, so it only offers
        // the paywall when it does.
        upgradeAvailable: !isPro,
        resetsAt: nextUtcMidnight(),
      },
      429,
      corsHeaders,
    );
  }

  const bytes = await image.arrayBuffer();

  let raw;
  try {
    const result = await env.AI.run(VISION_MODEL, {
      messages: visionMessages(platform),
      image: `data:${image.type};base64,${toBase64(bytes)}`,
      max_tokens: 700,
      temperature: 0.3,
    });
    raw = (result?.response || '').trim();
  } catch (err) {
    console.error('generate-prompt failed:', err);
    // The device got nothing, so its own allowance should not be spent.
    await releaseDailyQuota(env, deviceId);

    // A drained account allocation lasts until 00:00 UTC, so it must not be
    // reported as the transient 503 that clients retry against.
    if (isAllocationExhausted(err)) {
      return json(
        {
          error: "The app's free AI budget for today is used up. It resets at midnight UTC.",
          remaining: 0,
          limit,
          isPro,
          // Account-wide exhaustion — buying Pro would not unblock this.
          upgradeAvailable: false,
          resetsAt: nextUtcMidnight(),
        },
        429,
        corsHeaders,
      );
    }

    return json(
      { error: 'Prompt generation is busy right now. Please try again in a minute.' },
      503,
      corsHeaders,
    );
  }

  if (!raw) {
    await releaseDailyQuota(env, deviceId);
    return json({ error: 'Could not read that screenshot. Try a clearer one.' }, 422, corsHeaders);
  }

  const fields = parseDescription(raw);
  const filledCount = Object.values(fields).filter(Boolean).length;
  if (filledCount < 2) {
    await releaseDailyQuota(env, deviceId);
    return json(
      { error: 'Could not detect a UI in this image. Try a clearer screenshot.' },
      422,
      corsHeaders,
    );
  }

  // Store only metadata — the image was already consumed by the model.
  try {
    await env.mastui_catalog.put(
      `uploads/${today()}/${deviceId}-${crypto.randomUUID()}.json`,
      JSON.stringify({
        deviceId,
        platform,
        styleName: fields.STYLE_NAME || null,
        timestamp: new Date().toISOString(),
        fieldsCount: filledCount,
      }),
      { httpMetadata: { contentType: 'application/json' } },
    );
  } catch (err) {
    console.error('metadata archive failed:', err);
  }

  return json(
    {
      prompt: buildPrompt(fields, raw, platform),
      styleName: fields.STYLE_NAME || null,
      remaining: reservation.remaining,
      limit,
      isPro,
      resetsAt: nextUtcMidnight(),
    },
    200,
    corsHeaders,
  );
}

/** Tells "the account's 10,000 free Neurons are gone" (codes 3036 / 4006, and
 *  retrying only wastes requests) apart from "no data centre had capacity"
 *  (code 3040, which usually clears within seconds). */
function isAllocationExhausted(err) {
  const message = String(err?.message ?? err);
  return /\b(3036|4006)\b/.test(message) || /daily free allocation|neuron/i.test(message);
}

function visionMessages(platform) {
  const target = platform === 'web' ? 'web app' : 'mobile app';
  return [
    {
      role: 'system',
      content:
        'You read UI screenshots and describe them so that another AI can rebuild the screen ' +
        'from your description alone. Report only what is actually visible — never invent ' +
        'components that are not in the image. Reply with the six labelled lines you are asked ' +
        'for and nothing before or after them.',
    },
    {
      role: 'user',
      content: `Analyse this ${target} UI screenshot and reply in exactly this format:

SCREEN: the screen's purpose in two or three words, such as Login or Product detail
STRUCTURE: one sentence listing every visible element from top to bottom, in order
STYLE_NAME: two or three words naming the visual style, such as Soft Neumorphic
STYLE: two or three sentences on typography, corner radii, borders, shadows, icon style and spacing
PALETTE_NAME: two or three words naming the colour scheme, such as Warm Sand
PALETTE: the background, surface, text and accent colours as hex codes, saying what each is used for`,
    },
  ];
}

const DESCRIPTION_LABELS = [
  'SCREEN',
  'STRUCTURE',
  'STYLE_NAME',
  'STYLE',
  'PALETTE_NAME',
  'PALETTE',
];

/** Pulls the labelled sections out of the model's reply. Tolerates markdown
 *  emphasis and values that wrap onto following lines. */
function parseDescription(raw) {
  const fields = {};
  let current = null;

  for (const line of raw.split('\n')) {
    const match = line.match(/^\s*\**\s*([A-Z_]{5,13})\s*\**\s*:\s*(.*)$/);
    if (match && DESCRIPTION_LABELS.includes(match[1])) {
      current = match[1];
      fields[current] = cleanValue(match[2]);
    } else if (current && line.trim()) {
      fields[current] = cleanValue(`${fields[current]} ${line}`);
    }
  }
  return fields;
}

/** Small models sprinkle markdown emphasis through both labels and values. */
function cleanValue(value) {
  return value.replace(/\*+/g, ' ').replace(/\s+/g, ' ').trim();
}

/** Reshapes a sentence to sit mid-clause: no capitalised opening to read as a
 *  new sentence, no full stop to collide with the text that follows it. */
function inlineClause(text) {
  const trimmed = text.replace(/\s*\.\s*$/, '');
  if (!trimmed) return trimmed;

  // An all-caps opening word is an acronym such as "OTP field" — leave it be.
  const [firstWord] = trimmed.split(/\s+/, 1);
  const isAcronym = firstWord.length > 1 && firstWord === firstWord.toUpperCase();

  return isAcronym ? trimmed : trimmed[0].toLowerCase() + trimmed.slice(1);
}

/** Wraps the model's observations in the same scaffold the curated catalog
 *  prompts use, so generated and hand-written prompts read alike. */
function buildPrompt(fields, raw, platform) {
  const target = platform === 'web' ? 'web app' : 'mobile app';
  const { STRUCTURE: structure, STYLE: style, PALETTE: palette } = fields;

  // A small vision model sometimes ignores the format. Passing its prose
  // through beats emitting a template with empty sections.
  if (!structure && !style && !palette) {
    return `${PROMPT_OPENING}\n\nDesign a ${target} screen matching this reference:\n\n${raw}\n\n${PROMPT_CLOSING}`;
  }

  const screen = fields.SCREEN ? `${fields.SCREEN.toLowerCase()} screen` : 'screen';
  const layout = structure
    ? inlineClause(structure)
    : 'the layout shown in the reference image';
  const sections = [
    PROMPT_OPENING,
    `Design a ${screen} with ${layout} for a ${target}.`,
  ];
  if (style) {
    sections.push(`Visual style${fields.STYLE_NAME ? ` — ${fields.STYLE_NAME}` : ''}:\n${style}`);
  }
  if (palette) {
    sections.push(`Color palette${fields.PALETTE_NAME ? ` — ${fields.PALETTE_NAME}` : ''}:\n${palette}`);
  }
  sections.push(PROMPT_CLOSING);

  return sections.join('\n\n');
}

/** One small object per device per day, so devices never contend over a
 *  shared counter the way a single rollup JSON would. */
function quotaKey(deviceId) {
  return `usage/${today()}/${deviceId}.json`;
}

async function reserveDailyQuota(env, deviceId, limit) {
  const key = quotaKey(deviceId);
  const used = (await loadJSON(env, key, { count: 0 })).count || 0;
  if (used >= limit) return { allowed: false, remaining: 0 };

  await saveJSON(env, key, { count: used + 1 });
  return { allowed: true, remaining: limit - used - 1 };
}

const PRO_CACHE_SECONDS = 60 * 60;

/** Asks RevenueCat whether this app user holds the Pro entitlement.
 *
 *  Only a *positive* answer is cached. Caching "not Pro" would leave someone
 *  who just paid stuck on the free cap until the entry expired — which is
 *  exactly the moment they upgraded to escape. A free user costs at most a
 *  handful of lookups a day anyway, since their cap is 4.
 *
 *  Without `REVENUECAT_SECRET_KEY` set, everyone is treated as free — failing
 *  closed is right here, since the alternative hands out the Pro cap for free.
 */
async function isProSubscriber(env, appUserId) {
  const secret = env.REVENUECAT_SECRET_KEY;
  if (!secret || !appUserId) return false;
  if (!/^[A-Za-z0-9_.:$+-]{1,128}$/.test(appUserId)) return false;

  const cacheKey = `entitlements/${encodeURIComponent(appUserId)}.json`;
  const cached = await loadJSON(env, cacheKey, null);
  if (cached?.isPro === true &&
      Date.now() - cached.checkedAt < PRO_CACHE_SECONDS * 1000) {
    return true;
  }

  let isPro = false;
  try {
    const res = await fetch(
      `https://api.revenuecat.com/v1/subscribers/${encodeURIComponent(appUserId)}`,
      { headers: { Authorization: `Bearer ${secret}` } },
    );
    if (res.ok) {
      const body = await res.json();
      const entitlement = body?.subscriber?.entitlements?.[PRO_ENTITLEMENT_ID];
      // A null `expires_date` means lifetime, not expired.
      isPro =
        !!entitlement &&
        (entitlement.expires_date == null ||
          new Date(entitlement.expires_date).getTime() > Date.now());
    } else if (res.status !== 404) {
      // 404 is a user RevenueCat has never seen — a genuine "not Pro".
      console.error('RevenueCat lookup failed:', res.status);
      return cached?.isPro === true; // Fall back to the stale answer, if any.
    }
  } catch (err) {
    console.error('RevenueCat lookup error:', err);
    return cached?.isPro === true;
  }

  if (isPro) await saveJSON(env, cacheKey, { isPro: true, checkedAt: Date.now() });
  return isPro;
}

async function releaseDailyQuota(env, deviceId) {
  const key = quotaKey(deviceId);
  const used = (await loadJSON(env, key, { count: 0 })).count || 0;
  if (used > 0) await saveJSON(env, key, { count: used - 1 });
}

function today() {
  return new Date().toISOString().slice(0, 10);
}

/** Workers AI quotas reset at 00:00 UTC, so the client can say when. */
function nextUtcMidnight() {
  const reset = new Date();
  reset.setUTCHours(24, 0, 0, 0);
  return reset.toISOString();
}

/** Chunked because spreading a multi-megabyte array into fromCharCode
 *  overflows the call stack. */
function toBase64(buffer) {
  const bytes = new Uint8Array(buffer);
  let binary = '';
  for (let i = 0; i < bytes.length; i += 0x8000) {
    binary += String.fromCharCode(...bytes.subarray(i, i + 0x8000));
  }
  return btoa(binary);
}

async function loadCatalog(env) {
  const object = await env.mastui_catalog.get('catalog.json');
  if (!object) return [];

  const catalog = await object.json();
  if (!Array.isArray(catalog)) {
    throw new Error('catalog.json must contain an array');
  }
  return catalog;
}

async function saveCatalog(env, catalog) {
  await env.mastui_catalog.put('catalog.json', JSON.stringify(catalog, null, 2), {
    httpMetadata: { contentType: 'application/json' },
  });
}

/** Returns a canonical platform list, or null for an invalid supplied value. */
function normalizePlatforms(value) {
  if (value == null) return ['mobile'];
  if (!Array.isArray(value) || value.length === 0) return null;

  const platforms = [...new Set(value)];
  if (!platforms.every((platform) => platform === 'mobile' || platform === 'web')) {
    return null;
  }
  return platforms;
}

/** Compare admin secrets without leaking matching characters through timing. */
function isAdminAuthorized(request, env) {
  if (!env.ADMIN_SECRET) return false;

  const encoder = new TextEncoder();
  const received = encoder.encode(request.headers.get('X-Admin-Secret') || '');
  const expected = encoder.encode(env.ADMIN_SECRET);
  const sameLength = received.byteLength === expected.byteLength;

  return sameLength
    ? crypto.subtle.timingSafeEqual(received, expected)
    : !crypto.subtle.timingSafeEqual(received, received);
}

async function loadJSON(env, key, fallback) {
  const obj = await env.mastui_catalog.get(key);
  if (!obj) return fallback;
  try {
    const data = await obj.json();
    return data ?? fallback;
  } catch {
    return fallback;
  }
}

async function saveJSON(env, key, data) {
  await env.mastui_catalog.put(key, JSON.stringify(data), {
    httpMetadata: { contentType: 'application/json' },
  });
}

function json(data, status, headers = {}) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...headers, 'Content-Type': 'application/json' },
  });
}
