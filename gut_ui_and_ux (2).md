# Dr Gut – UI/UX Spec (for Antigravity agent)

> **Instruction to the agent:** Apply this visual design system to every screen described in `gut_complete_implementation.md`. This file defines colors, typography, components and per-screen layout. Do not change the functional behavior, fields, or flow defined in the implementation file — only the visual styling. This replaces any earlier dark/green design direction for Dr Gut.

**Design direction:** light, editorial, premium "studio" feel — warm off-white background, deep olive-green as the one accent, a mix of a characterful display serif for headlines and a clean sans for everything else, pill-shaped buttons, generous whitespace, small tracked-letter-spacing labels. Inspired by a modern agency/studio landing page.

---

## 1. Color Palette

| Token | Hex | Use |
|---|---|---|
| `background` | `#F4F2EA` | App background (warm off-white/cream) |
| `surface` | `#FFFFFF` | Card background, raised above the cream base |
| `surfaceBorder` | `#DAD6C8` | 1px border on cards, fields, outline buttons |
| `primary` (deep olive) | `#262B1C` | Primary button fill, headings, logo mark, dark section backgrounds |
| `accent` (lime) | `#C9F031` | Text/icon on `primary`, highlight accents, bold callout-block fill |
| `onPrimary` | `#C9F031` | Text/icons placed on the dark olive button or a dark section |
| `onAccent` | `#1C2012` | Text/icons placed on the lime callout block |
| `textPrimary` | `#1C1C16` | Headings, primary body text (on the cream background) |
| `textOnDark` | `#EDEBDD` | Body text on a dark olive section |
| `textSecondary` | `#6B6A5E` | Labels, captions, tracked small headings |
| `textMuted` | `#9C9A8C` | Disabled text, placeholder, footnotes |
| `error` | `#C1443A` | Validation errors, warnings |
| `divider` | `#E4E1D4` | Hairlines between sections |
| `footerDark` | `#1C2012` | Dark olive footer/section background |

Flutter `ColorScheme`:
```dart
final scheme = ColorScheme.light(
  surface: const Color(0xFFF4F2EA),
  surfaceContainer: const Color(0xFFFFFFFF),
  primary: const Color(0xFF262B1C),
  onPrimary: const Color(0xFFC8F04C),
  onSurface: const Color(0xFF1C1C16),
  outline: const Color(0xFFDAD6C8),
  error: const Color(0xFFC1443A),
);
```

---

## 2. Typography

- **Display font (headlines only):** an elegant, slightly decorative serif — e.g. `Fraunces` or `Playfair Display` (via `google_fonts`), used sparingly for the biggest heading on a screen, echoing the reference's "DUNA" wordmark and "into the world of tech" display line.
- **Body/UI font:** a clean grotesk sans — e.g. `Inter` or `Manrope` — used for everything else: labels, buttons, body copy, form fields.
- Add via `google_fonts`: `GoogleFonts.fraunces(...)` for display, `GoogleFonts.interTextTheme()` as the base text theme.

| Style | Font | Size | Weight | Color | Use |
|---|---|---|---|---|---|
| Display | Fraunces | 30sp | Regular/Italic | `textPrimary` | The one big headline per screen (e.g. "Let's build your plan") |
| Title | Inter | 19sp | SemiBold (600) | `textPrimary` | Section headers, card titles |
| Eyebrow label | Inter | 12sp | Medium (500), letter-spacing 1.2 | `textSecondary`, UPPERCASE | Small tracked tag above a headline (mirrors "ADVANCED WEB, APP & AI DEVELOPMENT") |
| Body | Inter | 15sp | Regular (400) | `textPrimary` | Form input text, paragraph copy |
| Label | Inter | 13sp | Medium (500) | `textSecondary` | Field labels, captions, tab labels |
| Caption | Inter | 12sp | Regular (400) | `textMuted` | Timestamps, helper text, disclaimer |

Line height: 1.3–1.4x for body/labels; 1.1x for the Display style to keep headlines tight, matching the reference's compact serif line-spacing.

---

## 3. Components

### Buttons
- **Primary button (filled):** full-width or intrinsic-width pill (`borderRadius: 28`), height 56, solid `primary` (deep olive) fill, label text in `onPrimary` (lime), semi-bold 16sp — directly mirrors the reference's dark "Request a project" button.
- **Secondary button (outline):** pill shape, transparent fill, 1.5px `textPrimary`-colored border, label text in `textPrimary` — mirrors "View references."
- **Icon button (circular, outline):** 48×48 circle, transparent fill, 1px `surfaceBorder`, icon in `textPrimary` (used for the hamburger-style menu in the reference; in Dr Gut, used for the GPS refresh button and similar small actions).
- **Pill toggle/chip (e.g. "pause" control in the reference):** small pill, `surface` fill, 1px `surfaceBorder`, icon + label in `textPrimary`. Reused in Dr Gut for the 1-day/7-day segmented control's unselected state.

### Cards
- Background `surface` (pure white against the cream page background), `borderRadius: 20`, 1px `surfaceBorder`, very soft shadow (black 6% opacity, blur 16, offset y 6) — much lighter than a dark-theme card shadow, since the base page is already light.
- Padding: 16–20px all sides.

### Text fields
- Background `surface`, `borderRadius: 14`, 1px `surfaceBorder` (becomes `primary`-colored on focus, 1.5px), label in `textSecondary` above the field, prefix icon in `textSecondary` (turns `primary` on focus). Cursor/selection color: `primary`.

### Bottom sheet (report upload picker)
- `surface` background, top corners `borderRadius: 24`, a small centered drag-handle bar in `surfaceBorder`. Two tappable rows ("Import from device," "Use camera"), each with a small circular icon badge: `primary` at 10% opacity fill, `primary`-colored icon.

### Eyebrow tag (small label with icon, like "✦ ADVANCED WEB, APP & AI DEVELOPMENT")
- A small leading glyph/icon in `primary`, followed by uppercase tracked `textSecondary` label text — used once at the top of the Landing page and optionally above each screen's Display headline.

### Progress / loading indicator
- A simple circular spinner or a slim horizontal progress line in `primary`, on the cream background — no glow effect here (glow belonged to the previous dark theme); keep it understated, matching the reference's calm, confident tone.

### Segmented button (1-day / 7-day toggle)
- Pill-shaped container, `surface` fill with `surfaceBorder` outline; selected segment fills solid `primary` with `onPrimary` (lime) text; unselected segment text in `textSecondary`.

### Dark section block
- A full-width `primary` (deep olive) background block used sparingly to break up the cream page — mirrors the reference's dark "DUNA is a digital agency…" and code-preview sections. Text inside uses `textOnDark`/`onPrimary`, headings still in the Display serif. Use at most once per screen (e.g. a single dark highlight block on the Landing page or the Plan screen's summary), never as the default background.

### Lime callout block
- A full-width `accent` (lime) background block with `onAccent` (near-black) text — mirrors the reference's bold "Not an oracle. A tool." section. Reserved for one key message per flow at most; in Dr Gut this suits a single standout line on the Landing page (e.g. "Not a diet fad. A plan built from your own numbers.") — optional, skip if it feels like too much for a course build.

### Stat row
- A horizontal row of 3–4 short stat pairs — a bold large number (Title style, `primary` or `onPrimary` depending on background) above a small Caption label — mirrored from the reference's "40+ / 10 / <24h / 100%" row. Optional use on the Landing page, e.g. showing something like a report-read time or number of local foods considered, if real numbers exist; omit rather than inventing fake stats.

### Logo mark
- A small evergreen/fir-tree style glyph (✦ or a simple leaf icon) in `primary`, paired with the wordmark "Dr Gut" set in the Display serif — used on the Landing screen in place of the reference's "DUNA" wordmark + icon pairing.

---

## 4. Screen-by-Screen Styling

### 4.1 Landing page
- Background: `background` (cream), full light theme — no dark overlay behind the hero content itself.
- Top: small logo mark + "Dr Gut" wordmark in Display serif, left-aligned, similar weight/position to "DUNA" in the reference.
- Eyebrow tag: `✦ PERSONALISED NUTRITION, FROM YOUR OWN REPORT` in tracked uppercase `textSecondary`.
- Headline: large Display-serif, two-toned like the reference — e.g. first line in a bold sans/serif mix: **"Your diet plan,"** then a lighter/italic serif line: *"built around you."* (Keep this to 2 short lines so it reads well on a phone.)
- Subtext: Body style, `textSecondary`, 2–3 lines explaining the value prop (report + location → local diet plan).
- Buttons stacked: primary filled pill **"Get Started"**, then a secondary outline pill **"Learn more"** underneath it (optional second action), exactly mirroring the reference's "Request a project" / "View references" pairing.
- Optional decorative element: a soft photographic or abstract image in the hero area (the reference uses a desert landscape under the headline) — for Dr Gut, a muted food/ingredient photo or a simple abstract shape works; keep it subtle and out of the way of the buttons.
- Optional dark section lower on the page (per the "Dark section block" in §3): a short statement in `textOnDark` explaining how it works in one or two lines, mirroring the reference's "DUNA is a digital agency…" block — skip for a minimal build.

### 4.2 Home screen
- Background: `background`. `AppBar` transparent, title "Dr Gut" in Title style (Inter, not the display serif, to keep the app bar restrained), a circular outline icon button (profile/edit) on the trailing edge — styled per the icon-button spec in §3.
- Greeting: Display-serif headline, e.g. *"Welcome back"* (shorter than the Landing headline, since this is a utility screen).
- Last-plan summary: a `surface` `Card` with an icon badge, a Title-style line (plan status), and Body-style secondary text underneath.
- Actions: primary filled pill **"Create a new plan"**, secondary outline pill **"View my plan"** (disabled state until a plan exists — reduce opacity to ~40% and keep the outline, rather than removing the border).

### 4.3 Profile screen
- Background: `background`, plain — no ambient glow (that was specific to the previous dark theme).
- Header: Eyebrow tag *"YOUR PROFILE"* above a Display-serif heading **"Let's build your plan."**
- Each form field styled per §3 (Text fields), stacked with 14px spacing, all on `surface` white cards against the cream page.
- Location card: `surface` `Card`, small `primary`-tinted location-pin icon badge, place name in Body style, refresh `IconButton` on the trailing edge (plain `textSecondary` icon, no circular background needed here — keep this one lightweight since it sits inside a card already).
- Plan-length segmented control per §3.
- Report upload tile: `surface` `Card`, cloud icon badge, label text; once chosen, file icon + filename + "Replace" in `primary`.
- Primary button pinned at the bottom: solid `primary` fill, `onPrimary` (lime) label text, full width.

### 4.4 Report upload bottom sheet
- Styled per §3's bottom sheet spec — cream-adjacent white sheet, drag handle, two rows with small olive icon badges ("Import from device," "Use camera").

### 4.5 Loading state
- Centered on `background`: a simple `primary`-colored circular spinner (no glow ring — that belonged to the prior dark theme), with Label-style status text beneath it in `textSecondary`, cycling through the four status strings from the implementation spec.

### 4.6 Plan screen
- `AppBar`: transparent, cream background, title "Your Plan" in Title style, a circular outline share/copy icon button on the trailing edge.
- Summary block: Eyebrow tag *"OVERVIEW"*, then a `surface` `Card` with the Body-style summary paragraph.
- "Findings from your report": stacked `surface` cards, each with a small `error`-tinted icon badge (10% opacity fill), nutrient name in Body/SemiBold, finding text in Caption/`textSecondary` underneath.
- Day cards: one `surface` `Card` per day, Title-style day label, a `divider` hairline, then each meal as a row — time in `primary`/Label-SemiBold, items in Body, "why" in Caption/`textMuted`.
- "Local tips" card: `surface` card with a small storefront/leaf icon badge and Body text.
- Disclaimer: Caption style, `textMuted`, centered, extra top padding at the very bottom.
- Optional: a slim dark `footerDark` bar at the very bottom of the scroll (mirroring the reference's dark footer strip) showing a small "Dr Gut" mark and the plan's date — purely decorative, skip if it adds unnecessary complexity for a course build. The reference's giant oversized "DUNA" wordmark footer is a marketing-site flourish, not applicable to a utility app screen — skip it entirely for Dr Gut.

### 4.7 Not used from the reference
The full reference is a marketing/agency website and includes several sections that don't map to Dr Gut's functional app and should be **skipped**: the services navigation bar, the code-preview panel, the "All disciplines" feature grid, the client results list, the FAQ accordion, and the long contact form. Dr Gut borrows only the color palette, typography pairing, button/card styling, and the optional dark-section/lime-callout treatment described above — not the marketing page structure itself.

---

## 5. Motion

- Screen transitions: standard Material fade-through, 220ms (slightly quicker/lighter than a dark-theme app, to match the airy feel).
- Button press: subtle scale-down to 0.97 on tap.
- Loading spinner: simple continuous rotation, no pulsing glow.
- Bottom sheet: slide up, 280ms, standard ease-out (no overshoot — keep it calm and editorial rather than bouncy).

---

## 6. Assets and Icons

- Icon set: `Icons` (Material Symbols, **outlined** variant) in `textPrimary` or `primary` depending on context — thin, light-weight icons to match the reference's restrained line-art feel (the fir-tree glyph, the thin menu lines).
- No photography/illustration required for Dr Gut's functional screens; reserve any decorative imagery (like the reference's fabric graphic) for the Landing page only, and keep it subtle.

---

## 7. Flutter Setup Notes

- Add to `pubspec.yaml`: `google_fonts: ^6.2.1` (already a dependency; just add `Fraunces` usage alongside the existing `Inter`/body font — no new package needed).
- Define the color scheme and two text styles (display serif + body sans) once in `theme.dart` and apply via `ThemeData(colorScheme: scheme, textTheme: ...)`, with the Display style applied explicitly per-headline (`GoogleFonts.fraunces(...)`) since Flutter's default `TextTheme` only supports one font family at a time.
- Keep all colors as named theme tokens — never hardcode hex values inside widgets, so the palette can be swapped later from one place, same discipline as the previous design system.
- This is a full palette swap from the earlier dark/green AI-assistant direction — if both are kept for reference, name this one `DrGutColors` (replacing the old values in place) or `DrGutLightColors` if you want to preserve the dark version as an alternate theme.
