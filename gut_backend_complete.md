# Dr Gut – Backend (Complete, Self-Contained)

> **Instruction to the agent:** This single file is everything needed to build Dr Gut's backend — no other file needs to be open at the same time. It exposes exactly the API contract the Flutter frontend expects, so the two connect with zero changes on either side.

---

## 1. Scope and Goal

Build a small **FastAPI** service that:
1. Receives the user's profile, GPS location, and an uploaded blood report from the Flutter app.
2. Sends the report and a prompt to the **Claude API** so the model can read the report and build a diet plan.
3. Returns a clean, validated JSON diet plan (or a clear error) back to the app.

The backend is the **only** place the AI API key exists. It is read from an environment variable and never sent to, or requested by, the mobile app — anything shipped inside an app binary can eventually be extracted, so the key must never live there.

---

## 2. How It Fits Into the Whole App

1. **Request in.** The Flutter app sends one multipart `POST /diet-plan` request containing every profile field, GPS coordinates, and the report file.
2. **File handling.** The backend reads the uploaded file into memory and base64-encodes it. It is **never written to disk** — used only for this one request, then discarded.
3. **Prompt building.** The backend fills a prompt template with the user's details — location, conditions, allergies, dislikes, budget, plan length.
4. **AI call.** The backend sends the prompt **and** the encoded report together in one request to `claude-sonnet-5`, so the model reads the actual report rather than guessing from text alone.
5. **What the model does.** It reads the values in the report, compares them to normal ranges, identifies deficiencies, chooses foods that correct them, filters out allergens/dislikes, favours foods realistically available in the user's region, stays within budget, and replies in **JSON only**.
6. **Response handling.** The backend strips any stray ```json fences, parses the reply, and validates it has the required fields. If parsing fails, it retries once, then returns a `500` error.
7. **Response out.** The backend returns the clean JSON to the app. No AI logic ever runs on the phone.

---

## 3. Tech Stack

| Purpose | Choice |
|---|---|
| Web framework | FastAPI |
| Server | `uvicorn` |
| Multipart form parsing | `python-multipart` |
| AI SDK | `anthropic` |
| Data validation | `pydantic` |
| AI model | `claude-sonnet-5` |
| Language | Python 3.11+ |

---

## 4. Project Structure

```
backend/
├── main.py
└── requirements.txt
```

That's the whole backend — deliberately a single file for a course project. If it grows later, split `main.py` into `models.py` (the Pydantic response model), `prompts.py` (the template), and `ai_client.py` (the `_call_model`/`_strip_code_fences` helpers), keeping `main.py` as just the route definitions.

---

## 5. API Contract

`POST /diet-plan` (multipart/form-data)

| Field | Type | Notes |
|---|---|---|
| name, phone | text | required |
| location, lat, lng | text | from the app's GPS (or manual entry) |
| disease, allergies, dislikes | text | optional, may be empty string |
| budget | text | rupees per day |
| plan_type | text | `day` or `week` |
| report | file | PDF / JPG / PNG, ≤10 MB |

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

**Error responses** — all return `{"detail": "message"}`:

| Situation | Status | `detail` |
|---|---|---|
| Unsupported file type | 400 | "Unsupported file type: ... Use PDF, JPG or PNG." |
| Empty file | 400 | "Uploaded report is empty." |
| File over 10 MB | 400 | "Report is larger than 10 MB." |
| Model can't read the report, after one retry | 500 | "Could not read this report clearly. Please try a clearer photo or a PDF." |
| Model returns invalid JSON twice | 500 | Same as above |
| Anthropic API/network/auth failure | 502 | "AI service is unavailable right now." |

`GET /health` — returns `{"status": "ok"}`, used only to confirm the server is reachable.

---

## 6. Full Code

### `backend/main.py`
```python
"""Dr Gut backend.

Reads a blood report (image or PDF), sends it plus the user's profile and
GPS location to the Claude API, and returns a structured JSON diet plan.

Setup:
    pip install -r requirements.txt
    export ANTHROPIC_API_KEY=sk-ant-...
    uvicorn main:app --host 0.0.0.0 --port 8000

The uploaded report is read into memory and never written to disk.
The API key is read only from the environment - it is never sent to,
or stored by, the Flutter app.
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

# CORS is open for development so the Flutter app (running on an emulator,
# a device, or Flutter web) can reach this server without extra config.
# Restrict allow_origins to your real domain before shipping this anywhere
# public.
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
    """Claude sometimes wraps JSON in ```json ... ``` even when told not to.
    Strip that safely before parsing."""
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
    data = json.loads(cleaned)  # raises json.JSONDecodeError -> caught below

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
    # --- validate the upload -------------------------------------------------
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

    # --- build the request to the model -------------------------------------
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

    # --- call the model, with one retry on a bad/invalid reply --------------
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
            # Network/auth/rate-limit errors from the model provider itself -
            # not worth retrying blindly, fail fast with a clear message.
            log.error("Anthropic API error: %s", e)
            raise HTTPException(status_code=502, detail="AI service is unavailable right now.")

    log.error("diet-plan failed for %s after retries: %s", name, last_error)
    raise HTTPException(
        status_code=500,
        detail="Could not read this report clearly. Please try a clearer photo or a PDF.",
    )
```

### `backend/requirements.txt`
```
fastapi==0.115.0
uvicorn[standard]==0.30.6
python-multipart==0.0.9
anthropic==0.34.2
pydantic==2.9.2
```

---

## 7. Code Walkthrough

**Configuration constants** (top of file) — `MODEL`, `MAX_TOKENS`, `MAX_REPORT_BYTES`, `ALLOWED_CONTENT_TYPES`, `REQUIRED_KEYS` are all centralised at the top so they're easy to find and tune. `ALLOWED_CONTENT_TYPES` is the single dict that drives both the validation check ("is this file type acceptable?") and the content-block type sent to Claude (`document` for PDFs, `image` for photos) — one source of truth for "what files are acceptable."

**CORS** — wide open (`allow_origins=["*"]`) purely so the Flutter app can reach the server during development from an emulator, a real device on the same Wi-Fi, or Flutter web without CORS errors. Restrict this to your real domain before deploying anywhere public.

**The prompt template** includes an explicit escape hatch: *"If the report is unreadable or not a blood report, reply with `{"error": "reason"}` instead."* This gives the model a clean way to say "I can't do this" instead of hallucinating a plan from a document that isn't a blood report — the backend specifically checks for that `error` key in `_call_model`.

**`_strip_code_fences(text)`** — a small defensive helper. Even when explicitly told "reply with ONLY JSON," models sometimes still wrap answers in ```` ```json ... ``` ```` fences. This strips a leading/trailing fence (with or without the `json` tag) so `json.loads()` doesn't fail on otherwise-valid JSON — it only touches fence markers, never the actual content.

**`_call_model(prompt, block)`** — the one place that talks to Claude:
1. Sends a single `messages.create()` call with **both** the report (`block`) and the instructions (`prompt`) in the same message — this is what lets the model actually read the report rather than reason about it blindly.
2. Joins all `text`-type content parts from the reply (defensive in case a long reply is split across multiple text blocks).
3. Strips fences, then `json.loads()`.
4. Raises `ValueError` if the reply contains an `"error"` key, or if any of the four `REQUIRED_KEYS` are missing (naming exactly which keys are missing, for fast debugging).
5. Returns the parsed `dict` only once both checks pass.

**`/health`** — trivial `GET` returning `{"status": "ok"}`. Not used by the app itself, but the fastest way to confirm the server is reachable before debugging the real endpoint.

**`/diet-plan`** — declared with `response_model=DietPlanResponse` so FastAPI validates and documents the response shape automatically.
- **Validate first, cheaply:** reject wrong content types, empty files, and files over 10 MB with `400` *before* touching the AI — so bad input fails in milliseconds, not after a 30–60 second AI round trip.
- **Build the request:** base64-encode the bytes, pick the right block type, fill the prompt (defaulting the three optional fields to the literal word `"none"` when empty so the model sees a clean instruction rather than a blank), and convert `plan_type` into an actual day count (`1` or `7`).
- **Call with one retry:** a `for attempt in (1, 2)` loop. `json.JSONDecodeError` or `ValueError` (bad JSON, missing keys, or the model's own `{"error": ...}` reply) → logged as a warning, loop continues. `anthropic.APIError` (network/auth/rate-limit) → logged as an error and raises `502` **immediately**, without retrying, since retrying an auth failure just wastes time and quota. If both attempts fail on parsing/validation, falls through to a final `500` with a message written for the end user, not a developer — exactly the string a `SnackBar` on the Flutter side can show as-is.

**Logging** — every attempt, success, and failure is logged with the user's name and attempt number via the standard `logging` module, so a course demo or debugging session can see exactly what happened without adding print statements.

---

## 8. Running and Testing It

**Run the server**
```bash
cd backend
pip install -r requirements.txt
export ANTHROPIC_API_KEY=sk-ant-...      # your real key, never committed to git
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```
`--host 0.0.0.0` (not `127.0.0.1`) matters — it lets a phone on the same Wi-Fi network reach the server via your PC's LAN IP, not just the PC itself.

**Confirm it's alive**
```bash
curl http://localhost:8000/health
# {"status":"ok"}
```

**Test the real endpoint without the app**, using a sample report image:
```bash
curl -X POST http://localhost:8000/diet-plan \
  -F "name=Test User" \
  -F "phone=9999999999" \
  -F "location=Coimbatore, Tamil Nadu" \
  -F "lat=11.0168" \
  -F "lng=76.9558" \
  -F "disease=" \
  -F "allergies=peanuts" \
  -F "dislikes=mushrooms" \
  -F "budget=300" \
  -F "plan_type=day" \
  -F "report=@sample_report.jpg;type=image/jpeg"
```
A correct response is a JSON body with `summary`, `deficiencies`, `days`, and `local_notes`. Check specifically that nothing in the returned plan mentions peanuts or mushrooms — that confirms the allergy/dislike filtering is working. Try again with `plan_type=week` and confirm `days` contains 7 entries.

**Connect the Flutter app:** set `kBaseUrl` in the frontend to:
- `http://10.0.2.2:8000` if running on the Android emulator (this is the emulator's special alias for your PC's `localhost`),
- `http://<your-PC's-LAN-IP>:8000` if running on a real phone on the same Wi-Fi (find the IP with `ipconfig` on Windows or `ifconfig`/`ip addr` on Mac/Linux).

---

## 9. Privacy and Security

- The uploaded report bytes exist only in memory for the duration of one request; `main.py` never writes them to disk, and nothing persists between requests.
- The API key is read once at process start from the environment and never appears in a response, a log line, or an error message.
- For any real deployment (beyond a course demo run on localhost): put this behind HTTPS, restrict `allow_origins` to your actual app's domain, and consider rate-limiting `/diet-plan` since each call costs real AI usage.
- Tell the user (on the frontend) why the report is being uploaded and that it isn't stored — this backend's behavior (no disk writes) already matches that promise.

---

## 10. Implementation Phases (backend only)

### Phase 1 – Skeleton
- Create `backend/main.py` and `requirements.txt`; implement `/health` only.
- **Accept when:** `uvicorn main:app` starts and `curl http://localhost:8000/health` returns `{"status":"ok"}`.

### Phase 2 – Upload and validation
- Implement `/diet-plan`'s form fields and the file-type/size/empty checks, returning the right `400` for each, without calling the AI yet.
- **Accept when:** a `curl` request with a bad file type or an oversized file returns the correct `400` and message; a good file passes through.

### Phase 3 – AI integration
- Implement the prompt template, `_call_model`, `_strip_code_fences`, and the base64/content-block building.
- **Accept when:** a real request with a real blood report returns valid JSON matching the API contract in §5.

### Phase 4 – Robustness
- Add the retry loop, the `anthropic.APIError` fast-fail path, and logging.
- **Accept when:** temporarily feeding a corrupted/non-report image still returns a clean `500` with the user-facing message (not a raw stack trace), and the server logs show what happened.

### Phase 5 – Connect to the frontend
- Set `kBaseUrl` in the Flutter app and run the full flow end to end.
- **Accept when:** submitting the form in the app returns a real plan on the Plan screen, and a deliberately-bad upload shows the right error in the app's UI.

---

## 11. Deliverables

- `backend/main.py`
- `backend/requirements.txt`
- Confirmed working via the `curl` tests in §8, with a screenshot or log excerpt for the demo.
- `ANTHROPIC_API_KEY` set locally (never committed to git — add a `.env`-style note or `.gitignore` entry if you keep it in a file).
