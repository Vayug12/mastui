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

      // ── Analytics: track view / copy events ──────────────────────────
      if (path === '/analytics/event' && request.method === 'POST') {
        const body = await request.json().catch(() => null);
        if (!body || !body.designId || !body.event || !['view', 'copy'].includes(body.event)) {
          return json({ error: 'Missing designId or invalid event (expected view|copy)' }, 400, corsHeaders);
        }
        const { designId, event, category } = body;
        const date = new Date().toISOString().slice(0, 10); // YYYY-MM-DD

        const stats = await loadJSON(env, 'analytics/stats.json', {});
        if (!stats[designId]) stats[designId] = { views: 0, copies: 0, category: category || 'Unknown' };
        if (category) stats[designId].category = category;
        if (event === 'view') stats[designId].views += 1;
        if (event === 'copy') stats[designId].copies += 1;

        // Daily breakdown
        const daily = await loadJSON(env, 'analytics/daily.json', {});
        const dayKey = `${date}:${designId}`;
        if (!daily[dayKey]) daily[dayKey] = { designId, date, views: 0, copies: 0, category: category || 'Unknown' };
        if (category) daily[dayKey].category = category;
        if (event === 'view') daily[dayKey].views += 1;
        if (event === 'copy') daily[dayKey].copies += 1;

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

      // ── Admin: aggregated analytics ──────────────────────────────────
      if (path === '/admin/analytics' && request.method === 'GET') {
        if (!isAdminAuthorized(request, env)) {
          return json({ error: 'Unauthorized' }, 401, corsHeaders);
        }
        const stats = await loadJSON(env, 'analytics/stats.json', {});
        const daily = await loadJSON(env, 'analytics/daily.json', {});

        // Category aggregation
        const byCategory = {};
        for (const [, data] of Object.entries(stats)) {
          const cat = data.category || 'Unknown';
          if (!byCategory[cat]) byCategory[cat] = { views: 0, copies: 0 };
          byCategory[cat].views += data.views;
          byCategory[cat].copies += data.copies;
        }

        return json({ designs: stats, byCategory, daily }, 200, corsHeaders);
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
