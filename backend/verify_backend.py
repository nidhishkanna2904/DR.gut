import asyncio
import httpx
from app.main import app
from app.database import SessionLocal, engine
from app.crud.user import get_or_create_user, get_user_by_phone
from app.crud.diet_request import create_diet_request, get_user_diet_history
from app.crud.calorie_log import create_calorie_log

async def run_tests():
    print("=== Testing Database & CRUD ===")
    async with SessionLocal() as db:
        # 1. User CRUD
        test_phone = "+919876543210"
        user = await get_or_create_user(db, name="Test Patient", phone=test_phone)
        print(f"Created/retrieved user: ID={user.id}, Name={user.name}, Phone={user.phone}")
        assert user.id is not None
        assert user.name == "Test Patient"

        # 2. Diet Request CRUD
        diet_req = await create_diet_request(
            db,
            user_id=user.id,
            location="Bengaluru, Karnataka",
            lat=12.9716,
            lng=77.5946,
            disease="Iron deficiency",
            allergies="Peanuts",
            dislikes="Bitter gourd",
            budget="250",
            plan_type="day",
            result_json={
                "summary": "High iron diet plan for testing",
                "deficiencies": [{"name": "Ferritin", "finding": "Low 12 ng/mL"}],
                "days": [{"day": "Day 1", "meals": [{"time": "Breakfast", "items": "Spinach oats", "why": "Iron rich"}]}],
                "local_notes": "Buy seasonal palak and jaggery from local market."
            },
            status="success"
        )
        print(f"Created diet request: ID={diet_req.id}, Status={diet_req.status}")
        assert diet_req.id is not None

        # 3. History retrieval
        history = await get_user_diet_history(db, user.id)
        print(f"Retrieved user history: {len(history)} records")
        assert len(history) >= 1

        # 4. Calorie Log CRUD
        cal_log = await create_calorie_log(
            db,
            user_id=user.id,
            total_calories=450,
            protein_g=20.5,
            carbs_g=55.0,
            fat_g=12.0,
            fiber_g=8.0,
            confidence="high",
            result_json={"meal_summary": "Idli and sambar"}
        )
        print(f"Created calorie log: ID={cal_log.id}, Calories={cal_log.total_calories}")
        assert cal_log.id is not None

    print("\n=== Testing FastAPI Endpoints ===")
    async with httpx.AsyncClient(transport=httpx.ASGITransport(app=app), base_url="http://test") as ac:
        # Health check
        res_health = await ac.get("/health")
        print(f"GET /health: {res_health.status_code} -> {res_health.json()}")
        assert res_health.status_code == 200
        assert res_health.json()["status"] == "ok"

        # Admin stats
        res_stats = await ac.get("/admin/stats")
        print(f"GET /admin/stats: {res_stats.status_code} -> {res_stats.json()}")
        assert res_stats.status_code == 200
        assert res_stats.json()["total_users"] >= 1
        assert res_stats.json()["total_diet_plans"] >= 1

        # History endpoint for existing phone
        res_hist = await ac.get(f"/history/{test_phone}")
        print(f"GET /history/{test_phone}: {res_hist.status_code} -> plans={res_hist.json()['total_plans']}")
        assert res_hist.status_code == 200
        assert res_hist.json()["user"]["phone"] == test_phone
        assert len(res_hist.json()["plans"]) >= 1

        # History endpoint for 404 phone
        res_404 = await ac.get("/history/0000000000")
        print(f"GET /history/0000000000: {res_404.status_code} -> {res_404.json()}")
        assert res_404.status_code == 404

        # Auth Login (Existing User)
        res_login_ok = await ac.post("/auth/login", json={"identifier": test_phone})
        print(f"POST /auth/login (existing): {res_login_ok.status_code} -> user={res_login_ok.json()['user']['name']}")
        assert res_login_ok.status_code == 200
        assert res_login_ok.json()["user"]["phone"] == test_phone

        # Auth Login (Non-existent User -> 404)
        non_existent_phone = "+910000099999"
        res_login_404 = await ac.post("/auth/login", json={"identifier": non_existent_phone})
        print(f"POST /auth/login (non-existent): {res_login_404.status_code} -> {res_login_404.json()}")
        assert res_login_404.status_code == 404
        assert "No account found in database" in res_login_404.json()["detail"]

        # Auth Register (New User)
        import time
        new_phone = f"+919{int(time.time()) % 1000000000:09d}"
        res_reg = await ac.post(
            "/auth/register",
            json={"name": "New Registered Patient", "phone": new_phone, "email": f"patient_{int(time.time())}@test.com"},
        )
        print(f"POST /auth/register: {res_reg.status_code} -> {res_reg.json()['message']}")
        assert res_reg.status_code == 201
        assert res_reg.json()["user"]["name"] == "New Registered Patient"

        # Auth Register (Duplicate Phone -> 400)
        res_reg_dup = await ac.post(
            "/auth/register",
            json={"name": "Duplicate Patient", "phone": new_phone},
        )
        print(f"POST /auth/register (duplicate): {res_reg_dup.status_code} -> {res_reg_dup.json()['detail']}")
        assert res_reg_dup.status_code == 400

    print("\n[SUCCESS] ALL TESTS PASSED SUCCESSFULLY!")

if __name__ == "__main__":
    asyncio.run(run_tests())
