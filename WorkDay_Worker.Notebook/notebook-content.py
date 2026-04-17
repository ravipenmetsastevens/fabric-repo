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
if not key_path: raise FileNotFoundError("Key file not found")
with open(key_path, "r", encoding="utf-8") as f: PRIVATE_KEY_PEM = f.read()

now = int(time.time())
claims = {"iss": CLIENT_ID, "sub": ISU_SUBJECT, "aud": TOKEN_URL, "iat": now, "exp": now + 300}
assertion = jwt.encode(claims, PRIVATE_KEY_PEM, algorithm="RS256")

r = requests.post(TOKEN_URL, headers={"Content-Type": "application/x-www-form-urlencoded"},
                  data={"grant_type":"urn:ietf:params:oauth:grant-type:jwt-bearer","assertion":assertion}, timeout=30)
body = r.json()
if "access_token" not in body: raise SystemExit(f"Auth failed: {body}")
access_token = body["access_token"]

session = requests.Session()
session.headers.update({"Authorization": f"Bearer {access_token}", "Accept": "application/json"})

personal_objs = [
    "/workers",                    # summary workers
    "/people",                     # if tenant exposes
    "/contacts",                   # if tenant exposes
    "/emails",                     # if tenant exposes
    "/phoneNumbers",               # if tenant exposes
    "/personalData"                # if tenant exposes
]

org_objs = [
    "/supervisoryOrganizations",
    "/positions",
    "/jobProfiles",
    "/companies",
    "/departments",
    "/costCenters",
    "/locations",
    "/currencies",
    "/countries",
    "/states",
    "/regions",
    "/timeTypes",
    "/payRates",
    "/payGroups",
    "/titles"
]

def check(ep):
    url = f"{API_BASE}{ep}"
    try:
        resp = session.get(url, params={"limit":5}, timeout=45)
        if resp.status_code == 200:
            print(f"{ep:35s} -> 200 OK")
        else:
            msg = resp.text.replace("\n"," ")
            if len(msg) > 140: msg = msg[:140] + "..."
            print(f"{ep:35s} -> {resp.status_code} | {msg}")
    except Exception as e:
        print(f"{ep:35s} -> error | {e}")

print("== Personal objects ==")
for ep in personal_objs: check(ep)

print("\n== Organization objects ==")
for ep in org_objs: check(ep)


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

candidates = [
    ("workers", [
        "/workers", "/common/workers", "/people", "/personalData"
    ]),
    ("supervisoryOrganizations", [
        "/supervisoryOrganizations", "/common/supervisoryOrganizations"
    ]),
    ("positions", [
        "/positions", "/common/positions"
    ]),
    ("jobProfiles", [
        "/jobProfiles", "/common/jobProfiles", "/titles"
    ]),
    ("companies", [
        "/companies", "/organizations", "/common/companies"
    ]),
    ("departments", [
        "/departments", "/organizationDepartments"
    ]),
    ("costCenters", [
        "/costCenters", "/common/costCenters"
    ]),
    ("locations", [
        "/locations", "/common/locations"
    ]),
    ("currencies", [
        "/currencies", "/values/currencies"
    ]),
    ("countries", [
        "/countries", "/values/countries"
    ]),
    ("states", [
        "/states", "/values/states", "/values/regions"
    ]),
    ("timeTypes", [
        "/timeTypes", "/values/timeTypes"
    ]),
    ("payRates", [
        "/payRates", "/values/payRates"
    ]),
    ("payGroups", [
        "/payGroups", "/values/payGroups"
    ])
]

key_paths = [
    "/lakehouse/data_central_lh/Files/workday_integration.key",
    "/lakehouse/default/Files/workday_integration.key",
]
key_path = next((p for p in key_paths if os.path.exists(p)), None)
if not key_path: raise FileNotFoundError("Key file not found")
with open(key_path, "r", encoding="utf-8") as f: PRIVATE_KEY_PEM = f.read()

now = int(time.time())
claims = {"iss": CLIENT_ID, "sub": ISU_SUBJECT, "aud": TOKEN_URL, "iat": now, "exp": now + 300}
assertion = jwt.encode(claims, PRIVATE_KEY_PEM, algorithm="RS256")
tok = requests.post(
    TOKEN_URL,
    headers={"Content-Type":"application/x-www-form-urlencoded"},
    data={"grant_type":"urn:ietf:params:oauth:grant-type:jwt-bearer","assertion":assertion},
    timeout=30
).json()
if "access_token" not in tok: raise SystemExit(f"Auth failed: {tok}")
hdrs = {"Authorization": f"Bearer {tok['access_token']}", "Accept": "application/json"}

def probe(path):
    try:
        r = requests.get(f"{API_BASE}{path}", params={"limit":5}, headers=hdrs, timeout=45)
        if r.status_code == 200: return "200 OK"
        msg = r.text.replace("\n"," ")
        return f"{r.status_code} | {msg[:140] + ('...' if len(msg)>140 else '')}"
    except Exception as e:
        return f"error | {e}"

for logical, paths in candidates:
    hit = None
    for p in paths:
        res = probe(p)
        print(f"{logical:26s} {p:32s} -> {res}")
        if res.startswith("200"): 
            hit = p
            break
    if not hit:
        pass


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

# %pip install requests PyJWT
import os, time, requests, jwt
from pyspark.sql import functions as F
from pyspark.sql.types import StructType, StructField, StringType

CLIENT_ID     = "N2ZkZWI1YjktOWM4Ni00ZDI2LTg0MzItNmY5YWMwMGMzYTUx"
ISU_SUBJECT   = "ISU_Ms_Fabric"
TOKEN_URL     = "https://wd5-services1.myworkday.com/ccx/oauth2/stevenstransport/token"
API_BASE      = "https://wd5-services1.myworkday.com/ccx/api/v1/stevenstransport"
TARGET_TABLE  = "workday_workers_bronze"

candidate_paths = [
    "/lakehouse/data_central_lh/Files/workday_integration.key",
    "/lakehouse/default/Files/workday_integration.key",
]
key_path = next((p for p in candidate_paths if os.path.exists(p)), None)
if not key_path:
    raise FileNotFoundError("Key not found")

with open(key_path, "r", encoding="utf-8") as f:
    PRIVATE_KEY_PEM = f.read()

now = int(time.time())
claims = {"iss": CLIENT_ID, "sub": ISU_SUBJECT, "aud": TOKEN_URL, "iat": now, "exp": now+300}
assertion = jwt.encode(claims, PRIVATE_KEY_PEM, algorithm="RS256")
r = requests.post(TOKEN_URL, headers={"Content-Type":"application/x-www-form-urlencoded"},
                  data={"grant_type":"urn:ietf:params:oauth:grant-type:jwt-bearer","assertion":assertion}, timeout=30)
body = r.json()
if "access_token" not in body:
    raise SystemExit(f"Auth failed: {body}")
access_token = body["access_token"]

session = requests.Session()
session.headers.update({"Authorization":f"Bearer {access_token}", "Accept":"application/json"})

def get_json(url, params=None, timeout=90, max_retries=4):
    for attempt in range(max_retries):
        resp = session.get(url, params=params, timeout=timeout)
        if resp.status_code == 200:
            return resp.json()
        if resp.status_code in (408,429,500,502,503,504):
            time.sleep(1.5**attempt)
            continue
        raise SystemExit(f"HTTP {resp.status_code}: {resp.text[:300]}")
    raise SystemExit("Max retries reached")

url = f"{API_BASE}/workers"
params = {"limit": 100}
rows = []
while url:
    data = get_json(url, params=params)
    items = data.get("data") or data.get("workers") or []
    for it in items:
        rec = {}
        # always include id and descriptor (name)
        rec["worker_id"] = it.get("id")
        rec["name"] = it.get("descriptor")
        rec["status"] = it.get("status") or it.get("workerStatus") or it.get("worker_status")
        rec["title"] = it.get("jobProfile") or it.get("title") or it.get("position")
        rec["email"] = it.get("primaryWorkEmail")
        rec["phone"] = it.get("primaryPhone") or it.get("workPhone") or it.get("phone")
        sup = it.get("supervisoryOrganization") or {}
        rec["manager"] = sup.get("descriptor")
        rec["department"] = it.get("supervisoryOrganization") and sup.get("descriptor")
        # flatten all nested dicts generically
        for k, v in it.items():
            if k in ("id","descriptor","status","jobProfile","title","primaryWorkEmail","primaryPhone","supervisoryOrganization"):
                continue
            if isinstance(v, dict):
                for sk, sv in v.items():
                    rec[f"{k}_{sk}"] = str(sv)
            else:
                rec[k] = str(v)
        rows.append(rec)
    url = (data.get("links") or {}).get("next")
    params = None

if not rows:
    print("No workers found")
    raise SystemExit()

cols = sorted({c for r in rows for c in r.keys()})
schema = StructType([StructField(c, StringType(), True) for c in cols])
data_rows = [[r.get(c) for c in cols] for r in rows]
df = spark.createDataFrame(data_rows, schema=schema)

if spark.catalog.tableExists(TARGET_TABLE):
    target_schema = spark.table(TARGET_TABLE).schema
    for f in target_schema.fields:
        if f.name not in df.columns:
            df = df.withColumn(f.name, F.lit(None).cast(f.dataType))
    df = df.select([F.col(f.name).cast(f.dataType) for f in target_schema.fields])
    df.write.mode("append").saveAsTable(TARGET_TABLE)
else:
    df.write.mode("overwrite").saveAsTable(TARGET_TABLE)

print(f"Loaded {df.count()} worker rows into {TARGET_TABLE}")


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

# %pip install requests PyJWT
import os, time, requests, jwt, json

CLIENT_ID     = "N2ZkZWI1YjktOWM4Ni00ZDI2LTg0MzItNmY5YWMwMGMzYTUx"
ISU_SUBJECT   = "ISU_Ms_Fabric"
TOKEN_URL     = "https://wd5-services1.myworkday.com/ccx/oauth2/stevenstransport/token"
API_BASE      = "https://wd5-services1.myworkday.com/ccx/api/v1/stevenstransport"

candidate_paths = [
    "/lakehouse/data_central_lh/Files/workday_integration.key",
    "/lakehouse/default/Files/workday_integration.key",
]
key_path = next((p for p in candidate_paths if os.path.exists(p)), None)
if not key_path:
    raise FileNotFoundError("Key not found")

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
    raise SystemExit(f"Auth failed: {body}")
access_token = body["access_token"]

session = requests.Session()
session.headers.update({"Authorization": f"Bearer {access_token}", "Accept": "application/json"})

def get_json(url, params=None, timeout=90, max_retries=4):
    for attempt in range(max_retries):
        resp = session.get(url, params=params, timeout=timeout)
        if resp.status_code == 200:
            return resp.json()
        if resp.status_code in (408,429,500,502,503,504):
            time.sleep(1.5**attempt)
            continue
        raise SystemExit(f"HTTP {resp.status_code}: {resp.text[:300]}")
    raise SystemExit("Max retries reached")

url = f"{API_BASE}/workers"
params = {"limit": 100}
all_keys = set()
sample_items = []

while url:
    data = get_json(url, params=params)
    items = data.get("data") or data.get("workers") or []
    for it in items:
        all_keys.update(it.keys())
        sample_items.append(it)
    url = (data.get("links") or {}).get("next")
    params = None
    if len(sample_items) > 300:
        break

print(f"\nTotal unique top-level keys: {len(all_keys)}\n")
for k in sorted(all_keys):
    print(k)

print("\nSample worker record (truncated):")
print(json.dumps(sample_items[0], indent=2)[:1500])


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

# %pip install requests PyJWT
import os, time, requests, jwt
from pyspark.sql import functions as F
from pyspark.sql.types import StructType, StructField, StringType

CLIENT_ID     = "N2ZkZWI1YjktOWM4Ni00ZDI2LTg0MzItNmY5YWMwMGMzYTUx"
ISU_SUBJECT   = "ISU_Ms_Fabric"
TOKEN_URL     = "https://wd5-services1.myworkday.com/ccx/oauth2/stevenstransport/token"
API_BASE      = "https://wd5-services1.myworkday.com/ccx/api/v1/stevenstransport"
TARGET_TABLE  = "workday_workers_bronze"

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
    raise SystemExit(f"Auth failed: {body}")
access_token = body["access_token"]

session = requests.Session()
session.headers.update({"Authorization": f"Bearer {access_token}", "Accept": "application/json"})

def get_json(url, timeout=90, max_retries=4):
    for attempt in range(max_retries):
        resp = session.get(url, timeout=timeout)
        if resp.status_code == 200:
            return resp.json()
        if resp.status_code in (408,429,500,502,503,504):
            time.sleep(1.5**attempt)
            continue
        print(f"HTTP {resp.status_code} {url}")
        return {}
    return {}

url = f"{API_BASE}/workers"
params = {"limit": 100}
workers = []
while url:
    data = get_json(url)
    items = data.get("data") or data.get("workers") or []
    workers.extend(items)
    url = (data.get("links") or {}).get("next")

records = []
for w in workers:
    wid = w.get("id")
    rec = {
        "worker_id": wid,
        "worker_name": w.get("descriptor"),
        "business_title": w.get("businessTitle"),
        "is_manager": str(w.get("isManager")),
        "primary_org": (w.get("primarySupervisoryOrganization") or {}).get("descriptor"),
        "location": (w.get("location") or {}).get("descriptor"),
        "dob": w.get("dateOfBirth")
    }
    sub_endpoints = {
        "workContactInformation": ["email", "phone"],
        "employmentData": ["hireDate","terminationDate","workerStatus"],
        "jobData": ["jobProfile","positionTitle","managementLevel","company","timeType","payRateType"],
        "organizationAssignments": ["department","costCenter","region"],
        "manager": ["manager_descriptor","manager_id"]
    }
    for ep in sub_endpoints.keys():
        eurl = f"{API_BASE}/workers/{wid}/{ep}"
        edata = get_json(eurl)
        if isinstance(edata, dict):
            for k, v in edata.items():
                if isinstance(v, dict):
                    for sk, sv in v.items():
                        rec[f"{ep}_{k}_{sk}"] = str(sv)
                else:
                    rec[f"{ep}_{k}"] = str(v)
    records.append(rec)

cols = sorted({k for r in records for k in r.keys()})
schema = StructType([StructField(c, StringType(), True) for c in cols])
data_rows = [[r.get(c) for c in cols] for r in records]
df = spark.createDataFrame(data_rows, schema=schema)
df.show()

if spark.catalog.tableExists(TARGET_TABLE):
    target_schema = spark.table(TARGET_TABLE).schema
    for f in target_schema.fields:
        if f.name not in df.columns:
            df = df.withColumn(f.name, F.lit(None).cast(f.dataType))
    df = df.select([F.col(f.name).cast(f.dataType) for f in target_schema.fields])
    df.write.mode("append").saveAsTable(TARGET_TABLE)
else:
    df.write.mode("overwrite").saveAsTable(TARGET_TABLE)

# print(f"Loaded {df.count()} workers with detailed attributes into {TARGET_TABLE}")


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

# %pip install requests PyJWT
import os, time, requests, jwt
import json

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
    raise SystemExit(f"Auth fail: {body}")
access_token = body["access_token"]

session = requests.Session()
session.headers.update({"Authorization": f"Bearer {access_token}", "Accept": "application/json"})

endpoints = [
    "/workers",
    "/workers/{id}",  # replace {id} later
    "/publicData",
    "/locations",
    "/currencies",
    "/people",
    "/personalData",
    "/workers/personalData",
    "/contacts",
    "/emails",
    "/phoneNumbers",
    "/organization",
    "/roles"
]

# first test top-level endpoints
for ep in endpoints:
    url = f"{API_BASE}{ep}"
    try:
        resp = session.get(url, timeout=30)
        print(f"{ep:25s} -> {resp.status_code}")
        if resp.status_code == 200:
            j = resp.json()
            if isinstance(j, dict):
                print("  keys:", list(j.keys())[:10])
            elif isinstance(j, list):
                print("  list length:", len(j))
        else:
            print("  body:", resp.text[:200])
    except Exception as e:
        print(f"{ep:25s} -> error {e}")

# if /workers worked, test one detail endpoint
if session.get(f"{API_BASE}/workers", timeout=30).status_code == 200:
    # get a worker id
    j = session.get(f"{API_BASE}/workers?limit=1", timeout=30).json()
    items = j.get("data") or j.get("workers") or []
    if items:
        wid = items[0].get("id")
        if wid:
            detail_ep = f"/workers/{wid}/workContactInformation"
            url = f"{API_BASE}{detail_ep}"
            resp = session.get(url, timeout=30)
            print(f"\nDetail endpoint {detail_ep} -> {resp.status_code}")
            if resp.status_code == 200:
                print(json.dumps(resp.json(), indent=2)[:1000])
            else:
                print("  body:", resp.text[:500])



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
    "/supervisoryOrganizations",
    "/positions",
    "/jobProfiles",
    "/locations",
    "/departments",
    "/companies",
    "/costCenters",
    "/regions",
    "/timeTypes",
    "/payRates",
    "/currencies",
    "/countries",
    "/states",
    "/timeOffPlans",
    "/benefitPlans",
    "/jobFamilies",
    "/grades",
    "/payGroups",
    "/Employee"
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
