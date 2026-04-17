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
# META     },
# META     "warehouse": {
# META       "default_warehouse": "6d0007d9-0647-4acb-9add-13d26a7f0b54",
# META       "known_warehouses": [
# META         {
# META           "id": "6d0007d9-0647-4acb-9add-13d26a7f0b54",
# META           "type": "Lakewarehouse"
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

import requests
import json


TENANT_ID = "f49a8b5b-b823-476e-9774-2865e550dc1d"
CLIENT_ID = "544f573d-d7db-46e4-b398-3e9e095af30b"
CLIENT_SECRET = mssparkutils.credentials.getSecret(
    "https://keyvault-fabric2.vault.azure.net/",
    "ADGROUPSSECRET"
)


# Step 1: Get access token
token_url = f"https://login.microsoftonline.com/{TENANT_ID}/oauth2/v2.0/token"

token_data = {
    "client_id": CLIENT_ID,
    "scope": "https://graph.microsoft.com/.default",
    "client_secret": CLIENT_SECRET,
    "grant_type": "client_credentials",
}

token_response = requests.post(token_url, data=token_data)

if token_response.status_code != 200:
    print("Failed to get token")
    print(token_response.status_code, token_response.text)
    exit()

access_token = token_response.json()["access_token"]
print("Access token acquired successfully.\n")

# Step 2: Call Graph API
headers = {
    "Authorization": f"Bearer {access_token}",
    "Content-Type": "application/json",
}

graph_url = "https://graph.microsoft.com/v1.0/users?$select=id,displayName,mail,jobTitle,department&$top=100"

response = requests.get(graph_url, headers=headers)

if response.status_code != 200:
    print("Graph API call failed")
    print(response.status_code, response.text)
    exit()

users = response.json()

print("Users Retrieved:\n")
print(json.dumps(users, indent=2))

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

# ============================================================
# Entra ID (Azure AD) -> Fabric Lakehouse tables for RLS
# Target tables (no underscores) in SQL endpoint namespace:
#   data_central_lh.adgroupemployee
#   data_central_lh.adgroupemployeehierarchy
# ============================================================

import requests
import time
from typing import Dict, Any, List, Optional
from pyspark.sql import functions as F

# ----------------------------
# CONFIG: fill these in
# ----------------------------
TENANT_ID = "f49a8b5b-b823-476e-9774-2865e550dc1d"
CLIENT_ID = "544f573d-d7db-46e4-b398-3e9e095af30b"
CLIENT_SECRET = mssparkutils.credentials.getSecret(
    "https://keyvault-fabric2.vault.azure.net/",
    "ADGROUPSSECRET"
)

EMP_TABLE = f"data_central_lh.adgroupemployee"
HIER_TABLE = f"data_central_lh.adgroupemployeehierarchy"

# Optional: limit users for testing (None = full load)
TEST_TOP: Optional[int] = None  # e.g., 200

# Throttling controls (Graph can return 429 if you hammer it)
THROTTLE_SEC = 0.15
BATCH_PAUSE_EVERY = 50
BATCH_PAUSE_SEC = 1.0

# Max org depth for hierarchy expansion
MAX_LEVELS = 25


# ============================================================
# AUTH
# ============================================================
def get_access_token() -> str:
    token_url = f"https://login.microsoftonline.com/{TENANT_ID}/oauth2/v2.0/token"
    data = {
        "client_id": CLIENT_ID,
        "scope": "https://graph.microsoft.com/.default",
        "client_secret": CLIENT_SECRET,
        "grant_type": "client_credentials",
    }
    r = requests.post(token_url, data=data, timeout=30)
    r.raise_for_status()
    return r.json()["access_token"]


# ============================================================
# GRAPH HELPERS
# ============================================================
def _handle_429(r: requests.Response) -> bool:
    if r.status_code == 429:
        retry_after = int(r.headers.get("Retry-After", "5"))
        time.sleep(retry_after)
        return True
    return False


def graph_get_all(url: str, headers: Dict[str, str]) -> List[Dict[str, Any]]:
    out: List[Dict[str, Any]] = []
    next_url = url

    while next_url:
        r = requests.get(next_url, headers=headers, timeout=60)
        if _handle_429(r):
            continue
        r.raise_for_status()

        payload = r.json()
        out.extend(payload.get("value", []))
        next_url = payload.get("@odata.nextLink")

        time.sleep(THROTTLE_SEC)

    return out


def fetch_users(headers: Dict[str, str]) -> List[Dict[str, Any]]:
    # Fields needed for reporting + RLS mapping
    select_fields = ",".join([
        "id",
        "displayName",
        "givenName",
        "surname",
        "userPrincipalName",
        "mail",
        "jobTitle",
        "department",
        "companyName",
        "officeLocation",
        "accountEnabled"
    ])

    # $top=999 + paging
    url = f"https://graph.microsoft.com/v1.0/users?$select={select_fields}&$top=999"
    users = graph_get_all(url, headers)

    if TEST_TOP is not None:
        users = users[:TEST_TOP]

    return users


def fetch_manager_map(users: List[Dict[str, Any]], headers: Dict[str, str]) -> Dict[str, Optional[str]]:
    """
    Reliable approach: per-user manager lookup.
    Returns: { employeeId -> managerId or None }
    """
    mgr_map: Dict[str, Optional[str]] = {}

    for i, u in enumerate(users, start=1):
        uid = u["id"]
        url = f"https://graph.microsoft.com/v1.0/users/{uid}/manager?$select=id"

        r = requests.get(url, headers=headers, timeout=30)
        if _handle_429(r):
            r = requests.get(url, headers=headers, timeout=30)

        if r.status_code == 404:
            mgr_map[uid] = None
        else:
            r.raise_for_status()
            mgr_map[uid] = r.json().get("id")

        if i % BATCH_PAUSE_EVERY == 0:
            time.sleep(BATCH_PAUSE_SEC)
        else:
            time.sleep(THROTTLE_SEC)

    return mgr_map


# ============================================================
# MAIN: EXTRACT
# ============================================================
token = get_access_token()
headers = {"Authorization": f"Bearer {token}", "Accept": "application/json"}

print("Pulling users from Microsoft Graph...")
users = fetch_users(headers)
print(f"Users retrieved: {len(users)}")

print("Pulling manager relationships (can take time for large directories)...")
mgr_map = fetch_manager_map(users, headers)
print("Manager map built.")


# ============================================================
# TRANSFORM: Employee table
# ============================================================
employee_rows = []
for u in users:
    uid = u.get("id")
    employee_rows.append({
        # keys
        "employeeid": uid,
        "managerid": mgr_map.get(uid),

        # identity
        "userprincipalname": u.get("userPrincipalName"),
        "mail": u.get("mail"),

        # name
        "displayname": u.get("displayName"),
        "givenname": u.get("givenName"),
        "surname": u.get("surname"),

        # org attributes
        "jobtitle": u.get("jobTitle"),
        "department": u.get("department"),
        "companyname": u.get("companyName"),
        "officelocation": u.get("officeLocation"),
        "accountenabled": u.get("accountEnabled"),
    })

emp_df = spark.createDataFrame(employee_rows)

# Basic hygiene
emp_df = emp_df.where(F.col("employeeid").isNotNull())

# Optional: filter out disabled accounts (uncomment if your RLS should ignore disabled users)
# emp_df = emp_df.where(F.col("accountenabled") == True)


# ============================================================
# TRANSFORM: Hierarchy closure table
# employeeid -> managerid for ALL levels (for RLS)
# ============================================================
base = emp_df.select("employeeid", "managerid").where(F.col("managerid").isNotNull())

# Level 1: employee -> direct manager
cur = base.select(
    F.col("employeeid").alias("employeeid"),
    F.col("managerid").alias("ancestorid"),
    F.lit(1).alias("level")
)

all_levels = cur

for lvl in range(2, MAX_LEVELS + 1):
    nxt = (
        cur.alias("c")
        .join(base.alias("b"), F.col("c.ancestorid") == F.col("b.employeeid"), "left")
        .select(
            F.col("c.employeeid").alias("employeeid"),
            F.col("b.managerid").alias("ancestorid"),
            F.lit(lvl).alias("level")
        )
        .where(F.col("ancestorid").isNotNull())
    )

    if nxt.rdd.isEmpty():
        break

    all_levels = all_levels.unionByName(nxt)
    cur = nxt

hier_df = (
    all_levels
    .dropDuplicates(["employeeid", "ancestorid"])
    .withColumnRenamed("ancestorid", "managerid")
)

# Add self rows (common RLS requirement: user can at least see their own rows)
self_rows = emp_df.select(
    F.col("employeeid"),
    F.col("employeeid").alias("managerid"),
    F.lit(0).alias("level")
)

hier_df = (
    hier_df.unionByName(self_rows)
          .dropDuplicates(["employeeid", "managerid"])
)

print("Hierarchy rows built.")


# ============================================================
# LOAD: write to mmc_dw_prod.dbo
# ============================================================
print(f"Writing employee table to {EMP_TABLE} ...")
emp_df.write.format("delta").mode("overwrite").saveAsTable(EMP_TABLE)

print(f"Writing hierarchy table to {HIER_TABLE} ...")
hier_df.write.format("delta").mode("overwrite").saveAsTable(HIER_TABLE)

print("Write complete.")


# ============================================================
# VALIDATE
# ============================================================
spark.sql(f"SELECT COUNT(*) AS cnt FROM {EMP_TABLE}").show()
spark.sql(f"SELECT COUNT(*) AS cnt FROM {HIER_TABLE}").show()

spark.sql(f"""
SELECT employeeid, displayname, userprincipalname, managerid
FROM {EMP_TABLE}
LIMIT 10
""").show(truncate=False)

spark.sql(f"""
SELECT employeeid, managerid, level
FROM {HIER_TABLE}
ORDER BY employeeid, level
LIMIT 20
""").show(truncate=False)

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }
