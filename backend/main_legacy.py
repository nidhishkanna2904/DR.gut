"""Dr Gut backend — production-ready FastAPI service.

Reads a blood report (image or PDF), sends it plus the user's profile and
GPS location to the Claude API, and returns a structured JSON diet plan.

Setup:
    pip install -r requirements.txt
    set ANTHROPIC_API_KEY=sk-ant-...   (Windows CMD)
    # OR
    $env:ANTHROPIC_API_KEY="sk-ant-..." (Windows PowerShell)
    uvicorn main:app --host 0.0.0.0 --port 8000 --reload

The uploaded report is read into memory and never written to disk.
The API key is read only from the environment — it is never sent to,
or stored by, the Flutter app.
"""
import base64
import json
import logging
import os
import re

import anthropic
from fastapi import FastAPI, File, Form, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)-8s %(name)s — %(message)s",
)
log = logging.getLogger("dr_gut")

app = FastAPI(title="Dr Gut API", version="1.0.0")

# CORS: open for development so Android emulator, physical device, or Flutter
# web can reach this server. Restrict allow_origins before shipping publicly.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── Anthropic client ─────────────────────────────────────────────────────────
# Reads ANTHROPIC_API_KEY automatically from the environment.
# Raises anthropic.AuthenticationError at runtime if the key is missing/wrong.
client = anthropic.Anthropic()

# ── Constants ────────────────────────────────────────────────────────────────
# "claude-sonnet-4-5" is the production alias; fall back to env override so
# a user can swap to claude-3-5-sonnet-20241022 or any other model without
# editing code.
MODEL = os.getenv("DR_GUT_MODEL", "claude-sonnet-4-5")
MAX_TOKENS = 6000
MAX_REPORT_BYTES = 10 * 1024 * 1024   # 10 MB — matches the Flutter app limit

ALLOWED_CONTENT_TYPES: dict[str, str] = {
    "application/pdf": "document",
    "image/jpeg": "image",
    "image/jpg": "image",
    "image/png": "image",
}

REQUIRED_KEYS = {"summary", "deficiencies", "days", "local_notes"}

# ── Prompt template ──────────────────────────────────────────────────────────
PROMPT = """\
You are a clinical nutrition assistant. Read the attached blood report and
identify any markers outside normal laboratory ranges (e.g. haemoglobin,
ferritin, vitamin B12, vitamin D, calcium, lipid profile, fasting/postprandial
glucose, HbA1c, thyroid panel).

User: {name}. Location: {location} (lat {lat}, lng {lng}).
Conditions: {disease}. Allergies: {allergies}. Dislikes: {dislikes}.
Budget: Rs {budget} per day. Plan length: {days} day(s).

Create a realistic diet plan that targets and helps correct the identified
deficiencies using foods commonly and cheaply available in that local
geographical area/region and season.
Strict rule: NEVER include any allergens or disliked foods under any circumstance.
Strict rule: Stay strictly within the user's daily budget.
If the report is unreadable or not a blood report, reply with {{"error": "reason"}}.

Reply with ONLY JSON, no markdown fences, no conversational prose, in exactly
this JSON structure:
{{
  "summary": "Clinical and nutritional overview of the findings and strategy",
  "deficiencies": [
    {{"name": "Marker Name (e.g. Iron)", "finding": "Result value and brief clinical note"}}
  ],
  "days": [
    {{
      "day": "Day 1",
      "meals": [
        {{"time": "Breakfast (8:30 AM)", "items": "Description of food items", "why": "Clinical/nutritional rationale"}}
      ]
    }}
  ],
  "local_notes": "Regional purchasing tips and seasonal food availability near the location"
}}\
"""


# ── Pydantic response models ─────────────────────────────────────────────────
class DietPlanResponse(BaseModel):
    summary: str
    deficiencies: list[dict]
    days: list[dict]
    local_notes: str


# ── Helper functions ─────────────────────────────────────────────────────────
def _strip_code_fences(text: str) -> str:
    """Claude sometimes wraps JSON in ```json ... ``` even when told not to.
    Strip that safely before parsing — only touches fence markers."""
    text = text.strip()
    text = re.sub(r"^```(?:json)?\s*", "", text)
    text = re.sub(r"\s*```$", "", text)
    return text.strip()


def _build_content_block(raw_bytes: bytes, content_type: str) -> dict:
    """Build the Anthropic content block for either an image or a document."""
    encoded = base64.b64encode(raw_bytes).decode("utf-8")
    block_type = ALLOWED_CONTENT_TYPES[content_type]

    if block_type == "document":
        # PDF: use the document content block format
        return {
            "type": "document",
            "source": {
                "type": "base64",
                "media_type": content_type,
                "data": encoded,
            },
        }
    else:
        # JPEG / PNG: use the image content block format
        return {
            "type": "image",
            "source": {
                "type": "base64",
                "media_type": content_type,
                "data": encoded,
            },
        }


