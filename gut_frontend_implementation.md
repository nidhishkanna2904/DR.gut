# Dr Gut – Frontend Implementation (Detailed)

> **Instruction to the agent:** This file gives the frontend code directly (`theme.dart`, `main.dart`) plus a full explanation of every part. Use it together with `gut_implemetation.md` (functional spec) and `gut_ui_and_ux.md` (design system) — this file is what turns those two into real, running screens. Wire the marked `// NOTE:` comments to the real services from `gut_implemetation.md` when the backend is ready; everything else can be used as-is.

---

## 1. Approach

The frontend is built as **three layers**, kept strictly separate so each can change without breaking the others:

1. **Design layer (`theme.dart`)** — every color, font size, and two reusable styled widgets. No screen ever writes a hex code or a `TextStyle` by hand; they all pull from here through `Theme.of(context)` or the `DrGutColors` constants. Changing the whole app's look later means editing one file, not twenty.
2. **Screen layer (`main.dart`)** — `ProfileScreen`, `LoadingScreen`, `PlanScreen`. Each is a `StatefulWidget` holding only the state it needs (text controllers, a location string, a selected file name, loading flags). No networking or GPS code lives inside the screens directly — they call out to clearly marked integration points instead.
3. **Integration layer (marked `// NOTE:` comments)** — every place that should eventually talk to GPS, the file picker/camera, or the backend currently runs a short `Future.delayed` mock instead of the real call. This is intentional: it lets you build, run, and screenshot the **entire app right now**, on any machine, with zero setup (no location permission prompts, no backend server, no API key) — then swap in the three real calls in one pass once the backend is ready, without touching any layout code.

This is the same order a professional Flutter team would use: **static layout → interactive state → real data**, each step independently testable.

---

## 2. `lib/theme.dart` — Design Layer, in Detail

### `DrGutColors`
A plain class of `static const Color` values — one per design token from `gut_ui_and_ux.md` (background, surface, surfaceBorder, primary, primaryGradientEnd, onPrimary, textPrimary, textSecondary, textMuted, error, divider), plus `primaryGradient`, a `LinearGradient` combining `primary` → `primaryGradientEnd` used on every main button.

Why a plain class instead of an enum or a theme extension: it's the simplest thing that works for a course project, and every value is reachable as `DrGutColors.primary` from anywhere with a single import — no `BuildContext` required, which matters for the gradient definitions that live outside `build()` methods.

### `buildDrGutTheme()`
Returns one `ThemeData` built like this:
- Starts from `ThemeData.dark(useMaterial3: true)` as a base so all the built-in Material widgets (checkboxes, snackbars, etc.) already look reasonable in dark mode.
- Replaces the text theme with `GoogleFonts.poppinsTextTheme(...)`, then forces `bodyColor`/`displayColor` to `textPrimary` so text is never invisible against the dark background.
- Sets `scaffoldBackgroundColor` to the near-black `background` token.
- Overrides `colorScheme.primary`, `onPrimary`, `error`, and `outline` so any default Material component (like a `Switch` or `Checkbox` if you add one later) automatically matches the palette.
- Defines `appBarTheme` as transparent/flat (no shadow, no tint) so the app bar blends into the background rather than sitting on a separate colored bar.
- Defines `inputDecorationTheme` **once**, centrally: filled with `surface`, 16px rounded corners, a `surfaceBorder`-colored outline normally, and a `primary`-colored, slightly thicker outline when focused. This is why every `TextFormField` in the app looks identical without repeating decoration code per field.
- Defines `cardTheme`: `surface` fill, no elevation/shadow property set here (the two callers that need a shadow — profile fields aren't cards, but the location/upload/plan cards are — add their own `BoxShadow` inline where the design system calls for the "floating glass" look), 20px rounded corners, `surfaceBorder` outline.
- Defines `dividerTheme` using the `divider` token, used inside the plan screen's meal list.

### `GradientPillButton`
A stateless widget wrapping the exact button style used everywhere a primary action exists (currently just "Analyze & create my diet plan," but reusable for any future primary CTA).

Internals:
- A `DecoratedBox` with the `primaryGradient` fill, `28px` corner radius (full pill at the 56px height used), and a soft green `BoxShadow` (35% opacity, 24px blur, offset down 10px) to create the glow the design system calls for.
- Inside, a `Material(color: Colors.transparent)` + `InkWell` so the button still gets a proper Material tap ripple/feedback despite the custom gradient background.
- Two mutually exclusive visual states, controlled by two constructor parameters:
  - `onPressed == null` → button is disabled; wrapped in `Opacity(0.5)`.
  - `loading == true` → the label text is replaced by a small `CircularProgressIndicator` in `onPrimary` color, and taps are ignored, but the button is **not** dimmed (so it doesn't look broken/disabled while genuinely working).
- Height is fixed at `56` to match the design system's button-height spec and to guarantee a comfortable 56px tap target.

### `IconChip`
A small stateless widget: a 40×40 circle, filled with the given color at 15% opacity, containing a 20px icon in the full-strength color. Used for every "badge" icon in the app — the location pin, the upload cloud, the bottom sheet's two option icons, and the plan screen's finding/tip icons. Takes an optional `color` override (defaults to `primary`) so the same widget can render the red-tinted warning icon on the plan screen's finding cards.

---

## 3. `lib/main.dart` — Screens, in Detail

### App root — `DrGutApp`
A `MaterialApp` with `debugShowCheckedModeBanner: false`, `theme: buildDrGutTheme()`, and `home: ProfileScreen()`. This is the only place the theme is attached — every descendant widget inherits it automatically.

### `ProfileScreen` — state and lifecycle
`StatefulWidget` holding:
- Six `TextEditingController`s: `_name`, `_phone`, `_disease`, `_allergies`, `_dislikes`, `_budget`.
- `_place` (`String`) — the currently displayed location text, starts as `'Detecting your location…'`.
- `_locating` (`bool`) — controls whether a small inline spinner or the refresh icon shows in the location card.
- `_planType` (`String`, `'day'` or `'week'`) — which segment is currently selected.
- `_reportName` (`String?`) — filename shown once a report has been "picked"; `null` means nothing uploaded yet.
- `_submitting` (`bool`) — drives the button's loading state and disables double-submits.

`initState()` immediately calls `_detectLocationMock()`, so the location card starts resolving the instant the screen appears — the user never has to tap anything to trigger it, matching the "auto-detected on screen open" requirement from the functional spec.

`_detectLocationMock()` — `// NOTE:` integration point #1. Currently: waits 900ms, then sets `_place` to a fixed example string and `_locating = false`. **Replace this method's body** with a real call to `LocationService.getCurrentLocation()` (from `gut_implemetation.md` §9), catching its typed exceptions (`GpsDisabled`, `PermissionDenied`, etc.) and setting `_place` to an error message with the manual-entry fallback in those cases.

`_pickReport()` — opens a `showModalBottomSheet` styled per the design system: `surface` background, top corners rounded 24px, a small centered drag-handle `Container`, then two `_sheetRow` entries built from a shared helper (so both rows are pixel-identical). Each row is a plain `ListTile` with an `IconChip` as the leading widget and the label as the title — deliberately simple, no extra decoration, so it reads as "part of the sheet" rather than as separate cards.

`_sheetRow()` — small private helper avoiding duplicated `ListTile` code between the two options.

`_submit()` — `// NOTE:` integration point #3.
1. Runs form validation (`_form.currentState!.validate()`); returns early if any required field fails.
2. Checks `_reportName != null`; if no report was picked, shows a `SnackBar` and returns — this enforces "report is required" purely in the UI layer before any network call would happen.
3. Sets `_submitting = true` (button shows its spinner).
4. Currently: `await Future.delayed(2 seconds)` standing in for the real network call.
5. Sets `_submitting = false` and pushes `PlanScreen`.
**Replace step 4** with `final plan = await ApiService.createPlan(profile, reportFile);` wrapped in try/catch (showing a `SnackBar` with a retry affordance on failure, per the functional spec's error-handling requirement), and pass the real `plan` into `PlanScreen(plan: plan)` instead of the current no-argument constructor with hardcoded placeholder content.

**Build method, top to bottom** (all inside a scrollable `ListView` with 20px horizontal / 24px top / 32px bottom padding, so the whole form scrolls as one column and never overflows on smaller phones):
1. `"Let's build your plan"` in `headlineSmall` — the display-style greeting.
2. `"Tell us a bit about you"` in `labelMedium`/`textSecondary` — the subtext, 6px below the heading.
3. 28px gap, then the form fields, each separated by 14px:
   - Name (`TextFormField`, required, person icon).
   - Phone number (required, phone keyboard, call icon).
   - **Location card**: a `Card` containing a `Row` — `IconChip` (location pin), 12px gap, the place text in an `Expanded` (so long place names wrap/truncate gracefully instead of overflowing), then either a small `CircularProgressIndicator` (while locating) or a refresh `IconButton` (once resolved) on the trailing edge.
   - Disease, Allergies, Dislikes (all optional, no validator).
   - Budget (required, numeric keyboard, ₹ icon).
4. 20px gap, then the **plan-length segmented control**: a `Container` with `surface` fill, full pill border radius, a thin border, and 4px inner padding, containing two `_segment()` widgets in a `Row`. Each `_segment` is a `GestureDetector` + `AnimatedContainer` (200ms) that fills solid green and switches text color to `onPrimary` when selected, animating smoothly between states rather than snapping.
5. 20px gap, then the **report upload tile**: an `InkWell`-wrapped `Card` (so the whole card is tappable, not just an icon inside it) showing either the "Upload blood report" prompt with a cloud icon, or — once a file is picked — a file icon, the filename (`Expanded` + `ellipsis` overflow so long filenames don't break the layout), and a green "Replace" text label on the trailing edge.
6. 28px gap, then the full-width `GradientPillButton`, wired to `_submit`, showing its internal spinner while `_submitting` is true.

### `PlanScreen` — structure
Currently a `StatelessWidget` with **hardcoded example content** matching the exact shape the real `DietPlan` model will have — this lets you see and approve the finished visual design before the backend exists. `// NOTE:` integration point (see §5): change it to accept a `DietPlan plan` constructor parameter and build its lists from `plan.deficiencies` / `plan.days` / `plan.localNotes` instead of the fixed example values.

Layout, top to bottom, inside a `ListView` (20px horizontal padding, 8px top, 32px bottom):
1. `AppBar` — transparent, title `"Your Plan"`, a trailing share/copy `IconButton` (`Icons.ios_share_outlined`) whose `onPressed` is currently empty — wire it to a "copy plan as text" action per the functional spec.
2. `"Overview"` heading (`titleMedium`), then a `Card` with the plain-language summary paragraph inside.
3. `"Findings from your report"` heading, then one `_findingCard()` per deficiency, each 8px apart: a `Card` → `Row` with a red-tinted `IconChip` (blood-drop icon), then a `Column` with the nutrient name (bold) above the specific finding text (smaller, `textSecondary`).
4. `"Day 1"` heading, then a single `Card` containing all of that day's meals stacked vertically, separated by a `Divider` (24px vertical space around each divider). Each `_meal()` row shows the time in green/bold (`labelLarge`), the food items below it in normal body text, then the "why" reasoning in small muted text underneath.
5. `"Local tips"` heading, then a `Card` with a storefront `IconChip` and explanatory text.
6. A centered, muted, small disclaimer paragraph at the very bottom, wrapped across two lines: *"General dietary guidance, not medical advice. Consult a doctor or dietitian."* — required by `gut_implemetation.md` §12 and never to be removed.

For a **7-day plan**, the same "Day N" card pattern simply repeats once per day — `// NOTE:` when wiring the real model, loop over `plan.days` and build one such `Card` per entry rather than hardcoding a single "Day 1" block.

### `LoadingScreen` — structure and animation
A separate `StatefulWidget` (not currently routed to by default — the profile screen's button spinner covers the loading state inline — but included fully built in case a dedicated full-screen loading route is preferred while the backend call runs).

- `SingleTickerProviderStateMixin` drives an `AnimationController` (7-second loop, `repeat()`) applied via `RotationTransition` to a circular gradient-glow container, producing the slow continuous rotation described in the design system.
- A separate `Timer.periodic` (every 2 seconds) cycles `_statusIndex` through the four status strings (`Reading your report…` → `Checking nutrient levels…` → `Finding foods available near you…` → `Building your plan…`), looping back to the start if the real network call takes longer than one full cycle.
- Both the `AnimationController` and the `Timer` are cancelled/disposed in `dispose()` to avoid leaks if the user navigates away mid-load.

---

## 4. `pubspec.yaml`
Only one dependency beyond a fresh `flutter create dr_gut`: `google_fonts: ^6.2.1`, for the Poppins typeface used across the whole `TextTheme`. Nothing else (no GPS/camera/networking packages) is required to run this frontend-only preview — those get added when you wire in the real services from `gut_implemetation.md`.

---

## 5. How to Run This Preview

1. `flutter create dr_gut`
2. Replace the generated `pubspec.yaml`, `lib/theme.dart`, and `lib/main.dart` with these three files.
3. `flutter pub get`
4. `flutter run`

No backend, GPS permission, or camera permission is needed — the app runs immediately with mock data so the visual design can be reviewed and adjusted first.

---

## 6. What You'll See (walkthrough)

**Profile screen.** A near-black screen fades in with the heading "Let's build your plan" in bold off-white text, a soft grey line underneath. Scrolling down, each field is its own dark rounded box with a thin grey border and a small grey icon on the left; tapping into any field turns its border bright green. About a second after the screen opens, the location card (which sits between the phone-number field and the disease field) finishes its brief spinner and settles on a place name, with a small refresh icon on the right you can tap to re-detect. Below the optional fields and budget field sits a dark pill-shaped switch — tapping "7 days" smoothly slides/fades the green fill over to that side. Underneath, a card reads "Upload blood report" with a cloud icon; tapping it dims the background and a sheet glides up from the bottom with a small grey handle bar at the top and two rows — "Import from device" with a folder icon, "Use camera" with a camera icon, each icon sitting in its own soft green circle. Picking one closes the sheet and the upload card instantly updates to show a document icon, a filename, and a green "Replace" label. At the very bottom, a full-width button glows green with a soft shadow beneath it, reading "Analyze & create my diet plan" — tapping it (once a report is picked and required fields are filled) swaps the text for a small spinning circle for two seconds, then moves to the plan screen.

**Loading screen (if routed to separately).** The whole screen goes quiet and dark except for a soft glowing green ring near the center, slowly and continuously turning, with a short line of grey-white text beneath it that changes every couple of seconds, calmly narrating what's happening.

**Plan screen.** A dark screen titled "Your Plan" appears with a small share icon in the top-right corner. Directly under the title is a card with a short written summary of what the report showed and how the plan addresses it. Below that, "Findings from your report" lists compact cards — each with a small red blood-drop icon on the left, the nutrient name in bold, and the specific abnormal value in smaller grey text underneath. Scrolling further, a "Day 1" card lists three meals stacked with thin divider lines between them — each meal shows its time in green bold text, the actual food items in normal white text below it, and a short grey explanation of why that food helps, right underneath. After the day card, a "Local tips" card appears with a small storefront icon and a note about buying locally. At the very bottom, centered small grey text reminds the reader this isn't medical advice.

Overall the interface reads as **calm, dark, and premium** — closer to a modern AI-assistant app than a typical clinical/hospital-style health app — while every piece of information (findings, meals, reasoning) stays clearly separated into its own card so it's easy to scan on a phone screen.

---

## 7. Next Step — Wiring the Three Integration Points

| # | Location in `main.dart` | Currently | Replace with |
|---|---|---|---|
| 1 | `_detectLocationMock()` in `ProfileScreen` | 900ms delay + fixed place string | `LocationService.getCurrentLocation()` (see `gut_implemetation.md` §9), with typed-error handling and the manual-entry fallback |
| 2 | The two `onTap` callbacks inside `_pickReport()`'s bottom sheet | Sets `_reportName` to a fixed string | `ReportPickerService.pickFromDevice()` / `pickFromCamera()`, storing the returned `File` alongside the filename |
| 3 | The `Future.delayed` inside `_submit()` | 2-second fake wait | `ApiService.createPlan(profile, reportFile)`, wrapped in try/catch, passing the returned `DietPlan` into `PlanScreen(plan: plan)` |

No other code needs to change for these three swaps — the entire visual layer, layout, validation, and navigation already work end to end.
