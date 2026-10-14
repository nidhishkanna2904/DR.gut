# Dr Gut – Complete Implementation Guide

> **Instruction to the agent:** This single file is the full spec, design system, and working code for Dr Gut. Build in the phase order given in §15. After each phase, run `flutter analyze` (and `flutter test` if tests exist) and fix all errors before moving on. Do not skip acceptance criteria. Ask the user only if something here is contradictory or missing.

---

## 1. Goal

Build **Dr Gut**, a cross-platform mobile app (**Flutter, Dart 3**, Android first, iOS-compatible) that creates a personalised diet plan from a user's **blood report** and **current GPS location**.

**Frontend is the priority and must be Flutter.**

---

## 2. How the App Works (user-facing workflow)

0. **Splash screen.** Brief native launch screen (app icon on the dark background) while Flutter initializes and the app checks local storage for a saved profile/"seen landing" flag.
1. **Landing page** *(first launch only)*. A welcome screen with the Dr Gut logo/name, a one-line tagline, and a **"Get Started"** button. Shown only once — after the user taps through, the app remembers this via `shared_preferences` and never shows it again.
2. **Home screen** *(every launch after the first, once a profile exists)*. Greets the returning user by name, shows a summary of their last plan (or a "no plan yet" empty state), and offers **"View my plan"**, **"Create a new plan,"** and **"Edit profile"** actions. A first-time user who just finished the Landing page skips this and goes straight to the Profile form.
3. **Profile form.** User enters name and phone. GPS location is detected automatically in the background and shown as a place name (with a refresh button and a manual fallback if GPS fails). User optionally adds disease, allergies, disliked foods, then enters a daily budget and picks **1-day** or **7-day** plan.
4. **Upload blood report.** User taps the upload tile, chooses **Import from device** or **Use camera**, and the selected file is shown with its name.
5. **Submit.** User taps "Analyze & create my diet plan." The app validates the form (report + location required) and shows a loading state while it waits.
6. **Behind the scenes**, the app sends the profile, GPS coordinates, and the report file to the backend server (see §3).
7. **Plan screen.** The app shows the findings from the report (e.g. "Iron — low"), the day-by-day meal plan with a short reason for each meal, local tips, and a not-medical-advice disclaimer. The plan is also saved locally so it can be shown again from the Home screen next time.

**Full screen order:** Splash → Landing *(first launch only)* → Home *(returning users)* / Profile form *(new users or "create new plan")* → Upload sheet → Loading → Plan screen.

---

## 3. How the Backend and AI Work

1. **Request in.** Flutter sends one multipart `POST /diet-plan` request containing all profile fields, GPS coordinates, and the report file.
2. **File handling.** The backend reads the uploaded file into memory and base64-encodes it. It is **never written to disk** — used only for this one request, then discarded.
3. **Prompt building.** The backend fills the prompt template (§13) with the user's details — location, conditions, allergies, dislikes, budget, plan length.
4. **AI call.** The backend sends the prompt **and** the encoded report together in one request to the AI model (`claude-sonnet-5`), so the model reads the actual report rather than guessing from text alone.
5. **What the model does.** It reads the values in the report, compares them to normal ranges, identifies deficiencies, chooses foods that correct them, filters out allergens/dislikes, favours foods realistically available in the user's region, stays within budget, and replies in **JSON only** (no prose).
6. **Response handling.** The backend strips any ```json fences from the reply, parses it, and validates it has the required fields. If parsing fails, it retries once, then returns a `500` error.
7. **Response out.** The backend returns the clean JSON to the app. No AI logic ever runs on the phone, and the AI key never leaves the server.

---

## 4. Hard Rules

- Use **Flutter/Dart only** for the mobile app. No React Native, no web wrappers.
- **Never put an AI API key in the Flutter app.** All AI calls happen in the backend; the key is read from the `ANTHROPIC_API_KEY` environment variable.
- Do not hardcode user data, plans or reports; use real GPS, real uploads, real API responses.
- Every screen must handle **loading, error and empty** states.
- Keep the plan screen's disclaimer: *"General dietary guidance, not medical advice. Consult a doctor or dietitian."*
- Do not store the uploaded report on the server after the response is sent.
- Use null-safe, lint-clean Dart. Material 3.

---

## 5. Tech Stack

| Layer | Choice |
|---|---|
| Mobile | Flutter (stable), Dart >=3.3, Material 3 |
| State management | `provider` |
| Networking | `http` (multipart upload) |
| GPS | `geolocator` |
| Reverse geocoding | `geocoding` |
| File import | `file_picker` |
| Camera | `image_picker` |
| Local storage | `shared_preferences` |
| Fonts | `google_fonts` (Poppins) |
| Backend | Python 3.11+, FastAPI, `uvicorn`, `python-multipart`, `anthropic` |
| AI model | `claude-sonnet-5` (reads image/PDF reports, returns JSON) |

`pubspec.yaml` dependencies:
```yaml
dependencies:
  flutter: {sdk: flutter}
  provider: ^6.1.2
  http: ^1.2.2
  geolocator: ^13.0.1
  geocoding: ^3.0.0
  file_picker: ^8.1.2
  image_picker: ^1.1.2
  shared_preferences: ^2.3.2
  google_fonts: ^6.2.1
```

---

## 6. Project Structure

```
dr_gut/
├── lib/
│   ├── main.dart                     # app entry, theme, providers
│   ├── theme.dart                    # colors, text theme, shared widgets
│   ├── config.dart                   # kBaseUrl
│   ├── models/
│   │   ├── user_profile.dart
│   │   └── diet_plan.dart
│   ├── services/
│   │   ├── location_service.dart
│   │   ├── report_picker_service.dart
│   │   ├── api_service.dart
│   │   └── storage_service.dart
│   ├── providers/
│   │   └── app_state.dart
│   ├── screens/
│   │   ├── landing_screen.dart
│   │   ├── home_screen.dart
│   │   ├── profile_screen.dart
│   │   ├── loading_screen.dart
│   │   └── plan_screen.dart
│   └── widgets/
│       ├── location_card.dart
│       ├── report_upload_tile.dart
│       └── meal_card.dart
├── backend/
│   ├── main.py
│   └── requirements.txt
└── gut_complete_implementation.md
```

---

## 7. Data Models

**`UserProfile`** – `name` (String), `phone` (String), `locationName` (String), `lat` (double), `lng` (double), `disease` (String, may be empty), `allergies` (String, may be empty), `dislikes` (String, may be empty), `budget` (int, rupees per day), `planType` (`'day'` | `'week'`). Include `toJson()`, `fromJson()`, `copyWith()`.

**`DietPlan`** – `summary` (String), `deficiencies` (`List<Deficiency>` with `name`, `finding`), `days` (`List<PlanDay>` with `day` and `List<Meal>`), `localNotes` (String). `Meal` has `time`, `items`, `why`. Include `DietPlan.fromJson()` that tolerates missing/null fields.

---

## 8. API Contract

`POST /diet-plan` (multipart/form-data)

| Field | Type | Notes |
|---|---|---|
| name, phone | text | required |
| location, lat, lng | text | from GPS (or manual) |
| disease, allergies, dislikes | text | optional, may be empty |
| budget | text | rupees per day |
| plan_type | text | `day` or `week` |
| report | file | PDF / JPG / PNG |

**Response 200 (JSON)**
```json
{
  "summary": "string",
  "deficiencies": [{"name": "Iron", "finding": "Hb 9.8 g/dL (low)"}],
  "days": [
    {"day": "Day 1",
     "meals": [{"time": "Breakfast", "items": "...", "why": "..."}]}
  ],
  "local_notes": "string"
}
```
Errors: `400` unreadable/invalid report, `422` bad fields, `500` AI/parsing failure, `502` AI service unavailable. Body: `{"detail": "message"}`.

---

## 9. UI/UX Design System

**Design direction:** dark, premium, "AI health assistant" feel — near-black background, a single glowing green accent, soft glassy cards with thin borders, rounded pill buttons, generous spacing.

### 9.1 Color palette

| Token | Hex | Use |
|---|---|---|
| `background` | `#0B0F0D` | App background |
| `surface` | `#141A17` | Card / form field background |
| `surfaceBorder` | `#2A332E` | 1px border on cards and fields |
| `primary` | `#22E38A` | Buttons, active states, icons, highlights |
| `primaryGradientEnd` | `#0FB86A` | Gradient end for buttons / glow effects |
| `onPrimary` | `#062017` | Text/icons on top of the green accent |
| `textPrimary` | `#F4F7F5` | Headings, primary text |
| `textSecondary` | `#9AA6A0` | Labels, hints, secondary text |
| `textMuted` | `#5E6A64` | Disabled text, timestamps |
| `error` | `#FF6B6B` | Validation errors, warnings |
| `divider` | `#1E2621` | Hairlines between sections |

### 9.2 Typography
`Poppins` via `google_fonts`. Display 28sp/SemiBold, Title 20sp/SemiBold, Body 15sp/Regular, Label 13sp/Medium, Caption 12sp/Regular.

### 9.3 Components
- **Primary button:** full-width pill (`borderRadius: 28`), height 56, `primary → primaryGradientEnd` gradient fill, soft green glow shadow.
- **Secondary button:** pill, transparent fill, 1px `surfaceBorder`.
- **Icon chip:** 40×40 circle, color at 15% opacity fill, full-strength icon — used for location pin, upload cloud, findings, tips.
- **Cards:** `surface` background, `borderRadius: 20`, 1px `surfaceBorder`, soft black shadow (20% opacity, blur 20, offset y 8).
- **Text fields:** `surface` background, `borderRadius: 16`, `surfaceBorder` outline that turns `primary` on focus.
- **Bottom sheet:** `surface` background, top corners `borderRadius: 24`, drag-handle bar, two icon-chip rows.
- **Loading indicator:** slim rotating glow ring in `primary`, with cycling status text beneath.
- **Segmented control (1-day/7-day):** pill container, selected side fills `primary` with `onPrimary` text.

### 9.4 Screen styling summary
- **Profile:** subtle top-of-screen green glow, greeting-style heading, stacked field cards, location card with refresh icon, segmented toggle, upload tile, bottom gradient pill button.
- **Loading:** centered glow ring animation with rotating status captions.
- **Plan:** transparent app bar with share icon, overview card, finding cards (red-tinted icon), day cards with meals separated by dividers, local-tips card, muted disclaimer.

### 9.5 Motion
Screen transitions: fade-through 250ms. Button press: scale to 0.97. Loading ring: 6–8s rotation loop with gentle opacity pulse. Bottom sheet: slide up with slight overshoot, 300ms.

---

## 10. Frontend Implementation

### 10.1 Approach
Three layers, kept strictly separate:
1. **Design layer (`theme.dart`)** — every color/font/reusable widget, so the whole app's look can change by editing one file.
2. **Screen layer (`main.dart`)** — `ProfileScreen`, `LoadingScreen`, `PlanScreen`, holding only local UI state.
3. **Integration layer (`// NOTE:` comments)** — every spot that should call GPS, the file picker, or the backend currently runs a short mock delay, so the whole app runs and can be demoed before the backend is connected, then wired in one pass later.

### 10.2 `lib/theme.dart`
```dart
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Dr Gut design tokens — every screen pulls colors/text styles from here.
class DrGutColors {
  static const background = Color(0xFF0B0F0D);
  static const surface = Color(0xFF141A17);
  static const surfaceBorder = Color(0xFF2A332E);
  static const primary = Color(0xFF22E38A);
  static const primaryGradientEnd = Color(0xFF0FB86A);
  static const onPrimary = Color(0xFF062017);
  static const textPrimary = Color(0xFFF4F7F5);
  static const textSecondary = Color(0xFF9AA6A0);
  static const textMuted = Color(0xFF5E6A64);
  static const error = Color(0xFFFF6B6B);
  static const divider = Color(0xFF1E2621);

  static const primaryGradient = LinearGradient(
    colors: [primary, primaryGradientEnd],
  );
}

ThemeData buildDrGutTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  final textTheme = GoogleFonts.poppinsTextTheme(base.textTheme).apply(
    bodyColor: DrGutColors.textPrimary,
    displayColor: DrGutColors.textPrimary,
  );

  return base.copyWith(
    scaffoldBackgroundColor: DrGutColors.background,
    colorScheme: base.colorScheme.copyWith(
      surface: DrGutColors.background,
      primary: DrGutColors.primary,
      onPrimary: DrGutColors.onPrimary,
      error: DrGutColors.error,
      outline: DrGutColors.surfaceBorder,
    ),
    textTheme: textTheme,
    appBarTheme: const AppBarTheme(
      backgroundColor: DrGutColors.background,
      elevation: 0,
      centerTitle: false,
      foregroundColor: DrGutColors.textPrimary,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: DrGutColors.surface,
      labelStyle: textTheme.labelMedium?.copyWith(color: DrGutColors.textSecondary),
      hintStyle: textTheme.bodyMedium?.copyWith(color: DrGutColors.textMuted),
      prefixIconColor: DrGutColors.textSecondary,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: DrGutColors.surfaceBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: DrGutColors.surfaceBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: DrGutColors.primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    ),
    cardTheme: CardThemeData(
      color: DrGutColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: DrGutColors.surfaceBorder),
      ),
      margin: EdgeInsets.zero,
    ),
    dividerTheme: const DividerThemeData(color: DrGutColors.divider, thickness: 1),
  );
}

/// The signature "glow" pill button used for every primary action.
class GradientPillButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  const GradientPillButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null || loading;
    return Opacity(
      opacity: disabled && !loading ? 0.5 : 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: DrGutColors.primaryGradient,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: DrGutColors.primary.withValues(alpha: 0.35),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(28),
            onTap: disabled ? null : onPressed,
            child: SizedBox(
              height: 56,
              child: Center(
                child: loading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: DrGutColors.onPrimary,
                        ),
                      )
                    : Text(
                        label,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              color: DrGutColors.onPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Small circular icon chip used throughout (location pin, upload cloud, etc).
class IconChip extends StatelessWidget {
  final IconData icon;
  final Color? color;
  const IconChip({super.key, required this.icon, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? DrGutColors.primary;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: c, size: 20),
    );
  }
}
```

**What each part does:** `DrGutColors` is a plain class of `static const Color` values, one per design token, reachable from anywhere with a single import — no `BuildContext` needed. `buildDrGutTheme()` starts from `ThemeData.dark()`, swaps in Poppins, and centrally defines input, card, app-bar and divider styling once so every screen looks identical without repeating decoration code. `GradientPillButton` has two independent visual states — `disabled` (dimmed) and `loading` (spinner replaces the label, not dimmed, since it's actively working) — and wraps its gradient box in a transparent `Material` + `InkWell` so it still gets a proper tap ripple. `IconChip` is the one small badge widget reused for every icon-in-a-circle across the app, with an optional color override for the plan screen's red-tinted warning icons.

### 10.3 `lib/main.dart`
```dart
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme.dart';

void main() => runApp(const DrGutApp());

class DrGutApp extends StatelessWidget {
  const DrGutApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Dr Gut',
        debugShowCheckedModeBanner: false,
        theme: buildDrGutTheme(),
        home: const AppRouter(),
      );
}

/// Decides which screen to open first: Landing (first launch only), Home
/// (a profile already exists), or straight to the Profile form (no profile
/// yet, landing already seen). NOTE: this mock always resolves to Landing
/// after a short delay; wire the two flags to StorageService per §11.
class AppRouter extends StatefulWidget {
  const AppRouter({super.key});

  @override
  State<AppRouter> createState() => _AppRouterState();
}

class _AppRouterState extends State<AppRouter> {
  @override
  void initState() {
    super.initState();
    _decide();
  }

  Future<void> _decide() async {
    // NOTE: replace with StorageService.hasSeenLanding() and
    // StorageService.loadProfile() != null.
    final prefs = await SharedPreferences.getInstance();
    final seenLanding = prefs.getBool('seen_landing') ?? false;
    final hasProfile = prefs.getString('saved_profile_name') != null;
    if (!mounted) return;

    Widget next;
    if (!seenLanding) {
      next = const LandingScreen();
    } else if (hasProfile) {
      next = const HomeScreen();
    } else {
      next = const ProfileScreen();
    }
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => next));
  }

  @override
  Widget build(BuildContext context) => const Scaffold(body: SizedBox.shrink());
}

// =========================================================== Landing page

class LandingScreen extends StatelessWidget {
  const LandingScreen({super.key});

  Future<void> _getStarted(BuildContext context) async {
    // NOTE: replace with StorageService.setSeenLanding(true).
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('seen_landing', true);
    if (!context.mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const ProfileScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(flex: 2),
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  gradient: DrGutColors.primaryGradient,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: DrGutColors.primary.withValues(alpha: 0.35),
                      blurRadius: 40,
                    ),
                  ],
                ),
                child: const Icon(Icons.eco_outlined, size: 48, color: DrGutColors.onPrimary),
              ),
              const SizedBox(height: 28),
              Text('Dr Gut', style: t.headlineMedium),
              const SizedBox(height: 10),
              Text(
                'Your diet plan, built from your blood report\nand what\'s available near you.',
                textAlign: TextAlign.center,
                style: t.bodyMedium?.copyWith(color: DrGutColors.textSecondary),
              ),
              const Spacer(flex: 3),
              GradientPillButton(
                label: 'Get Started',
                onPressed: () => _getStarted(context),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

// =========================================================== Home screen

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  // NOTE: this screen currently shows placeholder name/plan-status values.
  // Replace with real data from StorageService.loadProfile() and the last
  // saved DietPlan once available.

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dr Gut'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_outline),
            tooltip: 'Edit profile',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text('Welcome back', style: t.headlineSmall),
          const SizedBox(height: 4),
          Text('Here\'s where things stand',
              style: t.labelMedium?.copyWith(color: DrGutColors.textSecondary)),
          const SizedBox(height: 24),

          // Last-plan summary card (or empty state)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const IconChip(icon: Icons.restaurant_menu_outlined),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text('No plan yet', style: t.titleMedium),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  Text(
                    'Create your first plan by adding your profile and a blood report.',
                    style: t.bodySmall?.copyWith(color: DrGutColors.textSecondary),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          GradientPillButton(
            label: 'Create a new plan',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ProfileScreen()),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
              side: const BorderSide(color: DrGutColors.surfaceBorder),
            ),
            // Disabled until a plan actually exists.
            onPressed: null,
            child: const Text('View my plan'),
          ),
        ],
      ),
    );
  }
}

// =========================================================== Profile screen

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _disease = TextEditingController();
  final _allergies = TextEditingController();
  final _dislikes = TextEditingController();
  final _budget = TextEditingController();

  String _place = 'Detecting your location…';
  bool _locating = true;
  String _planType = 'day';
  String? _reportName;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _detectLocationMock();
  }

  // NOTE: UI-only stand-in. Wire to LocationService (geolocator + geocoding)
  // per §11.
  Future<void> _detectLocationMock() async {
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    setState(() {
      _place = 'Gandhipuram, Coimbatore';
      _locating = false;
    });
  }

  void _pickReport() {
    showModalBottomSheet(
      context: context,
      backgroundColor: DrGutColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: DrGutColors.surfaceBorder,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            _sheetRow(Icons.folder_open_outlined, 'Import from device', () {
              Navigator.pop(context);
              // NOTE: wire to ReportPickerService.pickFromDevice()
              setState(() => _reportName = 'blood_report.pdf');
            }),
            _sheetRow(Icons.photo_camera_outlined, 'Use camera', () {
              Navigator.pop(context);
              // NOTE: wire to ReportPickerService.pickFromCamera()
              setState(() => _reportName = 'camera_capture.jpg');
            }),
          ]),
        ),
      ),
    );
  }

  Widget _sheetRow(IconData icon, String label, VoidCallback onTap) {
    return ListTile(
      onTap: onTap,
      leading: IconChip(icon: icon),
      title: Text(label, style: Theme.of(context).textTheme.bodyLarge),
    );
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    if (_reportName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload your blood report')),
      );
      return;
    }
    setState(() => _submitting = true);
    // NOTE: wire to ApiService.createPlan(profile, report) per §12.
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    setState(() => _submitting = false);
    Navigator.push(context, MaterialPageRoute(builder: (_) => const PlanScreen()));
  }

  InputDecoration _decoration(String label, IconData icon) => InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, size: 20),
      );

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
            children: [
              Text("Let's build your plan", style: t.headlineSmall),
              const SizedBox(height: 6),
              Text('Tell us a bit about you',
                  style: t.labelMedium?.copyWith(color: DrGutColors.textSecondary)),
              const SizedBox(height: 28),

              TextFormField(
                controller: _name,
                decoration: _decoration('Name', Icons.person_outline),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: _decoration('Phone number', Icons.call_outlined),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 14),

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(children: [
                    const IconChip(icon: Icons.location_on_outlined),
                    const SizedBox(width: 12),
                    Expanded(child: Text(_place, style: t.bodyMedium)),
                    if (_locating)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: DrGutColors.primary,
                        ),
                      )
                    else
                      IconButton(
                        icon: const Icon(Icons.refresh, color: DrGutColors.textSecondary),
                        onPressed: () {
                          setState(() {
                            _locating = true;
                            _place = 'Detecting your location…';
                          });
                          _detectLocationMock();
                        },
                      ),
                  ]),
                ),
              ),
              const SizedBox(height: 14),

              TextFormField(
                controller: _disease,
                decoration: _decoration('Any disease (optional)', Icons.medical_information_outlined),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _allergies,
                decoration: _decoration('Any allergies (optional)', Icons.warning_amber_outlined),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _dislikes,
                decoration: _decoration('Foods you dislike (optional)', Icons.thumb_down_alt_outlined),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _budget,
                keyboardType: TextInputType.number,
                decoration: _decoration('Budget per day (₹)', Icons.currency_rupee),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 20),

              Container(
                decoration: BoxDecoration(
                  color: DrGutColors.surface,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: DrGutColors.surfaceBorder),
                ),
                padding: const EdgeInsets.all(4),
                child: Row(children: [
                  _segment('1 day', 'day'),
                  _segment('7 days', 'week'),
                ]),
              ),
              const SizedBox(height: 20),

              InkWell(
                onTap: _pickReport,
                borderRadius: BorderRadius.circular(20),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(children: [
                      IconChip(icon: _reportName == null
                          ? Icons.cloud_upload_outlined
                          : Icons.insert_drive_file_outlined),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _reportName ?? 'Upload blood report',
                          style: t.bodyMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (_reportName != null)
                        Text('Replace', style: t.labelMedium?.copyWith(color: DrGutColors.primary)),
                    ]),
                  ),
                ),
              ),
              const SizedBox(height: 28),

              GradientPillButton(
                label: 'Analyze & create my diet plan',
                loading: _submitting,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _segment(String label, String value) {
    final selected = _planType == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _planType = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? DrGutColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(24),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: selected ? DrGutColors.onPrimary : DrGutColors.textSecondary,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}

// =========================================================== Plan screen
// Placeholder content shown here for a standalone frontend preview.
// Replace with the real DietPlan returned by ApiService.

class PlanScreen extends StatelessWidget {
  const PlanScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Plan'),
        actions: [
          IconButton(icon: const Icon(Icons.ios_share_outlined), onPressed: () {}),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text('Overview', style: t.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Your report shows low iron and vitamin D. This plan uses '
                'locally available foods near Gandhipuram, Coimbatore to help '
                'correct both within your budget.',
                style: t.bodyMedium,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text('Findings from your report', style: t.titleMedium),
          const SizedBox(height: 10),
          _findingCard(context, 'Iron', 'Hb 9.8 g/dL — below normal range'),
          const SizedBox(height: 8),
          _findingCard(context, 'Vitamin D', '18 ng/mL — insufficient'),
          const SizedBox(height: 24),
          Text('Day 1', style: t.titleMedium),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                _meal(context, 'Breakfast', 'Ragi porridge with jaggery, boiled egg',
                    'Ragi and egg both support iron levels'),
                const Divider(height: 24),
                _meal(context, 'Lunch', 'Spinach dal, rice, a side of amla',
                    'Spinach and amla are iron- and vitamin C-rich, widely sold locally'),
                const Divider(height: 24),
                _meal(context, 'Dinner', 'Grilled fish or paneer, sautéed greens',
                    'Adds vitamin D and pairs iron with protein'),
              ]),
            ),
          ),
          const SizedBox(height: 24),
          Text('Local tips', style: t.titleMedium),
          const SizedBox(height: 10),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                const IconChip(icon: Icons.storefront_outlined),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Most items here are available at your nearest local '
                    'market or grocer within your daily budget.',
                    style: t.bodyMedium,
                  ),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 28),
          Center(
            child: Text(
              'General dietary guidance, not medical advice.\nConsult a doctor or dietitian.',
              textAlign: TextAlign.center,
              style: t.bodySmall?.copyWith(color: DrGutColors.textMuted),
            ),
          ),
        ],
      ),
    );
  }

  Widget _findingCard(BuildContext context, String name, String finding) {
    final t = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          const IconChip(icon: Icons.bloodtype_outlined, color: DrGutColors.error),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: t.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
                Text(finding, style: t.bodySmall?.copyWith(color: DrGutColors.textSecondary)),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  Widget _meal(BuildContext context, String time, String items, String why) {
    final t = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(time, style: t.labelLarge?.copyWith(color: DrGutColors.primary, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(items, style: t.bodyMedium),
        const SizedBox(height: 2),
        Text(why, style: t.bodySmall?.copyWith(color: DrGutColors.textMuted)),
      ],
    );
  }
}

// =========================================================== Loading screen
// Full-screen alternative to the inline button spinner, if a dedicated
// loading route is preferred while the backend responds.

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  int _statusIndex = 0;
  Timer? _timer;

  static const _statuses = [
    'Reading your report…',
    'Checking nutrient levels…',
    'Finding foods available near you…',
    'Building your plan…',
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 7))..repeat();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) {
      setState(() => _statusIndex = (_statusIndex + 1) % _statuses.length);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RotationTransition(
              turns: _controller,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      DrGutColors.primary.withValues(alpha: 0.35),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: const Icon(Icons.blur_circular, size: 90, color: DrGutColors.primary),
              ),
            ),
            const SizedBox(height: 28),
            Text(_statuses[_statusIndex], style: Theme.of(context).textTheme.titleMedium),
          ],
        ),
      ),
    );
  }
}
```

### 10.4 Screen-by-screen behaviour
- **`AppRouter`** — an invisible routing widget shown for a split second on launch (currently a blank `Scaffold`; pair it with a native/custom splash if you want a branded moment here). It reads two flags — "has the user seen the landing page" and "does a saved profile exist" — and pushes the right first real screen: `LandingScreen` (first launch), `HomeScreen` (returning user with a profile), or `ProfileScreen` (landing seen but no profile yet).
- **`LandingScreen`** — a centered welcome layout: a glowing circular logo badge, the app name, a two-line tagline, and a single `GradientPillButton` ("Get Started"). Tapping it saves `seen_landing = true` and navigates to `ProfileScreen`, replacing itself in the stack (`pushReplacement`) so the back button can't return to it.
- **`HomeScreen`** — greets the returning user, shows a card summarising their last plan (or the "No plan yet" empty state shown here), and offers two actions: a primary "Create a new plan" button (→ `ProfileScreen`) and a "View my plan" button, which stays disabled until a saved plan actually exists. An `AppBar` action icon opens `ProfileScreen` again for editing.
- **`ProfileScreen`** state: six `TextEditingController`s, `_place`/`_locating` for the location card, `_planType`, `_reportName`, `_submitting`. `initState()` calls `_detectLocationMock()` immediately so location starts resolving the instant the screen opens. `_submit()` validates the form, requires a report, shows the button's loading state, then (once wired) calls the real API and navigates to `PlanScreen` with the returned plan.
- **`PlanScreen`** currently shows hardcoded example content in the exact shape the real `DietPlan` will have, so the design can be reviewed before the backend exists. For a 7-day plan, the same "Day N" card pattern repeats once per day once wired to the real model.
- **`LoadingScreen`** drives a continuous 7-second rotation via `AnimationController` and cycles four status strings every 2 seconds via `Timer.periodic`; both are disposed properly to avoid leaks.

### 10.5 Run it standalone
```bash
flutter create dr_gut
# replace pubspec.yaml, lib/theme.dart, lib/main.dart with the code above
flutter pub get
flutter run
```
No backend, GPS, or camera permission is required — it runs immediately with mock data.

### 10.6 What you'll see
On first launch, after a brief blank moment, a centered welcome screen appears: a glowing green circular badge, "Dr Gut" in bold, a short two-line tagline, and a single green "Get Started" pill button near the bottom. Tapping it moves straight into the profile form. On any later launch (once a profile has been saved), the app instead opens on a Home screen — "Welcome back" heading, a card showing the last plan's status (or "No plan yet" the first time), a green "Create a new plan" button, and an outlined "View my plan" button that's disabled until a plan exists. A person icon in the top-right corner opens the profile form again for editing.

A near-black profile screen opens with "Let's build your plan" in bold text. Each field is a dark rounded box that glows green on focus. The location card auto-resolves after about a second, with a refresh icon on the right. A pill-shaped 1-day/7-day switch sits above an upload card; tapping it opens a bottom sheet sliding up with two icon-chip rows. The bottom button glows green with a soft shadow and shows a spinner while submitting. The plan screen that follows shows an overview card, red-tinted finding cards, a day card with meals separated by dividers (time in green, items in white, reasoning in muted grey), a local-tips card, and a small disclaimer at the very bottom.

### 10.7 Three integration points to wire later

| # | Location | Currently | Replace with |
|---|---|---|---|
| 1 | `_detectLocationMock()` in `ProfileScreen` | 900ms delay + fixed string | `LocationService.getCurrentLocation()`, with typed-error handling and manual-entry fallback |
| 2 | The two bottom-sheet `onTap` callbacks | Sets `_reportName` to a fixed string | `ReportPickerService.pickFromDevice()` / `pickFromCamera()` |
| 3 | The `Future.delayed` in `_submit()` | 2-second fake wait | `ApiService.createPlan(profile, reportFile)`, wrapped in try/catch, passing the real `DietPlan` into `PlanScreen`, and saving the plan locally so `HomeScreen` can show it |
| 4 | The two flag reads in `AppRouter._decide()` and the save in `LandingScreen._getStarted()` | Raw `SharedPreferences` calls | `StorageService.hasSeenLanding()` / `setSeenLanding()` and `StorageService.loadProfile()`, per §11 |
| 5 | `HomeScreen`'s hardcoded "No plan yet" card and disabled "View my plan" button | Static placeholder | Real last-saved `DietPlan` from `StorageService`; enable the button and navigate to `PlanScreen(plan: savedPlan)` once one exists |

---

## 11. Services (to implement when wiring the frontend)

**`LocationService`**
```dart
Future<LocationResult> getCurrentLocation();
// isLocationServiceEnabled -> checkPermission/requestPermission ->
// getCurrentPosition -> placemarkFromCoordinates.
// Throws: GpsDisabled, PermissionDenied, PermissionDeniedForever, Timeout.
// LocationResult { double lat; double lng; String placeName; }
```

**`ReportPickerService`**
```dart
Future<File?> pickFromDevice();
Future<File?> pickFromCamera();
```

**`ApiService`**
```dart
Future<DietPlan> createPlan(UserProfile profile, File report);
// POST {kBaseUrl}/diet-plan as multipart/form-data, timeout 120 s.
// Non-200 -> throw ApiException with a user-friendly message.
```

**`StorageService`** – using `shared_preferences`:
```dart
Future<void> saveProfile(UserProfile profile);
Future<UserProfile?> loadProfile();
Future<void> savePlan(DietPlan plan);
Future<DietPlan?> loadLastPlan();
Future<bool> hasSeenLanding();
Future<void> setSeenLanding(bool value);
```
`hasSeenLanding()`/`setSeenLanding()` back the Landing page's one-time-only behaviour; `saveProfile()`/`loadProfile()` back the Home screen's "returning user" check; `savePlan()`/`loadLastPlan()` let the Home screen show the last plan's summary and enable its "View my plan" button.

---

## 12. Backend Implementation

### 12.1 Approach
One FastAPI service with a single real endpoint, split into three responsibilities: validate the upload cheaply before doing anything expensive, talk to the AI model defensively (parsing/retrying), and return a predictable typed response or a clear error. The API key lives only on the server, read from `ANTHROPIC_API_KEY` — never sent to or requested by the app.

### 12.2 `backend/main.py`
```python
"""Dr Gut backend.

Reads a blood report (image or PDF), sends it plus the user's profile and
GPS location to the Claude API, and returns a structured JSON diet plan.

Setup:
    pip install -r requirements.txt
    export ANTHROPIC_API_KEY=sk-ant-...
    uvicorn main:app --host 0.0.0.0 --port 8000

The uploaded report is read into memory and never written to disk.
"""
import base64
import json
import logging
import re

import anthropic
from fastapi import FastAPI, File, Form, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

logging.basicConfig(level=logging.INFO)
log = logging.getLogger("dr_gut")

app = FastAPI(title="Dr Gut API")

# Open for development so the Flutter app can reach this server from an
# emulator, a device, or Flutter web. Restrict allow_origins before shipping
# this anywhere public.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

client = anthropic.Anthropic()  # reads ANTHROPIC_API_KEY from the environment

MODEL = "claude-sonnet-5"
MAX_TOKENS = 6000
MAX_REPORT_BYTES = 10 * 1024 * 1024  # 10 MB, matches the frontend's own limit
ALLOWED_CONTENT_TYPES = {
    "application/pdf": "document",
    "image/jpeg": "image",
    "image/png": "image",
}

REQUIRED_KEYS = {"summary", "deficiencies", "days", "local_notes"}

PROMPT = """You are a nutrition assistant. Read the attached blood report and
find values outside the normal range (e.g. haemoglobin, ferritin, vitamin B12,
vitamin D, calcium, cholesterol, glucose, thyroid).

User: {name}. Location: {location} (lat {lat}, lng {lng}).
Conditions: {disease}. Allergies: {allergies}. Dislikes: {dislikes}.
Budget: Rs {budget} per day. Plan length: {days} day(s).

Create a diet plan that corrects the deficiencies using foods commonly and
cheaply available in that local area/region and season. Never include
allergens or disliked foods. Stay within the budget. If the report is
unreadable or not a blood report, reply with {{"error": "reason"}} instead.

Reply with ONLY JSON, no markdown fences, no commentary, in exactly this
shape:
{{"summary": "string",
  "deficiencies": [{{"name": "string", "finding": "string"}}],
  "days": [{{"day": "string", "meals": [{{"time": "string", "items": "string", "why": "string"}}]}}],
  "local_notes": "string"}}"""


class DietPlanResponse(BaseModel):
    summary: str
    deficiencies: list[dict]
    days: list[dict]
    local_notes: str


def _strip_code_fences(text: str) -> str:
    """Claude sometimes wraps JSON in ```json ... ``` even when told not to."""
    text = text.strip()
    text = re.sub(r"^```(?:json)?\s*", "", text)
    text = re.sub(r"\s*```$", "", text)
    return text.strip()


def _call_model(prompt: str, block: dict) -> dict:
    """Send one request to Claude and parse its JSON reply. Raises ValueError
    on anything that isn't valid, complete JSON."""
    msg = client.messages.create(
        model=MODEL,
        max_tokens=MAX_TOKENS,
        messages=[{"role": "user", "content": [block, {"type": "text", "text": prompt}]}],
    )
    raw = "".join(part.text for part in msg.content if part.type == "text")
    cleaned = _strip_code_fences(raw)
    data = json.loads(cleaned)

    if "error" in data:
        raise ValueError(data["error"])
    missing = REQUIRED_KEYS - data.keys()
    if missing:
        raise ValueError(f"model response missing keys: {missing}")
    return data


@app.get("/health")
def health():
    return {"status": "ok"}


@app.post("/diet-plan", response_model=DietPlanResponse)
async def diet_plan(
    name: str = Form(...),
    phone: str = Form(...),
    location: str = Form(...),
    lat: float = Form(...),
    lng: float = Form(...),
    disease: str = Form(""),
    allergies: str = Form(""),
    dislikes: str = Form(""),
    budget: str = Form(...),
    plan_type: str = Form("day"),
    report: UploadFile = File(...),
):
    if report.content_type not in ALLOWED_CONTENT_TYPES:
        raise HTTPException(
            status_code=400,
            detail=f"Unsupported file type: {report.content_type}. Use PDF, JPG or PNG.",
        )

    raw_bytes = await report.read()
    if len(raw_bytes) == 0:
        raise HTTPException(status_code=400, detail="Uploaded report is empty.")
    if len(raw_bytes) > MAX_REPORT_BYTES:
        raise HTTPException(status_code=400, detail="Report is larger than 10 MB.")

    encoded = base64.b64encode(raw_bytes).decode()
    block_type = ALLOWED_CONTENT_TYPES[report.content_type]
    block = {
        "type": block_type,
        "source": {"type": "base64", "media_type": report.content_type, "data": encoded},
    }

    prompt = PROMPT.format(
        name=name,
        location=location,
        lat=lat,
        lng=lng,
        disease=disease or "none",
        allergies=allergies or "none",
        dislikes=dislikes or "none",
        budget=budget,
        days=7 if plan_type == "week" else 1,
    )

    last_error: Exception | None = None
    for attempt in (1, 2):
        try:
            data = _call_model(prompt, block)
            log.info("diet-plan ok for %s on attempt %d", name, attempt)
            return data
        except json.JSONDecodeError as e:
            last_error = e
            log.warning("attempt %d: model did not return valid JSON: %s", attempt, e)
        except ValueError as e:
            last_error = e
            log.warning("attempt %d: %s", attempt, e)
        except anthropic.APIError as e:
            log.error("Anthropic API error: %s", e)
            raise HTTPException(status_code=502, detail="AI service is unavailable right now.")

    log.error("diet-plan failed for %s after retries: %s", name, last_error)
    raise HTTPException(
        status_code=500,
        detail="Could not read this report clearly. Please try a clearer photo or a PDF.",
    )
```

`backend/requirements.txt`
```
fastapi==0.115.0
uvicorn[standard]==0.30.6
python-multipart==0.0.9
anthropic==0.34.2
pydantic==2.9.2
```

### 12.3 What each part does
- `ALLOWED_CONTENT_TYPES` is the single dict that drives both file-type validation and the content-block type sent to Claude (`document` for PDFs, `image` for photos).
- `_strip_code_fences` defensively removes stray ```` ```json ``` ```` wrappers before parsing, without touching real content.
- `_call_model` sends the report and prompt together in one message (so the model reads the actual report), checks for the model's own `{"error": ...}` escape hatch, and validates all four `REQUIRED_KEYS` are present before trusting the reply.
- `/diet-plan` validates the upload (type, non-empty, ≤10 MB) *before* any AI call, so bad input fails in milliseconds. It then retries once on a parsing/validation failure, but fails fast (no retry) on a genuine `anthropic.APIError` (auth/network/rate-limit), since retrying those blindly wastes time and quota. Every attempt is logged.

### 12.4 Running and testing it
```bash
cd backend
pip install -r requirements.txt
export ANTHROPIC_API_KEY=sk-ant-...
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```
`--host 0.0.0.0` (not `127.0.0.1`) lets a phone on the same Wi-Fi reach the server via your PC's LAN IP.

```bash
curl http://localhost:8000/health
# {"status":"ok"}

curl -X POST http://localhost:8000/diet-plan \
  -F "name=Test User" -F "phone=9999999999" \
  -F "location=Coimbatore, Tamil Nadu" -F "lat=11.0168" -F "lng=76.9558" \
  -F "disease=" -F "allergies=peanuts" -F "dislikes=mushrooms" \
  -F "budget=300" -F "plan_type=day" \
  -F "report=@sample_report.jpg;type=image/jpeg"
```
Check that the returned plan never mentions peanuts or mushrooms — that confirms the allergy/dislike filtering works.

**Connect the app:** set `kBaseUrl` to `http://10.0.2.2:8000` for the Android emulator, or `http://<PC LAN IP>:8000` for a real phone on the same Wi-Fi.

### 12.5 Error behaviour summary

| Situation | Status | `detail` sent to the app |
|---|---|---|
| Unsupported file type | 400 | "Unsupported file type: ... Use PDF, JPG or PNG." |
| Empty file | 400 | "Uploaded report is empty." |
| File over 10 MB | 400 | "Report is larger than 10 MB." |
| Model can't read the report, after retry | 500 | "Could not read this report clearly. Please try a clearer photo or a PDF." |
| Model returns invalid JSON twice | 500 | Same as above |
| Anthropic API/network/auth failure | 502 | "AI service is unavailable right now." |
| Success | 200 | The `DietPlanResponse` JSON body |

---

## 13. Permissions and Config

**Android** – `AndroidManifest.xml`
```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
<uses-permission android:name="android.permission.CAMERA"/>
```
Add `android:usesCleartextTraffic="true"` to `<application>` for development only.

**iOS** – `Info.plist`: `NSLocationWhenInUseUsageDescription`, `NSCameraUsageDescription`, `NSPhotoLibraryUsageDescription` with short user-facing reasons.

**`config.dart`**
```dart
const String kBaseUrl = 'http://10.0.2.2:8000'; // emulator; use PC LAN IP on a real phone
```

---

## 14. Privacy and Safety

- A blood report is sensitive health data. Tell the user on the upload tile that the report is used only to create their plan.
- Use HTTPS in production; keep the API key on the server only.
- If the report is unclear, ask the user to retake or upload a clearer copy rather than guessing values.
- Always show the not-medical-advice disclaimer on the plan screen.
- The uploaded report bytes exist only in memory for one request; nothing is written to disk or persists between requests.
- For a real deployment: HTTPS, restrict CORS to your app's real domain, and rate-limit `/diet-plan`.

---

## 15. Implementation Phases

### Phase 0 – Project setup
- Create the Flutter project, add dependencies, create the folder structure from §6, apply the theme.
- **Accept when:** `flutter pub get` and `flutter analyze` pass and the app launches to the profile screen.

### Phase 1 – Models, landing, home, and profile UI
- Implement `UserProfile`, `DietPlan`, `LandingScreen`, `HomeScreen`, `AppRouter`, and the full profile form with validation.
- **Accept when:** first launch shows Landing → "Get Started" opens the Profile form; relaunching the app after `seen_landing` is set (and no profile saved) skips straight to the Profile form; relaunching after a profile is saved opens Home instead; invalid form input shows errors and valid input passes.

### Phase 2 – GPS location
- Implement `LocationService`, permissions, the location card, refresh, manual fallback.
- **Accept when:** the place name appears on device; denied permission/GPS off shows a clear message and manual entry works.

### Phase 3 – Report upload
- Implement `ReportPickerService`, the bottom sheet, preview, size check, replace action.
- **Accept when:** a PDF/image imports and a photo captures; files over 10 MB are rejected.

### Phase 4 – Backend and AI
- Implement the FastAPI backend per §12.
- **Accept when:** a `curl` request returns valid JSON matching §8, and allergens/dislikes never appear in the plan.

### Phase 5 – Connect app to backend
- Implement `ApiService`, `AppState`, wire the submit button, save/load profile locally.
- **Accept when:** the full flow works end to end for both 1-day and 7-day plans, and errors show a friendly message with retry.

### Phase 6 – Testing and polish
- Add unit tests for `DietPlan.fromJson` and form validation; add an app icon/splash; zero-warning `flutter analyze`.
- **Accept when:** tests pass and `flutter build apk` succeeds.

---

## 16. Final Deliverables

- Flutter app source in `lib/` and a working debug APK.
- Backend in `backend/` with `requirements.txt` and run instructions.
- `README.md` with setup steps (Flutter, backend, `kBaseUrl`, permissions).
