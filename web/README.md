# MastUI web + extension

Two surfaces built from one catalog and one config file.

- **`web/`** — a static site generator. Renders one page per design, per style
  pack and per category, so every prompt has its own crawlable URL.
- **`extension/`** — a Chrome side panel that browses the same catalog and
  pastes a prompt straight into Lovable, v0, Bolt, Cursor or Claude.

Both read `shared/config.js`. Nothing else in either surface hardcodes a host.

---

## Changing the domain

Edit **one line** in [`shared/config.js`](../shared/config.js):

```js
export const SITE_URL = env.SITE_URL || 'https://mastui.pages.dev';
```

Then:

```bash
npm run build   # regenerates canonical tags, og:url, sitemap.xml, robots.txt
npm run pack    # regenerates extension/config.js and the store zip
```

That is the whole migration. Pages link to each other with relative paths, so
the site itself never needs to know where it is hosted.

---

## Build the site

```bash
cd web
npm run build          # fetch the live catalog from the Worker
npm run build:local    # or build offline from ../assets/catalog.json
npm run preview        # serve dist/ at http://localhost:3000
```

Output lands in `web/dist/` (gitignored).

### Deploy to Cloudflare Pages

1. Push this repo to GitHub.
2. Cloudflare dashboard → **Workers & Pages** → **Create** → **Pages** →
   **Connect to Git**.
3. Build settings:
   - Build command: `cd web && npm run build`
   - Build output directory: `web/dist`
   - Node version: 18 or higher
4. Deploy. The site goes live at `<project>.pages.dev`.

**Adding a custom domain later:** Pages → your project → **Custom domains** →
add it. Cloudflare handles DNS and the certificate. Then change `SITE_URL`,
rebuild, and add a redirect from the old host so existing links keep working.

---

## The extension

### Test it locally

```bash
npm run pack    # generates extension/config.js + the icon
```

Then `chrome://extensions` → enable **Developer mode** → **Load unpacked** →
select the `extension/` folder. Click the toolbar icon to open the panel.

### Publish it

1. Register once at
   [chrome.google.com/webstore/devconsole](https://chrome.google.com/webstore/devconsole)
   — a one-time $5 fee.
2. `npm run pack` → upload `web/dist/mastui-extension.zip`.
3. Fill in the listing: 128×128 icon, at least one 1280×800 screenshot, a
   description, and a privacy policy URL (host `docs/privacy-policy.md`).
4. Justify each permission in one line. The manifest asks only for what it
   needs, which keeps review short:

   | Permission | Why |
   | --- | --- |
   | `sidePanel` | the entire UI |
   | `activeTab` | capture a screenshot of the tab the user asked to capture |
   | `scripting` | paste the chosen prompt into the page's own input |
   | `storage` | cache the catalog and the anonymous device id |
   | `contextMenus` | the right-click capture entry point |

   Host permissions are limited to the Worker plus the five AI tools the panel
   can paste into. **Do not widen these to `<all_urls>`** — it turns a
   two-day review into a two-week one.

5. Once approved, paste the listing URL into `CHROME_STORE_URL` in
   `shared/config.js` and rebuild. The site's install buttons appear on their
   own — they stay hidden while that constant is empty.

---

## Files that matter

| File | Role |
| --- | --- |
| `shared/config.js` | every URL the project points at |
| `web/build.js` | fetches the catalog, writes `dist/` |
| `web/templates.js` | page HTML, meta tags, structured data |
| `web/static/app.js` | copy buttons, home search |
| `web/pack-extension.js` | syncs config into the extension, zips it |
| `extension/background.js` | tab capture and prompt injection |
| `extension/sidepanel.js` | the panel's three views |
| `extension/config.js` | **generated** — never edit |
