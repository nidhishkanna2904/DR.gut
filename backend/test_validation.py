"""Quick validation tests for Dr Gut backend — no AI key needed."""
import http.client
import json

BASE = "localhost"
PORT = 8000
BOUNDARY = "testboundary987654"


def make_multipart_body(fields: dict, file_content: bytes, filename: str, mime: str) -> bytes:
    parts = []
    for key, value in fields.items():
        parts.append(f"--{BOUNDARY}")
        parts.append(f'Content-Disposition: form-data; name="{key}"')
        parts.append("")
        parts.append(value)
    # File part
    parts.append(f"--{BOUNDARY}")
    parts.append(f'Content-Disposition: form-data; name="report"; filename="{filename}"')
    parts.append(f"Content-Type: {mime}")
    parts.append("")
    body_str = "\r\n".join(parts) + "\r\n"
    body_bytes = body_str.encode() + file_content + f"\r\n--{BOUNDARY}--\r\n".encode()
    return body_bytes


COMMON_FIELDS = {
    "name": "Test User",
    "phone": "9999999999",
    "location": "Coimbatore, Tamil Nadu",
    "lat": "11.0168",
    "lng": "76.9558",
    "budget": "300",
    "plan_type": "day",
}


def post(body: bytes, mime: str = None):
    conn = http.client.HTTPConnection(BASE, PORT, timeout=10)
    headers = {"Content-Type": f"multipart/form-data; boundary={BOUNDARY}"}
    conn.request("POST", "/diet-plan", body=body, headers=headers)
    resp = conn.getresponse()
    data = json.loads(resp.read())
    conn.close()
    return resp.status, data


print("=== Phase 1: Health check ===")
conn = http.client.HTTPConnection(BASE, PORT, timeout=5)
conn.request("GET", "/health")
r = conn.getresponse()
print(f"GET /health -> {r.status}: {json.loads(r.read())}")
conn.close()

print("\n=== Phase 2: Validation tests ===")

# Test: bad file type (.txt)
body = make_multipart_body(COMMON_FIELDS, b"not a report", "report.txt", "text/plain")
status, data = post(body)
print(f"Bad file type (txt)  -> {status} | detail: {data.get('detail', '')[:80]}")
assert status == 400, f"Expected 400, got {status}"
print("  PASS")

# Test: empty file
body = make_multipart_body(COMMON_FIELDS, b"", "report.jpg", "image/jpeg")
status, data = post(body)
print(f"Empty file           -> {status} | detail: {data.get('detail', '')[:80]}")
assert status == 400, f"Expected 400, got {status}"
print("  PASS")

# Test: oversized file (11 MB of zeros)
big = b"\x00" * (11 * 1024 * 1024)
body = make_multipart_body(COMMON_FIELDS, big, "report.jpg", "image/jpeg")
status, data = post(body)
print(f"Oversized file (11MB)-> {status} | detail: {data.get('detail', '')[:80]}")
assert status == 400, f"Expected 400, got {status}"
print("  PASS")

print("\nAll Phase 2 validation tests PASSED ✓")
