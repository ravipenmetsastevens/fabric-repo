# Fabric notebook source

# METADATA ********************

# META {
# META   "kernel_info": {
# META     "name": "synapse_pyspark"
# META   },
# META   "dependencies": {
# META     "lakehouse": {
# META       "default_lakehouse": "f9a73da1-08e4-4f3d-a67f-74623bfde721",
# META       "default_lakehouse_name": "data_central_lh",
# META       "default_lakehouse_workspace_id": "a6d2c31b-0b03-4c60-a258-c2664c56fe3d",
# META       "known_lakehouses": [
# META         {
# META           "id": "f9a73da1-08e4-4f3d-a67f-74623bfde721"
# META         },
# META         {
# META           "id": "116d22a7-a4dd-4285-8f7e-411dd6d99a46"
# META         }
# META       ]
# META     }
# META   }
# META }

# CELL ********************

# Welcome to your new notebook
# Type here in the cell editor to add code!


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

# %pip install requests PyJWT
import os, time, requests, jwt

TOKEN_URL = "https://wd5-services1.myworkday.com/ccx/oauth2/stevenstransport/token"
API_BASE  = "https://wd5-services1.myworkday.com/ccx/api/v1/stevenstransport"
CLIENT_ID = "N2ZkZWI1YjktOWM4Ni00ZDI2LTg0MzItNmY5YWMwMGMzYTUx"
ISU_SUBJECT = "ISU_Ms_Fabric"  # change to exact ISU username if needed

candidate_paths = [
    "/lakehouse/data_central_lh/Files/workday_integration.key",
    "/lakehouse/default/Files/workday_integration.key",
]

key_path = next((p for p in candidate_paths if os.path.exists(p)), None)
if not key_path:
    raise FileNotFoundError(
        "Key not found at expected lakehouse mounts. "
        "Attach the correct Lakehouse and verify the file path under Files."
    )

with open(key_path, "r", encoding="utf-8") as f:
    PRIVATE_KEY_PEM = f.read()

now = int(time.time())
claims = {"iss": CLIENT_ID, "sub": ISU_SUBJECT, "aud": TOKEN_URL, "iat": now, "exp": now+300}
assertion = jwt.encode(claims, PRIVATE_KEY_PEM, algorithm="RS256")

r = requests.post(
    TOKEN_URL,
    headers={"Content-Type": "application/x-www-form-urlencoded"},
    data={"grant_type": "urn:ietf:params:oauth:grant-type:jwt-bearer", "assertion": assertion},
    timeout=30
)
try:
    body = r.json()
except Exception:
    raise RuntimeError(f"Token call failed: {r.status_code} {r.text[:1000]}")

print("Token response keys:", list(body.keys()))

if "access_token" not in body:
    raise RuntimeError(f"No access_token. Status={r.status_code} Body={body}")

access_token = body["access_token"]
print("Got token. Expires in (s):", body.get("expires_in"))

# ---- inspect token claims (unverified) ----
try:
    decoded = jwt.decode(access_token, options={"verify_signature": False, "verify_aud": False})
    # Print a few useful fields if present
    print("Token claims (subset):", {k: decoded.get(k) for k in ("sub","scope","iss","aud","exp")})
except Exception as e:
    print("Token decode (unverified) failed:", e)

# ---- quick helper to probe endpoints ----
def probe(path: str, max_chars: int = 300):
    url = f"{API_BASE}{path if path.startswith('/') else '/' + path}"
    resp = requests.get(url, headers={"Authorization": f"Bearer {access_token}", "Accept": "application/json"}, timeout=60)
    preview = resp.text[:max_chars].replace("\n", "") if resp.text else ""
    print(f"{path:25s} -> {resp.status_code}  {preview}")
    return resp.status_code

# ---- first try workers as before ----
print("\nSingle call check:")
probe("/workers")
probe("/currencies")


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

# Set your candidate paths
candidate_paths = [
    "/lakehouse/data_central_lh/Files/workday_integration.key",
    "/lakehouse/default/Files/workday_integration.key",
]

# Find the first path that exists
key_path = next((p for p in candidate_paths if os.path.exists(p)), None)

if key_path:
    with open(key_path, "r", encoding="utf-8") as f:
        key_content = f.read()
    print("Found key at:", key_path)
    print("First 100 chars of key:\n", key_content[:100])
else:
    print("Key not found in expected locations.")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

# %pip install requests PyJWT
import os, time, requests, jwt

TOKEN_URL = "https://wd5-impl-services1.workday.com/ccx/oauth2/stevenstransport/token"
API_BASE  = "https://wd5-impl-services1.workday.com/ccx/api/v1/stevenstransport"
CLIENT_ID = "MTQ5OTE1ODItYTM2My00ZTA1LWI4OTMtMjBiMGU3YmJmZGMy"
ISU_SUBJECT = "ISU_Ms_Fabric"  # change to exact ISU username if needed

candidate_paths = [
    "/lakehouse/data_central_lh/Files/workday_integration.key",
    "/lakehouse/default/Files/workday_integration.key",
]

key_path = next((p for p in candidate_paths if os.path.exists(p)), None)
if not key_path:
    raise FileNotFoundError(
        "Key not found at expected lakehouse mounts. "
        "Attach the correct Lakehouse and verify the file path under Files."
    )

with open(key_path, "r", encoding="utf-8") as f:
    PRIVATE_KEY_PEM = f.read()

now = int(time.time())
claims = {"iss": CLIENT_ID, "sub": ISU_SUBJECT, "aud": TOKEN_URL, "iat": now, "exp": now+300}
assertion = jwt.encode(claims, PRIVATE_KEY_PEM, algorithm="RS256")

r = requests.post(
    TOKEN_URL,
    headers={"Content-Type": "application/x-www-form-urlencoded"},
    data={"grant_type": "urn:ietf:params:oauth:grant-type:jwt-bearer", "assertion": assertion},
    timeout=30
)
try:
    body = r.json()
except Exception:
    raise RuntimeError(f"Token call failed: {r.status_code} {r.text[:1000]}")

print("Token response keys:", list(body.keys()))

if "access_token" not in body:
    raise RuntimeError(f"No access_token. Status={r.status_code} Body={body}")

access_token = body["access_token"]
print("Got token. Expires in (s):", body.get("expires_in"))

# ---- inspect token claims (unverified) ----
try:
    decoded = jwt.decode(access_token, options={"verify_signature": False, "verify_aud": False})
    # Print a few useful fields if present
    print("Token claims (subset):", {k: decoded.get(k) for k in ("sub","scope","iss","aud","exp")})
except Exception as e:
    print("Token decode (unverified) failed:", e)

# ---- quick helper to probe endpoints ----
def probe(path: str, max_chars: int = 300):
    url = f"{API_BASE}{path if path.startswith('/') else '/' + path}"
    resp = requests.get(url, headers={"Authorization": f"Bearer {access_token}", "Accept": "application/json"}, timeout=60)
    preview = resp.text[:max_chars].replace("\n", "") if resp.text else ""
    print(f"{path:25s} -> {resp.status_code}  {preview}")
    return resp.status_code

# ---- first try workers as before ----
print("\nSingle call check:")
probe("/workers")





# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

# %pip install requests PyJWT
import os, time, requests, jwt

# ---- Auth & Config ----
TOKEN_URL = "https://wd5-services1.myworkday.com/ccx/oauth2/stevenstransport/token"
API_BASE  = "https://wd5-services1.myworkday.com/ccx/api/v1/stevenstransport"
CLIENT_ID = "N2ZkZWI1YjktOWM4Ni00ZDI2LTg0MzItNmY5YWMwMGMzYTUx"
ISU_SUBJECT = "ISU_Ms_Fabric"

candidate_paths = [
    "/lakehouse/data_central_lh/Files/workday_integration.key",
    "/lakehouse/default/Files/workday_integration.key",
]

key_path = next((p for p in candidate_paths if os.path.exists(p)), None)
if not key_path:
    raise FileNotFoundError("Key not found. Verify Lakehouse file path.")

with open(key_path, "r", encoding="utf-8") as f:
    PRIVATE_KEY_PEM = f.read()

now = int(time.time())
claims = {"iss": CLIENT_ID, "sub": ISU_SUBJECT, "aud": TOKEN_URL, "iat": now, "exp": now+300}
assertion = jwt.encode(claims, PRIVATE_KEY_PEM, algorithm="RS256")

r = requests.post(
    TOKEN_URL,
    headers={"Content-Type": "application/x-www-form-urlencoded"},
    data={"grant_type": "urn:ietf:params:oauth:grant-type:jwt-bearer", "assertion": assertion},
    timeout=30
)

body = r.json()
if "access_token" not in body:
    raise RuntimeError(f"Failed to get token. Status={r.status_code}, Body={body}")
access_token = body["access_token"]

url = f"{API_BASE}/workers"
params = {"limit": 10}  
headers = {
    "Authorization": f"Bearer {access_token}",
    "Accept": "application/json"
}

resp = requests.get(url, headers=headers, params=params, timeout=60)
print("Status:", resp.status_code)

if resp.status_code == 200:
    data = resp.json()
    workers = data.get("data") or data.get("workers") or []
    print(f"\nFound {len(workers)} worker records.\n")
    for i, w in enumerate(workers[:10], start=1):
        print(f"{i}. Worker ID: {w.get('id')} | Name: {w.get('descriptor')}")
else:
    print("Response text:", resp.text[:1000])


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }
