# Dr Gut – Implementation Spec (for Antigravity agent)

> **Instruction to the agent:** Build the app described below exactly as specified. Work through the phases in order. After each phase, run `flutter analyze` (and `flutter test` if tests exist) and fix all errors before starting the next phase. Do not skip acceptance criteria. Ask the user only if something here is contradictory or missing.

---

## 1. Goal

Build **Dr Gut**, a cross-platform mobile app (**Flutter, Dart 3**, Android first, iOS-compatible) that creates a personalised diet plan from a user's **blood report** and **current GPS location**.

**Frontend is the priority and must be Flutter.**

---

## 2. How the App Works (user-facing workflow)

1. **App opens → Profile form.** User enters name and phone. GPS location is detected automatically in the background and shown as a place name (with a refresh button and a manual fallback if GPS fails). User optionally adds disease, allergies, disliked foods, then enters a daily budget and picks **1-day** or **7-day** plan.
2. **Upload blood report.** User taps the upload tile, chooses **Import from device** or **Use camera**, and the selected file is shown with its name.
3. **Submit.** User taps "Analyze & create my diet plan." The app validates the form (report + location required) and shows a loading screen while it waits.
4. **Behind the scenes**, the app sends the profile, GPS coordinates, and the report file to the backend server (see section 3).
5. **Plan screen.** The app shows the findings from the report (e.g. "Iron — low"), the day-by-day meal plan with a short reason for each meal, local tips, and a not-medical-advice disclaimer.

---

## 3. How the Backend and AI Work

1. **Request in.** Flutter sends one multipart `POST /diet-plan` request containing all profile fields, GPS coordinates, and the report file.
2. **File handling.** The backend reads the uploaded file into memory and base64-encodes it. It is **never written to disk** — used only for this one request, then discarded.
3. **Prompt building.** The backend fills the prompt template (section 9) with the user's details — location, conditions, allergies, dislikes, budget, plan length.
4. **AI call.** The backend sends the prompt **and** the encoded report together in one request to the AI model (`claude-sonnet-5`), so the model reads the actual report rather than guessing from text alone.
5. **What the model does.** It reads the values in the report, compares them to normal ranges, identifies deficiencies, chooses foods that correct them, filters out allergens/dislikes, favours foods realistically available in the user's region, stays within budget, and replies in **JSON only** (no prose).
6. **Response handling.** The backend strips any ```json fences from the reply, parses it, and validates it has the required fields (`summary`, `deficiencies`, `days`, `local_notes`). If parsing fails, it retries once, then returns a `500` error.
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
```

---

## 6. Project Structure

```
dr_gut/
├── lib/
│   ├── main.dart                     # app entry, theme, providers
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
└── gut_implemetation.md
```

---

## 7. Data Models

**`UserProfile`** – `name` (String), `phone` (String), `locationName` (String), `lat` (double), `lng` (double), `disease` (String, may be empty), `allergies` (String, may be empty), `dislikes` (String, may be empty), `budget` (int, rupees per day), `planType` (`'day'` | `'week'`). Include `toJson()`, `fromJson()`, `copyWith()`.

**`DietPlan`** – `summary` (String), `deficiencies` (`List<Deficiency>` with `name`, `finding`), `days` (`List<PlanDay>` with `day` and `List<Meal>`), `localNotes` (String). `Meal` has `time`, `items`, `why`. Include `DietPlan.fromJson()` that tolerates missing/null fields.

---

## 8. Screens

### 8.1 Profile screen (`profile_screen.dart`)
Fields in order, all with prefix icons and outlined borders:

| Field | Rules |
|---|---|
| Name | required |
| Phone number | required, digits only, 10 digits |
| Location card | auto-filled by GPS on screen open; shows place name; refresh button; if GPS fails show error text and a **manual location text field** as fallback |
| Any disease | optional |
| Any allergies | optional |
| Foods you dislike | optional |
| Budget per day (₹) | required, numeric > 0 |
| Plan length | `SegmentedButton`: **1 day** / **7 days** |
| Blood report | upload tile (see 8.2) |

Primary button **"Analyze & create my diet plan"**: validates the form, requires location and a report, then calls the API and navigates to the plan screen. Disable the button while loading. Load a saved profile from `shared_preferences` on start and save it after a successful request.

### 8.2 Report upload
Tapping the tile opens a bottom sheet with exactly two options:
1. **Import from device** – `file_picker`, allowed extensions `pdf, jpg, jpeg, png`.
2. **Use camera** – `image_picker` with `ImageSource.camera`, `imageQuality: 85`.

After selection show the file name (and an image thumbnail for images) with a **Replace** action. Reject files larger than **10 MB** with a snackbar message.

### 8.3 Loading screen
Shown while waiting for the backend (can take up to 60+ seconds). Show a progress indicator and rotating status text: "Reading your report…", "Checking nutrient levels…", "Finding foods available near you…", "Building your plan…".

