# Dr Gut – Complete Development Requirements & Implementation Roadmap (Starting from Splash Screen)

> **Document Purpose:** This document details everything required to build, test, and ship **Dr Gut** end-to-end, beginning from the initial **Splash Screen** and covering all screens, services, permissions, backend AI pipelines, testing, and final deliverables.

---

## 1. Executive Summary & Core Concept

**Dr Gut** is a cross-platform mobile application (**Flutter, Dart 3**, Android-first, iOS-compatible) that generates a custom, budget-conscious diet plan derived directly from a user's **blood test report** and their **real-time GPS location**.

### User Journey Overview
```
┌────────────────────────────────────────────────────────┐
│ 1. Splash Screen                                       │
│    - Brand identity, glowing pulse animation           │
│    - Preloads cached user profile & checks GPS status  │
└──────────────────────────┬─────────────────────────────┘
                           ▼
┌────────────────────────────────────────────────────────┐
│ 2. Profile & Health Form Screen                        │
│    - Name & 10-digit phone number                      │
│    - Auto-detected GPS location card + manual fallback │
│    - Health conditions, allergies, dislikes            │
│    - Daily budget (₹) & Plan length (1-day vs 7-day)   │
│    - Blood report upload tile (with privacy guarantee) │
└──────────────────────────┬─────────────────────────────┘
                           ▼
┌────────────────────────────────────────────────────────┐
│ 3. Report Picker Modal (Bottom Sheet)                  │
│    - Option A: Import from device (PDF, JPG, PNG)      │
│    - Option B: Camera capture (ImagePicker)            │
│    - Strict < 10MB size validation & preview thumbnail │
└──────────────────────────┬─────────────────────────────┘
                           ▼
┌────────────────────────────────────────────────────────┐
│ 4. Loading & AI Analysis Screen                        │
│    - Pulsing neon green circular glow animation        │
│    - 4 rotating stages of analysis progress            │
│    - 120s timeout safeguard                           │
└──────────────────────────┬─────────────────────────────┘
                           ▼
┌────────────────────────────────────────────────────────┐
│ 5. Personalized Diet Plan Screen                       │
│    - Clinical overview & detected deficiencies cards   │
│    - Day-by-day structured meal breakdown + "Why" line │
│    - Regional & budget-tailored food tips              │
│    - One-tap Copy / Share action                       │
│    - Prominent medical disclaimer                      │
└────────────────────────────────────────────────────────┘
```

---

## 2. Environment & Prerequisites

### 2.1 Tooling & SDKs
- **Flutter SDK:** Version 3.19+ (Dart 3.3+)
- **Android SDK:** Platform 34 / Android Studio & command-line tools
- **Python:** 3.11+ (for the FastAPI backend)
- **Anthropic API Key:** Claude API key with access to `claude-sonnet-5` (configured on the server as `ANTHROPIC_API_KEY`)

### 2.2 Flutter Dependencies (`pubspec.yaml`)
```yaml
name: dr_gut
description: AI-powered diet plans from blood reports and GPS location.
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: '>=3.3.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter
  google_fonts: ^6.2.1          # Poppins font family
  provider: ^6.1.2              # App state management
  http: ^1.2.2                  # Multipart API client
  geolocator: ^13.0.1           # High-accuracy GPS positioning
  geocoding: ^3.0.0             # Reverse geocoding (lat/lng to city)
  file_picker: ^8.1.2           # PDF & image file selection
  image_picker: ^1.1.2          # Camera photo capture
  shared_preferences: ^2.3.2    # Local persistence of user profile
  share_plus: ^10.0.0           # Native text share / copy capability

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.0
```

### 2.3 Backend Dependencies (`backend/requirements.txt`)
```txt
fastapi>=0.111.0
uvicorn[standard]>=0.30.0
python-multipart>=0.0.9
anthropic>=0.30.0
pydantic>=2.7.0
```

---

## 3. UI/UX Design System & Tokens

### 3.1 Color Palette
- **Background (`#0B0F0D`):** Near-black with subtle organic green undertone.
- **Surface (`#141A17`):** Glassy card and form input background.
- **Surface Border (`#2A332E`):** 1px subtle boundary for cards and text fields.
- **Primary Accent (`#22E38A`):** High-vibrancy electric mint green for buttons, badges, highlights.
- **Primary Gradient End (`#0FB86A`):** Used in linear gradient buttons and ambient glow.
- **On Primary (`#062017`):** Dark text used over green accents for crisp contrast.
- **Text Primary (`#F4F7F5`):** Headings and primary values.
- **Text Secondary (`#9AA6A0`):** Labels, subtitles, hints.
- **Text Muted (`#5E6A64`):** Timestamps, helper footnotes, disclaimers.
- **Error / Warning (`#FF6B6B`):** Validation alerts and lab deficiency tags.

### 3.2 Typography
- **Font Family:** `Poppins` via `GoogleFonts.poppinsTextTheme()`.
- **Display:** 28sp SemiBold (600) — Screen greetings.
- **Title:** 20sp SemiBold (600) — Section cards.
- **Body:** 15sp Regular (400) — Input fields, meal descriptions.
- **Label:** 13sp Medium (500) — Badges, time slots, chips.
- **Caption:** 12sp Regular (400) — Disclaimers, helper notes.

---

## 4. Screen-by-Screen Specifications

### Step 1: Splash Screen (`lib/screens/splash_screen.dart`)
* **Role:** Establish brand presence, eliminate perceived cold-start latency, and initialize runtime services.
* **UI Elements:**
  - Deep black-green background (`#0B0F0D`) with a soft radial green ambient glow (`#22E38A` at 12% opacity).
  - Central pulsating Dr. Gut brand mark: A health-shield / organic leaf emblem inside an illuminated circular ring.
  - Title: **Dr. Gut** (28sp Poppins SemiBold, `#F4F7F5`).
  - Subtitle: *"Precision Nutrition • Grounded in Your Blood Work"* (13sp, `#9AA6A0`).
  - Subtle bottom loading indicator or pulsing dots.
* **Under-the-Hood Actions:**
  1. Initialize `SharedPreferences` and load cached `UserProfile` (if returning user).
  2. Perform initial background GPS status check (`Geolocator.isLocationServiceEnabled()`).
  3. Pre-cache Google Fonts to avoid text popping.
  4. Smoothly navigate (fade transition, 300ms) to `ProfileScreen`.

---

### Step 2: Profile & Form Screen (`lib/screens/profile_screen.dart`)
* **Header:**
  - Hero Greeting: **"Let's build your plan"**
  - Subtitle: *"Personalized nutrition adapted to your biomarkers and location"*
* **Form Inputs (stacked with 14px vertical spacing, outlined borders, prefix icons):**
  1. **Full Name** (Required): Text input, capitalized.
  2. **Phone Number** (Required): 10 digits validation, numeric keyboard.
  3. **Location Card** (`lib/widgets/location_card.dart`):
     - Displays detected place name (e.g. *"Indiranagar, Bengaluru"*).
     - Circular refresh button to re-trigger GPS detection.
     - **Manual Fallback:** If GPS permission is denied or location is disabled, gracefully reveals a manual text input field for city/region.
  4. **Health Conditions / Diseases** (Optional): e.g. *"Hypertension, Fatty Liver, Hypothyroidism"*.
  5. **Allergies** (Optional): e.g. *"Peanuts, Lactose, Shellfish"* — strictly blacklisted in generated meals.
  6. **Disliked Foods** (Optional): e.g. *"Bitter gourd, Eggplant, Mustard"*.
  7. **Daily Budget in ₹** (Required): e.g. *"300"* — strictly enforced so recommendations stay accessible.
  8. **Plan Length Toggle**: `SegmentedButton` with **1 Day** and **7 Days** pill options.
  9. **Blood Report Upload Tile** (`lib/widgets/report_upload_tile.dart`):
     - Displays dashed/solid surface card with cloud-upload icon chip.
     - Includes privacy safety badge: *"Your report is processed in-memory and never permanently stored"*.
     - Shows selected file name and thumbnail when chosen, with a green "Replace" button.
* **Primary Action Button:**
  - Full-width `GradientPillButton` (56px height, pill radius 28px): **"Analyze & create my diet plan"**.
  - Validates all fields, ensures location exists, and ensures report file is attached.

---

### Step 3: Report Picker Modal (`lib/widgets/report_upload_tile.dart`)
* Triggered when tapping the upload tile.
* Displays a bottom sheet with rounded top corners (radius: 24px) and drag-handle.
* **Two interactive options:**
  1. **Import from device:** Uses `file_picker` allowing extensions `['pdf', 'jpg', 'jpeg', 'png']`.
  2. **Use camera:** Uses `image_picker` (`ImageSource.camera`, `imageQuality: 85`).
* **Validation:**
  - Calculates file size. If `fileSize > 10MB`, rejects selection and displays snackbar: *"File size exceeds 10MB limit. Please upload a compressed copy."*

---

### Step 4: Loading & AI Analysis Screen (`lib/screens/loading_screen.dart`)
* Displayed while awaiting the backend API call (20 to 60 seconds).
* **Visuals:**
  - Ambient glowing green ring rotating at 6s/loop with an opacity pulse.
  - Large display title: **"Analyzing your biomarkers"**
  - **Cycling Status Messages** (transitions every 3.5 seconds):
    1. *"Reading your report…"*
    2. *"Checking nutrient levels & out-of-range markers…"*
    3. *"Finding foods available near your location…"*
    4. *"Building your personalized diet plan…"*
* **Safety:** 120-second timeout. If the request fails or times out, prompts user with a clear error message and a "Try Again" CTA.

---

### Step 5: Diet Plan Screen (`lib/screens/plan_screen.dart`)
* **App Bar:**
  - Transparent app bar with title **"Your Plan"**.
  - Circular icon action on top right: **Share / Copy** (exports full plan formatted as plain text).
* **Summary Card:**
  - Comprehensive clinical overview generated by Claude summarizing the patient's profile and nutritional strategy.
* **"Findings from your report" Section:**
  - Horizontal or vertical cards for each flagged lab finding (e.g. *Iron — Hb 9.8 g/dL (low)*, *Vitamin D3 — 14 ng/mL (insufficient)*).
  - Decorated with red-tinted warning icon chip (`#FF6B6B` at 15% opacity).
* **Day-by-Day Meal Plan Cards:**
  - One card per day (`Day 1` through `Day 7`).
  - Contains meals ordered by time: Breakfast, Lunch, Snack, Dinner.
  - Each meal specifies items and a distinct *"Why"* line (e.g. *"Spinach soup & lemon — high non-heme iron boosted by Vitamin C absorption"*).
* **"Local Tips" Section:**
  - Card highlighting region-specific, cost-effective foods matching the detected GPS coordinates and budget.
* **Mandatory Medical Disclaimer:**
  - Pinned at bottom: *"General dietary guidance, not medical advice. Consult a doctor or dietitian before making significant dietary changes."*

---

## 5. Mobile Services Architecture

```
lib/
├── config.dart                     # kBaseUrl (http://10.0.2.2:8000 for emulator, LAN IP for phone)
├── main.dart                       # App entry, ThemeData, MultiProvider setup
├── theme.dart                      # DrGutColors, buildDrGutTheme(), GradientPillButton, IconChip
├── models/
│   ├── user_profile.dart           # UserProfile (name, phone, GPS lat/lng, allergies, budget, etc.)
│   └── diet_plan.dart              # DietPlan, Deficiency, PlanDay, Meal (null-tolerant fromJson)
├── services/
│   ├── location_service.dart       # Geolocator + Geocoding with typed error exceptions
│   ├── report_picker_service.dart  # FilePicker & ImagePicker abstraction
│   ├── api_service.dart            # Multipart HTTP POST client with 120s timeout
│   └── storage_service.dart        # SharedPreferences saveProfile & loadProfile
├── providers/
│   └── app_state.dart              # State machine: idle | locating | loading | error | done
├── screens/
│   ├── splash_screen.dart          # Animated startup splash & cache loader
│   ├── profile_screen.dart         # Main input form & triggers
│   ├── loading_screen.dart         # Pulsing glow loading state
│   └── plan_screen.dart            # Output display, share action, disclaimer
└── widgets/
    ├── location_card.dart          # GPS status, refresh action & manual fallback
    ├── report_upload_tile.dart     # Upload tile & bottom sheet selector
    └── meal_card.dart              # Structured meal presentation
```

---

## 6. Backend Specifications (`backend/main.py`)

### 6.1 Server Architecture
- **Framework:** FastAPI with Uvicorn.
- **CORS:** Enabled for all development origins.
- **Endpoints:**
  - `GET /health` → Returns `{"status": "ok"}`
  - `POST /diet-plan` → Multipart/form-data ingestion

### 6.2 Multipart Form Request Contract
| Field Name | Type | Description |
|---|---|---|
| `name` | String | User's full name |
| `phone` | String | 10-digit mobile number |
| `location` | String | Formatted place name |
| `lat`, `lng` | String / Float | Exact GPS coordinates |
| `disease` | String | Known medical conditions (optional) |
| `allergies` | String | Allergens to exclude (optional) |
| `dislikes` | String | Disliked ingredients to exclude (optional) |
| `budget` | String / Int | Daily budget in INR |
| `plan_type` | String | `'day'` or `'week'` |
| `report` | File | PDF / JPG / PNG binary |

### 6.3 AI Processing Pipeline
1. Ingest file into memory using `UploadFile.read()`.
2. Convert file bytes into base64 string (**strictly never write file to disk**).
3. Determine media type:
   - JPG / PNG → Anthropic `image` block.
   - PDF → Anthropic `document` block.
4. Construct prompt injecting user coordinates, budget constraints, allergy blacklists, and medical history.
5. Invoke `claude-sonnet-5` with `max_tokens: 6000`.
6. Parse JSON output, strip any markdown backticks (` ```json `), and validate against Pydantic schema.
7. Retry once upon validation failure; if retry fails, return `500` error with friendly detail.

### 6.4 Response Payload (200 OK)
```json
{
  "summary": "Clinical and nutritional overview of the findings...",
  "deficiencies": [
    {
      "name": "Iron Deficiency",
      "finding": "Hemoglobin 9.8 g/dL (Normal: 12.0-15.5)"
    }
  ],
  "days": [
    {
      "day": "Day 1",
      "meals": [
        {
          "time": "Breakfast (8:30 AM)",
          "items": "Sprouted moong & methi chilla with mint chutney",
          "why": "High iron and folic acid to support hemoglobin synthesis"
        }
      ]
    }
  ],
  "local_notes": "All recommended ingredients are readily available at local markets within your budget."
}
```

---

## 7. Native Permissions & Configuration

### 7.1 Android (`android/app/src/main/AndroidManifest.xml`)
```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <!-- Internet & Network -->
    <uses-permission android:name="android.permission.INTERNET"/>
    
    <!-- GPS Location -->
    <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
    
    <!-- Camera -->
    <uses-permission android:name="android.permission.CAMERA"/>

    <application
        android:label="Dr Gut"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher"
        android:usesCleartextTraffic="true"> <!-- Needed for local emulator/LAN backend -->
        ...
    </application>
</manifest>
```

### 7.2 iOS (`ios/Runner/Info.plist`)
```xml
<key>NSLocationWhenInUseUsageDescription</key>
<string>Dr Gut requires your location to recommend affordable, locally available foods in your region.</string>
<key>NSCameraUsageDescription</key>
<string>Dr Gut requires camera access so you can take a clear photo of your blood report.</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>Dr Gut requires access to your photo library to upload your blood report.</string>
```

---

## 8. Privacy, Security & Compliance Rules

1. **Zero Disk Storage:** Uploaded reports are read directly into memory buffers, base64-encoded, sent to the model, and immediately released.
2. **API Key Isolation:** The Anthropic API key is strictly stored in backend environment variables (`os.environ["ANTHROPIC_API_KEY"]`) and is never packaged inside the Flutter mobile binary.
3. **Medical Disclaimer:** The disclaimer *"General dietary guidance, not medical advice. Consult a doctor or dietitian."* must remain clearly visible on the plan screen.
4. **Allergen Protection:** Prompts explicitly enforce strict exclusion of any food items listed under allergies.

---

## 9. Testing & Acceptance Criteria

### 9.1 Phase-by-Phase Verification
- [ ] **Phase 0 (Setup & Theme):** Flutter app compiles; dark palette and Poppins font verified.
- [ ] **Phase 1 (Models & Validation):** Form rejects empty names, invalid 10-digit phones, zero budget; models serialize correctly.
- [ ] **Phase 2 (GPS Location):** Detects latitude/longitude and converts to city name; manual input appears when GPS is denied.
- [ ] **Phase 3 (Report Upload):** Imports PDF/JPG/PNG and captures photo; rejects files > 10MB; displays preview and replace button.
- [ ] **Phase 4 (Backend AI):** FastAPI responds with validated JSON; allergens and disliked foods are excluded.
- [ ] **Phase 5 (End-to-End Integration):** Full journey from Splash Screen → Form → Upload → Loading Animation → Diet Plan Screen.
- [ ] **Phase 6 (Linting & APK Build):**
  - Zero warnings on `flutter analyze`.
  - Unit tests pass for `DietPlan.fromJson` and `UserProfile`.
  - App builds cleanly via `flutter build apk --debug`.

---

## 10. Final Deliverables Checklist
1. **Flutter Mobile Source Code:** Fully functional source code under `lib/`.
2. **FastAPI Backend Server:** `backend/main.py` with `requirements.txt`.
3. **Setup & Run Documentation:** Comprehensive instructions covering backend execution, setting `kBaseUrl`, and running on Android emulators or physical devices.
4. **Working Android APK:** Tested debug build demonstrating the complete user experience.
