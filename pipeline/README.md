# MastUI content pipeline

Turns prompt templates into the app's catalog: **prompt → HTML (Claude / Codex / OpenCode) → mobile screenshot (Playwright) → metadata**.

## Style packs (the product)

The app browses **style packs**: one visual style rendered as 7 foundation screens
(Login, Sign Up, Home, Profile, Settings, Search, Notifications) that share a single
palette and design system, so they read as one real app. Consistency comes from two
mechanisms: every pack pins ONE palette, and the pack's first screen (the anchor) is
passed as a reference into the prompts of the other six.

```sh
npm run packs -- --plan                        # list all packs (free)
node run.js --packs --style soft-dark          # generate one pack (7 screens)
node run.js --packs --limit 2                  # first 2 packs
node run.js --packs                            # all 15 packs (105 screens)
```

`--limit` counts packs here, not screens. Screens inside a pack generate sequentially
(the anchor must finish first); packs run in parallel.

HTML is only the intermediate render format — users never see it. They see the PNG plus the copyable prompt,
which describes the design in framework-agnostic terms so it works in v0, Lovable, Cursor or Claude.

## Setup

```sh
npm install
npx playwright install chromium
export ANTHROPIC_API_KEY=sk-ant-...     # PowerShell: $env:ANTHROPIC_API_KEY = "sk-ant-..."
```

## Use (legacy single-screen catalog)

```sh
npm run plan                  # print every prompt the catalog would produce (no API calls, free)
node run.js --limit 5         # generate + screenshot 5 screens — do this first
node run.js                   # the full catalog
node run.js --category Login  # one category
node run.js --style soft-dark # one style
node run.js --no-shoot        # HTML only, skip screenshots
node run.js --force           # regenerate items that already exist
npm run shoot                 # re-screenshot existing HTML without re-generating
```

### Choosing the generator

Default is Claude via the API (`ANTHROPIC_API_KEY`). No API key? `claude-code` runs
headless Claude Code (`claude -p`) on your Claude subscription. Codex and OpenCode
CLIs likewise use their own login (`codex login` / `opencode auth login`):

```sh
npm run generate:cc           # Claude subscription, no API key (claude -p)
npm run generate:codex        # or: node run.js --provider codex [--limit 5 …]
npm run generate:opencode     # or: node run.js --provider opencode
export MASTUI_PROVIDER=claude-code   # or set the default via env instead of the flag
```

Output per screen: `out/<id>/design.html`, `out/<id>/image.png`, `out/<id>/metadata.json`,
plus a combined `out/catalog.json` for the Cloudflare upload step.

Every catalog item also has `platforms`, currently `['mobile']` for generated
screens. Use `['web']` or `['mobile', 'web']` when adding a template that is
authored for those targets; this value is preserved through the app and admin.

## Getting screens into the app

Nothing reaches the app until you sync. The full loop:

```sh
node shoot.js        # design.html -> image.png
node catalog.js      # metadata.json + catalog.json, and the palette check
node sync-to-app.js  # copy into ../assets/, which the app reads
cd .. && flutter run
```

`sync-to-app.js` bundles the screens into the APK — good for local preview and as an
offline starter set, but adding screens this way needs a Play Store update. Once the
Cloudflare Worker + R2 are live, new screens arrive over the air and the bundle stops
being the only source.

## Authoring screens without an API key

`design.html` doesn't have to come from `generate.js`. Anything written to
`out/<id>/design.html` works, as long as `<id>` matches a template id (`npm run plan`
lists them) — `catalog.js` finds its prompt, tags and palette automatically. This is
the no-API-key path: Claude Code writes the HTML, then `shoot` → `catalog` → `sync`.

**The palette check matters here.** `catalog.js` exits 1 if a design's colors belong to a
different palette than its prompt promises — a user copying that prompt would never
reproduce what they saw. Fix the HTML rather than silencing it.

## Growing the catalog

Everything comes from `templates.js`:

- **`CATEGORIES`** — add a screen to an existing category, or a whole new category. Each screen needs a
  one-line `brief` describing its content.
- **`STYLES`** — add a visual language. Each style multiplies across *every* screen.

Current: 8 categories × 19 screens × 6 styles = **114 items**. One new style → +19 items. One new screen → +6.

## Knobs

| Env var | Default | Notes |
|---|---|---|
| `MASTUI_CONCURRENCY` | `3` | Parallel API requests. Raise if you aren't rate-limited. |
| `MASTUI_EFFORT` | `high` | `low`/`medium`/`high`/`xhigh`/`max` — lower is cheaper and faster, higher is more polished. Claude only. |
| `MASTUI_PROVIDER` | `claude` | `claude` / `claude-code` / `codex` / `opencode` — default generator when `--provider` isn't passed. |
| `MASTUI_CLAUDE_CODE_MODEL` | CLI default | Model passed to `claude -p --model …`, e.g. `opus` or `sonnet`. |
| `MASTUI_CODEX_MODEL` | CLI default | Model passed to `codex exec -m …`, e.g. `gpt-5.1-codex`. |
| `MASTUI_OPENCODE_MODEL` | CLI default | Model passed to `opencode run -m …`, e.g. `anthropic/claude-sonnet-5`. |

## Quality gate

Generation is cheap; curation isn't automatic. Review `out/*/image.png` and delete the folders you
wouldn't ship **before** uploading. 300 great screens beat 3000 mediocre ones.
