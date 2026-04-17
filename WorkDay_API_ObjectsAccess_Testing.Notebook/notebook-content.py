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

from notebookutils import mssparkutils

# --- Read secrets from Azure Key Vault ---
CLIENT_ID = mssparkutils.credentials.getSecret(
    "https://keyvault-fabric2.vault.azure.net/",
    "WORKDAYCLIENTID"
)
ISU_SUBJECT  = "ISU_Ms_Fabric"
TOKEN_URL    = "https://wd5-services1.myworkday.com/ccx/oauth2/stevenstransport/token"
API_BASE     = "https://wd5-services1.myworkday.com/ccx/api/v1/stevenstransport"

candidate_paths = [
    "/lakehouse/data_central_lh/Files/workday_integration.key",
    "/lakehouse/default/Files/workday_integration.key",
]
key_path = next((p for p in candidate_paths if os.path.exists(p)), None)
if not key_path:
    raise FileNotFoundError("Key file not found")

with open(key_path, "r", encoding="utf-8") as f:
    PRIVATE_KEY_PEM = f.read()

now = int(time.time())
claims = {"iss": CLIENT_ID, "sub": ISU_SUBJECT, "aud": TOKEN_URL, "iat": now, "exp": now + 300}
assertion = jwt.encode(claims, PRIVATE_KEY_PEM, algorithm="RS256")

r = requests.post(
    TOKEN_URL,
    headers={"Content-Type": "application/x-www-form-urlencoded"},
    data={"grant_type": "urn:ietf:params:oauth:grant-type:jwt-bearer", "assertion": assertion},
    timeout=30
)
body = r.json()
if "access_token" not in body:
    raise SystemExit(f"Auth failed: {body}")
access_token = body["access_token"]

session = requests.Session()
session.headers.update({
    "Authorization": f"Bearer {access_token}",
    "Accept": "application/json"
})

hr_objects = [
    "/workers",
    "/organizations",
    "/organizationTypes",
    "/organizationAssignmentChanges",
    "/jobs",
    "/people"
]

for ep in hr_objects:
    url = f"{API_BASE}{ep}"
    try:
        resp = session.get(url, params={"limit": 5}, timeout=45)
        if resp.status_code == 200:
            print(f"{ep:35s} -> 200 OK")
        else:
            txt = resp.text.replace("\n", " ")
            if len(txt) > 120:
                txt = txt[:120] + "..."
            print(f"{ep:35s} -> {resp.status_code} | {txt}")
    except Exception as e:
        print(f"{ep:35s} -> error | {e}")


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }
