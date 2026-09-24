# Design System

## Philosophy

This app follows a premium, minimal design language inspired by:

- ChatGPT
- Apple Human Interface Guidelines
- Linear
- Notion

The interface should feel calm, modern, intelligent, and effortless.

Never use flashy gradients, heavy shadows, oversized icons, or excessive colors.

The UI should prioritize whitespace, typography, hierarchy, and subtle animations over decoration.

---

# Core Principles

1. Less is more.
2. Every element must have a purpose.
3. Prefer whitespace over borders.
4. Avoid visual clutter.
5. Use smooth motion, never distracting animations.
6. Everything should feel premium.
7. No helper text. No redundant descriptions.
8. Minimal text per screen. Say more with less.
9. No fancy multiple icons. One icon, one clear meaning.

---

# Text Minimalism

Every screen should have minimum text.

No helper text under inputs or labels.

No duplicate text saying the same thing.

One heading. One description max. Then content.

If text can be removed without losing meaning, remove it.

---

# Color System

## Background

Primary Background
#FFFFFF

Secondary Background
#F7F7F8

Surface
#FFFFFF

Card
#FFFFFF

Divider
#ECECEC

---

## Text

Primary
#111111

Secondary
#666666

Muted
#8A8A8A

Disabled
#BDBDBD

---

## Primary Action / CTA

Primary CTA (ChatGPT signature filled button)
#000000 (Pure Black)

On Primary CTA
#FFFFFF (Pure White)

Primary Hover / Pressed
#222222

---

## Secondary Accents

Secondary Green (OpenAI Iconic Teal)
#10A37F

Secondary Green Hover
#0D8C6B

Secondary Blue (Interactive / Accent)
#0066FF

Secondary Blue Hover
#0052CC

Success
#10A37F

Warning
#F5A623

Danger
#E5484D

Never use multiple dominant accent colors in one screen. Use pure black for the primary CTA, and green/blue for secondary actions and subtle status badges.

---

# Corner Radius

Buttons
14px

Cards
18px

Dialogs
20px

Bottom Sheets
28px

Input Fields
14px

Images
16px

---

# Shadows

Avoid heavy shadows.

Use extremely soft elevation.

Example

0 2 12 rgba(0,0,0,0.05)

or

0 4 20 rgba(0,0,0,0.04)

---

# Typography

Use Inter.

Weights

Regular 400

Medium 500

SemiBold 600

Bold 700

Never use more than four font sizes on one screen.

Display
32

Title
24

Heading
20

Body
16

Caption
14

Small
12

Line height should always feel spacious.

---

# Spacing

Use an 8-point grid.

Allowed spacing

4

8

12

16

20

24

32

40

48

64

Never invent random spacing values.

---

# Buttons

Primary CTA

Filled

Pure Black (#000000)

Pure White text (#FFFFFF)

Height

52px

Radius

14px

Secondary Button (Outlined / Surface)

White or subtle background (#F7F7F8)

Subtle gray border (#ECECEC)

Dark text (#111111)

Secondary Action / Accent Button

Green (#10A37F) or Blue (#0066FF) outlined / tonal

Soft tint background with crisp accent text / icon

Height

52px (or 48px compact)

Radius

14px

Text Button

No border

Accent text (Green #10A37F or Blue #0066FF or Muted #666666)

Never use gradients.

---

# Inputs

Height

52px

Rounded corners

14px

Soft gray background

No hard borders.

Focus should use the accent color.

---

# Cards

Cards should:

have lots of padding

soft corners

minimal shadow

no unnecessary outlines

avoid multiple nested cards

---

# Icons

Use Lucide icons.

Size

20 or 24

Stroke width

2

Never mix icon styles.

One icon per action. No decorative multiple icons.

---

# Lists

Generous vertical spacing.

Each item should breathe.

Avoid dense layouts.

---

# Navigation

Bottom navigation should be simple.

No floating colorful effects.

Active item uses accent color.

Inactive items use muted gray.

---

# Animations

Duration

200–300ms

Use easeInOut.

Use fade, scale, or slide.

Never bounce.

Never over animate.

---

# Images

Rounded corners.

Consistent aspect ratios.

No decorative frames.

---

# Empty States

Every empty state should include:

simple icon

clear title

one action

No long explanations.

---

# Loading

Prefer skeleton loading.

Avoid full-screen spinners.

---

# Error States

Short error message.

One clear action.

No long explanations.

---

# Accessibility

Minimum touch target

44x44

Contrast should remain high.

Support dynamic text.

---

# Screen Layout

Every screen follows:

Top App Bar

↓

Page Title

↓

Primary Content

↓

Primary CTA

Use generous whitespace between sections.

No optional descriptions. Minimal text only.

---

# Responsiveness & Scroll Safety

Every screen, modal dialog, and bottom sheet must be 100% responsive and scroll-safe across all screen dimensions, landscape orientations, and system display zoom / font size settings.

## Rules:

1. **Never use naked Columns with fixed height or Spacer() without scroll protection:**
   - Always wrap screen bodies with `LayoutBuilder` + `SingleChildScrollView` + `ConstrainedBox(minHeight: constraints.maxHeight)` + `IntrinsicHeight` when elements need to stretch or pin actions to the bottom.
   - This ensures content expands naturally on large screens while smoothly scrolling on smaller phones (5–5.5 inches), split-screen, or landscape mode without `RenderFlex overflowed` errors.

2. **Modal Bottom Sheets must be Constrained & Scrollable:**
   - Always pass `isScrollControlled: true` to `showModalBottomSheet`.
   - Constrain maximum height via `ConstrainedBox(constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88))`.
   - Wrap dynamic/scrollable items in `Flexible(child: SingleChildScrollView(physics: const BouncingScrollPhysics(), ...))`.
   - Keep primary action buttons pinned at the bottom with a subtle divider so they remain immediately accessible.

3. **Dialogs & Confirmation Prompts:**
   - Dynamic or variable text in dialogs must be scroll-safe.
   - Maintain `insetPadding` (e.g. horizontal 24px) so dialogs never clip against viewport edges.

4. **Accessibility Font Scaling:**
   - Support system font scaling (>1.2x). Buttons, badges, and titles should use appropriate line wrapping or `TextOverflow.ellipsis` where single-line constraint is essential.
   - Never hardcode fixed viewport assumptions (e.g., assuming height is always >= 800px).

---

# DO

✓ Minimal

✓ Premium

✓ Calm

✓ Spacious

✓ Consistent

✓ Apple quality

✓ ChatGPT style

✓ Linear style

✓ Professional

✓ 100% Scroll-safe & responsive on all screen sizes

---

# DON'T

✗ Glassmorphism

✗ Neon colors

✗ Heavy gradients

✗ Large drop shadows

✗ Rounded blobs everywhere

✗ Material 3 colorful defaults

✗ Inconsistent spacing

✗ Different button styles

✗ Random font sizes

✗ Crowded layouts

✗ Naked Columns with Spacer() without scroll protection

✗ Fixed height assumptions causing RenderFlex overflows

✗ Helper text under inputs

✗ Multiple icons saying same thing

✗ Redundant text descriptions

✗ More than 2-3 lines of text per screen

---

# AI Instructions

Whenever creating a new screen:

- Reuse existing components whenever possible.
- Maintain identical spacing patterns.
- Do not invent new colors.
- Follow the typography scale.
- Keep interfaces minimal.
- Optimize for readability first.
- Every screen should look like it belongs in the same product.
- Always make screens and bottom sheets 100% responsive and scroll-safe (using LayoutBuilder + SingleChildScrollView + ConstrainedBox / Flexible) to guarantee zero RenderFlex overflow bugs on small devices, landscape, or high font-scaling modes.
- If unsure, choose the simpler option.
- No helper text under any input or label.
- Use minimum text. Say more with less.
- One icon per element. No fancy multiple icons.
- Primary CTA is always pure black (#000000) with white text. Secondary CTAs and accents use OpenAI green (#10A37F) and blue (#0066FF).
- The result should resemble a premium Apple-quality productivity app with the calm, high-contrast visual language of ChatGPT.