def _call_model(prompt: str, block: dict) -> dict:
    """Send one request to Claude and parse its JSON reply.

    Raises:
        json.JSONDecodeError  — model did not return valid JSON.
        ValueError            — JSON is valid but has an 'error' key or is
                                missing required keys.
        anthropic.APIError    — network / auth / rate-limit failure from the
                                Anthropic API itself.
    """
    msg = client.messages.create(
        model=MODEL,
        max_tokens=MAX_TOKENS,
        messages=[
            {
                "role": "user",
                "content": [block, {"type": "text", "text": prompt}],
            }
        ],
    )
    raw = "".join(part.text for part in msg.content if part.type == "text")
    log.debug("Raw model output (first 300 chars): %s", raw[:300])

    cleaned = _strip_code_fences(raw)
    data = json.loads(cleaned)      # raises json.JSONDecodeError → caught by caller

    if "error" in data:
        raise ValueError(data["error"])
    missing = REQUIRED_KEYS - data.keys()
    if missing:
        raise ValueError(f"Model response missing required keys: {missing}")
    return data


# ── Routes ───────────────────────────────────────────────────────────────────
@app.get("/health", tags=["meta"])
def health():
    """Liveness check — confirms the server is reachable."""
    return {"status": "ok", "app": "Dr Gut API", "model": MODEL}


@app.post("/diet-plan", response_model=DietPlanResponse, tags=["diet"])
async def diet_plan(
    name: str = Form(...),
    phone: str = Form(...),
    location: str = Form(...),
    lat: float = Form(0.0),
    lng: float = Form(0.0),
    disease: str = Form(""),
    allergies: str = Form(""),
    dislikes: str = Form(""),
    budget: str = Form(...),
    plan_type: str = Form("day"),
    report: UploadFile = File(...),
):
    """
    Accepts a blood report + user profile and returns a personalised diet plan.

    The file is read into memory and base64-encoded. It is **never** written to
    disk. The encoded bytes are sent to Claude together with the prompt so the
    model can actually read the report values rather than reason from text alone.
    """
    # ── 1. Validate the uploaded file ────────────────────────────────────────
    content_type = (report.content_type or "").lower()

    # Fallback: infer from file extension when the client sends a wrong/missing
    # MIME type (common with some Android file pickers).
    if content_type not in ALLOWED_CONTENT_TYPES:
        filename = report.filename or ""
        ext = filename.rsplit(".", 1)[-1].lower()
        content_type = {
            "pdf":  "application/pdf",
            "jpg":  "image/jpeg",
            "jpeg": "image/jpeg",
            "png":  "image/png",
        }.get(ext, content_type)

    if content_type not in ALLOWED_CONTENT_TYPES:
        raise HTTPException(
            status_code=400,
            detail=(
                f"Unsupported file type: {report.content_type}. "
                "Please upload a PDF, JPG, or PNG blood report."
            ),
        )

    raw_bytes = await report.read()

    if len(raw_bytes) == 0:
        raise HTTPException(status_code=400, detail="Uploaded report is empty.")
    if len(raw_bytes) > MAX_REPORT_BYTES:
        raise HTTPException(
            status_code=400,
            detail="Report exceeds the 10 MB size limit. Please compress or crop the file.",
        )

    log.info(
        "diet-plan request: name=%s plan_type=%s file=%s (%d bytes)",
        name, plan_type, report.filename, len(raw_bytes),
    )

    # ── 2. Build the AI request ──────────────────────────────────────────────
    block = _build_content_block(raw_bytes, content_type)

    days_count = 7 if plan_type == "week" else 1
    prompt = PROMPT.format(
        name=name,
        location=location,
        lat=lat,
        lng=lng,
        disease=disease or "none",
        allergies=allergies or "none",
        dislikes=dislikes or "none",
        budget=budget,
        days=days_count,
    )

    # ── 3. Call the model with one retry on bad/invalid JSON replies ─────────
    last_error: Exception | None = None
    for attempt in (1, 2):
        try:
            data = _call_model(prompt, block)
            log.info("diet-plan OK for '%s' on attempt %d", name, attempt)
            return data
        except json.JSONDecodeError as exc:
            last_error = exc
            log.warning("Attempt %d — model did not return valid JSON: %s", attempt, exc)
        except ValueError as exc:
            last_error = exc
            log.warning("Attempt %d — validation failure: %s", attempt, exc)
        except anthropic.APIError as exc:
            # Network / auth / rate-limit errors: no point retrying blindly.
            log.error("Anthropic API error on attempt %d: %s", attempt, exc)
            raise HTTPException(
                status_code=502,
                detail="AI service is temporarily unavailable. Please try again shortly.",
            ) from exc

    log.error("diet-plan FAILED for '%s' after 2 attempts. Last error: %s", name, last_error)
    raise HTTPException(
        status_code=500,
        detail=(
            "Could not read this report clearly. "
            "Please try a clearer scan or a well-lit photo, or upload as PDF."
        ),
    )


# ── Calorie Estimation ───────────────────────────────────────────────────────
CALORIE_PROMPT = """\
You are an expert nutritionist and food scientist. You are given a photo of a meal or food item.
Analyze the image carefully and estimate the nutritional content.

Identify every visible food item, estimate reasonable portion sizes, and calculate:
- Total estimated calories (kcal)
- Protein (grams)
- Carbohydrates (grams)
- Fat (grams)
- Fiber (grams)

Also provide a confidence level: "high" if the food is clearly visible and identifiable,
"medium" if partly obscured or mixed, "low" if very hard to identify.

If the image is NOT food, reply with {{"error": "This does not appear to be a food image."}}.

Reply with ONLY JSON, no markdown fences, in exactly this structure:
{{
  "food_items": [
    {{"name": "Food item name", "portion": "Estimated portion size", "calories": 250}}
  ],
  "total_calories": 580,
  "protein_g": 22,
  "carbs_g": 65,
  "fat_g": 18,
  "fiber_g": 6,
  "confidence": "high",
  "meal_summary": "Brief description of the overall meal and nutritional assessment",
  "health_tip": "One actionable tip to improve this meal nutritionally"
}}\
"""

CALORIE_REQUIRED_KEYS = {"food_items", "total_calories", "protein_g", "carbs_g", "fat_g"}

CALORIE_IMAGE_TYPES = {
    "image/jpeg": "image",
    "image/jpg": "image",
    "image/png": "image",
}


class CalorieEstimateResponse(BaseModel):
    food_items: list[dict]
    total_calories: int
    protein_g: float
    carbs_g: float
    fat_g: float
    fiber_g: float = 0
    confidence: str = "medium"
    meal_summary: str = ""
    health_tip: str = ""


@app.post("/estimate-calories", response_model=CalorieEstimateResponse, tags=["calories"])
async def estimate_calories(
    photo: UploadFile = File(...),
):
    """Accepts a food photo and returns an AI-powered calorie/macro estimate."""
    content_type = (photo.content_type or "").lower()

    if content_type not in CALORIE_IMAGE_TYPES:
        filename = photo.filename or ""
        ext = filename.rsplit(".", 1)[-1].lower()
        content_type = {
            "jpg":  "image/jpeg",
            "jpeg": "image/jpeg",
            "png":  "image/png",
        }.get(ext, content_type)

    if content_type not in CALORIE_IMAGE_TYPES:
        raise HTTPException(
            status_code=400,
            detail=f"Unsupported image type: {photo.content_type}. Please upload a JPG or PNG photo.",
        )

    raw_bytes = await photo.read()
    if len(raw_bytes) == 0:
        raise HTTPException(status_code=400, detail="Uploaded photo is empty.")
    if len(raw_bytes) > MAX_REPORT_BYTES:
        raise HTTPException(status_code=400, detail="Photo exceeds the 10 MB size limit.")

    encoded = base64.b64encode(raw_bytes).decode("utf-8")
    block = {
        "type": "image",
        "source": {"type": "base64", "media_type": content_type, "data": encoded},
    }

    last_error: Exception | None = None
    for attempt in (1, 2):
        try:
            msg = client.messages.create(
                model=MODEL,
                max_tokens=2000,
                messages=[
                    {
                        "role": "user",
                        "content": [block, {"type": "text", "text": CALORIE_PROMPT}],
                    }
                ],
            )
            raw = "".join(part.text for part in msg.content if part.type == "text")
            cleaned = _strip_code_fences(raw)
            data = json.loads(cleaned)

            if "error" in data:
                raise HTTPException(status_code=400, detail=data["error"])

            missing = CALORIE_REQUIRED_KEYS - data.keys()
            if missing:
                raise ValueError(f"Model response missing keys: {missing}")

            log.info("estimate-calories OK on attempt %d", attempt)
            return data

        except json.JSONDecodeError as exc:
            last_error = exc
            log.warning("Calorie attempt %d — model did not return valid JSON: %s", attempt, exc)
        except ValueError as exc:
            last_error = exc
            log.warning("Calorie attempt %d — validation failure: %s", attempt, exc)
        except anthropic.APIError as exc:
            log.error("Anthropic API error during calorie estimation: %s", exc)
            raise HTTPException(
                status_code=502,
                detail="AI service is temporarily unavailable. Please try again shortly.",
            ) from exc

    log.error("estimate-calories FAILED after 2 attempts: %s", last_error)
    raise HTTPException(
        status_code=500,
        detail="Could not analyze this food image. Please try a clearer, well-lit photo.",
    )
