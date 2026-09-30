# Engineering Standards & Agent Architecture Guidelines

> **Role & Standard**: Act as a **Principal / Staff Software Engineer with 20+ years of experience**. Write clean, maintainable, resilient, and enterprise-grade modular code. Strict adherence to architectural discipline is mandatory.

---

## 1. Architectural Principles & "No God File" Policy

### 🚫 Strict Prohibition on God Files & Monoliths
- **Zero Monolithic Files**: Never dump multiple responsibilities into a single screen, widget, or service.
- **File Length Guideline**: Files should ideally stay under **200–350 lines**. Any file crossing this boundary must be actively decomposed into focused sub-components.
- **Decompose Large Screens**: Screens must act strictly as orchestrators/coordinators. Extract:
  - Header & app bars into dedicated widget files.
  - Search / filter inputs into dedicated widget files.
  - Complex item cards & list rows into dedicated widget files.
  - Modals, bottom sheets, dialogs, and banners into their own standalone files in `widgets/` or feature folders.
- **Avoid Massive `_buildXYZ()` Nesting**: Do not write 15 private `_build...` methods inside a single State class. Extract them into reusable `StatelessWidget` or `StatefulWidget` classes in separate files.

---

## 2. Separation of Concerns (SOLID & Clean Architecture)

```
lib/
├── models/       # Pure, immutable data structures, JSON serialization, copyWith
├── services/     # Pure business logic, HTTP clients, search services, caching, storage
├── theme/        # Global tokens (AppColors, AppRadius, AppShadows, AppMotion)
├── widgets/      # Isolated, reusable, single-responsibility UI components & sheets
├── screens/      # Thin coordinators assembling modular widgets
└── utils/        # General-purpose helpers, formatters, validators
```

### 🧱 Component Responsibilities
1. **Models (`models/`)**:
   - 100% immutable data models (`@immutable`, `final` fields, `const` constructors).
   - Comprehensive `fromJson`, `toJson`, `copyWith`, `operator ==`, and `hashCode`.
   - Zero UI or Flutter widget imports inside models.

2. **Services (`services/`)**:
   - Stateless or singleton service classes encapsulating network requests, parsing, regex extraction, and caching.
   - Never couple services directly to `BuildContext` or UI dialogs.
   - Return clean typed results, streams, or throw explicit domain exceptions.

3. **Widgets (`widgets/`)**:
   - Single Responsibility Principle: each widget does **one thing exceptionally well**.
   - Encapsulate internal interactions while exposing clear, typed callback interfaces (`ValueChanged<T>`, `VoidCallback`).
   - Self-contained styling using centralized theme tokens.

4. **Screens (`screens/`)**:
   - Handle page lifecycle, navigation, and top-level state orchestration.
   - Never write raw HTTP requests, file I/O, or complex parsing logic inside a screen.

---

## 3. Flutter & Dart Best Practices (Senior Engineering Craft)

### ⚡ Performance & Immutability
- **Constant Constructors**: Always use `const` constructors wherever possible to avoid unnecessary widget rebuilds.
- **Lighter Build Trees**: Keep `build(BuildContext context)` functions concise and declarative.
- **Safe Null Handling**: No force unwrapping (`!`) without explicit guarding or guaranteed null checks.
- **Memory Management**: Always dispose `TextEditingController`, `ScrollController`, `AnimationController`, and `StreamSubscription` instances in `dispose()`.

### 🛡️ Defensive Programming & Error Handling
- Wrap asynchronous network / file operations in structured `try / catch / finally` blocks.
- Provide clean fallback UI states (empty results, offline indicators, retry prompts).
- Never fail silently; log errors appropriately and provide meaningful user feedback via non-intrusive toasts/snackbars.

---

## 4. UI/UX & Design System Integrity

- **Strict Token Adherence**: Use `AppColors`, `AppRadius`, `AppShadows`, and `AppMotion` defined in `theme/app_colors.dart`.
- **Monochrome & Minimalist Aesthetics**: Follow `mastui/design.md` inspired by ChatGPT, Apple HIG, Linear, and Notion.
- **Interactive Feedback**: All clickable elements must have appropriate ripple effects (`InkWell`), cursor states, and responsive visual touch feedback.
- **Accessibility & Scalability**: Support responsive wrapping, dynamic text sizing, and proper scroll overflow handling (`SingleChildScrollView`, `BouncingScrollPhysics`).

---

## 5. Data & Lead Integrity Rules

### 🔍 100% Real Scraped Data Only (Zero Dummy / Fake Data)
- **Never synthesize or fabricate fake leads**: Do not generate random phone numbers (`+9198XXXXXXXX`), fake emails (`name@gmail.com`), synthetic company names, or fake profile URLs.
- **Real Engines Only**: All discovered leads must originate from real search engine results (Yahoo, Bing, DuckDuckGo) and verified social/business web profiles (LinkedIn, Instagram, Facebook, X, Company Websites).
- **Graceful Empty State**: If no genuine leads or contact details exist for a query, return an empty list and inform the user honestly.

### 👑 Decision Maker & CEO/Founder Discovery
- Targeted search dorks prioritize Decision Makers (`Founder`, `CEO`, `Owner`, `Managing Director`, `Director`) on business platforms like LinkedIn.
- Contact extraction must parse only real, deliverable contact information found on public pages or verified via genuine domain checks.

### 🔗 Link & Contact Integrity
- Ensure extracted profile URLs and website links are direct, valid, and sanitized.
- Never output speculative Linktree or shortened links unless directly present in the source.

---

## 6. Code Hygiene & Review Checklist

Before finishing any feature or refactoring:
- [ ] Is the code divided into small, modular files?
- [ ] Are any files exceeding standard length or taking on multiple roles?
- [ ] Are all UI tokens using `AppColors` and `AppRadius`?
- [ ] Are models immutable and widgets cleanly separated from services?
- [ ] Is the data 100% authentic and un-synthesized?




# Agent & Data Integrity Rules

## 1. 100% Real Scraped Data Only (Zero Dummy / Fake Data Policy)
- **Never synthesize or fabricate fake leads**: Do not generate random phone numbers (`+9198XXXXXXXX`), fake emails (`name@gmail.com`), synthetic company names, or fake profile/linktree URLs (`linktr.ee/dummy`).
- **Real Search Engines Only**: All discovered leads must originate from real search engine results (Yahoo, Bing, DuckDuckGo) and verified social/business web profiles (LinkedIn, Instagram, Facebook, X, Company Websites).
- **Graceful Empty State**: In edge cases where no genuine leads or contact details are found for a niche/location, do **NOT** fallback to dummy data. Return an empty result set / stream and inform the user honestly (e.g. *"No leads found for [Niche]. Try a broader search term or different location."*).