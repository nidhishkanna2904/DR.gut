"""Dr. Gut backend - FastAPI application entry point.

All existing endpoints (/, /health, /diet-plan, /estimate-calories) are
preserved exactly as before.  New additions:
  - Async PostgreSQL via SQLAlchemy + asyncpg
  - Diet plan results saved to DB after every successful call
  - GET /history/{phone} - returns a user's past plans
  - GET /admin/stats    - live user and plan counts

Run:
    cd backend
    uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
"""

import base64
import json
import logging
import re
from contextlib import asynccontextmanager

import anthropic
from fastapi import Depends, FastAPI, File, Form, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from sqlalchemy import func, select, text
from sqlalchemy.ext.asyncio import AsyncSession

from app.config import settings
from app.crud.calorie_log import create_calorie_log
from app.crud.diet_request import create_diet_request
from app.crud.user import get_or_create_user
from app.database import engine
from app.deps import get_db
from app.models.diet_request import DietPlanRequest
from app.models.user import User
from app.routers import auth, history

# -- Logging -------------------------------------------------------------------
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)-8s %(name)s - %(message)s",
)
log = logging.getLogger("dr_gut")


# -- Lifespan (startup / shutdown) ---------------------------------------------
@asynccontextmanager
async def lifespan(app: FastAPI):
    # -- Startup ---------------------------------------------------------------
    log.info("Starting Dr. Gut API ...")
    try:
        async with engine.connect() as conn:
            await conn.execute(text("SELECT 1"))
        log.info("✅ Database connection OK  (%s)", settings.DATABASE_URL.split("@")[-1])
    except Exception as exc:  # noqa: BLE001
        log.error("❌ Cannot reach the database: %s", exc)
        raise RuntimeError("Database is unreachable - cannot start.") from exc

    yield  # <- server is live here

    # -- Shutdown --------------------------------------------------------------
    await engine.dispose()
    log.info("Database engine disposed. Goodbye.")


# -- App -----------------------------------------------------------------------
app = FastAPI(
    title="Dr. Gut API",
    version="2.0.0",
    description="AI-powered diet plans from blood reports + GPS location.",
    lifespan=lifespan,
)

# CORS open for development (Android emulator, real device, Flutter web)
# Restrict allow_origins before deploying publicly.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# Register sub-routers
app.include_router(auth.router)
app.include_router(history.router)

# -- Anthropic client ----------------------------------------------------------
client = anthropic.Anthropic(api_key=settings.ANTHROPIC_API_KEY)

# -- Constants -----------------------------------------------------------------
MODEL = settings.DR_GUT_MODEL
MAX_TOKENS = 6000
MAX_REPORT_BYTES = 10 * 1024 * 1024  # 10 MB

ALLOWED_CONTENT_TYPES: dict[str, str] = {
    "application/pdf": "document",
    "image/jpeg": "image",
    "image/jpg": "image",
    "image/png": "image",
}

REQUIRED_KEYS = {"summary", "deficiencies", "body_analysis", "days", "local_notes"}

# -- Prompt template -----------------------------------------------------------
PROMPT = """\
You are a clinical nutrition assistant. Read the attached blood report and
identify EVERY marker present in the report - both those outside AND within
normal laboratory ranges (e.g. haemoglobin, ferritin, vitamin B12, vitamin D,
calcium, lipid profile, fasting/postprandial glucose, HbA1c, thyroid panel,
cholesterol, triglycerides, creatinine, uric acid, etc.).

User: {name}. Location: {location} (lat {lat}, lng {lng}).
Conditions: {disease}. Allergies: {allergies}. Dislikes: {dislikes}.
Budget: Rs {budget} per day. Plan length: {days} day(s).

Create a realistic diet plan that targets and helps correct the identified
deficiencies using foods commonly and cheaply available in that local
geographical area/region and season.
Strict rule: NEVER include any allergens or disliked foods under any circumstance.
Strict rule: Stay strictly within the user's daily budget.
Strict rule: Use the location "{location}" to recommend locally available and
  seasonal ingredients specific to that geographical region.
Strict rule for multi-day plans: Every day MUST have a DIFFERENT set of meals.
  - For a 7-day plan, at least 4 days must have COMPLETELY different breakfast, lunch, and dinner items.
  - Do NOT repeat the same breakfast item on consecutive days.
  - Rotate protein sources (legumes, eggs, paneer, fish, chicken) across different days.
  - Rotate grain bases (rice, roti/wheat, millets like ragi/jowar/bajra, oats, poha/upma) across days.
  - Variety keeps patients compliant with the plan; monotony causes diet failure.
If the report is unreadable or not a blood report, reply with {{"error": "reason"}}.

IMPORTANT: Before the meal plan, produce a "body_analysis" table listing EVERY
marker found in the report with its actual value and status:
  - status must be one of: "deficient", "low", "normal", "optimal", "elevated", "high"
  - Include recommended daily intake and dietary tips for that marker.

Reply with ONLY JSON, no markdown fences, no conversational prose, in exactly
this JSON structure:
{{
  "summary": "Clinical and nutritional overview of the findings and strategy",
  "body_analysis": [
    {{
      "marker": "Marker name (e.g. Haemoglobin)",
      "value": "Actual value from report (e.g. 10.2 g/dL)",
      "normal_range": "Normal laboratory range (e.g. 12-16 g/dL)",
      "status": "deficient",
      "emoji": "Appropriate emoji (e.g. \u2b07\ufe0f for low, \u2705 for normal, \u26a0\ufe0f for high)",
      "dietary_tip": "One-line food-based recommendation"
    }}
  ],
  "deficiencies": [
    {{"name": "Marker Name (e.g. Iron)", "finding": "Result value and brief clinical note"}}
  ],
  "days": [
    {{
      "day": "Day 1",
      "meals": [
        {{
          "time": "Breakfast (8:30 AM)",
          "items": "Description of food items",
          "why": "Clinical/nutritional rationale",
          "nutrients": {{
            "calories": 350,
            "protein_g": 12,
            "carbs_g": 55,
            "fat_g": 8,
            "fiber_g": 5,
            "key_vitamins": "Iron, Vitamin C, Folate"
          }}
        }}
      ]
    }}
  ],
  "local_notes": "Regional purchasing tips and seasonal food availability near the location"
}}\
"""

# -- Diet Chat prompt ----------------------------------------------------------
DIET_CHAT_PROMPT = """\
You are Dr. Gut, a friendly and knowledgeable clinical nutrition AI assistant.
You are helping a patient understand and improve their personalised diet plan.

Patient's current diet plan context:
{plan_context}

Patient's question or request:
{user_message}

Instructions:
- Answer in a warm, clear, non-technical way (use simple English).
- If the user asks to modify or improve the plan (e.g., swap a food, reduce carbs, add variety),
  provide specific actionable suggestions that stay consistent with their deficiencies,
  allergies, dislikes, and budget shown in the plan context.
- If the user asks a general nutrition or health question, answer helpfully.
- Keep responses concise (under 200 words) unless a detailed explanation is needed.
- Do NOT output JSON; respond in friendly plain text or use brief bullet points.
- If you suggest a food swap, explain the nutritional reason in one sentence.
- Always end with an encouraging note if the user seems concerned.
"""

# -- Calorie estimation prompt --------------------------------------------------
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


# -- Pydantic response models ---------------------------------------------------
class DietPlanResponse(BaseModel):
    summary: str
    body_analysis: list[dict] = []
    deficiencies: list[dict]
    days: list[dict]
    local_notes: str


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


# -- Helper functions -----------------------------------------------------------
def _strip_code_fences(text: str) -> str:
    """Claude sometimes wraps JSON in ```json ... ``` - strip safely."""
    text = text.strip()
    text = re.sub(r"^```(?:json)?\s*", "", text)
    text = re.sub(r"\s*```$", "", text)
    return text.strip()


def _build_content_block(raw_bytes: bytes, content_type: str) -> dict:
    """Build the Anthropic content block for an image or a PDF document."""
    encoded = base64.b64encode(raw_bytes).decode("utf-8")
    block_type = ALLOWED_CONTENT_TYPES[content_type]
    return {
        "type": block_type,
        "source": {"type": "base64", "media_type": content_type, "data": encoded},
    }


def _call_model(prompt: str, block: dict) -> dict:
    """Send one request to Claude and parse its JSON reply.

    Raises:
        json.JSONDecodeError  - model did not return valid JSON.
        ValueError            - JSON valid but missing required keys or has error key.
        anthropic.APIError    - network / auth / rate-limit from Anthropic.
    """
    msg = client.messages.create(
        model=MODEL,
        max_tokens=MAX_TOKENS,
        messages=[{"role": "user", "content": [block, {"type": "text", "text": prompt}]}],
    )
    raw = "".join(part.text for part in msg.content if part.type == "text")
    log.debug("Raw model output (first 300 chars): %s", raw[:300])

    cleaned = _strip_code_fences(raw)
    data = json.loads(cleaned)

    if "error" in data:
        raise ValueError(data["error"])
    # body_analysis is optional for backwards compat; only require core keys
    core_required = {"summary", "deficiencies", "days", "local_notes"}
    missing = core_required - data.keys()
    if missing:
        raise ValueError(f"Model response missing required keys: {missing}")
    return data


def _generate_fallback_diet_plan(
    name: str,
    location: str,
    disease: str,
    allergies: str,
    dislikes: str,
    budget: str,
    plan_type: str,
) -> dict:
    """Generate a sensible offline diet plan when the AI service is unavailable.

    This uses rule-based clinical nutrition logic so the user still gets
    actionable guidance rather than a blank error screen.
    Each of the 7 days gets a DISTINCT set of meals to avoid monotony.
    """
    allergy_set = {a.strip().lower() for a in allergies.split(",") if a.strip()} if allergies else set()
    dislike_set = {d.strip().lower() for d in dislikes.split(",") if d.strip()} if dislikes else set()
    excluded = allergy_set | dislike_set

    condition = (disease or "").lower()

    # -- 7 distinct daily meal templates --------------------------------------
    # Each tuple is (breakfast, mid-morning, lunch, evening-snack, dinner)
    daily_templates = [
        # Day 1 - Ragi / Rice base
        [
            {"time": "Breakfast (8:00 AM)", "items": "Ragi porridge with jaggery, boiled egg, seasonal fruit",
             "why": "Ragi is rich in calcium and iron; jaggery adds iron; eggs provide B12 and protein."},
            {"time": "Mid-Morning (10:30 AM)", "items": "Handful of roasted chana and a small banana",
             "why": "Chana provides plant protein and fiber; banana adds potassium."},
            {"time": "Lunch (1:00 PM)", "items": "Brown rice, masoor dal, palak sabzi, curd, lemon wedge",
             "why": "Lentils supply iron and folate; spinach is iron-rich; vitamin C from lemon boosts absorption."},
            {"time": "Evening Snack (4:30 PM)", "items": "Sprouts chaat with tomato, onion, and lemon juice",
             "why": "Sprouts are rich in folate, iron, and vitamin C for enhanced nutrient absorption."},
            {"time": "Dinner (7:30 PM)", "items": "Jowar roti, mixed vegetable curry, small bowl of moong dal",
             "why": "Jowar is gluten-free and iron-rich; mixed vegetables supply micronutrients and fiber."},
        ],
        # Day 2 - Idli / Poha base
        [
            {"time": "Breakfast (8:00 AM)", "items": "Vegetable poha with peanuts, curry leaves, and lemon juice",
             "why": "Poha is iron-fortified; peanuts add healthy fat and protein; lemon enhances iron absorption."},
            {"time": "Mid-Morning (10:30 AM)", "items": "A glass of buttermilk with a pinch of cumin and salt",
             "why": "Buttermilk aids digestion and provides probiotics and calcium."},
            {"time": "Lunch (1:00 PM)", "items": "Steamed rice, sambar with drumstick, beans poriyal, small piece of fish (if non-veg)",
             "why": "Drumstick (moringa) is exceptionally high in iron and vitamin C; fish provides omega-3 and B12."},
            {"time": "Evening Snack (4:30 PM)", "items": "Boiled sweet potato with a pinch of chilli and salt",
             "why": "Sweet potato is rich in beta-carotene, potassium, and dietary fiber."},
            {"time": "Dinner (7:30 PM)", "items": "Chapati (2), rajma curry, cucumber-tomato salad",
             "why": "Rajma is an excellent plant-based iron and protein source; salad adds micronutrients."},
        ],
        # Day 3 - Oats / Millet base
        [
            {"time": "Breakfast (8:00 AM)", "items": "Oats upma with vegetables (carrot, peas, onion) and a boiled egg",
             "why": "Oats reduce cholesterol and provide soluble fiber; vegetables add vitamins."},
            {"time": "Mid-Morning (10:30 AM)", "items": "Seasonal fruit (guava or papaya) - one medium piece",
             "why": "Guava and papaya are high in vitamin C which significantly boosts non-heme iron absorption."},
            {"time": "Lunch (1:00 PM)", "items": "Bajra roti, chana dal, methi sabzi, curd",
             "why": "Bajra is rich in iron and magnesium; methi (fenugreek) improves blood glucose and iron levels."},
            {"time": "Evening Snack (4:30 PM)", "items": "Roasted makhana (fox nuts) with a pinch of turmeric and pepper",
             "why": "Makhana is low-calorie, rich in calcium and antioxidants."},
            {"time": "Dinner (7:30 PM)", "items": "Vegetable khichdi (rice + moong dal + veggies), papad, lemon pickle",
             "why": "Khichdi is a complete protein and easy-to-digest comfort meal ideal for gut health."},
        ],
        # Day 4 - South Indian fermented base
        [
            {"time": "Breakfast (8:00 AM)", "items": "2 idli with sambar and tomato chutney",
             "why": "Fermented batter improves bioavailability of minerals; sambar adds iron-rich lentils."},
            {"time": "Mid-Morning (10:30 AM)", "items": "Tender coconut water",
             "why": "Natural electrolytes including potassium and magnesium support hydration."},
            {"time": "Lunch (1:00 PM)", "items": "Curd rice with grated carrot, pomegranate seeds, and curry leaves",
             "why": "Probiotics from curd boost gut microbiome; pomegranate seeds are rich in iron and antioxidants."},
            {"time": "Evening Snack (4:30 PM)", "items": "Peanut chikki (1 piece) or a handful of mixed nuts",
             "why": "Nuts provide healthy fats, magnesium, and plant-based protein."},
            {"time": "Dinner (7:30 PM)", "items": "Pesarattu (green moong crepe) with ginger chutney",
             "why": "Green moong is rich in plant protein, iron, folate, and is low in calories."},
        ],
        # Day 5 - Egg / Paneer protein focus
        [
            {"time": "Breakfast (8:00 AM)", "items": "Besan chilla (2) with mint chutney and a glass of low-fat milk",
             "why": "Chickpea flour is high in protein and iron; milk provides calcium and B12."},
            {"time": "Mid-Morning (10:30 AM)", "items": "A small bowl of mixed fruit salad with lemon juice",
             "why": "Vitamin C from citrus enhances non-heme iron absorption from plant foods."},
            {"time": "Lunch (1:00 PM)", "items": "Roti (2), palak paneer, carrot-cucumber salad",
             "why": "Paneer provides calcium and protein; spinach is an excellent source of iron and folate."},
            {"time": "Evening Snack (4:30 PM)", "items": "Boiled chana chaat with onion, tomato, coriander, and chaat masala",
             "why": "Chickpeas are rich in iron, fiber, and protein - ideal afternoon energy booster."},
            {"time": "Dinner (7:30 PM)", "items": "Egg curry (2 eggs) or tofu masala with 2 rotis",
             "why": "Eggs provide B12, iron, and complete protein; tofu is an excellent vegan alternative."},
        ],
        # Day 6 - Fibre and gut-health focus
        [
            {"time": "Breakfast (8:00 AM)", "items": "Dalia (broken wheat) porridge with jaggery and ghee, seasonal fruit",
             "why": "Dalia is high in fiber and iron; jaggery adds iron; ghee aids fat-soluble vitamin absorption."},
            {"time": "Mid-Morning (10:30 AM)", "items": "Lassi (unsweetened, with a pinch of cumin)",
             "why": "Probiotic-rich; supports gut lining health and calcium absorption."},
            {"time": "Lunch (1:00 PM)", "items": "Red rice / hand-pounded rice, fish curry, beans stir-fry, papad",
             "why": "Red rice retains bran layer with B vitamins and iron; fish adds omega-3 and B12."},
            {"time": "Evening Snack (4:30 PM)", "items": "Steamed corn on the cob with lemon and chilli, or roasted groundnuts",
             "why": "Corn provides lutein and fiber; groundnuts supply niacin and plant protein."},
            {"time": "Dinner (7:30 PM)", "items": "Moong dal soup, ragi roti, beetroot stir-fry",
             "why": "Beetroot is rich in folate and iron; moong dal provides easily digestible protein."},
        ],
        # Day 7 - Light and restorative
        [
            {"time": "Breakfast (8:00 AM)", "items": "Upma (semolina / rava) with mixed vegetables and a boiled egg",
             "why": "Semolina provides B vitamins; egg boosts complete protein and B12 for the week's end."},
            {"time": "Mid-Morning (10:30 AM)", "items": "A glass of fresh orange juice or amla juice",
             "why": "Extremely high vitamin C content - enhances iron absorption for the entire day's meals."},
            {"time": "Lunch (1:00 PM)", "items": "Mixed millet khichdi (ragi + jowar + rice), mixed vegetable raita",
             "why": "Multi-millet khichdi provides diverse micronutrients, fiber, and a complete amino acid profile."},
            {"time": "Evening Snack (4:30 PM)", "items": "A small bowl of homemade trail mix (dates, almonds, walnuts, raisins)",
             "why": "Dates and raisins are dense in iron; nuts provide magnesium and healthy fats."},
            {"time": "Dinner (7:30 PM)", "items": "Light dal soup (arhar/toor), 2 plain rotis, sauteed greens (amaranth/bathua)",
             "why": "Toor dal is easily digestible; leafy greens like amaranth are among the highest plant-iron sources."},
        ],
    ]

    def _filter_meals(meals: list) -> list:
        """Remove individual meals that contain excluded ingredients."""
        safe = []
        for meal in meals:
            if not any(exc in meal["items"].lower() for exc in excluded):
                safe.append(meal)
        return safe if safe else [
            {"time": "Breakfast (8:00 AM)", "items": "Idli with sambar and coconut chutney",
             "why": "Fermented rice batter aids digestion; sambar provides lentil protein."},
            {"time": "Lunch (1:00 PM)", "items": "Rice, rasam, seasonal vegetable poriyal, curd",
             "why": "Balanced meal with carbs, protein, and probiotics from curd."},
            {"time": "Dinner (7:30 PM)", "items": "Chapati, moong dal, cucumber raita",
             "why": "Light, easily digestible dinner with adequate protein."},
        ]

    # -- Build deficiencies based on the stated condition ---------------------
    deficiencies = []
    if "iron" in condition or "anemia" in condition or "anaemia" in condition:
        deficiencies.append({"name": "Iron / Ferritin", "finding": "Likely low based on stated condition - increase iron-rich foods."})
    if "b12" in condition or "vitamin b" in condition:
        deficiencies.append({"name": "Vitamin B12", "finding": "May be deficient - include eggs, dairy, or fortified foods."})
    if "vitamin d" in condition or "bone" in condition:
        deficiencies.append({"name": "Vitamin D", "finding": "Possibly low - recommend morning sun exposure and fortified milk."})
    if "diabetes" in condition or "sugar" in condition or "glucose" in condition:
        deficiencies.append({"name": "Blood Glucose / HbA1c", "finding": "Elevated - low-GI foods and portion control recommended."})
    if "thyroid" in condition:
        deficiencies.append({"name": "Thyroid Panel", "finding": "Abnormal - avoid raw cruciferous vegetables; ensure adequate iodine and selenium."})
    if not deficiencies:
        deficiencies.append({"name": "General Nutrition", "finding": "No specific condition stated - balanced diet plan recommended."})

    # -- Build days with distinct meal templates -------------------------------
    days_count = 7 if plan_type == "week" else 1
    days = []
    for i in range(days_count):
        template = daily_templates[i % len(daily_templates)]
        days.append({"day": f"Day {i + 1}", "meals": _filter_meals(template)})

    return {
        "summary": (
            f"Offline nutrition plan for {name} near {location}. "
            f"This plan was generated using clinical nutrition guidelines because the AI service "
            f"was temporarily unavailable. It targets {disease or 'general wellness'} within a "
            f"budget of Rs.{budget}/day while avoiding {allergies or 'no'} allergens. "
            f"Each of the 7 days features a distinct set of meals to keep the plan interesting and nutritionally varied. "
            f"Please consult your doctor for personalised medical advice."
        ),
        "body_analysis": [],   # No blood report data available in offline mode
        "deficiencies": deficiencies,
        "days": days,
        "local_notes": (
            f"Shop at your nearest local market in {location} for seasonal vegetables and grains. "
            f"Prefer locally milled flours (ragi, jowar) and fresh greens. Buy curd and buttermilk "
            f"daily for freshness. This plan stays within Rs.{budget}/day using commonly available ingredients."
        ),
    }


async def _geocode_location_name(location_name: str) -> tuple[float, float]:
    """Geocode a text location name to (lat, lng) using Nominatim.

    Returns (0.0, 0.0) if geocoding fails so the caller can fall back gracefully.
    """
    import urllib.parse
    import urllib.request as urllib_req

    if not location_name or not location_name.strip():
        return 0.0, 0.0

    try:
        query = urllib.parse.quote(location_name.strip())
        url = (
            f"https://nominatim.openstreetmap.org/search"
            f"?q={query}&format=json&limit=1&addressdetails=0"
        )
        req = urllib_req.Request(url, headers={"User-Agent": "DrGutAPI/2.0"})
        with urllib_req.urlopen(req, timeout=5) as response:
            results = json.loads(response.read().decode())
            if results:
                return float(results[0]["lat"]), float(results[0]["lon"])
    except Exception as exc:  # noqa: BLE001
        log.warning("Nominatim geocoding for '%s' failed: %s", location_name, exc)

    return 0.0, 0.0


# -- Routes ---------------------------------------------------------------------
@app.get("/health", tags=["meta"])
def health():
    """Liveness check - confirms the server is reachable."""
    return {"status": "ok", "app": "Dr. Gut API", "version": "2.0.0", "model": MODEL}


@app.get("/admin/stats", tags=["meta"])
async def admin_stats(db: AsyncSession = Depends(get_db)):
    """Live counts of users and diet plans stored in the database."""
    user_count = (await db.execute(select(func.count(User.id)))).scalar_one()
    plan_count = (await db.execute(select(func.count(DietPlanRequest.id)))).scalar_one()
    return {"total_users": user_count, "total_diet_plans": plan_count}


@app.get("/location", tags=["location"])
async def detect_location():
    """Detect location from public IP as an automatic fallback when device GPS is unavailable."""
    import urllib.request
    try:
        req = urllib.request.Request(
            "http://ip-api.com/json/?fields=status,message,country,regionName,city,lat,lon",
            headers={"User-Agent": "DrGutAPI/2.0"},
        )
        with urllib.request.urlopen(req, timeout=4) as response:
            data = json.loads(response.read().decode())
            if data.get("status") == "success":
                city = data.get("city", "")
                region = data.get("regionName", "")
                country = data.get("country", "India")
                place_name = f"{city}, {region}, {country}" if city and region else (city or region or country)
                return {
                    "status": "success",
                    "lat": float(data.get("lat", 0.0)),
                    "lng": float(data.get("lon", 0.0)),
                    "city": city,
                    "state": region,
                    "country": country,
                    "place_name": place_name,
                }
    except Exception as exc:
        log.warning("IP location lookup failed: %s", exc)

    return {
        "status": "fallback",
        "lat": 9.919,
        "lng": 78.1195,
        "city": "Madurai",
        "state": "Tamil Nadu",
        "country": "India",
        "place_name": "Madurai, Tamil Nadu, India",
    }


@app.get("/reverse-geocode", tags=["location"])
async def reverse_geocode_endpoint(lat: float, lng: float):
    """Reverse geocode coordinates into a clean place name without browser CORS limitations."""
    import urllib.request
    try:
        url = f"https://api.bigdatacloud.net/data/reverse-geocode-client?latitude={lat}&longitude={lng}&localityLanguage=en"
        req = urllib.request.Request(url, headers={"User-Agent": "DrGutAPI/2.0"})
        with urllib.request.urlopen(req, timeout=4) as response:
            data = json.loads(response.read().decode())
            loc = (data.get("locality") or data.get("subLocality") or "").strip()
            city = (data.get("city") or "").strip()
            state = (data.get("principalSubdivision") or "").strip()
            country = (data.get("countryName") or "").strip()

            parts = [p for p in [loc, city, state, country] if p]
            seen = set()
            clean_parts = []
            for p in parts:
                if p.lower() not in seen:
                    seen.add(p.lower())
                    clean_parts.append(p)
            place_name = ", ".join(clean_parts) if clean_parts else f"{lat:.3f}, {lng:.3f}"
            return {
                "status": "success",
                "lat": lat,
                "lng": lng,
                "sub_locality": loc,
                "city": city,
                "state": state,
                "country": country,
                "place_name": place_name,
            }
    except Exception as exc:
        log.warning("Reverse geocode failed: %s", exc)
        return {
            "status": "fallback",
            "lat": lat,
            "lng": lng,
            "place_name": f"{lat:.3f}°N, {lng:.3f}°E",
        }


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
    db: AsyncSession = Depends(get_db),
):
    """
    Accept a blood report + user profile -> return a personalised AI diet plan.

    The file is read into memory, base64-encoded, and sent to Claude together
    with a prompt that includes the user's location, conditions, allergies,
    dislikes, and budget. It is **never** written to disk.

    The result is saved to the database before returning to the client.
    """
    # -- 1. Validate the uploaded file -----------------------------------------
    content_type = (report.content_type or "").lower()

    # Fallback: infer from extension when Android sends a wrong/missing MIME type.
    if content_type not in ALLOWED_CONTENT_TYPES:
        ext = (report.filename or "").rsplit(".", 1)[-1].lower()
        content_type = {
            "pdf": "application/pdf",
            "jpg": "image/jpeg",
            "jpeg": "image/jpeg",
            "png": "image/png",
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

    # -- 1b. Geocode text location when coordinates are missing (lat=0, lng=0) --
    # This happens when the user manually types a location name instead of using GPS.
    if lat == 0.0 and lng == 0.0 and location.strip():
        resolved_lat, resolved_lng = await _geocode_location_name(location)
        if resolved_lat != 0.0 or resolved_lng != 0.0:
            lat, lng = resolved_lat, resolved_lng
            log.info(
                "Geocoded '%s' -> lat=%.4f lng=%.4f",
                location, lat, lng,
            )
        else:
            log.warning("Could not geocode '%s' - proceeding with text name only", location)

    # -- 2. Build the AI request ------------------------------------------------
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

    # -- 3. Call Claude with fallback for missing/invalid API key -------------
    last_error: Exception | None = None
    data: dict | None = None

    is_placeholder_key = (
        not settings.ANTHROPIC_API_KEY
        or settings.ANTHROPIC_API_KEY.startswith("sk-ant-YOUR_KEY")
        or len(settings.ANTHROPIC_API_KEY.strip()) < 20
    )

    if is_placeholder_key:
        log.warning("Anthropic API key is placeholder or empty. Generating tailored clinical nutrition plan.")
        data = _generate_fallback_diet_plan(name, location, disease, allergies, dislikes, budget, plan_type)
    else:
        for attempt in (1, 2):
            try:
                data = _call_model(prompt, block)
                log.info("diet-plan OK for '%s' on attempt %d", name, attempt)
                break  # success
            except json.JSONDecodeError as exc:
                last_error = exc
                log.warning("Attempt %d - model did not return valid JSON: %s", attempt, exc)
            except ValueError as exc:
                last_error = exc
                log.warning("Attempt %d - validation failure: %s", attempt, exc)
            except anthropic.BadRequestError as exc:
                last_error = exc
                log.warning(
                    "Anthropic BadRequestError (likely credit/billing) on attempt %d: %s. Using offline plan.",
                    attempt,
                    exc,
                )
                data = _generate_fallback_diet_plan(name, location, disease, allergies, dislikes, budget, plan_type)
                break
            except anthropic.APIError as exc:
                last_error = exc
                log.warning(
                    "Anthropic API error on attempt %d: %s. Falling back to clinical nutrition protocol engine.",
                    attempt,
                    exc,
                )
                data = _generate_fallback_diet_plan(name, location, disease, allergies, dislikes, budget, plan_type)
                break

    # -- 4. Persist to DB regardless of outcome --------------------------------
    try:
        user = await get_or_create_user(db, name=name, phone=phone)
        await create_diet_request(
            db,
            user_id=user.id,
            location=location,
            lat=lat,
            lng=lng,
            disease=disease,
            allergies=allergies,
            dislikes=dislikes,
            budget=budget,
            plan_type=plan_type,
            result_json=data,
            status="success" if data else "error",
            error_msg=str(last_error) if last_error else None,
        )
    except Exception as db_exc:  # noqa: BLE001
        # DB write failure must NOT block the AI response from reaching the client.
        log.error("DB write failed (non-fatal): %s", db_exc)

    # -- 5. Return or raise ----------------------------------------------------
    if data:
        return data

    log.error("diet-plan FAILED for '%s' after 2 attempts. Last error: %s", name, last_error)
    raise HTTPException(
        status_code=500,
        detail=(
            "Could not read this report clearly. "
            "Please try a clearer scan or a well-lit photo, or upload as PDF."
        ),
    )


@app.post("/estimate-calories", response_model=CalorieEstimateResponse, tags=["calories"])
async def estimate_calories(
    photo: UploadFile = File(...),
    db: AsyncSession = Depends(get_db),
):
    """Accept a food photo -> return an AI-powered calorie/macro estimate.

    The result is saved to calorie_logs.
    """
    content_type = (photo.content_type or "").lower()

    if content_type not in CALORIE_IMAGE_TYPES:
        ext = (photo.filename or "").rsplit(".", 1)[-1].lower()
        content_type = {
            "jpg": "image/jpeg",
            "jpeg": "image/jpeg",
            "png": "image/png",
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
    block = {"type": "image", "source": {"type": "base64", "media_type": content_type, "data": encoded}}

    last_error: Exception | None = None
    data: dict | None = None

    for attempt in (1, 2):
        try:
            msg = client.messages.create(
                model=MODEL,
                max_tokens=2000,
                messages=[{"role": "user", "content": [block, {"type": "text", "text": CALORIE_PROMPT}]}],
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
            break

        except json.JSONDecodeError as exc:
            last_error = exc
            log.warning("Calorie attempt %d - model did not return valid JSON: %s", attempt, exc)
        except ValueError as exc:
            last_error = exc
            log.warning("Calorie attempt %d - validation failure: %s", attempt, exc)
        except anthropic.BadRequestError as exc:
            log.warning("Calorie snap credit/billing error: %s", exc)
            raise HTTPException(
                status_code=503,
                detail="AI credits exhausted. Please top up your Anthropic API credits at console.anthropic.com to use Calorie Snap.",
            ) from exc
        except anthropic.APIError as exc:
            log.error("Anthropic API error during calorie estimation: %s", exc)
            raise HTTPException(
                status_code=502,
                detail="AI service is temporarily unavailable. Please try again shortly.",
            ) from exc

    # Persist result (non-fatal if DB write fails)
    if data:
        try:
            await create_calorie_log(
                db,
                total_calories=int(data.get("total_calories", 0)),
                protein_g=float(data.get("protein_g", 0)),
                carbs_g=float(data.get("carbs_g", 0)),
                fat_g=float(data.get("fat_g", 0)),
                fiber_g=float(data.get("fiber_g", 0)),
                confidence=str(data.get("confidence", "medium")),
                result_json=data,
            )
        except Exception as db_exc:  # noqa: BLE001
            log.error("Calorie DB write failed (non-fatal): %s", db_exc)
        return data

    log.error("estimate-calories FAILED after 2 attempts: %s", last_error)
    raise HTTPException(
        status_code=500,
        detail="Could not analyze this food image. Please try a clearer, well-lit photo.",
    )


# -- Chat models ---------------------------------------------------------------
class DietChatRequest(BaseModel):
    message: str
    plan_summary: str = ""
    plan_deficiencies: list[dict] = []
    plan_days_preview: list[dict] = []
    local_notes: str = ""


class DietChatResponse(BaseModel):
    reply: str


@app.post("/diet-chat", response_model=DietChatResponse, tags=["diet"])
async def diet_chat(request: DietChatRequest):
    """
    AI-powered diet assistant chat endpoint.

    Accepts the user's current diet plan context (summary, deficiencies, meal preview)
    and a free-text message/question. Returns a personalised, conversational reply
    that can suggest plan improvements, answer nutrition questions, or swap foods.
    """
    # Build a human-readable plan context string
    plan_context_parts = []
    if request.plan_summary:
        plan_context_parts.append(f"Plan Summary: {request.plan_summary}")
    if request.plan_deficiencies:
        defs = "; ".join(f"{d.get('name', '')}: {d.get('finding', '')}" for d in request.plan_deficiencies)
        plan_context_parts.append(f"Identified Deficiencies: {defs}")
    if request.plan_days_preview:
        meals_text = []
        for day in request.plan_days_preview[:3]:  # include first 3 days as context
            day_label = day.get("day", "")
            meals = day.get("meals", [])
            meal_descriptions = " | ".join(f"{m.get('time', '')}: {m.get('items', '')}" for m in meals)
            meals_text.append(f"{day_label}: {meal_descriptions}")
        plan_context_parts.append("Sample Meals:\n" + "\n".join(meals_text))
    if request.local_notes:
        plan_context_parts.append(f"Local Tips: {request.local_notes}")

    plan_context = "\n\n".join(plan_context_parts) if plan_context_parts else "No plan context available yet."

    prompt = DIET_CHAT_PROMPT.format(
        plan_context=plan_context,
        user_message=request.message,
    )

    is_placeholder_key = (
        not settings.ANTHROPIC_API_KEY
        or settings.ANTHROPIC_API_KEY.startswith("sk-ant-YOUR_KEY")
        or len(settings.ANTHROPIC_API_KEY.strip()) < 20
    )

    if is_placeholder_key:
        return DietChatResponse(
            reply=(
                "I'm Dr. Gut, your nutrition assistant! 🌱 It looks like the AI service isn't configured yet. "
                "Once your Anthropic API key is set up, I'll be able to answer all your diet questions, "
                "suggest meal swaps, and help you improve your plan. In the meantime, feel free to share "
                "your questions and I'll do my best to help!"
            )
        )

    try:
        msg = client.messages.create(
            model=MODEL,
            max_tokens=600,
            messages=[{"role": "user", "content": prompt}],
        )
        reply_text = "".join(part.text for part in msg.content if part.type == "text").strip()
        log.info("diet-chat reply generated (%d chars)", len(reply_text))
        return DietChatResponse(reply=reply_text)

    except anthropic.BadRequestError as exc:
        log.warning("diet-chat credit/billing error: %s", exc)
        # Provide a helpful offline response instead of an error
        offline_reply = (
            "I'm currently running in offline mode due to an API credit limitation. "
            "However, based on your plan context, here are some general tips:\n\n"
            "\u2022 Ensure you're getting enough protein (legumes, eggs, dairy) at every meal.\n"
            "\u2022 Pair iron-rich foods with vitamin C sources (lemon, tomato, amla) to boost absorption.\n"
            "\u2022 Stay hydrated - aim for 8-10 glasses of water daily.\n"
            "\u2022 Avoid tea/coffee within 1 hour of meals as they inhibit iron absorption.\n"
            "\u2022 Eat seasonal and locally available vegetables for maximum freshness and nutrition.\n\n"
            "To get personalised AI answers, please top up your Anthropic API credits at console.anthropic.com "
            "or contact your developer. \U0001f331"
        )
        return DietChatResponse(reply=offline_reply)
    except anthropic.APIError as exc:
        log.error("diet-chat API error: %s", exc)
        raise HTTPException(
            status_code=502,
            detail="AI assistant is temporarily unavailable. Please try again shortly.",
        ) from exc
    except Exception as exc:  # noqa: BLE001
        log.error("diet-chat unexpected error: %s", exc)
        raise HTTPException(status_code=500, detail="Could not process your message.") from exc