### 8.4 Plan screen (`plan_screen.dart`)
- Summary text at the top.
- Section **"Findings from your report"**: one card per deficiency (name + finding).
- One card per day (`Day 1`…) with meals listed by time; each meal shows items and a smaller "why" line.
- Section **"Local tips"** showing `localNotes`.
- Disclaimer text at the bottom.
- App bar action to **share/copy the plan as text**.

---

## 9. Services

**`LocationService`**
```dart
Future<LocationResult> getCurrentLocation();
// Checks isLocationServiceEnabled -> checkPermission/requestPermission ->
// getCurrentPosition -> placemarkFromCoordinates.
// Throws typed errors: GpsDisabled, PermissionDenied, PermissionDeniedForever, Timeout.
// LocationResult { double lat; double lng; String placeName; }
```
`placeName` = subLocality, locality, administrativeArea, country (skip empty parts, comma separated).

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

**`StorageService`** – `saveProfile`, `loadProfile` using `shared_preferences`.

**`AppState` (ChangeNotifier)** – holds `UserProfile`, `File? report`, `DietPlan? plan`, `status` (`idle | locating | loading | error | done`), and `errorMessage`.

---

## 10. API Contract

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
Errors: `400` unreadable/invalid report, `422` bad fields, `500` AI/parsing failure. Body: `{"detail": "message"}`.

---

## 11. Backend (`backend/main.py`)

- FastAPI app, CORS enabled for development, single `POST /diet-plan` endpoint plus `GET /health`.
- Read the uploaded file, base64-encode it, send it to the model as an `image` block (JPG/PNG) or `document` block (PDF) together with the prompt below.
- Model: `claude-sonnet-5`, `max_tokens` 6000.
- Strip markdown code fences from the reply, parse JSON, validate required keys; on failure retry once, then return `500`.
- Do not write the uploaded file to disk.
- Run with `uvicorn main:app --host 0.0.0.0 --port 8000`.

**Prompt template**
```
You are a nutrition assistant. Read the attached blood report and find values
outside the normal range (e.g. haemoglobin, ferritin, vitamin B12, vitamin D,
calcium, cholesterol, glucose, thyroid).

User: {name}. Location: {location} (lat {lat}, lng {lng}).
Conditions: {disease}. Allergies: {allergies}. Dislikes: {dislikes}.
Budget: Rs {budget} per day. Plan length: {days} day(s).

Create a diet plan that corrects the deficiencies using foods commonly and
cheaply available in that local area/region and season. Never include
allergens or disliked foods. Stay within the budget. If the report is unreadable
or not a blood report, reply with {"error": "reason"}.

Reply with ONLY JSON in the agreed shape (summary, deficiencies, days, local_notes).
```

---

## 12. Permissions and Config

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

## 13. Implementation Phases

### Phase 0 – Project setup
- Create the Flutter project `dr_gut`, add dependencies, create the folder structure from section 6, set the Material 3 theme (green seed colour).
- **Accept when:** `flutter pub get` and `flutter analyze` pass and the app launches to an empty profile screen.

### Phase 1 – Models and profile UI
- Implement `UserProfile`, `DietPlan`, and the profile form with all validation from 8.1 (report and location can be stubbed).
- **Accept when:** invalid input shows errors and valid input passes validation.

### Phase 2 – GPS location
- Implement `LocationService`, permissions, `location_card.dart`, auto-detect on open, refresh button, manual fallback.
- **Accept when:** on a device the place name appears; denying permission or turning GPS off shows a clear message and the manual field works.

### Phase 3 – Report upload
- Implement `ReportPickerService`, the bottom sheet with both options, file preview, size check, replace action.
- **Accept when:** a PDF/image can be imported and a photo can be taken; files over 10 MB are rejected.

### Phase 4 – Backend and AI
- Implement the FastAPI backend per section 11 and `requirements.txt`.
- **Accept when:** a `curl` multipart request with a sample report returns valid JSON matching section 10, and allergens/dislikes never appear in the plan.

### Phase 5 – Connect app to backend
- Implement `ApiService`, `AppState`, loading screen and plan screen; wire the submit button; save/load profile locally.
- **Accept when:** the full flow works end to end from form to rendered plan for both 1-day and 7-day options, and errors (no internet, server error, bad report) show a friendly message with a retry option.

### Phase 6 – Testing and polish
- Add unit tests for `DietPlan.fromJson` (including missing fields) and form validation; add an app icon and splash screen; final `flutter analyze` with zero warnings.
- **Accept when:** tests pass and the app builds with `flutter build apk`.

---

## 14. Privacy and Safety

- A blood report is sensitive health data. Tell the user on the upload tile that the report is used only to create their plan.
- Use HTTPS in production; keep the API key on the server only.
- If the report is unclear, ask the user to retake or upload a clearer copy rather than guessing values.
- Always show the not-medical-advice disclaimer on the plan screen.

---

## 15. Final Deliverables

- Flutter app source in `lib/` and a working debug APK.
- Backend in `backend/` with `requirements.txt` and run instructions.
- `README.md` with setup steps (Flutter, backend, `kBaseUrl`, permissions).
