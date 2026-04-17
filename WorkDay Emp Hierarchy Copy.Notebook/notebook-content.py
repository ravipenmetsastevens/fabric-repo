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

# ============================================================
# Workday HR: Update ONLY wd_worker_bronze to add Active/Status
# - Does NOT touch org/bridge/edge tables
# - Adds 2 columns to wd_worker_bronze (if missing):
#     is_active        (string "1"/"0" when present)
#     worker_status_id (e.g., "Active", "Terminated", etc. when present)
# - Full reload of wd_worker_bronze ONLY (overwrite)
# ============================================================

import os, time, uuid, requests, jwt
from pathlib import Path
import xml.etree.ElementTree as ET
from datetime import datetime, timezone

from pyspark.sql.types import (
    StructType, StructField, StringType, TimestampType
)

# -------------------------
# 0) Config (same as yours)
# -------------------------
HOST = os.getenv("WORKDAY_HOST", "https://services1.wd503.myworkday.com").rstrip("/")
TENANT = os.getenv("WORKDAY_TENANT", "stevenstransport")

from notebookutils import mssparkutils

# --- Read secrets from Azure Key Vault ---
CLIENT_ID = mssparkutils.credentials.getSecret(
    "https://keyvault-fabric2.vault.azure.net/",
    "WORKDAYCLIENTID"
)
ISU_SUBJECT = os.getenv("WORKDAY_ISU_SUBJECT", "ISU_Ms_Fabric")
HR_VERSION = os.getenv("WORKDAY_HR_VERSION", "v45.0")

TOKEN_URL = f"{HOST}/ccx/oauth2/{TENANT}/token"
HR_URL    = f"{HOST}/ccx/service/{TENANT}/Human_Resources/{HR_VERSION}"

HTTP_TIMEOUT = 240
TOKEN_TTL_SECONDS = 300
TOKEN_REFRESH_SKEW_SECONDS = 45

DEFAULT_KEY_PATHS = [
    "/lakehouse/data_central_lh/Files/workday_integration.key",
    "/lakehouse/default/Files/workday_integration.key"
]

NS = {"wd": "urn:com.workday/bsvc", "env": "http://schemas.xmlsoap.org/soap/envelope/"}

def info(m): print(f"[INFO] {m}", flush=True)
def warn(m): print(f"[WARN] {m}", flush=True)

DB = spark.catalog.currentDatabase()
T_WORKER = f"{DB}.wd_worker_bronze"

# -------------------------
# 1) Auth (JWT -> OAuth2 token)
# -------------------------
def read_private_key() -> str:
    for p in DEFAULT_KEY_PATHS:
        if Path(p).is_file():
            return Path(p).read_text(encoding="utf-8")
    raise FileNotFoundError(f"Private key not found. Checked: {DEFAULT_KEY_PATHS}")

SESSION = requests.Session()

class TokenManager:
    def __init__(self):
        self.token = None
        self.acquired_at = 0

    def _fetch_token(self) -> str:
        now = int(time.time())
        private_key = read_private_key()
        claims = {
            "iss": CLIENT_ID,
            "sub": ISU_SUBJECT,
            "aud": TOKEN_URL,
            "iat": now,
            "exp": now + TOKEN_TTL_SECONDS,
            "jti": str(uuid.uuid4())
        }
        assertion = jwt.encode(claims, private_key, algorithm="RS256")
        if isinstance(assertion, bytes):
            assertion = assertion.decode("utf-8")

        data = {"grant_type": "urn:ietf:params:oauth:grant-type:jwt-bearer", "assertion": assertion}
        r = SESSION.post(TOKEN_URL, data=data, timeout=HTTP_TIMEOUT)
        r.raise_for_status()
        j = r.json()
        if "access_token" not in j:
            raise RuntimeError(f"Token response missing access_token: {str(j)[:1200]}")
        return j["access_token"]

    def get(self) -> str:
        now = int(time.time())
        if self.token is None or (now - self.acquired_at) >= (TOKEN_TTL_SECONDS - TOKEN_REFRESH_SKEW_SECONDS):
            info("Getting token…")
            self.token = self._fetch_token()
            self.acquired_at = now
            info("Token OK")
        return self.token

TOKEN_MGR = TokenManager()

def soap_post(url: str, soap_xml: str) -> str:
    token = TOKEN_MGR.get()
    headers = {"Content-Type": "text/xml; charset=utf-8", "Authorization": f"Bearer {token}", "SOAPAction": ""}
    r = SESSION.post(url, data=soap_xml.encode("utf-8"), headers=headers, timeout=HTTP_TIMEOUT)

    if r.status_code in (401, 403):
        warn(f"HTTP {r.status_code} (auth). Refreshing token and retrying once…")
        TOKEN_MGR.token = None
        token = TOKEN_MGR.get()
        headers["Authorization"] = f"Bearer {token}"
        r = SESSION.post(url, data=soap_xml.encode("utf-8"), headers=headers, timeout=HTTP_TIMEOUT)

    if r.status_code >= 400:
        warn(f"SOAP HTTP {r.status_code} from {url}")
        warn("SOAP fault/body excerpt (first 4000 chars):")
        print(r.text[:4000])
        raise RuntimeError(f"SOAP HTTP {r.status_code}")
    return r.text

# -------------------------
# 2) SOAP builder (same flags that work in your tenant)
# -------------------------
WORKER_FLAGS = [
    "Include_Reference",
    "Include_Personal_Information",
    "Include_Employment_Information",
    "Include_Organizations",
]

def build_get_workers(page:int, count:int) -> str:
    rg = "\n".join([f"<wd:{f}>true</wd:{f}>" for f in WORKER_FLAGS])
    return f"""<?xml version="1.0" encoding="UTF-8"?>
<env:Envelope xmlns:env="http://schemas.xmlsoap.org/soap/envelope/" xmlns:wd="urn:com.workday/bsvc">
  <env:Body>
    <wd:Get_Workers_Request wd:version="{HR_VERSION}">
      <wd:Response_Filter><wd:Page>{page}</wd:Page><wd:Count>{count}</wd:Count></wd:Response_Filter>
      <wd:Response_Group>{rg}</wd:Response_Group>
    </wd:Get_Workers_Request>
  </env:Body>
</env:Envelope>
"""

# -------------------------
# 3) XML helpers
# -------------------------
def t(node):
    if node is None: return None
    txt = node.text
    return txt.strip() if txt else None

def id_by_type(parent, wd_type: str):
    if parent is None: return None
    for n in parent.findall("wd:ID", NS):
        if n.get(f"{{{NS['wd']}}}type") == wd_type:
            return t(n)
    return None

def get_response_results(root):
    def tx(xp):
        n = root.find(xp, NS)
        return (n.text.strip() if n is not None and n.text else None)
    return {
        "Total_Results": tx(".//wd:Response_Results/wd:Total_Results"),
        "Total_Pages":   tx(".//wd:Response_Results/wd:Total_Pages"),
        "Page_Results":  tx(".//wd:Response_Results/wd:Page_Results"),
        "Page":          tx(".//wd:Response_Results/wd:Page"),
    }

def safe_find_text(elem, xpaths):
    if elem is None: return None
    for xp in xpaths:
        n = elem.find(xp, NS)
        v = t(n)
        if v:
            return v
    return None

# -------------------------
# 4) Worker extractor (ONLY change: add is_active + worker_status_id)
# -------------------------
def extract_worker_row(worker_elem, run_id, extract_ts_utc):
    wref = worker_elem.find("wd:Worker_Reference", NS)
    worker_wid = id_by_type(wref, "WID")
    employee_id = id_by_type(wref, "Employee_ID") or id_by_type(wref, "Contingent_Worker_ID")
    descriptor = t(worker_elem.find("wd:Worker_Descriptor", NS))

    wd = worker_elem.find("wd:Worker_Data", NS)
    worker_id = t(wd.find("wd:Worker_ID", NS)) if wd is not None else None
    user_id   = t(wd.find("wd:User_ID", NS)) if wd is not None else None

    first_name = safe_find_text(wd, [
        ".//wd:Personal_Data/wd:Name_Data/wd:Preferred_Name_Data/wd:Name_Detail_Data/wd:First_Name",
        ".//wd:Personal_Data/wd:Name_Data/wd:Legal_Name_Data/wd:Name_Detail_Data/wd:First_Name",
    ])

    middle_name = safe_find_text(wd, [
        ".//wd:Personal_Data/wd:Name_Data/wd:Preferred_Name_Data/wd:Name_Detail_Data/wd:Middle_Name",
        ".//wd:Personal_Data/wd:Name_Data/wd:Legal_Name_Data/wd:Name_Detail_Data/wd:Middle_Name",
    ])

    last_name = safe_find_text(wd, [
        ".//wd:Personal_Data/wd:Name_Data/wd:Preferred_Name_Data/wd:Name_Detail_Data/wd:Last_Name",
        ".//wd:Personal_Data/wd:Name_Data/wd:Legal_Name_Data/wd:Name_Detail_Data/wd:Last_Name",
    ])

    email = user_id if (user_id and "@" in user_id) else None

    # --- NEW: Active/Status (from Employment_Data/Worker_Status_Data)
    # Common Workday structure:
    # Worker_Data -> Employment_Data -> Worker_Status_Data -> Active
    # Worker_Data -> Employment_Data -> Worker_Status_Data -> Worker_Status_Reference -> ID[@wd:type='Worker_Status_ID']
    is_active = safe_find_text(wd, [
        ".//wd:Employment_Data/wd:Worker_Status_Data/wd:Active",
        ".//wd:Worker_Status_Data/wd:Active",
    ])

    worker_status_id = safe_find_text(wd, [
        ".//wd:Employment_Data/wd:Worker_Status_Data/wd:Worker_Status_Reference/wd:ID[@wd:type='Worker_Status_ID']",
        ".//wd:Worker_Status_Data/wd:Worker_Status_Reference/wd:ID[@wd:type='Worker_Status_ID']",
    ])

    return {
        "run_id": run_id,
        "extract_ts_utc": extract_ts_utc,
        "worker_wid": worker_wid,
        "employee_id": employee_id,
        "worker_id": worker_id,
        "user_id": user_id,
        "email": email,
        "worker_descriptor": descriptor,
        "first_name": first_name,
        "middle_name": middle_name,
        "last_name": last_name,
        # NEW
        "is_active": is_active,
        "worker_status_id": worker_status_id,
    }

# -------------------------
# 5) Updated schema for wd_worker_bronze ONLY
# -------------------------
WORKER_SCHEMA_V2 = StructType([
    StructField("run_id", StringType(), True),
    StructField("extract_ts_utc", TimestampType(), True),
    StructField("worker_wid", StringType(), True),
    StructField("employee_id", StringType(), True),
    StructField("worker_id", StringType(), True),
    StructField("user_id", StringType(), True),
    StructField("email", StringType(), True),
    StructField("worker_descriptor", StringType(), True),
    StructField("first_name", StringType(), True),
    StructField("middle_name", StringType(), True),
    StructField("last_name", StringType(), True),
    # NEW
    StructField("is_active", StringType(), True),
    StructField("worker_status_id", StringType(), True),
])

# -------------------------
# 6) Ensure columns exist (ALTER TABLE only)
# -------------------------
def ensure_worker_columns():
    # If table doesn't exist, create it (worker only)
    if not spark.catalog.tableExists(T_WORKER):
        info(f"wd_worker_bronze not found. Creating {T_WORKER} ...")
        spark.createDataFrame([], WORKER_SCHEMA_V2).write.format("delta").mode("overwrite").saveAsTable(T_WORKER)
        info(f"✅ Created {T_WORKER} with new columns.")
        return

    # Add missing columns safely
    existing_cols = {c.name.lower() for c in spark.table(T_WORKER).schema.fields}

    alters = []
    if "is_active" not in existing_cols:
        alters.append("is_active STRING")
    if "worker_status_id" not in existing_cols:
        alters.append("worker_status_id STRING")

    if alters:
        stmt = f"ALTER TABLE {T_WORKER} ADD COLUMNS ({', '.join(alters)})"
        info(f"Adding missing columns: {stmt}")
        spark.sql(stmt)
        info("✅ Columns added.")
    else:
        info("✅ wd_worker_bronze already has is_active + worker_status_id columns.")

# -------------------------
# 7) Paging (worker only) with hard stop + defensive empty-page stop
# -------------------------
class PageSizeManager:
    def __init__(self, sizes):
        self.sizes = sizes[:]
        self.idx = 0

    def size(self):
        return self.sizes[self.idx]

    def record_failure(self):
        if self.idx < len(self.sizes) - 1:
            self.idx += 1
            return self.sizes[self.idx]
        return None

    def record_success(self):
        pass

def reload_workers_only(page_sizes=(100, 50, 25, 10), sleep_between_pages=0.12, max_pages=None):
    run_id = str(uuid.uuid4())
    extract_ts_utc = datetime.now(timezone.utc).replace(tzinfo=None)
    info(f"Reloading ONLY workers -> {T_WORKER}")
    info(f"run_id={run_id} extract_ts_utc={extract_ts_utc}")

    psm = PageSizeManager(list(page_sizes))
    page = 1
    total_pages_reported = None
    total_written = 0
    consecutive_empty = 0

    rows_all = []

    while True:
        if max_pages is not None and page > int(max_pages):
            warn(f"max_pages hit ({max_pages}). Stopping early for test.")
            break

        soap = build_get_workers(page=page, count=psm.size())
        try:
            xml_text = soap_post(HR_URL, soap)
        except Exception as e:
            warn(f"Get_Workers page {page} failed at size={psm.size()}: {e}")
            nxt = psm.record_failure()
            if nxt is None:
                raise
            warn(f"Retrying page {page} with smaller page_size={nxt}")
            continue

        root = ET.fromstring(xml_text)
        rr = get_response_results(root)

        if rr.get("Total_Pages"):
            try:
                total_pages_reported = int(rr["Total_Pages"])
            except:
                pass

        workers = root.findall(".//wd:Response_Data/wd:Worker", NS)

        if not workers:
            consecutive_empty += 1
            warn(f"Empty page {page} (consecutive_empty={consecutive_empty})")
            if consecutive_empty >= 3:
                warn("3 consecutive empty pages -> stopping defensively.")
                break
            page += 1
            continue
        else:
            consecutive_empty = 0

        batch = [extract_worker_row(w, run_id, extract_ts_utc) for w in workers]
        rows_all.extend(batch)
        total_written += len(batch)

        if page == 1:
            info(f"[Probe] First batch sample:")
            for r in batch[:5]:
                info({k: r.get(k) for k in ["employee_id", "worker_descriptor", "is_active", "worker_status_id"]})

        if page % 10 == 0:
            info(f"[Workers] page {page}"
                 + (f"/{total_pages_reported}" if total_pages_reported else "")
                 + f" | total_rows_collected={total_written} | page_size={psm.size()}")

        if total_pages_reported is not None and page >= total_pages_reported:
            break

        page += 1
        psm.record_success()
        time.sleep(sleep_between_pages)

    # Overwrite worker table only (and allow schema overwrite if it was older)
    info(f"Writing {len(rows_all)} rows to {T_WORKER} (overwrite worker table only)")
    (
        spark.createDataFrame(rows_all, WORKER_SCHEMA_V2)
             .write.format("delta")
             .mode("overwrite")
             .option("overwriteSchema", "true")
             .saveAsTable(T_WORKER)
    )

    info("✅ Done. Worker table refreshed with is_active + worker_status_id.")
    info(f"Total rows written: {len(rows_all)}")
    info(f"run_id = {run_id}")

# -------------------------
# 8) RUN
# -------------------------
info(f"HR_URL: {HR_URL}")
ensure_worker_columns()

# If you want to validate quickly, set max_pages=2 first.
# Then remove max_pages once stable.
reload_workers_only(max_pages=None)


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

# ============================================================
# Build 10-level CEO chain columns + Department per level
# Output: data_central_lh.dbo.wd_worker_hierarchy_wide (Delta)
#
# Inputs:
#   - data_central_lh.dbo.wd_worker_ceo_chain         (must exist)
#       employee_id, employee_name, manager_employee_id, depth,
#       path_employee_ids, path_names, asof_ts_utc (optional)
#   - data_central_lh.dbo.wd_worker_bronze            (names)
#   - data_central_lh.dbo.wd_worker_sup_org_bronze    (emp->org refs)
#   - data_central_lh.dbo.wd_sup_org_bronze           (org_name/subtype)
#
# Notes:
#   - Picks ONE "department" per employee using rule:
#       prefer org_subtype_id='Department' else latest membership
#   - Overwrites the output table AND schema 
# ============================================================

from pyspark.sql import functions as F
from pyspark.sql.window import Window

# ---------------------------
# 0) Config
# ---------------------------
DB = "data_central_lh"

T_WORKER  = f"{DB}.wd_worker_bronze"
T_SUPORG  = f"{DB}.wd_sup_org_bronze"
T_W_SUP   = f"{DB}.wd_worker_sup_org_bronze"
T_CHAIN   = f"{DB}.wd_worker_ceo_chain"
T_WIDE    = f"{DB}.wd_worker_hierarchy_wide"

MAX_LEVELS = 10

def info(m): print(f"[INFO] {m}", flush=True)

# ---------------------------
# 1) Latest worker names (one row per employee_id)
# ---------------------------
info(f"Reading worker table: {T_WORKER}")
w = spark.table(T_WORKER)

w_latest = (
    w.withColumn(
        "rn",
        F.row_number().over(
            Window.partitionBy("employee_id").orderBy(F.col("extract_ts_utc").desc(), F.col("run_id").desc())
        ),
    )
    .filter(F.col("rn") == 1)
    .select(
        F.col("employee_id").cast("string").alias("employee_id"),
        F.col("worker_descriptor").alias("employee_name"),
        F.col("user_id").alias("user_id"),
        F.col("email").alias("email"),
    )
)

# ---------------------------
# 2) Latest org table (one row per org_ref_id)
# ---------------------------
info(f"Reading supervisory org table: {T_SUPORG}")
o = spark.table(T_SUPORG)

o_latest = (
    o.withColumn(
        "rn",
        F.row_number().over(
            Window.partitionBy("org_ref_id").orderBy(F.col("extract_ts_utc").desc(), F.col("run_id").desc())
        ),
    )
    .filter(F.col("rn") == 1)
    .select(
        F.col("org_ref_id").cast("string").alias("org_ref_id"),
        F.col("org_name").alias("org_name"),
        F.col("org_subtype_id").alias("org_subtype_id"),
        F.col("inactive").alias("org_inactive"),
    )
)

# ---------------------------
# 3) Employee -> Department mapping (pick ONE org_name per employee)
#    RULE:
#      - Prefer org_subtype_id='Department'
#      - Else pick latest ws membership by extract_ts_utc
# ---------------------------
info(f"Reading worker->org membership table: {T_W_SUP}")
ws = spark.table(T_W_SUP)

# Keep latest membership per (employee, org_ref) so duplicates don't skew ranking
ws_latest = (
    ws.withColumn(
        "rn",
        F.row_number().over(
            Window.partitionBy("employee_id", "org_ref_id").orderBy(F.col("extract_ts_utc").desc(), F.col("run_id").desc())
        ),
    )
    .filter(F.col("rn") == 1)
    .select(
        F.col("employee_id").cast("string").alias("employee_id"),
        F.col("org_ref_id").cast("string").alias("org_ref_id"),
        F.col("extract_ts_utc").alias("ws_extract_ts_utc"),
    )
)

ws_named = (
    ws_latest.join(o_latest, "org_ref_id", "left")
             .withColumn(
                 "dept_rank",
                 F.when(F.col("org_subtype_id") == F.lit("Department"), F.lit(0)).otherwise(F.lit(1))
             )
)

dept_pick = (
    ws_named.withColumn(
        "rn_dept",
        F.row_number().over(
            Window.partitionBy("employee_id").orderBy(
                F.col("dept_rank").asc(),
                F.col("ws_extract_ts_utc").desc(),
                F.col("org_ref_id").asc()
            )
        )
    )
    .filter(F.col("rn_dept") == 1)
    .select(
        "employee_id",
        F.col("org_name").alias("department_name"),
        F.col("org_ref_id").alias("department_org_ref_id"),
    )
)

emp_dim = (
    w_latest.join(dept_pick, "employee_id", "left")
            .select("employee_id", "employee_name", "department_name", "department_org_ref_id")
)

# ---------------------------
# 4) Read chain table + split IDs into 10 level EmpID columns
# ---------------------------
info(f"Reading chain table: {T_CHAIN}")
chain = spark.table(T_CHAIN)

# Validate required cols exist
required = {"employee_id","employee_name","manager_employee_id","depth","path_employee_ids","path_names"}
missing = [c for c in required if c not in chain.columns]
if missing:
    raise Exception(f"Chain table is missing required columns: {missing}")

wide = (
    chain.select(
        F.col("employee_id").cast("string").alias("employee_id"),
        F.col("employee_name").alias("employee_name"),
        F.col("manager_employee_id").cast("string").alias("manager_employee_id"),
        F.col("depth").cast("int").alias("depth"),
        F.col("path_employee_ids").alias("path_employee_ids"),
        F.col("path_names").alias("path_names"),
    )
    .withColumn("path_ids_arr", F.split(F.col("path_employee_ids"), r"\s*>\s*"))
)

# Create Level_01_EmpID .. Level_10_EmpID
for i in range(1, MAX_LEVELS + 1):
    wide = wide.withColumn(f"Level_{i:02d}_EmpID", F.element_at(F.col("path_ids_arr"), i))

wide = wide.drop("path_ids_arr")

# ---------------------------
# 5) Join each Level EmpID to employee dimension to get Name + Department
# ---------------------------
for i in range(1, MAX_LEVELS + 1):
    alias = f"lvl{i:02d}"
    wide = (
        wide.join(
            emp_dim.select(
                F.col("employee_id").alias(f"{alias}_employee_id"),
                F.col("employee_name").alias(f"Level_{i:02d}_Name"),
                F.col("department_name").alias(f"Level_{i:02d}_Department"),
                F.col("department_org_ref_id").alias(f"Level_{i:02d}_DepartmentOrgRefID"),
            ),
            wide[f"Level_{i:02d}_EmpID"] == F.col(f"{alias}_employee_id"),
            "left",
        )
        .drop(f"{alias}_employee_id")
    )

# Optional combined display per level: "Name (Dept)"
for i in range(1, MAX_LEVELS + 1):
    wide = wide.withColumn(
        f"Level_{i:02d}",
        F.when(
            F.col(f"Level_{i:02d}_Name").isNotNull() & F.col(f"Level_{i:02d}_Department").isNotNull(),
            F.concat(
                F.col(f"Level_{i:02d}_Name"),
                F.lit(" ("),
                F.col(f"Level_{i:02d}_Department"),
                F.lit(")")
            )
        ).otherwise(F.col(f"Level_{i:02d}_Name"))
    )

wide = wide.withColumn("asof_ts_utc", F.current_timestamp())

# ---------------------------
# 6) Write output (overwrite + overwriteSchema to fix mismatch)
# ---------------------------
info(f"Writing output table (overwrite schema): {T_WIDE}")

wide.write.format("delta") \
    .mode("overwrite") \
    .option("overwriteSchema", "true") \
    .saveAsTable(T_WIDE)

info("✅ Done. Sample:")
display(
    wide.select(
        "employee_id","employee_name","depth",
        "Level_01","Level_02","Level_03","Level_04","Level_05",
        "Level_06","Level_07","Level_08","Level_09","Level_10"
    ).limit(20)
)

# Optional: quick max chain length check (names string)
# display(wide.select(F.size(F.split("path_names", r"\s*>\s*")).alias("levels_count")).agg(F.max("levels_count")).alias("max_levels"))


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

from pyspark.sql import functions as F
from pyspark.sql.window import Window

DB = "data_central_lh"
T_WORKER = f"{DB}.wd_worker_bronze"
T_EDGE   = f"{DB}.wd_worker_manager_edge_bronze"
T_OUT    = f"{DB}.wd_worker_ceo_chain"

# 1) Latest worker names
w = spark.table(T_WORKER)
w_latest = (
    w.withColumn("rn", F.row_number().over(Window.partitionBy("employee_id").orderBy(F.col("extract_ts_utc").desc(), F.col("run_id").desc())))
     .filter("rn = 1")
     .select(F.col("employee_id").cast("string").alias("employee_id"),
             F.col("worker_descriptor").alias("employee_name"))
)

# 2) Latest edges (one manager per employee)
e = spark.table(T_EDGE)
e_latest = (
    e.withColumn("rn", F.row_number().over(Window.partitionBy("employee_id").orderBy(F.col("extract_ts_utc").desc(), F.col("run_id").desc())))
     .filter("rn = 1")
     .select(F.col("employee_id").cast("string").alias("employee_id"),
             F.col("manager_employee_id").cast("string").alias("manager_employee_id"),
             F.col("org_ref_id").cast("string").alias("org_ref_id"))
)

base = (e_latest.join(w_latest, "employee_id", "left")
                .cache())

# ---- Move small graph to driver (safe at ~10k) ----
edges = base.select("employee_id","manager_employee_id","org_ref_id","employee_name").collect()
names = w_latest.collect()

mgr_of = {r["employee_id"]: r["manager_employee_id"] for r in edges}
org_of = {r["employee_id"]: r["org_ref_id"] for r in edges}
name_of = {r["employee_id"]: (r["employee_name"] or r["employee_id"]) for r in names}

# include employees that exist in edge table but missing in worker table
for r in edges:
    if r["employee_id"] not in name_of:
        name_of[r["employee_id"]] = r["employee_name"] or r["employee_id"]

# 3) Chain computation with memoization + cycle detection
# result maps: emp -> (depth, path_ids, path_names, root_id)
memo = {}

def compute(emp_id):
    """
    Returns (depth, path_ids, path_names).
    depth=0 for root, -1 for cycle/unresolved.
    Path is CEO/root -> ... -> emp
    """
    if emp_id in memo:
        return memo[emp_id]

    visited = set()
    stack = []
    cur = emp_id

    # walk up until root or known node
    while True:
        if cur is None or cur == "" or cur not in mgr_of:
            # root: no manager info
            root = cur
            break

        if cur in memo:
            # attach to known chain
            root = cur
            break

        if cur in visited:
            # cycle detected
            # mark all in cycle as unresolved
            for x in stack:
                memo[x] = (-1, None, None)
            return memo[emp_id]

        visited.add(cur)
        stack.append(cur)

        m = mgr_of.get(cur)
        if m is None or m == "" or m == cur or m not in name_of:
            # root: null manager OR self-managed OR manager not present in roster
            root = cur
            break

        cur = m

    # build chain from root down to emp_id
    if root in memo and memo[root][0] != -1:
        root_depth, root_path_ids, root_path_names = memo[root]
        # root_path already ends at 'root'
        chain_ids = root_path_ids.split(" > ")
        chain_names = root_path_names.split(" > ")
    else:
        # build path from root to top (root itself)
        chain_ids = [root]
        chain_names = [name_of.get(root, root)]
        memo[root] = (0, " > ".join(chain_ids), " > ".join(chain_names))

    # now walk down from root to emp_id using manager pointers in reverse:
    # easiest: reconstruct by following managers from emp_id up to root, then reverse
    up = []
    cur = emp_id
    guard = 0
    while cur is not None and cur != "" and guard < 200:
        up.append(cur)
        if cur == root:
            break
        cur = mgr_of.get(cur)
        guard += 1

    if guard >= 200 or (up and up[-1] != root):
        memo[emp_id] = (-1, None, None)
        return memo[emp_id]

    down_ids = list(reversed(up))
    down_names = [name_of.get(x, x) for x in down_ids]
    depth = len(down_ids) - 1

    memo[emp_id] = (depth, " > ".join(down_ids), " > ".join(down_names))
    return memo[emp_id]

rows = []
for emp_id in name_of.keys():
    depth, path_ids, path_names = compute(emp_id)
    mgr = mgr_of.get(emp_id)
    rows.append((emp_id,
                 name_of.get(emp_id),
                 mgr,
                 name_of.get(mgr) if mgr else None,
                 org_of.get(emp_id),
                 depth,
                 path_ids,
                 path_names))

schema = "employee_id string, employee_name string, manager_employee_id string, manager_name string, org_ref_id string, depth int, path_employee_ids string, path_names string"
out_df = spark.createDataFrame(rows, schema=schema).withColumn("asof_ts_utc", F.current_timestamp())

out_df.write.format("delta").mode("overwrite").saveAsTable(T_OUT)

display(out_df.orderBy(F.col("depth").desc_nulls_last()).limit(50))


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

# ============================================================
# Workday HR: Workers + Supervisory Orgs + Hierarchy -> Bronze Delta
# Tables:
#  1) wd_worker_bronze
#  2) wd_sup_org_bronze
#  3) wd_worker_sup_org_bronze   (bridge)
#  4) wd_worker_manager_edge_bronze (edges derived from org manager)
#
# Notes:
# - Get_Workers uses validated flags:
#   Include_Reference, Include_Personal_Information, Include_Employment_Information, Include_Organizations
# - Get_Organizations uses empty Response_Group (your tenant validates only that),
#   BUT response still includes Organization_Data and Manager_Reference.
# - We fetch ALL org pages first (small, 144 total), then ALL workers (9593 total).
# - We filter worker org_refs to only those org_ref_ids that exist in supervisory orgs.
# ============================================================

import os, time, uuid, requests, jwt
from pathlib import Path
import xml.etree.ElementTree as ET
from datetime import datetime, timezone

from pyspark.sql.types import (
    StructType, StructField, StringType, TimestampType, IntegerType
)

# -------------------------
# 0) Config
# -------------------------
HOST = os.getenv("WORKDAY_HOST", "https://services1.wd503.myworkday.com").rstrip("/")
TENANT = os.getenv("WORKDAY_TENANT", "stevenstransport")

from notebookutils import mssparkutils

# --- Read secrets from Azure Key Vault ---
CLIENT_ID = mssparkutils.credentials.getSecret(
    "https://keyvault-fabric2.vault.azure.net/",
    "WORKDAYCLIENTID"
)
ISU_SUBJECT = os.getenv("WORKDAY_ISU_SUBJECT", "ISU_Ms_Fabric")
HR_VERSION = os.getenv("WORKDAY_HR_VERSION", "v45.0")

TOKEN_URL = f"{HOST}/ccx/oauth2/{TENANT}/token"
HR_URL    = f"{HOST}/ccx/service/{TENANT}/Human_Resources/{HR_VERSION}"

HTTP_TIMEOUT = 240
TOKEN_TTL_SECONDS = 300
TOKEN_REFRESH_SKEW_SECONDS = 45

DEFAULT_KEY_PATHS = [
    "/lakehouse/data_central_lh/Files/workday_integration.key",
    "/lakehouse/default/Files/workday_integration.key"
]

NS = {"wd": "urn:com.workday/bsvc", "env": "http://schemas.xmlsoap.org/soap/envelope/"}

def info(m): print(f"[INFO] {m}", flush=True)
def warn(m): print(f"[WARN] {m}", flush=True)

DB = spark.catalog.currentDatabase()

T_WORKER = f"{DB}.wd_worker_bronze"
T_ORG    = f"{DB}.wd_sup_org_bronze"
T_BRIDGE = f"{DB}.wd_worker_sup_org_bronze"
T_EDGE   = f"{DB}.wd_worker_manager_edge_bronze"

# -------------------------
# 1) Auth (JWT -> OAuth2 token)
# -------------------------
def read_private_key() -> str:
    for p in DEFAULT_KEY_PATHS:
        if Path(p).is_file():
            return Path(p).read_text(encoding="utf-8")
    raise FileNotFoundError(f"Private key not found. Checked: {DEFAULT_KEY_PATHS}")

SESSION = requests.Session()

class TokenManager:
    def __init__(self):
        self.token = None
        self.acquired_at = 0

    def _fetch_token(self) -> str:
        now = int(time.time())
        private_key = read_private_key()
        claims = {
            "iss": CLIENT_ID,
            "sub": ISU_SUBJECT,
            "aud": TOKEN_URL,
            "iat": now,
            "exp": now + TOKEN_TTL_SECONDS,
            "jti": str(uuid.uuid4())
        }
        assertion = jwt.encode(claims, private_key, algorithm="RS256")
        if isinstance(assertion, bytes):
            assertion = assertion.decode("utf-8")

        data = {"grant_type": "urn:ietf:params:oauth:grant-type:jwt-bearer", "assertion": assertion}
        r = SESSION.post(TOKEN_URL, data=data, timeout=HTTP_TIMEOUT)
        r.raise_for_status()
        j = r.json()
        if "access_token" not in j:
            raise RuntimeError(f"Token response missing access_token: {str(j)[:1200]}")
        return j["access_token"]

    def get(self) -> str:
        now = int(time.time())
        if self.token is None or (now - self.acquired_at) >= (TOKEN_TTL_SECONDS - TOKEN_REFRESH_SKEW_SECONDS):
            info("Getting token…")
            self.token = self._fetch_token()
            self.acquired_at = now
            info("Token OK")
        return self.token

TOKEN_MGR = TokenManager()

def soap_post(url: str, soap_xml: str) -> str:
    token = TOKEN_MGR.get()
    headers = {"Content-Type": "text/xml; charset=utf-8", "Authorization": f"Bearer {token}", "SOAPAction": ""}
    r = SESSION.post(url, data=soap_xml.encode("utf-8"), headers=headers, timeout=HTTP_TIMEOUT)

    if r.status_code in (401, 403):
        warn(f"HTTP {r.status_code} (auth). Refreshing token and retrying once…")
        TOKEN_MGR.token = None
        token = TOKEN_MGR.get()
        headers["Authorization"] = f"Bearer {token}"
        r = SESSION.post(url, data=soap_xml.encode("utf-8"), headers=headers, timeout=HTTP_TIMEOUT)

    if r.status_code >= 400:
        warn(f"SOAP HTTP {r.status_code} from {url}")
        warn("SOAP fault/body excerpt (first 4000 chars):")
        print(r.text[:4000])
        raise RuntimeError(f"SOAP HTTP {r.status_code}")
    return r.text

# -------------------------
# 2) SOAP builders (validated for your tenant)
# -------------------------
WORKER_FLAGS = [
    "Include_Reference",
    "Include_Personal_Information",
    "Include_Employment_Information",
    "Include_Organizations",
]

def build_get_workers(page:int, count:int) -> str:
    rg = "\n".join([f"<wd:{f}>true</wd:{f}>" for f in WORKER_FLAGS])
    return f"""<?xml version="1.0" encoding="UTF-8"?>
<env:Envelope xmlns:env="http://schemas.xmlsoap.org/soap/envelope/" xmlns:wd="urn:com.workday/bsvc">
  <env:Body>
    <wd:Get_Workers_Request wd:version="{HR_VERSION}">
      <wd:Response_Filter><wd:Page>{page}</wd:Page><wd:Count>{count}</wd:Count></wd:Response_Filter>
      <wd:Response_Group>{rg}</wd:Response_Group>
    </wd:Get_Workers_Request>
  </env:Body>
</env:Envelope>
"""

# Response_Group must be empty for your tenant; still returns Organization_Data + Manager_Reference
def build_get_orgs(page:int, count:int) -> str:
    return f"""<?xml version="1.0" encoding="UTF-8"?>
<env:Envelope xmlns:env="http://schemas.xmlsoap.org/soap/envelope/" xmlns:wd="urn:com.workday/bsvc">
  <env:Body>
    <wd:Get_Organizations_Request wd:version="{HR_VERSION}">
      <wd:Request_Criteria>
        <wd:Organization_Type_Reference>
          <wd:ID wd:type="Organization_Type_ID">SUPERVISORY</wd:ID>
        </wd:Organization_Type_Reference>
      </wd:Request_Criteria>
      <wd:Response_Filter><wd:Page>{page}</wd:Page><wd:Count>{count}</wd:Count></wd:Response_Filter>
      <wd:Response_Group/>
    </wd:Get_Organizations_Request>
  </env:Body>
</env:Envelope>
"""

# -------------------------
# 3) XML helpers
# -------------------------
def t(node):
    if node is None: return None
    txt = node.text
    return txt.strip() if txt else None

def id_by_type(parent, wd_type: str):
    if parent is None: return None
    for n in parent.findall("wd:ID", NS):
        if n.get(f"{{{NS['wd']}}}type") == wd_type:
            return t(n)
    return None

def get_response_results(root):
    def tx(xp):
        n = root.find(xp, NS)
        return (n.text.strip() if n is not None and n.text else None)
    return {
        "Total_Results": tx(".//wd:Response_Results/wd:Total_Results"),
        "Total_Pages":   tx(".//wd:Response_Results/wd:Total_Pages"),
        "Page_Results":  tx(".//wd:Response_Results/wd:Page_Results"),
        "Page":          tx(".//wd:Response_Results/wd:Page"),
    }

def safe_find_text(elem, xpaths):
    for xp in xpaths:
        n = elem.find(xp, NS)
        v = t(n)
        if v:
            return v
    return None

# -------------------------
# 4) Extractors
# -------------------------
def extract_worker_rows(worker_elem, run_id, extract_ts_utc):
    wref = worker_elem.find("wd:Worker_Reference", NS)
    worker_wid = id_by_type(wref, "WID")
    employee_id = id_by_type(wref, "Employee_ID") or id_by_type(wref, "Contingent_Worker_ID")
    descriptor = t(worker_elem.find("wd:Worker_Descriptor", NS))

    wd = worker_elem.find("wd:Worker_Data", NS)
    worker_id = t(wd.find("wd:Worker_ID", NS)) if wd is not None else None
    user_id = t(wd.find("wd:User_ID", NS)) if wd is not None else None

    first_name = safe_find_text(wd, [
        ".//wd:Personal_Data/wd:Name_Data/wd:Preferred_Name_Data/wd:Name_Detail_Data/wd:First_Name",
        ".//wd:Personal_Data/wd:Name_Data/wd:Legal_Name_Data/wd:Name_Detail_Data/wd:First_Name",
    ]) if wd is not None else None

    middle_name = safe_find_text(wd, [
        ".//wd:Personal_Data/wd:Name_Data/wd:Preferred_Name_Data/wd:Name_Detail_Data/wd:Middle_Name",
        ".//wd:Personal_Data/wd:Name_Data/wd:Legal_Name_Data/wd:Name_Detail_Data/wd:Middle_Name",
    ]) if wd is not None else None

    last_name = safe_find_text(wd, [
        ".//wd:Personal_Data/wd:Name_Data/wd:Preferred_Name_Data/wd:Name_Detail_Data/wd:Last_Name",
        ".//wd:Personal_Data/wd:Name_Data/wd:Legal_Name_Data/wd:Name_Detail_Data/wd:Last_Name",
    ]) if wd is not None else None

    email = None
    if user_id and "@" in user_id:
        email = user_id

    worker_row = {
        "run_id": run_id,
        "extract_ts_utc": extract_ts_utc,
        "worker_wid": worker_wid,
        "employee_id": employee_id,
        "worker_id": worker_id,
        "user_id": user_id,
        "email": email,
        "worker_descriptor": descriptor,
        "first_name": first_name,
        "middle_name": middle_name,
        "last_name": last_name
    }

    # Collect org refs broadly; we will filter to supervisory orgs later.
    org_refs = []
    if wd is not None:
        for org_ref in wd.findall(".//wd:Organization_Reference", NS):
            owid = id_by_type(org_ref, "WID")
            orefid = id_by_type(org_ref, "Organization_Reference_ID")
            if owid or orefid:
                org_refs.append((owid, orefid))

        for sup_ref in wd.findall(".//wd:Supervisory_Organization_Reference", NS):
            owid = id_by_type(sup_ref, "WID")
            orefid = id_by_type(sup_ref, "Organization_Reference_ID") or id_by_type(sup_ref, "Supervisory_Organization_ID")
            if owid or orefid:
                org_refs.append((owid, orefid))

    # de-dup
    seen = set()
    org_refs = [(a,b) for (a,b) in org_refs if not ((a,b) in seen or seen.add((a,b)))]

    # bridge rows (unfiltered for now)
    bridge_rows = []
    for (owid, orefid) in org_refs:
        bridge_rows.append({
            "run_id": run_id,
            "extract_ts_utc": extract_ts_utc,
            "worker_wid": worker_wid,
            "employee_id": employee_id,
            "org_wid": owid,
            "org_ref_id": orefid
        })

    return worker_row, bridge_rows

def extract_org_row(org_elem, run_id, extract_ts_utc):
    oref = org_elem.find("wd:Organization_Reference", NS)
    org_wid = id_by_type(oref, "WID")
    org_ref_id = id_by_type(oref, "Organization_Reference_ID")

    od = org_elem.find("wd:Organization_Data", NS)
    org_name = t(od.find("wd:Name", NS)) if od is not None else None
    org_code = t(od.find("wd:Organization_Code", NS)) if od is not None else None

    org_type_id = t(od.find(".//wd:Organization_Type_Reference/wd:ID[@wd:type='Organization_Type_ID']", NS)) if od is not None else None
    org_subtype_id = t(od.find(".//wd:Organization_Subtype_Reference/wd:ID[@wd:type='Organization_Subtype_ID']", NS)) if od is not None else None

    inactive = t(od.find("wd:Inactive", NS)) if od is not None else None
    last_updated = t(od.find("wd:Last_Updated_DateTime", NS)) if od is not None else None

    mgr_ref = od.find("wd:Manager_Reference", NS) if od is not None else None
    manager_wid = id_by_type(mgr_ref, "WID") if mgr_ref is not None else None
    manager_employee_id = id_by_type(mgr_ref, "Employee_ID") if mgr_ref is not None else None

    return {
        "run_id": run_id,
        "extract_ts_utc": extract_ts_utc,
        "org_wid": org_wid,
        "org_ref_id": org_ref_id,
        "org_code": org_code,
        "org_name": org_name,
        "org_type_id": org_type_id,
        "org_subtype_id": org_subtype_id,
        "inactive": inactive,
        "last_updated_datetime": last_updated,
        "manager_wid": manager_wid,
        "manager_employee_id": manager_employee_id
    }

# -------------------------
# 5) Schemas
# -------------------------
WORKER_SCHEMA = StructType([
    StructField("run_id", StringType(), True),
    StructField("extract_ts_utc", TimestampType(), True),
    StructField("worker_wid", StringType(), True),
    StructField("employee_id", StringType(), True),
    StructField("worker_id", StringType(), True),
    StructField("user_id", StringType(), True),
    StructField("email", StringType(), True),
    StructField("worker_descriptor", StringType(), True),
    StructField("first_name", StringType(), True),
    StructField("middle_name", StringType(), True),
    StructField("last_name", StringType(), True),
])

ORG_SCHEMA = StructType([
    StructField("run_id", StringType(), True),
    StructField("extract_ts_utc", TimestampType(), True),
    StructField("org_wid", StringType(), True),
    StructField("org_ref_id", StringType(), True),
    StructField("org_code", StringType(), True),
    StructField("org_name", StringType(), True),
    StructField("org_type_id", StringType(), True),
    StructField("org_subtype_id", StringType(), True),
    StructField("inactive", StringType(), True),
    StructField("last_updated_datetime", StringType(), True),
    StructField("manager_wid", StringType(), True),
    StructField("manager_employee_id", StringType(), True),
])

BRIDGE_SCHEMA = StructType([
    StructField("run_id", StringType(), True),
    StructField("extract_ts_utc", TimestampType(), True),
    StructField("worker_wid", StringType(), True),
    StructField("employee_id", StringType(), True),
    StructField("org_wid", StringType(), True),
    StructField("org_ref_id", StringType(), True),
])

EDGE_SCHEMA = StructType([
    StructField("run_id", StringType(), True),
    StructField("extract_ts_utc", TimestampType(), True),
    StructField("employee_id", StringType(), True),
    StructField("worker_wid", StringType(), True),
    StructField("org_ref_id", StringType(), True),
    StructField("org_wid", StringType(), True),
    StructField("manager_employee_id", StringType(), True),
    StructField("manager_wid", StringType(), True),
])

# -------------------------
# 6) Create tables (overwrite) - bronze full reload
# -------------------------
def recreate_tables():
    info(f"Lakehouse DB: {DB}")
    for tname, schema in [
        (T_WORKER, WORKER_SCHEMA),
        (T_ORG, ORG_SCHEMA),
        (T_BRIDGE, BRIDGE_SCHEMA),
        (T_EDGE, EDGE_SCHEMA),
    ]:
        spark.sql(f"DROP TABLE IF EXISTS {tname}")
        spark.createDataFrame([], schema).write.format("delta").mode("overwrite").saveAsTable(tname)
        info(f"✅ Created {tname}")

# -------------------------
# 7) Paging helpers
# -------------------------
class PageSizeManager:
    def __init__(self, sizes):
        self.sizes = sizes[:]
        self.idx = 0
        self.fail_streak = 0

    def size(self):
        return self.sizes[self.idx]

    def record_failure(self):
        self.fail_streak += 1
        if self.idx < len(self.sizes) - 1:
            self.idx += 1
            return self.sizes[self.idx]
        return None

    def record_success(self):
        self.fail_streak = 0

# -------------------------
# 8) Load ALL Supervisory Orgs (small)
# -------------------------
def load_all_orgs(run_id, extract_ts_utc, page_size=100):
    psm = PageSizeManager([page_size, 50, 25, 10])
    page = 1
    total_org = 0
    org_rows_all = []

    total_pages_reported = None

    while True:
        soap = build_get_orgs(page=page, count=psm.size())
        try:
            xml_text = soap_post(HR_URL, soap)
        except Exception as e:
            warn(f"Get_Organizations page {page} failed at size={psm.size()}: {e}")
            nxt = psm.record_failure()
            if nxt is None: raise
            warn(f"Retrying page {page} with smaller page_size={nxt}")
            continue

        root = ET.fromstring(xml_text)
        rr = get_response_results(root)

        if rr.get("Total_Pages"):
            try: total_pages_reported = int(rr["Total_Pages"])
            except: pass

        orgs = root.findall(".//wd:Response_Data/wd:Organization", NS)
        if not orgs:
            break

        batch = [extract_org_row(o, run_id, extract_ts_utc) for o in orgs]
        org_rows_all.extend(batch)
        total_org += len(batch)

        if page % 2 == 0:
            info(f"[Orgs] page {page}" + (f"/{total_pages_reported}" if total_pages_reported else "") + f" | batch={len(batch)} total={total_org}")

        if total_pages_reported is not None and page >= total_pages_reported:
            break

        page += 1
        psm.record_success()
        time.sleep(0.10)

    info(f"✅ Orgs fetched: {len(org_rows_all)}")
    return org_rows_all

# -------------------------
# 9) Load ALL Workers + bridge + edges
# -------------------------
def load_all_workers_and_write(run_id, extract_ts_utc, org_lookup_by_refid, org_lookup_by_wid):
    psm = PageSizeManager([100, 50, 25, 10])
    page = 1

    total_pages_reported = None
    total_workers = 0
    total_bridge = 0
    total_edges = 0

    def write_batch(worker_rows, bridge_rows, edge_rows):
        if worker_rows:
            spark.createDataFrame(worker_rows, WORKER_SCHEMA).write.format("delta").mode("append").saveAsTable(T_WORKER)
        if bridge_rows:
            spark.createDataFrame(bridge_rows, BRIDGE_SCHEMA).write.format("delta").mode("append").saveAsTable(T_BRIDGE)
        if edge_rows:
            spark.createDataFrame(edge_rows, EDGE_SCHEMA).write.format("delta").mode("append").saveAsTable(T_EDGE)

    while True:
        soap = build_get_workers(page=page, count=psm.size())
        try:
            xml_text = soap_post(HR_URL, soap)
        except Exception as e:
            warn(f"Get_Workers page {page} failed at size={psm.size()}: {e}")
            nxt = psm.record_failure()
            if nxt is None: raise
            warn(f"Retrying page {page} with smaller page_size={nxt}")
            continue

        root = ET.fromstring(xml_text)
        rr = get_response_results(root)

        if rr.get("Total_Pages"):
            try: total_pages_reported = int(rr["Total_Pages"])
            except: pass

        workers = root.findall(".//wd:Response_Data/wd:Worker", NS)
        if not workers:
            break

        # Build rows
        worker_rows = []
        bridge_rows = []
        edge_rows = []

        for w in workers:
            wrow, btemp = extract_worker_rows(w, run_id, extract_ts_utc)
            worker_rows.append(wrow)

            # Filter bridge rows to only Supervisory orgs (by org_ref_id or org_wid)
            for b in btemp:
                o = None
                if b.get("org_wid"):
                    o = org_lookup_by_wid.get(b["org_wid"])
                if o is None and b.get("org_ref_id"):
                    o = org_lookup_by_refid.get(b["org_ref_id"])

                if o is None:
                    continue  # not a supervisory org (location, cost center, etc.)

                # Keep filtered bridge
                bridge_rows.append(b)

                # Create worker->manager edge using org manager
                edge_rows.append({
                    "run_id": run_id,
                    "extract_ts_utc": extract_ts_utc,
                    "employee_id": b["employee_id"],
                    "worker_wid": b["worker_wid"],
                    "org_ref_id": o.get("org_ref_id"),
                    "org_wid": o.get("org_wid"),
                    "manager_employee_id": o.get("manager_employee_id"),
                    "manager_wid": o.get("manager_wid"),
                })

        # ---- Probe prints (per batch) before write
        if page == 1:
            info(f"[Workers] First batch sample employee_ids: {[r['employee_id'] for r in worker_rows[:5]]}")
            info(f"[Bridge] First batch filtered bridge rows: {len(bridge_rows)}")
            info(f"[Edges] First batch edges rows: {len(edge_rows)}")

        write_batch(worker_rows, bridge_rows, edge_rows)

        total_workers += len(worker_rows)
        total_bridge += len(bridge_rows)
        total_edges += len(edge_rows)

        if page % 10 == 0:
            info(f"[Workers] page {page}" + (f"/{total_pages_reported}" if total_pages_reported else "") +
                 f" | workers={total_workers} bridge={total_bridge} edges={total_edges} | page_size={psm.size()}")

        if total_pages_reported is not None and page >= total_pages_reported:
            break

        page += 1
        psm.record_success()
        time.sleep(0.12)

    info("✅ Workers load complete.")
    info(f"Totals: workers={total_workers} bridge={total_bridge} edges={total_edges}")

# -------------------------
# 10) RUN
# -------------------------
info(f"HR_URL: {HR_URL}")

run_id = str(uuid.uuid4())
extract_ts_utc = datetime.now(timezone.utc).replace(tzinfo=None)
info(f"run_id={run_id} extract_ts_utc={extract_ts_utc}")

# (A) Recreate tables
recreate_tables()

# (B) Load orgs -> write org table -> build lookups
org_rows = load_all_orgs(run_id, extract_ts_utc, page_size=100)
info(f"[Orgs] Writing {len(org_rows)} rows to {T_ORG}")
spark.createDataFrame(org_rows, ORG_SCHEMA).write.format("delta").mode("append").saveAsTable(T_ORG)

org_by_refid = {o["org_ref_id"]: o for o in org_rows if o.get("org_ref_id")}
org_by_wid   = {o["org_wid"]: o for o in org_rows if o.get("org_wid")}
info(f"[Orgs] Lookup sizes: by_refid={len(org_by_refid)} by_wid={len(org_by_wid)}")

# (C) Load workers + filtered bridge + edges (append)
load_all_workers_and_write(run_id, extract_ts_utc, org_by_refid, org_by_wid)

info("✅ HR bronze build finished.")
info(f"Tables:\n - {T_WORKER}\n - {T_ORG}\n - {T_BRIDGE}\n - {T_EDGE}")


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

# ============================================================
# Workday FM Get_Journals (NO DATE FILTERS) -> Bronze Delta tables
# DROP old tables, CREATE new tables, LOAD ALL journals (paged)
# Adds: token refresh, retries/backoff, adaptive page sizing, defensive stop
# ============================================================

import os, time, uuid, requests, jwt
from pathlib import Path
from datetime import datetime, timedelta, timezone
import xml.etree.ElementTree as ET

from pyspark.sql.types import (
    StructType, StructField, StringType, TimestampType, DateType, IntegerType, DoubleType
)

# -------------------------
# 0) Config
# -------------------------
HOST = os.getenv("WORKDAY_HOST", "https://services1.wd503.myworkday.com").rstrip("/")
TENANT = os.getenv("WORKDAY_TENANT", "stevenstransport")
from notebookutils import mssparkutils

# --- Read secrets from Azure Key Vault ---
CLIENT_ID = mssparkutils.credentials.getSecret(
    "https://keyvault-fabric2.vault.azure.net/",
    "WORKDAYCLIENTID"
)
ISU_SUBJECT = os.getenv("WORKDAY_ISU_SUBJECT", "ISU_Ms_Fabric")
FM_VERSION = os.getenv("WORKDAY_FM_VERSION", "v45.0")

TOKEN_URL = f"{HOST}/ccx/oauth2/{TENANT}/token"
SOAP_URL  = f"{HOST}/ccx/service/{TENANT}/Financial_Management/{FM_VERSION}"

HTTP_TIMEOUT = 240  # seconds per HTTP call

TOKEN_TTL_SECONDS = 300
TOKEN_REFRESH_SKEW_SECONDS = 45

DEFAULT_KEY_PATHS = [
    "/lakehouse/data_central_lh/Files/workday_integration.key",
    "/lakehouse/default/Files/workday_integration.key"
]

DB = spark.catalog.currentDatabase()

OLD_T_HDR  = f"{DB}.brz_wd_fm_journal_header"
OLD_T_LINE = f"{DB}.brz_wd_fm_journal_line"
OLD_T_KV   = f"{DB}.brz_wd_fm_journal_line_worktag_kv"

T_HDR  = f"{DB}.wd_journal_header_bronze"
T_LINE = f"{DB}.wd_journal_line_bronze"
T_KV   = f"{DB}.wd_journal_line_worktag_kv_bronze"

NS = {"wd": "urn:com.workday/bsvc", "env": "http://schemas.xmlsoap.org/soap/envelope/"}

def info(m): print(f"[INFO] {m}", flush=True)
def warn(m): print(f"[WARN] {m}", flush=True)

# -------------------------
# 0.1) Spark keep-alive-ish settings (best-effort)
# -------------------------
try:
    spark.conf.set("spark.sql.broadcastTimeout", "36000")
except Exception as e:
    warn(f"Spark conf set skipped: {e}")

# -------------------------
# 1) Auth (JWT -> OAuth2 token)
# -------------------------
def read_private_key() -> str:
    for p in DEFAULT_KEY_PATHS:
        if Path(p).is_file():
            return Path(p).read_text(encoding="utf-8")
    raise FileNotFoundError(f"Private key not found. Checked: {DEFAULT_KEY_PATHS}")

from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry

SESSION = requests.Session()
retry = Retry(
    total=6,
    backoff_factor=1.2,
    status_forcelist=[429, 500, 502, 503, 504],
    allowed_methods=["POST"]
)
SESSION.mount("https://", HTTPAdapter(max_retries=retry))
SESSION.mount("http://", HTTPAdapter(max_retries=retry))

class TokenManager:
    def __init__(self):
        self.token = None
        self.acquired_at = 0

    def _fetch_token(self) -> str:
        now = int(time.time())
        private_key = read_private_key()
        claims = {
            "iss": CLIENT_ID,
            "sub": ISU_SUBJECT,
            "aud": TOKEN_URL,
            "iat": now,
            "exp": now + TOKEN_TTL_SECONDS,
            "jti": str(uuid.uuid4())
        }
        assertion = jwt.encode(claims, private_key, algorithm="RS256")
        if isinstance(assertion, bytes):
            assertion = assertion.decode("utf-8")

        data = {
            "grant_type": "urn:ietf:params:oauth:grant-type:jwt-bearer",
            "assertion": assertion
        }
        r = SESSION.post(TOKEN_URL, data=data, timeout=HTTP_TIMEOUT)
        r.raise_for_status()
        return r.json()["access_token"]

    def get(self) -> str:
        now = int(time.time())
        needs_refresh = (
            self.token is None or
            (now - self.acquired_at) >= (TOKEN_TTL_SECONDS - TOKEN_REFRESH_SKEW_SECONDS)
        )
        if needs_refresh:
            info("Getting token…")
            self.token = self._fetch_token()
            self.acquired_at = now
            info("Token OK")
        return self.token

TOKEN_MGR = TokenManager()

# -------------------------
# 2) SOAP builders (NO FILTERS)
# -------------------------
def build_get_journals_request_no_filters(page: int, count: int) -> str:
    # NOTE: no Request_Criteria at all
    return f"""<?xml version="1.0" encoding="UTF-8"?>
<env:Envelope xmlns:env="http://schemas.xmlsoap.org/soap/envelope/" xmlns:wd="urn:com.workday/bsvc">
  <env:Body>
    <wd:Get_Journals_Request wd:version="{FM_VERSION}">
      <wd:Response_Filter>
        <wd:Page>{page}</wd:Page>
        <wd:Count>{count}</wd:Count>
      </wd:Response_Filter>
    </wd:Get_Journals_Request>
  </env:Body>
</env:Envelope>
"""

def call_get_journals(soap_xml: str) -> str:
    token = TOKEN_MGR.get()
    headers = {
        "Content-Type": "text/xml; charset=utf-8",
        "Authorization": f"Bearer {token}",
    }

    r = SESSION.post(SOAP_URL, data=soap_xml.encode("utf-8"), headers=headers, timeout=HTTP_TIMEOUT)

    if r.status_code in (401, 403):
        warn(f"HTTP {r.status_code} (auth). Refreshing token and retrying once…")
        TOKEN_MGR.token = None
        token = TOKEN_MGR.get()
        headers["Authorization"] = f"Bearer {token}"
        r = SESSION.post(SOAP_URL, data=soap_xml.encode("utf-8"), headers=headers, timeout=HTTP_TIMEOUT)

    if r.status_code >= 400:
        raise RuntimeError(f"HTTP {r.status_code}\n{r.text[:4000]}")
    return r.text

# -------------------------
# 3) XML helpers
# -------------------------
def t(node):
    if node is None: return None
    txt = node.text
    return txt.strip() if txt else None

def id_by_type(parent, wd_type: str):
    if parent is None: return None
    for n in parent.findall("wd:ID", NS):
        if n.get(f"{{{NS['wd']}}}type") == wd_type:
            return t(n)
    return None

def parse_float(x):
    if x is None or x == "": return None
    try: return float(x)
    except: return None

def parse_date_obj(x):
    if not x: return None
    try:
        return datetime.strptime(x[:10], "%Y-%m-%d").date()
    except:
        return None

# -------------------------
# 4) Parse response -> rows
# -------------------------
def parse_get_journals_response(xml_text: str, run_id: str, extract_ts_utc: datetime):
    root = ET.fromstring(xml_text)

    totals = {
        "Total_Results": t(root.find(".//wd:Response_Results/wd:Total_Results", NS)),
        "Total_Pages":   t(root.find(".//wd:Response_Results/wd:Total_Pages", NS)),
        "Page_Results":  t(root.find(".//wd:Response_Results/wd:Page_Results", NS)),
        "Page":          t(root.find(".//wd:Response_Results/wd:Page", NS)),
    }

    hdr_rows, line_rows, kv_rows = [], [], []

    jes = root.findall(".//wd:Response_Data/wd:Journal_Entry", NS)
    for je in jes:
        je_ref = je.find("wd:Journal_Entry_Reference", NS)

        journal_wid = id_by_type(je_ref, "WID")
        accounting_journal_id = id_by_type(je_ref, "Accounting_Journal_ID")

        journal_number = t(je.find(".//wd:Journal_Number", NS))
        journal_status_id = t(je.find(".//wd:Journal_Status_Reference/wd:ID[@wd:type='Journal_Entry_Status_ID']", NS))

        company_ref_id = t(je.find(".//wd:Company_Reference/wd:ID[@wd:type='Company_Reference_ID']", NS)) \
                         or t(je.find(".//wd:Company_Reference/wd:ID[@wd:type='Organization_Reference_ID']", NS))
        currency_id = t(je.find(".//wd:Currency_Reference/wd:ID[@wd:type='Currency_ID']", NS))
        ledger_ref_id = t(je.find(".//wd:Ledger_Reference/wd:ID[@wd:type='Ledger_Reference_ID']", NS))
        ledger_period_wid = t(je.find(".//wd:Ledger_Period_Reference/wd:ID[@wd:type='WID']", NS))

        accounting_date_str = t(je.find(".//wd:Accounting_Date", NS))
        accounting_date = parse_date_obj(accounting_date_str)

        creation_date = t(je.find(".//wd:Creation_Date", NS))
        total_ledger_debits = parse_float(t(je.find(".//wd:Total_Ledger_Debits", NS)))
        total_ledger_credits = parse_float(t(je.find(".//wd:Total_Ledger_Credits", NS)))
        journal_source_id = t(je.find(".//wd:Journal_Source_Reference/wd:ID[@wd:type='Journal_Source_ID']", NS))
        originated_by_wid = t(je.find(".//wd:Originated_By_Reference/wd:ID[@wd:type='WID']", NS))

        accounting_month = accounting_date_str[:7] if accounting_date_str and len(accounting_date_str) >= 7 else None

        hdr_rows.append({
            "run_id": run_id,
            "extract_ts_utc": extract_ts_utc,
            "journal_wid": journal_wid,
            "accounting_journal_id": accounting_journal_id,
            "journal_number": journal_number,
            "journal_status_id": journal_status_id,
            "company_reference_id": company_ref_id,
            "currency_id": currency_id,
            "ledger_reference_id": ledger_ref_id,
            "ledger_period_wid": ledger_period_wid,
            "accounting_date": accounting_date,
            "creation_date": creation_date,
            "total_ledger_debits": total_ledger_debits,
            "total_ledger_credits": total_ledger_credits,
            "journal_source_id": journal_source_id,
            "originated_by_wid": originated_by_wid,
            "accounting_month": accounting_month
        })

        lines = je.findall(".//wd:Journal_Entry_Line_Data", NS)
        if not lines:
            lines = je.findall(".//wd:Journal_Entry_Line", NS)

        line_order = 0
        for ln in lines:
            line_order += 1

            journal_line_number = t(ln.find(".//wd:Journal_Line_Number", NS)) or t(ln.find(".//wd:Line_Number", NS))
            exclude_from_spend_report = t(ln.find(".//wd:Exclude_from_Spend_Report", NS))

            line_company_id = t(ln.find(".//wd:Company_Reference/wd:ID[@wd:type='Company_Reference_ID']", NS)) \
                              or t(ln.find(".//wd:Company_Reference/wd:ID[@wd:type='Organization_Reference_ID']", NS))

            ledger_account_wid = t(ln.find(".//wd:Ledger_Account_Reference/wd:ID[@wd:type='WID']", NS))
            ledger_account_id  = t(ln.find(".//wd:Ledger_Account_Reference/wd:ID[@wd:type='Ledger_Account_ID']", NS)) \
                                 or t(ln.find(".//wd:Ledger_Account_Reference/wd:ID[@wd:type='Account_ID']", NS))

            currency_id_line = t(ln.find(".//wd:Currency_Reference/wd:ID[@wd:type='Currency_ID']", NS)) or currency_id

            debit_amount = parse_float(t(ln.find(".//wd:Debit_Amount", NS)))
            credit_amount = parse_float(t(ln.find(".//wd:Credit_Amount", NS)))
            ledger_debit_amount = parse_float(t(ln.find(".//wd:Ledger_Debit_Amount", NS)))
            ledger_credit_amount = parse_float(t(ln.find(".//wd:Ledger_Credit_Amount", NS)))

            memo_line = t(ln.find(".//wd:Memo", NS))

            amt_signed = None
            if debit_amount is not None or credit_amount is not None:
                amt_signed = (debit_amount or 0.0) - (credit_amount or 0.0)

            line_rows.append({
                "run_id": run_id,
                "extract_ts_utc": extract_ts_utc,
                "journal_wid": journal_wid,
                "line_order": line_order,
                "journal_line_number": journal_line_number,
                "exclude_from_spend_report": exclude_from_spend_report,
                "line_company_reference_id": line_company_id,
                "ledger_account_id": ledger_account_id,
                "ledger_account_wid": ledger_account_wid,
                "currency_id": currency_id_line,
                "debit_amount": debit_amount,
                "credit_amount": credit_amount,
                "ledger_debit_amount": ledger_debit_amount,
                "ledger_credit_amount": ledger_credit_amount,
                "amount_signed": amt_signed,
                "memo": memo_line,
                "accounting_date": accounting_date,
                "accounting_month": accounting_month
            })

            worktags = ln.findall(".//wd:Worktags_Reference", NS)
            if not worktags:
                worktags = ln.findall(".//wd:Worktags", NS)

            for wt in worktags:
                for idn in wt.findall(".//wd:ID", NS):
                    kv_rows.append({
                        "run_id": run_id,
                        "extract_ts_utc": extract_ts_utc,
                        "journal_wid": journal_wid,
                        "line_order": line_order,
                        "worktag_type": idn.get(f"{{{NS['wd']}}}type"),
                        "worktag_value": t(idn),
                        "accounting_date": accounting_date,
                        "accounting_month": accounting_month
                    })

    return hdr_rows, line_rows, kv_rows, totals

# -------------------------
# 5) Schemas
# -------------------------
HDR_SCHEMA = StructType([
    StructField("run_id", StringType(), True),
    StructField("extract_ts_utc", TimestampType(), True),
    StructField("journal_wid", StringType(), True),
    StructField("accounting_journal_id", StringType(), True),
    StructField("journal_number", StringType(), True),
    StructField("journal_status_id", StringType(), True),
    StructField("company_reference_id", StringType(), True),
    StructField("currency_id", StringType(), True),
    StructField("ledger_reference_id", StringType(), True),
    StructField("ledger_period_wid", StringType(), True),
    StructField("accounting_date", DateType(), True),
    StructField("creation_date", StringType(), True),
    StructField("total_ledger_debits", DoubleType(), True),
    StructField("total_ledger_credits", DoubleType(), True),
    StructField("journal_source_id", StringType(), True),
    StructField("originated_by_wid", StringType(), True),
    StructField("accounting_month", StringType(), True),
])

LINE_SCHEMA = StructType([
    StructField("run_id", StringType(), True),
    StructField("extract_ts_utc", TimestampType(), True),
    StructField("journal_wid", StringType(), True),
    StructField("line_order", IntegerType(), True),
    StructField("journal_line_number", StringType(), True),
    StructField("exclude_from_spend_report", StringType(), True),
    StructField("line_company_reference_id", StringType(), True),
    StructField("ledger_account_id", StringType(), True),
    StructField("ledger_account_wid", StringType(), True),
    StructField("currency_id", StringType(), True),
    StructField("debit_amount", DoubleType(), True),
    StructField("credit_amount", DoubleType(), True),
    StructField("ledger_debit_amount", DoubleType(), True),
    StructField("ledger_credit_amount", DoubleType(), True),
    StructField("amount_signed", DoubleType(), True),
    StructField("memo", StringType(), True),
    StructField("accounting_date", DateType(), True),
    StructField("accounting_month", StringType(), True),
])

KV_SCHEMA = StructType([
    StructField("run_id", StringType(), True),
    StructField("extract_ts_utc", TimestampType(), True),
    StructField("journal_wid", StringType(), True),
    StructField("line_order", IntegerType(), True),
    StructField("worktag_type", StringType(), True),
    StructField("worktag_value", StringType(), True),
    StructField("accounting_date", DateType(), True),
    StructField("accounting_month", StringType(), True),
])

# -------------------------
# 6) Drop old tables + create new tables
# -------------------------
def drop_old_tables_and_create_new():
    info(f"Current Spark database (Lakehouse): {DB}")

    spark.sql(f"DROP TABLE IF EXISTS {OLD_T_KV}")
    spark.sql(f"DROP TABLE IF EXISTS {OLD_T_LINE}")
    spark.sql(f"DROP TABLE IF EXISTS {OLD_T_HDR}")
    info("✅ Dropped OLD bronze tables (if existed).")

    spark.sql(f"DROP TABLE IF EXISTS {T_KV}")
    spark.sql(f"DROP TABLE IF EXISTS {T_LINE}")
    spark.sql(f"DROP TABLE IF EXISTS {T_HDR}")

    spark.createDataFrame([], HDR_SCHEMA).write.format("delta").mode("overwrite").saveAsTable(T_HDR)
    spark.createDataFrame([], LINE_SCHEMA).write.format("delta").mode("overwrite").saveAsTable(T_LINE)
    spark.createDataFrame([], KV_SCHEMA).write.format("delta").mode("overwrite").saveAsTable(T_KV)

    info("✅ New bronze tables created:")
    info(f" - {T_HDR}")
    info(f" - {T_LINE}")
    info(f" - {T_KV}")

# -------------------------
# 7) Reload ALL journals (NO FILTERS)
# -------------------------
class PageSizeManager:
    def __init__(self, sizes):
        self.sizes = sizes[:]  # e.g. [200,100,50,25,10]
        self.idx = 0
        self.success_streak = 0

    def size(self):
        return self.sizes[self.idx]

    def record_success(self):
        self.success_streak += 1
        # if stable, cautiously move back up (optional). Keep simple: don't auto-increase.
        # You can implement increase later if you want.

    def record_failure(self):
        self.success_streak = 0
        if self.idx < len(self.sizes) - 1:
            self.idx += 1
            return self.sizes[self.idx]
        return None

def reload_all_no_filters(max_pages=None, sleep_between_pages=0.1):
    run_id = str(uuid.uuid4())
    extract_ts_utc = datetime.now(timezone.utc).replace(tzinfo=None)

    psm = PageSizeManager([200, 100, 50, 25, 10])
    page = 1

    total_hdr = total_line = total_kv = 0
    total_pages_reported = None
    consecutive_empty = 0

    info(f"run_id = {run_id}")
    info("Reload mode: NO FILTERS (paging entire Get_Journals)")
    info(f"Initial page_size={psm.size()}")

    def write_batch(h, l, k):
        if h:
            spark.createDataFrame(h, HDR_SCHEMA).write.format("delta").mode("append").saveAsTable(T_HDR)
        if l:
            spark.createDataFrame(l, LINE_SCHEMA).write.format("delta").mode("append").saveAsTable(T_LINE)
        if k:
            spark.createDataFrame(k, KV_SCHEMA).write.format("delta").mode("append").saveAsTable(T_KV)

    while True:
        if max_pages is not None and page > int(max_pages):
            warn(f"max_pages hit ({max_pages}). Stopping early for test.")
            break

        page_size = psm.size()
        soap = build_get_journals_request_no_filters(page=page, count=page_size)

        try:
            xml_text = call_get_journals(soap)
        except Exception as e:
            warn(f"Page {page} failed with page_size={page_size}: {e}")
            next_size = psm.record_failure()
            if next_size is None:
                raise
            warn(f"Retrying page {page} with smaller page_size={next_size}")
            continue

        h, l, k, totals = parse_get_journals_response(xml_text, run_id, extract_ts_utc)

        # capture total pages if Workday provides it
        try:
            if totals.get("Total_Pages"):
                total_pages_reported = int(totals["Total_Pages"])
        except:
            pass

        if not h and not l:
            consecutive_empty += 1
            warn(f"Empty page {page} (consecutive_empty={consecutive_empty})")
            if consecutive_empty >= 3:
                warn("3 consecutive empty pages -> stopping defensively.")
                break
            page += 1
            continue
        else:
            consecutive_empty = 0

        write_batch(h, l, k)
        total_hdr += len(h); total_line += len(l); total_kv += len(k)

        if page % 10 == 0:
            info(f"Progress: page {page}"
                 + (f"/{total_pages_reported}" if total_pages_reported else "")
                 + f" | hdr={total_hdr} line={total_line} kv={total_kv} | page_size={page_size}")

        # if Workday told us total pages, stop when done
        if total_pages_reported is not None and page >= total_pages_reported:
            info(f"Reached reported last page {page}/{total_pages_reported}.")
            break

        page += 1
        if sleep_between_pages and sleep_between_pages > 0:
            time.sleep(sleep_between_pages)

        psm.record_success()

    info("✅ Reload complete.")
    info(f"Rows written: hdr={total_hdr}, line={total_line}, kv={total_kv}")
    info(f"run_id = {run_id}")

# -------------------------
# 8) RUN IT
# -------------------------
drop_old_tables_and_create_new()

# If Workday is cranky, start with max_pages=200 to validate mechanics.
# Then remove max_pages once stable.
reload_all_no_filters(max_pages=None, sleep_between_pages=0.15)


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }
