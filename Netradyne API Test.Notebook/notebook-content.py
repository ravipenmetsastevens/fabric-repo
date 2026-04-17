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

# MARKDOWN ********************


# CELL ********************

# ====== CONFIG ======


import requests, json
from notebookutils import mssparkutils

# --- Read secrets from Azure Key Vault ---
ACCESS_TOKEN = mssparkutils.credentials.getSecret(
    "https://keyvault-fabric2.vault.azure.net/",
    "NETRAACCESSTOKEN"
)

TENANT = mssparkutils.credentials.getSecret(
    "https://keyvault-fabric2.vault.azure.net/",
    "NETRATENANT"
)
PAGE_LIMIT   = 100

BRONZE_TBL   = "netr_driver_report_daily_bronze"           # Lakehouse Delta table
SNAP_BASE = "/lakehouse/data_central_lh/Files/stage/netr_driver_report_daily_bronze"

import requests
from datetime import datetime, timedelta, timezone
from zoneinfo import ZoneInfo
from pyspark.sql import functions as F

BASE = "https://api.netradyne.com"

# Snapshot window: yesterday in America/Chicago → UTC
now_ct = datetime.now(ZoneInfo("America/Chicago"))
y_date = (now_ct - timedelta(days=1)).date()
start_ct = datetime(y_date.year, y_date.month, y_date.day, 0, 0, 0, tzinfo=ZoneInfo("America/Chicago"))
end_ct   = start_ct + timedelta(days=1)
start_utc, end_utc = start_ct.astimezone(timezone.utc), end_ct.astimezone(timezone.utc)
to_ms = lambda d: int(d.timestamp() * 1000)
y_str = y_date.isoformat()

# Pull API (v2 drivers/report) with pagination
session = requests.Session()
session.headers.update({"Authorization": f"Bearer {ACCESS_TOKEN}", "Accept": "application/json"})

params = {"interval":"daily","startTime":to_ms(start_utc),"endTime":to_ms(end_utc),"limit":PAGE_LIMIT}
url = f"{BASE}/driveri/v2/tenants/{TENANT}/drivers/report"

rows = []

def consume(body):
    for it in body.get("data", {}).get("driverReport", []):
        d   = (it.get("driver")  or {})
        det = (it.get("details") or {})
        rows.append({
            "driver_id":         d.get("driverId"),
            "first_name":        d.get("firstName"),
            "last_name":         d.get("lastName"),
            "driver_score":      det.get("driverScore"),
            "minutes_analyzed":  det.get("minutesAnalyzed"),
            "green_minutes_pct": det.get("greenMinutesPercentage"),
            "overspeeding_pct":  det.get("overspeedingPercentage"),
            "snapshot_date":     y_str
        })

r = session.get(url, params=params, timeout=90); r.raise_for_status()
body = r.json(); consume(body)
next_url = body.get("links", {}).get("next")
while next_url:
    r = session.get(next_url, timeout=90); r.raise_for_status()
    body = r.json(); consume(body)
    next_url = body.get("links", {}).get("next")

print(f"Fetched {len(rows)} rows for {y_str}")

# To Spark DF
if rows:
    df = spark.createDataFrame(rows)
else:
    df = spark.createDataFrame([], schema="""
        driver_id STRING, first_name STRING, last_name STRING, driver_score DOUBLE,
        minutes_analyzed LONG, green_minutes_pct DOUBLE, overspeeding_pct DOUBLE, snapshot_date STRING
    """)

df = (df.withColumn("snapshot_date", F.col("snapshot_date").cast("date"))
        .withColumn("ingested_at_utc", F.current_timestamp()))

# Create Bronze if missing
spark.sql(f"""
CREATE TABLE IF NOT EXISTS {BRONZE_TBL} (
  driver_id           STRING,
  first_name          STRING,
  last_name           STRING,
  driver_score        DOUBLE,
  minutes_analyzed    BIGINT,
  green_minutes_pct   DOUBLE,
  overspeeding_pct    DOUBLE,
  snapshot_date       DATE,
  ingested_at_utc     TIMESTAMP
) USING DELTA PARTITIONED BY (snapshot_date)
""")

# MERGE into Bronze (driver_id + snapshot_date)
df.createOrReplaceTempView("stage_driver_report")
spark.sql(f"""
MERGE INTO {BRONZE_TBL} AS tgt
USING stage_driver_report AS src
  ON tgt.driver_id = src.driver_id AND tgt.snapshot_date = src.snapshot_date
WHEN MATCHED THEN UPDATE SET
  tgt.first_name        = src.first_name,
  tgt.last_name         = src.last_name,
  tgt.driver_score      = src.driver_score,
  tgt.minutes_analyzed  = src.minutes_analyzed,
  tgt.green_minutes_pct = src.green_minutes_pct,
  tgt.overspeeding_pct  = src.overspeeding_pct,
  tgt.ingested_at_utc   = src.ingested_at_utc
WHEN NOT MATCHED THEN INSERT *
""")
print("Bronze MERGE complete.")

# Write Parquet snapshot for Warehouse COPY INTO
SNAP_PATH = f"{SNAP_BASE}/snapshot_date={y_str}"
(df.select("driver_id","first_name","last_name","driver_score","minutes_analyzed",
           "green_minutes_pct","overspeeding_pct","snapshot_date",
           F.current_timestamp().alias("loaded_at_utc"))
  .write.mode("overwrite").parquet(SNAP_PATH))
print("Snapshot parquet written ->", SNAP_PATH)


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# MARKDOWN ********************

# _<mark>**Drivers API Test**</mark>_

# CELL ********************

import requests, json

import requests, json
from notebookutils import mssparkutils

# --- Read secrets from Azure Key Vault ---
ACCESS_TOKEN = mssparkutils.credentials.getSecret(
    "https://keyvault-fabric2.vault.azure.net/",
    "NETRAACCESSTOKEN"
)

TENANT = mssparkutils.credentials.getSecret(
    "https://keyvault-fabric2.vault.azure.net/",
    "NETRATENANT"
)

base = "https://api.netradyne.com"
url  = f"{base}/driveri/v2/tenants/{TENANT}/drivers"
hdrs = {"Authorization": f"Bearer {ACCESS_TOKEN}", "Accept": "application/json"}

r = requests.get(url, headers=hdrs, timeout=30)
if r.status_code == 404: 
    url = f"{base}/driveri/v1/tenants/{TENANT}/drivers"
    r = requests.get(url, headers=hdrs, timeout=30)

print("STATUS:", r.status_code, r.reason)
try:
    print(json.dumps(r.json(), indent=2))
except Exception:
    print(r.text)


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************


import requests, json
from notebookutils import mssparkutils

# --- Read secrets from Azure Key Vault ---
ACCESS_TOKEN = mssparkutils.credentials.getSecret(
    "https://keyvault-fabric2.vault.azure.net/",
    "NETRAACCESSTOKEN"
)

TENANT = mssparkutils.credentials.getSecret(
    "https://keyvault-fabric2.vault.azure.net/",
    "NETRATENANT"
)
url = f"https://api.netradyne.com/driveri/v1/tenants/{TENANT}/devices"
r = requests.get(url, headers={"Authorization": f"Bearer {ACCESS_TOKEN}", "Accept":"application/json"}, timeout=30)
print(r.status_code, r.reason)
print(json.dumps(r.json(), indent=2))




# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# MARKDOWN ********************

# _<mark> ****GREENZone API Test****</mark>_

# CELL ********************

import requests, json
from datetime import datetime, timedelta, timezone
import requests, json
from notebookutils import mssparkutils

# --- Read secrets from Azure Key Vault ---
ACCESS_TOKEN = mssparkutils.credentials.getSecret(
    "https://keyvault-fabric2.vault.azure.net/",
    "NETRAACCESSTOKEN"
)

TENANT = mssparkutils.credentials.getSecret(
    "https://keyvault-fabric2.vault.azure.net/",
    "NETRATENANT"
)
url = f"https://api.netradyne.com/driveri/v1/tenants/{TENANT}/devices"
r = requests.get(url, headers={"Authorization": f"Bearer {ACCESS_TOKEN}", "Accept":"application/json"}, timeout=30)
print(r.status_code, r.reason)
print(json.dumps(r.json(), indent=2))




# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

import requests, json, time
from datetime import datetime, timedelta, timezone

# --- EDIT THESE ---
import requests, json
from notebookutils import mssparkutils

# --- Read secrets from Azure Key Vault ---
ACCESS_TOKEN = mssparkutils.credentials.getSecret(
    "https://keyvault-fabric2.vault.azure.net/",
    "NETRAACCESSTOKEN"
)

TENANT = mssparkutils.credentials.getSecret(
    "https://keyvault-fabric2.vault.azure.net/",
    "NETRATENANT"
)

base = "https://api.netradyne.com"
url  = f"{base}/driveri/v1/tenants/{TENANT}/fleetscore"
hdrs = {
    "Authorization": f"Bearer {ACCESS_TOKEN}",
    "Accept": "application/json",
    "Accept-Encoding": "gzip"
}

# Tiny window: yesterday 10:00–10:15 UTC
start_dt = (datetime.now(timezone.utc) - timedelta(days=1)).replace(hour=10, minute=0, second=0, microsecond=0)
end_dt   = start_dt + timedelta(minutes=15)
to_ms = lambda d: int(d.timestamp() * 1000)
print(start_dt)
params1 = {"interval": "daily", "startTime": to_ms(start_dt), "endTime": to_ms(end_dt)}

t0 = time.perf_counter()
try:
    r = requests.get(url, headers=hdrs, params=params1, timeout=(5, 20))  # connect=5s, read=20s
except requests.exceptions.ReadTimeout:
    raise SystemExit("Read timed out (20s). Try another 15-min window or raise the read timeout.")

elapsed = time.perf_counter() - t0

# If your tenant uses 'start'/'end' keys, flip once
if r.status_code == 400 and "Start time is required" in r.text:
    params2 = {"interval": "daily", "start": to_ms(start_dt), "end": to_ms(end_dt)}
    t1 = time.perf_counter()
    r = requests.get(url, headers=hdrs, params=params2, timeout=(5, 20))
    elapsed = time.perf_counter() - t1

print("URL:", r.request.url)
print("STATUS:", r.status_code, r.reason, f"| elapsed: {elapsed:.2f}s")
try:
    body = r.json()
    print(json.dumps(body, indent=2))
except Exception:
    print(r.text)


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

import requests, json
from datetime import datetime, timedelta, timezone
from datetime import date

import requests, json
from notebookutils import mssparkutils

# --- Read secrets from Azure Key Vault ---
ACCESS_TOKEN = mssparkutils.credentials.getSecret(
    "https://keyvault-fabric2.vault.azure.net/",
    "NETRAACCESSTOKEN"
)

TENANT = mssparkutils.credentials.getSecret(
    "https://keyvault-fabric2.vault.azure.net/",
    "NETRATENANT"
)
DRIVER_ID = "HIGGB"

INTERVAL     = "daily"                 # daily | weekly | monthly
DATE_STR     = date.today().isoformat()  # 'YYYY-MM-DD' (change if you want another day)

base  = "https://api.netradyne.com"
hdrs  = {"Authorization": f"Bearer {ACCESS_TOKEN}", "Accept": "application/json"}

# v1 first
url_v1 = f"{base}/driveri/v1/tenants/{TENANT}/drivers/{DRIVER_ID}/score"
params = {"interval": INTERVAL, "date": DATE_STR}
r = requests.get(url_v1, headers=hdrs, params=params, timeout=30)

# fallback to v2 if not found
if r.status_code == 404:
    url_v2 = f"{base}/driveri/v2/tenants/{TENANT}/drivers/{DRIVER_ID}/score"
    r = requests.get(url_v2, headers=hdrs, params=params, timeout=30)

print("STATUS:", r.status_code, r.reason)
try:
    print(json.dumps(r.json(), indent=2))
except Exception:
    print(r.text)


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

import requests, json

import requests, json
from notebookutils import mssparkutils

# --- Read secrets from Azure Key Vault ---
ACCESS_TOKEN = mssparkutils.credentials.getSecret(
    "https://keyvault-fabric2.vault.azure.net/",
    "NETRAACCESSTOKEN"
)

TENANT = mssparkutils.credentials.getSecret(
    "https://keyvault-fabric2.vault.azure.net/",
    "NETRATENANT"
)

base = "https://api.netradyne.com"
hdrs = {"Authorization": f"Bearer {ACCESS_TOKEN}", "Accept": "application/json"}

# try v1, fall back to v2 if needed
url = f"{base}/driveri/v1/tenants/{TENANT}/users"
r = requests.get(url, headers=hdrs, timeout=30)
if r.status_code == 404:
    url = f"{base}/driveri/v2/tenants/{TENANT}/users"
    r = requests.get(url, headers=hdrs, timeout=30)

print("STATUS:", r.status_code, r.reason)
try:
    data = r.json()
    print(json.dumps(data, indent=2))
    if isinstance(data, dict) and isinstance(data.get("data"), list):
        print("\nUsers returned:", len(data["data"]))
except Exception:
    print(r.text)



# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

import requests, json
from datetime import datetime, timedelta, timezone

import requests, json
from notebookutils import mssparkutils

# --- Read secrets from Azure Key Vault ---
ACCESS_TOKEN = mssparkutils.credentials.getSecret(
    "https://keyvault-fabric2.vault.azure.net/",
    "NETRAACCESSTOKEN"
)

TENANT = mssparkutils.credentials.getSecret(
    "https://keyvault-fabric2.vault.azure.net/",
    "NETRATENANT"
)

base = "https://api.netradyne.com"
url  = f"{base}/driveri/v2/tenants/{TENANT}/drivers/report"
hdrs = {"Authorization": f"Bearer {ACCESS_TOKEN}", "Accept": "application/json"}

# one small day (yesterday UTC)
start = (datetime.now(timezone.utc)-timedelta(days=1)).replace(hour=0, minute=0, second=0, microsecond=0)
end   = start + timedelta(days=1)
to_ms = lambda d: int(d.timestamp()*1000)

params = {"interval":"daily","startTime":to_ms(start),"endTime":to_ms(end)}
r = requests.get(url, headers=hdrs, params=params, timeout=45)

if r.status_code == 400 and "Start time" in r.text:
    params = {"interval":"daily","start":to_ms(start),"end":to_ms(end)}
    r = requests.get(url, headers=hdrs, params=params, timeout=45)

print("STATUS:", r.status_code, r.reason)
print(json.dumps(r.json(), indent=2) if r.headers.get("content-type","").startswith("application/json") else r.text)


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

# Bronze table to hold raw/normalized driver-report rows (one row per driver per day)
BRONZE = "netr_driver_report_daily_bronze"

spark.sql(f"""
CREATE TABLE IF NOT EXISTS {BRONZE} (
  driver_id           STRING,
  first_name          STRING,
  last_name           STRING,
  driver_score        DOUBLE,
  minutes_analyzed    BIGINT,
  green_minutes_pct   DOUBLE,
  overspeeding_pct    DOUBLE,
  snapshot_date       DATE,         -- the business date you’re snapshotting (e.g., yesterday)
  ingested_at_utc     TIMESTAMP
)
USING DELTA
PARTITIONED BY (snapshot_date)
""")
print("Bronze table ready:", BRONZE)


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

import requests, json
from datetime import datetime, timezone, timedelta

import requests, json
from notebookutils import mssparkutils

# --- Read secrets from Azure Key Vault ---
ACCESS_TOKEN = mssparkutils.credentials.getSecret(
    "https://keyvault-fabric2.vault.azure.net/",
    "NETRAACCESSTOKEN"
)

TENANT = mssparkutils.credentials.getSecret(
    "https://keyvault-fabric2.vault.azure.net/",
    "NETRATENANT"
)

base = "https://api.netradyne.com"
url  = f"{base}/driveri/v2/tenants/{TENANT}/drivers/report"
hdrs = {"Authorization": f"Bearer {ACCESS_TOKEN}", "Accept": "application/json"}

# start at LAST MONDAY (UTC) 00:00, 1-day window to keep payload small
today = datetime.now(timezone.utc).date()
days_since_monday = (today.weekday() - 0) % 7
if days_since_monday == 0:  # if today is Monday, use the previous Monday
    days_since_monday = 7
last_monday = today - timedelta(days=days_since_monday)

start = datetime(last_monday.year, last_monday.month, last_monday.day, tzinfo=timezone.utc)
end   = start + timedelta(days=1)
to_ms = lambda d: int(d.timestamp() * 1000)

# limit=10 as requested
params = {"interval": "daily", "startTime": to_ms(start), "endTime": to_ms(end), "limit": 100}
r = requests.get(url, headers=hdrs, params=params, timeout=45)

# Some tenants use 'start'/'end' keys instead of 'startTime'/'endTime'
if r.status_code == 400 and "Start time" in r.text:
    params = {"interval": "daily", "start": to_ms(start), "end": to_ms(end), "limit": 100}
    r = requests.get(url, headers=hdrs, params=params, timeout=45)

print("STATUS:", r.status_code, r.reason)
print(json.dumps(r.json(), indent=2) if r.headers.get("content-type","").startswith("application/json") else r.text)


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

spark.sql("SHOW DATABASES").show(truncate=False)
spark.sql("SHOW TABLES").show(truncate=False)


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }
