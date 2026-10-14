import asyncio
import json
import asyncpg

async def show_db_history():
    conn = await asyncpg.connect("postgresql://dr_gut_user:nidhish%2329@127.0.0.1:5432/dr_gut")
    print("==================================================")
    print("          DR. GUT — LOCAL DATABASE HISTORY         ")
    print("==================================================\n")
    
    users = await conn.fetch("SELECT id, name, phone, created_at FROM users ORDER BY id;")
    print(f"-- USERS TABLE ({len(users)} registered users) --")
    for u in users:
        print(f"  User #{u['id']}: {u['name']} (Phone: {u['phone']}) - Joined: {u['created_at'].strftime('%Y-%m-%d %H:%M:%S')}")
    
    plans = await conn.fetch("SELECT id, user_id, location, budget, plan_type, status, created_at, result_json FROM diet_plan_requests ORDER BY id;")
    print(f"\n-- DIET PLAN REQUESTS ({len(plans)} plans stored) --")
    for p in plans:
        summary = ""
        if p["result_json"]:
            res = json.loads(p["result_json"]) if isinstance(p["result_json"], str) else p["result_json"]
            summary = res.get("summary", "")[:75]
        print(f"  Plan #{p['id']}: User ID={p['user_id']} | Type={p['plan_type']} | Budget=Rs {p['budget']} | Status={p['status']}")
        print(f"          Created: {p['created_at'].strftime('%Y-%m-%d %H:%M:%S')}")
        print(f"          Summary: {summary}...")
        print(f"          Location: {p['location']}")

    calories = await conn.fetch("SELECT id, user_id, total_calories, protein_g, carbs_g, fat_g, fiber_g, confidence, created_at FROM calorie_logs ORDER BY id;")
    print(f"\n-- CALORIE ESTIMATION LOGS ({len(calories)} photo analyses stored) --")
    for c in calories:
        print(f"  Log #{c['id']}: {c['total_calories']} kcal | P: {c['protein_g']}g | C: {c['carbs_g']}g | F: {c['fat_g']}g | Fiber: {c['fiber_g']}g | Confidence: {c['confidence']}")
        print(f"          Logged: {c['created_at'].strftime('%Y-%m-%d %H:%M:%S')}")

    print("\n==================================================")
    await conn.close()

if __name__ == "__main__":
    asyncio.run(show_db_history())
