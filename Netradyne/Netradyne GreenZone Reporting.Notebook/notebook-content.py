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
PAGE_LIMIT   = 500
BRONZE_TBL   = "netr_alerts_v1_bronze"   # existing Lakehouse Delta table
DAYS_BACK    = 3
# ====================

import requests, time
from datetime import datetime, timedelta, timezone
from zoneinfo import ZoneInfo
from pyspark.sql import functions as F
from pyspark.sql.types import StructType, StructField, StringType

BASE = "https://api.netradyne.com"
base_url = f"{BASE}/driveri/v1/tenants/{TENANT}/alerts"

# ---- last 3 days (CT -> UTC) ----
now_ct   = datetime.now(ZoneInfo("America/Chicago"))
start_ct = (now_ct - timedelta(days=DAYS_BACK)).replace(hour=0, minute=0, second=0, microsecond=0)
end_ct   = now_ct
to_ms_ct = lambda dct: int(dct.astimezone(timezone.utc).timestamp() * 1000)
print(f"Alerts last {DAYS_BACK} days (CT): {start_ct} → {end_ct}")

# ---- daily chunking ----
def day_chunks(start_dt, end_dt):
    cur = start_dt
    one = timedelta(days=1)
    while cur < end_dt:
        nxt = min(cur + one, end_dt)
        yield (cur, nxt)
        cur = nxt

# ---- robust GET ----
session = requests.Session()
session.headers.update({
    "Authorization": f"Bearer {ACCESS_TOKEN}",
    "Accept": "application/json",
    "Accept-Encoding": "gzip"
})
def get_json(url, params=None, timeout=90, max_retries=4):
    backoff = 1.5
    for attempt in range(1, max_retries+1):
        r = session.get(url, params=params, timeout=timeout)
        sc = r.status_code
        if sc in (408, 429, 500, 502, 503, 504):
            time.sleep(backoff ** attempt); continue
        if sc >= 400 and sc != 404:
            raise SystemExit(f"HTTP {sc} {url} | {r.text[:300]}")
        if sc == 204 or not (r.content and r.text.strip()):
            return {"data": {"alerts": []}, "links": {}, "totalCount": 0}
        ct = (r.headers.get("content-type") or "").lower()
        if "application/json" not in ct:
            raise SystemExit(f"Non-JSON {sc} ({ct}) {url} | {r.text[:200]}")
        return r.json()
    raise SystemExit("Max retries reached")

# ---- helpers ----
def safe(d, *keys, default=None):
    x = d
    for k in keys:
        x = (x or {}).get(k) if isinstance(x, dict) else None
    return x if x is not None else default

def first_or(lst, key, default=None):
    if isinstance(lst, list) and lst and isinstance(lst[0], dict):
        return lst[0].get(key, default)
    return default

def s(v): return None if v is None else str(v)

# ---- fixed ingest schema (all STRING) ----
COLS = [
    "data.alerts.updatedOn","data.alerts.speedData.speed","data.alerts.speedData.speedLimit",
    "data.alerts.videos.id","data.alerts.videos.status","data.alerts.videos.position","data.alerts.videos.timestamp",
    "data.alerts.camera.id","data.alerts.alertStatus","data.alerts.vehicle.vehicleNumber","data.alerts.vehicle.status",
    "data.alerts.vehicle.associationTime","data.alerts.driver.firstName","data.alerts.driver.lastName",
    "data.alerts.driver.driverId","data.alerts.details.subTypeId","data.alerts.details.weatherPrediction",
    "data.alerts.gpsData.timestamp","data.alerts.gpsData.latitude","data.alerts.gpsData.longitude","data.alerts.vehicle.vin",
    "data.alerts.details.severity","data.alerts.details.severityDescription","data.alerts.details.category",
    "data.alerts.details.categoryDescription","data.alerts.details.alertVideoStatus","data.alerts.details.cause",
    "data.alerts.id","data.alerts.timestamp","data.alerts.duration","data.alerts.details.typeId",
    "data.alerts.details.typeDescription","data.alerts.details.subTypeDescription",
    "links.self","links.next","links.prev","links.first","links.last","totalCount"
]
SCHEMA = StructType([StructField(c, StringType(), True) for c in COLS])

def consume_to_records(body, out_rows):
    lnks = body.get("links") or {}
    tcnt = body.get("totalCount")

    raw = body.get("data")
    if isinstance(raw, dict) and isinstance(raw.get("alerts"), list):
        items = [x for x in raw["alerts"] if isinstance(x, dict)]
    elif isinstance(raw, list):
        items = [x for x in raw if isinstance(x, dict)]
    elif isinstance(raw, dict):
        items = [raw]
    else:
        items = []

    for it in items:
        vids = it.get("videos")
        vids_list = vids if isinstance(vids, list) else ([vids] if isinstance(vids, dict) else [])
        row = {
            "data.alerts.updatedOn":                   s(safe(it, "updatedOn")),
            "data.alerts.speedData.speed":             s(safe(it, "speedData","speed")),
            "data.alerts.speedData.speedLimit":        s(safe(it, "speedData","speedLimit")),
            "data.alerts.videos.id":                   s(first_or(vids_list, "id")),
            "data.alerts.videos.status":               s(first_or(vids_list, "status")),
            "data.alerts.videos.position":             s(first_or(vids_list, "position")),
            "data.alerts.videos.timestamp":            s(first_or(vids_list, "timestamp")),
            "data.alerts.camera.id":                   s(safe(it, "camera","id")),
            "data.alerts.alertStatus":                 s(safe(it, "alertStatus")),
            "data.alerts.vehicle.vehicleNumber":       s(safe(it, "vehicle","vehicleNumber")),
            "data.alerts.vehicle.status":              s(safe(it, "vehicle","status")),
            "data.alerts.vehicle.associationTime":     s(safe(it, "vehicle","associationTime")),
            "data.alerts.driver.firstName":            s(safe(it, "driver","firstName")),
            "data.alerts.driver.lastName":             s(safe(it, "driver","lastName")),
            "data.alerts.driver.driverId":             s(safe(it, "driver","driverId")),
            "data.alerts.details.subTypeId":           s(safe(it, "details","subTypeId")),
            "data.alerts.details.weatherPrediction":   s(safe(it, "details","weatherPrediction")),
            "data.alerts.gpsData.timestamp":           s(safe(it, "gpsData","timestamp")),
            "data.alerts.gpsData.latitude":            s(safe(it, "gpsData","latitude")),
            "data.alerts.gpsData.longitude":           s(safe(it, "gpsData","longitude")),
            "data.alerts.vehicle.vin":                 s(safe(it, "vehicle","vin")),
            "data.alerts.details.severity":            s(safe(it, "details","severity")),
            "data.alerts.details.severityDescription": s(safe(it, "details","severityDescription")),
            "data.alerts.details.category":            s(safe(it, "details","category")),
            "data.alerts.details.categoryDescription": s(safe(it, "details","categoryDescription")),
            "data.alerts.details.alertVideoStatus":    s(safe(it, "details","alertVideoStatus")),
            "data.alerts.details.cause":               s(safe(it, "details","cause")),
            "data.alerts.id":                          s(safe(it, "id") or safe(it,"alertId") or safe(it,"eventId")),
            "data.alerts.timestamp":                   s(safe(it, "timestamp") or safe(it,"occurredAt") or safe(it,"eventTime")),
            "data.alerts.duration":                    s(safe(it, "duration")),
            "data.alerts.details.typeId":              s(safe(it, "details","typeId")),
            "data.alerts.details.typeDescription":     s(safe(it, "details","typeDescription")),
            "data.alerts.details.subTypeDescription":  s(safe(it, "details","subTypeDescription")),
            "links.self":                               s(lnks.get("self")),
            "links.next":                               s(lnks.get("next")),
            "links.prev":                               s(lnks.get("prev")),
            "links.first":                              s(lnks.get("first")),
            "links.last":                               s(lnks.get("last")),
            "totalCount":                               s(tcnt)
        }
        out_rows.append([row.get(c) for c in COLS])

# ==== MAIN: loop day-by-day, paginate, write ====
total_written = 0
for (day_start_ct, day_end_ct) in day_chunks(start_ct, end_ct):
    params = {"startTime": to_ms_ct(day_start_ct), "endTime": to_ms_ct(day_end_ct), "limit": PAGE_LIMIT}

    day_rows = []
    body = get_json(base_url, params=params, timeout=120); consume_to_records(body, day_rows)
    next_url = (body.get("links") or {}).get("next")

    pages = 1
    while next_url:
        body = get_json(next_url, timeout=120); consume_to_records(body, day_rows)
        next_url = (body.get("links") or {}).get("next")
        pages += 1
        if pages > 500: break  # safety guard

    # DataFrame (explicit schema)
    df_day = spark.createDataFrame(day_rows, schema=SCHEMA) if day_rows else spark.createDataFrame([], schema=SCHEMA)
    if df_day.rdd.isEmpty():
        print(f"[{day_start_ct.date()}] no data"); continue

    # de-dupe within the day by alert id
    df_day = df_day.withColumn("_id", F.col("`data.alerts.id`")).dropDuplicates(["_id"]).drop("_id")

    # align to bronze target schema/types
    target_schema = spark.table(BRONZE_TBL).schema
    for f in target_schema.fields:
        if f.name in df_day.columns:
            df_day = df_day.withColumn(f.name, F.col(f"`{f.name}`").cast(f.dataType))
        else:
            df_day = df_day.withColumn(f.name, F.lit(None).cast(f.dataType))
    df_day = df_day.select([F.col(f"`{f.name}`") for f in target_schema.fields])

    df_day.write.mode("append").saveAsTable(BRONZE_TBL)
    cnt = df_day.count()
    total_written += cnt
    print(f"[{day_start_ct.date()}] wrote {cnt} rows across {pages} page(s)")

print(f"Append complete → {BRONZE_TBL} | total rows written: {total_written}")


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

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
BRONZE_TBL   = "netr_driver_report_daily_bronze"   # existing Bronze table
# ====================

import requests
from datetime import datetime, timedelta, timezone
from zoneinfo import ZoneInfo
from pyspark.sql import functions as F

BASE = "https://api.netradyne.com"

# ---------- 1) 13-week window (CT -> UTC) ----------
now_ct = datetime.now(ZoneInfo("America/Chicago"))
start_ct = (now_ct - timedelta(weeks=13)).replace(hour=0, minute=0, second=0, microsecond=0)
end_ct   = now_ct  # include up to now today
start_utc = start_ct.astimezone(timezone.utc)
end_utc   = end_ct.astimezone(timezone.utc)
to_ms = lambda d: int(d.timestamp() * 1000)

print(f"13-week window CT: {start_ct} → {end_ct}")

# ---------- 2) Pull drivers/report weekly over the whole window ----------
session = requests.Session()
session.headers.update({"Authorization": f"Bearer {ACCESS_TOKEN}", "Accept": "application/json"})

params = {"interval":"weekly","startTime":to_ms(start_utc),"endTime":to_ms(end_utc),"limit":PAGE_LIMIT}
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
            "overspeeding_pct":  det.get("overspeedingPercentage")
        })

r = session.get(url, params=params, timeout=90)
if r.status_code == 400 and "Start time" in r.text:
    # some tenants want start/end keys
    params = {"interval":"weekly","start":to_ms(start_utc),"end":to_ms(end_utc),"limit":PAGE_LIMIT}
    r = session.get(url, params=params, timeout=90)
r.raise_for_status()

body = r.json(); consume(body)
next_url = body.get("links", {}).get("next")
while next_url:
    rr = session.get(next_url, timeout=90); rr.raise_for_status()
    body = rr.json(); consume(body)
    next_url = body.get("links", {}).get("next")

print(f"Fetched {len(rows)} weekly rows (across all drivers) for the 13-week window")

# ---------- 3) Aggregate to ONE score per driver over the 13 weeks ----------
if rows:
    df = spark.createDataFrame(rows)
else:
    # nothing returned; bail cleanly
    df = spark.createDataFrame([], schema="""
        driver_id STRING, first_name STRING, last_name STRING,
        driver_score DOUBLE, minutes_analyzed LONG,
        green_minutes_pct DOUBLE, overspeeding_pct DOUBLE
    """)

# minutes-weighted averages; fallback to simple avg if total minutes is 0
df_agg = (
    df.fillna({"driver_score":0.0,"minutes_analyzed":0,"green_minutes_pct":0.0,"overspeeding_pct":0.0})
      .withColumn("w_score", F.col("driver_score") * F.col("minutes_analyzed"))
      .withColumn("w_green", F.col("green_minutes_pct") * F.col("minutes_analyzed"))
      .withColumn("w_overs", F.col("overspeeding_pct") * F.col("minutes_analyzed"))
      .groupBy("driver_id","first_name","last_name")
      .agg(
          F.sum("minutes_analyzed").alias("minutes_analyzed"),
          F.sum("w_score").alias("sum_w_score"),
          F.sum("w_green").alias("sum_w_green"),
          F.sum("w_overs").alias("sum_w_overs"),
          F.avg("driver_score").alias("avg_score_fallback"),
          F.avg("green_minutes_pct").alias("avg_green_fallback"),
          F.avg("overspeeding_pct").alias("avg_overs_fallback"),
      )
      .withColumn(
          "driver_score",
          F.when(F.col("minutes_analyzed") > 0,
                 F.col("sum_w_score") / F.col("minutes_analyzed")).otherwise(F.col("avg_score_fallback"))
      )
      .withColumn(
          "green_minutes_pct",
          F.when(F.col("minutes_analyzed") > 0,
                 F.col("sum_w_green") / F.col("minutes_analyzed")).otherwise(F.col("avg_green_fallback"))
      )
      .withColumn(
          "overspeeding_pct",
          F.when(F.col("minutes_analyzed") > 0,
                 F.col("sum_w_overs") / F.col("minutes_analyzed")).otherwise(F.col("avg_overs_fallback"))
      )
      .select(
          "driver_id","first_name","last_name",
          "driver_score","minutes_analyzed","green_minutes_pct","overspeeding_pct"
      )
      # snapshot_date = end of window (today CT)
      .withColumn("snapshot_date", F.lit(now_ct.date().isoformat()).cast("date"))
      .withColumn("ingested_at_utc", F.current_timestamp())
)

# ---------- 4) Upsert into Bronze (idempotent on driver_id + snapshot_date = today) ----------
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

df_agg.createOrReplaceTempView("stage_13w")
spark.sql(f"""
MERGE INTO {BRONZE_TBL} AS tgt
USING stage_13w AS src
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

print("Bronze upsert complete for 13-week aggregate (snapshot_date = today CT).")


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }
