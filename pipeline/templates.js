/**
 * Prompt factory: categories x screens x styles x palettes -> hundreds of prompts.
 *
 * Each generated prompt describes a MOBILE APP SCREEN in design terms only —
 * no framework, no library. That way the same prompt works in v0, Lovable,
 * Cursor, or Claude, and the user picks their own output target.
 *
 * A style is split into two halves so the catalog never looks monotonous:
 *   spec     — the structural language (shape, type, shadow, spacing). Colorless.
 *   palettes — the color story. Each style carries several; screens rotate through
 *              them, so two Neon Cyber screens share a language but not a hue.
 */

export const CATEGORIES = [
  {
    id: 'login',
    name: 'Login',
    screens: [
      { slug: 'email-login', title: 'Email Login', platforms: ['mobile', 'web'], brief: 'a login screen with email and password fields, a primary sign-in button, a secondary social-login button with a small neutral circular icon glyph (no real brand logo) and "Continue with Google" label, and a small "Forgot password?" link' },
      { slug: 'otp-verify', title: 'OTP Verification', platforms: ['mobile', 'web'], brief: 'a phone verification screen with six single-digit OTP boxes, a countdown timer for resending the code, and a full-width verify button' },
      { slug: 'signup', title: 'Create Account', platforms: ['mobile', 'web'], brief: 'a sign-up screen with name, email and password fields, a password-strength hint, a terms checkbox, and a primary create-account button' },
    ],
  },
  {
    id: 'dashboard',
    name: 'Dashboard',
    screens: [
      { slug: 'finance-overview', title: 'Finance Overview', platforms: ['mobile', 'web'], brief: 'a finance dashboard with a large balance card at the top, a row of four quick-action icons, a simple line chart of spending, and a recent-transactions list' },
      { slug: 'fitness-stats', title: 'Fitness Stats', platforms: ['mobile', 'web'], brief: 'a fitness dashboard with a circular progress ring for daily steps, three small stat tiles (calories, distance, active minutes), and a weekly bar chart' },
      { slug: 'analytics', title: 'Analytics', platforms: ['mobile', 'web'], brief: 'an analytics dashboard with a headline metric and percentage delta, a segmented time-range control, an area chart, and a breakdown list with small progress bars' },
    ],
  },
  {
    id: 'onboarding',
    name: 'Onboarding',
    screens: [
      { slug: 'welcome-slide', title: 'Welcome Slide', platforms: ['mobile', 'web'], brief: 'an onboarding slide with a large illustration area, a bold headline, one supporting sentence, three dot page-indicators, and a floating next button' },
      { slug: 'permissions', title: 'Permissions', platforms: ['mobile', 'web'], brief: 'a permissions request screen with an icon, a headline explaining why access is needed, two benefit bullet rows with small icons, an allow button and a "Not now" text button' },
    ],
  },
  {
    id: 'ecommerce',
    name: 'E-commerce',
    screens: [
      { slug: 'product-grid', title: 'Product Grid', platforms: ['mobile', 'web'], brief: 'a shop screen with a rounded search bar, horizontal category chips, and a two-column grid of product cards each with an image area, name, price and a small favourite icon' },
      { slug: 'product-detail', title: 'Product Detail', platforms: ['mobile', 'web'], brief: 'a product detail screen with a large image area, product title and price, a star rating row, size selector chips, a short description, and a sticky add-to-cart bar at the bottom' },
      { slug: 'cart', title: 'Shopping Cart', platforms: ['mobile', 'web'], brief: 'a cart screen with a list of item rows (thumbnail, name, quantity stepper, price), a promo-code field, an order summary block, and a sticky checkout button' },
    ],
  },
  {
    id: 'profile',
    name: 'Profile',
    screens: [
      { slug: 'settings-list', title: 'Profile & Settings', platforms: ['mobile', 'web'], brief: 'a profile screen with a circular avatar, name and email, and grouped settings rows separated by thin dividers, each with an icon and a chevron' },
      { slug: 'edit-profile', title: 'Edit Profile', platforms: ['mobile', 'web'], brief: 'an edit-profile screen with a large avatar and a change-photo button, labelled text fields for name, username and bio, and a save button' },
    ],
  },
  {
    id: 'pricing',
    name: 'Pricing',
    screens: [
      { slug: 'two-plans', title: 'Simple Pricing', platforms: ['mobile', 'web'], brief: 'a pricing screen with two plan cards (Free and Pro) stacked vertically, the Pro card visually highlighted with a "Popular" chip, each listing four features with small check icons' },
      { slug: 'billing-toggle', title: 'Plans with Billing Toggle', platforms: ['mobile', 'web'], brief: 'a pricing screen with a monthly/yearly segmented toggle at the top showing a "Save 20%" chip, and three compact plan cards in a horizontal scroll row' },
    ],
  },
  {
    id: 'chat',
    name: 'Chat',
    screens: [
      { slug: 'conversation', title: 'Chat Conversation', platforms: ['mobile', 'web'], brief: 'a chat screen with a header showing avatar, name and online status, alternating incoming and outgoing message bubbles with timestamps, and a rounded input bar with an attach icon and a send button' },
      { slug: 'inbox', title: 'Chat Inbox', platforms: ['mobile', 'web'], brief: 'a message inbox with a search bar, a horizontal row of story-style avatars, and a list of conversation rows each with avatar, name, message preview, time and an unread count badge' },
    ],
  },
  {
    id: 'search',
    name: 'Search',
    screens: [
      { slug: 'empty-search', title: 'Search & Filters', platforms: ['mobile', 'web'], brief: 'a search screen with a focused search bar, a "Recent searches" list with small clock icons and remove buttons, and a "Popular" section of tappable chips' },
      { slug: 'results', title: 'Search Results', platforms: ['mobile', 'web'], brief: 'a search results screen with the query in the search bar, a horizontal filter chip row, a result count line, and a vertical list of result cards each with a thumbnail, title and two meta lines' },
    ],
  },
];

/** Supported targets for a design. Screens are mobile by default because the
 * generator and screenshot pipeline currently render at a phone viewport. */
export const DESIGN_PLATFORMS = ['mobile', 'web'];
const DEFAULT_PLATFORMS = ['mobile'];

function platformsFor(screen) {
  const platforms = [...new Set(screen.platforms ?? DEFAULT_PLATFORMS)];
  if (platforms.length === 0 || !platforms.every((platform) => DESIGN_PLATFORMS.includes(platform))) {
    throw new Error(`Invalid platforms for ${screen.slug}: ${platforms.join(', ')}`);
  }
  return platforms;
}

/**
 * The shelf. MastUI is a store — the whole point is that users find every kind of
 * design here, not one house style. Each entry is a self-contained visual language
 * and may contradict the others freely (gradients, neon and glass are welcome here
 * even though the MastUI app's own shell UI avoids them).
 *
 * `spec` describes form only. Never put colors in it — they belong in `palettes`,
 * so the same style ships in several hues and the catalog grid stays varied.
 */
export const STYLES = [
  {
    id: 'chatgpt-minimal',
    name: 'Modern Minimalist',
    tags: ['Minimal', 'Light'],
    fontFamily: {
      heading: '-apple-system, BlinkMacSystemFont, "SF Pro Display", "Segoe UI", sans-serif',
      body: '-apple-system, BlinkMacSystemFont, "SF Pro Text", "Segoe UI", sans-serif',
    },
    spec: `Typography carries the hierarchy through opacity levels of a single near-black ink rather than through different colors. Cards sit on the background with almost invisible 1px borders and a very soft shadow. Corner radii: cards 16px, buttons 20px, search bar 28px. Simple outline icons with 2px stroke. Generous whitespace and Apple-inspired spacing. Flat — no gradients, no glass. Calm, premium, elegant and highly readable.`,
    palettes: [
      { id: 'ink-blue', name: 'Ink Blue', spec: `White #FFFFFF background. Ink #111111 at 100% / 72% / 45% opacity for primary / secondary / hint text. Dividers rgba(17,17,17,0.08), borders rgba(17,17,17,0.10). Accent soft blue #3B82F6.` },
      { id: 'warm-sage', name: 'Warm Sage', spec: `Warm off-white #FCFBF8 background, white cards. Ink #14181A at 100% / 70% / 44%. Borders rgba(20,24,26,0.10). Accent muted sage green #4F7A5C.` },
      { id: 'cool-plum', name: 'Cool Plum', spec: `Cool white #FBFBFD background. Ink #16141C at 100% / 70% / 42%. Borders rgba(22,20,28,0.10). Accent deep plum #6D4BA8.` },
    ],
  },
  {
    id: 'soft-dark',
    name: 'Soft Dark',
    tags: ['Dark', 'Minimal'],
    fontFamily: {
      heading: '-apple-system, BlinkMacSystemFont, "SF Pro Display", "Segoe UI", sans-serif',
      body: '-apple-system, BlinkMacSystemFont, "SF Pro Text", "Segoe UI", sans-serif',
    },
    spec: `A dark canvas with slightly lighter elevated surfaces — elevation is shown by surface tone, never by shadow. Hairline 1px borders at low opacity. Cards 16px radius, buttons 20px. Outline icons, 2px stroke. Restrained, comfortable for night use — no glow, no neon.`,
    palettes: [
      { id: 'graphite', name: 'Graphite', spec: `Background #121212, surfaces #1C1C1E. Text #F5F5F5 / rgba(245,245,245,0.65) / rgba(245,245,245,0.4). Borders rgba(255,255,255,0.08). Accent periwinkle #7C9CF5.` },
      { id: 'midnight-teal', name: 'Midnight Teal', spec: `Background #0F1719, surfaces #162124. Text #E6F0F0 / rgba(230,240,240,0.62) / rgba(230,240,240,0.38). Borders rgba(230,240,240,0.09). Accent teal #4DB6A5.` },
      { id: 'warm-coal', name: 'Warm Coal', spec: `Background #17140F, surfaces #201C16. Text #F2EDE4 / rgba(242,237,228,0.62) / rgba(242,237,228,0.38). Borders rgba(242,237,228,0.09). Accent amber #D99A4E.` },
    ],
  },
  {
    id: 'warm-editorial',
    name: 'Warm Editorial',
    tags: ['Editorial', 'Serif'],
    fontFamily: {
      heading: 'Georgia, "Times New Roman", serif',
      body: '-apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif',
    },
    spec: `Serif display headings (Georgia) paired with a clean sans-serif for body text. Generous line height and a large type scale. Thin 1px rules instead of card borders; no shadows. Understated, magazine-like, spacious.`,
    palettes: [
      { id: 'terracotta', name: 'Terracotta', spec: `Warm off-white #FAF7F2 background. Text #1A1614 / rgba(26,22,20,0.7). Rules rgba(26,22,20,0.12). Accent terracotta #C2603F.` },
      { id: 'ink-navy', name: 'Ink Navy', spec: `Cool paper #F7F8FA background. Text #14213D / rgba(20,33,61,0.68). Rules rgba(20,33,61,0.12). Accent navy #1D3A8A.` },
      { id: 'olive-press', name: 'Olive Press', spec: `Newsprint #F4F3EC background. Text #232619 / rgba(35,38,25,0.68). Rules rgba(35,38,25,0.14). Accent olive #6B7A3A.` },
    ],
  },
  {
    id: 'neubrutal',
    name: 'Neubrutalism',
    tags: ['Bold', 'Playful'],
    fontFamily: {
      heading: '"Arial Black", "Helvetica Neue", "Impact", sans-serif',
      body: '-apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif',
    },
    spec: `Every card and button carries a solid 2px black border and a hard 4px offset black drop shadow with zero blur. Bold heavy sans-serif headings. Corner radius 12px. Flat color blocks, no gradients. High contrast, chunky, confident and playful.`,
    palettes: [
      { id: 'yellow-teal', name: 'Yellow Teal', spec: `Background #FDF6E3. Accent blocks #FFD23F yellow and #4ECDC4 teal. All borders and text pure black #000000.` },
      { id: 'pink-lime', name: 'Pink Lime', spec: `Background #F0F0FF. Accent blocks #FF5CA8 pink and #C6FF3D lime. All borders and text pure black #000000.` },
      { id: 'orange-blue', name: 'Orange Blue', spec: `Background #FFF2E8. Accent blocks #FF6B1A orange and #2D5BFF blue. All borders and text pure black #000000.` },
    ],
  },
  {
    id: 'pastel-soft',
    name: 'Soft Pastel',
    tags: ['Pastel', 'Rounded'],
    fontFamily: {
      heading: '"Nunito", "SF Pro Rounded", -apple-system, sans-serif',
      body: '"Nunito", "SF Pro Rounded", -apple-system, sans-serif',
    },
    spec: `Rounded, friendly geometry — cards 24px radius, buttons fully pill-shaped. Soft diffuse shadows and no borders at all. Medium-weight rounded sans-serif. Gentle, approachable and airy.`,
    palettes: [
      { id: 'lavender', name: 'Lavender', spec: `Background #F6F4FF, cards #FFFFFF. Text #2E2A45 / rgba(46,42,69,0.6). Accents indigo #A5B4FC and pink #FBCFE8.` },
      { id: 'peach-mint', name: 'Peach Mint', spec: `Background #FFF6F2, cards #FFFFFF. Text #40312C / rgba(64,49,44,0.6). Accents peach #FFB4A2 and mint #A8DCD1.` },
      { id: 'sky-butter', name: 'Sky Butter', spec: `Background #F2F8FF, cards #FFFFFF. Text #27384A / rgba(39,56,74,0.6). Accents sky #A7D3F5 and butter #FFE5A0.` },
    ],
  },
  {
    id: 'mono-technical',
    name: 'Technical Mono',
    tags: ['Mono', 'Dense'],
    fontFamily: {
      heading: '"SF Mono", "Cascadia Code", "Fira Code", "Consolas", monospace',
      body: '-apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif',
      mono: '"SF Mono", "Cascadia Code", "Fira Code", "Consolas", monospace',
    },
    spec: `Monospace type for labels, numbers and metadata; clean sans-serif for prose. Sharp 6px corner radii. 1px solid borders, no shadows at all. The accent appears only on interactive elements. Dense, information-rich, precise — like a developer tool.`,
    palettes: [
      { id: 'slate-blue', name: 'Slate Blue', spec: `Background #F4F5F7, surfaces #FFFFFF. Text #1F2328 / #656D76. Borders #D8DBE0. Accent #2563EB.` },
      { id: 'terminal-green', name: 'Terminal Green', spec: `Background #0D1117, surfaces #161B22. Text #C9D1D9 / #8B949E. Borders #30363D. Accent #3FB950.` },
      { id: 'paper-red', name: 'Paper Red', spec: `Background #FAF9F7, surfaces #FFFFFF. Text #1C1B19 / #6E6A63. Borders #DDD9D2. Accent #D0342C.` },
    ],
  },
  {
    id: 'glass',
    name: 'Glassmorphism',
    tags: ['Glass', 'Blur'],
    fontFamily: {
      heading: '-apple-system, BlinkMacSystemFont, "SF Pro Display", "Segoe UI", sans-serif',
      body: '-apple-system, BlinkMacSystemFont, "SF Pro Text", "Segoe UI", sans-serif',
    },
    spec: `A saturated blurred background of large soft color blobs bleeding into each other. Every surface is frosted glass: a low-opacity white fill, backdrop-filter blur(24px), a 1px rgba(255,255,255,0.25) highlight border catching light from the top-left, and 24px radius. White text with a subtle shadow for legibility. Layered depth, translucency everywhere, light and futuristic.`,
    palettes: [
      { id: 'violet-cyan', name: 'Violet Cyan', spec: `Background blobs #7C3AED violet and #06B6D4 cyan on a #1E1B4B base.` },
      { id: 'sunset', name: 'Sunset', spec: `Background blobs #F97316 orange and #EC4899 pink on a #4C1D3D base.` },
      { id: 'aurora', name: 'Aurora', spec: `Background blobs #10B981 emerald and #3B82F6 blue on a #0B2545 base.` },
    ],
  },
  {
    id: 'vibrant-gradient',
    name: 'Vibrant Gradient',
    tags: ['Gradient', 'Bold'],
    fontFamily: {
      heading: '"Arial Black", "Helvetica Neue", "Impact", sans-serif',
      body: '-apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif',
    },
    spec: `Bold full-bleed gradients are the primary design element, with a second gradient reserved for buttons. White cards float on top at 20px radius with generous colored shadows tinted to match the gradient beneath them. Heavy bold sans-serif headings in white. Energetic, saturated, confident.`,
    palettes: [
      { id: 'coral-slate', name: 'Coral Slate', spec: `Main gradient #FF6B6B coral into #556270 slate. Button gradient #4ECDC4 into #C7F464.` },
      { id: 'purple-magenta', name: 'Purple Magenta', spec: `Main gradient #7B2FF7 purple into #F107A3 magenta. Button gradient #00C9FF into #92FE9D.` },
      { id: 'ocean-lime', name: 'Ocean Lime', spec: `Main gradient #0575E6 blue into #021B79 deep navy. Button gradient #F7971E amber into #FFD200 yellow.` },
    ],
  },
  {
    id: 'neon-cyber',
    name: 'Neon Cyber',
    tags: ['Neon', 'Dark'],
    fontFamily: {
      heading: '"SF Mono", "Cascadia Code", "Courier New", monospace',
      body: '-apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif',
      mono: '"SF Mono", "Cascadia Code", "Courier New", monospace',
    },
    spec: `A near-black canvas with a faint grid or scanline texture. Two neon accents that actually glow — each carries a matching outer box-shadow, and key numbers get a text glow. Thin 1px neon borders on cards. Monospace or wide-tracked uppercase labels. High-contrast, electric, cyberpunk.`,
    palettes: [
      { id: 'cyan-magenta', name: 'Cyan Magenta', spec: `Background #0A0A0F, text #E8E8F0. Neons #00F0FF cyan and #FF2E97 magenta.` },
      { id: 'lime-violet', name: 'Lime Violet', spec: `Background #080F08, text #E6F5E6. Neons #39FF14 lime and #B026FF violet.` },
      { id: 'amber-red', name: 'Amber Red', spec: `Background #100A05, text #F5EDE4. Neons #FFB000 amber and #FF3131 red.` },
    ],
  },
  {
    id: 'clay-3d',
    name: 'Claymorphism',
    tags: ['3D', 'Playful'],
    fontFamily: {
      heading: '"Nunito", "SF Pro Rounded", -apple-system, sans-serif',
      body: '"Nunito", "SF Pro Rounded", -apple-system, sans-serif',
    },
    spec: `Every element is puffy 3D clay: large 32px radii, a light inner highlight along the top edge, a soft inner shadow along the bottom, and a large diffuse outer drop shadow — as if moulded from soft plastic. Chunky rounded sans-serif. Toy-like, tactile, friendly and bouncy.`,
    palettes: [
      { id: 'lilac-candy', name: 'Lilac Candy', spec: `Background #EBE5FF, cards #F5F1FF. Text #3B3054. Accents #FF9A8B, #A0E7E5, #FFD3B6.` },
      { id: 'mint-cream', name: 'Mint Cream', spec: `Background #DFF5EC, cards #EFFBF6. Text #1F4438. Accents #FFB5A7, #B8E0D2, #F6D186.` },
      { id: 'blush-sky', name: 'Blush Sky', spec: `Background #FFE8EC, cards #FFF4F6. Text #4A2B36. Accents #A6D8FF, #FFC4D6, #FFF1A6.` },
    ],
  },
  {
    id: 'retro-y2k',
    name: 'Retro Y2K',
    tags: ['Retro', 'Bold'],
    fontFamily: {
      heading: '"Arial Black", "Impact", sans-serif',
      body: '-apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif',
    },
    spec: `Chrome and metallic silver gradient surfaces on a saturated background. Bubble-style bold rounded typography, with some headings filled by a chrome gradient. Pill shapes everywhere, star and sparkle motifs, thick white outlines. Loud, nostalgic, early-2000s optimistic.`,
    palettes: [
      { id: 'electric-blue', name: 'Electric Blue', spec: `Background #1E27E8. Accents #FF00E5 hot pink and #FFF200 yellow.` },
      { id: 'bubblegum', name: 'Bubblegum', spec: `Background #FF6EC7. Accents #00E5FF cyan and #FFFFFF white.` },
      { id: 'lime-shock', name: 'Lime Shock', spec: `Background #B4FF39. Accents #FF3D00 orange-red and #7B2FF7 purple.` },
    ],
  },
  {
    id: 'material-you',
    name: 'Material You',
    tags: ['Material', 'Android'],
    fontFamily: {
      heading: '"Roboto", "Segoe UI", sans-serif',
      body: '"Roboto", "Segoe UI", sans-serif',
    },
    spec: `Google Material 3 expressive. Large 28px radii on cards, fully rounded 20px filled buttons, tonal icon buttons on circular containers. Material Symbols-style icons. Clear elevation tiers and a visible ripple-ready feel. Native Android through and through.`,
    palettes: [
      { id: 'purple-seed', name: 'Purple Seed', spec: `Tonal palette from a #6750A4 seed: surface #FFFBFE, surface-container #F3EDF7, primary-container #EADDFF with on-primary-container #21005D.` },
      { id: 'green-seed', name: 'Green Seed', spec: `Tonal palette from a #386A20 seed: surface #FDFDF5, surface-container #EFF2E8, primary-container #B7F397 with on-primary-container #082100.` },
      { id: 'coral-seed', name: 'Coral Seed', spec: `Tonal palette from a #B3261E seed: surface #FFFBFF, surface-container #F9EAE8, primary-container #F9DEDC with on-primary-container #410E0B.` },
    ],
  },
  {
    id: 'ios-native',
    name: 'iOS Native',
    tags: ['iOS', 'System'],
    fontFamily: {
      heading: '-apple-system, BlinkMacSystemFont, "SF Pro Display", "SF Pro Text", sans-serif',
      body: '-apple-system, BlinkMacSystemFont, "SF Pro Text", sans-serif',
    },
    spec: `Apple HIG defaults. Grouped-list background with pure white inset list cards at 10px radius. SF-style typography at iOS sizes: 34px bold large title, 17px body, 13px footnote. Full-width hairline separators inset from the left edge, chevrons on rows, a large title header. Looks like a stock iOS system app.`,
    palettes: [
      { id: 'system-blue', name: 'System Blue', spec: `Grouped background #F2F2F7, cards #FFFFFF. Label #000000, secondary #3C3C4399. Tint system blue #007AFF.` },
      { id: 'system-dark', name: 'System Dark', spec: `Grouped background #000000, cards #1C1C1E. Label #FFFFFF, secondary #EBEBF599. Tint system blue #0A84FF.` },
      { id: 'system-green', name: 'System Green', spec: `Grouped background #F2F2F7, cards #FFFFFF. Label #000000, secondary #3C3C4399. Tint system green #34C759.` },
    ],
  },
  {
    id: 'luxury-dark',
    name: 'Luxury Dark',
    tags: ['Luxury', 'Dark'],
    fontFamily: {
      heading: 'Georgia, "Times New Roman", serif',
      body: '-apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif',
      mono: '"SF Mono", "Cascadia Code", monospace',
    },
    spec: `The metallic accent appears only as thin 1px borders, small-caps labels and key text — never as a large fill. High-contrast serif display headings paired with wide-tracked uppercase sans-serif labels. Very generous spacing, minimal ornament, small 4px radii. Expensive, restrained, editorial — like a luxury fashion house.`,
    palettes: [
      { id: 'gold', name: 'Champagne Gold', spec: `Background #0C0C0C, surfaces #161616. Text #F5F1E8. Accent champagne gold #C6A15B.` },
      { id: 'platinum', name: 'Platinum', spec: `Background #0A0C0E, surfaces #14181C. Text #EDF1F4. Accent cool platinum #B8C4CC.` },
      { id: 'burgundy', name: 'Burgundy', spec: `Background #100608, surfaces #1A0C10. Text #F4E9EC. Accent deep burgundy #8C2F44.` },
    ],
  },
  {
    id: 'nature-organic',
    name: 'Organic Nature',
    tags: ['Organic', 'Calm'],
    fontFamily: {
      heading: '"Nunito", "SF Pro Rounded", -apple-system, sans-serif',
      body: '"Nunito", "SF Pro Rounded", -apple-system, sans-serif',
    },
    spec: `Organic asymmetric blob shapes and irregular border-radii (e.g. 60% 40% 55% 45%) on decorative elements. Rounded humanist sans-serif. Leaf, sun and wave line motifs. Soft natural shadows. Grounded, calm, sustainable and wholesome.`,
    palettes: [
      { id: 'forest-clay', name: 'Forest Clay', spec: `Background sand #F5F1E8, surfaces #E8E0D0. Text #2B2A26. Primary forest green #2D5A3D, accent clay #B5654B.` },
      { id: 'ocean-sand', name: 'Ocean Sand', spec: `Background #F2F6F5, surfaces #E2ECEA. Text #1E2A2C. Primary deep ocean #1F5F6B, accent coral sand #E0A56B.` },
      { id: 'desert-bloom', name: 'Desert Bloom', spec: `Background #FCF3EA, surfaces #F3E3D3. Text #33261E. Primary rust #A8542C, accent cactus green #6E8B5A.` },
    ],
  },
  {
    id: 'raw-brutalist',
    name: 'Raw Brutalist',
    tags: ['Brutalist', 'Raw'],
    fontFamily: {
      heading: 'system-ui, -apple-system, sans-serif',
      body: 'system-ui, -apple-system, sans-serif',
    },
    spec: `System default fonts at unstyled browser sizes. Zero border-radius everywhere, thick 3px solid black borders, no shadows at all. Underlined links, left-aligned everything, rows of dashes or equals signs used as section dividers instead of rules. Deliberately anti-design — reads like a raw unstyled HTML document.`,
    palettes: [
      { id: 'default-web', name: 'Default Web', spec: `Background #FFFFFF. Text #000000. Link blue #0000EE, visited purple #551A8B.` },
      { id: 'terminal-white', name: 'Terminal White', spec: `Background #F0F0F0. Text #1A1A1A. Accent red #CC0000.` },
      { id: 'gray-scale', name: 'Gray Scale', spec: `Background #E5E5E5. Text #262626. Accent orange #CC5500.` },
    ],
  },
  {
    id: 'swiss-grid',
    name: 'Swiss International',
    tags: ['Grid', 'Typographic'],
    fontFamily: {
      heading: '"Helvetica Neue", "Arial", sans-serif',
      body: '"Helvetica Neue", "Arial", sans-serif',
    },
    spec: `A strict modular grid with one bold accent color used sparingly for a single element per screen. Tight-tracked Helvetica-style sans-serif, left-aligned ragged-right text. Thin 1px rules define regions instead of cards. Zero radius, zero shadow — every element sits on a precise baseline grid. Rational and disciplined.`,
    palettes: [
      { id: 'red-black', name: 'Red Black', spec: `Background #FFFFFF. Text #111111. Accent red #E30613.` },
      { id: 'blue-white', name: 'Blue White', spec: `Background #FAFAFA. Text #14161A. Accent blue #0047AB.` },
      { id: 'yellow-black', name: 'Yellow Black', spec: `Background #FFFFFF. Text #101010. Accent yellow #F5C400.` },
    ],
  },
  {
    id: 'memphis',
    name: 'Memphis Pattern',
    tags: ['Memphis', 'Playful'],
    fontFamily: {
      heading: '"Arial Black", "Helvetica Neue", sans-serif',
      body: '-apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif',
    },
    spec: `Squiggles, confetti dots and zigzag lines scattered as decorative background motifs behind flat-color geometric shapes (triangles, half-circles, squiggly underlines). Thick black outlines on every card. Bold geometric sans headings. Asymmetric, loud, 80s-postmodern clash of color and shape.`,
    palettes: [
      { id: 'primary-clash', name: 'Primary Clash', spec: `Background #FFFFFF. Shapes red #FF3366, blue #33CCFF, yellow #FFCC00. Outlines and text black #000000.` },
      { id: 'pastel-memphis', name: 'Pastel Memphis', spec: `Background #FFF8F0. Shapes pink #FFB3C6, mint #B3F0E5, lilac #D6B3FF. Outlines charcoal #262626.` },
      { id: 'mono-memphis', name: 'Mono Memphis', spec: `Background #F2F2F2. Shapes black #111111 and single accent orange #FF5A1F.` },
    ],
  },
  {
    id: 'art-deco',
    name: 'Art Deco',
    tags: ['Deco', 'Elegant'],
    fontFamily: {
      heading: 'Georgia, "Playfair Display", serif',
      body: '"Arial Narrow", "Helvetica Neue", sans-serif',
    },
    spec: `Symmetrical geometric ornament — sunburst and fan motifs framing cards, stepped ziggurat edges on headers. Thin metallic-line borders and dividers. Tall elegant serif display type with wide letter-spacing for headings, condensed sans for body. Opulent, symmetrical, jazz-age glamour.`,
    palettes: [
      { id: 'black-gold', name: 'Black Gold', spec: `Background #0D0D0D, surfaces #161616. Text #F3EFE3. Accent gold #C9A24B.` },
      { id: 'emerald-gold', name: 'Emerald Gold', spec: `Background #0B1F1A, surfaces #122A23. Text #EDF5F0. Accent gold #C9A24B, accent emerald #1F7A5C.` },
      { id: 'navy-gold', name: 'Navy Gold', spec: `Background #0A1128, surfaces #121B3A. Text #EEF0FA. Accent gold #D4AF37.` },
    ],
  },
  {
    id: 'vaporwave',
    name: 'Vaporwave',
    tags: ['Vaporwave', 'Retro'],
    fontFamily: {
      heading: '"Courier New", monospace',
      body: '-apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif',
    },
    spec: `A gradient sky background fading into a horizon crossed by a neon grid, with classical-statue-bust and palm-tree silhouettes as decorative accents. Chrome-outlined headline text. Thin neon-pink grid lines throughout. Nostalgic 90s-internet, dreamlike, softly glitchy.`,
    palettes: [
      { id: 'pink-cyan-purple', name: 'Pink Cyan Purple', spec: `Sky gradient #FF71CE pink into #01CDFE cyan over #2D1B4E purple base. Grid lines #FF71CE.` },
      { id: 'sunset-grid', name: 'Sunset Grid', spec: `Sky gradient #FF9A5C orange into #B24BF3 purple over #1A0B2E base. Grid lines #FFD35C.` },
      { id: 'mint-lavender', name: 'Mint Lavender', spec: `Sky gradient #7CF5D1 mint into #C6A8FF lavender over #241B3A base. Grid lines #C6A8FF.` },
    ],
  },
  {
    id: 'cyber-noir',
    name: 'Cyber Noir',
    tags: ['Noir', 'Dark'],
    fontFamily: {
      heading: '"Arial Narrow", "Helvetica Neue", sans-serif',
      body: '-apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif',
    },
    spec: `A near-black canvas lit by a single cold key light — most of the UI stays in deep shadow with one bright focal element per screen. Sharp thin borders, no glow. Condensed uppercase sans for labels. Moody, cinematic, restrained high-contrast — closer to film noir than cyberpunk neon.`,
    palettes: [
      { id: 'cold-blue', name: 'Cold Blue', spec: `Background #08090C, surfaces #101318. Text #DCE3EC. Key light #6FA8FF.` },
      { id: 'blood-red-accent', name: 'Blood Red Accent', spec: `Background #0A0808, surfaces #131010. Text #E9E4E4. Key light #E23B3B.` },
      { id: 'steel-gray', name: 'Steel Gray', spec: `Background #0B0C0D, surfaces #16181A. Text #E2E5E7. Key light #9FB4C7.` },
    ],
  },
  {
    id: 'skeuomorphic',
    name: 'Skeuomorphic',
    tags: ['Skeuomorphic', 'Realistic'],
    fontFamily: {
      heading: '-apple-system, BlinkMacSystemFont, "SF Pro Display", sans-serif',
      body: '-apple-system, BlinkMacSystemFont, "SF Pro Text", sans-serif',
    },
    spec: `Buttons and cards mimic real-world material — brushed-metal gradients, a glossy top highlight on buttons, and realistic drop shadows with a consistent light direction. Rounded 8px corners. Detailed and tactile, in the vein of pre-flat-design (iOS 6 era) interfaces.`,
    palettes: [
      { id: 'leather-brown', name: 'Leather Brown', spec: `Background #E9DCC9, surfaces gradient #F5EBD8 to #D9C6A3. Text #3A2A18. Accent brass #B08A3E.` },
      { id: 'brushed-steel', name: 'Brushed Steel', spec: `Background #D6D9DC, surfaces gradient #F0F1F2 to #B8BCC0. Text #24272A. Accent blue #2F6FCC.` },
      { id: 'glossy-blue', name: 'Glossy Blue', spec: `Background #DCEBFB, surfaces gradient #FFFFFF to #BBD8F5. Text #14202E. Accent #1E63C4.` },
    ],
  },
  {
    id: 'flat-2',
    name: 'Flat Design 2.0',
    tags: ['Flat', 'Illustration'],
    fontFamily: {
      heading: '-apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif',
      body: '-apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif',
    },
    spec: `Large soft-color geometric illustration blocks with simple rounded blob-people figures as decorative accents. Flat solid-fill cards at 12px radius, no shadow, no gradient, no texture. Confident single-weight sans-serif. Clean, friendly, corporate-startup illustration style.`,
    palettes: [
      { id: 'coral-navy', name: 'Coral Navy', spec: `Background #FFFFFF, surfaces #F5F6F8. Text #14213D. Illustration coral #FF6F59 and navy #14213D.` },
      { id: 'teal-cream', name: 'Teal Cream', spec: `Background #FFFCF5, surfaces #F6F1E4. Text #20342E. Illustration teal #2A9D8F and cream #FFF3D6.` },
      { id: 'violet-yellow', name: 'Violet Yellow', spec: `Background #FAFAFF, surfaces #F1F0FA. Text #241B3A. Illustration violet #7B5EA7 and yellow #FFC93C.` },
    ],
  },
  {
    id: 'duotone',
    name: 'Duotone',
    tags: ['Duotone', 'Photo'],
    fontFamily: {
      heading: '"Arial Black", "Helvetica Neue", sans-serif',
      body: '-apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif',
    },
    spec: `Every illustration or photo placeholder renders as a two-color duotone block (a dark shadow tone plus a bright highlight tone) — no other color appears except in these duotone areas and one accent. Bold condensed headline type. High-contrast, editorial, graphic-poster feel.`,
    palettes: [
      { id: 'navy-orange', name: 'Navy Orange', spec: `Background #FFFFFF. Duotone shadow #14213D, highlight #FF8500. Text #14213D.` },
      { id: 'purple-lime', name: 'Purple Lime', spec: `Background #FAFAFA. Duotone shadow #3C1361, highlight #C6FF3D. Text #241033.` },
      { id: 'black-red', name: 'Black Red', spec: `Background #FFFFFF. Duotone shadow #100000, highlight #FF3B30. Text #100000.` },
    ],
  },
  {
    id: 'kawaii',
    name: 'Kawaii Cute',
    tags: ['Cute', 'Pastel'],
    fontFamily: {
      heading: '"Nunito", "SF Pro Rounded", -apple-system, sans-serif',
      body: '"Nunito", "SF Pro Rounded", -apple-system, sans-serif',
    },
    spec: `Rounded blob shapes with simple cute face details (dot eyes, blush marks) as decorative mascots. Bubble-rounded corners 24px and up, soft pastel fills, thick 3px white sticker-style outline. Rounded chunky typeface. Playful, childlike, sticker-book charm.`,
    palettes: [
      { id: 'mint-pink', name: 'Mint Pink', spec: `Background #FFF0F5, cards #FFFFFF. Text #4A3040. Accents mint #B8F2E6 and pink #FFC2D6.` },
      { id: 'lavender-yellow', name: 'Lavender Yellow', spec: `Background #F3F0FF, cards #FFFFFF. Text #3A3050. Accents lavender #D8CCFF and yellow #FFE79A.` },
      { id: 'sky-peach', name: 'Sky Peach', spec: `Background #EFF8FF, cards #FFFFFF. Text #2E3A4A. Accents sky #BFE3FF and peach #FFD4B8.` },
    ],
  },
  {
    id: 'terminal-hacker',
    name: 'Terminal Hacker',
    tags: ['Terminal', 'Hacker'],
    fontFamily: {
      heading: '"SF Mono", "Cascadia Code", "Fira Code", "Courier New", monospace',
      body: '"SF Mono", "Cascadia Code", "Fira Code", "Courier New", monospace',
      mono: '"SF Mono", "Cascadia Code", "Fira Code", "Courier New", monospace',
    },
    spec: `Pure black background, monospace text everywhere including headings, a faint scanline overlay texture, and a blinking-cursor motif on inputs. Sharp 0px radius, thin 1px borders in the accent color. ASCII box-drawing characters used as dividers. Old-CRT-terminal, minimal, all-monospace.`,
    palettes: [
      { id: 'green-phosphor', name: 'Green Phosphor', spec: `Background #000000. Text and borders phosphor green #33FF66.` },
      { id: 'amber-phosphor', name: 'Amber Phosphor', spec: `Background #0A0700. Text and borders amber #FFB000.` },
      { id: 'white-terminal', name: 'White Terminal', spec: `Background #000000. Text and borders #E8E8E8, accent red #FF5555.` },
    ],
  },
  {
    id: 'print-newspaper',
    name: 'Print Newspaper',
    tags: ['Print', 'Editorial'],
    fontFamily: {
      heading: 'Georgia, "Times New Roman", serif',
      body: 'Georgia, "Times New Roman", serif',
    },
    spec: `A multi-column text layout with a bold masthead-style headline in a condensed serif, thin black rules between columns, and a halftone-dot texture on image placeholders. Justified body text. Ink-on-newsprint, dense, classic broadsheet feel.`,
    palettes: [
      { id: 'newsprint-gray', name: 'Newsprint Gray', spec: `Background #F1EFE9. Text #1C1C1C. Rules #1C1C1C.` },
      { id: 'sepia-print', name: 'Sepia Print', spec: `Background #F3E9D6. Text #2E2013. Rules #2E2013.` },
      { id: 'bw-print', name: 'Black White Print', spec: `Background #FFFFFF. Text #000000. Rules #000000, accent red #C1121F.` },
    ],
  },
  {
    id: 'comic-book',
    name: 'Comic Book',
    tags: ['Comic', 'Bold'],
    fontFamily: {
      heading: '"Arial Black", "Impact", sans-serif',
      body: '-apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif',
    },
    spec: `Bold black outlines on every shape, halftone-dot shading in accent areas, speech-bubble-shaped callouts, and dynamic diagonal action-line motifs behind headers. Comic-style bold italic display font. Punchy, graphic-novel energy.`,
    palettes: [
      { id: 'primary-comic', name: 'Primary Comic', spec: `Background #FFF9E8. Blocks red #E5303B, yellow #FFD23F, blue #2E5EAA. Outlines black #000000.` },
      { id: 'noir-comic', name: 'Noir Comic', spec: `Background #F2F2F2. Blocks black #000000 and white #FFFFFF. Accent red #E5303B.` },
      { id: 'manga-comic', name: 'Manga Comic', spec: `Background #FFFFFF. Blocks black #000000. Accent pink #FF6FA5.` },
    ],
  },
  {
    id: 'watercolor',
    name: 'Watercolor',
    tags: ['Watercolor', 'Soft'],
    fontFamily: {
      heading: 'Georgia, "Playfair Display", serif',
      body: '-apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif',
    },
    spec: `Soft irregular watercolor-wash blobs with visible pigment-bleed edges as background texture behind clean white cards. Hairline borders, no hard shadows. An elegant handwritten-style accent font for headings paired with clean sans body. Artistic, gentle, hand-painted.`,
    palettes: [
      { id: 'blush-sage', name: 'Blush Sage', spec: `Background wash #F8E6E6 blush and #E3EFE3 sage on #FFFFFF cards. Text #33302C.` },
      { id: 'ocean-wash', name: 'Ocean Wash', spec: `Background wash #DCEEF7 blue and #E7F3EE teal on #FFFFFF cards. Text #1E2E33.` },
      { id: 'sunset-wash', name: 'Sunset Wash', spec: `Background wash #FBE3D0 peach and #F6D6E3 pink on #FFFFFF cards. Text #3A2A28.` },
    ],
  },
  {
    id: 'paper-cut',
    name: 'Paper Cut',
    tags: ['Paper', 'Layered'],
    fontFamily: {
      heading: '"Nunito", "SF Pro Rounded", -apple-system, sans-serif',
      body: '"Nunito", "SF Pro Rounded", -apple-system, sans-serif',
    },
    spec: `Layered die-cut paper shapes with soft drop shadows showing physical stacking depth, rounded card edges like cut cardstock, and a subtle paper-grain texture. Friendly rounded sans. Tactile, crafted, layered illustration style.`,
    palettes: [
      { id: 'coral-cream', name: 'Coral Cream', spec: `Background #FFF8EF, layers coral #FF8577 and cream #FFEFD6. Text #3A2A20.` },
      { id: 'teal-sand', name: 'Teal Sand', spec: `Background #F5F1E6, layers teal #3E8E8C and sand #E9DCC1. Text #24302E.` },
      { id: 'plum-blush', name: 'Plum Blush', spec: `Background #FCF3F5, layers plum #7A4B6E and blush #F6D6DE. Text #362430.` },
    ],
  },
  {
    id: 'isometric',
    name: 'Isometric',
    tags: ['Isometric', '3D'],
    fontFamily: {
      heading: '-apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif',
      body: '-apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif',
    },
    spec: `Decorative isometric-3D illustration blocks (boxes, platforms) used as accent art, with flat crisp 8px-radius cards sitting above them and subtle long-cast shadows implying the isometric light angle. Clean geometric sans. Techy, dimensional, dashboard-illustration feel.`,
    palettes: [
      { id: 'blue-purple-iso', name: 'Blue Purple', spec: `Background #F5F6FA. Iso blocks blue #4C6FFF and purple #8C5CF5. Text #171A2B.` },
      { id: 'orange-teal-iso', name: 'Orange Teal', spec: `Background #FAF7F2. Iso blocks orange #FF8A3D and teal #2BB6A3. Text #24211A.` },
      { id: 'green-navy-iso', name: 'Green Navy', spec: `Background #F4F8F5. Iso blocks green #3FAE6B and navy #1E2A4A. Text #16221A.` },
    ],
  },
  {
    id: 'holographic',
    name: 'Holographic',
    tags: ['Holographic', 'Iridescent'],
    fontFamily: {
      heading: '-apple-system, BlinkMacSystemFont, "SF Pro Display", sans-serif',
      body: '-apple-system, BlinkMacSystemFont, "SF Pro Text", sans-serif',
    },
    spec: `An iridescent shifting-rainbow gradient sheen across card surfaces and buttons, like a hologram sticker, with thin white specular highlight lines at 20px card radius. White or near-white text carries a soft glow. Futuristic, shiny, collectible-card aesthetic.`,
    palettes: [
      { id: 'silver-holo', name: 'Silver Holo', spec: `Background #0E0E12. Sheen gradient #C9F7FF, #F6C9FF, #FFF6C9. Text #F5F5FA.` },
      { id: 'pink-holo', name: 'Pink Holo', spec: `Background #140A12. Sheen gradient #FFB8E6, #B8E4FF, #FFF0B8. Text #FBF0F8.` },
      { id: 'black-holo', name: 'Black Holo', spec: `Background #000000. Sheen gradient #7CFFE8, #FF7CD6, #FFE87C. Text #F2F2F2.` },
    ],
  },
  {
    id: 'corporate-flat',
    name: 'Corporate Flat Illustration',
    tags: ['Corporate', 'Illustration'],
    fontFamily: {
      heading: '-apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif',
      body: '-apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif',
    },
    spec: `Rounded flat-color human illustrations with oversized heads and limbs as decorative hero art, generously spaced clean cards at 12px radius with soft single-color shadows. Friendly geometric sans. Approachable B2B SaaS illustration style.`,
    palettes: [
      { id: 'indigo-peach', name: 'Indigo Peach', spec: `Background #FFFFFF, surfaces #F5F5FC. Illustration indigo #4F46E5 and peach #FFB199. Text #1D1B33.` },
      { id: 'teal-coral', name: 'Teal Coral', spec: `Background #FFFFFF, surfaces #F1F9F8. Illustration teal #0E9488 and coral #FF7A63. Text #142523.` },
      { id: 'violet-mint', name: 'Violet Mint', spec: `Background #FFFFFF, surfaces #F7F5FC. Illustration violet #7C4FE0 and mint #7EE0C3. Text #221B33.` },
    ],
  },
  {
    id: 'dark-academia',
    name: 'Dark Academia',
    tags: ['Academia', 'Vintage'],
    fontFamily: {
      heading: 'Georgia, "Playfair Display", serif',
      body: '-apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif',
    },
    spec: `Deep wood-brown and leather tones with ornate thin gold-foil rule lines framing cards, classic serif display headings evoking old library books, and small candle-lit vignette shading in corners. Scholarly, moody, gothic-library aesthetic.`,
    palettes: [
      { id: 'leather-gold', name: 'Leather Gold', spec: `Background #1B140F, surfaces #241B14. Text #EDE0CC. Accent gold #B08A3E.` },
      { id: 'forest-brass', name: 'Forest Brass', spec: `Background #10160F, surfaces #171F16. Text #E3EADF. Accent brass #A6813C.` },
      { id: 'burgundy-ivory', name: 'Burgundy Ivory', spec: `Background #180E10, surfaces #221317. Text #F1E7E3. Accent #8C3A4A.` },
    ],
  },
  {
    id: 'cottagecore',
    name: 'Cottagecore',
    tags: ['Cottagecore', 'Rustic'],
    fontFamily: {
      heading: 'Georgia, "Playfair Display", serif',
      body: '-apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif',
    },
    spec: `Soft floral-sprig line motifs as decorative borders, gingham-check texture accents, and warm cream cards at 14px radius with soft natural shadows. A cozy serif-meets-handwritten heading pairing. Rustic, wholesome, countryside warmth.`,
    palettes: [
      { id: 'cream-sage', name: 'Cream Sage', spec: `Background #FBF6EC, cards #FFFFFF. Text #3A3626. Accent sage #7C9070.` },
      { id: 'butter-rose', name: 'Butter Rose', spec: `Background #FDF6E0, cards #FFFFFF. Text #40342A. Accent rose #C97A83.` },
      { id: 'linen-berry', name: 'Linen Berry', spec: `Background #F6F1E6, cards #FFFFFF. Text #362E28. Accent berry #7A3B52.` },
    ],
  },
  {
    id: 'steampunk',
    name: 'Steampunk Industrial',
    tags: ['Steampunk', 'Ornate'],
    fontFamily: {
      heading: 'Georgia, "Playfair Display", serif',
      body: '-apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif',
      mono: '"SF Mono", "Courier New", monospace',
    },
    spec: `Brass-gear and rivet motifs as decorative corner ornaments, an aged-copper metallic gradient on accent surfaces, and thick dark-bronze beveled borders. Ornate Victorian display serif for headings, technical mono for data. Industrial, ornate, brass-and-leather.`,
    palettes: [
      { id: 'copper-charcoal', name: 'Copper Charcoal', spec: `Background #1A1613, surfaces #241E19. Text #ECE2D2. Accent copper #B5652D.` },
      { id: 'brass-navy', name: 'Brass Navy', spec: `Background #101623, surfaces #17202E. Text #E6EAF2. Accent brass #C09A3E.` },
      { id: 'bronze-forest', name: 'Bronze Forest', spec: `Background #14180F, surfaces #1C2216. Text #E7ECDD. Accent bronze #A8763B.` },
    ],
  },
  {
    id: 'scandi-nordic',
    name: 'Scandinavian Nordic',
    tags: ['Nordic', 'Minimal'],
    fontFamily: {
      heading: '-apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif',
      body: '-apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif',
    },
    spec: `Very pale neutral wood and linen tones, extremely restrained ornament, thin 1px warm-gray borders at 10px radius. Clean humanist sans with generous negative space. Calm, functional, hygge-inspired — warmer than pure white minimalism.`,
    palettes: [
      { id: 'birch-clay', name: 'Birch Clay', spec: `Background #F7F4EE, cards #FFFFFF. Text #2C2A26. Accent clay #B5714D.` },
      { id: 'linen-forest', name: 'Linen Forest', spec: `Background #F5F3EC, cards #FFFFFF. Text #262924. Accent forest #4C6650.` },
      { id: 'oat-slate', name: 'Oat Slate', spec: `Background #F6F4EF, cards #FFFFFF. Text #292A2C. Accent slate #5C6570.` },
    ],
  },
  {
    id: 'wabi-sabi',
    name: 'Wabi-Sabi',
    tags: ['Zen', 'Organic'],
    fontFamily: {
      heading: '-apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif',
      body: '-apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif',
    },
    spec: `Deliberately imperfect hand-drawn-feeling borders with slightly irregular line weight, a raw-linen background texture, and asymmetric generous negative space in muted earthen tones. Thin brush-stroke accent lines replace dividers. Serene, imperfect-on-purpose, Japanese minimalism.`,
    palettes: [
      { id: 'clay-ash', name: 'Clay Ash', spec: `Background #EFE9DF. Text #332F28. Accent clay #A9784F, ash gray #8A8378.` },
      { id: 'moss-stone', name: 'Moss Stone', spec: `Background #EAEAE0. Text #2C2E26. Accent moss #6B7A4F, stone #8C8C82.` },
      { id: 'sand-ink', name: 'Sand Ink', spec: `Background #F0E9DC. Text #26221C. Accent sand #C9A876, ink #33302B.` },
    ],
  },
  {
    id: 'saas-clean',
    name: 'SaaS Clean',
    tags: ['SaaS', 'Corporate'],
    fontFamily: {
      heading: '-apple-system, BlinkMacSystemFont, "Inter", "Segoe UI", sans-serif',
      body: '-apple-system, BlinkMacSystemFont, "Inter", "Segoe UI", sans-serif',
    },
    spec: `Crisp white cards with a single vivid brand accent, 8px radius, a subtle 1px border plus a barely-visible shadow, and clean geometric sans (Inter-style). Small rounded-square icon badges with tinted backgrounds. Confident, trustworthy, modern product design.`,
    palettes: [
      { id: 'indigo-slate', name: 'Indigo Slate', spec: `Background #FFFFFF, surfaces #F8F9FB. Text #16181D. Accent indigo #4F46E5.` },
      { id: 'violet-gray', name: 'Violet Gray', spec: `Background #FFFFFF, surfaces #F9F8FB. Text #18161D. Accent violet #7C3AED.` },
      { id: 'emerald-slate', name: 'Emerald Slate', spec: `Background #FFFFFF, surfaces #F7FAF9. Text #131B18. Accent emerald #0D9488.` },
    ],
  },
  {
    id: 'fintech-trust',
    name: 'Fintech Trust',
    tags: ['Fintech', 'Corporate'],
    fontFamily: {
      heading: '-apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif',
      body: '-apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif',
      mono: '"SF Mono", "Cascadia Code", "Fira Code", monospace',
    },
    spec: `Deep navy surfaces with crisp white data cards, thin 1px borders, tabular monospace numerals for all monetary figures, and small secure-lock iconography. 10px radius, no ornament. Serious, precise, bank-grade trustworthy.`,
    palettes: [
      { id: 'navy-white', name: 'Navy White', spec: `Background #0B1830, cards #FFFFFF. Text on dark #EAF0FA, text on card #101828. Accent #2563EB.` },
      { id: 'forest-white', name: 'Forest White', spec: `Background #0A1F1A, cards #FFFFFF. Text on dark #E8F3EF, text on card #10241E. Accent #0F9D6C.` },
      { id: 'charcoal-white', name: 'Charcoal White', spec: `Background #16181B, cards #FFFFFF. Text on dark #ECEDEF, text on card #17191C. Accent #4B5563.` },
    ],
  },
  {
    id: 'gaming-hud',
    name: 'Gaming HUD',
    tags: ['Gaming', 'HUD'],
    fontFamily: {
      heading: '"Arial Black", "Impact", sans-serif',
      body: '-apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif',
      mono: '"SF Mono", "Cascadia Code", monospace',
    },
    spec: `Angular clipped-corner panels with diagonal-cut edges instead of rounded corners, a thin glowing accent border on active elements, a bold italic condensed display font for headings, and small hexagonal icon frames. Aggressive, competitive, in-game-overlay energy.`,
    palettes: [
      { id: 'red-black-hud', name: 'Red Black', spec: `Background #0C0C0E, panels #17171A. Text #ECECEE. Accent glow #FF2A3D.` },
      { id: 'cyan-black-hud', name: 'Cyan Black', spec: `Background #080D0E, panels #121A1C. Text #E4F4F6. Accent glow #23E5FF.` },
      { id: 'gold-black-hud', name: 'Gold Black', spec: `Background #0D0C08, panels #1A1710. Text #F2EEDF. Accent glow #FFC93C.` },
    ],
  },
  {
    id: 'neumorphism',
    name: 'Neumorphism',
    tags: ['Neumorphism', 'Soft'],
    fontFamily: {
      heading: '"Nunito", "SF Pro Rounded", -apple-system, sans-serif',
      body: '"Nunito", "SF Pro Rounded", -apple-system, sans-serif',
    },
    spec: `Elements are extruded from a single-tone background using a light shadow on one side and a dark shadow on the other, creating a soft-embossed look with no borders and no separate surface color. Large 20px radii. Rounded sans. Monochrome, tactile, soft-UI.`,
    palettes: [
      { id: 'cool-gray-neu', name: 'Cool Gray', spec: `Background #E4E7EC, all surfaces the same tone. Text #3A3F47. Accent #5B7FDB.` },
      { id: 'warm-beige-neu', name: 'Warm Beige', spec: `Background #E9E3D8, all surfaces the same tone. Text #46403A. Accent #C97A4A.` },
      { id: 'blue-neu', name: 'Blue', spec: `Background #D9E4F0, all surfaces the same tone. Text #2C3A47. Accent #2F6FCC.` },
    ],
  },
  {
    id: 'aurora-gradient',
    name: 'Aurora Gradient',
    tags: ['Gradient', 'Ethereal'],
    fontFamily: {
      heading: '-apple-system, BlinkMacSystemFont, "SF Pro Display", sans-serif',
      body: '-apple-system, BlinkMacSystemFont, "SF Pro Text", sans-serif',
    },
    spec: `Soft multi-hue aurora-like gradient washes — dreamy and translucent rather than saturated — behind clean glassy-white cards with soft shadows at 20px radius. A light modern sans-serif. Ethereal, calm, northern-lights inspired.`,
    palettes: [
      { id: 'teal-violet-aurora', name: 'Teal Violet', spec: `Aurora wash teal #5CE0C6 into violet #A78BFA over #0E1524 base. Cards #FFFFFF at low opacity.` },
      { id: 'pink-blue-aurora', name: 'Pink Blue', spec: `Aurora wash pink #F5A8D0 into blue #7FB8F0 over #14101F base. Cards #FFFFFF at low opacity.` },
      { id: 'green-gold-aurora', name: 'Green Gold', spec: `Aurora wash green #6FE0A0 into gold #F0D178 over #0E1710 base. Cards #FFFFFF at low opacity.` },
    ],
  },
  {
    id: 'gothic-dark',
    name: 'Gothic Dark',
    tags: ['Gothic', 'Dark'],
    fontFamily: {
      heading: 'Georgia, "Times New Roman", serif',
      body: '-apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif',
    },
    spec: `A near-black background with ornate thin filigree line-art borders framing cards, blackletter-inspired display headings paired with a clean body sans, and a single deep accent used sparingly. Dramatic, ornate, dark-romantic.`,
    palettes: [
      { id: 'blood-bone', name: 'Blood Bone', spec: `Background #0C0A0A, surfaces #151212. Text #EDE7E3. Accent blood red #8A1E2B.` },
      { id: 'violet-bone', name: 'Violet Bone', spec: `Background #0B0A11, surfaces #151320. Text #EAE7F0. Accent violet #5B3A8C.` },
      { id: 'emerald-bone', name: 'Emerald Bone', spec: `Background #090C0A, surfaces #121712. Text #E7EDE7. Accent emerald #1E6B4A.` },
    ],
  },
  {
    id: 'tropical-vibrant',
    name: 'Tropical Vibrant',
    tags: ['Tropical', 'Vibrant'],
    fontFamily: {
      heading: '"Nunito", "SF Pro Rounded", -apple-system, sans-serif',
      body: '"Nunito", "SF Pro Rounded", -apple-system, sans-serif',
    },
    spec: `Large leaf and palm-frond silhouette motifs as decorative background accents, a saturated warm-sun palette, and rounded 18px cards with soft colored shadows. A bold friendly rounded sans. Energetic, sunny, vacation-poster vibrant.`,
    palettes: [
      { id: 'mango-teal', name: 'Mango Teal', spec: `Background #FFF3DC. Leaf motifs teal #1E9E8C. Accent mango #FF9F1C. Text #2B2114.` },
      { id: 'hibiscus-lime', name: 'Hibiscus Lime', spec: `Background #FFF0F2. Leaf motifs lime #8FCB3C. Accent hibiscus #FF4D6D. Text #2A1418.` },
      { id: 'papaya-ocean', name: 'Papaya Ocean', spec: `Background #FFF1E6. Leaf motifs ocean #1B7FA8. Accent papaya #FF7A3D. Text #241A14.` },
    ],
  },
  {
    id: 'blueprint',
    name: 'Blueprint',
    tags: ['Blueprint', 'Technical'],
    fontFamily: {
      heading: '"SF Mono", "Cascadia Code", "Courier New", monospace',
      body: '"SF Mono", "Cascadia Code", "Courier New", monospace',
      mono: '"SF Mono", "Cascadia Code", "Courier New", monospace',
    },
    spec: `A deep blue canvas with a fine white grid-line texture throughout, thin white 1px construction-line borders on cards, and corner crop-mark ticks on card edges. Technical monospace for labels and measurements. Precise, drafting-table, technical-drawing feel.`,
    palettes: [
      { id: 'classic-blueprint', name: 'Classic Blueprint', spec: `Background #0F3D8A, grid lines rgba(255,255,255,0.15). Text #EAF1FF. Accent white #FFFFFF.` },
      { id: 'cyan-blueprint', name: 'Cyan Blueprint', spec: `Background #062B3A, grid lines rgba(180,240,255,0.15). Text #E4FBFF. Accent cyan #5FD8F0.` },
      { id: 'white-on-navy', name: 'White on Navy', spec: `Background #14204A, grid lines rgba(255,255,255,0.12). Text #F0F3FF. Accent amber #F0B94A.` },
    ],
  },
  {
    id: 'vintage-sepia',
    name: 'Vintage Sepia',
    tags: ['Vintage', 'Sepia'],
    fontFamily: {
      heading: 'Georgia, "Times New Roman", serif',
      body: 'Georgia, "Times New Roman", serif',
    },
    spec: `A warm sepia-toned background with a subtle film-grain and vignette texture, ornate thin double-rule borders, and a classic serif display type reminiscent of old photographs and letterpress. An aged-paper texture on card surfaces. Nostalgic, antique, old-photograph warmth.`,
    palettes: [
      { id: 'sepia-classic', name: 'Sepia Classic', spec: `Background #E9D9BC. Text #3B2E1D. Rules #6B563A.` },
      { id: 'faded-rose', name: 'Faded Rose', spec: `Background #E9D6D2. Text #3A2825. Rules #7A5450.` },
      { id: 'ash-brown', name: 'Ash Brown', spec: `Background #DED6C9. Text #322B22. Rules #665A47.` },
    ],
  },
  {
    id: 'poster-bold',
    name: 'Bold Poster',
    tags: ['Poster', 'Typographic'],
    fontFamily: {
      heading: '"Arial Black", "Impact", sans-serif',
      body: '-apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif',
    },
    spec: `Oversized display type is the dominant visual element — headlines span the full width and overlap other elements confidently. Flat solid color blocks with zero shadow, sharp 0px or 4px radius, and a high-contrast two-color palette per screen. Graphic, confident, gig-poster energy.`,
    palettes: [
      { id: 'red-cream', name: 'Red Cream', spec: `Background #F3E9D8. Type block red #D62828. Text #221C15.` },
      { id: 'black-yellow', name: 'Black Yellow', spec: `Background #111111. Type block yellow #FFD400. Text #F5F5F5.` },
      { id: 'blue-white-poster', name: 'Blue White', spec: `Background #FFFFFF. Type block blue #1D3AE8. Text #101018.` },
    ],
  },
  {
    id: 'line-art',
    name: 'Minimal Line Art',
    tags: ['LineArt', 'Minimal'],
    fontFamily: {
      heading: '-apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif',
      body: '-apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif',
    },
    spec: `Single-weight continuous line-art illustrations are the only decorative imagery, otherwise pure white space. Hairline 1px borders, no fill colors except one accent line color. A thin elegant sans-serif. Extremely minimal, artistic, gallery-clean.`,
    palettes: [
      { id: 'black-white-line', name: 'Black White', spec: `Background #FFFFFF. Line art and text #111111.` },
      { id: 'sage-line', name: 'Sage', spec: `Background #FAFBF8. Line art #4C6B4F. Text #22261F.` },
      { id: 'terracotta-line', name: 'Terracotta', spec: `Background #FDF9F6. Line art #B5573A. Text #2A2019.` },
    ],
  },
  {
    id: 'candy-pop',
    name: 'Candy Pop',
    tags: ['Candy', 'Playful'],
    fontFamily: {
      heading: '"Nunito", "SF Pro Rounded", -apple-system, sans-serif',
      body: '"Nunito", "SF Pro Rounded", -apple-system, sans-serif',
    },
    spec: `A glossy candy-shell gradient fill on rounded pill buttons and cards, sprinkle and dot confetti motifs, a thick white outline, and a bubbly rounded typeface. Sweet, glossy, sugar-rush playful.`,
    palettes: [
      { id: 'bubblegum-candy', name: 'Bubblegum', spec: `Background #FFF0F6. Candy gradient #FF6FB0 into #FFB3D9. Text #3A1A2A.` },
      { id: 'lemon-candy', name: 'Lemon', spec: `Background #FFFBEB. Candy gradient #FFD93D into #FFF2A8. Text #3A3419.` },
      { id: 'grape-candy', name: 'Grape', spec: `Background #F5F0FF. Candy gradient #9B5DE5 into #C9A8FF. Text #2A1A3A.` },
    ],
  },
];

/**
 * The foundation screens nearly every app needs. A "style pack" renders all of
 * them in ONE style and ONE palette so they read as a single real app — same
 * colors, type, buttons, cards and spacing — not unrelated gallery pieces.
 */
export const PACK_SCREENS = [
  { slug: 'login', title: 'Login', platforms: ['mobile', 'web'], brief: 'a login screen with email and password fields, a primary sign-in button, a secondary social-login button with a small neutral circular icon glyph (no real brand logo) and "Continue with Google" label, and a small "Forgot password?" link' },
  { slug: 'signup', title: 'Sign Up', platforms: ['mobile', 'web'], brief: 'a sign-up screen with name, email and password fields, a password-strength hint, a terms checkbox, and a primary create-account button' },
  { slug: 'home', title: 'Home', platforms: ['mobile', 'web'], brief: 'a home screen with a greeting header and small avatar, a search bar, a horizontally scrolling row of featured cards, a section header with a "See all" link above a vertical list of content cards, and a five-icon bottom navigation bar with home active' },
  { slug: 'profile', title: 'Profile', platforms: ['mobile', 'web'], brief: 'a profile screen with a large centered avatar, name and username, a three-column stats row (posts, followers, following), a two-line bio, an edit-profile button, and a recent-activity list' },
  { slug: 'settings', title: 'Settings', platforms: ['mobile', 'web'], brief: 'a settings screen with grouped sections (Account, Preferences, About) of rows with icons and chevrons, toggle switches on the notifications and dark-mode rows, and a red sign-out row at the bottom' },
  { slug: 'search', title: 'Search', platforms: ['mobile', 'web'], brief: 'a search screen with a focused search bar, a "Recent searches" list with small clock icons and remove buttons, and a "Popular" section of tappable chips' },
  { slug: 'notifications', title: 'Notifications', platforms: ['mobile', 'web'], brief: 'a notifications screen with All/Mentions segmented tabs, notification rows grouped under "Today" and "This week" headers, each row with an avatar or icon, a message with the actor name in bold, a timestamp, and unread rows subtly highlighted' },
];

/** Build the prompt a MastUI user will copy into their AI coding tool. */
export function buildUserPrompt(screen, style, palette) {
  const fontLines = [];
  if (style.fontFamily) {
    if (style.fontFamily.heading) {
      fontLines.push(`- Headings / display: ${style.fontFamily.heading}`);
    }
    if (style.fontFamily.body && style.fontFamily.body !== style.fontFamily.heading) {
      fontLines.push(`- Body / labels: ${style.fontFamily.body}`);
    }
    if (style.fontFamily.mono) {
      fontLines.push(`- Monospace / data: ${style.fontFamily.mono}`);
    }
  }

  const platform = platformsFor(screen);
  const isWeb = platform.includes('web');
  const isMobile = platform.includes('mobile');
  let platformLine;
  if (isWeb && isMobile) {
    platformLine = 'This is a RESPONSIVE design — it should work on both mobile and desktop. Use mobile layout patterns (bottom nav, stacked content) for mobile, and desktop layout patterns (sidebar/nav bar, wider content areas) for web.';
  } else if (isWeb) {
    platformLine = 'This is a WEB/DESKTOP app screen. Use desktop layout patterns: navigation bar or sidebar, wider content areas, hover states on buttons, larger typography. Do NOT include mobile status bars or home indicators.';
  } else {
    platformLine = 'This is a MOBILE app screen. Use mobile layout patterns: bottom navigation bar, stacked content, touch-friendly tap targets.';
  }

  return [
    `Act like a frontend developer with 15 years of experience. I want the exact same UI with 95-99% similarity.`,
    ``,
    `Platform: ${platformLine}`,
    ``,
    `Design ${screen.brief}.`,
    ``,
    `Visual style — ${style.name}:`,
    style.spec,
    ``,
    `Color palette — ${palette.name}:`,
    palette.spec,
    ``,
    ...(fontLines.length > 0
      ? [
          `Typography — use these exact font families:`,
          ...fontLines,
          ``,
        ]
      : []),
    `Commit fully to this style — it should be unmistakable at a glance. Use realistic content, not placeholder text. Keep animations smooth (200ms ease-out).`,
  ].join('\n');
}

/** Build the instruction sent to Claude to render this prompt as a mobile screenshot-able page. */
export function buildRenderPrompt(userPrompt) {
  return [
    userPrompt,
    ``,
    `---`,
    `Output requirements (these apply to your response only, not to the design):`,
    `- Return a single complete HTML document, nothing else. No markdown fences, no commentary before or after.`,
    `- All CSS inline in one <style> tag. No external requests of any kind: no CDN links, no web fonts, no remote images, no scripts. Use only system-available font families as specified in the Typography section above.`,
    `- The page renders at exactly 390x844 (iPhone viewport). The body must be exactly that size with no scrolling and no margin. This is a MOBILE APP — use mobile layout patterns (bottom nav, stacked content, touch-friendly targets).`,
    `- Draw icons as inline SVG, styled to match the design above (stroke weight, fill and shape are part of the style — do not default to thin outlines). Represent photos/illustrations as placeholder blocks with correct proportions, tinted to fit the palette — never <img> tags.`,
    `- Include a realistic status bar (time, signal, wifi, battery) at the top and a home indicator at the bottom, both tinted to suit the palette.`,
    `- Use realistic placeholder content — real-sounding names, prices and copy. Never lorem ipsum, never "Label 1".`,
    `- This is a static screenshot: render one polished default state. No JavaScript.`,
  ].join('\n');
}

/** Build the instruction sent to Claude to render this prompt as a web/desktop screenshot-able page. */
export function buildWebRenderPrompt(userPrompt) {
  return [
    userPrompt,
    ``,
    `---`,
    `Output requirements (these apply to your response only, not to the design):`,
    `- Return a single complete HTML document, nothing else. No markdown fences, no commentary before or after.`,
    `- All CSS inline in one <style> tag. No external requests of any kind: no CDN links, no web fonts, no remote images, no scripts. Use only system-available font families as specified in the Typography section above.`,
    `- The page renders at exactly 1440x900 (desktop browser viewport). The body must be exactly that size with no scrolling and no margin. This is a WEB/DESKTOP APP — use desktop layout patterns: navigation bar or sidebar, wider content areas, hover states visible on buttons, larger typography.`,
    `- Do NOT include mobile status bars or home indicators. This is NOT a mobile app.`,
    `- Draw icons as inline SVG, styled to match the design above (stroke weight, fill and shape are part of the style — do not default to thin outlines). Represent photos/illustrations as placeholder blocks with correct proportions, tinted to fit the palette — never <img> tags.`,
    `- Use realistic placeholder content — real-sounding names, prices and copy. Never lorem ipsum, never "Label 1".`,
    `- This is a static screenshot: render one polished default state. No JavaScript.`,
  ].join('\n');
}

/**
 * Expand every category x screen x style into a flat catalog.
 *
 * Palette is not part of the id — it rotates deterministically across screens so
 * that neighbouring cards in the app's grid never share a color story, while the
 * item count stays at screens x styles.
 *
 * Each screen that targets multiple platforms produces separate catalog items
 * (e.g. `login-modern-minimalist` for mobile, `login-modern-minimalist-web` for web)
 * so each gets its own viewport-optimized HTML and screenshot.
 */
export function buildCatalog({ categories = CATEGORIES, styles = STYLES } = {}) {
  const items = [];
  let screenIndex = 0;

  for (const category of categories) {
    for (const screen of category.screens) {
      const screenPlatforms = platformsFor(screen);
      styles.forEach((style, styleIndex) => {
        // Offset by style so each style starts on a different palette.
        const palette = style.palettes[(screenIndex + styleIndex) % style.palettes.length];
        const userPrompt = buildUserPrompt(screen, style, palette);
        const baseId = `${category.id}-${screen.slug}-${style.id}`;

        for (const platform of screenPlatforms) {
          const isWeb = platform === 'web';
          items.push({
            id: isWeb ? `${baseId}-web` : baseId,
            title: `${style.name} ${screen.title}`,
            category: category.name,
            platforms: [platform],
            styleId: style.id,
            styleTags: [...style.tags, palette.name],
            palette: palette.id,
            prompt: userPrompt,
            ...(style.fontFamily ? { fontFamily: style.fontFamily } : {}),
            renderPrompt: isWeb ? buildWebRenderPrompt(userPrompt) : buildRenderPrompt(userPrompt),
          });
        }
      });
      screenIndex++;
    }
  }
  return items;
}

/**
 * Expand every style into a "style pack": the PACK_SCREENS rendered in that
 * style's first palette. One palette per pack is the whole point — every screen
 * shares the same color story so the set reads as one app. (More packs per
 * style later = pick another palette here.)
 *
 * Each screen that targets multiple platforms produces separate pack items.
 */
export function buildPacks({ styles = STYLES } = {}) {
  return styles.map((style) => {
    const palette = style.palettes[0];
    const screens = PACK_SCREENS.flatMap((screen, order) => {
      const screenPlatforms = platformsFor(screen);
      const userPrompt = buildUserPrompt(screen, style, palette);
      const baseId = `${style.id}-${screen.slug}`;

      return screenPlatforms.map((platform) => {
        const isWeb = platform === 'web';
        return {
          id: isWeb ? `${baseId}-web` : baseId,
          packId: style.id,
          packName: style.name,
          order,
          title: `${style.name} ${screen.title}`,
          category: screen.title,
          platforms: [platform],
          styleId: style.id,
          styleTags: [...style.tags, palette.name],
          palette: palette.id,
          prompt: userPrompt,
          ...(style.fontFamily ? { fontFamily: style.fontFamily } : {}),
          renderPrompt: isWeb ? buildWebRenderPrompt(userPrompt) : buildRenderPrompt(userPrompt),
        };
      });
    });
    return { id: style.id, name: style.name, tags: style.tags, palette, screens };
  });
}
