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

# Welcome to your new notebook
# Type here in the cell editor to add code!


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# MARKDOWN ********************

# <mark>**Vector BOL Script**</mark>

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
# META   "language_group": "synapse_pyspark"
# META }

# MARKDOWN ********************


# MARKDOWN ********************

# <mark>**Vector BOL Check-in Script**</mark>

# CELL ********************

import requests, json, time
from datetime import datetime, timezone, timedelta

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

# Fairlife Facility Check-In (execution mixin id)
FAIRLIFE_CHECKIN_EXECUTION_MIXIN = "b3c99c93-fd6c-466b-bdb6-59950dc31c11"

# (Optional) Fairlife firm id. You previously said you don't need firmId.
# Keep it None unless you want to constrain results further.
FIRM_ID = None  # "8ccd57ef-16a5-4b54-acd3-926af17d7139"

# Tables (drop/recreate)
TBL_META  = "vector_checkin_meta_bronze"
TBL_EVENTS= "vector_checkin_events_bronze"
TBL_RAW   = "vector_checkin_raw_bronze"

# Window + paging
MONTHS_BACK = 2
DATE_FIELD  = "modifiedDate"  # you confirmed modifiedDate range filter works

PAGE_SIZE   = 100
MAX_IDS     = 10000          # do not try to pull more using offset paging
MAX_OFFSET  = 9900           # avoid offset=10000 which triggers "all shards failed"
SLEEP_BETWEEN_GETS = 0.10

HEADERS = {
    "Authorization": f"Bearer {VECTOR_TOKEN}",
    "Content-Type": "application/json",
    "Accept": "application/json",
}

# =========================
# HELPERS
# =========================
def now_utc():
    return datetime.now(timezone.utc)

def iso_z(dt: datetime) -> str:
    # Vector examples use Z strings
    return dt.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.000Z")

def now_utc_ts_naive():
    # Spark TimestampType prefers naive
    return datetime.now(timezone.utc).replace(tzinfo=None)

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

def post_query(payload, timeout=60):
    r = requests.post(QUERY_ENDPOINT, headers=HEADERS, json=payload, timeout=timeout)
    if r.status_code != 200:
        print("\n--- QUERY FAILED ---")
        print("HTTP:", r.status_code)
        print("Payload:\n", json.dumps(payload, indent=2)[:4000])
        try:
            print("Response:\n", json.dumps(r.json(), indent=2)[:4000])
        except Exception:
            print("Response text:\n", r.text[:4000])
        r.raise_for_status()
    return r.json()

def get_record(entity_id, timeout=60):
    r = requests.get(f"{RECORD_ENDPOINT}/{entity_id}", headers=HEADERS, timeout=timeout)
    if r.status_code != 200:
        print("\n--- GET RECORD FAILED ---", entity_id, r.status_code)
        try:
            print(json.dumps(r.json(), indent=2)[:2000])
        except Exception:
            print(r.text[:2000])
        r.raise_for_status()
    return r.json()

def table_exists(tbl_name: str) -> bool:
    try:
        spark.table(tbl_name)
        return True
    except Exception:
        return False

def drop_table_if_exists(tbl_name: str):
    spark.sql(f"DROP TABLE IF EXISTS {tbl_name}")

# =========================
# VECTOR QUERY PAYLOAD BUILDER
# =========================
def build_payload(offset, size, start_iso, end_iso):
    filters = [
        {
            "type": "containsEdge",
            "path": "mixins.active",
            "values": [{"entityId": FAIRLIFE_CHECKIN_EXECUTION_MIXIN}]
        },
        {
            "type": "range",
            "path": DATE_FIELD,
            "gte": start_iso,
            "lte": end_iso
        }
    ]
    md = {
        "size": size,
        "offset": offset,
        "shouldIncludeLeafEntities": True
    }
    if FIRM_ID:
        md["firmId"] = FIRM_ID

    return {"filters": filters, "metadata": md}

def collect_ids_in_window(start_iso, end_iso, page_size=100):
    ids = []
    offset = 0
    total = None

    while True:
        if offset > MAX_OFFSET:
            print(f"\nReached MAX_OFFSET={MAX_OFFSET}. Stopping pagination to avoid shard failures.")
            break
        if len(ids) >= MAX_IDS:
            print(f"\nReached MAX_IDS={MAX_IDS}. Stopping pagination.")
            break

        size = min(page_size, MAX_IDS - len(ids))
        payload = build_payload(offset=offset, size=size, start_iso=start_iso, end_iso=end_iso)

        resp = post_query(payload)
        md = resp.get("metadata") or {}
        if total is None and isinstance(md.get("totalEntityMatchCount"), int):
            total = md["totalEntityMatchCount"]
            print(f"Total matches reported by Vector: {total}")

        children = resp.get("children", []) or []
        if not children:
            break

        for c in children:
            uid = jget(c, "data.uniqueId")
            if uid:
                ids.append(uid)

        offset += size
        if offset % 1000 == 0:
            print(f"  collected IDs: {len(ids)} (offset={offset})")

        # If total known and we've paged through it, stop
        if isinstance(total, int) and offset >= total:
            break

    # de-dupe preserve order
    seen = set()
    out = []
    for x in ids:
        if x not in seen:
            out.append(x)
            seen.add(x)

    return out, (total if total is not None else -1)

# =========================
# PARSERS
# =========================
def extract_shipment_linkage(entity: dict):
    """
    Based on your probe, Fairlife check-in shipment fields are here:
      core_yms_execution.outbound.shipmentNumber
      core_yms_execution.outbound.shipmentDocument
    """
    ship_num = jget(entity, "core_yms_execution.outbound.shipmentNumber", "") or ""
    ship_doc = jget(entity, "core_yms_execution.outbound.shipmentDocument", {}) or {}

    ship_doc_eid  = (ship_doc.get("entityId") or "")
    ship_doc_name = (ship_doc.get("displayName") or "")
    ship_doc_docname = jget(ship_doc, "denormalizedProperties.document.name", "") or ""

    return ship_num, ship_doc_eid, ship_doc_name, ship_doc_docname

def parse_meta(entity: dict, extracted_at):
    ship_num, ship_doc_eid, ship_doc_name, ship_doc_docname = extract_shipment_linkage(entity)

    # basic descriptors
    row = {
        "entityId": str(entity.get("uniqueId") or ""),
        "shipmentNumber": ship_num,
        "shipmentDocumentEntityId": ship_doc_eid,
        "shipmentDocumentName": ship_doc_name,
        "shipmentDocumentDocumentName": ship_doc_docname,

        "creationDateUtc": str(entity.get("creationDate") or ""),
        "modifiedDateUtc": str(entity.get("modifiedDate") or ""),

        "ownerFirmId": str(jget(entity, "owner.firm.entityId") or ""),
        "ownerFirmName": str(jget(entity, "owner.firm.displayName") or ""),
        "ownerUserId": str(jget(entity, "owner.user.entityId") or ""),
        "ownerUserName": str(jget(entity, "owner.user.displayName") or ""),

        "createdByUserId": str(jget(entity, "createdBy.entityId") or ""),
        "createdByUserName": str(jget(entity, "createdBy.displayName") or ""),
        "modifiedByUserId": str(jget(entity, "modifiedBy.entityId") or ""),
        "modifiedByUserName": str(jget(entity, "modifiedBy.displayName") or ""),

        "visitStatus": str(jget(entity, "core_yms_execution.visit.status") or ""),
        "workflowStatus": str(jget(entity, "core_storyboard_execution.status") or ""),
        "needsAttentionStatus": str(jget(entity, "fairlife_execution.needsAttentionStatus") or jget(entity, "kraft_heinz_execution.needsAttentionStatus") or ""),

        "driverId": str(jget(entity, "core_yms_execution.driver.entityId") or ""),
        "driverName": str(jget(entity, "core_yms_execution.driver.displayName") or ""),
        "driverFirmId": str(jget(entity, "core_yms_execution.driver.denormalizedProperties.owner.firm.entityId") or ""),
        "driverFirmName": str(jget(entity, "core_yms_execution.driver.denormalizedProperties.owner.firm.displayName") or ""),

        # yard/facility/location (these are important for yard metrics later)
        "facilityName": str(jget(entity, "basebowl_facility.location.name") or ""),
        "facilityRegion": str(jget(entity, "basebowl_facility.location.address.region") or ""),
        "facilityLocality": str(jget(entity, "basebowl_facility.location.address.locality") or ""),
        "facilityPostalCode": str(jget(entity, "basebowl_facility.location.address.postalCode") or ""),
        "facilityTimezoneId": str(jget(entity, "basebowl_facility.location.address.timezoneId") or ""),
        "facilityStreetAddress": str(jget(entity, "basebowl_facility.location.address.streetAddress") or ""),

        "extractedAtUtc": extracted_at,
        "rawJson": json.dumps(entity)
    }
    return row

def parse_events(entity: dict, extracted_at):
    """
    Flatten core_storyboard_execution.events for reporting/audit.
    """
    out = []
    checkin_id = str(entity.get("uniqueId") or "")
    ship_num, ship_doc_eid, ship_doc_name, ship_doc_docname = extract_shipment_linkage(entity)

    events = jget(entity, "core_storyboard_execution.events", []) or []
    if not isinstance(events, list):
        return out

    for ev in events:
        if not isinstance(ev, dict):
            continue
        out.append({
            "checkinEntityId": checkin_id,
            "shipmentNumber": ship_num,
            "shipmentDocumentEntityId": ship_doc_eid,

            "eventId": str(ev.get("id") or ""),
            "eventType": str(ev.get("eventType") or ""),
            "eventName": str(ev.get("name") or ""),
            "creationDateUtc": str(ev.get("creationDate") or ""),
            "processedDateUtc": str(ev.get("processedDate") or ""),

            "createdByUserId": str(jget(ev, "createdBy.entityId") or ""),
            "createdByUserName": str(jget(ev, "createdBy.displayName") or ""),

            # Optional: store mappings/details in raw form (keeps schema stable)
            "detailsJson": json.dumps(ev.get("details")) if ev.get("details") is not None else None,
            "outputMappingsJson": json.dumps(ev.get("outputMappings")) if ev.get("outputMappings") is not None else None,

            "extractedAtUtc": extracted_at
        })
    return out

def parse_raw(entity: dict, extracted_at):
    ship_num, ship_doc_eid, ship_doc_name, ship_doc_docname = extract_shipment_linkage(entity)
    return {
        "entityId": str(entity.get("uniqueId") or ""),
        "shipmentNumber": ship_num,
        "shipmentDocumentEntityId": ship_doc_eid,
        "creationDateUtc": str(entity.get("creationDate") or ""),
        "modifiedDateUtc": str(entity.get("modifiedDate") or ""),
        "extractedAtUtc": extracted_at,
        "rawJson": json.dumps(entity)
    }

# =========================
# SCHEMAS (explicit)
# =========================
meta_schema = StructType([
    StructField("entityId", StringType(), False),

    StructField("shipmentNumber", StringType(), True),
    StructField("shipmentDocumentEntityId", StringType(), True),
    StructField("shipmentDocumentName", StringType(), True),
    StructField("shipmentDocumentDocumentName", StringType(), True),

    StructField("creationDateUtc", StringType(), True),
    StructField("modifiedDateUtc", StringType(), True),

    StructField("ownerFirmId", StringType(), True),
    StructField("ownerFirmName", StringType(), True),
    StructField("ownerUserId", StringType(), True),
    StructField("ownerUserName", StringType(), True),

    StructField("createdByUserId", StringType(), True),
    StructField("createdByUserName", StringType(), True),
    StructField("modifiedByUserId", StringType(), True),
    StructField("modifiedByUserName", StringType(), True),

    StructField("visitStatus", StringType(), True),
    StructField("workflowStatus", StringType(), True),
    StructField("needsAttentionStatus", StringType(), True),

    StructField("driverId", StringType(), True),
    StructField("driverName", StringType(), True),
    StructField("driverFirmId", StringType(), True),
    StructField("driverFirmName", StringType(), True),

    StructField("facilityName", StringType(), True),
    StructField("facilityRegion", StringType(), True),
    StructField("facilityLocality", StringType(), True),
    StructField("facilityPostalCode", StringType(), True),
    StructField("facilityTimezoneId", StringType(), True),
    StructField("facilityStreetAddress", StringType(), True),

    StructField("extractedAtUtc", TimestampType(), False),
    StructField("rawJson", StringType(), True),
])

events_schema = StructType([
    StructField("checkinEntityId", StringType(), False),
    StructField("shipmentNumber", StringType(), True),
    StructField("shipmentDocumentEntityId", StringType(), True),

    StructField("eventId", StringType(), True),
    StructField("eventType", StringType(), True),
    StructField("eventName", StringType(), True),
    StructField("creationDateUtc", StringType(), True),
    StructField("processedDateUtc", StringType(), True),

    StructField("createdByUserId", StringType(), True),
    StructField("createdByUserName", StringType(), True),

    StructField("detailsJson", StringType(), True),
    StructField("outputMappingsJson", StringType(), True),

    StructField("extractedAtUtc", TimestampType(), False),
])

raw_schema = StructType([
    StructField("entityId", StringType(), False),
    StructField("shipmentNumber", StringType(), True),
    StructField("shipmentDocumentEntityId", StringType(), True),
    StructField("creationDateUtc", StringType(), True),
    StructField("modifiedDateUtc", StringType(), True),
    StructField("extractedAtUtc", TimestampType(), False),
    StructField("rawJson", StringType(), True),
])

# =========================
# RUN: window last N months
# =========================
end_dt   = now_utc()
start_dt = end_dt - timedelta(days=30*MONTHS_BACK)

start_iso = iso_z(start_dt)
end_iso   = iso_z(end_dt)

print("====================================================")
print("STEP 1: Collect check-in entity IDs in window")
print("====================================================")
print(f"Window: {start_iso} -> {end_iso} (by {DATE_FIELD})")

candidate_ids, total = collect_ids_in_window(start_iso, end_iso, PAGE_SIZE)
print(f"\nCollected {len(candidate_ids)} candidate IDs (total reported={total})")

if not candidate_ids:
    raise SystemExit("No entities found in the window. Check token/mixinId/tenant access.")

print("\n====================================================")
print("STEP 2: Fetch records, extract linkage, skip blanks")
print("====================================================")

extracted_at = now_utc_ts_naive()

meta_rows   = []
events_rows = []
raw_rows    = []

kept = 0
skipped = 0

for idx, eid in enumerate(candidate_ids, start=1):
    ent = get_record(eid)

    ship_num, ship_doc_eid, ship_doc_name, ship_doc_docname = extract_shipment_linkage(ent)

    # Skip if linkage is blank (your rule)
    if not ship_num or not ship_doc_eid:
        skipped += 1
        if idx % 500 == 0:
            print(f"  idx={idx} kept={kept} skipped={skipped} (still skipping blanks)")
        time.sleep(SLEEP_BETWEEN_GETS)
        continue

    meta_rows.append(parse_meta(ent, extracted_at))
    events_rows.extend(parse_events(ent, extracted_at))
    raw_rows.append(parse_raw(ent, extracted_at))

    kept += 1
    if kept % 200 == 0:
        print(f"  kept={kept} skipped={skipped} last_shipment={ship_num} last_doc={ship_doc_name}")

    time.sleep(SLEEP_BETWEEN_GETS)

print(f"\nDONE fetching. kept={kept}, skipped={skipped}")
print("Counts:")
print("  meta  :", len(meta_rows))
print("  events:", len(events_rows))
print("  raw   :", len(raw_rows))

if kept == 0:
    raise SystemExit("All records were skipped due to missing shipmentNumber/shipmentDocumentEntityId. Adjust linkage paths or skip rule.")

print("\n====================================================")
print("STEP 3: Drop + recreate bronze tables (overwrite)")
print("====================================================")

# Create Spark DFs
df_meta   = spark.createDataFrame(meta_rows, schema=meta_schema)
df_events = spark.createDataFrame(events_rows, schema=events_schema) if events_rows else spark.createDataFrame([], schema=events_schema)
df_raw    = spark.createDataFrame(raw_rows, schema=raw_schema)

# Drop tables
drop_table_if_exists(TBL_META)
drop_table_if_exists(TBL_EVENTS)
drop_table_if_exists(TBL_RAW)

# Overwrite/create
df_meta.write.format("delta").mode("overwrite").option("overwriteSchema","true").saveAsTable(TBL_META)
df_events.write.format("delta").mode("overwrite").option("overwriteSchema","true").saveAsTable(TBL_EVENTS)
df_raw.write.format("delta").mode("overwrite").option("overwriteSchema","true").saveAsTable(TBL_RAW)

print(f"Recreated tables:\n  {TBL_META}\n  {TBL_EVENTS}\n  {TBL_RAW}")

print("\nSample meta rows (shipment link check):")
df_meta.select("entityId","shipmentNumber","shipmentDocumentEntityId","shipmentDocumentName","modifiedDateUtc","visitStatus").show(10, truncate=False)


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
)

QUERY_ENDPOINT  = "https://api.withvector.com/1.0/entities/query"
RECORD_ENDPOINT = "https://api.withvector.com/1.0/entities/records"

# Fairlife Check-In Execution (this is the execution mixin for Fairlife Facility Check-In)
FAIRLIFE_CHECKIN_EXEC_MIXIN = "b3c99c93-fd6c-466b-bdb6-59950dc31c11"

# Tables (3-table design for bronze)
TBL_CHECKIN_META   = "vector_checkin_meta_bronze"
TBL_CHECKIN_EVENTS = "vector_checkin_events_bronze"
TBL_CHECKIN_FILES  = "vector_checkin_files_bronze"

# Pull last N months by modifiedDate (3 months requested)
MONTHS_BACK = 3

# Pagination + throttling
PAGE_SIZE = 100
SLEEP_BETWEEN_GETS = 0.10
HTTP_TIMEOUT = 60
MAX_GET_RETRIES = 4

HEADERS = {
    "Authorization": f"Bearer {VECTOR_TOKEN}",
    "Content-Type": "application/json",
    "Accept": "application/json",
}

# =========================
# HELPERS
# =========================
def now_utc():
    return datetime.now(timezone.utc)

def now_utc_ts_naive():
    # Spark TimestampType likes naive datetimes
    return datetime.now(timezone.utc).replace(tzinfo=None)

def iso_z(dt: datetime) -> str:
    # Format like 2025-11-02T19:26:04.000Z
    return dt.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.000Z")

def months_back_start(months: int) -> datetime:
    # good-enough "3 months" window without extra deps:
    # 3 months ~= 92 days
    days = int(round(months * 30.67))
    return now_utc() - timedelta(days=days)

from datetime import timedelta

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

def safe_json(resp):
    ctype = (resp.headers.get("content-type") or "").lower()
    if "application/json" in ctype:
        try:
            return resp.json()
        except Exception:
            return None
    return None

def post_query(payload):
    r = requests.post(QUERY_ENDPOINT, headers=HEADERS, json=payload, timeout=HTTP_TIMEOUT)
    if r.status_code != 200:
        print("\n--- QUERY FAILED ---")
        print("HTTP:", r.status_code)
        print("Payload:\n", json.dumps(payload, indent=2)[:4000])
        j = safe_json(r)
        if j is not None:
            print("Response:\n", json.dumps(j, indent=2)[:4000])
        else:
            print("Response text:\n", r.text[:4000])
        r.raise_for_status()
    return r.json()

def get_record(entity_id):
    last_err = None
    for attempt in range(1, MAX_GET_RETRIES + 1):
        try:
            r = requests.get(f"{RECORD_ENDPOINT}/{entity_id}", headers=HEADERS, timeout=HTTP_TIMEOUT)
            if r.status_code != 200:
                # show response and retry a bit
                print(f"GET {entity_id} failed HTTP={r.status_code} attempt={attempt}")
                j = safe_json(r)
                if j is not None:
                    print(json.dumps(j, indent=2)[:2000])
                else:
                    print(r.text[:2000])
                r.raise_for_status()
            return r.json()
        except Exception as e:
            last_err = e
            time.sleep(0.75 * attempt)
    raise last_err

def table_exists(table_name: str) -> bool:
    try:
        spark.table(table_name)
        return True
    except Exception:
        return False

# =========================
# 1) BUILD WORKING PAYLOAD (DATE FILTER SHAPE THAT VECTOR ACCEPTS)
# =========================
def build_checkin_query_payload(offset: int, size: int, date_field: str, start_iso: str, end_iso: str):
    """
    IMPORTANT: Vector's working range filter uses gte/lte at TOP LEVEL (not inside 'value').
    """
    return {
        "filters": [
            {
                "type": "containsEdge",
                "path": "mixins.active",
                "values": [{"entityId": FAIRLIFE_CHECKIN_EXEC_MIXIN}]
            },
            {
                "type": "range",
                "path": date_field,
                "gte": start_iso,
                "lte": end_iso
            }
        ],
        "metadata": {
            "size": size,
            "offset": offset,
            "shouldIncludeLeafEntities": True
        }
    }

def get_total_matches(date_field: str, start_iso: str, end_iso: str) -> int:
    payload = build_checkin_query_payload(offset=0, size=1, date_field=date_field, start_iso=start_iso, end_iso=end_iso)
    resp = post_query(payload)
    md = resp.get("metadata") or {}
    total = md.get("totalEntityMatchCount")
    if not isinstance(total, int):
        # fallback if Vector omits total
        # We'll paginate until empty
        return -1
    return total

def collect_ids_in_window(date_field: str, start_iso: str, end_iso: str, page_size: int):
    total = get_total_matches(date_field, start_iso, end_iso)
    ids = []
    offset = 0

    if total == 0:
        return [], 0

    print(f"Total matches reported by Vector: {total if total >= 0 else '(unknown)'}")

    while True:
        if total >= 0 and offset >= total:
            break

        payload = build_checkin_query_payload(offset=offset, size=page_size, date_field=date_field, start_iso=start_iso, end_iso=end_iso)

        # Avoid the exact “offset way beyond total” shard failure you saw
        if total >= 0 and offset > total:
            break

        resp = post_query(payload)
        children = resp.get("children", []) or []
        if not children:
            break

        for c in children:
            uid = jget(c, "data.uniqueId")
            if uid:
                ids.append(uid)

        offset += page_size

        if offset % (page_size * 10) == 0:
            print(f"  collected IDs: {len(ids)} (offset={offset})")

    # de-dupe preserve order
    seen = set()
    out = []
    for x in ids:
        if x not in seen:
            out.append(x)
            seen.add(x)

    return out, total

# =========================
# 2) PARSERS (META / EVENTS / FILES)
# =========================
def pick_address(addr):
    if not isinstance(addr, dict):
        return {}
    geo = addr.get("geolocation") if isinstance(addr.get("geolocation"), dict) else {}
    return {
        "region":        str(addr.get("region") or ""),
        "locality":      str(addr.get("locality") or ""),
        "postalCode":    str(addr.get("postalCode") or ""),
        "timezoneId":    str(addr.get("timezoneId") or ""),
        "countryName":   str(addr.get("countryName") or ""),
        "streetAddress": str(addr.get("streetAddress") or ""),
        "latitude":      str(geo.get("latitude") or ""),
        "longitude":     str(geo.get("longitude") or ""),
    }

def extract_shipment_linkage(ent: dict):
    """
    Fairlife check-ins: shipment linkage is typically in:
      - core_yms_execution.outbound.shipmentNumber
      - core_yms_execution.outbound.shipmentDocument (edge)
        - denormalizedProperties.document.name
    We also try a couple other places defensively.
    """
    ship_num = (
        jget(ent, "core_yms_execution.outbound.shipmentNumber", "") or
        jget(ent, "core_yms_shipment.shipmentNumber", "") or
        jget(ent, "core_documents_shipment.shipmentNumber", "") or
        ""
    )

    ship_doc = (
        jget(ent, "core_yms_execution.outbound.shipmentDocument", None) or
        jget(ent, "core_yms_shipment.shipmentDocument", None) or
        None
    )

    ship_doc_eid = ""
    ship_doc_name = ""
    ship_doc_docname = ""

    if isinstance(ship_doc, dict):
        ship_doc_eid = str(ship_doc.get("entityId") or "")
        ship_doc_name = str(ship_doc.get("displayName") or "")
        ship_doc_docname = str(jget(ship_doc, "denormalizedProperties.document.name") or "")

    return ship_num, ship_doc_eid, ship_doc_name, ship_doc_docname

def parse_meta(ent: dict, extracted_at):
    ship_num, doc_eid, doc_name, doc_docname = extract_shipment_linkage(ent)

    owner_firm_id = str(jget(ent, "owner.firm.entityId") or "")
    owner_firm_nm = str(jget(ent, "owner.firm.displayName") or "")
    owner_user_id = str(jget(ent, "owner.user.entityId") or "")
    owner_user_nm = str(jget(ent, "owner.user.displayName") or "")

    workflow_status = str(jget(ent, "core_storyboard_execution.status") or "")
    visit_status = str(jget(ent, "core_yms_execution.visit.status") or "")
    needs_attention = str(jget(ent, "fairlife_execution.needsAttentionStatus") or jget(ent, "kraft_heinz_execution.needsAttentionStatus") or "")

    # Location can be at visit.location (older) OR facility.location.address OR createdAt, etc.
    loc = (
        jget(ent, "core_yms_execution.visit.location", None) or
        jget(ent, "basebowl_facility.location.address", None) or
        jget(ent, "core_storyboard_execution.createdAt", None) or
        None
    )
    loc = pick_address(loc)

    driver = jget(ent, "core_yms_execution.driver", {}) or {}
    driver_id = str(driver.get("entityId") or "")
    driver_name = str(driver.get("displayName") or "")
    driver_firm_id = str(jget(driver, "denormalizedProperties.owner.firm.entityId") or "")
    driver_firm_name = str(jget(driver, "denormalizedProperties.owner.firm.displayName") or "")

    # Some useful YMS visit timestamps (these are great for yard KPIs later)
    visit = jget(ent, "core_yms_execution.visit", {}) or {}
    def dt(path):
        return str(jget(visit, path) or "")

    return {
        "entityId": str(ent.get("uniqueId") or ""),
        "shipmentNumber": str(ship_num or ""),
        "shipmentDocumentEntityId": doc_eid,
        "shipmentDocumentName": doc_name,
        "shipmentDocumentDocumentName": doc_docname,

        "creationDateUtc": str(ent.get("creationDate") or ""),
        "modifiedDateUtc": str(ent.get("modifiedDate") or ""),

        "ownerFirmId": owner_firm_id,
        "ownerFirmName": owner_firm_nm,
        "ownerUserId": owner_user_id,
        "ownerUserName": owner_user_nm,

        "createdByUserId": str(jget(ent, "createdBy.entityId") or ""),
        "createdByUserName": str(jget(ent, "createdBy.displayName") or ""),
        "modifiedByUserId": str(jget(ent, "modifiedBy.entityId") or ""),
        "modifiedByUserName": str(jget(ent, "modifiedBy.displayName") or ""),

        "workflowStatus": workflow_status,
        "visitStatus": visit_status,
        "needsAttentionStatus": needs_attention,

        "driverId": driver_id,
        "driverName": driver_name,
        "driverFirmId": driver_firm_id,
        "driverFirmName": driver_firm_name,

        "locationRegion": loc.get("region",""),
        "locationLocality": loc.get("locality",""),
        "locationPostalCode": loc.get("postalCode",""),
        "locationTimezoneId": loc.get("timezoneId",""),
        "locationStreetAddress": loc.get("streetAddress",""),
        "locationCountryName": loc.get("countryName",""),
        "locationLatitude": loc.get("latitude",""),
        "locationLongitude": loc.get("longitude",""),

        # Yard timing signals (not the “yards moved” metric yet, but needed for dwell times)
        "arrivalTime": dt("arrivalTime.dateTime"),
        "checkinTime": dt("checkinTime.dateTime"),
        "gateEntryTime": dt("gateEntryTime.dateTime"),
        "inYardCompleteTime": dt("inYardCompleteTime.dateTime"),
        "gateExitTime": dt("gateExitTime.dateTime"),
        "departureTime": dt("departureTime.dateTime"),

        "extractedAtUtc": extracted_at,
        "rawJson": json.dumps(ent)
    }

def parse_events(ent: dict, extracted_at):
    rows = []
    evs = jget(ent, "core_storyboard_execution.events", []) or []
    if not isinstance(evs, list):
        return rows

    checkin_id = str(ent.get("uniqueId") or "")
    for e in evs:
        if not isinstance(e, dict):
            continue
        rows.append({
            "checkinEntityId": checkin_id,
            "eventId": str(e.get("id") or ""),
            "eventType": str(e.get("eventType") or ""),
            "eventName": str(e.get("name") or ""),
            "eventCreationDateUtc": str(e.get("creationDate") or ""),
            "eventProcessedDateUtc": str(e.get("processedDate") or ""),
            "createdByUserId": str(jget(e, "createdBy.entityId") or ""),
            "createdByUserName": str(jget(e, "createdBy.displayName") or ""),
            "sourceTaskId": str(jget(e, "source.taskId") or ""),
            "sourceSceneId": str(jget(e, "source.sceneId") or ""),
            "sourceStoryId": str(jget(e, "source.storyId") or ""),
            "extractedAtUtc": extracted_at,
            "rawEventJson": json.dumps(e)
        })
    return rows

def parse_files(ent: dict, extracted_at):
    """
    Check-in entities usually don't carry document attachments like BOL docs.
    Keep table for future (if they start attaching photos / gate passes / etc).
    """
    rows = []
    # If Vector ever provides attachments, you can add paths here.
    return rows

def has_linkage(meta_row: dict) -> bool:
    # Skip “empty shipment” records: require at least shipmentNumber OR shipmentDocumentEntityId
    sn = (meta_row.get("shipmentNumber") or "").strip()
    de = (meta_row.get("shipmentDocumentEntityId") or "").strip()
    return (sn != "") or (de != "")

# =========================
# 3) SCHEMAS
# =========================
meta_schema = StructType([
    StructField("entityId", StringType(), False),

    StructField("shipmentNumber", StringType(), True),
    StructField("shipmentDocumentEntityId", StringType(), True),
    StructField("shipmentDocumentName", StringType(), True),
    StructField("shipmentDocumentDocumentName", StringType(), True),

    StructField("creationDateUtc", StringType(), True),
    StructField("modifiedDateUtc", StringType(), True),

    StructField("ownerFirmId", StringType(), True),
    StructField("ownerFirmName", StringType(), True),
    StructField("ownerUserId", StringType(), True),
    StructField("ownerUserName", StringType(), True),

    StructField("createdByUserId", StringType(), True),
    StructField("createdByUserName", StringType(), True),
    StructField("modifiedByUserId", StringType(), True),
    StructField("modifiedByUserName", StringType(), True),

    StructField("workflowStatus", StringType(), True),
    StructField("visitStatus", StringType(), True),
    StructField("needsAttentionStatus", StringType(), True),

    StructField("driverId", StringType(), True),
    StructField("driverName", StringType(), True),
    StructField("driverFirmId", StringType(), True),
    StructField("driverFirmName", StringType(), True),

    StructField("locationRegion", StringType(), True),
    StructField("locationLocality", StringType(), True),
    StructField("locationPostalCode", StringType(), True),
    StructField("locationTimezoneId", StringType(), True),
    StructField("locationStreetAddress", StringType(), True),
    StructField("locationCountryName", StringType(), True),
    StructField("locationLatitude", StringType(), True),
    StructField("locationLongitude", StringType(), True),

    StructField("arrivalTime", StringType(), True),
    StructField("checkinTime", StringType(), True),
    StructField("gateEntryTime", StringType(), True),
    StructField("inYardCompleteTime", StringType(), True),
    StructField("gateExitTime", StringType(), True),
    StructField("departureTime", StringType(), True),

    StructField("extractedAtUtc", TimestampType(), False),
    StructField("rawJson", StringType(), True),
])

events_schema = StructType([
    StructField("checkinEntityId", StringType(), False),
    StructField("eventId", StringType(), True),
    StructField("eventType", StringType(), True),
    StructField("eventName", StringType(), True),
    StructField("eventCreationDateUtc", StringType(), True),
    StructField("eventProcessedDateUtc", StringType(), True),
    StructField("createdByUserId", StringType(), True),
    StructField("createdByUserName", StringType(), True),
    StructField("sourceTaskId", StringType(), True),
    StructField("sourceSceneId", StringType(), True),
    StructField("sourceStoryId", StringType(), True),
    StructField("extractedAtUtc", TimestampType(), False),
    StructField("rawEventJson", StringType(), True),
])

files_schema = StructType([
    StructField("checkinEntityId", StringType(), False),
    StructField("attachmentGroup", StringType(), True),
    StructField("fileUniqueId", StringType(), True),
    StructField("fileName", StringType(), True),
    StructField("fileType", StringType(), True),
    StructField("filePages", IntegerType(), True),
    StructField("fileUri", StringType(), True),
    StructField("previewCount", IntegerType(), True),
    StructField("extractedAtUtc", TimestampType(), False),
    StructField("rawFileJson", StringType(), True),
])

# =========================
# RUN: LAST 3 MONTHS BY modifiedDate
# =========================
end_dt = now_utc()
start_dt = now_utc() - timedelta(days=int(round(MONTHS_BACK * 30.67)))

start_iso = iso_z(start_dt)
end_iso   = iso_z(end_dt)

DATE_FIELD = "modifiedDate"  # Vector supports this in your probe

print("====================================================")
print("STEP 1: Collect check-in entity IDs in window")
print("====================================================")
print(f"Window: {start_iso} -> {end_iso} (by {DATE_FIELD})")

candidate_ids, total = collect_ids_in_window(DATE_FIELD, start_iso, end_iso, PAGE_SIZE)
print(f"\nCollected {len(candidate_ids)} candidate IDs")

if not candidate_ids:
    raise SystemExit("No check-in entities found in the window. Confirm mixin id + token access.")

print("\n====================================================")
print("STEP 2: Fetch records, extract linkage, skip blanks")
print("====================================================")

extracted_at = now_utc_ts_naive()

meta_rows = []
event_rows = []
file_rows = []

kept = 0
skipped = 0

for i, eid in enumerate(candidate_ids, start=1):
    ent = get_record(eid)

    meta = parse_meta(ent, extracted_at)

    if not has_linkage(meta):
        skipped += 1
        # keep throttling but don’t waste more parsing
        if i % 250 == 0:
            print(f"  progress={i}/{len(candidate_ids)} kept={kept} skipped={skipped}")
        time.sleep(SLEEP_BETWEEN_GETS)
        continue

    meta_rows.append(meta)
    event_rows.extend(parse_events(ent, extracted_at))
    file_rows.extend(parse_files(ent, extracted_at))

    kept += 1

    if kept % 250 == 0:
        print(f"  kept={kept} skipped={skipped} last_shipment={meta.get('shipmentNumber','')} last_doc={meta.get('shipmentDocumentDocumentName','')}")

    time.sleep(SLEEP_BETWEEN_GETS)

print(f"\nDONE fetching. kept={kept}, skipped={skipped}")
print(f"Counts:\n  meta={len(meta_rows)}\n  events={len(event_rows)}\n  files={len(file_rows)}")

print("\n====================================================")
print("STEP 3: Create DataFrames")
print("====================================================")

df_meta   = spark.createDataFrame(meta_rows, schema=meta_schema)
df_events = spark.createDataFrame(event_rows, schema=events_schema)
df_files  = spark.createDataFrame(file_rows,  schema=files_schema)

print("df_meta:", df_meta.count())
print("df_events:", df_events.count())
print("df_files:", df_files.count())

print("\n====================================================")
print("STEP 4: Update bronze tables (delete window then append)")
print("====================================================")
delete_start = start_iso
delete_end   = end_iso

# META
if not table_exists(TBL_CHECKIN_META):
    df_meta.write.format("delta").mode("overwrite").saveAsTable(TBL_CHECKIN_META)
else:
    # IMPORTANT: column is modifiedDateUtc (NOT modifiedDate)
    spark.sql(f"""
      DELETE FROM {TBL_CHECKIN_META}
      WHERE modifiedDateUtc >= '{delete_start}' AND modifiedDateUtc <= '{delete_end}'
    """)
    df_meta.write.format("delta").mode("append").option("mergeSchema","true").saveAsTable(TBL_CHECKIN_META)

# EVENTS
if not table_exists(TBL_CHECKIN_EVENTS):
    df_events.write.format("delta").mode("overwrite").saveAsTable(TBL_CHECKIN_EVENTS)
else:
    # delete by joining to meta ids in window is expensive; simplest is delete by extracted json event timestamp window
    # but we don't have reliable event timestamps for all rows. So delete by check-in modifiedDate window using meta table:
    # We'll delete events for checkins whose meta.modifiedDateUtc is in the window.
    spark.sql(f"""
      DELETE FROM {TBL_CHECKIN_EVENTS}
      WHERE checkinEntityId IN (
        SELECT entityId
        FROM {TBL_CHECKIN_META}
        WHERE modifiedDateUtc >= '{delete_start}' AND modifiedDateUtc <= '{delete_end}'
      )
    """)
    df_events.write.format("delta").mode("append").option("mergeSchema","true").saveAsTable(TBL_CHECKIN_EVENTS)

# FILES
if not table_exists(TBL_CHECKIN_FILES):
    df_files.write.format("delta").mode("overwrite").saveAsTable(TBL_CHECKIN_FILES)
else:
    spark.sql(f"""
      DELETE FROM {TBL_CHECKIN_FILES}
      WHERE checkinEntityId IN (
        SELECT entityId
        FROM {TBL_CHECKIN_META}
        WHERE modifiedDateUtc >= '{delete_start}' AND modifiedDateUtc <= '{delete_end}'
      )
    """)
    df_files.write.format("delta").mode("append").option("mergeSchema","true").saveAsTable(TBL_CHECKIN_FILES)

print(f"\n✅ Updated:\n  {TBL_CHECKIN_META}\n  {TBL_CHECKIN_EVENTS}\n  {TBL_CHECKIN_FILES}")


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
)

QUERY_ENDPOINT  = "https://api.withvector.com/1.0/entities/query"
RECORD_ENDPOINT = "https://api.withvector.com/1.0/entities/records"

# NOTE:
# You said "Fair Life Check-In Mixin-ID = 54809ba0-e1c6-46ec-af52-a392803a36b0"
# That ID is "Storyboard Execution" schema/mixin. It CAN still work as a filter if Vector uses it that way.
# If you later find you’re missing check-in records, try setting CHECKIN_MIXIN_ID to:
#   7d2eb17e-9f9d-49c1-8b7f-d55179b3071e  (Kraft Heinz Facility Check-In)
CHECKIN_MIXIN_ID = "54809ba0-e1c6-46ec-af52-a392803a36b0"

# If firm scoping causes issues, set this to None and we won't send firmId
FIRM_ID = None  # example if you want scope: "8ccd57ef-16a5-4b54-acd3-926af17d7139"

# Bronze tables for CHECK-IN (separate from BOL, per your plan)
TBL_CHECKIN_HEADER = "vector_checkin_meta_bronze"
TBL_CHECKIN_EVENTS = "vector_checkin_events_bronze"

MAX_ENTITIES = 1000
PAGE_SIZE    = 50
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

def now_utc_ts():
    return datetime.now(timezone.utc).replace(tzinfo=None)  # Spark TimestampType likes naive

def as_str(x):
    return "" if x is None else str(x)

def extract_shipment_number(entity):
    """
    ShipmentNumber for joining BOL <-> Check-in.
    Based on your sample JSON, the BEST source is:
      core_yms_execution.queries.appointment.request.name
    """
    candidates = [
        "core_yms_execution.queries.appointment.request.name",
        "core_yms_execution.appointment.request.name",
        "core_yms_execution.visit.loadNumber",
        "core_yms_execution.visit.shipmentNumber",
        "core_yms_execution.visit.purchaseOrderNumber",
        "core_storyboard_execution.name",  # not ideal; last fallback
    ]
    for p in candidates:
        v = jget(entity, p)
        if v is not None and str(v).strip() != "":
            return str(v).strip()
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

    # optional firm scope (ONLY if you want it)
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

def parse_checkin_header(entity, extracted_at):
    """
    Header-level fields for reporting + raw JSON for bronze completeness.
    IMPORTANT: shipmentNumber is included.
    """
    shipment_number = extract_shipment_number(entity)

    return {
        "entityId": as_str(entity.get("uniqueId")),
        "shipmentNumber": shipment_number,

        "creationDateUtc": as_str(entity.get("creationDate")),
        "modifiedDateUtc": as_str(entity.get("modifiedDate")),

        "ownerFirmId": as_str(jget(entity, "owner.firm.entityId")),
        "ownerFirmName": as_str(jget(entity, "owner.firm.displayName")),
        "ownerUserId": as_str(jget(entity, "owner.user.entityId")),
        "ownerUserName": as_str(jget(entity, "owner.user.displayName")),

        "createdByUserId": as_str(jget(entity, "createdBy.entityId")),
        "createdByUserName": as_str(jget(entity, "createdBy.displayName")),
        "modifiedByUserId": as_str(jget(entity, "modifiedBy.entityId")),
        "modifiedByUserName": as_str(jget(entity, "modifiedBy.displayName")),

        # useful check-in status
        "workflowStatus": as_str(jget(entity, "core_storyboard_execution.status")),
        "visitStatus": as_str(jget(entity, "core_yms_execution.visit.status")),
        "needsAttentionStatus": as_str(jget(entity, "kraft_heinz_execution.needsAttentionStatus")),

        # driver
        "driverId": as_str(jget(entity, "core_yms_execution.driver.entityId")),
        "driverName": as_str(jget(entity, "core_yms_execution.driver.displayName")),
        "driverFirmId": as_str(jget(entity, "core_yms_execution.driver.denormalizedProperties.owner.firm.entityId")),
        "driverFirmName": as_str(jget(entity, "core_yms_execution.driver.denormalizedProperties.owner.firm.displayName")),

        # location (from visit.location)
        "locationRegion": as_str(jget(entity, "core_yms_execution.visit.location.region")),
        "locationLocality": as_str(jget(entity, "core_yms_execution.visit.location.locality")),
        "locationPostalCode": as_str(jget(entity, "core_yms_execution.visit.location.postalCode")),
        "locationTimezoneId": as_str(jget(entity, "core_yms_execution.visit.location.timezoneId")),
        "locationStreetAddress": as_str(jget(entity, "core_yms_execution.visit.location.streetAddress")),
        "locationLatitude": as_str(jget(entity, "core_yms_execution.visit.location.geolocation.latitude")),
        "locationLongitude": as_str(jget(entity, "core_yms_execution.visit.location.geolocation.longitude")),

        "extractedAtUtc": extracted_at,
        "rawJson": json.dumps(entity)
    }

def parse_checkin_events(entity, extracted_at):
    """
    Explode core_storyboard_execution.events to event rows.
    IMPORTANT: shipmentNumber is included on each event row for easy joins.
    """
    shipment_number = extract_shipment_number(entity)
    entity_id = as_str(entity.get("uniqueId"))

    events = jget(entity, "core_storyboard_execution.events", []) or []
    out = []
    if not isinstance(events, list):
        return out

    for e in events:
        if not isinstance(e, dict):
            continue

        out.append({
            "entityId": entity_id,
            "shipmentNumber": shipment_number,

            "eventId": as_str(e.get("id")),
            "eventType": as_str(e.get("eventType")),
            "eventName": as_str(e.get("name")),
            "creationDateUtc": as_str(e.get("creationDate")),
            "processedDateUtc": as_str(e.get("processedDate")),

            "createdByUserId": as_str(jget(e, "createdBy.entityId")),
            "createdByUserName": as_str(jget(e, "createdBy.displayName")),

            # source
            "sourceStoryId": as_str(jget(e, "source.storyId")),
            "sourceSceneId": as_str(jget(e, "source.sceneId")),
            "sourceTaskId": as_str(jget(e, "source.taskId")),

            # mapping destination(s) (store as string for bronze)
            "outputMappingsJson": json.dumps(e.get("outputMappings")) if e.get("outputMappings") is not None else "",

            "extractedAtUtc": extracted_at
        })

    return out

# =========================
# EXPLICIT SCHEMAS
# =========================
checkin_header_schema = StructType([
    StructField("entityId", StringType(), False),
    StructField("shipmentNumber", StringType(), True),

    StructField("creationDateUtc", StringType(), True),
    StructField("modifiedDateUtc", StringType(), True),

    StructField("ownerFirmId", StringType(), True),
    StructField("ownerFirmName", StringType(), True),
    StructField("ownerUserId", StringType(), True),
    StructField("ownerUserName", StringType(), True),

    StructField("createdByUserId", StringType(), True),
    StructField("createdByUserName", StringType(), True),
    StructField("modifiedByUserId", StringType(), True),
    StructField("modifiedByUserName", StringType(), True),

    StructField("workflowStatus", StringType(), True),
    StructField("visitStatus", StringType(), True),
    StructField("needsAttentionStatus", StringType(), True),

    StructField("driverId", StringType(), True),
    StructField("driverName", StringType(), True),
    StructField("driverFirmId", StringType(), True),
    StructField("driverFirmName", StringType(), True),

    StructField("locationRegion", StringType(), True),
    StructField("locationLocality", StringType(), True),
    StructField("locationPostalCode", StringType(), True),
    StructField("locationTimezoneId", StringType(), True),
    StructField("locationStreetAddress", StringType(), True),
    StructField("locationLatitude", StringType(), True),
    StructField("locationLongitude", StringType(), True),

    StructField("extractedAtUtc", TimestampType(), False),
    StructField("rawJson", StringType(), True),
])

checkin_events_schema = StructType([
    StructField("entityId", StringType(), False),
    StructField("shipmentNumber", StringType(), True),

    StructField("eventId", StringType(), True),
    StructField("eventType", StringType(), True),
    StructField("eventName", StringType(), True),
    StructField("creationDateUtc", StringType(), True),
    StructField("processedDateUtc", StringType(), True),

    StructField("createdByUserId", StringType(), True),
    StructField("createdByUserName", StringType(), True),

    StructField("sourceStoryId", StringType(), True),
    StructField("sourceSceneId", StringType(), True),
    StructField("sourceTaskId", StringType(), True),

    StructField("outputMappingsJson", StringType(), True),

    StructField("extractedAtUtc", TimestampType(), False),
])

# =========================
# QUICK PROBE (1 RECORD) - optional but useful
# =========================
# Put any known check-in UUID here to validate shipment extraction
PROBE_ENTITY_ID = None  # e.g. "30ea9894-afc4-47d1-973e-411b802df628"

if PROBE_ENTITY_ID:
    probe = get_record(PROBE_ENTITY_ID)
    print("Probe entityId:", probe.get("uniqueId"))
    print("Extracted shipmentNumber:", extract_shipment_number(probe))
    print("Path core_yms_execution.queries.appointment.request.name:",
          jget(probe, "core_yms_execution.queries.appointment.request.name"))

# =========================
# RUN - FETCH N IDS -> GET RECORDS -> PARSE -> WRITE
# =========================
print(f"Fetching up to {MAX_ENTITIES} Check-In document IDs...")
entity_ids = fetch_first_n_ids(n=MAX_ENTITIES, page_size=PAGE_SIZE)
print(f"Found {len(entity_ids)} IDs")

if not entity_ids:
    raise SystemExit("No entities returned. Token/mixinId/tenant access issue.")

extracted_at = now_utc_ts()

header_rows = []
event_rows  = []

print("Fetching full JSON records and parsing...")
for idx, eid in enumerate(entity_ids, start=1):
    ent = get_record(eid)
    header_rows.append(parse_checkin_header(ent, extracted_at))
    event_rows.extend(parse_checkin_events(ent, extracted_at))

    if idx % 50 == 0:
        print(f"  parsed {idx}/{len(entity_ids)}")
    time.sleep(SLEEP_BETWEEN_GETS)

df_header = spark.createDataFrame(header_rows, schema=checkin_header_schema)
df_events = spark.createDataFrame(event_rows,  schema=checkin_events_schema)

print("Header rows:", df_header.count())
print("Event rows:", df_events.count())

# =========================
# WRITE TO BRONZE TABLES
# =========================
# Use mergeSchema so adding shipmentNumber doesn't blow up existing tables.
# If you want a clean reset, you can DROP TABLE first (commented below).
#
# spark.sql(f"DROP TABLE IF EXISTS {TBL_CHECKIN_HEADER}")
# spark.sql(f"DROP TABLE IF EXISTS {TBL_CHECKIN_EVENTS}")

df_header.write.format("delta").mode("append").option("mergeSchema", "true").saveAsTable(TBL_CHECKIN_HEADER)
df_events.write.format("delta").mode("append").option("mergeSchema", "true").saveAsTable(TBL_CHECKIN_EVENTS)

print(f"Appended to {TBL_CHECKIN_HEADER} and {TBL_CHECKIN_EVENTS}")


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

import requests, json, time
from datetime import datetime, timezone, timedelta

from pyspark.sql.types import (
    StructType, StructField, StringType, BooleanType, IntegerType, TimestampType
)
from pyspark.sql import functions as F

# =====================================================
# CONFIG
# =====================================================
from notebookutils import mssparkutils

# --- Read secrets from Azure Key Vault ---
VECTOR_TOKEN = mssparkutils.credentials.getSecret(
    "https://keyvault-fabric2.vault.azure.net/",
    "VECTORTOKEN"
)

QUERY_ENDPOINT  = "https://api.withvector.com/1.0/entities/query"
RECORD_ENDPOINT = "https://api.withvector.com/1.0/entities/records"

# Fairlife Facility Check-In mixin (you provided)
FAIRLIFE_CHECKIN_MIXIN = "b3c99c93-fd6c-466b-bdb6-59950dc31c11"

# Bronze tables (3 tables)
TBL_CHECKIN_META   = "vector_checkin_meta_bronze"
TBL_CHECKIN_EVENTS = "vector_checkin_events_bronze"
TBL_CHECKIN_FILES  = "vector_checkin_attachments_bronze"

# Pull window
MONTHS_BACK = 3

# Query / paging
PAGE_SIZE = 100
MAX_IDS   = 50000   # safety cap; adjust if you want

# GET throttling
SLEEP_BETWEEN_GETS = 0.12

HEADERS = {
    "Authorization": f"Bearer {VECTOR_TOKEN}",
    "Content-Type": "application/json",
    "Accept": "application/json",
}

# =====================================================
# HELPERS
# =====================================================
def now_utc_ts():
    # Spark TimestampType likes naive
    return datetime.now(timezone.utc).replace(tzinfo=None)

def iso_z(dt: datetime) -> str:
    # ensure UTC Z
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    return dt.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.000Z")

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

def find_paths_with_key(obj, key_name, prefix=""):
    """
    Finds JSON paths where a key exists. Used for debugging/probing.
    """
    paths = []
    if isinstance(obj, dict):
        for k, v in obj.items():
            p = f"{prefix}.{k}" if prefix else k
            if k == key_name:
                paths.append(p)
            paths.extend(find_paths_with_key(v, key_name, p))
    elif isinstance(obj, list):
        for i, v in enumerate(obj):
            p = f"{prefix}[{i}]"
            paths.extend(find_paths_with_key(v, key_name, p))
    return paths

def post_query(payload, timeout=60):
    r = requests.post(QUERY_ENDPOINT, headers=HEADERS, json=payload, timeout=timeout)
    ct = (r.headers.get("content-type") or "").lower()
    if r.status_code != 200:
        print("\n--- QUERY FAILED ---")
        print("HTTP:", r.status_code)
        print("Payload:\n", json.dumps(payload, indent=2)[:4000])
        if "application/json" in ct:
            try:
                print("Response:\n", json.dumps(r.json(), indent=2)[:4000])
            except Exception:
                print("Response text:\n", r.text[:4000])
        else:
            print("Response text:\n", r.text[:4000])
        return None, r.status_code, r.text
    return r.json(), r.status_code, None

def get_record(entity_id, timeout=60):
    r = requests.get(f"{RECORD_ENDPOINT}/{entity_id}", headers=HEADERS, timeout=timeout)
    r.raise_for_status()
    return r.json()

# =====================================================
# DATE-FILTER PAYLOAD BUILDER (auto-tries shapes)
# =====================================================
def build_payload_candidates(start_z, end_z, size, offset, date_field):
    """
    Vector's filter grammar is picky. We'll try a few shapes.
    We keep the mixin filter AND the date filter.
    """
    base = {
        "filters": [
            {
                "type": "containsEdge",
                "path": "mixins.active",
                "values": [{"entityId": FAIRLIFE_CHECKIN_MIXIN}]
            }
        ],
        "metadata": {
            "size": size,
            "offset": offset,
            "shouldIncludeLeafEntities": True
        }
    }

    # Candidate 1: range with gte/lte at top-level (this fixes the exact error you got)
    p1 = json.loads(json.dumps(base))
    p1["filters"].append({
        "type": "range",
        "path": date_field,
        "gte": start_z,
        "lte": end_z
    })

    # Candidate 2: two separate comparisons (sometimes works on systems that don't like range)
    p2 = json.loads(json.dumps(base))
    p2["filters"].append({"type": "gte", "path": date_field, "value": start_z})
    p2["filters"].append({"type": "lte", "path": date_field, "value": end_z})

    # Candidate 3: range but with gt/lt
    p3 = json.loads(json.dumps(base))
    p3["filters"].append({
        "type": "range",
        "path": date_field,
        "gt": start_z,
        "lt": end_z
    })

    return [p1, p2, p3]

def find_working_date_payload(start_z, end_z, size=10, offset=0):
    """
    Try modifiedDate first, then creationDate.
    Returns (working_date_field, working_payload_template)
    """
    for date_field in ["modifiedDate", "creationDate"]:
        candidates = build_payload_candidates(start_z, end_z, size, offset, date_field)
        for i, payload in enumerate(candidates, start=1):
            resp, status, _ = post_query(payload)
            if status == 200 and isinstance(resp, dict):
                print(f"✅ Working date filter: date_field={date_field}, candidate#{i}")
                return date_field, payload
    raise RuntimeError("No working date filter payload found (modifiedDate/creationDate).")

# =====================================================
# EXTRACT SHIPMENT/BOL LINKAGE (CHECK-IN JSON)
# =====================================================
def extract_shipment_link(ent: dict) -> dict:
    """
    In your sample, linkage is under:
      core_yms_execution.outbound.shipmentNumber
      core_yms_execution.outbound.shipmentDocument.{entityId,displayName,denormalizedProperties.document.name}
    We'll also check a couple other likely paths.
    """
    # shipment number candidates (priority order)
    ship_num = (
        jget(ent, "core_yms_execution.outbound.shipmentNumber") or
        jget(ent, "core_yms_shipment.shipmentNumber") or
        jget(ent, "core_documents_shipment.shipmentNumber") or
        ""
    )

    # shipmentDocument edge candidates
    doc = (
        jget(ent, "core_yms_execution.outbound.shipmentDocument") or
        jget(ent, "core_yms_shipment.shipmentDocument") or
        {}
    )
    doc_eid  = str(jget(doc, "entityId") or "")
    doc_name = str(jget(doc, "displayName") or "")
    doc_docname = str(jget(doc, "denormalizedProperties.document.name") or "")

    return {
        "shipmentNumber": str(ship_num or ""),
        "shipmentDocumentEntityId": doc_eid,
        "shipmentDocumentName": doc_name,
        "shipmentDocumentDocumentName": doc_docname
    }

def should_keep(ent: dict) -> bool:
    link = extract_shipment_link(ent)
    # Skip records with no usable linkage (you asked to skip blanks)
    if not link["shipmentNumber"]:
        return False
    # If you want to allow shipmentNumber-only records, comment this block out:
    if (not link["shipmentDocumentEntityId"]) and (not link["shipmentDocumentName"]) and (not link["shipmentDocumentDocumentName"]):
        return False
    return True

# =====================================================
# ATTACHMENTS (best-effort: scan a few known places)
# =====================================================
def collect_attachments(ent: dict, extracted_at):
    rows = []

    def add_files(group_name, files):
        if not isinstance(files, list):
            return
        for f in files:
            if not isinstance(f, dict):
                continue
            previews = f.get("preview") if isinstance(f.get("preview"), list) else []
            rows.append({
                "checkinEntityId": str(ent.get("uniqueId") or ""),
                "attachmentGroup": group_name,
                "fileUniqueId": str(f.get("uniqueId") or ""),
                "fileName": str(f.get("name") or ""),
                "fileType": str(f.get("type") or ""),
                "filePages": int(f.get("pages") or 0),
                "fileUri": str(f.get("uri") or ""),
                "previewCount": int(len(previews)),
                "extractedAtUtc": extracted_at
            })

    # common locations
    add_files("document.attachments.files", jget(ent, "document.attachments.files", []))
    add_files("core_yms_execution.attachments.files", jget(ent, "core_yms_execution.attachments.files", []))

    # sometimes outbound/inbound may have doc blobs
    add_files("core_yms_execution.outbound.attachments.files", jget(ent, "core_yms_execution.outbound.attachments.files", []))
    add_files("core_yms_execution.inbound.attachments.files", jget(ent, "core_yms_execution.inbound.attachments.files", []))

    return rows

# =====================================================
# FLATTEN EVENTS (for yard/task timeline reporting)
# =====================================================
def flatten_events(ent: dict, extracted_at):
    out = []
    evs = jget(ent, "core_storyboard_execution.events", []) or []
    if not isinstance(evs, list):
        return out

    for e in evs:
        if not isinstance(e, dict):
            continue
        out.append({
            "checkinEntityId": str(ent.get("uniqueId") or ""),
            "eventId": str(e.get("id") or ""),
            "eventType": str(e.get("eventType") or ""),
            "eventName": str(e.get("name") or ""),
            "creationDateUtc": str(e.get("creationDate") or ""),
            "processedDateUtc": str(e.get("processedDate") or ""),
            "sourceStoryId": str(jget(e, "source.storyId") or ""),
            "sourceSceneId": str(jget(e, "source.sceneId") or ""),
            "sourceTaskId": str(jget(e, "source.taskId") or ""),
            "createdByUserId": str(jget(e, "createdBy.entityId") or ""),
            "createdByUserName": str(jget(e, "createdBy.displayName") or ""),
            "extractedAtUtc": extracted_at
        })
    return out

# =====================================================
# BUILD CHECK-IN META ROW
# =====================================================
def parse_checkin_meta(ent: dict, extracted_at):
    link = extract_shipment_link(ent)

    return {
        "checkinEntityId": str(ent.get("uniqueId") or ""),
        "creationDate": str(ent.get("creationDate") or ""),
        "modifiedDate": str(ent.get("modifiedDate") or ""),
        "ownerFirmId": str(jget(ent, "owner.firm.entityId") or ""),
        "ownerFirmName": str(jget(ent, "owner.firm.displayName") or ""),
        "ownerUser": str(jget(ent, "owner.user.displayName") or ""),
        "shipmentNumber": link["shipmentNumber"],
        "shipmentDocumentEntityId": link["shipmentDocumentEntityId"],
        "shipmentDocumentName": link["shipmentDocumentName"],
        "shipmentDocumentDocumentName": link["shipmentDocumentDocumentName"],
        "visitStatus": str(jget(ent, "core_yms_execution.visit.status") or ""),
        "extractedAtUtc": extracted_at,
        "rawJson": json.dumps(ent)
    }

# =====================================================
# SCHEMAS (explicit)
# =====================================================
checkin_meta_schema = StructType([
    StructField("checkinEntityId", StringType(), False),
    StructField("creationDate", StringType(), True),
    StructField("modifiedDate", StringType(), True),
    StructField("ownerFirmId", StringType(), True),
    StructField("ownerFirmName", StringType(), True),
    StructField("ownerUser", StringType(), True),

    StructField("shipmentNumber", StringType(), True),
    StructField("shipmentDocumentEntityId", StringType(), True),
    StructField("shipmentDocumentName", StringType(), True),
    StructField("shipmentDocumentDocumentName", StringType(), True),

    StructField("visitStatus", StringType(), True),

    StructField("extractedAtUtc", TimestampType(), False),
    StructField("rawJson", StringType(), True),
])

events_schema = StructType([
    StructField("checkinEntityId", StringType(), False),
    StructField("eventId", StringType(), True),
    StructField("eventType", StringType(), True),
    StructField("eventName", StringType(), True),
    StructField("creationDateUtc", StringType(), True),
    StructField("processedDateUtc", StringType(), True),
    StructField("sourceStoryId", StringType(), True),
    StructField("sourceSceneId", StringType(), True),
    StructField("sourceTaskId", StringType(), True),
    StructField("createdByUserId", StringType(), True),
    StructField("createdByUserName", StringType(), True),
    StructField("extractedAtUtc", TimestampType(), False),
])

files_schema = StructType([
    StructField("checkinEntityId", StringType(), False),
    StructField("attachmentGroup", StringType(), True),
    StructField("fileUniqueId", StringType(), True),
    StructField("fileName", StringType(), True),
    StructField("fileType", StringType(), True),
    StructField("filePages", IntegerType(), True),
    StructField("fileUri", StringType(), True),
    StructField("previewCount", IntegerType(), True),
    StructField("extractedAtUtc", TimestampType(), False),
])

# =====================================================
# STEP 1: Find working payload for last 3 months
# =====================================================
end_dt   = datetime.now(timezone.utc)
start_dt = end_dt - timedelta(days=MONTHS_BACK * 30)

start_z = iso_z(start_dt)
end_z   = iso_z(end_dt)

print("====================================================")
print("STEP 1: Find a working query payload for date filtering")
print("====================================================")
date_field, working_payload = find_working_date_payload(start_z, end_z, size=10, offset=0)

# We'll reuse it, swapping offset/size
def query_page(offset, size):
    p = json.loads(json.dumps(working_payload))
    p["metadata"]["offset"] = int(offset)
    p["metadata"]["size"] = int(size)
    return p

print("\nUsing window:", start_z, "->", end_z)
print("Using date field:", date_field)

# =====================================================
# STEP 2: Collect IDs
# =====================================================
print("\n====================================================")
print("STEP 2: Collect check-in entity IDs in window")
print("====================================================")

ids = []
offset = 0

while len(ids) < MAX_IDS:
    payload = query_page(offset, PAGE_SIZE)
    resp, status, _ = post_query(payload)
    if status != 200 or not resp:
        break

    children = resp.get("children", []) or []
    if not children:
        break

    for c in children:
        uid = jget(c, "data.uniqueId")
        if uid:
            ids.append(uid)

    offset += PAGE_SIZE

    md = resp.get("metadata") or {}
    total = md.get("totalEntityMatchCount")
    if isinstance(total, int) and offset >= total:
        break

# de-dupe
seen = set()
entity_ids = []
for x in ids:
    if x not in seen:
        entity_ids.append(x)
        seen.add(x)

print(f"Found {len(entity_ids)} candidate IDs (pre-filter)")

if not entity_ids:
    raise SystemExit("No check-ins returned for the date window. Confirm mixin/date filter.")

# =====================================================
# STEP 3: Fetch JSON, SKIP junk, build rows
# =====================================================
print("\n====================================================")
print("STEP 3: Fetch records, extract linkage, skip blanks")
print("====================================================")

extracted_at = now_utc_ts()

meta_rows  = []
event_rows = []
file_rows  = []

kept = 0
skipped = 0

for i, eid in enumerate(entity_ids, start=1):
    ent = get_record(eid)

    if not should_keep(ent):
        skipped += 1
        continue

    kept += 1
    meta_rows.append(parse_checkin_meta(ent, extracted_at))
    event_rows.extend(flatten_events(ent, extracted_at))
    file_rows.extend(collect_attachments(ent, extracted_at))

    if kept % 50 == 0:
        sample = meta_rows[-1]
        print(f"  kept={kept} skipped={skipped} last_shipment={sample['shipmentNumber']} last_doc={sample['shipmentDocumentDocumentName']}")
    time.sleep(SLEEP_BETWEEN_GETS)

print(f"\nDONE fetching. kept={kept}, skipped={skipped}")
if kept == 0:
    raise SystemExit("All records were skipped (no shipmentNumber/doc linkage found). Relax should_keep() logic.")

df_meta  = spark.createDataFrame(meta_rows,  schema=checkin_meta_schema)
df_evts  = spark.createDataFrame(event_rows, schema=events_schema) if event_rows else spark.createDataFrame([], schema=events_schema)
df_files = spark.createDataFrame(file_rows,  schema=files_schema)  if file_rows  else spark.createDataFrame([], schema=files_schema)

print("\nCounts:")
print("  meta :", df_meta.count())
print("  events:", df_evts.count())
print("  files :", df_files.count())

# =====================================================
# STEP 4: Update last-3-months slice in 3 bronze tables
# (delete window then append)
# =====================================================
print("\n====================================================")
print("STEP 4: Update bronze tables (delete window then append)")
print("====================================================")

# Make sure tables exist; if not, create them with overwrite
def table_exists(tbl):
    try:
        spark.table(tbl)
        return True
    except Exception:
        return False

# Delete window bounds use string ISO dates; works fine with ISO Z
# We delete on modifiedDate for meta and events/files (they get extractedAtUtc same batch)
delete_start = start_z
delete_end   = end_z

if not table_exists(TBL_CHECKIN_META):
    df_meta.write.format("delta").mode("overwrite").saveAsTable(TBL_CHECKIN_META)
else:
    spark.sql(f"""
      DELETE FROM {TBL_CHECKIN_META}
      WHERE modifiedDate >= '{delete_start}' AND modifiedDate <= '{delete_end}'
    """)
    df_meta.write.format("delta").mode("append").option("mergeSchema","true").saveAsTable(TBL_CHECKIN_META)

if not table_exists(TBL_CHECKIN_EVENTS):
    df_evts.write.format("delta").mode("overwrite").saveAsTable(TBL_CHECKIN_EVENTS)
else:
    # safest delete by extractedAtUtc window is messy; use checkinEntityId set if you want exact.
    # Here we delete by event creationDateUtc window when present, fallback to append.
    spark.sql(f"""
      DELETE FROM {TBL_CHECKIN_EVENTS}
      WHERE creationDateUtc >= '{delete_start}' AND creationDateUtc <= '{delete_end}'
    """)
    df_evts.write.format("delta").mode("append").option("mergeSchema","true").saveAsTable(TBL_CHECKIN_EVENTS)

if not table_exists(TBL_CHECKIN_FILES):
    df_files.write.format("delta").mode("overwrite").saveAsTable(TBL_CHECKIN_FILES)
else:
    # delete is hard because files don't have creationDate from source; use meta IDs approach.
    # We'll delete rows for the checkin IDs we just loaded (clean + exact).
    df_meta.select("checkinEntityId").distinct().createOrReplaceTempView("tmp_checkin_ids")
    spark.sql(f"""
      DELETE FROM {TBL_CHECKIN_FILES}
      WHERE checkinEntityId IN (SELECT checkinEntityId FROM tmp_checkin_ids)
    """)
    df_files.write.format("delta").mode("append").option("mergeSchema","true").saveAsTable(TBL_CHECKIN_FILES)

print(f"✅ Updated tables:\n  {TBL_CHECKIN_META}\n  {TBL_CHECKIN_EVENTS}\n  {TBL_CHECKIN_FILES}")

# =====================================================
# QUICK PROBE OUTPUT (top 20 for sanity)
# =====================================================
print("\nSample rows (meta):")
df_meta.select(
    "checkinEntityId","creationDate","modifiedDate","ownerFirmName","ownerUser",
    "shipmentNumber","shipmentDocumentDocumentName","visitStatus"
).orderBy(F.col("modifiedDate").desc()).show(20, truncate=False)


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

import requests, json, time
from datetime import datetime, timezone, timedelta

# ====================================================
# CONFIG
# ====================================================
from notebookutils import mssparkutils

# --- Read secrets from Azure Key Vault ---
VECTOR_TOKEN = mssparkutils.credentials.getSecret(
    "https://keyvault-fabric2.vault.azure.net/",
    "VECTORTOKEN"
)

QUERY_ENDPOINT  = "https://api.withvector.com/1.0/entities/query"
RECORD_ENDPOINT = "https://api.withvector.com/1.0/entities/records"

# This is the mixin you actually need for Check-In records (from your probe output):
# mixins.active includes ('Fairlife Facility Check-In', 'b3c99c93-fd6c-466b-bdb6-59950dc31c11')
FAIRLIFE_CHECKIN_MIXIN = "b3c99c93-fd6c-466b-bdb6-59950dc31c11"

MAX_ENTITIES = 1000
PAGE_SIZE    = 50
SLEEP_BETWEEN_GETS = 0.10  # be gentle

HEADERS = {
    "Authorization": f"Bearer {VECTOR_TOKEN}",
    "Content-Type": "application/json",
    "Accept": "application/json",
}

# ====================================================
# HELPERS
# ====================================================
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

def iso_z(dt):
    # Vector uses Z timestamps
    return dt.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.000Z")

def utc_now():
    return datetime.now(timezone.utc)

def post_query(payload, timeout=60):
    r = requests.post(QUERY_ENDPOINT, headers=HEADERS, json=payload, timeout=timeout)
    ct = (r.headers.get("content-type") or "").lower()

    # Return structured error info instead of crashing
    if r.status_code != 200:
        out = {"__http_status": r.status_code, "__text": r.text}
        if "application/json" in ct:
            try:
                out["__json"] = r.json()
            except Exception:
                out["__json"] = None
        return out

    return r.json()

def get_record(entity_id, timeout=60):
    r = requests.get(f"{RECORD_ENDPOINT}/{entity_id}", headers=HEADERS, timeout=timeout)
    r.raise_for_status()
    return r.json()

def build_payload(offset, size, date_field=None, start_iso=None, end_iso=None):
    """
    Builds a Vector /entities/query payload:
      - Filter by check-in mixin
      - Optional date range filter on createdDate/modifiedDate
    """
    filters = [
        {
            "type": "containsEdge",
            "path": "mixins.active",
            "values": [{"entityId": FAIRLIFE_CHECKIN_MIXIN}]
        }
    ]

    # If date filter requested, attach it
    if date_field and start_iso and end_iso:
        # ✅ Working shape (no nested "value")
        filters.append({
            "type": "range",
            "path": date_field,     # "creationDate" or "modifiedDate"
            "gte": start_iso,
            "lte": end_iso
        })

    payload = {
        "filters": filters,
        "metadata": {
            "size": size,
            "offset": offset,
            "shouldIncludeLeafEntities": True
        }
    }
    return payload

def try_find_working_date_filter(window_start_iso, window_end_iso, size=10, offset=0):
    """
    Tries creationDate and modifiedDate using the "range" filter shape that Vector expects.
    Returns (working_date_field, sample_resp, sample_payload) or (None, None, None)
    """
    candidates = ["modifiedDate", "creationDate"]

    for field in candidates:
        payload = build_payload(offset=offset, size=size,
                                date_field=field,
                                start_iso=window_start_iso,
                                end_iso=window_end_iso)
        resp = post_query(payload)
        if isinstance(resp, dict) and resp.get("__http_status"):
            print(f"Date filter failed for {field}. HTTP {resp['__http_status']}")
            j = resp.get("__json")
            if j:
                print(json.dumps(j, indent=2)[:2000])
            else:
                print(resp.get("__text","")[:2000])
            continue

        # Success if it returns children list
        if isinstance(resp, dict) and "children" in resp:
            return field, resp, payload

    return None, None, None

def extract_linkage_fields(ent):
    """
    Pull ShipmentNumber + BOL/ShipmentDocument info from the places you observed.
    Primary (from your probe output):
      core_yms_execution.outbound.shipmentNumber
      core_yms_execution.outbound.shipmentDocument.{entityId,displayName,denormalizedProperties.document.name}
    Fallbacks included for safety.
    """
    ship_no = (
        (jget(ent, "core_yms_execution.outbound.shipmentNumber") or "").strip()
        or (jget(ent, "core_yms_shipment.shipmentNumber") or "").strip()
        or (jget(ent, "core_documents_shipment.shipmentNumber") or "").strip()
    )

    doc_edge = (
        jget(ent, "core_yms_execution.outbound.shipmentDocument")
        or jget(ent, "core_yms_shipment.shipmentDocument")
        or {}
    )

    doc_id = (jget(doc_edge, "entityId") or "").strip()
    doc_name = (jget(doc_edge, "displayName") or "").strip()
    doc_document_name = (jget(doc_edge, "denormalizedProperties.document.name") or "").strip()

    # If displayName missing but document.name exists, use it as a friendly label
    if (not doc_name) and doc_document_name:
        doc_name = doc_document_name

    return {
        "checkinEntityId": (ent.get("uniqueId") or "").strip(),
        "creationDate": (ent.get("creationDate") or "").strip(),
        "modifiedDate": (ent.get("modifiedDate") or "").strip(),
        "ownerFirmId": (jget(ent, "owner.firm.entityId") or "").strip(),
        "ownerFirmName": (jget(ent, "owner.firm.displayName") or "").strip(),
        "ownerUser": (jget(ent, "owner.user.displayName") or "").strip(),
        "shipmentNumber": ship_no,
        "shipmentDocumentEntityId": doc_id,
        "shipmentDocumentName": doc_name,
        "shipmentDocumentDocumentName": doc_document_name
    }

def is_empty_linkage(x):
    # Skip records with no linkage
    return (not x.get("shipmentNumber")) and (not x.get("shipmentDocumentEntityId"))

# ====================================================
# STEP 0: Date window (last 2 months)
# ====================================================
end_dt = utc_now()
start_dt = end_dt - timedelta(days=60)

window_start_iso = iso_z(start_dt)
window_end_iso   = iso_z(end_dt)

print("====================================================")
print("STEP 1: Find working date filter (created/modified) for last 2 months")
print("====================================================")
print(f"Window: {window_start_iso} -> {window_end_iso}")

date_field, sample_resp, sample_payload = try_find_working_date_filter(
    window_start_iso, window_end_iso, size=10, offset=0
)

if not date_field:
    raise SystemExit("No working date filter found for creationDate/modifiedDate. Keep querying without date filter OR inspect API docs.")

print("\n✅ Working date filter field:", date_field)
print("✅ Working payload shape you can reuse (example):")
print(json.dumps(sample_payload, indent=2))

# ====================================================
# STEP 2: Fetch up to MAX_ENTITIES check-in IDs within the window
# ====================================================
print("\n====================================================")
print(f"STEP 2: Fetch up to {MAX_ENTITIES} check-in IDs using {date_field} window")
print("====================================================")

entity_ids = []
offset = 0

while len(entity_ids) < MAX_ENTITIES:
    size = min(PAGE_SIZE, MAX_ENTITIES - len(entity_ids))
    payload = build_payload(
        offset=offset,
        size=size,
        date_field=date_field,
        start_iso=window_start_iso,
        end_iso=window_end_iso
    )

    resp = post_query(payload)

    if isinstance(resp, dict) and resp.get("__http_status"):
        print("\n----- QUERY ERROR -----")
        print("Payload:", json.dumps(payload, indent=2)[:2000])
        j = resp.get("__json")
        if j:
            print("Response:", json.dumps(j, indent=2)[:2000])
        else:
            print("Response text:", (resp.get("__text") or "")[:2000])
        break

    children = resp.get("children", []) or []
    if not children:
        break

    for c in children:
        uid = jget(c, "data.uniqueId")
        if uid:
            entity_ids.append(uid)

    offset += size

    md = resp.get("metadata") or {}
    total = md.get("totalEntityMatchCount")
    if isinstance(total, int) and offset >= total:
        break

print(f"Fetched IDs: {len(entity_ids)}")

if not entity_ids:
    raise SystemExit("0 IDs returned for last 2 months. Either no data in window, or date filter excludes everything.")

# De-dupe while preserving order
seen = set()
entity_ids = [x for x in entity_ids if not (x in seen or seen.add(x))]

# ====================================================
# STEP 3: Pull records + extract shipment/BOL linkage, skipping empty ones
# ====================================================
print("\n====================================================")
print("STEP 3: GET each record JSON and extract shipmentNumber + BOL document linkage")
print("====================================================")

results = []
skipped_empty = 0

for i, eid in enumerate(entity_ids, start=1):
    ent = get_record(eid)
    linkage = extract_linkage_fields(ent)

    if is_empty_linkage(linkage):
        skipped_empty += 1
    else:
        results.append(linkage)

    if i % 50 == 0:
        print(f"Processed {i}/{len(entity_ids)} | kept={len(results)} | skipped_empty={skipped_empty}")

    time.sleep(SLEEP_BETWEEN_GETS)

print("\n====================================================")
print("DONE")
print("====================================================")
print(f"Total fetched IDs: {len(entity_ids)}")
print(f"Kept (non-empty linkage): {len(results)}")
print(f"Skipped (empty shipmentNumber & shipmentDocument): {skipped_empty}")

# Show a few samples clearly
print("\n--- SAMPLE (first 10 kept) ---")
for r in results[:10]:
    print(json.dumps(r, indent=2))

# If you just want the two columns to copy/paste quickly:
print("\n--- QUICK LIST (shipmentNumber, shipmentDocumentEntityId, checkinEntityId) first 50 ---")
for r in results[:50]:
    print(f"{r.get('shipmentNumber')}\t{r.get('shipmentDocumentName')}\t{r.get('checkinEntityId')}")


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

import requests, json, time
from datetime import datetime, timezone, timedelta

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

# Mixins:
# - This is the one shown in your working check-in JSON:
#   mixins.active includes ("Fairlife Facility Check-In", "b3c99c93-fd6c-466b-bdb6-59950dc31c11")
FAIRLIFE_CHECKIN_MIXIN = "b3c99c93-fd6c-466b-bdb6-59950dc31c11"

# If you want to keep firm filtering, set this; otherwise set to None
# (you said you don't need firmId for Fairlife check-ins)
FIRM_ID = "8ccd57ef-16a5-4b54-acd3-926af17d7139"

HEADERS = {
    "Authorization": f"Bearer {VECTOR_TOKEN}",
    "Content-Type": "application/json",
    "Accept": "application/json",
}

# How many to fetch for probe
N_TO_FETCH = 20     # set to 1000 once you confirm payload returns the right data
PAGE_SIZE  = 50     # keep modest; Vector can be picky with larger pages
SLEEP_BETWEEN_GETS = 0.05

# Sample record you provided (check-in UUID)
SAMPLE_CHECKIN_UUID = "81fc3f53-1762-48a5-bf25-0e58d00eb2a5"


# =========================
# HELPERS
# =========================
def jget(obj, path, default=None):
    """Safe nested getter using dot paths (dict only)."""
    cur = obj
    for p in path.split("."):
        if cur is None:
            return default
        if isinstance(cur, dict):
            cur = cur.get(p)
        else:
            return default
    return cur if cur is not None else default

def iso_z(dt: datetime) -> str:
    """ISO string with Z. Accepts aware dt."""
    return dt.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.%f")[:-3] + "Z"

def safe_resp_json(r: requests.Response):
    ct = (r.headers.get("content-type") or "").lower()
    if "application/json" in ct:
        try:
            return r.json()
        except Exception:
            return None
    return None

def http_get_record(entity_id: str) -> dict:
    url = f"{RECORD_ENDPOINT}/{entity_id}"
    r = requests.get(url, headers=HEADERS, timeout=60)
    r.raise_for_status()
    return r.json()

def http_post_query(payload: dict) -> dict:
    r = requests.post(QUERY_ENDPOINT, headers=HEADERS, json=payload, timeout=60)
    if r.status_code != 200:
        print("\n----- Vector QUERY ERROR payload -----")
        print(json.dumps(payload, indent=2)[:4000])
        print("----- Vector QUERY ERROR response -----")
        j = safe_resp_json(r)
        if j is not None:
            print(json.dumps(j, indent=2)[:4000])
        else:
            print((r.text or "")[:4000])
    r.raise_for_status()
    return r.json()

def find_first_present(entity: dict, paths: list[str]):
    """Return (path, value) for first non-empty value from paths."""
    for p in paths:
        v = jget(entity, p, None)
        if v is None:
            continue
        # treat empty string as missing
        if isinstance(v, str) and v.strip() == "":
            continue
        return p, v
    return None, None

def extract_linkage_fields(checkin: dict) -> dict:
    """
    Extract shipmentNumber + shipmentDocument (BOL) from likely locations.
    Based on your sample, the real paths were:
      core_yms_execution.outbound.shipmentNumber
      core_yms_execution.outbound.shipmentDocument (edge)
    """
    shipment_number_paths = [
        "core_yms_shipment.shipmentNumber",                    # sometimes present in other tenants
        "core_yms_execution.outbound.shipmentNumber",          # <-- your sample
        "core_yms_execution.inbound.shipmentNumber",           # just in case
        "core_documents_shipment.shipmentNumber",              # if a document schema is attached
    ]
    ship_doc_paths = [
        "core_yms_execution.outbound.shipmentDocument",        # <-- your sample
        "core_yms_execution.inbound.shipmentDocument",
        "core_yms_shipment.shipmentDocument",
    ]

    ship_num_path, ship_num_val = find_first_present(checkin, shipment_number_paths)
    ship_doc_path, ship_doc_val = find_first_present(checkin, ship_doc_paths)

    # ship_doc_val should be an "edge"-like object: {entityId, displayName, denormalizedProperties{document.name...}}
    ship_doc_entity_id = ""
    ship_doc_display = ""
    ship_doc_doc_name = ""
    if isinstance(ship_doc_val, dict):
        ship_doc_entity_id = str(ship_doc_val.get("entityId") or "")
        ship_doc_display = str(ship_doc_val.get("displayName") or "")
        ship_doc_doc_name = str(jget(ship_doc_val, "denormalizedProperties.document.name") or "")

    out = {
        "checkinEntityId": str(checkin.get("uniqueId") or ""),
        "creationDate": str(checkin.get("creationDate") or ""),
        "modifiedDate": str(checkin.get("modifiedDate") or ""),
        "ownerFirmId": str(jget(checkin, "owner.firm.entityId") or ""),
        "ownerFirmName": str(jget(checkin, "owner.firm.displayName") or ""),
        "ownerUserName": str(jget(checkin, "owner.user.displayName") or ""),

        "shipmentNumber": str(ship_num_val or ""),
        "shipmentNumber_path": ship_num_path or "",

        "shipmentDocument_entityId": ship_doc_entity_id,
        "shipmentDocument_displayName": ship_doc_display,
        "shipmentDocument_documentName": ship_doc_doc_name,
        "shipmentDocument_path": ship_doc_path or "",

        "visitStatus": str(jget(checkin, "core_yms_execution.visit.status") or ""),
        "apptRequestName": str(jget(checkin, "core_yms_execution.queries.appointment.request.name") or ""),
    }
    return out

def build_checkin_query_payload(
    mixin_id: str,
    size: int,
    offset: int,
    date_field: str | None = None,   # "creationDate" or "modifiedDate"
    start_iso: str | None = None,
    end_iso: str | None = None,
    firm_id: str | None = None
) -> dict:
    """
    Working Vector query payload builder.
    IMPORTANT: For range filter, gte/lte must be TOP-LEVEL keys.
    """
    filters = [
        {
            "type": "containsEdge",
            "path": "mixins.active",
            "values": [{"entityId": mixin_id}]
        }
    ]

    if date_field and start_iso and end_iso:
        filters.append({
            "type": "range",
            "path": date_field,
            # NOTE: gte/lte are top-level keys (this fixes your error)
            "gte": start_iso,
            "lte": end_iso
        })

    metadata = {
        "size": size,
        "offset": offset,
        "shouldIncludeLeafEntities": True
    }
    if firm_id:
        metadata["firmId"] = firm_id

    return {"filters": filters, "metadata": metadata}

def fetch_checkin_ids_last_2_months(
    n: int,
    page_size: int,
    mixin_id: str,
    use_date_field: str = "modifiedDate",   # or "creationDate"
    firm_id: str | None = None
) -> list[str]:
    """
    Fetch up to n check-in entityIds within last 2 months by created/modified date.
    Returns list of UUIDs (uniqueId).
    """
    end_dt = datetime.now(timezone.utc)
    start_dt = end_dt - timedelta(days=60)
    start_iso = iso_z(start_dt)
    end_iso = iso_z(end_dt)

    ids = []
    offset = 0
    while len(ids) < n:
        size = min(page_size, n - len(ids))
        payload = build_checkin_query_payload(
            mixin_id=mixin_id,
            size=size,
            offset=offset,
            date_field=use_date_field,
            start_iso=start_iso,
            end_iso=end_iso,
            firm_id=firm_id
        )
        resp = http_post_query(payload)
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

    # de-dupe while preserving order
    seen = set()
    out = []
    for x in ids:
        if x not in seen:
            out.append(x)
            seen.add(x)
    return out

def pretty_print_json(obj: dict, max_chars: int = 12000):
    s = json.dumps(obj, indent=2)
    if len(s) > max_chars:
        print(s[:max_chars] + "\n...<truncated>...")
    else:
        print(s)


# =========================
# STEP 1: Dump ONE check-in JSON (inspect)
# =========================
print("====================================================")
print("STEP 1: Fetch single check-in record JSON (for inspection)")
print("====================================================")
checkin = http_get_record(SAMPLE_CHECKIN_UUID)
print("HTTP: 200")
print("Top-level keys:", list(checkin.keys()))
mixins_active = [(m.get("displayName"), m.get("entityId")) for m in (jget(checkin, "mixins.active") or []) if isinstance(m, dict)]
print("mixins.active:", mixins_active)

print("\n--- Linkage extraction (shipmentNumber + shipmentDocument) ---")
linkage = extract_linkage_fields(checkin)
print(json.dumps(linkage, indent=2))

print("\n--- FULL ENTITY JSON (truncated) ---")
pretty_print_json(checkin, max_chars=12000)


# =========================
# STEP 2: PROBE payload for last 2 months (created/modified)
# =========================
print("\n====================================================")
print("STEP 2: Probe query payload for last 2 months (created/modified)")
print("====================================================")
end_dt = datetime.now(timezone.utc)
start_dt = end_dt - timedelta(days=60)
start_iso = iso_z(start_dt)
end_iso = iso_z(end_dt)
print(f"Window: {start_iso} -> {end_iso}")

probe_payload = build_checkin_query_payload(
    mixin_id=FAIRLIFE_CHECKIN_MIXIN,
    size=10,
    offset=0,
    date_field="modifiedDate",    # switch to "creationDate" if you prefer
    start_iso=start_iso,
    end_iso=end_iso,
    firm_id=FIRM_ID
)
print("\nPayload that should work (range filter with top-level gte/lte):")
print(json.dumps(probe_payload, indent=2))

probe_resp = http_post_query(probe_payload)
print("\nHTTP: 200")
print("metadata:", probe_resp.get("metadata"))
print("returned children:", len(probe_resp.get("children", []) or []))

sample_ids = []
for c in (probe_resp.get("children") or [])[:10]:
    uid = jget(c, "data.uniqueId")
    if uid:
        sample_ids.append(uid)
print("sample uniqueIds:", sample_ids)


# =========================
# STEP 3: Fetch N records and print key linkage fields (NO TABLE WRITES)
# =========================
print("\n====================================================")
print(f"STEP 3: Fetch {N_TO_FETCH} check-ins from last 2 months and print linkage fields")
print("====================================================")
ids = fetch_checkin_ids_last_2_months(
    n=N_TO_FETCH,
    page_size=PAGE_SIZE,
    mixin_id=FAIRLIFE_CHECKIN_MIXIN,
    use_date_field="modifiedDate",     # or "creationDate"
    firm_id=FIRM_ID
)
print(f"Found {len(ids)} IDs")

rows = []
for i, eid in enumerate(ids, start=1):
    ent = http_get_record(eid)
    rows.append(extract_linkage_fields(ent))
    if i % 25 == 0:
        print(f"  fetched {i}/{len(ids)}")
    time.sleep(SLEEP_BETWEEN_GETS)

print("\n--- OUTPUT (compact) ---")
for r in rows:
    print(json.dumps({
        "checkinEntityId": r["checkinEntityId"],
        "modifiedDate": r["modifiedDate"],
        "visitStatus": r["visitStatus"],
        "shipmentNumber": r["shipmentNumber"],
        "shipmentNumber_path": r["shipmentNumber_path"],
        "shipmentDocument_entityId": r["shipmentDocument_entityId"],
        "shipmentDocument_displayName": r["shipmentDocument_displayName"],
        "shipmentDocument_documentName": r["shipmentDocument_documentName"],
        "shipmentDocument_path": r["shipmentDocument_path"],
        "apptRequestName": r["apptRequestName"],
    }, indent=2))


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

import requests, json
from datetime import datetime, timedelta, timezone

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

HEADERS = {
    "Authorization": f"Bearer {VECTOR_TOKEN}",
    "Content-Type": "application/json",
    "Accept": "application/json",
}

# Example check-in URL you gave:
# https://app.withvector.com/view/9b444061-171e-49f3-bc4f-a2ab36355011/entity/e8d3aea0-179b-4308-a0ce-99b0b25f7717
CHECKIN_UUID = "e8d3aea0-179b-4308-a0ce-99b0b25f7717"

# Last 2 months window (UTC)
NOW_UTC = datetime.now(timezone.utc)
START_UTC = NOW_UTC - timedelta(days=60)

# ISO strings Vector usually expects (keep Z)
START_ISO = START_UTC.strftime("%Y-%m-%dT%H:%M:%S.000Z")
END_ISO   = NOW_UTC.strftime("%Y-%m-%dT%H:%M:%S.000Z")

# If you want to scope by firm later, you can set:
FIRM_ID = None  # e.g. "8ccd57ef-16a5-4b54-acd3-926af17d7139"


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

def pretty(x, n=4000):
    s = json.dumps(x, indent=2, ensure_ascii=False)
    return s[:n] + ("..." if len(s) > n else "")

def get_record(entity_uuid: str) -> dict:
    url = f"{RECORD_ENDPOINT}/{entity_uuid}"
    r = requests.get(url, headers=HEADERS, timeout=60)
    print("GET:", url)
    print("HTTP:", r.status_code)
    if r.status_code != 200:
        try:
            print(pretty(r.json()))
        except Exception:
            print(r.text[:4000])
        r.raise_for_status()
    return r.json()

def extract_shipment_linkage(ent: dict) -> dict:
    """
    Pull the key linkage fields you mentioned:
      - core_yms_shipment.shipmentNumber
      - core_yms_shipment.shipmentDocument (edge)
      - core_yms_shipment.shipmentDocument.denormalizedProperties.document.name
    plus a few alternates we’ve seen in other entities.
    """
    out = {
        "uniqueId": ent.get("uniqueId"),
        "creationDate": ent.get("creationDate"),
        "modifiedDate": ent.get("modifiedDate"),
        "ownerFirmId": jget(ent, "owner.firm.entityId", ""),
        "ownerFirmName": jget(ent, "owner.firm.displayName", ""),
        "ownerUser": jget(ent, "owner.user.displayName", ""),

        # Your target fields
        "core_yms_shipment.shipmentNumber": jget(ent, "core_yms_shipment.shipmentNumber", ""),
        "core_yms_shipment.shipmentDocument.entityId": jget(ent, "core_yms_shipment.shipmentDocument.entityId", ""),
        "core_yms_shipment.shipmentDocument.displayName": jget(ent, "core_yms_shipment.shipmentDocument.displayName", ""),
        "core_yms_shipment.shipmentDocument.document.name": jget(ent, "core_yms_shipment.shipmentDocument.denormalizedProperties.document.name", ""),

        # Common alternates (sometimes it’s stored differently)
        "core_documents_shipment.shipmentNumber": jget(ent, "core_documents_shipment.shipmentNumber", ""),
        "core_documents_shipment.identification.bolNumber": jget(ent, "core_documents_shipment.identification.bolNumber", ""),
        "core_yms_execution.queries.appointment.request.name": jget(ent, "core_yms_execution.queries.appointment.request.name", ""),
        "core_yms_execution.visit.status": jget(ent, "core_yms_execution.visit.status", ""),
    }
    return out

def find_paths(obj, target_key, max_hits=50):
    """
    Quick “where is this key in the JSON?” helper.
    Example: find_paths(ent, "shipmentNumber")
    """
    hits = []
    def walk(x, path=""):
        if len(hits) >= max_hits:
            return
        if isinstance(x, dict):
            for k,v in x.items():
                p = f"{path}.{k}" if path else k
                if k == target_key:
                    hits.append(p)
                walk(v, p)
        elif isinstance(x, list):
            for i, v in enumerate(x):
                p = f"{path}[{i}]"
                walk(v, p)
    walk(obj)
    return hits

def post_query(payload: dict) -> dict:
    r = requests.post(QUERY_ENDPOINT, headers=HEADERS, json=payload, timeout=60)
    print("\nPOST:", QUERY_ENDPOINT)
    print("HTTP:", r.status_code)
    print("Payload:")
    print(pretty(payload, n=2500))
    if r.status_code != 200:
        print("Response:")
        try:
            print(pretty(r.json(), n=2500))
        except Exception:
            print(r.text[:2500])
        return {"__http_status": r.status_code, "__text": r.text, "__json": (r.json() if r.headers.get("content-type","").startswith("application/json") else None)}
    return r.json()

def build_last_2_months_payloads(size=10, offset=0, date_mode="modifiedDate"):
    """
    Vector filter grammar is finicky. We’ll try multiple common shapes.
    date_mode: "creationDate" or "modifiedDate"
    """
    base_md = {
        "size": size,
        "offset": offset,
        "shouldIncludeLeafEntities": True,
    }
    if FIRM_ID:
        base_md["firmId"] = FIRM_ID

    # Candidates: try a few typical operators
    candidates = []

    # A) range operator (common in search systems)
    candidates.append({
        "filters": [{
            "type": "range",
            "path": date_mode,
            "value": {"gte": START_ISO, "lte": END_ISO}
        }],
        "metadata": dict(base_md)
    })

    # B) between operator
    candidates.append({
        "filters": [{
            "type": "between",
            "path": date_mode,
            "value": {"start": START_ISO, "end": END_ISO}
        }],
        "metadata": dict(base_md)
    })

    # C) and + gte/lte
    candidates.append({
        "filters": [{
            "type": "and",
            "filters": [
                {"type": "gte", "path": date_mode, "value": START_ISO},
                {"type": "lte", "path": date_mode, "value": END_ISO},
            ]
        }],
        "metadata": dict(base_md)
    })

    # D) and + greaterThan/lessThan
    candidates.append({
        "filters": [{
            "type": "and",
            "filters": [
                {"type": "greaterThanOrEqual", "path": date_mode, "value": START_ISO},
                {"type": "lessThanOrEqual", "path": date_mode, "value": END_ISO},
            ]
        }],
        "metadata": dict(base_md)
    })

    return candidates

def try_find_working_date_filter(size=10, offset=0):
    """
    Try creationDate and modifiedDate payloads; print first one that returns children.
    """
    print("\n=========================")
    print("PROBE: last 2 months date filter (tries multiple shapes)")
    print("Window:", START_ISO, "->", END_ISO)
    print("=========================")

    for date_mode in ["modifiedDate", "creationDate"]:
        payloads = build_last_2_months_payloads(size=size, offset=offset, date_mode=date_mode)
        for i, p in enumerate(payloads, start=1):
            print(f"\n--- Trying date_mode={date_mode}, candidate #{i} ---")
            resp = post_query(p)

            # If error
            if isinstance(resp, dict) and resp.get("__http_status"):
                continue

            children = resp.get("children") if isinstance(resp, dict) else None
            if isinstance(children, list):
                print("returned children:", len(children))
                # If it returns something, we consider it "working"
                if len(children) > 0:
                    print("✅ This payload shape works.")
                    # Show one sample UID path that worked in your earlier tests
                    sample = children[0]
                    print("Sample child keys:", list(sample.keys()) if isinstance(sample, dict) else type(sample))
                    print("Sample uniqueId at data.uniqueId:", jget(sample, "data.uniqueId"))
                    return p, resp

    print("\n❌ None of the date filter shapes worked (Vector filter grammar may differ).")
    return None, None


# =========================
# 1) SINGLE-RECORD PROBE (your check-in UUID)
# =========================
print("====================================================")
print("STEP 1: Fetch single check-in record JSON")
print("====================================================")
ent = get_record(CHECKIN_UUID)

print("\nTop-level keys:", list(ent.keys()))
print("mixins.active:", [(m.get("displayName"), m.get("entityId")) for m in (jget(ent, "mixins.active") or []) if isinstance(m, dict)])

link = extract_shipment_linkage(ent)
print("\n--- Shipment/BOL linkage fields (what you care about) ---")
print(pretty(link, n=4000))

print("\n--- Where is 'shipmentNumber' found in this JSON? (paths) ---")
print(find_paths(ent, "shipmentNumber", max_hits=50))

print("\n--- Where is 'shipmentDocument' found in this JSON? (paths) ---")
print(find_paths(ent, "shipmentDocument", max_hits=50))

# If you want to inspect the full JSON (careful: huge)
print("\n--- FULL ENTITY JSON (truncated) ---")
print(pretty(ent, n=8000))

# =========================
# 2) DATE FILTER PROBE (last 2 months) - no writes, just find payload that works
# =========================
print("\n====================================================")
print("STEP 2: Probe query payload for last 2 months (created/modified)")
print("====================================================")
working_payload, working_resp = try_find_working_date_filter(size=10, offset=0)

if working_payload:
    print("\n✅ Working payload you can reuse:")
    print(pretty(working_payload, n=4000))
else:
    print("\nNo working date payload found in this probe run. If you paste one 400 response, I can match Vector’s expected filter contract exactly.")


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

import requests, json

# =========================
# CONFIG
# =========================
from notebookutils import mssparkutils

# --- Read secrets from Azure Key Vault ---
VECTOR_TOKEN = mssparkutils.credentials.getSecret(
    "https://keyvault-fabric2.vault.azure.net/",
    "VECTORTOKEN"
)  # <-- your token
CHECKIN_ENTITY_ID = "e8d3aea0-179b-4308-a0ce-99b0b25f7717"

RECORD_ENDPOINT = "https://api.withvector.com/1.0/entities/records"

HEADERS = {
    "Authorization": f"Bearer {VECTOR_TOKEN}",
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

def extract_shipment_number_from_checkin(ent: dict) -> str:
    """
    Check-In entities often don't have "core_documents_shipment.shipmentNumber".
    Best candidates (based on your sample JSON) are:
      - core_yms_execution.queries.appointment.request.name
      - core_yms_execution.queries.appointment.request.loadNumber / shipmentNumber / purchaseOrderNumber (if present)
      - core_storyboard_execution.id (sometimes numeric string)
    """
    candidates = [
        jget(ent, "core_yms_execution.queries.appointment.request.name"),
        jget(ent, "core_yms_execution.queries.appointment.request.loadNumber"),
        jget(ent, "core_yms_execution.queries.appointment.request.shipmentNumber"),
        jget(ent, "core_yms_execution.queries.appointment.request.purchaseOrderNumber"),
        jget(ent, "core_storyboard_execution.id"),
        jget(ent, "core_storyboard_execution.name"),
    ]
    for c in candidates:
        if c is None:
            continue
        s = str(c).strip()
        if s:
            return s
    return ""

# =========================
# RUN
# =========================
url = f"{RECORD_ENDPOINT}/{CHECKIN_ENTITY_ID}"
resp = requests.get(url, headers=HEADERS, timeout=60)

print("HTTP Status:", resp.status_code)
resp.raise_for_status()

entity = resp.json()

print("\n===== QUICK FIELDS =====")
print("uniqueId:", entity.get("uniqueId"))
print("creationDate:", entity.get("creationDate"))
print("modifiedDate:", entity.get("modifiedDate"))

mixins = jget(entity, "mixins.active", [])
print("\nMixins.active:")
for m in mixins if isinstance(mixins, list) else []:
    if isinstance(m, dict):
        print(" -", m.get("displayName"), m.get("entityId"))

shipment_number = extract_shipment_number_from_checkin(entity)
print("\nDerived shipmentNumber (best guess):", shipment_number)

print("\n===== FULL ENTITY JSON =====\n")
print(json.dumps(entity, indent=2)[:200000])  # increase/decrease if you want


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

# MAGIC %%sql
# MAGIC DROP TABLE IF EXISTS ibmi_incr_stopoff_og_appt_bronze;

# METADATA ********************

# META {
# META   "language": "sparksql",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************


import json
import time
import math
import requests
from datetime import datetime, timezone

from pyspark.sql.types import (
    StructType, StructField, StringType, TimestampType, BooleanType, DoubleType
)
from pyspark.sql import functions as F

# ----------------------------
# CONFIG
# ----------------------------
BASE_URL = "https://api.withvector.com/1.0"
QUERY_ENDPOINT = f"{BASE_URL}/entities/query"
RECORD_ENDPOINT = f"{BASE_URL}/entities/records"   # + /{uuid}

from notebookutils import mssparkutils

# --- Read secrets from Azure Key Vault ---
VECTOR_TOKEN = mssparkutils.credentials.getSecret(
    "https://keyvault-fabric2.vault.azure.net/",
    "VECTORTOKEN"
)

# Pull size
N_RECORDS = 1000
PAGE_SIZE = 250          # Vector query size
GET_SLEEP = 0.12         # per-record throttle
POST_SLEEP = 0.10        # between query pages
MAX_RETRIES = 6

CHECKIN_MIXIN_ID = "7d2eb17e-9f9d-49c1-8b7f-d55179b3071e"  # Kraft Heinz Facility Check-In (example)


FIRM_ID = None

# Bronze tables
TBL_RAW    = "vector_checkin_raw_bronze"
TBL_KV     = "vector_checkin_kv_bronze"
TBL_EVENTS = "vector_checkin_events_bronze"

HEADERS = {
    "Authorization": f"Bearer {TOKEN}",
    "Content-Type": "application/json",
    "Accept": "application/json",
}

# ----------------------------
# HELPERS
# ----------------------------
def now_utc_ts():
    return datetime.now(timezone.utc)

def s(x):
    return None if x is None else str(x)

def safe_get(obj, path, default=None):
    cur = obj
    for part in path.split("."):
        if cur is None:
            return default
        if isinstance(cur, dict):
            cur = cur.get(part)
        elif isinstance(cur, list):
            try:
                idx = int(part)
                cur = cur[idx]
            except:
                return default
        else:
            return default
    return cur if cur is not None else default

def mixins_active_str(entity_json):
    arr = safe_get(entity_json, "mixins.active", []) or []
    out = []
    for m in arr:
        if isinstance(m, dict):
            dn = m.get("displayName")
            eid = m.get("entityId")
            if dn and eid:
                out.append(f"{dn} ({eid})")
            elif dn:
                out.append(dn)
            elif eid:
                out.append(eid)
    return " | ".join(out) if out else None

def request_with_retries(method, url, *, headers=None, data=None, timeout=60, max_retries=6, sleep_base=0.6):
    last_err = None
    for attempt in range(1, max_retries + 1):
        try:
            if method.upper() == "GET":
                r = requests.get(url, headers=headers, timeout=timeout)
            else:
                r = requests.post(url, headers=headers, data=data, timeout=timeout)

            # Treat 429/5xx as retryable
            if r.status_code in (429, 500, 502, 503, 504):
                last_err = (r.status_code, r.text[:2000])
                time.sleep(sleep_base * (2 ** (attempt - 1)))
                continue

            return r
        except Exception as e:
            last_err = str(e)
            time.sleep(sleep_base * (2 ** (attempt - 1)))

    raise RuntimeError(f"Request failed after retries: {method} {url} last_err={last_err}")

def post_entities_query(size, offset):
    payload = {
        "filters": [
            {
                "type": "containsEdge",
                "path": "mixins.active",
                "values": [{"entityId": CHECKIN_MIXIN_ID}]
            }
        ],
        "metadata": {
            "size": int(size),
            "offset": int(offset),
            "shouldIncludeLeafEntities": True
        }
    }
    if FIRM_ID:
        payload["metadata"]["firmId"] = FIRM_ID

    r = request_with_retries(
        "POST",
        QUERY_ENDPOINT,
        headers=HEADERS,
        data=json.dumps(payload),
        max_retries=MAX_RETRIES
    )

    if r.status_code >= 400:
        print("----- Vector QUERY ERROR payload -----")
        print(json.dumps(payload, indent=2))
        print("----- Vector QUERY ERROR response -----")
        try:
            print(json.dumps(r.json(), indent=2)[:4000])
        except:
            print(r.text[:4000])
        r.raise_for_status()

    return r.json()

def get_record(uuid):
    url = f"{RECORD_ENDPOINT}/{uuid}"
    r = request_with_retries("GET", url, headers=HEADERS, max_retries=MAX_RETRIES)
    if r.status_code >= 400:
        print(f"----- Vector GET ERROR uuid={uuid} -----")
        try:
            print(json.dumps(r.json(), indent=2)[:4000])
        except:
            print(r.text[:4000])
        r.raise_for_status()
    return r.json()

# Flatten JSON into scalar key/value rows
SCALAR_TYPES = (str, int, float, bool)

def type_name(v):
    if v is None:
        return "null"
    if isinstance(v, bool):
        return "bool"
    if isinstance(v, int) and not isinstance(v, bool):
        return "int"
    if isinstance(v, float):
        return "float"
    if isinstance(v, str):
        return "string"
    return "other"

def to_string_value(v, max_len=4000):
    if v is None:
        return None
    if isinstance(v, (dict, list)):
        txt = json.dumps(v, ensure_ascii=False)
    else:
        txt = str(v)
    return txt[:max_len]

def flatten_json_scalars(obj, prefix="", out=None, max_rows=20000):
    """
    Flattens JSON to (path, scalar_value, value_type).
    Only emits scalar leaves; lists are indexed.
    max_rows is a safety to avoid runaway (huge arrays).
    """
    if out is None:
        out = []

    if len(out) >= max_rows:
        return out

    if isinstance(obj, dict):
        for k, v in obj.items():
            p = f"{prefix}.{k}" if prefix else k
            flatten_json_scalars(v, p, out, max_rows=max_rows)
            if len(out) >= max_rows:
                break
    elif isinstance(obj, list):
        for i, v in enumerate(obj):
            p = f"{prefix}.{i}" if prefix else str(i)
            flatten_json_scalars(v, p, out, max_rows=max_rows)
            if len(out) >= max_rows:
                break
    else:
        # scalar leaf
        out.append((prefix, obj, type_name(obj)))

    return out

# ----------------------------
# STEP 1: FETCH 1000 UUIDs via pagination
# ----------------------------
print(f"Fetching up to {N_RECORDS} check-in UUIDs...")
uuids = []
offset = 0

while len(uuids) < N_RECORDS:
    size = min(PAGE_SIZE, N_RECORDS - len(uuids))
    resp = post_entities_query(size=size, offset=offset)
    children = resp.get("children", []) or []

    # IMPORTANT: uniqueId is under child['data']['uniqueId']
    page_ids = []
    for ch in children:
        if not isinstance(ch, dict):
            continue
        data = ch.get("data")
        uid = data.get("uniqueId") if isinstance(data, dict) else None
        if uid:
            page_ids.append(uid)

    # stop if no more
    if not page_ids:
        break

    uuids.extend(page_ids)

    offset += len(children)  # advance by returned count (not by requested size)
    print(f"  got {len(uuids)} / {N_RECORDS} (offset now {offset})")
    time.sleep(POST_SLEEP)

uuids = uuids[:N_RECORDS]
print(f"Total UUIDs collected: {len(uuids)}")
if not uuids:
    raise SystemExit("No UUIDs returned. Fix CHECKIN_MIXIN_ID and/or set FIRM_ID if required.")

# ----------------------------
# STEP 2: GET FULL JSON for each UUID
# ----------------------------
print("\nFetching full JSON for each UUID...")
records = []
for i, uid in enumerate(uuids, start=1):
    rec = get_record(uid)
    records.append(rec)
    if i % 25 == 0 or i == len(uuids):
        print(f"  fetched {i}/{len(uuids)}")
    time.sleep(GET_SLEEP)

extracted_at = now_utc_ts()

# ----------------------------
# STEP 3: BUILD BRONZE ROWS
# ----------------------------

# RAW rows (1 row per check-in)
raw_rows = []
for r in records:
    raw_rows.append({
        "checkinEntityId": s(r.get("uniqueId")),
        "creationDateUtc": s(r.get("creationDate")),
        "modifiedDateUtc": s(r.get("modifiedDate")),
        "ownerFirmId": s(safe_get(r, "owner.firm.entityId")),
        "ownerFirmName": s(safe_get(r, "owner.firm.displayName")),
        "ownerUserId": s(safe_get(r, "owner.user.entityId")),
        "ownerUserName": s(safe_get(r, "owner.user.displayName")),
        "createdByUserId": s(safe_get(r, "createdBy.entityId")),
        "createdByUserName": s(safe_get(r, "createdBy.displayName")),
        "modifiedByUserId": s(safe_get(r, "modifiedBy.entityId")),
        "modifiedByUserName": s(safe_get(r, "modifiedBy.displayName")),
        "statusState": s(safe_get(r, "status.state")),
        "mixinsActive": mixins_active_str(r),

        # Keep these whole objects too (helps a ton for Yard stuff without schema churn)
        "coreYmsExecutionJson": json.dumps(r.get("core_yms_execution"), ensure_ascii=False) if r.get("core_yms_execution") is not None else None,
        "ymsExecutionJson": json.dumps(r.get("core_yms_execution"), ensure_ascii=False) if r.get("core_yms_execution") is not None else None,
        "storyboardExecutionJson": json.dumps(r.get("core_storyboard_execution"), ensure_ascii=False) if r.get("core_storyboard_execution") is not None else None,

        "rawJson": json.dumps(r, ensure_ascii=False),
        "extractedAtUtc": extracted_at
    })

# EVENTS rows (1 row per event)
event_rows = []
for r in records:
    checkin_id = s(r.get("uniqueId"))
    events = safe_get(r, "core_storyboard_execution.events", []) or []
    for ev in events:
        if not isinstance(ev, dict):
            continue
        event_rows.append({
            "checkinEntityId": checkin_id,
            "eventId": s(ev.get("id")),
            "eventType": s(ev.get("eventType")),
            "eventName": s(ev.get("name")),
            "creationDateUtc": s(ev.get("creationDate")),
            "processedDateUtc": s(ev.get("processedDate")),
            "createdByUserId": s(safe_get(ev, "createdBy.entityId")),
            "createdByUserName": s(safe_get(ev, "createdBy.displayName")),
            "sourceTaskId": s(safe_get(ev, "source.taskId")),
            "sourceSceneId": s(safe_get(ev, "source.sceneId")),
            "sourceStoryId": s(safe_get(ev, "source.storyId")),

            # dump the rich parts so you never lose data
            "createdAtJson": json.dumps(ev.get("createdAt"), ensure_ascii=False) if ev.get("createdAt") is not None else None,
            "deviceInfoJson": json.dumps(ev.get("deviceInfo"), ensure_ascii=False) if ev.get("deviceInfo") is not None else None,
            "detailsJson": json.dumps(ev.get("details"), ensure_ascii=False) if ev.get("details") is not None else None,
            "associationsJson": json.dumps(ev.get("associations"), ensure_ascii=False) if ev.get("associations") is not None else None,
            "outputMappingsJson": json.dumps(ev.get("outputMappings"), ensure_ascii=False) if ev.get("outputMappings") is not None else None,

            "extractedAtUtc": extracted_at
        })

# KV rows (all scalar attributes)
# WARNING: This can get big. For 1000 records it’s still manageable, but it depends on event array sizes.
kv_rows = []
MAX_KV_ROWS_PER_ENTITY = 30000  # safety cap per entity

print("\nFlattening JSON to key/value rows (all scalar attributes)...")
for i, r in enumerate(records, start=1):
    entity_id = s(r.get("uniqueId"))
    flat = flatten_json_scalars(r, out=None, max_rows=MAX_KV_ROWS_PER_ENTITY)
    for path, value, vtype in flat:
        # Store only scalar leaves; stringify to a safe length
        if value is None:
            sval = None
        elif isinstance(value, (dict, list)):
            # shouldn't happen because we emit only scalars, but keep safe
            sval = to_string_value(value)
        else:
            sval = to_string_value(value)

        kv_rows.append({
            "checkinEntityId": entity_id,
            "jsonPath": s(path),
            "valueType": s(vtype),
            "valueString": sval,
            "extractedAtUtc": extracted_at
        })

    if i % 25 == 0 or i == len(records):
        print(f"  flattened {i}/{len(records)}")

# ----------------------------
# STEP 4: CREATE DATAFRAMES (explicit schemas)
# ----------------------------
schema_raw = StructType([
    StructField("checkinEntityId", StringType(), True),
    StructField("creationDateUtc", StringType(), True),
    StructField("modifiedDateUtc", StringType(), True),
    StructField("ownerFirmId", StringType(), True),
    StructField("ownerFirmName", StringType(), True),
    StructField("ownerUserId", StringType(), True),
    StructField("ownerUserName", StringType(), True),
    StructField("createdByUserId", StringType(), True),
    StructField("createdByUserName", StringType(), True),
    StructField("modifiedByUserId", StringType(), True),
    StructField("modifiedByUserName", StringType(), True),
    StructField("statusState", StringType(), True),
    StructField("mixinsActive", StringType(), True),

    StructField("coreYmsExecutionJson", StringType(), True),
    StructField("ymsExecutionJson", StringType(), True),
    StructField("storyboardExecutionJson", StringType(), True),

    StructField("rawJson", StringType(), True),
    StructField("extractedAtUtc", TimestampType(), True),
])

schema_events = StructType([
    StructField("checkinEntityId", StringType(), True),
    StructField("eventId", StringType(), True),
    StructField("eventType", StringType(), True),
    StructField("eventName", StringType(), True),
    StructField("creationDateUtc", StringType(), True),
    StructField("processedDateUtc", StringType(), True),
    StructField("createdByUserId", StringType(), True),
    StructField("createdByUserName", StringType(), True),
    StructField("sourceTaskId", StringType(), True),
    StructField("sourceSceneId", StringType(), True),
    StructField("sourceStoryId", StringType(), True),
    StructField("createdAtJson", StringType(), True),
    StructField("deviceInfoJson", StringType(), True),
    StructField("detailsJson", StringType(), True),
    StructField("associationsJson", StringType(), True),
    StructField("outputMappingsJson", StringType(), True),
    StructField("extractedAtUtc", TimestampType(), True),
])

schema_kv = StructType([
    StructField("checkinEntityId", StringType(), True),
    StructField("jsonPath", StringType(), True),
    StructField("valueType", StringType(), True),
    StructField("valueString", StringType(), True),
    StructField("extractedAtUtc", TimestampType(), True),
])

df_raw = spark.createDataFrame(raw_rows, schema=schema_raw)
df_events = spark.createDataFrame(event_rows, schema=schema_events)
df_kv = spark.createDataFrame(kv_rows, schema=schema_kv)

print("\nCounts:")
print("RAW:", df_raw.count())
print("EVENTS:", df_events.count())
print("KV:", df_kv.count())

# ----------------------------
# STEP 5: DROP + RECREATE TABLES (overwrite)
# ----------------------------
spark.sql(f"DROP TABLE IF EXISTS {TBL_RAW}")
spark.sql(f"DROP TABLE IF EXISTS {TBL_EVENTS}")
spark.sql(f"DROP TABLE IF EXISTS {TBL_KV}")

df_raw.write.format("delta").mode("overwrite").saveAsTable(TBL_RAW)
df_events.write.format("delta").mode("overwrite").saveAsTable(TBL_EVENTS)
df_kv.write.format("delta").mode("overwrite").saveAsTable(TBL_KV)

print("\n✅ Created and loaded Bronze tables:")
print(" -", TBL_RAW)
print(" -", TBL_EVENTS)
print(" -", TBL_KV)

# ----------------------------
# QUICK: Find Yard-related fields (discovery)
# ----------------------------
print("\n🔎 Quick Yard discovery (top paths containing 'yard', 'shuttle', 'move'):")
df_kv.filter(
    F.lower(F.col("jsonPath")).rlike("yard|shuttle|move|spot|dock|gate")
).groupBy("jsonPath").count().orderBy(F.desc("count")).show(50, truncate=False)


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

# MAGIC %%sql
# MAGIC DROP Table dbo.vector_checkin_snapshot_bronze;

# METADATA ********************

# META {
# META   "language": "sparksql",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

# ============================
# VECTOR -> FABRIC BRONZE LOAD
# 10 Check-In records
# ============================

import json
import time
import requests
from datetime import datetime, timezone

from pyspark.sql import functions as F
from pyspark.sql.types import (
    StructType, StructField, StringType, TimestampType, BooleanType, DoubleType
)

# ----------------------------
# CONFIG
# ----------------------------
BASE_URL = "https://api.withvector.com/1.0"
QUERY_ENDPOINT = f"{BASE_URL}/entities/query"
RECORD_ENDPOINT = f"{BASE_URL}/entities/records"   # + /{uuid}

# Paste your bearer token here
from notebookutils import mssparkutils

# --- Read secrets from Azure Key Vault ---
VECTOR_TOKEN = mssparkutils.credentials.getSecret(
    "https://keyvault-fabric2.vault.azure.net/",
    "VECTORTOKEN"
)

# How many check-in records to fetch
N_RECORDS = 100
PAGE_SIZE = 10
OFFSET = 0

# Mixins:
# - In your sample check-in JSON, active mixins include:
#   * 54809ba0-e1c6-46ec-af52-a392803a36b0 (Storyboard Execution)
#   * cf96dc53-9659-4f4b-a2a7-2b2bee249466 (YMS Execution)
#   * 7d2eb17e-9f9d-49c1-8b7f-d55179b3071e (Kraft Heinz Facility Check-In)
#
# If you want "check-in executions", the most specific is usually the Facility Check-In mixin.
CHECKIN_MIXIN_ID = "7d2eb17e-9f9d-49c1-8b7f-d55179b3071e"

# If your tenant requires firm scoping in metadata, set this. Otherwise leave None.
FIRM_ID = None  # e.g. "8ccd57ef-16a5-4b54-acd3-926af17d7139"

# Bronze table names
TBL_RAW      = "vector_checkin_raw_bronze"
TBL_EVENTS   = "vector_checkin_events_bronze"
TBL_SNAPSHOT = "vector_checkin_snapshot_bronze"

HEADERS = {
    "Authorization": f"Bearer {TOKEN}",
    "Content-Type": "application/json",
    "Accept": "application/json",
}

# ----------------------------
# HELPERS
# ----------------------------
def now_utc_ts():
    return datetime.now(timezone.utc)

def s(x):
    if x is None:
        return None
    return str(x)

def safe_get(obj, path, default=None):
    """
    safe_get(d, "a.b.0.c") supports dict + list indexing
    """
    cur = obj
    for part in path.split("."):
        if cur is None:
            return default
        if isinstance(cur, dict):
            cur = cur.get(part)
        elif isinstance(cur, list):
            try:
                idx = int(part)
                cur = cur[idx]
            except:
                return default
        else:
            return default
    return cur if cur is not None else default

def parse_ts(ts_str):
    # Keep as string? We'll store timestamps as timestamp type where we can
    # Spark can parse ISO8601 Z via to_timestamp if needed; for Python timestamp fields:
    return ts_str

def mixins_active_str(entity_json):
    arr = safe_get(entity_json, "mixins.active", []) or []
    out = []
    for m in arr:
        if isinstance(m, dict):
            dn = m.get("displayName")
            eid = m.get("entityId")
            if dn and eid:
                out.append(f"{dn} ({eid})")
            elif dn:
                out.append(dn)
            elif eid:
                out.append(eid)
    return " | ".join(out) if out else None

def post_entities_query(size, offset):
    payload = {
        "filters": [
            {
                "type": "containsEdge",
                "path": "mixins.active",
                "values": [{"entityId": CHECKIN_MIXIN_ID}]
            }
        ],
        "metadata": {
            "size": int(size),
            "offset": int(offset),
            "shouldIncludeLeafEntities": True
        }
    }
    if FIRM_ID:
        payload["metadata"]["firmId"] = FIRM_ID

    r = requests.post(QUERY_ENDPOINT, headers=HEADERS, data=json.dumps(payload), timeout=60)

    if r.status_code >= 400:
        print("----- Vector QUERY ERROR payload -----")
        print(json.dumps(payload, indent=2))
        print("----- Vector QUERY ERROR response -----")
        try:
            print(json.dumps(r.json(), indent=2)[:4000])
        except:
            print(r.text[:4000])
        r.raise_for_status()

    return r.json()

def get_record(uuid):
    url = f"{RECORD_ENDPOINT}/{uuid}"
    r = requests.get(url, headers=HEADERS, timeout=60)
    if r.status_code >= 400:
        print(f"----- Vector GET ERROR uuid={uuid} -----")
        try:
            print(json.dumps(r.json(), indent=2)[:4000])
        except:
            print(r.text[:4000])
        r.raise_for_status()
    return r.json()

# ----------------------------
# STEP 1: FETCH 10 UUIDs (query API)
# ----------------------------
print(f"Fetching {N_RECORDS} check-in entity IDs via query...")
resp = post_entities_query(size=PAGE_SIZE, offset=OFFSET)

children = resp.get("children", []) or []
# IMPORTANT: In Vector query response, each child usually looks like:
# { "data": {...}, "children": [...], "metadata": {...} }
uuids = []
for ch in children:
    data = ch.get("data") if isinstance(ch, dict) else None
    uid = data.get("uniqueId") if isinstance(data, dict) else None
    if uid:
        uuids.append(uid)

uuids = uuids[:N_RECORDS]
print(f"Returned {len(uuids)} UUIDs:")
for u in uuids:
    print(" -", u)

if not uuids:
    raise SystemExit(
        "No UUIDs returned. Fix CHECKIN_MIXIN_ID and/or add FIRM_ID in metadata if required."
    )

# ----------------------------
# STEP 2: GET FULL JSON FOR EACH UUID
# ----------------------------
print("\nFetching full JSON records via single-record API...")
records = []
for i, uid in enumerate(uuids, start=1):
    rec = get_record(uid)
    records.append(rec)
    if i % 5 == 0 or i == len(uuids):
        print(f"  fetched {i}/{len(uuids)}")
    time.sleep(0.15)  # light throttle

extracted_at = now_utc_ts()

# ----------------------------
# STEP 3: BUILD BRONZE ROWS
# ----------------------------

# 3A) RAW table rows (1 row per check-in)
raw_rows = []
for r in records:
    raw_rows.append({
        "checkinEntityId": s(r.get("uniqueId")),
        "creationDateUtc": s(r.get("creationDate")),
        "modifiedDateUtc": s(r.get("modifiedDate")),
        "ownerFirmId": s(safe_get(r, "owner.firm.entityId")),
        "ownerFirmName": s(safe_get(r, "owner.firm.displayName")),
        "ownerUserId": s(safe_get(r, "owner.user.entityId")),
        "ownerUserName": s(safe_get(r, "owner.user.displayName")),
        "createdByUserId": s(safe_get(r, "createdBy.entityId")),
        "createdByUserName": s(safe_get(r, "createdBy.displayName")),
        "modifiedByUserId": s(safe_get(r, "modifiedBy.entityId")),
        "modifiedByUserName": s(safe_get(r, "modifiedBy.displayName")),
        "statusState": s(safe_get(r, "status.state")),
        "mixinsActive": mixins_active_str(r),
        "rawJson": json.dumps(r, ensure_ascii=False),
        "extractedAtUtc": extracted_at
    })

# 3B) EVENTS table rows (1 row per event)
event_rows = []
for r in records:
    checkin_id = s(r.get("uniqueId"))
    events = safe_get(r, "core_storyboard_execution.events", []) or []
    for ev in events:
        if not isinstance(ev, dict):
            continue
        event_rows.append({
            "checkinEntityId": checkin_id,
            "eventId": s(ev.get("id")),
            "eventType": s(ev.get("eventType")),
            "eventName": s(ev.get("name")),
            "creationDateUtc": s(ev.get("creationDate")),
            "processedDateUtc": s(ev.get("processedDate")),
            "createdByUserId": s(safe_get(ev, "createdBy.entityId")),
            "createdByUserName": s(safe_get(ev, "createdBy.displayName")),
            "sourceTaskId": s(safe_get(ev, "source.taskId")),
            "sourceSceneId": s(safe_get(ev, "source.sceneId")),
            "sourceStoryId": s(safe_get(ev, "source.storyId")),
            "devicePlatform": s(safe_get(ev, "deviceInfo.platform")),
            "deviceName": s(safe_get(ev, "deviceInfo.name")),
            "deviceAppVersion": s(safe_get(ev, "deviceInfo.appVersion")),
            "createdAtRegion": s(safe_get(ev, "createdAt.region")),
            "createdAtLocality": s(safe_get(ev, "createdAt.locality")),
            "createdAtPostalCode": s(safe_get(ev, "createdAt.postalCode")),
            "createdAtTimezoneId": s(safe_get(ev, "createdAt.timezoneId")),
            "createdAtCountryName": s(safe_get(ev, "createdAt.countryName")),
            "createdAtStreetAddress": s(safe_get(ev, "createdAt.streetAddress")),
            "createdAtLatitude": safe_get(ev, "createdAt.geolocation.latitude"),
            "createdAtLongitude": safe_get(ev, "createdAt.geolocation.longitude"),
            "associationsJson": json.dumps(ev.get("associations"), ensure_ascii=False) if ev.get("associations") is not None else None,
            "detailsJson": json.dumps(ev.get("details"), ensure_ascii=False) if ev.get("details") is not None else None,
            "outputMappingsJson": json.dumps(ev.get("outputMappings"), ensure_ascii=False) if ev.get("outputMappings") is not None else None,
            "extractedAtUtc": extracted_at
        })

# 3C) SNAPSHOT table rows (flattened “current state”)
snapshot_rows = []
for r in records:
    snapshot_rows.append({
        "checkinEntityId": s(r.get("uniqueId")),

        "storyboardId": s(safe_get(r, "core_storyboard_execution.id")),
        "storyboardName": s(safe_get(r, "core_storyboard_execution.name")),
        "storyboardStatus": s(safe_get(r, "core_storyboard_execution.status")),
        "planEntityId": s(safe_get(r, "core_storyboard_execution.plan.entityId")),
        "planDisplayName": s(safe_get(r, "core_storyboard_execution.plan.displayName")),

        "needsAttentionStatus": s(safe_get(r, "kraft_heinz_execution.needsAttentionStatus")),

        "visitStatus": s(safe_get(r, "core_yms_execution.visit.status")),
        "visitLocationRegion": s(safe_get(r, "core_yms_execution.visit.location.region")),
        "visitLocationLocality": s(safe_get(r, "core_yms_execution.visit.location.locality")),
        "visitLocationPostalCode": s(safe_get(r, "core_yms_execution.visit.location.postalCode")),
        "visitLocationTimezoneId": s(safe_get(r, "core_yms_execution.visit.location.timezoneId")),
        "visitLocationCountryName": s(safe_get(r, "core_yms_execution.visit.location.countryName")),
        "visitLocationStreetAddress": s(safe_get(r, "core_yms_execution.visit.location.streetAddress")),
        "visitLocationLatitude": safe_get(r, "core_yms_execution.visit.location.geolocation.latitude"),
        "visitLocationLongitude": safe_get(r, "core_yms_execution.visit.location.geolocation.longitude"),

        "driverEntityId": s(safe_get(r, "core_yms_execution.driver.entityId")),
        "driverDisplayName": s(safe_get(r, "core_yms_execution.driver.displayName")),
        "driverFirmId": s(safe_get(r, "core_yms_execution.driver.denormalizedProperties.owner.firm.entityId")),
        "driverFirmName": s(safe_get(r, "core_yms_execution.driver.denormalizedProperties.owner.firm.displayName")),
        "driverEmailPrimary": s(safe_get(r, "core_yms_execution.driver.denormalizedProperties.person.emails.0.value")),

        "appointmentRequestName": s(safe_get(r, "core_yms_execution.queries.appointment.request.name")),
        "appointmentResponseStatus": s(safe_get(r, "core_yms_execution.queries.appointment.response.status")),
        "noAppointment": safe_get(r, "core_yms_execution.noAppointment"),

        "nextTask": s(safe_get(r, "sharedContext.nextTask")),
        "extractedAtUtc": extracted_at
    })

# ----------------------------
# STEP 4: CREATE DATAFRAMES WITH EXPLICIT SCHEMA
# ----------------------------
schema_raw = StructType([
    StructField("checkinEntityId", StringType(), True),
    StructField("creationDateUtc", StringType(), True),
    StructField("modifiedDateUtc", StringType(), True),
    StructField("ownerFirmId", StringType(), True),
    StructField("ownerFirmName", StringType(), True),
    StructField("ownerUserId", StringType(), True),
    StructField("ownerUserName", StringType(), True),
    StructField("createdByUserId", StringType(), True),
    StructField("createdByUserName", StringType(), True),
    StructField("modifiedByUserId", StringType(), True),
    StructField("modifiedByUserName", StringType(), True),
    StructField("statusState", StringType(), True),
    StructField("mixinsActive", StringType(), True),
    StructField("rawJson", StringType(), True),
    StructField("extractedAtUtc", TimestampType(), True),
])

schema_events = StructType([
    StructField("checkinEntityId", StringType(), True),
    StructField("eventId", StringType(), True),
    StructField("eventType", StringType(), True),
    StructField("eventName", StringType(), True),
    StructField("creationDateUtc", StringType(), True),
    StructField("processedDateUtc", StringType(), True),
    StructField("createdByUserId", StringType(), True),
    StructField("createdByUserName", StringType(), True),
    StructField("sourceTaskId", StringType(), True),
    StructField("sourceSceneId", StringType(), True),
    StructField("sourceStoryId", StringType(), True),
    StructField("devicePlatform", StringType(), True),
    StructField("deviceName", StringType(), True),
    StructField("deviceAppVersion", StringType(), True),
    StructField("createdAtRegion", StringType(), True),
    StructField("createdAtLocality", StringType(), True),
    StructField("createdAtPostalCode", StringType(), True),
    StructField("createdAtTimezoneId", StringType(), True),
    StructField("createdAtCountryName", StringType(), True),
    StructField("createdAtStreetAddress", StringType(), True),
    StructField("createdAtLatitude", DoubleType(), True),
    StructField("createdAtLongitude", DoubleType(), True),
    StructField("associationsJson", StringType(), True),
    StructField("detailsJson", StringType(), True),
    StructField("outputMappingsJson", StringType(), True),
    StructField("extractedAtUtc", TimestampType(), True),
])

schema_snapshot = StructType([
    StructField("checkinEntityId", StringType(), True),

    StructField("storyboardId", StringType(), True),
    StructField("storyboardName", StringType(), True),
    StructField("storyboardStatus", StringType(), True),
    StructField("planEntityId", StringType(), True),
    StructField("planDisplayName", StringType(), True),

    StructField("needsAttentionStatus", StringType(), True),

    StructField("visitStatus", StringType(), True),
    StructField("visitLocationRegion", StringType(), True),
    StructField("visitLocationLocality", StringType(), True),
    StructField("visitLocationPostalCode", StringType(), True),
    StructField("visitLocationTimezoneId", StringType(), True),
    StructField("visitLocationCountryName", StringType(), True),
    StructField("visitLocationStreetAddress", StringType(), True),
    StructField("visitLocationLatitude", DoubleType(), True),
    StructField("visitLocationLongitude", DoubleType(), True),

    StructField("driverEntityId", StringType(), True),
    StructField("driverDisplayName", StringType(), True),
    StructField("driverFirmId", StringType(), True),
    StructField("driverFirmName", StringType(), True),
    StructField("driverEmailPrimary", StringType(), True),

    StructField("appointmentRequestName", StringType(), True),
    StructField("appointmentResponseStatus", StringType(), True),
    StructField("noAppointment", BooleanType(), True),

    StructField("nextTask", StringType(), True),
    StructField("extractedAtUtc", TimestampType(), True),
])

df_raw = spark.createDataFrame(raw_rows, schema=schema_raw)
df_events = spark.createDataFrame(event_rows, schema=schema_events)
df_snapshot = spark.createDataFrame(snapshot_rows, schema=schema_snapshot)

print("\nCounts:")
print("raw:", df_raw.count())
print("events:", df_events.count())
print("snapshot:", df_snapshot.count())

# ----------------------------
# STEP 5: DROP + RECREATE TABLES (overwrite)
# ----------------------------
spark.sql(f"DROP TABLE IF EXISTS {TBL_RAW}")
spark.sql(f"DROP TABLE IF EXISTS {TBL_EVENTS}")
spark.sql(f"DROP TABLE IF EXISTS {TBL_SNAPSHOT}")

df_raw.write.format("delta").mode("overwrite").saveAsTable(TBL_RAW)
df_events.write.format("delta").mode("overwrite").saveAsTable(TBL_EVENTS)
df_snapshot.write.format("delta").mode("overwrite").saveAsTable(TBL_SNAPSHOT)

print("\n✅ Created and loaded Bronze tables:")
print(" -", TBL_RAW)
print(" -", TBL_EVENTS)
print(" -", TBL_SNAPSHOT)

# quick peek
print("\nSample snapshot rows:")
df_snapshot.select(
    "checkinEntityId", "storyboardId", "storyboardName", "visitStatus", "appointmentRequestName", "needsAttentionStatus"
).show(10, truncate=False)


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

HEADERS = {
    "Authorization": f"Bearer {VECTOR_TOKEN}",
    "Accept": "application/json"
}

workflow_entity_id = "54809ba0-e1c6-46ec-af52-a392803a36b0"

url = f"https://api.withvector.com/1.0/entities/records/{workflow_entity_id}"
r = requests.get(url, headers=HEADERS, timeout=60)

print("GET", url)
print("HTTP:", r.status_code)
r.raise_for_status()

wf = r.json()

print("\nTop-level keys:", list(wf.keys()))
print("uniqueId:", wf.get("uniqueId"))
print("creationDate:", wf.get("creationDate"))
print("modifiedDate:", wf.get("modifiedDate"))

mixins = (wf.get("mixins") or {}).get("active") or []
print("\nMixins.active:")
for m in mixins:
    if isinstance(m, dict):
        print(" -", m.get("displayName"), m.get("entityId"))

print("\n=== FULL WORKFLOW JSON (truncated) ===")
print(json.dumps(wf, indent=2)[:99000])


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

import requests, json, re, time

# =========================
# CONFIG
# =========================
from notebookutils import mssparkutils

# --- Read secrets from Azure Key Vault ---
VECTOR_TOKEN = mssparkutils.credentials.getSecret(
    "https://keyvault-fabric2.vault.azure.net/",
    "VECTORTOKEN"
)
FIRM_ID      = "8ccd57ef-16a5-4b54-acd3-926af17d7139"
FAIRLIFE_MIXIN_ID = "5a30a865-1353-4363-ac11-1248cb13e15d"

QUERY_ENDPOINT = "https://api.withvector.com/1.0/entities/query"
RECORD_ENDPOINT = "https://api.withvector.com/1.0/entities/records/{}"

HEADERS = {
    "Authorization": f"Bearer {VECTOR_TOKEN}",
    "Accept": "application/json",
    "Content-Type": "application/json",
}

UUID_RE = re.compile(r"^[0-9a-fA-F-]{8}-[0-9a-fA-F-]{4}-[0-9a-fA-F-]{4}-[0-9a-fA-F-]{4}-[0-9a-fA-F-]{12}$")

# =========================
# HELPERS
# =========================
def post_entities_query(size=10, offset=0, firm_id=None, mixin_id=None, leaf=True):
    payload = {
        "metadata": {
            "size": size,
            "offset": offset,
            "shouldIncludeLeafEntities": bool(leaf)
        }
    }
    if firm_id:
        payload["metadata"]["firmId"] = firm_id

    if mixin_id:
        payload["filters"] = [{
            "type": "containsEdge",
            "path": "mixins.active",
            "values": [{"entityId": mixin_id}]
        }]

    r = requests.post(QUERY_ENDPOINT, headers=HEADERS, data=json.dumps(payload), timeout=60)
    r.raise_for_status()
    return r.json()

def get_record(eid):
    url = RECORD_ENDPOINT.format(eid)
    r = requests.get(url, headers=HEADERS, timeout=60)
    r.raise_for_status()
    return r.json()

def find_entity_ids(obj, path="$", hits=None):
    if hits is None:
        hits = []
    if isinstance(obj, dict):
        # capture entityId occurrences
        if "entityId" in obj and isinstance(obj["entityId"], str) and UUID_RE.match(obj["entityId"]):
            hits.append((path + ".entityId", obj["entityId"], obj.get("displayName"), obj.get("entityType")))
        for k, v in obj.items():
            find_entity_ids(v, f"{path}.{k}", hits)
    elif isinstance(obj, list):
        for i, v in enumerate(obj):
            find_entity_ids(v, f"{path}[{i}]", hits)
    return hits

def mixin_names(rec):
    mx = ((rec.get("mixins") or {}).get("active") or [])
    out = []
    for m in mx:
        if isinstance(m, dict) and m.get("displayName"):
            out.append(m["displayName"])
    return out

# =========================
# 1) GET 10 FAIRLIFE DOCS (entityIds)
# =========================
print("Querying 10 Fairlife Shipment Documents (leaf + firmId + mixin)...")
resp = post_entities_query(size=10, offset=0, firm_id=FIRM_ID, mixin_id=FAIRLIFE_MIXIN_ID, leaf=True)

children = resp.get("children") or []
print("Returned children:", len(children))
print("totalEntityMatchCount:", (resp.get("metadata") or {}).get("totalEntityMatchCount"))

# IMPORTANT: in Vector query results, the entityId is typically under child["data"]["uniqueId"] OR child["data"]["entityId"]
# Your earlier probes showed "uniqueId: None" because you were looking at the wrong place.
# We'll print the keys and extract safely.

doc_ids = []
for i, c in enumerate(children):
    data = c.get("data") or {}
    # Try the common places
    eid = data.get("uniqueId") or data.get("entityId") or c.get("uniqueId")
    if isinstance(eid, str) and UUID_RE.match(eid):
        doc_ids.append(eid)
    else:
        # last resort: scan this child object for the first UUID-looking entityId
        hits = find_entity_ids(c)
        if hits:
            doc_ids.append(hits[0][1])

print("\n=== 10 Fairlife Doc UUIDs ===")
for x in doc_ids:
    print(x)

if not doc_ids:
    raise SystemExit("No doc UUIDs extracted from query response. Need to inspect child['data'] structure.")

# =========================
# 2) GET ONE DOC RECORD JSON
# =========================
DOC_ID = doc_ids[0]
print("\nFetching full JSON for first doc:", DOC_ID)
doc = get_record(DOC_ID)

print("Doc uniqueId:", doc.get("uniqueId"))
print("Doc creationDate:", doc.get("creationDate"))
print("Doc mixins:", mixin_names(doc))

# =========================
# 3) FIND LINKED ENTITY IDS INSIDE DOC
# =========================
hits = find_entity_ids(doc)
print("\nTotal entityId refs inside doc:", len(hits))

# show top 40 paths to see what's available
print("\nSample linked entityId refs (first 40):")
for p, eid, dn, et in hits[:40]:
    print("-", p, "=>", eid, "|", dn, "| entityType:", et)

# prioritize likely workflow/YMS keywords in the JSON path
keywords = ("workflow", "storyboard", "execution", "plan", "yms", "yard", "move", "shuttle", "checkin", "checkout", "load")
priority = [h for h in hits if any(k in h[0].lower() for k in keywords)]
print("\nPriority refs (keyword path match):", len(priority))
for p, eid, dn, et in priority[:50]:
    print("-", p, "=>", eid, "|", dn, "| entityType:", et)

# =========================
# 4) FETCH A FEW LINKED RECORDS AND IDENTIFY THE REAL "DATA" ONES
# =========================
to_fetch = []
seen = set()
for p, eid, dn, et in (priority + hits):
    if eid not in seen and eid != DOC_ID:
        seen.add(eid)
        to_fetch.append((p, eid, dn, et))
    if len(to_fetch) >= 15:
        break

print("\nFetching up to 15 linked records to find the one with yard metrics...")
for p, eid, dn, et in to_fetch:
    try:
        rec = get_record(eid)
        mx = mixin_names(rec)
        top_keys = list(rec.keys())[:25]
        print("\n----------------------------------")
        print("Path:", p)
        print("Linked entityId:", eid, "|", dn)
        print("Mixins:", mx)
        print("Top-level keys:", top_keys)

        # quick signal: does this record contain an 'entity' payload with operational fields?
        entity_blob = rec.get("entity") or {}
        if entity_blob:
            # print first-level keys under entity to help you spot yms/workflow fields
            print("entity.* keys:", list(entity_blob.keys())[:25])

    except Exception as e:
        print("\n----------------------------------")
        print("FAILED fetching linked:", eid, "|", dn)
        print("Error:", str(e)[:300])
        continue


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
FAIRLIFE_SHIPMENT_DOC_MIXIN = "54809ba0-e1c6-46ec-af52-a392803a36b0"

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

import requests
import json

# =========================
# CONFIG
# =========================
BASE_URL = "https://api.withvector.com/1.0"
ENTITY_ID = "30ea9894-afc4-47d1-973e-411b802df628"

from notebookutils import mssparkutils

# --- Read secrets from Azure Key Vault ---
VECTOR_TOKEN = mssparkutils.credentials.getSecret(
    "https://keyvault-fabric2.vault.azure.net/",
    "VECTORTOKEN"
)

HEADERS = {
    "Authorization": f"Bearer {TOKEN}",
    "Content-Type": "application/json"
}

# =========================
# FETCH SINGLE ENTITY JSON
# =========================
url = f"{BASE_URL}/entities/records/{ENTITY_ID}"

resp = requests.get(url, headers=HEADERS, timeout=60)
resp.raise_for_status()

entity_json = resp.json()

# =========================
# OUTPUT
# =========================
print("Fetched Check-In Entity UUID:", entity_json.get("uniqueId"))
print("Creation Date:", entity_json.get("creationDate"))
print("Modified Date:", entity_json.get("modifiedDate"))
print("\n===== FULL JSON DUMP =====\n")
print(json.dumps(entity_json, indent=2))


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

import requests
import json

# =========================
# CONFIG
# =========================
from notebookutils import mssparkutils

# --- Read secrets from Azure Key Vault ---
VECTOR_TOKEN = mssparkutils.credentials.getSecret(
    "https://keyvault-fabric2.vault.azure.net/",
    "VECTORTOKEN"
)
ENTITY_UUID  = "30ea9894-afc4-47d1-973e-411b802df628"

URL = f"https://api.withvector.com/1.0/entities/records/{ENTITY_UUID}"

HEADERS = {
    "Authorization": f"Bearer {VECTOR_TOKEN}",
    "Content-Type": "application/json"
}

# =========================
# CALL API
# =========================
response = requests.get(URL, headers=HEADERS, timeout=60)

# =========================
# VALIDATE RESPONSE
# =========================
print("HTTP Status:", response.status_code)

if response.status_code != 200:
    print("ERROR RESPONSE:")
    print(response.text)
    raise SystemExit("Failed to fetch entity JSON")

# =========================
# PARSE + DISPLAY JSON
# =========================
entity_json = response.json()

print("\n===== FULL ENTITY JSON =====\n")
print(json.dumps(entity_json, indent=2))


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
HEADERS = {"Authorization": f"Bearer {VECTOR_TOKEN}", "Accept": "application/json"}

INSTANCE_ID = "116d63aa-719e-4d05-8042-08b11a006639"
url = f"https://api.withvector.com/1.0/entities/records/{INSTANCE_ID}"

r = requests.get(url, headers=HEADERS, timeout=120)
print("GET", url)
print("HTTP:", r.status_code)
r.raise_for_status()

obj = r.json()

print("\nTop-level keys:", list(obj.keys()))
print("uniqueId:", obj.get("uniqueId"))
print("creationDate:", obj.get("creationDate"))
print("modifiedDate:", obj.get("modifiedDate"))

mixins = (obj.get("mixins") or {}).get("active") or []
print("\nMixins.active:")
for m in mixins:
    if isinstance(m, dict):
        print(" -", m.get("displayName"), m.get("entityId"))

print("\n=== FULL JSON (first 12000 chars) ===")
print(json.dumps(obj, indent=2)[:99000])


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
QUERY_URL = "https://api.withvector.com/1.0/entities/query"

FAIRLIFE_SHIPMENT_MIXIN = "5a30a865-1353-4363-ac11-1248cb13e15d"
FIRM_ID = "8ccd57ef-16a5-4b54-acd3-926af17d7139"

headers = {
    "Authorization": f"Bearer {TOKEN}",
    "Content-Type": "application/json"
}

payload = {
    "filters": [{
        "type": "containsEdge",
        "path": "mixins.active",
        "values": [{"entityId": FAIRLIFE_SHIPMENT_MIXIN}]
    }]
}

resp = requests.post(QUERY_URL, headers=headers, json=payload)
resp.raise_for_status()

shipment_ids = [
    c["data"]["entityId"]
    for c in resp.json()["children"]
    if c.get("data", {}).get("entityId")
]

print("Fairlife Shipment Document UUIDs:")
for i in shipment_ids:
    print(i)


FAIRLIFE_CHECKIN_MIXIN = "54809ba0-e1c6-46ec-af52-a392803a36b0"

payload = {
    "filters": [{
        "type": "containsEdge",
        "path": "mixins.active",
        "values": [{"entityId": FAIRLIFE_CHECKIN_MIXIN}]
    }]
}

resp = requests.post(QUERY_URL, headers=headers, json=payload)
resp.raise_for_status()

checkin_ids = [
    c["data"]["entityId"]
    for c in resp.json()["children"]
    if c.get("data", {}).get("entityId")
]

print("\nFairlife Check-In UUIDs:")
for i in checkin_ids:
    print(i)


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

import requests
import json
from pprint import pprint

BASE_URL = "https://api.withvector.com/1.0"
QUERY_ENDPOINT = f"{BASE_URL}/entities/query"
RECORD_ENDPOINT = f"{BASE_URL}/entities/records"

from notebookutils import mssparkutils

# --- Read secrets from Azure Key Vault ---
VECTOR_TOKEN = mssparkutils.credentials.getSecret(
    "https://keyvault-fabric2.vault.azure.net/",
    "VECTORTOKEN"
)

FAIRLIFE_SHIPMENT_MIXIN = "5a30a865-1353-4363-ac11-1248cb13e15d"
FAIRLIFE_FIRM_ID = "8ccd57ef-16a5-4b54-acd3-926af17d7139"

HEADERS = {
    "Authorization": f"Bearer {TOKEN}",
    "Content-Type": "application/json"
}

def fetch_10_fairlife_shipments():
    payload = {
        "filters": [
            {
                "type": "containsEdge",
                "path": "mixins.active",
                "values": [
                    {"entityId": FAIRLIFE_SHIPMENT_MIXIN}
                ]
            }
        ],
        "metadata": {
            "size": 10,
            "offset": 0,
            "shouldIncludeLeafEntities": True,
            "firmIds": [FAIRLIFE_FIRM_ID]
        }
    }

    r = requests.post(
        QUERY_ENDPOINT,
        headers=HEADERS,
        data=json.dumps(payload),
        timeout=60
    )
    r.raise_for_status()
    data = r.json()

    shipment_ids = []
    for c in data.get("children", []):
        entity_id = c.get("data", {}).get("entityId")
        if entity_id:
            shipment_ids.append(entity_id)

    return shipment_ids

def fetch_checkins_for_shipment(shipment_uuid):
    r = requests.get(
        f"{RECORD_ENDPOINT}/{shipment_uuid}",
        headers=HEADERS,
        timeout=60
    )
    r.raise_for_status()
    entity = r.json()

    # Check-ins / workflows are referenced here
    docs = (
        entity
        .get("core_storyboard_execution", {})
        .get("documents", [])
    )

    checkin_ids = []
    for d in docs:
        eid = d.get("entityId")
        if eid:
            checkin_ids.append(eid)

    return checkin_ids

print("Fetching 10 Fairlife Shipment UUIDs...")
shipment_ids = fetch_10_fairlife_shipments()

print(f"\nFound {len(shipment_ids)} shipment UUIDs:")
for s in shipment_ids:
    print("  Shipment:", s)

results = []

print("\nFetching Check-In UUIDs for each shipment...\n")
for shipment_id in shipment_ids:
    checkins = fetch_checkins_for_shipment(shipment_id)
    results.append({
        "shipment_uuid": shipment_id,
        "checkin_uuids": checkins
    })

print("\nFINAL RESULT")
pprint(results)


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }
