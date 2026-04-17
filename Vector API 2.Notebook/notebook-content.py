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

# MAGIC %%sql
# MAGIC DROP TABLE IF EXISTS vector_checkin_kv_bronze;
# MAGIC 
# MAGIC 


# METADATA ********************

# META {
# META   "language": "sparksql",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

import requests, json, time
from datetime import datetime, timezone

from pyspark.sql.types import (
    StructType, StructField, StringType, BooleanType, IntegerType, TimestampType
)

# =========================
# CONFIG
# =========================
from notebookutils import mssparkutils

# --- Read secrets from Azure Key Vault ---
VECTOR_TOKEN = mssparkutils.credentials.getSecret(
    "https://keyvault-fabric2.vault.azure.net/",
    "VECTORTOKEN"
)  # <-- put your token here

QUERY_ENDPOINT  = "https://api.withvector.com/1.0/entities/query"
RECORD_ENDPOINT = "https://api.withvector.com/1.0/entities/records"

# Check-In mixin you provided (this is what we filter on)
CHECKIN_MIXIN_ID = "54809ba0-e1c6-46ec-af52-a392803a36b0"

# You said: don't use firmId (Fairlife-specific). So we won't send it.
# If you ever need it again, set FIRM_ID and add to metadata.
FIRM_ID = None  # e.g. "8ccd57ef-16a5-4b54-acd3-926af17d7139"

# Tables
TBL_CHECKIN_HEADER = "vector_checkin_header_bronze"
TBL_CHECKIN_EVENTS = "vector_checkin_events_bronze"
TBL_CHECKIN_RAW    = "vector_checkin_raw_bronze"

MAX_ENTITIES = 1000
PAGE_SIZE    = 50           # keep modest
SLEEP_BETWEEN_GETS = 0.12   # be nice to API

HEADERS = {
    "Authorization": f"Bearer {VECTOR_TOKEN}",
    "Content-Type": "application/json",
    "Accept": "application/json",
}

# =========================
# HELPERS
# =========================
def now_utc_ts():
    # Spark TimestampType prefers naive timestamp
    return datetime.now(timezone.utc).replace(tzinfo=None)

def jget(obj, path, default=None):
    """Safe nested getter using dot paths."""
    cur = obj
    for p in path.split("."):
        if cur is None:
            return default
        if isinstance(cur, dict):
            cur = cur.get(p)
        else:
            return default
    return cur if cur is not None else default

def pick_address(addr):
    if not isinstance(addr, dict):
        return {"streetAddress":"","locality":"","region":"","postalCode":"","timezoneId":"","countryName":""}
    return {
        "streetAddress": str(addr.get("streetAddress") or ""),
        "locality":      str(addr.get("locality") or ""),
        "region":        str(addr.get("region") or ""),
        "postalCode":    str(addr.get("postalCode") or ""),
        "timezoneId":    str(addr.get("timezoneId") or ""),
        "countryName":   str(addr.get("countryName") or ""),
    }

def infer_shipment_number(entity: dict) -> str:
    """
    Check-In doesn't always have a neat shipmentNumber property like shipment documents.
    In your sample JSON, the best key was:
      core_yms_execution.queries.appointment.request.name
    We also try other likely fields.
    """
    candidates = [
        jget(entity, "core_yms_execution.queries.appointment.request.shipmentNumber"),
        jget(entity, "core_yms_execution.queries.appointment.request.loadNumber"),
        jget(entity, "core_yms_execution.queries.appointment.request.purchaseOrderNumber"),
        jget(entity, "core_yms_execution.queries.appointment.request.name"),  # <-- your sample uses this
        jget(entity, "core_yms_execution.appointment.name"),
        jget(entity, "core_yms_execution.appointment.displayName"),
        jget(entity, "core_storyboard_execution.name"),  # fallback (not ideal as a key)
    ]
    for c in candidates:
        if c is None:
            continue
        c = str(c).strip()
        if c:
            return c
    return ""

def post_query(offset, size):
    payload = {
        "filters": [
            {
                "type": "containsEdge",
                "path": "mixins.active",
                "values": [{"entityId": CHECKIN_MIXIN_ID}]
            }
        ],
        "metadata": {
            "size": size,
            "offset": offset,
            "shouldIncludeLeafEntities": True
        }
    }

    # Optional firm scoping (disabled per your instruction)
    if FIRM_ID:
        payload["metadata"]["firmId"] = FIRM_ID

    r = requests.post(QUERY_ENDPOINT, headers=HEADERS, json=payload, timeout=60)

    if r.status_code != 200:
        print("----- Vector QUERY ERROR payload -----")
        print(json.dumps(payload, indent=2)[:4000])
        print("----- Vector QUERY ERROR response -----")
        try:
            print(json.dumps(r.json(), indent=2)[:4000])
        except Exception:
            print(r.text[:4000])

    r.raise_for_status()
    return r.json()

def fetch_first_n_ids(n=1000, page_size=50):
    ids = []
    offset = 0

    while len(ids) < n:
        size = min(page_size, n - len(ids))
        resp = post_query(offset=offset, size=size)
        children = resp.get("children", []) or []
        if not children:
            break

        # IMPORTANT: Vector query returns items as {"data": {...}} (your probe showed this)
        for c in children:
            uid = jget(c, "data.uniqueId")
            if uid:
                ids.append(str(uid))

        offset += size

        md = resp.get("metadata") or {}
        total = md.get("totalEntityMatchCount")
        if isinstance(total, int) and offset >= total:
            break

    # de-dupe preserve order
    seen = set()
    out = []
    for x in ids:
        if x not in seen:
            out.append(x)
            seen.add(x)
    return out

def get_record(entity_id: str) -> dict:
    r = requests.get(f"{RECORD_ENDPOINT}/{entity_id}", headers=HEADERS, timeout=60)
    r.raise_for_status()
    return r.json()

# =========================
# PARSERS
# =========================
def parse_checkin_header(entity: dict, extracted_at):
    owner_addr = jget(entity, "core_yms_execution.visit.location")
    owner_addr = owner_addr if isinstance(owner_addr, dict) else {}
    visit_loc = pick_address(owner_addr)

    shipment_number = infer_shipment_number(entity)

    return {
        "entityId": str(entity.get("uniqueId") or ""),
        "shipmentNumber": shipment_number,

        "ownerUserId": str(jget(entity, "owner.user.entityId") or ""),
        "ownerUserName": str(jget(entity, "owner.user.displayName") or ""),
        "ownerFirmId": str(jget(entity, "owner.firm.entityId") or ""),
        "ownerFirmName": str(jget(entity, "owner.firm.displayName") or ""),

        "createdByUserId": str(jget(entity, "createdBy.entityId") or ""),
        "createdByUserName": str(jget(entity, "createdBy.displayName") or ""),
        "creationDateUtc": str(entity.get("creationDate") or ""),
        "modifiedByUserId": str(jget(entity, "modifiedBy.entityId") or ""),
        "modifiedByUserName": str(jget(entity, "modifiedBy.displayName") or ""),
        "modifiedDateUtc": str(entity.get("modifiedDate") or ""),

        "storyboardId": str(jget(entity, "core_storyboard_execution.id") or ""),
        "workflowName": str(jget(entity, "core_storyboard_execution.name") or ""),
        "workflowStatus": str(jget(entity, "core_storyboard_execution.status") or ""),

        "visitStatus": str(jget(entity, "core_yms_execution.visit.status") or ""),
        "needsAttentionStatus": str(jget(entity, "kraft_heinz_execution.needsAttentionStatus") or ""),

        "visitRegion": visit_loc["region"],
        "visitCity": visit_loc["locality"],
        "visitPostalCode": visit_loc["postalCode"],
        "visitStreet": visit_loc["streetAddress"],
        "visitTimezoneId": visit_loc["timezoneId"],
        "visitCountry": visit_loc["countryName"],

        "appointmentRequestName": str(jget(entity, "core_yms_execution.queries.appointment.request.name") or ""),
        "appointmentResponseStatus": str(jget(entity, "core_yms_execution.queries.appointment.response.status") or ""),

        "noAppointment": bool(jget(entity, "core_yms_execution.noAppointment")) if jget(entity, "core_yms_execution.noAppointment") is not None else False,

        "extractedAtUtc": extracted_at
    }

def parse_checkin_raw(entity: dict, extracted_at):
    return {
        "entityId": str(entity.get("uniqueId") or ""),
        "shipmentNumber": infer_shipment_number(entity),
        "creationDateUtc": str(entity.get("creationDate") or ""),
        "modifiedDateUtc": str(entity.get("modifiedDate") or ""),
        "rawJson": json.dumps(entity),
        "extractedAtUtc": extracted_at
    }

def parse_checkin_events(entity: dict, extracted_at):
    rows = []
    entity_id = str(entity.get("uniqueId") or "")
    shipment_number = infer_shipment_number(entity)

    events = jget(entity, "core_storyboard_execution.events", [])
    if not isinstance(events, list):
        return rows

    for e in events:
        if not isinstance(e, dict):
            continue

        created_at_addr = e.get("createdAt") if isinstance(e.get("createdAt"), dict) else {}
        created_at_addr = pick_address(created_at_addr)

        source = e.get("source") if isinstance(e.get("source"), dict) else {}
        device = e.get("deviceInfo") if isinstance(e.get("deviceInfo"), dict) else {}
        mobile = device.get("mobile") if isinstance(device.get("mobile"), dict) else {}

        # Keep the messy nested bits as JSON strings in Bronze (safe + flexible)
        details_json = json.dumps(e.get("details")) if e.get("details") is not None else ""
        output_mappings_json = json.dumps(e.get("outputMappings")) if e.get("outputMappings") is not None else ""
        associations_json = json.dumps(e.get("associations")) if e.get("associations") is not None else ""

        rows.append({
            "entityId": entity_id,
            "shipmentNumber": shipment_number,

            "eventId": str(e.get("id") or ""),
            "eventType": str(e.get("eventType") or ""),
            "eventName": str(e.get("name") or ""),

            "taskId": str(source.get("taskId") or ""),
            "sceneId": str(source.get("sceneId") or ""),
            "storyId": str(source.get("storyId") or ""),

            "createdByUserId": str(jget(e, "createdBy.entityId") or ""),
            "createdByUserName": str(jget(e, "createdBy.displayName") or ""),

            "creationDateUtc": str(e.get("creationDate") or ""),
            "processedDateUtc": str(e.get("processedDate") or ""),

            "createdAtRegion": created_at_addr["region"],
            "createdAtCity": created_at_addr["locality"],
            "createdAtPostalCode": created_at_addr["postalCode"],
            "createdAtStreet": created_at_addr["streetAddress"],
            "createdAtTimezoneId": created_at_addr["timezoneId"],
            "createdAtCountry": created_at_addr["countryName"],

            "deviceName": str(device.get("name") or ""),
            "deviceLocale": str(device.get("locale") or ""),
            "devicePlatform": str(device.get("platform") or ""),
            "deviceAppVersion": str(device.get("appVersion") or ""),
            "deviceTimezoneId": str(device.get("timezoneId") or ""),
            "deviceConnectionType": str(device.get("connectionType") or ""),
            "deviceWorkflowVersion": str(device.get("workflowVersion") or ""),

            "isTablet": bool(mobile.get("isTablet")) if mobile.get("isTablet") is not None else False,
            "osVersion": str(mobile.get("osVersion") or ""),

            "detailsJson": details_json,
            "outputMappingsJson": output_mappings_json,
            "associationsJson": associations_json,

            "extractedAtUtc": extracted_at
        })

    return rows

# =========================
# EXPLICIT SCHEMAS
# =========================
checkin_header_schema = StructType([
    StructField("entityId", StringType(), False),
    StructField("shipmentNumber", StringType(), True),

    StructField("ownerUserId", StringType(), True),
    StructField("ownerUserName", StringType(), True),
    StructField("ownerFirmId", StringType(), True),
    StructField("ownerFirmName", StringType(), True),

    StructField("createdByUserId", StringType(), True),
    StructField("createdByUserName", StringType(), True),
    StructField("creationDateUtc", StringType(), True),
    StructField("modifiedByUserId", StringType(), True),
    StructField("modifiedByUserName", StringType(), True),
    StructField("modifiedDateUtc", StringType(), True),

    StructField("storyboardId", StringType(), True),
    StructField("workflowName", StringType(), True),
    StructField("workflowStatus", StringType(), True),

    StructField("visitStatus", StringType(), True),
    StructField("needsAttentionStatus", StringType(), True),

    StructField("visitRegion", StringType(), True),
    StructField("visitCity", StringType(), True),
    StructField("visitPostalCode", StringType(), True),
    StructField("visitStreet", StringType(), True),
    StructField("visitTimezoneId", StringType(), True),
    StructField("visitCountry", StringType(), True),

    StructField("appointmentRequestName", StringType(), True),
    StructField("appointmentResponseStatus", StringType(), True),
    StructField("noAppointment", BooleanType(), True),

    StructField("extractedAtUtc", TimestampType(), False),
])

checkin_events_schema = StructType([
    StructField("entityId", StringType(), False),
    StructField("shipmentNumber", StringType(), True),

    StructField("eventId", StringType(), True),
    StructField("eventType", StringType(), True),
    StructField("eventName", StringType(), True),

    StructField("taskId", StringType(), True),
    StructField("sceneId", StringType(), True),
    StructField("storyId", StringType(), True),

    StructField("createdByUserId", StringType(), True),
    StructField("createdByUserName", StringType(), True),

    StructField("creationDateUtc", StringType(), True),
    StructField("processedDateUtc", StringType(), True),

    StructField("createdAtRegion", StringType(), True),
    StructField("createdAtCity", StringType(), True),
    StructField("createdAtPostalCode", StringType(), True),
    StructField("createdAtStreet", StringType(), True),
    StructField("createdAtTimezoneId", StringType(), True),
    StructField("createdAtCountry", StringType(), True),

    StructField("deviceName", StringType(), True),
    StructField("deviceLocale", StringType(), True),
    StructField("devicePlatform", StringType(), True),
    StructField("deviceAppVersion", StringType(), True),
    StructField("deviceTimezoneId", StringType(), True),
    StructField("deviceConnectionType", StringType(), True),
    StructField("deviceWorkflowVersion", StringType(), True),

    StructField("isTablet", BooleanType(), True),
    StructField("osVersion", StringType(), True),

    StructField("detailsJson", StringType(), True),
    StructField("outputMappingsJson", StringType(), True),
    StructField("associationsJson", StringType(), True),

    StructField("extractedAtUtc", TimestampType(), False),
])

checkin_raw_schema = StructType([
    StructField("entityId", StringType(), False),
    StructField("shipmentNumber", StringType(), True),
    StructField("creationDateUtc", StringType(), True),
    StructField("modifiedDateUtc", StringType(), True),
    StructField("rawJson", StringType(), True),
    StructField("extractedAtUtc", TimestampType(), False),
])

# =========================
# RUN
# =========================
print(f"Fetching up to {MAX_ENTITIES} Check-In entity IDs...")
entity_ids = fetch_first_n_ids(n=MAX_ENTITIES, page_size=PAGE_SIZE)
print(f"Found {len(entity_ids)} IDs")

if not entity_ids:
    raise SystemExit("Zero IDs returned. Token/mixin access issue.")

extracted_at = now_utc_ts()

header_rows = []
event_rows  = []
raw_rows    = []

print("Fetching full JSON records (GET /entities/records/{id}) and parsing...")
for idx, eid in enumerate(entity_ids, start=1):
    ent = get_record(eid)

    header_rows.append(parse_checkin_header(ent, extracted_at))
    raw_rows.append(parse_checkin_raw(ent, extracted_at))
    event_rows.extend(parse_checkin_events(ent, extracted_at))

    if idx % 50 == 0:
        print(f"  parsed {idx}/{len(entity_ids)}")
    time.sleep(SLEEP_BETWEEN_GETS)

df_header = spark.createDataFrame(header_rows, schema=checkin_header_schema)
df_events = spark.createDataFrame(event_rows,  schema=checkin_events_schema)
df_raw    = spark.createDataFrame(raw_rows,    schema=checkin_raw_schema)

print("Header rows:", df_header.count())
print("Event rows:", df_events.count())
print("Raw rows:", df_raw.count())

# =========================
# WRITE (overwrite tables to avoid schema mismatch pain)
# =========================
spark.sql(f"DROP TABLE IF EXISTS {TBL_CHECKIN_HEADER}")
spark.sql(f"DROP TABLE IF EXISTS {TBL_CHECKIN_EVENTS}")
spark.sql(f"DROP TABLE IF EXISTS {TBL_CHECKIN_RAW}")

df_header.write.format("delta").mode("overwrite").option("overwriteSchema","true").saveAsTable(TBL_CHECKIN_HEADER)
df_events.write.format("delta").mode("overwrite").option("overwriteSchema","true").saveAsTable(TBL_CHECKIN_EVENTS)
df_raw.write.format("delta").mode("overwrite").option("overwriteSchema","true").saveAsTable(TBL_CHECKIN_RAW)

print(f"Loaded: {TBL_CHECKIN_HEADER}, {TBL_CHECKIN_EVENTS}, {TBL_CHECKIN_RAW}")

# Quick sanity: show a few shipment numbers + workflow
df_header.select("entityId","shipmentNumber","workflowStatus","visitStatus","creationDateUtc").show(500, truncate=False)


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

import requests, json, time
from datetime import datetime, timezone

from pyspark.sql.types import (
    StructType, StructField, StringType, BooleanType, IntegerType, TimestampType
)

# =========================
# CONFIG
# =========================
from notebookutils import mssparkutils

# --- Read secrets from Azure Key Vault ---
VECTOR_TOKEN = mssparkutils.credentials.getSecret(
    "https://keyvault-fabric2.vault.azure.net/",
    "VECTORTOKEN"
)  # <-- put your token here

QUERY_ENDPOINT  = "https://api.withvector.com/1.0/entities/query"
RECORD_ENDPOINT = "https://api.withvector.com/1.0/entities/records"

# Check-In mixin you provided (this is what we filter on)
CHECKIN_MIXIN_ID = "54809ba0-e1c6-46ec-af52-a392803a36b0"

# You said: don't use firmId (Fairlife-specific). So we won't send it.
# If you ever need it again, set FIRM_ID and add to metadata.
FIRM_ID = None  # e.g. "8ccd57ef-16a5-4b54-acd3-926af17d7139"

# Tables
TBL_CHECKIN_HEADER = "vector_checkin_header_bronze"
TBL_CHECKIN_EVENTS = "vector_checkin_events_bronze"
TBL_CHECKIN_RAW    = "vector_checkin_raw_bronze"

MAX_ENTITIES = 1000
PAGE_SIZE    = 50           # keep modest
SLEEP_BETWEEN_GETS = 0.12   # be nice to API

HEADERS = {
    "Authorization": f"Bearer {VECTOR_TOKEN}",
    "Content-Type": "application/json",
    "Accept": "application/json",
}

# =========================
# HELPERS
# =========================
def now_utc_ts():
    # Spark TimestampType prefers naive timestamp
    return datetime.now(timezone.utc).replace(tzinfo=None)

def jget(obj, path, default=None):
    """Safe nested getter using dot paths."""
    cur = obj
    for p in path.split("."):
        if cur is None:
            return default
        if isinstance(cur, dict):
            cur = cur.get(p)
        else:
            return default
    return cur if cur is not None else default

def pick_address(addr):
    if not isinstance(addr, dict):
        return {"streetAddress":"","locality":"","region":"","postalCode":"","timezoneId":"","countryName":""}
    return {
        "streetAddress": str(addr.get("streetAddress") or ""),
        "locality":      str(addr.get("locality") or ""),
        "region":        str(addr.get("region") or ""),
        "postalCode":    str(addr.get("postalCode") or ""),
        "timezoneId":    str(addr.get("timezoneId") or ""),
        "countryName":   str(addr.get("countryName") or ""),
    }

def infer_shipment_number(entity: dict) -> str:
    """
    Check-In doesn't always have a neat shipmentNumber property like shipment documents.
    In your sample JSON, the best key was:
      core_yms_execution.queries.appointment.request.name
    We also try other likely fields.
    """
    candidates = [
        jget(entity, "core_yms_execution.queries.appointment.request.shipmentNumber"),
        jget(entity, "core_yms_execution.queries.appointment.request.loadNumber"),
        jget(entity, "core_yms_execution.queries.appointment.request.purchaseOrderNumber"),
        jget(entity, "core_yms_execution.queries.appointment.request.name"),  # <-- your sample uses this
        jget(entity, "core_yms_execution.appointment.name"),
        jget(entity, "core_yms_execution.appointment.displayName"),
        jget(entity, "core_storyboard_execution.name"),  # fallback (not ideal as a key)
    ]
    for c in candidates:
        if c is None:
            continue
        c = str(c).strip()
        if c:
            return c
    return ""

def post_query(offset, size):
    payload = {
        "filters": [
            {
                "type": "containsEdge",
                "path": "mixins.active",
                "values": [{"entityId": CHECKIN_MIXIN_ID}]
            }
        ],
        "metadata": {
            "size": size,
            "offset": offset,
            "shouldIncludeLeafEntities": True
        }
    }

    # Optional firm scoping (disabled per your instruction)
    if FIRM_ID:
        payload["metadata"]["firmId"] = FIRM_ID

    r = requests.post(QUERY_ENDPOINT, headers=HEADERS, json=payload, timeout=60)

    if r.status_code != 200:
        print("----- Vector QUERY ERROR payload -----")
        print(json.dumps(payload, indent=2)[:4000])
        print("----- Vector QUERY ERROR response -----")
        try:
            print(json.dumps(r.json(), indent=2)[:4000])
        except Exception:
            print(r.text[:4000])

    r.raise_for_status()
    return r.json()

def fetch_first_n_ids(n=1000, page_size=50):
    ids = []
    offset = 0

    while len(ids) < n:
        size = min(page_size, n - len(ids))
        resp = post_query(offset=offset, size=size)
        children = resp.get("children", []) or []
        if not children:
            break

        # IMPORTANT: Vector query returns items as {"data": {...}} (your probe showed this)
        for c in children:
            uid = jget(c, "data.uniqueId")
            if uid:
                ids.append(str(uid))

        offset += size

        md = resp.get("metadata") or {}
        total = md.get("totalEntityMatchCount")
        if isinstance(total, int) and offset >= total:
            break

    # de-dupe preserve order
    seen = set()
    out = []
    for x in ids:
        if x not in seen:
            out.append(x)
            seen.add(x)
    return out

def get_record(entity_id: str) -> dict:
    r = requests.get(f"{RECORD_ENDPOINT}/{entity_id}", headers=HEADERS, timeout=60)
    r.raise_for_status()
    return r.json()

# =========================
# PARSERS
# =========================
def parse_checkin_header(entity: dict, extracted_at):
    owner_addr = jget(entity, "core_yms_execution.visit.location")
    owner_addr = owner_addr if isinstance(owner_addr, dict) else {}
    visit_loc = pick_address(owner_addr)

    shipment_number = infer_shipment_number(entity)

    return {
        "entityId": str(entity.get("uniqueId") or ""),
        "shipmentNumber": shipment_number,

        "ownerUserId": str(jget(entity, "owner.user.entityId") or ""),
        "ownerUserName": str(jget(entity, "owner.user.displayName") or ""),
        "ownerFirmId": str(jget(entity, "owner.firm.entityId") or ""),
        "ownerFirmName": str(jget(entity, "owner.firm.displayName") or ""),

        "createdByUserId": str(jget(entity, "createdBy.entityId") or ""),
        "createdByUserName": str(jget(entity, "createdBy.displayName") or ""),
        "creationDateUtc": str(entity.get("creationDate") or ""),
        "modifiedByUserId": str(jget(entity, "modifiedBy.entityId") or ""),
        "modifiedByUserName": str(jget(entity, "modifiedBy.displayName") or ""),
        "modifiedDateUtc": str(entity.get("modifiedDate") or ""),

        "storyboardId": str(jget(entity, "core_storyboard_execution.id") or ""),
        "workflowName": str(jget(entity, "core_storyboard_execution.name") or ""),
        "workflowStatus": str(jget(entity, "core_storyboard_execution.status") or ""),

        "visitStatus": str(jget(entity, "core_yms_execution.visit.status") or ""),
        "needsAttentionStatus": str(jget(entity, "kraft_heinz_execution.needsAttentionStatus") or ""),

        "visitRegion": visit_loc["region"],
        "visitCity": visit_loc["locality"],
        "visitPostalCode": visit_loc["postalCode"],
        "visitStreet": visit_loc["streetAddress"],
        "visitTimezoneId": visit_loc["timezoneId"],
        "visitCountry": visit_loc["countryName"],

        "appointmentRequestName": str(jget(entity, "core_yms_execution.queries.appointment.request.name") or ""),
        "appointmentResponseStatus": str(jget(entity, "core_yms_execution.queries.appointment.response.status") or ""),

        "noAppointment": bool(jget(entity, "core_yms_execution.noAppointment")) if jget(entity, "core_yms_execution.noAppointment") is not None else False,

        "extractedAtUtc": extracted_at
    }

def parse_checkin_raw(entity: dict, extracted_at):
    return {
        "entityId": str(entity.get("uniqueId") or ""),
        "shipmentNumber": infer_shipment_number(entity),
        "creationDateUtc": str(entity.get("creationDate") or ""),
        "modifiedDateUtc": str(entity.get("modifiedDate") or ""),
        "rawJson": json.dumps(entity),
        "extractedAtUtc": extracted_at
    }

def parse_checkin_events(entity: dict, extracted_at):
    rows = []
    entity_id = str(entity.get("uniqueId") or "")
    shipment_number = infer_shipment_number(entity)

    events = jget(entity, "core_storyboard_execution.events", [])
    if not isinstance(events, list):
        return rows

    for e in events:
        if not isinstance(e, dict):
            continue

        created_at_addr = e.get("createdAt") if isinstance(e.get("createdAt"), dict) else {}
        created_at_addr = pick_address(created_at_addr)

        source = e.get("source") if isinstance(e.get("source"), dict) else {}
        device = e.get("deviceInfo") if isinstance(e.get("deviceInfo"), dict) else {}
        mobile = device.get("mobile") if isinstance(device.get("mobile"), dict) else {}

        # Keep the messy nested bits as JSON strings in Bronze (safe + flexible)
        details_json = json.dumps(e.get("details")) if e.get("details") is not None else ""
        output_mappings_json = json.dumps(e.get("outputMappings")) if e.get("outputMappings") is not None else ""
        associations_json = json.dumps(e.get("associations")) if e.get("associations") is not None else ""

        rows.append({
            "entityId": entity_id,
            "shipmentNumber": shipment_number,

            "eventId": str(e.get("id") or ""),
            "eventType": str(e.get("eventType") or ""),
            "eventName": str(e.get("name") or ""),

            "taskId": str(source.get("taskId") or ""),
            "sceneId": str(source.get("sceneId") or ""),
            "storyId": str(source.get("storyId") or ""),

            "createdByUserId": str(jget(e, "createdBy.entityId") or ""),
            "createdByUserName": str(jget(e, "createdBy.displayName") or ""),

            "creationDateUtc": str(e.get("creationDate") or ""),
            "processedDateUtc": str(e.get("processedDate") or ""),

            "createdAtRegion": created_at_addr["region"],
            "createdAtCity": created_at_addr["locality"],
            "createdAtPostalCode": created_at_addr["postalCode"],
            "createdAtStreet": created_at_addr["streetAddress"],
            "createdAtTimezoneId": created_at_addr["timezoneId"],
            "createdAtCountry": created_at_addr["countryName"],

            "deviceName": str(device.get("name") or ""),
            "deviceLocale": str(device.get("locale") or ""),
            "devicePlatform": str(device.get("platform") or ""),
            "deviceAppVersion": str(device.get("appVersion") or ""),
            "deviceTimezoneId": str(device.get("timezoneId") or ""),
            "deviceConnectionType": str(device.get("connectionType") or ""),
            "deviceWorkflowVersion": str(device.get("workflowVersion") or ""),

            "isTablet": bool(mobile.get("isTablet")) if mobile.get("isTablet") is not None else False,
            "osVersion": str(mobile.get("osVersion") or ""),

            "detailsJson": details_json,
            "outputMappingsJson": output_mappings_json,
            "associationsJson": associations_json,

            "extractedAtUtc": extracted_at
        })

    return rows

# =========================
# EXPLICIT SCHEMAS
# =========================
checkin_header_schema = StructType([
    StructField("entityId", StringType(), False),
    StructField("shipmentNumber", StringType(), True),

    StructField("ownerUserId", StringType(), True),
    StructField("ownerUserName", StringType(), True),
    StructField("ownerFirmId", StringType(), True),
    StructField("ownerFirmName", StringType(), True),

    StructField("createdByUserId", StringType(), True),
    StructField("createdByUserName", StringType(), True),
    StructField("creationDateUtc", StringType(), True),
    StructField("modifiedByUserId", StringType(), True),
    StructField("modifiedByUserName", StringType(), True),
    StructField("modifiedDateUtc", StringType(), True),

    StructField("storyboardId", StringType(), True),
    StructField("workflowName", StringType(), True),
    StructField("workflowStatus", StringType(), True),

    StructField("visitStatus", StringType(), True),
    StructField("needsAttentionStatus", StringType(), True),

    StructField("visitRegion", StringType(), True),
    StructField("visitCity", StringType(), True),
    StructField("visitPostalCode", StringType(), True),
    StructField("visitStreet", StringType(), True),
    StructField("visitTimezoneId", StringType(), True),
    StructField("visitCountry", StringType(), True),

    StructField("appointmentRequestName", StringType(), True),
    StructField("appointmentResponseStatus", StringType(), True),
    StructField("noAppointment", BooleanType(), True),

    StructField("extractedAtUtc", TimestampType(), False),
])

checkin_events_schema = StructType([
    StructField("entityId", StringType(), False),
    StructField("shipmentNumber", StringType(), True),

    StructField("eventId", StringType(), True),
    StructField("eventType", StringType(), True),
    StructField("eventName", StringType(), True),

    StructField("taskId", StringType(), True),
    StructField("sceneId", StringType(), True),
    StructField("storyId", StringType(), True),

    StructField("createdByUserId", StringType(), True),
    StructField("createdByUserName", StringType(), True),

    StructField("creationDateUtc", StringType(), True),
    StructField("processedDateUtc", StringType(), True),

    StructField("createdAtRegion", StringType(), True),
    StructField("createdAtCity", StringType(), True),
    StructField("createdAtPostalCode", StringType(), True),
    StructField("createdAtStreet", StringType(), True),
    StructField("createdAtTimezoneId", StringType(), True),
    StructField("createdAtCountry", StringType(), True),

    StructField("deviceName", StringType(), True),
    StructField("deviceLocale", StringType(), True),
    StructField("devicePlatform", StringType(), True),
    StructField("deviceAppVersion", StringType(), True),
    StructField("deviceTimezoneId", StringType(), True),
    StructField("deviceConnectionType", StringType(), True),
    StructField("deviceWorkflowVersion", StringType(), True),

    StructField("isTablet", BooleanType(), True),
    StructField("osVersion", StringType(), True),

    StructField("detailsJson", StringType(), True),
    StructField("outputMappingsJson", StringType(), True),
    StructField("associationsJson", StringType(), True),

    StructField("extractedAtUtc", TimestampType(), False),
])

checkin_raw_schema = StructType([
    StructField("entityId", StringType(), False),
    StructField("shipmentNumber", StringType(), True),
    StructField("creationDateUtc", StringType(), True),
    StructField("modifiedDateUtc", StringType(), True),
    StructField("rawJson", StringType(), True),
    StructField("extractedAtUtc", TimestampType(), False),
])

# =========================
# RUN
# =========================
print(f"Fetching up to {MAX_ENTITIES} Check-In entity IDs...")
entity_ids = fetch_first_n_ids(n=MAX_ENTITIES, page_size=PAGE_SIZE)
print(f"Found {len(entity_ids)} IDs")

if not entity_ids:
    raise SystemExit("Zero IDs returned. Token/mixin access issue.")

extracted_at = now_utc_ts()

header_rows = []
event_rows  = []
raw_rows    = []

print("Fetching full JSON records (GET /entities/records/{id}) and parsing...")
for idx, eid in enumerate(entity_ids, start=1):
    ent = get_record(eid)

    header_rows.append(parse_checkin_header(ent, extracted_at))
    raw_rows.append(parse_checkin_raw(ent, extracted_at))
    event_rows.extend(parse_checkin_events(ent, extracted_at))

    if idx % 50 == 0:
        print(f"  parsed {idx}/{len(entity_ids)}")
    time.sleep(SLEEP_BETWEEN_GETS)

df_header = spark.createDataFrame(header_rows, schema=checkin_header_schema)
df_events = spark.createDataFrame(event_rows,  schema=checkin_events_schema)
df_raw    = spark.createDataFrame(raw_rows,    schema=checkin_raw_schema)

print("Header rows:", df_header.count())
print("Event rows:", df_events.count())
print("Raw rows:", df_raw.count())

# =========================
# WRITE (overwrite tables to avoid schema mismatch pain)
# =========================
spark.sql(f"DROP TABLE IF EXISTS {TBL_CHECKIN_HEADER}")
spark.sql(f"DROP TABLE IF EXISTS {TBL_CHECKIN_EVENTS}")
spark.sql(f"DROP TABLE IF EXISTS {TBL_CHECKIN_RAW}")

df_header.write.format("delta").mode("overwrite").option("overwriteSchema","true").saveAsTable(TBL_CHECKIN_HEADER)
df_events.write.format("delta").mode("overwrite").option("overwriteSchema","true").saveAsTable(TBL_CHECKIN_EVENTS)
df_raw.write.format("delta").mode("overwrite").option("overwriteSchema","true").saveAsTable(TBL_CHECKIN_RAW)

print(f"Loaded: {TBL_CHECKIN_HEADER}, {TBL_CHECKIN_EVENTS}, {TBL_CHECKIN_RAW}")

# Quick sanity: show a few shipment numbers + workflow
df_header.select("entityId","shipmentNumber","workflowStatus","visitStatus","creationDateUtc").show(20, truncate=False)


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

import json
import requests
import pandas as pd
from datetime import datetime, timezone

TOKEN = "6e3410b8a276520af92bb4712563f9ab"
ENTITY_ID = "4b9c5324-8d2e-4632-b93b-0ff1d5b60f9e"
BASE = "https://api.withvector.com/1.0"

def jget(d, path, default=None):
    cur = d
    for p in path.split("."):
        if isinstance(cur, dict) and p in cur:
            cur = cur[p]
        else:
            return default
    return cur

def pick_address(addr):
    if not isinstance(addr, dict):
        return {}
    return {
        "region": addr.get("region"),
        "locality": addr.get("locality"),
        "postalCode": addr.get("postalCode"),
        "streetAddress": addr.get("streetAddress"),
        "timezoneId": addr.get("timezoneId"),
        "countryName": addr.get("countryName"),
    }

def mixin_ids(entity):
    out = []
    for m in (jget(entity, "mixins.active", []) or []):
        if isinstance(m, dict) and m.get("entityId"):
            out.append(m["entityId"])
    return out

def best_main_doc_uri(entity):
    agg = jget(entity, "document.attachments.aggregate.uri")
    if agg:
        return agg
    files = jget(entity, "document.attachments.files", []) or []
    if files and isinstance(files[0], dict):
        return files[0].get("uri")
    return None

# ---- fetch
headers = {"Authorization": f"Bearer {TOKEN}", "Accept": "application/json"}
url = f"{BASE}/entities/records/{ENTITY_ID}"

resp = requests.get(url, headers=headers, timeout=60)
print("GET:", url)
print("Status:", resp.status_code)
resp.raise_for_status()

entity = resp.json()
extracted_at = datetime.now(timezone.utc).isoformat()

# ---- meta (1 row)
ship = entity.get("core_documents_shipment") or {}

carrier = jget(entity, "core_documents_shipment.carrier") or {}
driver  = jget(entity, "core_documents_shipment.driver") or {}
trailer = jget(entity, "core_documents_shipment.trailer") or {}
facility = jget(entity, "core_documents_shipment.facility") or {}
origin_loc = jget(entity, "core_documents_shipment.originLocation") or {}
dest_loc   = jget(entity, "core_documents_shipment.destinationLocation") or {}

origin_addr   = pick_address(jget(origin_loc, "denormalizedProperties.location.address"))
dest_addr     = pick_address(jget(dest_loc, "denormalizedProperties.location.address"))
facility_addr = pick_address(jget(facility, "denormalizedProperties.location.address"))

meta_row = {
    "entityId": entity.get("uniqueId"),
    "documentName": jget(entity, "document.name"),
    "ownerFirmId": jget(entity, "owner.firm.entityId"),
    "ownerFirmName": jget(entity, "owner.firm.displayName"),
    "creationDate": entity.get("creationDate"),
    "modifiedDate": entity.get("modifiedDate"),
    "uploadDate": jget(entity, "document.uploadDate"),
    "mixinsActive": ";".join(mixin_ids(entity)),

    # shipment summary
    "shipmentNumber": jget(ship, "shipmentNumber"),
    "shipmentStatus": jget(ship, "shipmentStatus"),
    "shipmentDate": jget(ship, "shipmentDate"),
    "receiver": jget(ship, "receiver"),
    "proNumber": jget(ship, "identification.proNumber"),
    "truckNumber": jget(ship, "truckNumber"),
    "trailerNumber": jget(ship, "trailerNumber") or jget(ship, "pickupTrailerNumber"),
    "sealNumber": jget(ship, "seal.number"),

    # carrier
    "carrierId": carrier.get("entityId"),
    "carrierName": carrier.get("displayName"),
    "carrierScac": jget(carrier, "denormalizedProperties.carrier.scac"),
    "carrierLegalName": jget(carrier, "denormalizedProperties.business.legalName"),

    # driver
    "driverId": driver.get("entityId"),
    "driverName": driver.get("displayName"),
    "driverFirmId": jget(entity, "core_documents_shipment.driverFirm.entityId") or jget(driver, "denormalizedProperties.owner.firm.entityId"),
    "driverFirmName": jget(entity, "core_documents_shipment.driverFirm.displayName") or jget(driver, "denormalizedProperties.owner.firm.displayName"),

    # trailer entity
    "trailerEntityId": trailer.get("entityId"),
    "trailerDisplayName": trailer.get("displayName"),
    "trailerName": jget(trailer, "denormalizedProperties.core_yms_trailer.name"),
    "trailerStatus": jget(trailer, "denormalizedProperties.core_yms_trailer.status"),

    # facility
    "facilityId": facility.get("entityId"),
    "facilityName": facility.get("displayName"),
    "facilityRegion": facility_addr.get("region"),
    "facilityCity": facility_addr.get("locality"),
    "facilityPostalCode": facility_addr.get("postalCode"),
    "facilityStreet": facility_addr.get("streetAddress"),

    # origin
    "originLocationId": origin_loc.get("entityId"),
    "originLocationName": origin_loc.get("displayName"),
    "originRegion": origin_addr.get("region"),
    "originCity": origin_addr.get("locality"),
    "originPostalCode": origin_addr.get("postalCode"),
    "originStreet": origin_addr.get("streetAddress"),

    # destination
    "destinationLocationId": dest_loc.get("entityId"),
    "destinationLocationName": dest_loc.get("displayName"),
    "destinationRegion": dest_addr.get("region"),
    "destinationCity": dest_addr.get("locality"),
    "destinationPostalCode": dest_addr.get("postalCode"),
    "destinationStreet": dest_addr.get("streetAddress"),

    # signatures
    "driverSigned": jget(ship, "driverSigned"),
    "driverSignedDate": jget(ship, "driverSignature.signedDate"),
    "shipperSignedDate": jget(ship, "shipperSignature.signedDate"),
    "receiverSignedDate": jget(ship, "receiverSignature.signedDate"),

    # main doc link
    "bolAttachmentUri": best_main_doc_uri(entity),

    "extractedAt": extracted_at,
}

df_meta = pd.DataFrame([meta_row])

# ---- attachments (document.attachments only)
files = jget(entity, "document.attachments.files", []) or []
att_rows = []
for f in files:
    if not isinstance(f, dict):
        continue
    att_rows.append({
        "entityId": entity.get("uniqueId"),
        "documentName": jget(entity, "document.name"),
        "fileUniqueId": f.get("uniqueId"),
        "fileName": f.get("name"),
        "fileType": f.get("type"),
        "pages": f.get("pages"),
        "fileUri": f.get("uri"),
        "previewCount": len(f.get("preview", []) or []) if isinstance(f.get("preview"), list) else None,
        "aggregatePdfUri": jget(entity, "document.attachments.aggregate.uri"),
        "attachmentsVersion": jget(entity, "document.attachments.version"),
        "extractedAt": extracted_at
    })

df_attach = pd.DataFrame(att_rows)

# ---- show tables
print("\n=== META (1 row) ===")
display(df_meta)

print("\n=== ATTACHMENTS ===")
display(df_attach)


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

import requests, json

from notebookutils import mssparkutils

# --- Read secrets from Azure Key Vault ---
VECTOR_TOKEN = mssparkutils.credentials.getSecret(
    "https://keyvault-fabric2.vault.azure.net/",
    "VECTORTOKEN"
)
QUERY_ENDPOINT = "https://api.withvector.com/1.0/entities/query"

FIRM_ID = "8ccd57ef-16a5-4b54-acd3-926af17d7139"          # Fairlife
FAIRLIFE_SHIPMENT_DOC_MIXIN = "5a30a865-1353-4363-ac11-1248cb13e15d"

HEADERS = {
    "Authorization": f"Bearer {VECTOR_TOKEN}",
    "Content-Type": "application/json",
    "Accept": "application/json",
}

payload = {
    "filters": [
        {
            "type": "containsEdge",
            "path": "mixins.active",
            "values": [{"entityId": FAIRLIFE_SHIPMENT_DOC_MIXIN}],
        }
    ],
    "metadata": {
        "size": 10,
        "offset": 0,
        "shouldIncludeLeafEntities": True,
        "firmId": FIRM_ID,
    },
}

r = requests.post(QUERY_ENDPOINT, headers=HEADERS, json=payload, timeout=60)

if r.status_code >= 400:
    print("----- Vector QUERY ERROR payload -----")
    print(json.dumps(payload, indent=2))
    print("----- Vector QUERY ERROR response -----")
    try:
        print(json.dumps(r.json(), indent=2)[:4000])
    except Exception:
        print(r.text[:4000])
    r.raise_for_status()

resp = r.json()
children = resp.get("children", []) or []

uuids = [c.get("uniqueId") for c in children if c.get("uniqueId")]

print(f"Returned {len(uuids)} UUIDs:")
for u in uuids:
    print(u)


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

import requests, json

from notebookutils import mssparkutils

# --- Read secrets from Azure Key Vault ---
VECTOR_TOKEN = mssparkutils.credentials.getSecret(
    "https://keyvault-fabric2.vault.azure.net/",
    "VECTORTOKEN"
)
QUERY_ENDPOINT = "https://api.withvector.com/1.0/entities/query"

FIRM_ID = "8ccd57ef-16a5-4b54-acd3-926af17d7139"          # Fairlife
FAIRLIFE_SHIPMENT_DOC_MIXIN = "5a30a865-1353-4363-ac11-1248cb13e15d"

HEADERS = {
    "Authorization": f"Bearer {VECTOR_TOKEN}",
    "Content-Type": "application/json",
    "Accept": "application/json",
}

def run_probe(name, payload):
    print("\n" + "="*110)
    print(f"PROBE: {name}")
    print("Payload:")
    print(json.dumps(payload, indent=2))

    r = requests.post(QUERY_ENDPOINT, headers=HEADERS, json=payload, timeout=60)
    print(f"HTTP: {r.status_code}")

    # Print response (compact) even on 200 so we can see metadata / children shape
    try:
        resp = r.json()
    except Exception:
        print("Non-JSON response:")
        print(r.text[:2000])
        return

    top_keys = list(resp.keys())
    print("Top-level keys:", top_keys)

    md = resp.get("metadata", {}) or {}
    if md:
        print("metadata keys:", list(md.keys()))
        for k in ["totalEntityMatchCount", "totalChildrenCount"]:
            if k in md:
                print(f"{k}: {md.get(k)}")
    else:
        print("metadata: (none)")

    children = resp.get("children", []) or []
    print("returned children:", len(children))

    if children:
        c0 = children[0]
        print("first child keys:", list(c0.keys())[:20])
        print("first uniqueId:", c0.get("uniqueId"))
        print("first displayName:", c0.get("displayName"))
        print("first creationDate:", c0.get("creationDate"))
        # print first 5 IDs
        ids = [c.get("uniqueId") for c in children if c.get("uniqueId")]
        print("sample UUIDs:", ids[:5])

    if r.status_code >= 400:
        print("ERROR body:")
        print(json.dumps(resp, indent=2)[:4000])

# 1) Leaf only (this should return *something* if your token works)
payload_leaf_only = {
    "metadata": {
        "size": 10,
        "offset": 0,
        "shouldIncludeLeafEntities": True
    }
}

# 2) Leaf + firm scope in metadata (KNOWN to work in your earlier successful probe)
payload_leaf_firm = {
    "metadata": {
        "size": 10,
        "offset": 0,
        "shouldIncludeLeafEntities": True,
        "firmId": FIRM_ID
    }
}

# 3) Leaf + firm + Fairlife Shipment Document mixin (your target)
payload_leaf_firm_mixin = {
    "filters": [
        {
            "type": "containsEdge",
            "path": "mixins.active",
            "values": [{"entityId": FAIRLIFE_SHIPMENT_DOC_MIXIN}]
        }
    ],
    "metadata": {
        "size": 10,
        "offset": 0,
        "shouldIncludeLeafEntities": True,
        "firmId": FIRM_ID
    }
}

# 4) Same as #3 but using firmIds array (also worked in your earlier probe)
payload_leaf_firmIds_mixin = {
    "filters": [
        {
            "type": "containsEdge",
            "path": "mixins.active",
            "values": [{"entityId": FAIRLIFE_SHIPMENT_DOC_MIXIN}]
        }
    ],
    "metadata": {
        "size": 10,
        "offset": 0,
        "shouldIncludeLeafEntities": True,
        "firmIds": [FIRM_ID]
    }
}

run_probe("1) shouldIncludeLeafEntities only", payload_leaf_only)
run_probe("2) leaf + firmId", payload_leaf_firm)
run_probe("3) leaf + firmId + Fairlife mixin", payload_leaf_firm_mixin)
run_probe("4) leaf + firmIds[] + Fairlife mixin", payload_leaf_firmIds_mixin)


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

# ==========================================
# VECTOR -> FABRIC LAKEHOUSE (BRONZE)
# Fairlife Shipment Document (BOL-style doc)
# Creates/appends 2 Delta tables:
#   1) bronze_vector_bol_header
#   2) bronze_vector_bol_files
# ==========================================

import os
import time
import json
import requests
from datetime import datetime, timezone

from pyspark.sql import Row
from pyspark.sql import functions as F
from pyspark.sql.types import (
    StructType, StructField,
    StringType, BooleanType, IntegerType,
    TimestampType
)

# -----------------------
# CONFIG
# -----------------------
BASE_URL = "https://api.withvector.com"
QUERY_ENDPOINT = f"{BASE_URL}/1.0/entities/query"
RECORD_ENDPOINT = f"{BASE_URL}/1.0/entities/records"

# Firm + mixin (Fairlife Shipment Document)
FIRM_ID = "8ccd57ef-16a5-4b54-acd3-926af17d7139"
FAIRLIFE_SHIPMENT_DOC_MIXIN = "5a30a865-1353-4363-ac11-1248cb13e15d"

# How many entities to fetch (leaf entities) and how many full records to hydrate
PAGE_SIZE = 250          # query page size (Vector supports pagination via offset)
MAX_ENTITIES = 1000      # pull first 1000

# Throttling
SLEEP_BETWEEN_RECORD_CALLS_SEC = 0.15

# Bronze table names (keep consistent)

# delta table names (Lakehouse)

TBL_HEADER = "vector_bol_meta_bronze"
TBL_FILES  = "vector_bol_attachments_bronze"

# Token: set in environment or paste here (not recommended)
VECTOR_TOKEN =  "6e3410b8a276520af92bb4712563f9ab"

HEADERS = {
    "Authorization": f"Bearer {VECTOR_TOKEN}",
    "Content-Type": "application/json",
    "Accept": "application/json"
}

# -----------------------
# Helpers
# -----------------------
def iso_to_ts(iso_str: str):
    """Return Python datetime (UTC) or None."""
    if not iso_str:
        return None
    try:
        # Handles "2025-12-15T16:26:16.934Z"
        if iso_str.endswith("Z"):
            iso_str = iso_str.replace("Z", "+00:00")
        return datetime.fromisoformat(iso_str).astimezone(timezone.utc).replace(tzinfo=None)
    except Exception:
        return None

def jget(obj, path, default=None):
    """Safe deep-get with dot path, returns default if missing."""
    cur = obj
    for part in path.split("."):
        if cur is None:
            return default
        if isinstance(cur, dict):
            cur = cur.get(part, None)
        else:
            return default
    return cur if cur is not None else default

def pick_address(addr_obj):
    """Return normalized address dict (strings), even if missing."""
    addr_obj = addr_obj or {}
    return {
        "region": str(addr_obj.get("region")) if addr_obj.get("region") is not None else None,
        "locality": str(addr_obj.get("locality")) if addr_obj.get("locality") is not None else None,
        "postalCode": str(addr_obj.get("postalCode")) if addr_obj.get("postalCode") is not None else None,
        "streetAddress": str(addr_obj.get("streetAddress")) if addr_obj.get("streetAddress") is not None else None,
        "countryName": str(addr_obj.get("countryName")) if addr_obj.get("countryName") is not None else None,
        "timezoneId": str(addr_obj.get("timezoneId")) if addr_obj.get("timezoneId") is not None else None,
    }

def list_mixins(entity_json):
    """Return list of (displayName, entityId) tuples."""
    out = []
    active = jget(entity_json, "mixins.active", []) or []
    for m in active:
        out.append((m.get("displayName"), m.get("entityId")))
    return out

def best_main_doc_uri(entity_json):
    """
    Prefer document.attachments.aggregate.uri if present,
    else first document.attachments.files[0].uri
    """
    agg_uri = jget(entity_json, "document.attachments.aggregate.uri")
    if agg_uri:
        return agg_uri
    files = jget(entity_json, "document.attachments.files", []) or []
    if files and isinstance(files, list):
        u = files[0].get("uri")
        return u
    return None

def post_query(offset: int, size: int):
    payload = {
        "filters": [
            {
                "type": "containsEdge",
                "path": "mixins.active",
                "values": [{"entityId": FAIRLIFE_SHIPMENT_DOC_MIXIN}]
            }
        ],
        "metadata": {
            "size": size,
            "offset": offset,
            "shouldIncludeLeafEntities": True,
            "firmId": FIRM_ID
        }
    }
    r = requests.post(QUERY_ENDPOINT, headers=HEADERS, data=json.dumps(payload), timeout=60)
    r.raise_for_status()
    return r.json()

def get_record(unique_id: str):
    r = requests.get(f"{RECORD_ENDPOINT}/{unique_id}", headers=HEADERS, timeout=60)
    r.raise_for_status()
    return r.json()

# -----------------------
# Spark schemas (explicit to avoid inference errors)
# -----------------------
header_schema = StructType([
    StructField("vectorEntityId", StringType(), False),
    StructField("documentName", StringType(), True),
    StructField("creationDateUtc", TimestampType(), True),
    StructField("modifiedDateUtc", TimestampType(), True),
    StructField("uploadDateUtc", TimestampType(), True),

    StructField("ownerFirmId", StringType(), True),
    StructField("ownerFirmName", StringType(), True),

    # shipment summary (core_documents_shipment)
    StructField("shipmentNumber", StringType(), True),
    StructField("shipmentStatus", StringType(), True),
    StructField("shipmentDateUtc", TimestampType(), True),
    StructField("receiver", StringType(), True),
    StructField("receiverId", StringType(), True),
    StructField("bolNumber", StringType(), True),
    StructField("proNumber", StringType(), True),
    StructField("truckNumber", StringType(), True),
    StructField("trailerNumber", StringType(), True),
    StructField("sealNumber", StringType(), True),

    # carrier
    StructField("carrierId", StringType(), True),
    StructField("carrierName", StringType(), True),
    StructField("carrierScac", StringType(), True),
    StructField("carrierLegalName", StringType(), True),

    # driver
    StructField("driverId", StringType(), True),
    StructField("driverName", StringType(), True),
    StructField("driverFirmId", StringType(), True),
    StructField("driverFirmName", StringType(), True),

    # trailer entity
    StructField("trailerEntityId", StringType(), True),
    StructField("trailerDisplayName", StringType(), True),
    StructField("trailerName", StringType(), True),
    StructField("trailerStatus", StringType(), True),

    # origin location
    StructField("originLocationId", StringType(), True),
    StructField("originLocationName", StringType(), True),
    StructField("originRegion", StringType(), True),
    StructField("originCity", StringType(), True),
    StructField("originPostalCode", StringType(), True),
    StructField("originStreet", StringType(), True),

    # destination location
    StructField("destinationLocationId", StringType(), True),
    StructField("destinationLocationName", StringType(), True),
    StructField("destinationRegion", StringType(), True),
    StructField("destinationCity", StringType(), True),
    StructField("destinationPostalCode", StringType(), True),
    StructField("destinationStreet", StringType(), True),

    # facility (often same as origin but keep it)
    StructField("facilityId", StringType(), True),
    StructField("facilityName", StringType(), True),
    StructField("facilityRegion", StringType(), True),
    StructField("facilityCity", StringType(), True),
    StructField("facilityPostalCode", StringType(), True),
    StructField("facilityStreet", StringType(), True),

    # signatures
    StructField("driverSigned", BooleanType(), True),
    StructField("driverSignedDateUtc", TimestampType(), True),
    StructField("shipperSignedDateUtc", TimestampType(), True),
    StructField("receiverSignedDateUtc", TimestampType(), True),

    # main doc link
    StructField("bolAttachmentUri", StringType(), True),

    # lineage
    StructField("mixinsActive", StringType(), True),   # store as JSON string
    StructField("extractedAtUtc", TimestampType(), False)
])

files_schema = StructType([
    StructField("vectorEntityId", StringType(), False),
    StructField("fileUniqueId", StringType(), True),
    StructField("fileName", StringType(), True),
    StructField("fileType", StringType(), True),
    StructField("pages", IntegerType(), True),
    StructField("uri", StringType(), True),

    StructField("isAggregate", BooleanType(), False),
    StructField("extractedAtUtc", TimestampType(), False)
])

# -----------------------
# 1) Pull first N entity IDs
# -----------------------
entity_ids = []
offset = 0
while len(entity_ids) < MAX_ENTITIES:
    size = min(PAGE_SIZE, MAX_ENTITIES - len(entity_ids))
    resp = post_query(offset=offset, size=size)
    children = resp.get("children", []) or []
    if not children:
        break

    # children elements usually have "uniqueId" and "displayName"
    for c in children:
        uid = c.get("uniqueId")
        if uid:
            entity_ids.append(uid)

    offset += len(children)
    if len(children) < size:
        break

print(f"Fetched entity IDs: {len(entity_ids)}")

if not entity_ids:
    raise SystemExit(
        "No entities returned. Verify:\n"
        "- Token scope/permissions\n"
        "- metadata.shouldIncludeLeafEntities=true\n"
        "- metadata.firmId set correctly\n"
        "- mixin id is correct\n"
    )

# -----------------------
# 2) Hydrate full records + build rows
# -----------------------
extracted_at = datetime.utcnow()

header_rows = []
file_rows = []

for i, uid in enumerate(entity_ids, 1):
    doc = get_record(uid)

    ship = jget(doc, "core_documents_shipment", {}) or {}
    carrier = jget(ship, "carrier", {}) or {}
    driver  = jget(ship, "driver", {}) or {}
    trailer = jget(ship, "trailer", {}) or {}
    facility = jget(ship, "facility", {}) or {}

    origin_loc = jget(ship, "originLocation", {}) or {}
    dest_loc   = jget(ship, "destinationLocation", {}) or {}

    origin_addr = pick_address(jget(origin_loc, "denormalizedProperties.location.address"))
    dest_addr   = pick_address(jget(dest_loc, "denormalizedProperties.location.address"))
    facility_addr = pick_address(jget(facility, "denormalizedProperties.location.address"))

    mixins = list_mixins(doc)

    header_rows.append(Row(
        vectorEntityId=str(jget(doc, "uniqueId")),
        documentName=jget(doc, "document.name"),
        creationDateUtc=iso_to_ts(jget(doc, "creationDate")),
        modifiedDateUtc=iso_to_ts(jget(doc, "modifiedDate")),
        uploadDateUtc=iso_to_ts(jget(doc, "document.uploadDate")),

        ownerFirmId=jget(doc, "owner.firm.entityId"),
        ownerFirmName=jget(doc, "owner.firm.displayName"),

        shipmentNumber=jget(ship, "shipmentNumber"),
        shipmentStatus=jget(ship, "shipmentStatus"),
        shipmentDateUtc=iso_to_ts(jget(ship, "shipmentDate")),
        receiver=jget(ship, "receiver"),
        receiverId=jget(ship, "receiverId"),
        bolNumber=jget(ship, "identification.bolNumber"),
        proNumber=jget(ship, "identification.proNumber"),
        truckNumber=jget(ship, "truckNumber"),
        trailerNumber=jget(ship, "trailerNumber") or jget(ship, "pickupTrailerNumber"),
        sealNumber=jget(ship, "seal.number"),

        carrierId=carrier.get("entityId"),
        carrierName=carrier.get("displayName"),
        carrierScac=jget(carrier, "denormalizedProperties.carrier.scac"),
        carrierLegalName=jget(carrier, "denormalizedProperties.business.legalName"),

        driverId=driver.get("entityId"),
        driverName=driver.get("displayName"),
        driverFirmId=jget(ship, "driverFirm.entityId") or jget(driver, "denormalizedProperties.owner.firm.entityId"),
        driverFirmName=jget(ship, "driverFirm.displayName") or jget(driver, "denormalizedProperties.owner.firm.displayName"),

        trailerEntityId=trailer.get("entityId"),
        trailerDisplayName=trailer.get("displayName"),
        trailerName=jget(trailer, "denormalizedProperties.core_yms_trailer.name"),
        trailerStatus=jget(trailer, "denormalizedProperties.core_yms_trailer.status"),

        originLocationId=origin_loc.get("entityId"),
        originLocationName=origin_loc.get("displayName"),
        originRegion=origin_addr.get("region"),
        originCity=origin_addr.get("locality"),
        originPostalCode=origin_addr.get("postalCode"),
        originStreet=origin_addr.get("streetAddress"),

        destinationLocationId=dest_loc.get("entityId"),
        destinationLocationName=dest_loc.get("displayName"),
        destinationRegion=dest_addr.get("region"),
        destinationCity=dest_addr.get("locality"),
        destinationPostalCode=dest_addr.get("postalCode"),
        destinationStreet=dest_addr.get("streetAddress"),

        facilityId=facility.get("entityId"),
        facilityName=facility.get("displayName"),
        facilityRegion=facility_addr.get("region"),
        facilityCity=facility_addr.get("locality"),
        facilityPostalCode=facility_addr.get("postalCode"),
        facilityStreet=facility_addr.get("streetAddress"),

        driverSigned=jget(ship, "driverSigned"),
        driverSignedDateUtc=iso_to_ts(jget(ship, "driverSignature.signedDate")),
        shipperSignedDateUtc=iso_to_ts(jget(ship, "shipperSignature.signedDate")),
        receiverSignedDateUtc=iso_to_ts(jget(ship, "receiverSignature.signedDate")),

        bolAttachmentUri=best_main_doc_uri(doc),

        mixinsActive=json.dumps(mixins, ensure_ascii=False),
        extractedAtUtc=extracted_at
    ))

    # files (document.attachments.files + aggregate)
    files = jget(doc, "document.attachments.files", []) or []
    for f in files:
        file_rows.append(Row(
            vectorEntityId=str(jget(doc, "uniqueId")),
            fileUniqueId=str(f.get("uniqueId")) if f.get("uniqueId") is not None else None,
            fileName=f.get("name"),
            fileType=f.get("type"),
            pages=int(f.get("pages")) if f.get("pages") is not None else None,
            uri=f.get("uri"),
            isAggregate=False,
            extractedAtUtc=extracted_at
        ))

    agg = jget(doc, "document.attachments.aggregate", {}) or {}
    if agg:
        file_rows.append(Row(
            vectorEntityId=str(jget(doc, "uniqueId")),
            fileUniqueId=str(agg.get("uniqueId")) if agg.get("uniqueId") is not None else None,
            fileName=agg.get("name"),
            fileType=agg.get("type"),
            pages=int(agg.get("pages")) if agg.get("pages") is not None else None,
            uri=agg.get("uri"),
            isAggregate=True,
            extractedAtUtc=extracted_at
        ))

    if i % 50 == 0:
        print(f"Hydrated {i}/{len(entity_ids)} records...")
    time.sleep(SLEEP_BETWEEN_RECORD_CALLS_SEC)

print(f"Built header rows: {len(header_rows)}")
print(f"Built file rows:   {len(file_rows)}")

# -----------------------
# 3) Create Spark DataFrames with explicit schema
# -----------------------
df_header = spark.createDataFrame(header_rows, schema=header_schema) if header_rows else spark.createDataFrame([], header_schema)
df_files  = spark.createDataFrame(file_rows,  schema=files_schema)  if file_rows  else spark.createDataFrame([], files_schema)

# Optional: de-dupe within this batch
df_header = df_header.dropDuplicates(["vectorEntityId"])
df_files  = df_files.dropDuplicates(["vectorEntityId", "fileUniqueId", "uri", "isAggregate"])

display(df_header.limit(20))
display(df_files.limit(20))

# -----------------------
# 4) Append to Lakehouse tables (create if missing)
# -----------------------
spark.sql(f"""
CREATE TABLE IF NOT EXISTS {TBL_HEADER}
USING DELTA
AS SELECT * FROM (SELECT 1 as _dummy) WHERE 1=0
""")
spark.sql(f"ALTER TABLE {TBL_HEADER} SET TBLPROPERTIES ('delta.columnMapping.mode'='name')")

spark.sql(f"""
CREATE TABLE IF NOT EXISTS {TBL_FILES}
USING DELTA
AS SELECT * FROM (SELECT 1 as _dummy) WHERE 1=0
""")
spark.sql(f"ALTER TABLE {TBL_FILES} SET TBLPROPERTIES ('delta.columnMapping.mode'='name')")

# Write (append) with schema evolution enabled
(
    df_header
    .write
    .format("delta")
    .mode("append")
    .option("mergeSchema", "true")
    .saveAsTable(TBL_HEADER)
)

(
    df_files
    .write
    .format("delta")
    .mode("append")
    .option("mergeSchema", "true")
    .saveAsTable(TBL_FILES)
)

print("✅ Done. Appended to:")
print(f" - {TBL_HEADER}")
print(f" - {TBL_FILES}")


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

from pyspark.sql import Row
from pyspark.sql.types import (
    StructType, StructField, StringType, BooleanType, LongType, DoubleType, TimestampType
)
from pyspark.sql.functions import current_timestamp
import requests
from datetime import datetime, timezone

# =============================
# CONFIG
# =============================
TOKEN = "6e3410b8a276520af92bb4712563f9ab"
BASE  = "https://api.withvector.com/1.0"

# Fairlife Shipment Document mixin
MIXIN = "5a30a865-1353-4363-ac11-1248cb13e15d"

# how many to bring
MAX_RECORDS = 1000
PAGE_SIZE   = 200  # Vector may allow 200-500; keep conservative

# delta table names (Lakehouse)
TBL_META = "vector_bol_meta_bronze"
TBL_FILES = "vector_bol_attachments_bronze"

headers = {"Authorization": f"Bearer {TOKEN}", "Content-Type": "application/json"}

# =============================
# HELPERS
# =============================
def jget(obj, path, default=None):
    if obj is None:
        return default
    cur = obj
    for part in path.split("."):
        if cur is None:
            return default
        if isinstance(cur, dict):
            cur = cur.get(part, default)
        else:
            return default
    return cur

def pick_address(addr):
    if not isinstance(addr, dict):
        return {}
    return {
        "region": addr.get("region"),
        "locality": addr.get("locality"),
        "postalCode": addr.get("postalCode"),
        "streetAddress": addr.get("streetAddress"),
        "timezoneId": addr.get("timezoneId"),
        "countryName": addr.get("countryName"),
        "latitude": jget(addr, "geolocation.latitude"),
        "longitude": jget(addr, "geolocation.longitude"),
    }

def best_main_doc_uri(entity):
    # Prefer aggregate pdf if present, else first attachment file uri
    agg_uri = jget(entity, "document.attachments.aggregate.uri")
    if agg_uri:
        return agg_uri
    files = jget(entity, "document.attachments.files", []) or []
    if files and isinstance(files, list):
        u = files[0].get("uri")
        if u:
            return u
    return None

def post_query(offset, size):
    payload = {
        "filters": [
            {
                "type": "containsEdge",
                "path": "mixins.active",
                "values": [{"entityId": MIXIN}]
            }
        ],
        "metadata": {
            "offset": offset,
            "size": size
        }
    }
    r = requests.post(f"{BASE}/entities/query", headers=headers, json=payload, timeout=60)
    r.raise_for_status()
    return r.json()

def parse_one(entity):
    ship = entity.get("core_documents_shipment") or {}

    carrier = ship.get("carrier") or {}
    driver  = ship.get("driver") or {}
    trailer = ship.get("trailer") or {}
    facility = ship.get("facility") or {}

    origin_loc = ship.get("originLocation") or {}
    dest_loc   = ship.get("destinationLocation") or {}

    origin_addr = pick_address(jget(origin_loc, "denormalizedProperties.location.address"))
    dest_addr   = pick_address(jget(dest_loc, "denormalizedProperties.location.address"))
    facility_addr = pick_address(jget(facility, "denormalizedProperties.location.address"))

    # META row
    meta = {
        "entityId": entity.get("uniqueId"),
        "documentName": jget(entity, "document.name"),
        "creationDate": entity.get("creationDate"),
        "modifiedDate": entity.get("modifiedDate"),

        "ownerFirmId": jget(entity, "owner.firm.entityId"),
        "ownerFirmName": jget(entity, "owner.firm.displayName"),

        "shipmentNumber": ship.get("shipmentNumber"),
        "pickupShipmentNumber": ship.get("pickupShipmentNumber"),
        "shipmentStatus": ship.get("shipmentStatus"),
        "shipmentDate": ship.get("shipmentDate"),
        "receiver": ship.get("receiver"),
        "receiverId": ship.get("receiverId"),
        "proNumber": jget(ship, "identification.proNumber"),
        "bolNumber": jget(ship, "identification.bolNumber"),

        "truckNumber": ship.get("truckNumber"),
        "trailerNumber": ship.get("trailerNumber") or ship.get("pickupTrailerNumber"),
        "sealNumber": jget(ship, "seal.number"),

        "carrierId": carrier.get("entityId"),
        "carrierName": carrier.get("displayName"),
        "carrierScac": jget(carrier, "denormalizedProperties.carrier.scac"),
        "carrierLegalName": jget(carrier, "denormalizedProperties.business.legalName"),

        "driverId": driver.get("entityId"),
        "driverName": driver.get("displayName"),
        "driverFirmId": jget(ship, "driverFirm.entityId") or jget(driver, "denormalizedProperties.owner.firm.entityId"),
        "driverFirmName": jget(ship, "driverFirm.displayName") or jget(driver, "denormalizedProperties.owner.firm.displayName"),

        "trailerEntityId": trailer.get("entityId"),
        "trailerDisplayName": trailer.get("displayName"),
        "trailerName": jget(trailer, "denormalizedProperties.core_yms_trailer.name"),
        "trailerStatus": jget(trailer, "denormalizedProperties.core_yms_trailer.status"),

        "facilityId": facility.get("entityId"),
        "facilityName": facility.get("displayName"),
        "facilityRegion": facility_addr.get("region"),
        "facilityCity": facility_addr.get("locality"),
        "facilityPostalCode": facility_addr.get("postalCode"),
        "facilityStreet": facility_addr.get("streetAddress"),
        "facilityTimezoneId": facility_addr.get("timezoneId"),

        "originLocationId": origin_loc.get("entityId"),
        "originLocationName": origin_loc.get("displayName"),
        "originRegion": origin_addr.get("region"),
        "originCity": origin_addr.get("locality"),
        "originPostalCode": origin_addr.get("postalCode"),
        "originStreet": origin_addr.get("streetAddress"),

        "destinationLocationId": dest_loc.get("entityId"),
        "destinationLocationName": dest_loc.get("displayName"),
        "destinationRegion": dest_addr.get("region"),
        "destinationCity": dest_addr.get("locality"),
        "destinationPostalCode": dest_addr.get("postalCode"),
        "destinationStreet": dest_addr.get("streetAddress"),

        "driverSigned": ship.get("driverSigned"),
        "driverSignedDate": jget(ship, "driverSignature.signedDate"),
        "shipperSignedDate": jget(ship, "shipperSignature.signedDate"),
        "receiverSignedDate": jget(ship, "receiverSignature.signedDate"),

        "bolAttachmentUri": best_main_doc_uri(entity),
        "extractedAt": datetime.now(timezone.utc).isoformat()
    }

    # ATTACHMENTS rows (flatten document + key embedded attachments we care about)
    rows = []

    def add_files(group_name, files_obj):
        if not isinstance(files_obj, dict):
            return
        files = files_obj.get("files") or []
        if not isinstance(files, list):
            return
        version = files_obj.get("version")
        agg = files_obj.get("aggregate") or {}
        agg_uri = agg.get("uri")
        agg_uid = agg.get("uniqueId")
        for f in files:
            rows.append({
                "entityId": entity.get("uniqueId"),
                "group": group_name,
                "fileUniqueId": f.get("uniqueId"),
                "fileName": f.get("name"),
                "fileType": f.get("type"),
                "filePages": f.get("pages"),
                "fileUri": f.get("uri"),
                "version": version,
                "aggregateUri": agg_uri,
                "aggregateUniqueId": agg_uid,
                "extractedAt": meta["extractedAt"]
            })

    add_files("document.attachments", jget(entity, "document.attachments"))
    add_files("core_documents_shipment.packingList", jget(entity, "core_documents_shipment.packingList"))
    add_files("core_documents_shipment.proofOfShipmentAttachment", jget(entity, "core_documents_shipment.proofOfShipmentAttachment"))
    add_files("core_documents_shipment.proofOfDeliveryAttachment", jget(entity, "core_documents_shipment.proofOfDeliveryAttachment"))

    return meta, rows

# =============================
# 1) FETCH FIRST N
# =============================
all_entities = []
offset = 0

while len(all_entities) < MAX_RECORDS:
    batch = post_query(offset=offset, size=PAGE_SIZE)
    children = batch.get("children") or []
    if not children:
        break

    # Vector returns {"children":[{"data":{...}}, ...]} style
    entities = [c.get("data") for c in children if isinstance(c, dict) and isinstance(c.get("data"), dict)]
    if not entities:
        break

    all_entities.extend(entities)
    offset += PAGE_SIZE

    if len(entities) < PAGE_SIZE:
        break

all_entities = all_entities[:MAX_RECORDS]
print(f"Fetched entities: {len(all_entities)}")

if not all_entities:
    raise SystemExit("No entities returned (even without date filter). Check token / mixin filter.")

# =============================
# 2) PARSE INTO 2 DATASETS
# =============================
meta_rows = []
file_rows = []

for e in all_entities:
    meta, files = parse_one(e)
    meta_rows.append(meta)
    file_rows.extend(files)

print("Meta rows:", len(meta_rows))
print("Attachment rows:", len(file_rows))

# =============================
# 3) BUILD DATAFRAMES WITH EXPLICIT SCHEMAS (avoids Spark infer errors)
# =============================
meta_schema = StructType([
    StructField("entityId", StringType(), True),
    StructField("documentName", StringType(), True),
    StructField("creationDate", StringType(), True),
    StructField("modifiedDate", StringType(), True),

    StructField("ownerFirmId", StringType(), True),
    StructField("ownerFirmName", StringType(), True),

    StructField("shipmentNumber", StringType(), True),
    StructField("pickupShipmentNumber", StringType(), True),
    StructField("shipmentStatus", StringType(), True),
    StructField("shipmentDate", StringType(), True),
    StructField("receiver", StringType(), True),
    StructField("receiverId", StringType(), True),
    StructField("proNumber", StringType(), True),
    StructField("bolNumber", StringType(), True),

    StructField("truckNumber", StringType(), True),
    StructField("trailerNumber", StringType(), True),
    StructField("sealNumber", StringType(), True),

    StructField("carrierId", StringType(), True),
    StructField("carrierName", StringType(), True),
    StructField("carrierScac", StringType(), True),
    StructField("carrierLegalName", StringType(), True),

    StructField("driverId", StringType(), True),
    StructField("driverName", StringType(), True),
    StructField("driverFirmId", StringType(), True),
    StructField("driverFirmName", StringType(), True),

    StructField("trailerEntityId", StringType(), True),
    StructField("trailerDisplayName", StringType(), True),
    StructField("trailerName", StringType(), True),
    StructField("trailerStatus", StringType(), True),

    StructField("facilityId", StringType(), True),
    StructField("facilityName", StringType(), True),
    StructField("facilityRegion", StringType(), True),
    StructField("facilityCity", StringType(), True),
    StructField("facilityPostalCode", StringType(), True),
    StructField("facilityStreet", StringType(), True),
    StructField("facilityTimezoneId", StringType(), True),

    StructField("originLocationId", StringType(), True),
    StructField("originLocationName", StringType(), True),
    StructField("originRegion", StringType(), True),
    StructField("originCity", StringType(), True),
    StructField("originPostalCode", StringType(), True),
    StructField("originStreet", StringType(), True),

    StructField("destinationLocationId", StringType(), True),
    StructField("destinationLocationName", StringType(), True),
    StructField("destinationRegion", StringType(), True),
    StructField("destinationCity", StringType(), True),
    StructField("destinationPostalCode", StringType(), True),
    StructField("destinationStreet", StringType(), True),

    StructField("driverSigned", BooleanType(), True),
    StructField("driverSignedDate", StringType(), True),
    StructField("shipperSignedDate", StringType(), True),
    StructField("receiverSignedDate", StringType(), True),

    StructField("bolAttachmentUri", StringType(), True),
    StructField("extractedAt", StringType(), True),
])

files_schema = StructType([
    StructField("entityId", StringType(), True),
    StructField("group", StringType(), True),
    StructField("fileUniqueId", StringType(), True),
    StructField("fileName", StringType(), True),
    StructField("fileType", StringType(), True),
    StructField("filePages", LongType(), True),
    StructField("fileUri", StringType(), True),
    StructField("version", LongType(), True),
    StructField("aggregateUri", StringType(), True),
    StructField("aggregateUniqueId", StringType(), True),
    StructField("extractedAt", StringType(), True),
])

df_meta = spark.createDataFrame(meta_rows, schema=meta_schema)
df_files = spark.createDataFrame(file_rows, schema=files_schema)

display(df_meta.limit(25))
display(df_files.limit(25))

# =============================
# 4) APPEND TO LAKEHOUSE TABLES (Delta)
# =============================
(df_meta
 .write
 .format("delta")
 .mode("append")
 .saveAsTable(TBL_META))

(df_files
 .write
 .format("delta")
 .mode("append")
 .saveAsTable(TBL_FILES))

print("✅ Appended to tables:")
print(" -", TBL_META)
print(" -", TBL_FILES)


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

import json
import requests
from datetime import datetime, timezone

# =========================
# CONFIG
# =========================
BASE = "https://api.withvector.com/1.0"
TOKEN = "6e3410b8a276520af92bb4712563f9ab"

# Mixins
MIXIN_DOCUMENT = "11111111-0000-0000-0000-000000000011"
MIXIN_FAIRLIFE_SHIPMENT_DOC = "5a30a865-1353-4363-ac11-1248cb13e15d"

# Pull more if you want
DEFAULT_SIZE = 10
TIMEOUT_SECONDS = 60

headers = {
    "Authorization": f"Bearer {TOKEN}",
    "Content-Type": "application/json",
    "Accept": "application/json",
}

def pretty(obj):
    return json.dumps(obj, indent=2, ensure_ascii=False)

def summarize_child(child):
    # child might be {"data":{...}} or might be direct entity dict depending on API
    data = child.get("data", child)
    return {
        "uniqueId": data.get("uniqueId"),
        "displayName": (data.get("precomputation") or {}).get("displayName"),
        "creationDate": data.get("creationDate"),
        "ownerFirm": ((data.get("owner") or {}).get("firm") or {}).get("displayName"),
        "activeMixins": [
            (m.get("displayName"), m.get("entityId"))
            for m in ((data.get("mixins") or {}).get("active") or [])
        ][:10]
    }

def run_query(name, payload):
    url = f"{BASE}/entities/query"
    print("\n" + "="*90)
    print(f"TEST: {name}")
    print("-"*90)
    print("POST", url)
    print("Payload:\n", pretty(payload))

    try:
        r = requests.post(url, headers=headers, json=payload, timeout=TIMEOUT_SECONDS)
    except Exception as e:
        print("REQUEST ERROR:", repr(e))
        return

    print("\nHTTP:", r.status_code)
    # Try parse JSON
    try:
        j = r.json()
    except Exception:
        print("Non-JSON response (first 1500 chars):")
        print(r.text[:1500])
        return

    children = j.get("children") or []
    meta = j.get("metadata") or {}

    print("Top-level keys:", list(j.keys()))
    print("metadata keys:", list(meta.keys()) if isinstance(meta, dict) else type(meta))
    print("returned children:", len(children))

    if len(children) > 0:
        print("\nFirst child summary:")
        print(pretty(summarize_child(children[0])))
    else:
        # print small snippet to see if there's an error message field
        print("\nResponse snippet (first 800 chars):")
        print(json.dumps(j, indent=2)[:800])

def main():
    # -------------------------
    # Probe 0: Can we query anything at all?
    # -------------------------
    run_query(
        "PROBE 0 - NO FILTERS (baseline)",
        {
            "metadata": {"size": DEFAULT_SIZE}
        }
    )

    # -------------------------
    # Probe 1: Document mixin only (common requirement)
    # -------------------------
    run_query(
        "PROBE 1 - FILTER: Document mixin (containsEdge on mixins.active)",
        {
            "filters": [{
                "type": "containsEdge",
                "path": "mixins.active",
                "values": [{"entityId": MIXIN_DOCUMENT}]
            }],
            "metadata": {"size": DEFAULT_SIZE}
        }
    )

    # -------------------------
    # Probe 2: Fairlife Shipment Document mixin only
    # -------------------------
    run_query(
        "PROBE 2 - FILTER: Fairlife Shipment Document mixin (containsEdge on mixins.active)",
        {
            "filters": [{
                "type": "containsEdge",
                "path": "mixins.active",
                "values": [{"entityId": MIXIN_FAIRLIFE_SHIPMENT_DOC}]
            }],
            "metadata": {"size": DEFAULT_SIZE}
        }
    )

    # -------------------------
    # Probe 3: AND: Document + Fairlife mixin (if supported)
    # -------------------------
    run_query(
        "PROBE 3 - FILTER: AND(Document + Fairlife mixin)",
        {
            "filters": [{
                "type": "and",
                "filters": [
                    {"type": "containsEdge", "path": "mixins.active", "values": [{"entityId": MIXIN_DOCUMENT}]},
                    {"type": "containsEdge", "path": "mixins.active", "values": [{"entityId": MIXIN_FAIRLIFE_SHIPMENT_DOC}]}
                ]
            }],
            "metadata": {"size": DEFAULT_SIZE}
        }
    )

    # -------------------------
    # Probe 4: Variant - values as strings (some APIs want this)
    # -------------------------
    run_query(
        "PROBE 4 - VARIANT: containsEdge values as strings",
        {
            "filters": [{
                "type": "containsEdge",
                "path": "mixins.active",
                "values": [MIXIN_FAIRLIFE_SHIPMENT_DOC]
            }],
            "metadata": {"size": DEFAULT_SIZE}
        }
    )

    # -------------------------
    # Probe 5: Variant - filter on mixins.active.entityId (common alternative)
    # -------------------------
    run_query(
        "PROBE 5 - VARIANT: contains on mixins.active.entityId",
        {
            "filters": [{
                "type": "contains",
                "path": "mixins.active.entityId",
                "value": MIXIN_FAIRLIFE_SHIPMENT_DOC
            }],
            "metadata": {"size": DEFAULT_SIZE}
        }
    )

    # -------------------------
    # Probe 6: Variant - hasEdge operator (sometimes used)
    # -------------------------
    run_query(
        "PROBE 6 - VARIANT: hasEdge",
        {
            "filters": [{
                "type": "hasEdge",
                "path": "mixins.active",
                "value": {"entityId": MIXIN_FAIRLIFE_SHIPMENT_DOC}
            }],
            "metadata": {"size": DEFAULT_SIZE}
        }
    )

    # -------------------------
    # Probe 7: If query returns nothing unless you include firmId context,
    #          try adding a firm filter (Fairlife firm from your sample).
    # -------------------------
    FAIRLIFE_FIRM_ID = "8ccd57ef-16a5-4b54-acd3-926af17d7139"
    run_query(
        "PROBE 7 - FILTER: Fairlife mixin + owner.firm.entityId (if firm scoping exists)",
        {
            "filters": [{
                "type": "and",
                "filters": [
                    {"type": "containsEdge", "path": "mixins.active", "values": [{"entityId": MIXIN_FAIRLIFE_SHIPMENT_DOC}]},
                    {"type": "equals", "path": "owner.firm.entityId", "value": FAIRLIFE_FIRM_ID}
                ]
            }],
            "metadata": {"size": DEFAULT_SIZE}
        }
    )

    # -------------------------
    # Probe 8: Sanity - fetch the known record by ID (should work already)
    # -------------------------
    print("\n" + "="*90)
    print("PROBE 8 - GET known BOL record by ID (sanity check token)")
    known_id = "4b9c5324-8d2e-4632-b93b-0ff1d5b60f9e"
    url = f"{BASE}/entities/records/{known_id}"
    print("GET", url)
    r = requests.get(url, headers=headers, timeout=TIMEOUT_SECONDS)
    print("HTTP:", r.status_code)
    try:
        j = r.json()
        print("uniqueId:", j.get("uniqueId"))
        print("creationDate:", j.get("creationDate"))
        print("document.name:", (j.get("document") or {}).get("name"))
        print("mixins.active:", [(m.get("displayName"), m.get("entityId")) for m in ((j.get("mixins") or {}).get("active") or [])])
    except Exception:
        print("Non-JSON response (first 800 chars):")
        print(r.text[:800])

if __name__ == "__main__":
    main()


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

import requests, json

from notebookutils import mssparkutils

# --- Read secrets from Azure Key Vault ---
VECTOR_TOKEN = mssparkutils.credentials.getSecret(
    "https://keyvault-fabric2.vault.azure.net/",
    "VECTORTOKEN"
)
QUERY_ENDPOINT = "https://api.withvector.com/1.0/entities/query"

FIRM_ID = "8ccd57ef-16a5-4b54-acd3-926af17d7139"          # Fairlife
FAIRLIFE_SHIPMENT_DOC_MIXIN = "5a30a865-1353-4363-ac11-1248cb13e15d"

HEADERS = {
    "Authorization": f"Bearer {VECTOR_TOKEN}",
    "Content-Type": "application/json",
    "Accept": "application/json",
}

payload = {
    "filters": [
        {
            "type": "containsEdge",
            "path": "mixins.active",
            "values": [{"entityId": FAIRLIFE_SHIPMENT_DOC_MIXIN}]
        }
    ],
    "metadata": {
        "size": 10,
        "offset": 0,
        "shouldIncludeLeafEntities": True,
        "firmId": FIRM_ID
    }
}

r = requests.post(QUERY_ENDPOINT, headers=HEADERS, json=payload, timeout=60)
r.raise_for_status()
resp = r.json()

children = resp.get("children", []) or []

# Extract from wrapper["data"]
rows = []
for w in children:
    d = (w or {}).get("data") or {}
    rows.append({
        "uniqueId": d.get("uniqueId"),
        "displayName": d.get("document", {}).get("name") or d.get("displayName"),
        "creationDate": d.get("creationDate"),
    })

print(f"Returned {len(rows)} Fairlife docs.")
uuids = [x["uniqueId"] for x in rows if x.get("uniqueId")]

print("\n10 UUIDs:")
for u in uuids:
    print(u)

# optional: show a compact table-like view
print("\nUUID | creationDate | name")
for x in rows:
    print(f"{x.get('uniqueId')} | {x.get('creationDate')} | {x.get('displayName')}")


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

import requests, json, time
from datetime import datetime, timezone

from pyspark.sql import Row
from pyspark.sql.types import (
    StructType, StructField, StringType, BooleanType, IntegerType, TimestampType
)

# =========================
# CONFIG
# =========================
from notebookutils import mssparkutils

# --- Read secrets from Azure Key Vault ---
VECTOR_TOKEN = mssparkutils.credentials.getSecret(
    "https://keyvault-fabric2.vault.azure.net/",
    "VECTORTOKEN"
)

QUERY_ENDPOINT  = "https://api.withvector.com/1.0/entities/query"
RECORD_ENDPOINT = "https://api.withvector.com/1.0/entities/records"

FIRM_ID = "8ccd57ef-16a5-4b54-acd3-926af17d7139"  # Fairlife
FAIRLIFE_SHIPMENT_DOC_MIXIN = "5a30a865-1353-4363-ac11-1248cb13e15d"

TBL_HEADER = "vector_bol_meta_bronze"
TBL_FILES  = "vector_bol_attachments_bronze"

MAX_ENTITIES = 500        # adjust
PAGE_SIZE    = 50         # keep modest (Vector can get picky)
SLEEP_BETWEEN_GETS = 0.15

HEADERS = {
    "Authorization": f"Bearer {VECTOR_TOKEN}",
    "Content-Type": "application/json",
    "Accept": "application/json",
}

# =========================
# HELPERS
# =========================
def jget(obj, path, default=None):
    """Safe nested getter using dot paths."""
    cur = obj
    for p in path.split("."):
        if cur is None:
            return default
        if isinstance(cur, dict):
            cur = cur.get(p)
        else:
            return default
    return cur if cur is not None else default

def pick_address(addr):
    if not isinstance(addr, dict):
        return {}
    return {
        "streetAddress": str(addr.get("streetAddress") or ""),
        "locality":      str(addr.get("locality") or ""),
        "region":        str(addr.get("region") or ""),
        "postalCode":    str(addr.get("postalCode") or ""),
    }

def now_utc_ts():
    return datetime.now(timezone.utc).replace(tzinfo=None)  # Spark TimestampType likes naive

def post_query(offset, size):
    payload = {
        "filters": [
            {
                "type": "containsEdge",
                "path": "mixins.active",
                "values": [{"entityId": FAIRLIFE_SHIPMENT_DOC_MIXIN}]
            }
        ],
        "metadata": {
            "size": size,
            "offset": offset,
            "shouldIncludeLeafEntities": True,
            "firmId": FIRM_ID
        }
    }
    r = requests.post(QUERY_ENDPOINT, headers=HEADERS, json=payload, timeout=60)
    if r.status_code != 200:
        # print useful debug
        print("----- Vector QUERY ERROR payload -----")
        print(json.dumps(payload, indent=2)[:4000])
        print("----- Vector QUERY ERROR response -----")
        try:
            print(json.dumps(r.json(), indent=2)[:4000])
        except Exception:
            print(r.text[:4000])
    r.raise_for_status()
    return r.json()

def fetch_first_n_ids(n=500, page_size=50):
    ids = []
    offset = 0
    while len(ids) < n:
        size = min(page_size, n - len(ids))
        resp = post_query(offset=offset, size=size)
        children = resp.get("children", []) or []
        if not children:
            break

        for c in children:
            uid = jget(c, "data.uniqueId")
            if uid:
                ids.append(uid)

        offset += size

        # stop early if API says fewer exist
        md = resp.get("metadata") or {}
        total = md.get("totalEntityMatchCount")
        if isinstance(total, int) and offset >= total:
            break

    # de-dupe while preserving order
    seen = set()
    out = []
    for x in ids:
        if x not in seen:
            out.append(x)
            seen.add(x)
    return out

def get_record(entity_id):
    r = requests.get(f"{RECORD_ENDPOINT}/{entity_id}", headers=HEADERS, timeout=60)
    r.raise_for_status()
    return r.json()

def collect_attachments(entity, extracted_at):
    """
    Returns list of dict rows for attachment table.
    """
    rows = []

    def add_files(group_name, files):
        if not isinstance(files, list):
            return
        for f in files:
            if not isinstance(f, dict):
                continue
            previews = f.get("preview") if isinstance(f.get("preview"), list) else []
            rows.append({
                "entityId": entity.get("uniqueId"),
                "attachmentGroup": group_name,
                "fileUniqueId": str(f.get("uniqueId") or ""),
                "fileName": str(f.get("name") or ""),
                "fileType": str(f.get("type") or ""),
                "filePages": int(f.get("pages") or 0),
                "fileUri": str(f.get("uri") or ""),
                "previewCount": int(len(previews)),
                "extractedAtUtc": extracted_at
            })

    # document.attachments.files
    add_files("document.attachments.files", jget(entity, "document.attachments.files", []))

    # core_documents_shipment attachments
    add_files("core_documents_shipment.packingList.files", jget(entity, "core_documents_shipment.packingList.files", []))
    add_files("core_documents_shipment.proofOfDeliveryAttachment.files", jget(entity, "core_documents_shipment.proofOfDeliveryAttachment.files", []))
    add_files("core_documents_shipment.proofOfShipmentAttachment.files", jget(entity, "core_documents_shipment.proofOfShipmentAttachment.files", []))

    return rows

def parse_header(entity, extracted_at):
    ship = entity.get("core_documents_shipment") or {}
    carrier = ship.get("carrier") or {}
    driver = ship.get("driver") or {}
    trailer = ship.get("trailer") or {}
    facility = ship.get("facility") or {}

    origin_loc = ship.get("originLocation") or {}
    dest_loc   = ship.get("destinationLocation") or {}

    origin_addr = pick_address(jget(origin_loc, "denormalizedProperties.location.address"))
    dest_addr   = pick_address(jget(dest_loc, "denormalizedProperties.location.address"))
    facility_addr = pick_address(jget(facility, "denormalizedProperties.location.address"))

    row = {
        "entityId": str(entity.get("uniqueId") or ""),
        "documentName": str(jget(entity, "document.name") or ""),
        "creationDateUtc": str(entity.get("creationDate") or ""),
        "modifiedDateUtc": str(entity.get("modifiedDate") or ""),

        "ownerFirmId": str(jget(entity, "owner.firm.entityId") or ""),
        "ownerFirmName": str(jget(entity, "owner.firm.displayName") or ""),
        "createdByUserId": str(jget(entity, "createdBy.entityId") or ""),
        "createdByUserName": str(jget(entity, "createdBy.displayName") or ""),
        "modifiedByUserId": str(jget(entity, "modifiedBy.entityId") or ""),
        "modifiedByUserName": str(jget(entity, "modifiedBy.displayName") or ""),

        "shipmentNumber": str(ship.get("shipmentNumber") or ""),
        "shipmentStatus": str(ship.get("shipmentStatus") or ""),
        "shipmentDateUtc": str(ship.get("shipmentDate") or ""),
        "receiver": str(ship.get("receiver") or ""),
        "receiverId": str(ship.get("receiverId") or ""),
        "bolNumber": str(jget(ship, "identification.bolNumber") or ""),
        "proNumber": str(jget(ship, "identification.proNumber") or ""),
        "truckNumber": str(ship.get("truckNumber") or ""),
        "trailerNumber": str(ship.get("trailerNumber") or ship.get("pickupTrailerNumber") or ""),
        "sealNumber": str(jget(ship, "seal.number") or ""),

        "carrierId": str(carrier.get("entityId") or ""),
        "carrierName": str(carrier.get("displayName") or ""),
        "carrierScac": str(jget(carrier, "denormalizedProperties.carrier.scac") or ""),
        "carrierLegalName": str(jget(carrier, "denormalizedProperties.business.legalName") or ""),

        "driverId": str(driver.get("entityId") or ""),
        "driverName": str(driver.get("displayName") or ""),
        "driverFirmId": str(jget(entity, "core_documents_shipment.driverFirm.entityId") or jget(driver, "denormalizedProperties.owner.firm.entityId") or ""),
        "driverFirmName": str(jget(entity, "core_documents_shipment.driverFirm.displayName") or jget(driver, "denormalizedProperties.owner.firm.displayName") or ""),

        "originLocationId": str(origin_loc.get("entityId") or ""),
        "originLocationName": str(origin_loc.get("displayName") or ""),
        "originStreet": origin_addr.get("streetAddress",""),
        "originCity": origin_addr.get("locality",""),
        "originRegion": origin_addr.get("region",""),
        "originPostalCode": origin_addr.get("postalCode",""),

        "destinationLocationId": str(dest_loc.get("entityId") or ""),
        "destinationLocationName": str(dest_loc.get("displayName") or ""),
        "destinationStreet": dest_addr.get("streetAddress",""),
        "destinationCity": dest_addr.get("locality",""),
        "destinationRegion": dest_addr.get("region",""),
        "destinationPostalCode": dest_addr.get("postalCode",""),

        "facilityId": str(facility.get("entityId") or ""),
        "facilityName": str(facility.get("displayName") or ""),
        "facilityStreet": facility_addr.get("streetAddress",""),
        "facilityCity": facility_addr.get("locality",""),
        "facilityRegion": facility_addr.get("region",""),
        "facilityPostalCode": facility_addr.get("postalCode",""),

        "driverSigned": bool(ship.get("driverSigned")) if ship.get("driverSigned") is not None else False,
        "driverSignedDateUtc": str(jget(ship, "driverSignature.signedDate") or ""),
        "shipperSignedDateUtc": str(jget(ship, "shipperSignature.signedDate") or ""),
        "receiverSignedDateUtc": str(jget(ship, "receiverSignature.signedDate") or ""),

        "hasOsd": bool(ship.get("hasOsd")) if ship.get("hasOsd") is not None else False,
        "isVoided": bool(ship.get("isVoided")) if ship.get("isVoided") is not None else False,

        "extractedAtUtc": extracted_at,
        "rawJson": json.dumps(entity)  # bronze: keep it
    }
    return row

# =========================
# EXPLICIT SCHEMAS (prevents Spark inference errors)
# =========================
header_schema = StructType([
    StructField("entityId", StringType(), False),
    StructField("documentName", StringType(), True),
    StructField("creationDateUtc", StringType(), True),
    StructField("modifiedDateUtc", StringType(), True),

    StructField("ownerFirmId", StringType(), True),
    StructField("ownerFirmName", StringType(), True),
    StructField("createdByUserId", StringType(), True),
    StructField("createdByUserName", StringType(), True),
    StructField("modifiedByUserId", StringType(), True),
    StructField("modifiedByUserName", StringType(), True),

    StructField("shipmentNumber", StringType(), True),
    StructField("shipmentStatus", StringType(), True),
    StructField("shipmentDateUtc", StringType(), True),
    StructField("receiver", StringType(), True),
    StructField("receiverId", StringType(), True),
    StructField("bolNumber", StringType(), True),
    StructField("proNumber", StringType(), True),
    StructField("truckNumber", StringType(), True),
    StructField("trailerNumber", StringType(), True),
    StructField("sealNumber", StringType(), True),

    StructField("carrierId", StringType(), True),
    StructField("carrierName", StringType(), True),
    StructField("carrierScac", StringType(), True),
    StructField("carrierLegalName", StringType(), True),

    StructField("driverId", StringType(), True),
    StructField("driverName", StringType(), True),
    StructField("driverFirmId", StringType(), True),
    StructField("driverFirmName", StringType(), True),

    StructField("originLocationId", StringType(), True),
    StructField("originLocationName", StringType(), True),
    StructField("originStreet", StringType(), True),
    StructField("originCity", StringType(), True),
    StructField("originRegion", StringType(), True),
    StructField("originPostalCode", StringType(), True),

    StructField("destinationLocationId", StringType(), True),
    StructField("destinationLocationName", StringType(), True),
    StructField("destinationStreet", StringType(), True),
    StructField("destinationCity", StringType(), True),
    StructField("destinationRegion", StringType(), True),
    StructField("destinationPostalCode", StringType(), True),

    StructField("facilityId", StringType(), True),
    StructField("facilityName", StringType(), True),
    StructField("facilityStreet", StringType(), True),
    StructField("facilityCity", StringType(), True),
    StructField("facilityRegion", StringType(), True),
    StructField("facilityPostalCode", StringType(), True),

    StructField("driverSigned", BooleanType(), True),
    StructField("driverSignedDateUtc", StringType(), True),
    StructField("shipperSignedDateUtc", StringType(), True),
    StructField("receiverSignedDateUtc", StringType(), True),

    StructField("hasOsd", BooleanType(), True),
    StructField("isVoided", BooleanType(), True),

    StructField("extractedAtUtc", TimestampType(), False),
    StructField("rawJson", StringType(), True),
])

files_schema = StructType([
    StructField("entityId", StringType(), False),
    StructField("attachmentGroup", StringType(), True),
    StructField("fileUniqueId", StringType(), True),
    StructField("fileName", StringType(), True),
    StructField("fileType", StringType(), True),
    StructField("filePages", IntegerType(), True),
    StructField("fileUri", StringType(), True),
    StructField("previewCount", IntegerType(), True),
    StructField("extractedAtUtc", TimestampType(), False),
])

# =========================
# RUN
# =========================
print(f"Fetching up to {MAX_ENTITIES} Fairlife Shipment Document IDs...")
entity_ids = fetch_first_n_ids(n=MAX_ENTITIES, page_size=PAGE_SIZE)
print(f"Found {len(entity_ids)} IDs")

if not entity_ids:
    raise SystemExit("No entities returned. Token/firmId/mixinId/tenant access issue.")

extracted_at = now_utc_ts()

header_rows = []
file_rows = []

print("Fetching full JSON records and parsing...")
for idx, eid in enumerate(entity_ids, start=1):
    ent = get_record(eid)
    header_rows.append(parse_header(ent, extracted_at))
    file_rows.extend(collect_attachments(ent, extracted_at))
    if idx % 25 == 0:
        print(f"  parsed {idx}/{len(entity_ids)}")
    time.sleep(SLEEP_BETWEEN_GETS)

df_header = spark.createDataFrame(header_rows, schema=header_schema)
df_files  = spark.createDataFrame(file_rows,  schema=files_schema)

print("Header rows:", df_header.count())
print("File rows:", df_files.count())

# =========================
# APPEND TO BRONZE TABLES
# =========================
# Create/append Delta tables in Lakehouse
df_header.write.format("delta").mode("append").saveAsTable(TBL_HEADER)
df_files.write.format("delta").mode("append").saveAsTable(TBL_FILES)

print(f"Appended to {TBL_HEADER} and {TBL_FILES}")


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark",
# META   "frozen": false,
# META   "editable": true
# META }

# CELL ********************

import requests, json, time
from datetime import datetime, timezone

from pyspark.sql.types import (
    StructType, StructField, StringType, BooleanType, IntegerType, TimestampType
)

# =========================
# CONFIG
# =========================
from notebookutils import mssparkutils

# --- Read secrets from Azure Key Vault ---
VECTOR_TOKEN = mssparkutils.credentials.getSecret(
    "https://keyvault-fabric2.vault.azure.net/",
    "VECTORTOKEN"
)

QUERY_ENDPOINT  = "https://api.withvector.com/1.0/entities/query"
RECORD_ENDPOINT = "https://api.withvector.com/1.0/entities/records"

FIRM_ID = "8ccd57ef-16a5-4b54-acd3-926af17d7139"  # Fairlife
FAIRLIFE_SHIPMENT_DOC_MIXIN = "5a30a865-1353-4363-ac11-1248cb13e15d"

TBL_HEADER = "vector_bol_meta_bronze"
TBL_FILES  = "vector_bol_attachments_bronze"

MAX_ENTITIES = 500
PAGE_SIZE    = 50
SLEEP_BETWEEN_GETS = 0.15

RESET_TABLES = True   # <-- set True once to rebuild; then set False

HEADERS = {
    "Authorization": f"Bearer {VECTOR_TOKEN}",
    "Content-Type": "application/json",
    "Accept": "application/json",
}

# =========================
# HELPERS
# =========================
def jget(obj, path, default=None):
    cur = obj
    for p in path.split("."):
        if cur is None:
            return default
        if isinstance(cur, dict):
            cur = cur.get(p)
        else:
            return default
    return cur if cur is not None else default

def pick_address(addr):
    if not isinstance(addr, dict):
        return {"streetAddress":"", "locality":"", "region":"", "postalCode":""}
    return {
        "streetAddress": str(addr.get("streetAddress") or ""),
        "locality":      str(addr.get("locality") or ""),
        "region":        str(addr.get("region") or ""),
        "postalCode":    str(addr.get("postalCode") or ""),
    }

def now_utc_ts():
    return datetime.now(timezone.utc).replace(tzinfo=None)

def post_query(offset, size):
    payload = {
        "filters": [
            {
                "type": "containsEdge",
                "path": "mixins.active",
                "values": [{"entityId": FAIRLIFE_SHIPMENT_DOC_MIXIN}]
            }
        ],
        "metadata": {
            "size": size,
            "offset": offset,
            "shouldIncludeLeafEntities": True,
            "firmId": FIRM_ID
        }
    }
    r = requests.post(QUERY_ENDPOINT, headers=HEADERS, json=payload, timeout=60)
    if r.status_code != 200:
        print("----- Vector QUERY ERROR payload -----")
        print(json.dumps(payload, indent=2)[:4000])
        print("----- Vector QUERY ERROR response -----")
        try:
            print(json.dumps(r.json(), indent=2)[:4000])
        except Exception:
            print(r.text[:4000])
    r.raise_for_status()
    return r.json()

def fetch_first_n_ids(n=500, page_size=50):
    ids = []
    offset = 0

    while len(ids) < n:
        size = min(page_size, n - len(ids))
        resp = post_query(offset=offset, size=size)
        children = resp.get("children", []) or []
        if not children:
            break

        for c in children:
            uid = jget(c, "data.uniqueId")
            if uid:
                ids.append(uid)

        offset += size

        md = resp.get("metadata") or {}
        total = md.get("totalEntityMatchCount")
        if isinstance(total, int) and offset >= total:
            break

    # de-dupe preserve order
    seen = set()
    out = []
    for x in ids:
        if x not in seen:
            out.append(x)
            seen.add(x)
    return out

def get_record(entity_id):
    r = requests.get(f"{RECORD_ENDPOINT}/{entity_id}", headers=HEADERS, timeout=60)
    r.raise_for_status()
    return r.json()

def collect_attachments(entity, extracted_at):
    rows = []

    def add_files(group_name, files):
        if not isinstance(files, list):
            return
        for f in files:
            if not isinstance(f, dict):
                continue
            previews = f.get("preview") if isinstance(f.get("preview"), list) else []
            rows.append({
                "entityId": str(entity.get("uniqueId") or ""),
                "attachmentGroup": group_name,
                "fileUniqueId": str(f.get("uniqueId") or ""),
                "fileName": str(f.get("name") or ""),
                "fileType": str(f.get("type") or ""),
                "filePages": int(f.get("pages") or 0),
                "fileUri": str(f.get("uri") or ""),
                "previewCount": int(len(previews)),
                "extractedAtUtc": extracted_at
            })

    add_files("document.attachments.files", jget(entity, "document.attachments.files", []))
    add_files("core_documents_shipment.packingList.files", jget(entity, "core_documents_shipment.packingList.files", []))
    add_files("core_documents_shipment.proofOfDeliveryAttachment.files", jget(entity, "core_documents_shipment.proofOfDeliveryAttachment.files", []))
    add_files("core_documents_shipment.proofOfShipmentAttachment.files", jget(entity, "core_documents_shipment.proofOfShipmentAttachment.files", []))

    return rows

def parse_header(entity, extracted_at):
    ship = entity.get("core_documents_shipment") or {}
    carrier = ship.get("carrier") or {}
    driver = ship.get("driver") or {}
    facility = ship.get("facility") or {}

    origin_loc = ship.get("originLocation") or {}
    dest_loc   = ship.get("destinationLocation") or {}

    origin_addr = pick_address(jget(origin_loc, "denormalizedProperties.location.address"))
    dest_addr   = pick_address(jget(dest_loc, "denormalizedProperties.location.address"))
    facility_addr = pick_address(jget(facility, "denormalizedProperties.location.address"))

    return {
        "entityId": str(entity.get("uniqueId") or ""),
        "documentName": str(jget(entity, "document.name") or ""),
        "creationDateUtc": str(entity.get("creationDate") or ""),
        "modifiedDateUtc": str(entity.get("modifiedDate") or ""),

        "ownerFirmId": str(jget(entity, "owner.firm.entityId") or ""),
        "ownerFirmName": str(jget(entity, "owner.firm.displayName") or ""),
        "createdByUserId": str(jget(entity, "createdBy.entityId") or ""),
        "createdByUserName": str(jget(entity, "createdBy.displayName") or ""),
        "modifiedByUserId": str(jget(entity, "modifiedBy.entityId") or ""),
        "modifiedByUserName": str(jget(entity, "modifiedBy.displayName") or ""),

        "shipmentNumber": str(ship.get("shipmentNumber") or ""),
        "shipmentStatus": str(ship.get("shipmentStatus") or ""),
        "shipmentDateUtc": str(ship.get("shipmentDate") or ""),
        "receiver": str(ship.get("receiver") or ""),
        "receiverId": str(ship.get("receiverId") or ""),
        "bolNumber": str(jget(ship, "identification.bolNumber") or ""),
        "proNumber": str(jget(ship, "identification.proNumber") or ""),
        "truckNumber": str(ship.get("truckNumber") or ""),
        "trailerNumber": str(ship.get("trailerNumber") or ship.get("pickupTrailerNumber") or ""),
        "sealNumber": str(jget(ship, "seal.number") or ""),

        "carrierId": str(carrier.get("entityId") or ""),
        "carrierName": str(carrier.get("displayName") or ""),
        "carrierScac": str(jget(carrier, "denormalizedProperties.carrier.scac") or ""),
        "carrierLegalName": str(jget(carrier, "denormalizedProperties.business.legalName") or ""),

        "driverId": str(driver.get("entityId") or ""),
        "driverName": str(driver.get("displayName") or ""),
        "driverFirmId": str(jget(entity, "core_documents_shipment.driverFirm.entityId") or jget(driver, "denormalizedProperties.owner.firm.entityId") or ""),
        "driverFirmName": str(jget(entity, "core_documents_shipment.driverFirm.displayName") or jget(driver, "denormalizedProperties.owner.firm.displayName") or ""),

        "originLocationId": str(origin_loc.get("entityId") or ""),
        "originLocationName": str(origin_loc.get("displayName") or ""),
        "originStreet": origin_addr.get("streetAddress",""),
        "originCity": origin_addr.get("locality",""),
        "originRegion": origin_addr.get("region",""),
        "originPostalCode": origin_addr.get("postalCode",""),

        "destinationLocationId": str(dest_loc.get("entityId") or ""),
        "destinationLocationName": str(dest_loc.get("displayName") or ""),
        "destinationStreet": dest_addr.get("streetAddress",""),
        "destinationCity": dest_addr.get("locality",""),
        "destinationRegion": dest_addr.get("region",""),
        "destinationPostalCode": dest_addr.get("postalCode",""),

        "facilityId": str(facility.get("entityId") or ""),
        "facilityName": str(facility.get("displayName") or ""),
        "facilityStreet": facility_addr.get("streetAddress",""),
        "facilityCity": facility_addr.get("locality",""),
        "facilityRegion": facility_addr.get("region",""),
        "facilityPostalCode": facility_addr.get("postalCode",""),

        "driverSigned": bool(ship.get("driverSigned")) if ship.get("driverSigned") is not None else False,
        "driverSignedDateUtc": str(jget(ship, "driverSignature.signedDate") or ""),
        "shipperSignedDateUtc": str(jget(ship, "shipperSignature.signedDate") or ""),
        "receiverSignedDateUtc": str(jget(ship, "receiverSignature.signedDate") or ""),

        "hasOsd": bool(ship.get("hasOsd")) if ship.get("hasOsd") is not None else False,
        "isVoided": bool(ship.get("isVoided")) if ship.get("isVoided") is not None else False,

        "extractedAtUtc": extracted_at,
        "rawJson": json.dumps(entity),
    }

# =========================
# EXPLICIT SCHEMAS
# =========================
header_schema = StructType([
    StructField("entityId", StringType(), False),
    StructField("documentName", StringType(), True),
    StructField("creationDateUtc", StringType(), True),
    StructField("modifiedDateUtc", StringType(), True),

    StructField("ownerFirmId", StringType(), True),
    StructField("ownerFirmName", StringType(), True),
    StructField("createdByUserId", StringType(), True),
    StructField("createdByUserName", StringType(), True),
    StructField("modifiedByUserId", StringType(), True),
    StructField("modifiedByUserName", StringType(), True),

    StructField("shipmentNumber", StringType(), True),
    StructField("shipmentStatus", StringType(), True),
    StructField("shipmentDateUtc", StringType(), True),
    StructField("receiver", StringType(), True),
    StructField("receiverId", StringType(), True),
    StructField("bolNumber", StringType(), True),
    StructField("proNumber", StringType(), True),
    StructField("truckNumber", StringType(), True),
    StructField("trailerNumber", StringType(), True),
    StructField("sealNumber", StringType(), True),

    StructField("carrierId", StringType(), True),
    StructField("carrierName", StringType(), True),
    StructField("carrierScac", StringType(), True),
    StructField("carrierLegalName", StringType(), True),

    StructField("driverId", StringType(), True),
    StructField("driverName", StringType(), True),
    StructField("driverFirmId", StringType(), True),
    StructField("driverFirmName", StringType(), True),

    StructField("originLocationId", StringType(), True),
    StructField("originLocationName", StringType(), True),
    StructField("originStreet", StringType(), True),
    StructField("originCity", StringType(), True),
    StructField("originRegion", StringType(), True),
    StructField("originPostalCode", StringType(), True),

    StructField("destinationLocationId", StringType(), True),
    StructField("destinationLocationName", StringType(), True),
    StructField("destinationStreet", StringType(), True),
    StructField("destinationCity", StringType(), True),
    StructField("destinationRegion", StringType(), True),
    StructField("destinationPostalCode", StringType(), True),

    StructField("facilityId", StringType(), True),
    StructField("facilityName", StringType(), True),
    StructField("facilityStreet", StringType(), True),
    StructField("facilityCity", StringType(), True),
    StructField("facilityRegion", StringType(), True),
    StructField("facilityPostalCode", StringType(), True),

    StructField("driverSigned", BooleanType(), True),
    StructField("driverSignedDateUtc", StringType(), True),
    StructField("shipperSignedDateUtc", StringType(), True),
    StructField("receiverSignedDateUtc", StringType(), True),

    StructField("hasOsd", BooleanType(), True),
    StructField("isVoided", BooleanType(), True),

    StructField("extractedAtUtc", TimestampType(), False),
    StructField("rawJson", StringType(), True),
])

files_schema = StructType([
    StructField("entityId", StringType(), False),
    StructField("attachmentGroup", StringType(), True),
    StructField("fileUniqueId", StringType(), True),
    StructField("fileName", StringType(), True),
    StructField("fileType", StringType(), True),
    StructField("filePages", IntegerType(), True),
    StructField("fileUri", StringType(), True),
    StructField("previewCount", IntegerType(), True),
    StructField("extractedAtUtc", TimestampType(), False),
])

# =========================
# RUN FETCH + PARSE
# =========================
print(f"Fetching up to {MAX_ENTITIES} Fairlife Shipment Document IDs...")
entity_ids = fetch_first_n_ids(n=MAX_ENTITIES, page_size=PAGE_SIZE)
print(f"Found {len(entity_ids)} IDs")
if not entity_ids:
    raise SystemExit("No entities returned. Check token/firmId/mixinId.")

extracted_at = now_utc_ts()
header_rows = []
file_rows = []

print("Fetching full JSON records and parsing...")
for i, eid in enumerate(entity_ids, start=1):
    ent = get_record(eid)
    header_rows.append(parse_header(ent, extracted_at))
    file_rows.extend(collect_attachments(ent, extracted_at))
    if i % 25 == 0:
        print(f"  parsed {i}/{len(entity_ids)}")
    time.sleep(SLEEP_BETWEEN_GETS)

df_header = spark.createDataFrame(header_rows, schema=header_schema)
df_files  = spark.createDataFrame(file_rows,  schema=files_schema)

print("Header rows:", df_header.count())
print("File rows:", df_files.count())

# =========================
# DROP + WRITE
# =========================
if RESET_TABLES:
    print("RESET_TABLES=True -> dropping existing tables (if any)...")
    spark.sql(f"DROP TABLE IF EXISTS {TBL_HEADER}")
    spark.sql(f"DROP TABLE IF EXISTS {TBL_FILES}")

    print("Writing fresh Delta tables...")
    df_header.write.format("delta").mode("overwrite").saveAsTable(TBL_HEADER)
    df_files.write.format("delta").mode("overwrite").saveAsTable(TBL_FILES)
else:
    print("Appending to existing Delta tables...")
    df_header.write.format("delta").mode("append").saveAsTable(TBL_HEADER)
    df_files.write.format("delta").mode("append").saveAsTable(TBL_FILES)

print(f"Done -> {TBL_HEADER}, {TBL_FILES}")


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

import json
import requests

BASE = "https://api.withvector.com/1.0"
TOKEN = "6e3410b8a276520af92bb4712563f9ab"

MIXIN_DOCUMENT = "11111111-0000-0000-0000-000000000011"
MIXIN_FAIRLIFE_SHIPMENT_DOC = "5a30a865-1353-4363-ac11-1248cb13e15d"
FAIRLIFE_FIRM_ID = "8ccd57ef-16a5-4b54-acd3-926af17d7139"

headers = {
    "Authorization": f"Bearer {TOKEN}",
    "Content-Type": "application/json",
    "Accept": "application/json",
}

def pretty(x): 
    return json.dumps(x, indent=2)

def summarize(child):
    data = child.get("data", child)
    return {
        "uniqueId": data.get("uniqueId"),
        "displayName": (data.get("precomputation") or {}).get("displayName"),
        "creationDate": data.get("creationDate"),
        "ownerFirm": ((data.get("owner") or {}).get("firm") or {}).get("displayName"),
        "mixins.active": [(m.get("displayName"), m.get("entityId")) for m in ((data.get("mixins") or {}).get("active") or [])]
    }

def post_query(name, payload):
    url = f"{BASE}/entities/query"
    print("\n" + "="*100)
    print("TEST:", name)
    print("POST:", url)
    print("Payload:\n", pretty(payload))

    r = requests.post(url, headers=headers, json=payload, timeout=60)
    print("HTTP:", r.status_code)

    try:
        j = r.json()
    except Exception:
        print("Non-JSON response (first 1200 chars):")
        print(r.text[:1200])
        return

    print("Top-level keys:", list(j.keys()))
    children = j.get("children") or []
    print("returned children:", len(children))

    if children:
        print("First child summary:\n", pretty(summarize(children[0])))
    else:
        print("Response snippet:\n", pretty(j)[:800])

def main():
    # Always include offset + size
    base_meta = {"size": 10, "offset": 0}

    # 0) Baseline (no filters)
    post_query(
        "PROBE 0 - NO FILTERS (baseline)",
        {"metadata": base_meta}
    )

    # 1) Document mixin only
    post_query(
        "PROBE 1 - Document mixin only",
        {
            "filters": [{
                "type": "containsEdge",
                "path": "mixins.active",
                "values": [{"entityId": MIXIN_DOCUMENT}]
            }],
            "metadata": base_meta
        }
    )

    # 2) Fairlife Shipment Document mixin only
    post_query(
        "PROBE 2 - Fairlife Shipment Document mixin only",
        {
            "filters": [{
                "type": "containsEdge",
                "path": "mixins.active",
                "values": [{"entityId": MIXIN_FAIRLIFE_SHIPMENT_DOC}]
            }],
            "metadata": base_meta
        }
    )

    # 3) AND(Document + Fairlife mixin)  ✅ FIXED SHAPE (filters, not filter)
    post_query(
        "PROBE 3 - AND(Document + Fairlife mixin)",
        {
            "filters": [{
                "type": "and",
                "filters": [
                    {
                        "type": "containsEdge",
                        "path": "mixins.active",
                        "values": [{"entityId": MIXIN_DOCUMENT}]
                    },
                    {
                        "type": "containsEdge",
                        "path": "mixins.active",
                        "values": [{"entityId": MIXIN_FAIRLIFE_SHIPMENT_DOC}]
                    }
                ]
            }],
            "metadata": base_meta
        }
    )

    # 4) AND(Document + Fairlife mixin + owner firm) (optional)
    post_query(
        "PROBE 4 - AND(Document + Fairlife mixin + owner.firm.entityId)",
        {
            "filters": [{
                "type": "and",
                "filters": [
                    {
                        "type": "containsEdge",
                        "path": "mixins.active",
                        "values": [{"entityId": MIXIN_DOCUMENT}]
                    },
                    {
                        "type": "containsEdge",
                        "path": "mixins.active",
                        "values": [{"entityId": MIXIN_FAIRLIFE_SHIPMENT_DOC}]
                    },
                    {
                        "type": "equals",
                        "path": "owner.firm.entityId",
                        "value": FAIRLIFE_FIRM_ID
                    }
                ]
            }],
            "metadata": base_meta
        }
    )

    # 5) Pagination sanity (offset 10)
    post_query(
        "PROBE 5 - Pagination offset 10 (no filters)",
        {"metadata": {"size": 10, "offset": 10}}
    )

if __name__ == "__main__":
    main()


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

import json
import requests

BASE = "https://api.withvector.com/1.0"
TOKEN = "6e3410b8a276520af92bb4712563f9ab"

MIXIN_DOCUMENT = "11111111-0000-0000-0000-000000000011"
MIXIN_FAIRLIFE_SHIPMENT_DOC = "5a30a865-1353-4363-ac11-1248cb13e15d"
FAIRLIFE_FIRM_ID = "8ccd57ef-16a5-4b54-acd3-926af17d7139"

headers = {
    "Authorization": f"Bearer {TOKEN}",
    "Content-Type": "application/json",
    "Accept": "application/json",
}

def pretty(x): 
    return json.dumps(x, indent=2)

def run_probe(name, payload):
    url = f"{BASE}/entities/query"
    print("\n" + "="*110)
    print("TEST:", name)
    print("POST:", url)
    print("Payload:\n", pretty(payload))

    r = requests.post(url, headers=headers, json=payload, timeout=60)
    print("HTTP:", r.status_code)

    try:
        j = r.json()
    except Exception:
        print("Non-JSON response:", r.text[:1200])
        return

    children = j.get("children") or []
    meta = j.get("metadata") or {}
    print("Top-level keys:", list(j.keys()))
    print("metadata keys:", list(meta.keys()) if isinstance(meta, dict) else type(meta))
    print("returned children:", len(children))

    if children:
        first = children[0].get("data", children[0])
        mixins = (first.get("mixins") or {}).get("active") or []
        print("First uniqueId:", first.get("uniqueId"))
        print("First displayName:", (first.get("precomputation") or {}).get("displayName"))
        print("First creationDate:", first.get("creationDate"))
        print("First mixins.active:", [(m.get("displayName"), m.get("entityId")) for m in mixins][:10])
    else:
        print("Response snippet:\n", pretty(j)[:800])

def contains_edge(mixin_id):
    return {
        "type": "containsEdge",
        "path": "mixins.active",
        "values": [{"entityId": mixin_id}]
    }

def equals(path, value):
    return {
        "type": "equals",
        "path": path,
        "value": value
    }

def main():
    # Common metadata base
    base_meta = {"size": 10, "offset": 0}

    # 0) Baseline
    run_probe("0 - Baseline (no filters)", {"metadata": base_meta})

    # 1) Baseline + include leaf entities
    run_probe("1 - Baseline + shouldIncludeLeafEntities:true",
              {"metadata": {**base_meta, "shouldIncludeLeafEntities": True}})

    # 2) Firm scope as FILTER (not metadata)
    run_probe("2 - owner.firm.entityId filter only",
              {"filters": [equals("owner.firm.entityId", FAIRLIFE_FIRM_ID)],
               "metadata": base_meta})

    # 3) Document mixin only
    run_probe("3 - Document mixin only",
              {"filters": [contains_edge(MIXIN_DOCUMENT)],
               "metadata": base_meta})

    # 4) Fairlife Shipment Document mixin only
    run_probe("4 - Fairlife Shipment Document mixin only",
              {"filters": [contains_edge(MIXIN_FAIRLIFE_SHIPMENT_DOC)],
               "metadata": base_meta})

    # 5) BOTH mixins as two filters (NO 'and' wrapper)  <-- this is the key test
    run_probe("5 - Two mixins as two filters (implicit AND?)",
              {"filters": [
                    contains_edge(MIXIN_DOCUMENT),
                    contains_edge(MIXIN_FAIRLIFE_SHIPMENT_DOC)
               ],
               "metadata": base_meta})

    # 6) Two mixins + firm filter (still no 'and' wrapper)
    run_probe("6 - Two mixins + firm filter (implicit AND)",
              {"filters": [
                    contains_edge(MIXIN_DOCUMENT),
                    contains_edge(MIXIN_FAIRLIFE_SHIPMENT_DOC),
                    equals("owner.firm.entityId", FAIRLIFE_FIRM_ID),
               ],
               "metadata": base_meta})

    # 7) Same as 6 but include leaf entities
    run_probe("7 - Two mixins + firm + shouldIncludeLeafEntities:true",
              {"filters": [
                    contains_edge(MIXIN_DOCUMENT),
                    contains_edge(MIXIN_FAIRLIFE_SHIPMENT_DOC),
                    equals("owner.firm.entityId", FAIRLIFE_FIRM_ID),
               ],
               "metadata": {**base_meta, "shouldIncludeLeafEntities": True}})

    # 8) Try firm scope in metadata (guessing common pattern)
    # If your API supports firm scoping this way, this often unlocks results.
    run_probe("8 - Firm scope in metadata (firmId) + leaf",
              {"filters": [
                    contains_edge(MIXIN_FAIRLIFE_SHIPMENT_DOC),
               ],
               "metadata": {**base_meta, "shouldIncludeLeafEntities": True, "firmId": FAIRLIFE_FIRM_ID}})

    run_probe("9 - Firm scope in metadata (firmIds array) + leaf",
              {"filters": [
                    contains_edge(MIXIN_FAIRLIFE_SHIPMENT_DOC),
               ],
               "metadata": {**base_meta, "shouldIncludeLeafEntities": True, "firmIds": [FAIRLIFE_FIRM_ID]}})

if __name__ == "__main__":
    main()


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

import requests
from datetime import datetime, timezone
from pyspark.sql import Row
from pyspark.sql.types import (
    StructType, StructField, StringType, BooleanType, IntegerType, DoubleType, TimestampType
)

# ============================================================
# CONFIG
# ============================================================
TOKEN = "6e3410b8a276520af92bb4712563f9ab"
BASE  = "https://api.withvector.com/1.0"

# Fairlife Shipment Document mixin (your focus)
FAIRLIFE_BOL_MIXIN = "5a30a865-1353-4363-ac11-1248cb13e15d"

# November 2025 UTC
START_DATE = "2025-11-01T00:00:00Z"
END_DATE   = "2025-11-30T23:59:59Z"

# Lakehouse tables
DB = "data_central_lh"
META_TABLE = f"{DB}.vector_bol_meta_bronze"
ATT_TABLE  = f"{DB}.vector_bol_attachments_bronze"

# ============================================================
# HELPERS
# ============================================================
def iso_to_ts(s):
    """Return python datetime or None; Spark will map it to TimestampType."""
    if not s:
        return None
    # Vector uses Z; normalize for fromisoformat
    try:
        return datetime.fromisoformat(s.replace("Z", "+00:00"))
    except Exception:
        return None

def jget(obj, path, default=None):
    """Safe nested getter with dotted paths (supports dict + list indices)."""
    if obj is None:
        return default
    cur = obj
    for part in path.split("."):
        if cur is None:
            return default
        if isinstance(cur, dict):
            cur = cur.get(part, None)
        elif isinstance(cur, list):
            # allow numeric index path segments
            try:
                idx = int(part)
                cur = cur[idx] if 0 <= idx < len(cur) else None
            except Exception:
                return default
        else:
            return default
    return default if cur is None else cur

def pick_address(addr_obj):
    """Return normalized address dict (strings + lat/long)."""
    if not isinstance(addr_obj, dict):
        return {
            "region": None, "locality": None, "postalCode": None, "streetAddress": None,
            "timezoneId": None, "countryName": None, "latitude": None, "longitude": None
        }
    geo = addr_obj.get("geolocation") or {}
    return {
        "region": addr_obj.get("region"),
        "locality": addr_obj.get("locality"),
        "postalCode": addr_obj.get("postalCode"),
        "streetAddress": addr_obj.get("streetAddress"),
        "timezoneId": addr_obj.get("timezoneId"),
        "countryName": addr_obj.get("countryName"),
        "latitude": geo.get("latitude"),
        "longitude": geo.get("longitude")
    }

def best_main_doc_uri(entity):
    """
    Prefer document.attachments.aggregate.uri if present.
    Otherwise use first file uri.
    """
    agg = jget(entity, "document.attachments.aggregate.uri")
    if agg:
        return agg
    files = jget(entity, "document.attachments.files", []) or []
    if files and isinstance(files, list):
        u = (files[0] or {}).get("uri")
        return u
    return None

def req(method, url, headers=None, json=None, timeout=60):
    r = requests.request(method, url, headers=headers, json=json, timeout=timeout)
    r.raise_for_status()
    return r

# ============================================================
# SCHEMAS (explicit to avoid Spark inference issues)
# ============================================================
meta_schema = StructType([
    StructField("entityId", StringType(), True),
    StructField("documentName", StringType(), True),

    StructField("ownerFirmId", StringType(), True),
    StructField("ownerFirmName", StringType(), True),

    # shipment summary
    StructField("shipmentNumber", StringType(), True),
    StructField("shipmentStatus", StringType(), True),
    StructField("shipmentDate", TimestampType(), True),
    StructField("receiver", StringType(), True),
    StructField("proNumber", StringType(), True),
    StructField("truckNumber", StringType(), True),
    StructField("trailerNumber", StringType(), True),
    StructField("sealNumber", StringType(), True),

    # carrier
    StructField("carrierId", StringType(), True),
    StructField("carrierName", StringType(), True),
    StructField("carrierScac", StringType(), True),
    StructField("carrierLegalName", StringType(), True),

    # driver
    StructField("driverId", StringType(), True),
    StructField("driverName", StringType(), True),
    StructField("driverFirmId", StringType(), True),
    StructField("driverFirmName", StringType(), True),

    # trailer
    StructField("trailerEntityId", StringType(), True),
    StructField("trailerDisplayName", StringType(), True),
    StructField("trailerName", StringType(), True),
    StructField("trailerStatus", StringType(), True),

    # facility address
    StructField("facilityId", StringType(), True),
    StructField("facilityName", StringType(), True),
    StructField("facilityRegion", StringType(), True),
    StructField("facilityCity", StringType(), True),
    StructField("facilityPostalCode", StringType(), True),
    StructField("facilityStreet", StringType(), True),

    # origin address
    StructField("originLocationId", StringType(), True),
    StructField("originLocationName", StringType(), True),
    StructField("originRegion", StringType(), True),
    StructField("originCity", StringType(), True),
    StructField("originPostalCode", StringType(), True),
    StructField("originStreet", StringType(), True),

    # destination address
    StructField("destinationLocationId", StringType(), True),
    StructField("destinationLocationName", StringType(), True),
    StructField("destinationRegion", StringType(), True),
    StructField("destinationCity", StringType(), True),
    StructField("destinationPostalCode", StringType(), True),
    StructField("destinationStreet", StringType(), True),

    # signatures
    StructField("driverSigned", BooleanType(), True),
    StructField("driverSignedDate", TimestampType(), True),
    StructField("shipperSignedDate", TimestampType(), True),
    StructField("receiverSignedDate", TimestampType(), True),

    # main doc uri
    StructField("bolAttachmentUri", StringType(), True),

    # timestamps
    StructField("creationDate", TimestampType(), True),
    StructField("modifiedDate", TimestampType(), True),
    StructField("extractedAt", TimestampType(), True),
])

attach_schema = StructType([
    StructField("entityId", StringType(), True),
    StructField("documentName", StringType(), True),

    StructField("attachmentGroup", StringType(), True),  # e.g., document.attachments / packingList / proofOfDeliveryAttachment
    StructField("fileUniqueId", StringType(), True),
    StructField("fileName", StringType(), True),
    StructField("fileType", StringType(), True),
    StructField("pages", IntegerType(), True),
    StructField("uri", StringType(), True),

    StructField("previewUri", StringType(), True),
    StructField("previewWidth", IntegerType(), True),
    StructField("previewHeight", IntegerType(), True),

    StructField("extractedAt", TimestampType(), True),
])

# ============================================================
# CREATE DB + TABLES (Delta) IF NOT EXISTS
# ============================================================
spark.sql(f"CREATE DATABASE IF NOT EXISTS {DB}")

spark.sql(f"""
CREATE TABLE IF NOT EXISTS {META_TABLE} (
  entityId STRING,
  documentName STRING,
  ownerFirmId STRING,
  ownerFirmName STRING,
  shipmentNumber STRING,
  shipmentStatus STRING,
  shipmentDate TIMESTAMP,
  receiver STRING,
  proNumber STRING,
  truckNumber STRING,
  trailerNumber STRING,
  sealNumber STRING,
  carrierId STRING,
  carrierName STRING,
  carrierScac STRING,
  carrierLegalName STRING,
  driverId STRING,
  driverName STRING,
  driverFirmId STRING,
  driverFirmName STRING,
  trailerEntityId STRING,
  trailerDisplayName STRING,
  trailerName STRING,
  trailerStatus STRING,
  facilityId STRING,
  facilityName STRING,
  facilityRegion STRING,
  facilityCity STRING,
  facilityPostalCode STRING,
  facilityStreet STRING,
  originLocationId STRING,
  originLocationName STRING,
  originRegion STRING,
  originCity STRING,
  originPostalCode STRING,
  originStreet STRING,
  destinationLocationId STRING,
  destinationLocationName STRING,
  destinationRegion STRING,
  destinationCity STRING,
  destinationPostalCode STRING,
  destinationStreet STRING,
  driverSigned BOOLEAN,
  driverSignedDate TIMESTAMP,
  shipperSignedDate TIMESTAMP,
  receiverSignedDate TIMESTAMP,
  bolAttachmentUri STRING,
  creationDate TIMESTAMP,
  modifiedDate TIMESTAMP,
  extractedAt TIMESTAMP
)
USING DELTA
""")

spark.sql(f"""
CREATE TABLE IF NOT EXISTS {ATT_TABLE} (
  entityId STRING,
  documentName STRING,
  attachmentGroup STRING,
  fileUniqueId STRING,
  fileName STRING,
  fileType STRING,
  pages INT,
  uri STRING,
  previewUri STRING,
  previewWidth INT,
  previewHeight INT,
  extractedAt TIMESTAMP
)
USING DELTA
""")

# ============================================================
# QUERY: find all entity IDs for Nov 2025 (Fairlife BOL mixin)
# ============================================================
headers = {"Authorization": f"Bearer {TOKEN}", "Content-Type": "application/json"}

search_payload = {
    "filters": [
        {
            "type": "containsEdge",
            "path": "mixins.active",
            "values": [{"entityId": FAIRLIFE_BOL_MIXIN}]
        },
        {
            "type": "range",
            "path": "creationDate",
            "gte": START_DATE,
            "lte": END_DATE
        }
    ],
    "metadata": {
        "size": 200,
        "offset": 0
    }
}

entity_ids = []
offset = 0

while True:
    search_payload["metadata"]["offset"] = offset
    resp = req("POST", f"{BASE}/entities/query", headers=headers, json=search_payload, timeout=60).json()

    rows = resp.get("children", []) or []
    if not rows:
        break

    for row in rows:
        eid = (row.get("data") or {}).get("uniqueId")
        if eid:
            entity_ids.append(eid)

    if len(rows) < 200:
        break
    offset += 200

print(f"Found {len(entity_ids)} Fairlife BOL entities created in Nov 2025")

if not entity_ids:
    raise SystemExit("No records found for Nov 2025. Done.")

# ============================================================
# PROCESS + APPEND
# ============================================================
extracted_at = datetime.now(timezone.utc)

meta_rows = []
attach_rows = []

for i, entity_id in enumerate(entity_ids, 1):
    print(f"[{i}/{len(entity_ids)}] GET entity {entity_id}")
    entity = req(
        "GET",
        f"{BASE}/entities/records/{entity_id}",
        headers={"Authorization": f"Bearer {TOKEN}"},
        timeout=60
    ).json()

    ship   = entity.get("core_documents_shipment") or {}
    driver = ship.get("driver") or {}
    carrier = ship.get("carrier") or {}
    trailer = ship.get("trailer") or {}
    facility = ship.get("facility") or {}
    origin_loc = ship.get("originLocation") or {}
    dest_loc = ship.get("destinationLocation") or {}

    origin_addr = pick_address(jget(origin_loc, "denormalizedProperties.location.address"))
    dest_addr   = pick_address(jget(dest_loc, "denormalizedProperties.location.address"))
    facility_addr = pick_address(jget(facility, "denormalizedProperties.location.address"))

    meta_rows.append(Row(
        entityId=entity.get("uniqueId"),
        documentName=jget(entity, "document.name"),

        ownerFirmId=jget(entity, "owner.firm.entityId"),
        ownerFirmName=jget(entity, "owner.firm.displayName"),

        shipmentNumber=jget(ship, "shipmentNumber"),
        shipmentStatus=jget(ship, "shipmentStatus"),
        shipmentDate=iso_to_ts(jget(ship, "shipmentDate")),
        receiver=jget(ship, "receiver"),
        proNumber=jget(ship, "identification.proNumber"),
        truckNumber=jget(ship, "truckNumber"),
        trailerNumber=jget(ship, "trailerNumber") or jget(ship, "pickupTrailerNumber"),
        sealNumber=jget(ship, "seal.number"),

        carrierId=carrier.get("entityId"),
        carrierName=carrier.get("displayName"),
        carrierScac=jget(carrier, "denormalizedProperties.carrier.scac"),
        carrierLegalName=jget(carrier, "denormalizedProperties.business.legalName"),

        driverId=driver.get("entityId"),
        driverName=driver.get("displayName"),
        driverFirmId=jget(ship, "driverFirm.entityId") or jget(driver, "denormalizedProperties.owner.firm.entityId"),
        driverFirmName=jget(ship, "driverFirm.displayName") or jget(driver, "denormalizedProperties.owner.firm.displayName"),

        trailerEntityId=trailer.get("entityId"),
        trailerDisplayName=trailer.get("displayName"),
        trailerName=jget(trailer, "denormalizedProperties.core_yms_trailer.name"),
        trailerStatus=jget(trailer, "denormalizedProperties.core_yms_trailer.status"),

        facilityId=facility.get("entityId"),
        facilityName=facility.get("displayName"),
        facilityRegion=facility_addr.get("region"),
        facilityCity=facility_addr.get("locality"),
        facilityPostalCode=facility_addr.get("postalCode"),
        facilityStreet=facility_addr.get("streetAddress"),

        originLocationId=origin_loc.get("entityId"),
        originLocationName=origin_loc.get("displayName"),
        originRegion=origin_addr.get("region"),
        originCity=origin_addr.get("locality"),
        originPostalCode=origin_addr.get("postalCode"),
        originStreet=origin_addr.get("streetAddress"),

        destinationLocationId=dest_loc.get("entityId"),
        destinationLocationName=dest_loc.get("displayName"),
        destinationRegion=dest_addr.get("region"),
        destinationCity=dest_addr.get("locality"),
        destinationPostalCode=dest_addr.get("postalCode"),
        destinationStreet=dest_addr.get("streetAddress"),

        driverSigned=jget(ship, "driverSigned"),
        driverSignedDate=iso_to_ts(jget(ship, "driverSignature.signedDate")),
        shipperSignedDate=iso_to_ts(jget(ship, "shipperSignature.signedDate")),
        receiverSignedDate=iso_to_ts(jget(ship, "receiverSignature.signedDate")),

        bolAttachmentUri=best_main_doc_uri(entity),

        creationDate=iso_to_ts(entity.get("creationDate")),
        modifiedDate=iso_to_ts(entity.get("modifiedDate")),
        extractedAt=extracted_at
    ))

    # ------------------------------
    # Attachments (multiple groups)
    # ------------------------------
    def add_files(group_name, files_obj):
        if not files_obj:
            return
        files = files_obj.get("files") if isinstance(files_obj, dict) else None
        if not files:
            return
        for f in files:
            if not isinstance(f, dict):
                continue

            # pick first preview image if available
            preview0 = None
            previews = f.get("preview") or []
            if previews and isinstance(previews, list) and isinstance(previews[0], dict):
                preview0 = previews[0]

            attach_rows.append(Row(
                entityId=entity.get("uniqueId"),
                documentName=jget(entity, "document.name"),

                attachmentGroup=group_name,
                fileUniqueId=f.get("uniqueId"),
                fileName=f.get("name"),
                fileType=f.get("type"),
                pages=f.get("pages") if isinstance(f.get("pages"), int) else None,
                uri=f.get("uri"),

                previewUri=(preview0 or {}).get("uri"),
                previewWidth=(preview0 or {}).get("width") if isinstance((preview0 or {}).get("width"), int) else None,
                previewHeight=(preview0 or {}).get("height") if isinstance((preview0 or {}).get("height"), int) else None,

                extractedAt=extracted_at
            ))

    # document primary attachments
    add_files("document.attachments", jget(entity, "document.attachments"))

    # shipment-related attachments (if present)
    add_files("core_documents_shipment.packingList", jget(entity, "core_documents_shipment.packingList"))
    add_files("core_documents_shipment.proofOfDeliveryAttachment", jget(entity, "core_documents_shipment.proofOfDeliveryAttachment"))
    add_files("core_documents_shipment.proofOfShipmentAttachment", jget(entity, "core_documents_shipment.proofOfShipmentAttachment"))

# ============================================================
# WRITE (APPEND) TO DELTA TABLES
# ============================================================
df_meta = spark.createDataFrame(meta_rows, schema=meta_schema)
df_att  = spark.createDataFrame(attach_rows, schema=attach_schema)

print("Meta rows:", df_meta.count())
print("Attachment rows:", df_att.count())

# Append
df_meta.write.mode("append").format("delta").saveAsTable(META_TABLE)
df_att.write.mode("append").format("delta").saveAsTable(ATT_TABLE)

print(f"✅ Appended to {META_TABLE} and {ATT_TABLE}")

# Optional: quick peek
display(df_meta.limit(50))
display(df_att.limit(50))


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

import requests
from datetime import datetime, timezone

from pyspark.sql import Row
from pyspark.sql.types import (
    StructType, StructField, StringType, BooleanType
)

# =====================
# CONFIG
# =====================
TOKEN = "6e3410b8a276520af92bb4712563f9ab"  # per your note: token directly, no env vars
ENTITY_ID = "4b9c5324-8d2e-4632-b93b-0ff1d5b60f9e"
BASE = "https://api.withvector.com/1.0"

LAKEHOUSE_DB = "data_central_lh"  # change if you want (ex: "bronze", "vector_raw", etc.)
TBL_META = f"{LAKEHOUSE_DB}.vector_bol_meta_bronze"
TBL_ATTACH = f"{LAKEHOUSE_DB}.vector_bol_attachments_bronze"

FAIRLIFE_MIXIN_ID = "5a30a865-1353-4363-ac11-1248cb13e15d"  # Fairlife Shipment Document

# =====================
# HELPERS
# =====================
def jget(d, path, default=None):
    cur = d
    for p in path.split("."):
        if isinstance(cur, dict) and p in cur:
            cur = cur[p]
        else:
            return default
    return cur

def pick_address(addr):
    if not isinstance(addr, dict):
        return {}
    return {
        "region": addr.get("region"),
        "locality": addr.get("locality"),
        "postalCode": addr.get("postalCode"),
        "streetAddress": addr.get("streetAddress"),
        "timezoneId": addr.get("timezoneId"),
        "countryName": addr.get("countryName"),
    }

def mixin_ids(entity):
    out = []
    for m in (jget(entity, "mixins.active", []) or []):
        if isinstance(m, dict) and m.get("entityId"):
            out.append(m["entityId"])
    return out

def best_main_doc_uri(entity):
    agg = jget(entity, "document.attachments.aggregate.uri")
    if agg:
        return agg
    files = jget(entity, "document.attachments.files", []) or []
    if files and isinstance(files[0], dict):
        return files[0].get("uri")
    return None

def to_str(x):
    # Keep Spark schema stable (StringType) even when null/missing
    if x is None:
        return None
    return str(x)

# =====================
# FETCH ENTITY JSON
# =====================
headers = {"Authorization": f"Bearer {TOKEN}", "Accept": "application/json"}
url = f"{BASE}/entities/records/{ENTITY_ID}"

resp = requests.get(url, headers=headers, timeout=60)
print("GET:", url)
print("Status:", resp.status_code)
resp.raise_for_status()

entity = resp.json()
extracted_at = datetime.now(timezone.utc).isoformat()


active_mixins = mixin_ids(entity)
print(active_mixins)
if FAIRLIFE_MIXIN_ID not in active_mixins:
    raise ValueError(
        f"Entity {ENTITY_ID} is missing Fairlife Shipment Document mixin {FAIRLIFE_MIXIN_ID}. "
        f"Active mixins: {active_mixins}"
    )

# =====================
# BUILD META ROW
# =====================
ship = entity.get("core_documents_shipment") or {}

carrier = jget(entity, "core_documents_shipment.carrier") or {}
driver  = jget(entity, "core_documents_shipment.driver") or {}
trailer = jget(entity, "core_documents_shipment.trailer") or {}
facility = jget(entity, "core_documents_shipment.facility") or {}
origin_loc = jget(entity, "core_documents_shipment.originLocation") or {}
dest_loc   = jget(entity, "core_documents_shipment.destinationLocation") or {}

origin_addr   = pick_address(jget(origin_loc, "denormalizedProperties.location.address"))
dest_addr     = pick_address(jget(dest_loc, "denormalizedProperties.location.address"))
facility_addr = pick_address(jget(facility, "denormalizedProperties.location.address"))

meta_row = {
    "entityId": to_str(entity.get("uniqueId")),
    "documentName": to_str(jget(entity, "document.name")),
    "ownerFirmId": to_str(jget(entity, "owner.firm.entityId")),
    "ownerFirmName": to_str(jget(entity, "owner.firm.displayName")),
    "creationDate": to_str(entity.get("creationDate")),
    "modifiedDate": to_str(entity.get("modifiedDate")),
    "uploadDate": to_str(jget(entity, "document.uploadDate")),
    "mixinsActive": to_str(";".join(active_mixins)),

    # shipment summary
    "shipmentNumber": to_str(jget(ship, "shipmentNumber")),
    "shipmentStatus": to_str(jget(ship, "shipmentStatus")),
    "shipmentDate": to_str(jget(ship, "shipmentDate")),
    "receiver": to_str(jget(ship, "receiver")),
    "proNumber": to_str(jget(ship, "identification.proNumber")),
    "truckNumber": to_str(jget(ship, "truckNumber")),
    "trailerNumber": to_str(jget(ship, "trailerNumber") or jget(ship, "pickupTrailerNumber")),
    "sealNumber": to_str(jget(ship, "seal.number")),

    # carrier
    "carrierId": to_str(carrier.get("entityId")),
    "carrierName": to_str(carrier.get("displayName")),
    "carrierScac": to_str(jget(carrier, "denormalizedProperties.carrier.scac")),
    "carrierLegalName": to_str(jget(carrier, "denormalizedProperties.business.legalName")),

    # driver
    "driverId": to_str(driver.get("entityId")),
    "driverName": to_str(driver.get("displayName")),
    "driverFirmId": to_str(jget(entity, "core_documents_shipment.driverFirm.entityId") or jget(driver, "denormalizedProperties.owner.firm.entityId")),
    "driverFirmName": to_str(jget(entity, "core_documents_shipment.driverFirm.displayName") or jget(driver, "denormalizedProperties.owner.firm.displayName")),

    # trailer
    "trailerEntityId": to_str(trailer.get("entityId")),
    "trailerDisplayName": to_str(trailer.get("displayName")),
    "trailerName": to_str(jget(trailer, "denormalizedProperties.core_yms_trailer.name")),
    "trailerStatus": to_str(jget(trailer, "denormalizedProperties.core_yms_trailer.status")),

    # facility
    "facilityId": to_str(facility.get("entityId")),
    "facilityName": to_str(facility.get("displayName")),
    "facilityRegion": to_str(facility_addr.get("region")),
    "facilityCity": to_str(facility_addr.get("locality")),
    "facilityPostalCode": to_str(facility_addr.get("postalCode")),
    "facilityStreet": to_str(facility_addr.get("streetAddress")),

    # origin
    "originLocationId": to_str(origin_loc.get("entityId")),
    "originLocationName": to_str(origin_loc.get("displayName")),
    "originRegion": to_str(origin_addr.get("region")),
    "originCity": to_str(origin_addr.get("locality")),
    "originPostalCode": to_str(origin_addr.get("postalCode")),
    "originStreet": to_str(origin_addr.get("streetAddress")),

    # destination
    "destinationLocationId": to_str(dest_loc.get("entityId")),
    "destinationLocationName": to_str(dest_loc.get("displayName")),
    "destinationRegion": to_str(dest_addr.get("region")),
    "destinationCity": to_str(dest_addr.get("locality")),
    "destinationPostalCode": to_str(dest_addr.get("postalCode")),
    "destinationStreet": to_str(dest_addr.get("streetAddress")),

    # signatures
    "driverSigned": jget(ship, "driverSigned"),
    "driverSignedDate": to_str(jget(ship, "driverSignature.signedDate")),
    "shipperSignedDate": to_str(jget(ship, "shipperSignature.signedDate")),
    "receiverSignedDate": to_str(jget(ship, "receiverSignature.signedDate")),

    # main doc uri
    "bolAttachmentUri": to_str(best_main_doc_uri(entity)),

    "extractedAt": to_str(extracted_at),
}

# Explicit schema to avoid NullType inference issues
meta_schema = StructType([
    StructField("entityId", StringType(), True),
    StructField("documentName", StringType(), True),
    StructField("ownerFirmId", StringType(), True),
    StructField("ownerFirmName", StringType(), True),
    StructField("creationDate", StringType(), True),
    StructField("modifiedDate", StringType(), True),
    StructField("uploadDate", StringType(), True),
    StructField("mixinsActive", StringType(), True),

    StructField("shipmentNumber", StringType(), True),
    StructField("shipmentStatus", StringType(), True),
    StructField("shipmentDate", StringType(), True),
    StructField("receiver", StringType(), True),
    StructField("proNumber", StringType(), True),
    StructField("truckNumber", StringType(), True),
    StructField("trailerNumber", StringType(), True),
    StructField("sealNumber", StringType(), True),

    StructField("carrierId", StringType(), True),
    StructField("carrierName", StringType(), True),
    StructField("carrierScac", StringType(), True),
    StructField("carrierLegalName", StringType(), True),

    StructField("driverId", StringType(), True),
    StructField("driverName", StringType(), True),
    StructField("driverFirmId", StringType(), True),
    StructField("driverFirmName", StringType(), True),

    StructField("trailerEntityId", StringType(), True),
    StructField("trailerDisplayName", StringType(), True),
    StructField("trailerName", StringType(), True),
    StructField("trailerStatus", StringType(), True),

    StructField("facilityId", StringType(), True),
    StructField("facilityName", StringType(), True),
    StructField("facilityRegion", StringType(), True),
    StructField("facilityCity", StringType(), True),
    StructField("facilityPostalCode", StringType(), True),
    StructField("facilityStreet", StringType(), True),

    StructField("originLocationId", StringType(), True),
    StructField("originLocationName", StringType(), True),
    StructField("originRegion", StringType(), True),
    StructField("originCity", StringType(), True),
    StructField("originPostalCode", StringType(), True),
    StructField("originStreet", StringType(), True),

    StructField("destinationLocationId", StringType(), True),
    StructField("destinationLocationName", StringType(), True),
    StructField("destinationRegion", StringType(), True),
    StructField("destinationCity", StringType(), True),
    StructField("destinationPostalCode", StringType(), True),
    StructField("destinationStreet", StringType(), True),

    StructField("driverSigned", BooleanType(), True),
    StructField("driverSignedDate", StringType(), True),
    StructField("shipperSignedDate", StringType(), True),
    StructField("receiverSignedDate", StringType(), True),

    StructField("bolAttachmentUri", StringType(), True),
    StructField("extractedAt", StringType(), True),
])

df_meta = spark.createDataFrame([meta_row], schema=meta_schema)

# =====================
# BUILD ATTACHMENTS DF
# =====================
files = jget(entity, "document.attachments.files", []) or []
att_rows = []
for f in files:
    if not isinstance(f, dict):
        continue
    att_rows.append({
        "entityId": to_str(entity.get("uniqueId")),
        "documentName": to_str(jget(entity, "document.name")),
        "fileUniqueId": to_str(f.get("uniqueId")),
        "fileName": to_str(f.get("name")),
        "fileType": to_str(f.get("type")),
        "pages": to_str(f.get("pages")),
        "fileUri": to_str(f.get("uri")),
        "aggregatePdfUri": to_str(jget(entity, "document.attachments.aggregate.uri")),
        "attachmentsVersion": to_str(jget(entity, "document.attachments.version")),
        "extractedAt": to_str(extracted_at),
    })

att_schema = StructType([
    StructField("entityId", StringType(), True),
    StructField("documentName", StringType(), True),
    StructField("fileUniqueId", StringType(), True),
    StructField("fileName", StringType(), True),
    StructField("fileType", StringType(), True),
    StructField("pages", StringType(), True),
    StructField("fileUri", StringType(), True),
    StructField("aggregatePdfUri", StringType(), True),
    StructField("attachmentsVersion", StringType(), True),
    StructField("extractedAt", StringType(), True),
])

df_attach = spark.createDataFrame(att_rows, schema=att_schema)

# =====================
# CREATE DB + APPEND TO TABLES
# =====================
spark.sql(f"CREATE DATABASE IF NOT EXISTS {LAKEHOUSE_DB}")

# Append meta
(df_meta
 .write
 .format("delta")
 .mode("append")
 .option("mergeSchema", "true")
 .saveAsTable(TBL_META)
)

# Append attachments
(df_attach
 .write
 .format("delta")
 .mode("append")
 .option("mergeSchema", "true")
 .saveAsTable(TBL_ATTACH)
)

print("✅ Appended to Lakehouse tables:")
print(" -", TBL_META, "rows:", df_meta.count())
print(" -", TBL_ATTACH, "rows:", df_attach.count())

# Optional quick peek
display(df_meta)
display(df_attach)


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

import requests
import json

# ===============================
# CONFIG
# ===============================
from notebookutils import mssparkutils

# --- Read secrets from Azure Key Vault ---
VECTOR_TOKEN = mssparkutils.credentials.getSecret(
    "https://keyvault-fabric2.vault.azure.net/",
    "VECTORTOKEN"
)
BASE_URL = "https://api.withvector.com/1.0/entities/records"

BOL_ENTITY_ID = "4b9c5324-8d2e-4632-b93b-0ff1d5b60f9e"
WORKFLOW_ENTITY_ID = "7c9de5c9-11dc-4921-bc68-0c16acd8fe7e"

HEADERS = {
    "Authorization": f"Bearer {VECTOR_TOKEN}",
    "Content-Type": "application/json"
}

# ===============================
# HELPER FUNCTION
# ===============================
def fetch_entity(entity_id, label):
    url = f"{BASE_URL}/{entity_id}"
    print(f"\nRequesting {label}...")
    print(f"GET {url}")

    resp = requests.get(url, headers=HEADERS)

    print(f"Status: {resp.status_code}")
    resp.raise_for_status()

    data = resp.json()
    print(f"\n========== FULL {label.upper()} JSON ==========\n")
    print(json.dumps(data, indent=2))
    return data


# ===============================
# EXECUTION
# ===============================
bol_json = fetch_entity(BOL_ENTITY_ID, "BOL DOCUMENT")
# workflow_json = fetch_entity(WORKFLOW_ENTITY_ID, "WORKFLOW / STORYBOARD")


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

import requests, json

TOKEN = "6e3410b8a276520af92bb4712563f9ab"  
BASE = "https://api.withvector.com/1.0"
MIXIN_FAIRLIFE_BASE = "54809ba0-e1c6-46ec-af52-a392803a36b0"

payload = {
  "filters": [
    {"type": "containsEdge", "path": "mixins.active",
     "values": [{"entityId": MIXIN_FAIRLIFE_BASE}]},
    {"type": "range", "path": "creationDate",
     "gte": "2025-11-01T00:00:00.000Z",
     "lte": "2025-12-12T23:59:59.999Z"}
  ],
  "orders": [{"path": "creationDate", "type": "descending"}],
  "metadata": {"size": 50, "offset": 0}
}

r = requests.post(
    f"{BASE}/entities/query",
    headers={"Authorization": f"Bearer {TOKEN}", "Content-Type": "application/json"},
    json=payload,
    timeout=60
)

print("Status:", r.status_code)
data = r.json()
print("Top-level keys:", list(data.keys()))
print("Rows returned:", len(data.get("children", [])))

# dump first record id + fetch full
if data.get("children"):
    first = data["children"][0]
    uid = first.get("uniqueId")
    print("\nFirst uniqueId:", uid)
    full = requests.get(
        f"{BASE}/entities/records/{uid}",
        headers={"Authorization": f"Bearer {TOKEN}"},
        timeout=60
    ).json()
    print("\nFULL RECORD:")
    print(json.dumps(full, indent=2)[:8000])  # trim console output


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

import json
import requests
from datetime import datetime, timedelta, timezone

# ======================
# CONFIG (edit these 2)
# ======================
TOKEN = "6e3410b8a276520af92bb4712563f9ab"  

# Pick the mixin you want to test:
# - Storyboard Execution: 54809ba0-e1c6-46ec-af52-a392803a36b0
# - Document:            11111111-0000-0000-0000-000000000011
MIXIN_ENTITY_ID = "54809ba0-e1c6-46ec-af52-a392803a36b0"

BASE_URL = "https://api.withvector.com"
ENDPOINT = f"{BASE_URL}/1.0/entities/query"

def iso_z(dt: datetime) -> str:
    return dt.astimezone(timezone.utc).isoformat().replace("+00:00", "Z")

# Last 30 days window
now_utc = datetime.now(timezone.utc)
gte = iso_z(now_utc - timedelta(days=30))
lte = iso_z(now_utc)

payload = {
    "filters": [
        {
            "type": "containsEdge",
            "path": "mixins.active",
            "values": [{"entityId": MIXIN_ENTITY_ID}]
        },
        {
            "type": "range",
            "path": "creationDate",
            "gte": gte,
            "lte": lte
        }
    ],
    "orders": [
        {"path": "creationDate", "type": "descending"}
    ],
    "metadata": {
        "size": 1,
        "offset": 0,
        "shouldIncludeLeafEntities": True
    }
}

headers = {
    "Authorization": f"Bearer {TOKEN}",
    "Content-Type": "application/json"
}

print("Requesting 1 record for last 30 days...")
print(f"Mixin: {MIXIN_ENTITY_ID}")
print(f"Range: {gte}  ->  {lte}")
print(f"POST: {ENDPOINT}\n")

resp = requests.post(ENDPOINT, headers=headers, json=payload, timeout=60)

print("Status:", resp.status_code)
if resp.status_code != 200:
    print(resp.text)
    raise SystemExit(1)

data = resp.json()
children = data.get("children", [])

print("Rows returned:", len(children))
if not children:
    print("No records found for that mixin in the last 30 days.")
    raise SystemExit(0)

# In Vector responses, each child often has {"data": {...}}; fall back to raw child if not.
first = children[0].get("data", children[0])

print("\n========== FULL JSON DUMP (FIRST RECORD) ==========\n")
print(json.dumps(first, indent=2))


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

import requests, json

TOKEN = "6e3410b8a276520af92bb4712563f9ab" 
BASE = "https://api.withvector.com/1.0"
MIXIN = "54809ba0-e1c6-46ec-af52-a392803a36b0"

payload = {
  "filters": [
    {
      "type": "containsEdge",
      "path": "mixins.active",
      "values": [{ "entityId": "54809ba0-e1c6-46ec-af52-a392803a36b0" }]
    },
    {
      "type": "equals",
      "path": "owner.firm.entityId",
      "value": "8ccd57ef-16a5-4b54-acd3-926af17d7139"
    }
  ],
  "orders": [{ "path": "creationDate", "type": "descending" }],
  "metadata": { "size": 50, "offset": 0, "shouldIncludeLeafEntities": True }
}

resp = requests.post(
    f"{BASE}/entities/query",
    headers={"Authorization": f"Bearer {TOKEN}", "Content-Type": "application/json"},
    json=payload,
    timeout=60
)

print("Status:", resp.status_code)
print("Response text (first 2000 chars):")
print(resp.text[:2000])

data = resp.json() if resp.text.strip() else {}
children = data.get("children", [])
print("\nTop-level keys:", list(data.keys()))
print("Rows returned:", len(children))

if children:
    print("\nFirst child keys:", list(children[0].keys()))
    print("First uniqueId:", children[0].get("uniqueId"))


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

import requests
import json
from urllib.parse import urlparse

TOKEN = "6e3410b8a276520af92bb4712563f9ab"  
API_BASE = "https://api.withvector.com/1.0"
HEADERS = {
    "Authorization": f"Bearer {TOKEN}",
    "Content-Type": "application/json"
}

VECTOR_APP_URL = "https://app.withvector.com/view/ac497162-e782-4f35-a3cd-ee595616dcbf/entity/d87029f7-159e-49ad-a67d-0a3fbceb5197"

def extract_entity_id(app_url: str) -> str:
    parts = [p for p in urlparse(app_url).path.split("/") if p]
    # format: /view/{something}/entity/{entityId}
    return parts[-1]

def dump_entity(app_url: str):
    entity_id = extract_entity_id(app_url)
    print("EntityId:", entity_id)

    url = f"{API_BASE}/entities/records/{entity_id}"
    print("GET:", url)

    resp = requests.get(url, headers=HEADERS)
    print("Status:", resp.status_code)

    if resp.status_code != 200:
        print(resp.text)
        return

    data = resp.json()
    print("\n========= FULL ENTITY JSON DUMP ==========\n")
    print(json.dumps(data, indent=2))

if __name__ == "__main__":
    dump_entity(VECTOR_APP_URL)


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

import requests
import json

API_BASE = "https://api.withvector.com/1.0"
QUERY_URL = f"{API_BASE}/entities/query"
TOKEN = "6e3410b8a276520af92bb4712563f9ab"  


MIXIN_ID = "ed18d48a-e32a-4f7a-a918-3088ea75fef3"

HEADERS = {
    "Authorization": f"Bearer {TOKEN}",
    "Content-Type": "application/json"
}


payload = {
    "filters": [
        {
            "type": "containsEdge",
            "path": "mixins.active",
            "values": [
                {"entityId": MIXIN_ID}
            ]
        }
    ],
    "orders": [
        {
            "path": "creationDate",
            "type": "descending"
        }
    ],
    "metadata": {
        "size": 1,            
        "offset": 0,
        "shouldIncludeLeafEntities": True
    }
}

print("Requesting one sample document...")
resp = requests.post(QUERY_URL, headers=HEADERS, data=json.dumps(payload))

if resp.status_code != 200:
    print(f"Error {resp.status_code}")
    print(resp.text)
    raise SystemExit()

data = resp.json()
children = data.get("children", [])
if not children:
    print("No documents returned for this mixin.")
    raise SystemExit()


doc = children[0].get("data", children[0])


print("\n========== FULL DOCUMENT JSON DUMP ==========\n")
print(json.dumps(doc, indent=2))


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

import requests
import json

API_BASE = "https://api.withvector.com/1.0"
RECORD_URL = f"{API_BASE}/entities/records"
TOKEN = "6e3410b8a276520af92bb4712563f9ab" 

HEADERS = {
    "Authorization": f"Bearer {TOKEN}",
    "Content-Type": "application/json"
}

ENTITY_ID = "982b6d71-c5f6-40c0-99e9-e833030b506c"

def dump_entity(entity_id: str):
    url = f"{RECORD_URL}/{entity_id}"
    print("Requesting:", url)

    resp = requests.get(url, headers=HEADERS)
    print("Status:", resp.status_code)

    if resp.status_code != 200:
        print(resp.text)
        return

    data = resp.json()

    print("\n========== FULL ENTITY JSON DUMP ==========\n")
    print(json.dumps(data, indent=2))

if __name__ == "__main__":
    dump_entity(ENTITY_ID)


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

import requests
import json

API_BASE = "https://api.withvector.com/1.0"
QUERY_URL = f"{API_BASE}/entities/query"
TOKEN = "6e3410b8a276520af92bb4712563f9ab"  # <-- put your real token here

HEADERS = {
    "Authorization": f"Bearer {TOKEN}",
    "Content-Type": "application/json"
}


MIXIN_EMPTY_POD = "f1b7767b-595a-4a56-b679-6bd16075bb3e"

payload = {
    "filters": [
        {
            "type": "containsEdge",
            "path": "mixins.active",
            "values": [
                {"entityId": MIXIN_EMPTY_POD}
            ]
        }
    ],
    "orders": [
        {
            "path": "creationDate",
            "type": "descending"
        }
    ],
    "metadata": {
        "size": 1,              
        "offset": 0,
        "shouldIncludeLeafEntities": True
    }
}

print("Requesting one Empty-POD document...")
resp = requests.post(QUERY_URL, headers=HEADERS, data=json.dumps(payload))
print("Status:", resp.status_code)

if resp.status_code != 200:
    print(resp.text)
    raise SystemExit()

data = resp.json()
children = data.get("children", [])
if not children:
    print("No documents returned for this filter.")
    raise SystemExit()

doc = children[0].get("data", children[0])

print("\n========== FULL EMPTY-POD JSON ==========\n")
print(json.dumps(doc, indent=2))


owner_firm = doc.get("owner", {}).get("firm", {})
print("\nOwner firm:", owner_firm.get("displayName"), owner_firm.get("entityId"))
print("Document name:", doc.get("document", {}).get("name"))


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

import requests, json

API_BASE = "https://api.withvector.com/1.0"
QUERY_URL = f"{API_BASE}/entities/query"
TOKEN = "6e3410b8a276520af92bb4712563f9ab"  

HEADERS = {
    "Authorization": f"Bearer {TOKEN}",
    "Content-Type": "application/json"
}

def build_payload(offset=0, size=50):
    return {
        "filters": [
            {
                "type": "containsEdge",
                "path": "mixins.active",
                "values": [
                    { "entityId": "67556b42-a941-4f42-ba8e-bf3a63f00843" }  # eBOL mixin
                ]
            },
            {
                "type": "range",
                "entityType": "/1.0/entities/metadata/entity.json",
                "label": "Posted Date",
                "path": "creationDate",
                "gte": "2025-11-01T00:00:00.000Z",
                "lte": "2025-11-30T23:59:59.999Z"
            }
        ],
        "orders": [
            {
                "path": "creationDate",
                "type": "descending",
                "label": "Posted Date"
            }
        ],
        "metadata": {
            "size": size,
            "offset": offset,
            "maxSizePerGroup": size,
            "shouldIncludeLeafEntities": True
        }
    }

def test_query():
    payload = build_payload()
    resp = requests.post(QUERY_URL, headers=HEADERS, data=json.dumps(payload))
    print("Status:", resp.status_code)
    data = resp.json()
    print("Top-level keys:", list(data.keys()))
    rows = data.get("children", [])
    print("Rows returned:", len(rows))
    print(json.dumps(data["children"][0]["data"], indent=2))
    for i, row in enumerate(rows[:1], start=1):
        doc = row.get("data", row)
        print(f"\n#{i}")
        print("  uniqueId:", doc.get("uniqueId"))
        print("  name:", doc.get("document", {}).get("name"))
        print("  creationDate:", doc.get("creationDate"))

if __name__ == "__main__":
    test_query()


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# MARKDOWN ********************


# CELL ********************

import requests
import json
from datetime import datetime, timedelta
from collections import Counter


API_BASE = "https://api.withvector.com/1.0"
QUERY_URL = f"{API_BASE}/entities/query"
TOKEN = "6e3410b8a276520af92bb4712563f9ab" 


E_BOL_MIXIN = "ed18d48a-e32a-4f7a-a918-3088ea75fef3"


PAGE_SIZE = 200

HEADERS = {
    "Authorization": f"Bearer {TOKEN}",
    "Content-Type": "application/json"
}


today = datetime.utcnow().date()


end_date = datetime(today.year, today.month, 1)  
start_date = datetime(end_date.year - 1, end_date.month, 1) 
end_date = end_date - timedelta(seconds=1) 

# Convert to ISO8601 with 'Z'
GTE_ISO = start_date.strftime("%Y-%m-%dT%H:%M:%S.000Z")
LTE_ISO = end_date.strftime("%Y-%m-%dT%H:%M:%S.999Z")


def build_query_payload(offset: int, size: int) -> dict:
    """
    Build the /entities/query payload for eBOL documents in the last 12 months.
    """
    return {
        "filters": [
            {
                "type": "containsEdge",
                "path": "mixins.active",
                "values": [
                    {"entityId": E_BOL_MIXIN}
                ]
            },
            {
                "type": "range",
                "entityType": "/1.0/entities/metadata/entity.json",
                "label": "Posted Date",
                "path": "creationDate",
                "gte": GTE_ISO,
                "lte": LTE_ISO
            }
        ],
        "orders": [
            {
                "path": "creationDate",
                "type": "descending",
                "label": "Posted Date"
            }
        ],
        "metadata": {
            "size": size,
            "offset": offset,
            "maxSizePerGroup": size,
            "shouldIncludeLeafEntities": True
        }
    }


def fetch_all_ebol_creation_dates() -> list:
    """
    Page through /entities/query and collect creationDate values
    for all eBOL documents in the last 12 months.
    """
    offset = 0
    creation_dates = []
    total_expected = None

    while True:
        payload = build_query_payload(offset, PAGE_SIZE)
        resp = requests.post(QUERY_URL, headers=HEADERS, data=json.dumps(payload))

        if resp.status_code != 200:
            print(f"ERROR: {resp.status_code}")
            print(resp.text)
            break

        data = resp.json()

 
        if total_expected is None:
            total_expected = data.get("metadata", {}).get("totalEntityMatchCount")
            print("Total match count (reported by API):", total_expected)

        rows = data.get("children", [])
        if not rows:
            print("No more rows. Stopping pagination.")
            break

        for row in rows:
            doc = row.get("data", row)
            creation_date_str = doc.get("creationDate")
            if creation_date_str:
                creation_dates.append(creation_date_str)

        print(f"Fetched {len(rows)} docs at offset {offset}")
        offset += PAGE_SIZE

    return creation_dates


def to_year_month(date_str: str) -> str:
    """
    Convert an ISO8601 date string to 'YYYY-MM'.
    Vector uses 'Z' suffix — handle that explicitly.
    """

    if date_str.endswith("Z"):
        date_str = date_str.replace("Z", "+00:00")
    dt = datetime.fromisoformat(date_str)
    return dt.strftime("%Y-%m")


def main():
    print(f"Date range: {GTE_ISO}  to  {LTE_ISO}")
    creation_dates = fetch_all_ebol_creation_dates()

    print("\nTotal documents fetched:", len(creation_dates))


    ym_counts = Counter(to_year_month(d) for d in creation_dates)

    print("\nMonthly breakdown for eBOL (last 12 full months):")
    for ym in sorted(ym_counts.keys()):
        print(f"{ym}: {ym_counts[ym]}")




if __name__ == "__main__":
    main()


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }
