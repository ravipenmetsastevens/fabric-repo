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

# ============================================================
# Fabric Notebook: OneLake (Lakehouse Files) -> Azure Blob (SAS)
# - Reads jpg/png/webp from: /lakehouse/default/Files/workday_employee_photos
# - Resizes (downscales) images BEFORE upload (optional format normalize to JPEG)
# - Uploads to container: employee-photos (from your SAS URL)
# - Overwrites existing blobs
# - Retries with backoff on 429/5xx
# ============================================================

import os, time, uuid
from io import BytesIO
from urllib.parse import urlparse

# Azure SDK
from azure.storage.blob import BlobServiceClient, ContentSettings

# Pillow (image processing)
try:
    from PIL import Image, ImageOps
except Exception:
    # If Pillow isn't installed in your Fabric runtime, uncomment next 2 lines:
    # import sys, subprocess
    # subprocess.check_call([sys.executable, "-m", "pip", "install", "Pillow"])
    from PIL import Image, ImageOps  # retry after install

# -------------------------
# 0) Config (from your SAS URL)
# -------------------------



from notebookutils import mssparkutils

# --- Read secrets from Azure Key Vault ---
sas_token_key  = mssparkutils.credentials.getSecret(
    "https://keyvault-fabric2.vault.azure.net/",
    "SASTOKENKEY"
)


SAS_CONTAINER_URL = (
    "https://fabricstoragescus.blob.core.windows.net/employee-photos"
    "?{sas_token_key}"
)

SOURCE_DIR = "/lakehouse/default/Files/workday_employee_photos"  # OneLake files
ALLOWED_EXT = {".jpg", ".jpeg", ".png", ".webp"}                 # adjust if needed

# Tunables
MAX_FILES = None              # e.g. 50 for a test; None = all
MAX_RETRIES = 6
BASE_BACKOFF_SECONDS = 1.0
SLEEP_BETWEEN_FILES = 0.05    # small throttle

# -------------------------
# Resize / compression config
# -------------------------
MAX_DIM = 256                 # 96/128/256 are common; pick what you need
JPEG_QUALITY = 85             # 75-90 typical
ALWAYS_OUTPUT_JPEG = True     # True = normalize everything to JPEG (recommended)
SKIP_IF_SMALLER = True        # don't upscale tiny images

run_id = str(uuid.uuid4())

def info(m): print(f"[INFO] {m}", flush=True)
def warn(m): print(f"[WARN] {m}", flush=True)

# -------------------------
# 1) Parse SAS URL -> account_url + container + sas_token
# -------------------------
u = urlparse(SAS_CONTAINER_URL)
account_url = f"{u.scheme}://{u.netloc}"
container_name = u.path.strip("/")
sas_token = u.query  # keep querystring as-is

info(f"run_id={run_id}")
info(f"account_url={account_url}")
info(f"container={container_name}")
info(f"SOURCE_DIR={SOURCE_DIR}")

# -------------------------
# 2) Blob clients
# -------------------------
service = BlobServiceClient(account_url=account_url, credential=sas_token)
container_client = service.get_container_client(container_name)

# -------------------------
# 3) File discovery helpers (works in Fabric notebooks)
# -------------------------
def list_source_files(source_dir: str):
    """
    List files under OneLake Lakehouse Files.
    Uses dbutils.fs if available; falls back to os.walk.
    Returns: list of dicts {path, name, size}
    """
    files = []
    try:
        ls = dbutils.fs.ls(source_dir)  # noqa: F821
        for x in ls:
            files.append({"path": x.path, "name": x.name, "size": getattr(x, "size", None)})
        return files
    except Exception:
        pass

    for root, _, fnames in os.walk(source_dir):
        for fn in fnames:
            full = os.path.join(root, fn)
            try:
                size = os.path.getsize(full)
            except Exception:
                size = None
            files.append({"path": full, "name": fn, "size": size})
    return files

def normalize_local_path(p: str) -> str:
    """
    Convert paths like 'file:/lakehouse/..' to '/lakehouse/..' if needed.
    """
    if p.startswith("file:"):
        p2 = p.replace("file://", "")
        if p2.startswith("/"):
            return p2
        if p2.startswith("lakehouse/"):
            return "/" + p2
        return p2
    return p

def guess_content_type_from_ext(ext: str) -> str:
    ext = ext.lower()
    if ext in (".jpg", ".jpeg"): return "image/jpeg"
    if ext == ".png": return "image/png"
    if ext == ".webp": return "image/webp"
    return "application/octet-stream"

def build_blob_name(original_name: str, out_ext: str) -> str:
    base, _ = os.path.splitext(original_name)
    return base + out_ext

# -------------------------
# 4) Resize helper
# -------------------------
def resize_image_bytes(input_bytes: bytes, original_ext: str):
    """
    Returns: (out_bytes, out_ext, out_content_type, meta)
    - Downscales to MAX_DIM (preserving aspect ratio) and fixes EXIF orientation
    - Optionally converts everything to JPEG for consistent/smaller output
    - If PIL fails to read, passes through original bytes
    """
    meta = {
        "orig_bytes": len(input_bytes),
        "orig_ext": original_ext.lower(),
        "orig_w": None, "orig_h": None,
        "out_w": None, "out_h": None,
        "out_bytes": None,
        "changed": False,
        "reason": None,
    }

    try:
        img = Image.open(BytesIO(input_bytes))
        img = ImageOps.exif_transpose(img)  # fix rotations
        meta["orig_w"], meta["orig_h"] = img.size

        # Decide if we will output JPEG
        if ALWAYS_OUTPUT_JPEG:
            if img.mode != "RGB":
                img = img.convert("RGB")

        w, h = img.size
        needs_downscale = max(w, h) > MAX_DIM

        if SKIP_IF_SMALLER and not needs_downscale:
            # No resize; optionally normalize format if ALWAYS_OUTPUT_JPEG
            if ALWAYS_OUTPUT_JPEG:
                out = BytesIO()
                img.save(out, format="JPEG", quality=JPEG_QUALITY, optimize=True, progressive=True)
                out_bytes = out.getvalue()
                meta["changed"] = True
                meta["reason"] = "format_normalized_to_jpeg"
                meta["out_w"], meta["out_h"] = img.size
                meta["out_bytes"] = len(out_bytes)
                return out_bytes, ".jpg", "image/jpeg", meta

            meta["changed"] = False
            meta["reason"] = "no_resize_needed"
            meta["out_w"], meta["out_h"] = img.size
            meta["out_bytes"] = len(input_bytes)
            return input_bytes, original_ext.lower(), guess_content_type_from_ext(original_ext), meta

        # Downscale
        img.thumbnail((MAX_DIM, MAX_DIM))
        meta["out_w"], meta["out_h"] = img.size

        out = BytesIO()
        if ALWAYS_OUTPUT_JPEG:
            img.save(out, format="JPEG", quality=JPEG_QUALITY, optimize=True, progressive=True)
            out_bytes = out.getvalue()
            meta["changed"] = True
            meta["reason"] = "resized_to_jpeg"
            meta["out_bytes"] = len(out_bytes)
            return out_bytes, ".jpg", "image/jpeg", meta
        else:
            # keep original type if you really want
            fmt = "PNG" if original_ext.lower() == ".png" else "JPEG"
            if fmt == "JPEG" and img.mode != "RGB":
                img = img.convert("RGB")
            if fmt == "PNG":
                img.save(out, format="PNG", optimize=True)
                out_ext = ".png"
                out_ct = "image/png"
            else:
                img.save(out, format="JPEG", quality=JPEG_QUALITY, optimize=True, progressive=True)
                out_ext = ".jpg"
                out_ct = "image/jpeg"

            out_bytes = out.getvalue()
            meta["changed"] = True
            meta["reason"] = "resized_keepish_format"
            meta["out_bytes"] = len(out_bytes)
            return out_bytes, out_ext, out_ct, meta

    except Exception as e:
        meta["changed"] = False
        meta["reason"] = f"pass_through_pil_error:{e}"
        meta["out_bytes"] = len(input_bytes)
        return input_bytes, original_ext.lower(), guess_content_type_from_ext(original_ext), meta

# -------------------------
# 5) Robust upload with retries/backoff (bytes-based)
# -------------------------
def upload_one_bytes(blob_name: str, data: bytes, content_type: str):
    blob_client = container_client.get_blob_client(blob_name)
    content_settings = ContentSettings(content_type=content_type)

    last_err = None
    for attempt in range(1, MAX_RETRIES + 1):
        try:
            blob_client.upload_blob(
                data,
                overwrite=True,
                content_settings=content_settings
            )
            return True, None, len(data), content_type
        except Exception as e:
            last_err = e
            backoff = min(60.0, BASE_BACKOFF_SECONDS * (2 ** (attempt - 1)))
            warn(f"[{blob_name}] attempt {attempt}/{MAX_RETRIES} failed: {e}. backoff={backoff}s")
            time.sleep(backoff)

    return False, str(last_err), None, content_type

# -------------------------
# 6) Run upload loop
# -------------------------
all_files = list_source_files(SOURCE_DIR)

# Filter allowed images
img_files = []
for f in all_files:
    name = f["name"]
    ext = os.path.splitext(name.lower())[1]
    if ext in ALLOWED_EXT:
        img_files.append(f)

img_files = sorted(img_files, key=lambda x: x["name"].lower())

if MAX_FILES is not None:
    img_files = img_files[:int(MAX_FILES)]

info(f"Discovered {len(all_files)} items; uploading {len(img_files)} image files")
info(f"Resize config: MAX_DIM={MAX_DIM}, ALWAYS_OUTPUT_JPEG={ALWAYS_OUTPUT_JPEG}, JPEG_QUALITY={JPEG_QUALITY}")

ok = 0
fail = 0
changed = 0

for i, f in enumerate(img_files, start=1):
    name = f["name"]
    local_path = normalize_local_path(f["path"])
    ext = os.path.splitext(name.lower())[1]

    if i % 50 == 0:
        info(f"Progress: {i}/{len(img_files)} | ok={ok} fail={fail} changed={changed}")

    try:
        with open(local_path, "rb") as fp:
            original_bytes = fp.read()

        out_bytes, out_ext, out_ct, meta = resize_image_bytes(original_bytes, ext)

        blob_name = build_blob_name(name, out_ext) if ALWAYS_OUTPUT_JPEG else name

        success, err, nbytes, ct = upload_one_bytes(blob_name, out_bytes, out_ct)

        if success:
            ok += 1
            if meta.get("changed"):
                changed += 1
                info(
                    f"[{blob_name}] {meta['reason']} | "
                    f"{meta.get('orig_w')}x{meta.get('orig_h')} -> {meta.get('out_w')}x{meta.get('out_h')} | "
                    f"{meta.get('orig_bytes')} -> {meta.get('out_bytes')} bytes"
                )
        else:
            fail += 1
            warn(f"[{blob_name}] FAILED permanently: {err}")

    except Exception as e:
        fail += 1
        warn(f"[{name}] Unexpected error: {e}")

    if SLEEP_BETWEEN_FILES and SLEEP_BETWEEN_FILES > 0:
        time.sleep(SLEEP_BETWEEN_FILES)

info("✅ Upload run complete.")
info(f"ok={ok}, fail={fail}, changed={changed}, run_id={run_id}")

# NOTE (important):
# Your pasted SAS shows `sp=r` (read). Upload requires write/create perms (usually includes `w` and `c`).
# If you get auth errors on upload, regenerate the SAS with the right permissions.


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

# ============================================================
# Fabric Notebook: OneLake (Lakehouse Files) -> Azure Blob (SAS)
# - Reads jpg/png from: /lakehouse/default/Files/workday_employee_photos
# - Uploads to container: employee-photos (from your SAS URL)
# - Overwrites existing blobs
# - Retries with backoff on 429/5xx
# ============================================================

import os, re, time, uuid
from urllib.parse import urlparse, parse_qs, urlencode
from datetime import datetime, timezone

# Azure SDK
from azure.storage.blob import BlobServiceClient, ContentSettings

# -------------------------
# 0) Config (from your SAS URL)
# -------------------------
from notebookutils import mssparkutils

# --- Read secrets from Azure Key Vault ---
sas_token_key  = mssparkutils.credentials.getSecret(
    "https://keyvault-fabric2.vault.azure.net/",
    "SASTOKENKEY"
)


SAS_CONTAINER_URL = (
    "https://fabricstoragescus.blob.core.windows.net/employee-photos"
    "?{sas_token_key}"
)

SOURCE_DIR = "/lakehouse/default/Files/workday_employee_photos"  # OneLake files
ALLOWED_EXT = {".jpg", ".jpeg", ".png", ".webp"}                 # adjust if needed

# Tunables
MAX_FILES = None              # e.g. 50 for a test; None = all
MAX_RETRIES = 6
BASE_BACKOFF_SECONDS = 1.0
SLEEP_BETWEEN_FILES = 0.05    # small throttle

run_id = str(uuid.uuid4())

def info(m): print(f"[INFO] {m}", flush=True)
def warn(m): print(f"[WARN] {m}", flush=True)

# -------------------------
# 1) Parse SAS URL -> account_url + container + sas_token
# -------------------------
u = urlparse(SAS_CONTAINER_URL)
account_url = f"{u.scheme}://{u.netloc}"
container_name = u.path.strip("/")

# Keep SAS querystring exactly (order doesn't matter; keep as-is)
sas_token = u.query

info(f"run_id={run_id}")
info(f"account_url={account_url}")
info(f"container={container_name}")
info(f"SOURCE_DIR={SOURCE_DIR}")

# -------------------------
# 2) Blob clients
# -------------------------
# BlobServiceClient using account_url + SAS
service = BlobServiceClient(account_url=account_url, credential=sas_token)
container_client = service.get_container_client(container_name)

# -------------------------
# 3) File discovery helpers (works in Fabric notebooks)
# -------------------------
def list_source_files(source_dir: str):
    """
    List files under OneLake Lakehouse Files.
    Uses dbutils.fs if available; falls back to os walk.
    Returns: list of dicts {path, name, size}
    """
    files = []
    # Try dbutils.fs.ls (Fabric usually has it)
    try:
        ls = dbutils.fs.ls(source_dir)  # noqa: F821
        for x in ls:
            # x.path looks like 'file:/lakehouse/...'? sometimes. Normalize.
            p = x.path
            name = x.name
            size = getattr(x, "size", None)
            files.append({"path": p, "name": name, "size": size})
        return files
    except Exception:
        pass

    # Fallback to local filesystem path
    for root, _, fnames in os.walk(source_dir):
        for fn in fnames:
            full = os.path.join(root, fn)
            try:
                size = os.path.getsize(full)
            except Exception:
                size = None
            files.append({"path": full, "name": fn, "size": size})
    return files

def normalize_local_path(p: str) -> str:
    """
    Convert paths like 'file:/lakehouse/..' to '/lakehouse/..' if needed.
    """
    if p.startswith("file:"):
        # possible formats: file:/lakehouse/... or file:///lakehouse/...
        p2 = p.replace("file://", "")
        if p2.startswith("/"):
            return p2
        if p2.startswith("lakehouse/"):
            return "/" + p2
        return p2
    return p

def guess_content_type(filename: str) -> str:
    ext = os.path.splitext(filename.lower())[1]
    if ext in (".jpg", ".jpeg"): return "image/jpeg"
    if ext == ".png": return "image/png"
    if ext == ".webp": return "image/webp"
    return "application/octet-stream"

# -------------------------
# 4) Robust upload with retries/backoff
# -------------------------
def upload_one(local_path: str, blob_name: str):
    blob_client = container_client.get_blob_client(blob_name)

    ct = guess_content_type(blob_name)
    content_settings = ContentSettings(content_type=ct)

    # Read bytes once (photos are small). If large, stream instead.
    with open(local_path, "rb") as f:
        data = f.read()

    last_err = None
    for attempt in range(1, MAX_RETRIES + 1):
        try:
            blob_client.upload_blob(
                data,
                overwrite=True,
                content_settings=content_settings
            )
            return True, None, len(data), ct
        except Exception as e:
            last_err = e
            # exponential backoff with cap
            backoff = min(60.0, BASE_BACKOFF_SECONDS * (2 ** (attempt - 1)))
            warn(f"[{blob_name}] attempt {attempt}/{MAX_RETRIES} failed: {e}. backoff={backoff}s")
            time.sleep(backoff)

    return False, str(last_err), None, ct

# -------------------------
# 5) Run upload loop
# -------------------------
all_files = list_source_files(SOURCE_DIR)

# Filter allowed images
img_files = []
for f in all_files:
    name = f["name"]
    ext = os.path.splitext(name.lower())[1]
    if ext in ALLOWED_EXT:
        img_files.append(f)

img_files = sorted(img_files, key=lambda x: x["name"].lower())

if MAX_FILES is not None:
    img_files = img_files[:int(MAX_FILES)]

info(f"Discovered {len(all_files)} items; uploading {len(img_files)} image files")

ok = 0
fail = 0

for i, f in enumerate(img_files, start=1):
    name = f["name"]
    local_path = normalize_local_path(f["path"])
    blob_name = name  # keep same filename in blob container

    if i % 50 == 0:
        info(f"Progress: {i}/{len(img_files)} | ok={ok} fail={fail}")

    try:
        success, err, nbytes, ct = upload_one(local_path, blob_name)
        if success:
            ok += 1
        else:
            fail += 1
            warn(f"[{blob_name}] FAILED permanently: {err}")
    except Exception as e:
        fail += 1
        warn(f"[{blob_name}] Unexpected error: {e}")

    if SLEEP_BETWEEN_FILES and SLEEP_BETWEEN_FILES > 0:
        time.sleep(SLEEP_BETWEEN_FILES)

info("✅ Upload run complete.")
info(f"ok={ok}, fail={fail}, run_id={run_id}")


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

# ============================================================
# Workday HR Get_Workers (with photo) -> OneLake Files + Delta metadata
# - No separate Get_Employee_Image operation (does not exist in tenant)
# - Auto-detects valid photo flag in Worker_Response_Group
# - Writes /lakehouse/default/Files/workday_employee_photos/<EmpID>.<ext>
# - Writes metadata Delta table: wd_employee_photo_meta_bronze
# ============================================================

import os, time, uuid, base64, hashlib, re
from pathlib import Path
from datetime import datetime, timezone
import requests, jwt
import xml.etree.ElementTree as ET

from pyspark.sql.types import StructType, StructField, StringType, TimestampType, LongType
from pyspark.sql import functions as F

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
HR_SOAP_URL = f"{HOST}/ccx/service/{TENANT}/Human_Resources/{HR_VERSION}"

HTTP_TIMEOUT = 240
TOKEN_TTL_SECONDS = 300
TOKEN_REFRESH_SKEW_SECONDS = 45

DEFAULT_KEY_PATHS = [
    "/lakehouse/data_central_lh/Files/workday_integration.key",
    "/lakehouse/default/Files/workday_integration.key"
]

DB = spark.catalog.currentDatabase()

FILES_BASE_DIR = "/lakehouse/default/Files/workday_employee_photos"
T_META = f"{DB}.wd_employee_photo_meta_bronze"

# Run controls
MAX_PAGES = None            # set e.g. 2 for testing
PAGE_SIZE = 50              # conservative
SLEEP_BETWEEN_PAGES = 0.15

MAX_RETRIES_PER_PAGE = 3
BACKOFF_BASE_SECONDS = 1.0
CIRCUIT_BREAKER_CONSEC_PAGE_FAIL = 10

# Candidate flags (tenant/version dependent)
PHOTO_FLAG_CANDIDATES = [
    "Include_Photo",
    "Include_Photo_Data",
    "Include_Worker_Photo",
    "Include_Worker_Photo_Data",
    "Include_Worker_Images",
    "Include_Images",
    "Include_Image",
    "Include_Profile_Photo"
]

# These are already known-good in your tenant from earlier work:
BASE_WORKER_FLAGS = [
    "Include_Reference",
    "Include_Personal_Information",
    "Include_Employment_Information",
    "Include_Organizations"
]

NS = {"wd": "urn:com.workday/bsvc", "env": "http://schemas.xmlsoap.org/soap/envelope/"}
BASE64_RE = re.compile(r"^[A-Za-z0-9+/=\s]+$")

def info(m): print(f"[INFO] {m}", flush=True)
def warn(m): print(f"[WARN] {m}", flush=True)

# -------------------------
# 1) Auth
# -------------------------
def read_private_key() -> str:
    for p in DEFAULT_KEY_PATHS:
        if Path(p).is_file():
            return Path(p).read_text(encoding="utf-8")
    raise FileNotFoundError(f"Private key not found. Checked: {DEFAULT_KEY_PATHS}")

SESSION = requests.Session()  # no urllib3 retries; we control retries

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
        return r.json()["access_token"]

    def get(self) -> str:
        now = int(time.time())
        if self.token is None or (now - self.acquired_at) >= (TOKEN_TTL_SECONDS - TOKEN_REFRESH_SKEW_SECONDS):
            info("Getting token…")
            self.token = self._fetch_token()
            self.acquired_at = now
            info("Token OK")
        return self.token

TOKEN_MGR = TokenManager()

# -------------------------
# 2) SOAP helpers
# -------------------------
def soap_post(url: str, soap_xml: str, print_fault_excerpt: bool = True) -> str:
    token = TOKEN_MGR.get()
    headers = {"Content-Type": "text/xml; charset=utf-8", "Authorization": f"Bearer {token}"}
    r = SESSION.post(url, data=soap_xml.encode("utf-8"), headers=headers, timeout=HTTP_TIMEOUT)

    if r.status_code in (401, 403):
        warn(f"HTTP {r.status_code} (auth). Refreshing token and retrying once…")
        TOKEN_MGR.token = None
        token = TOKEN_MGR.get()
        headers["Authorization"] = f"Bearer {token}"
        r = SESSION.post(url, data=soap_xml.encode("utf-8"), headers=headers, timeout=HTTP_TIMEOUT)

    if r.status_code >= 400:
        if print_fault_excerpt:
            warn(f"SOAP HTTP {r.status_code} from {url}")
            warn("SOAP body excerpt (first 2500 chars):")
            print(r.text[:2500])
        raise RuntimeError(f"SOAP HTTP {r.status_code}")
    return r.text

def build_get_workers_request(page: int, count: int, flags: list[str]) -> str:
    # Build Worker_Response_Group from flags
    # Example:
    # <wd:Response_Group>
    #   <wd:Include_Reference>1</wd:Include_Reference>
    #   <wd:Include_Photo_Data>1</wd:Include_Photo_Data>
    # </wd:Response_Group>
    rg = "\n".join([f"        <wd:{f}>1</wd:{f}>" for f in flags])

    return f"""<?xml version="1.0" encoding="UTF-8"?>
<env:Envelope xmlns:env="http://schemas.xmlsoap.org/soap/envelope/" xmlns:wd="urn:com.workday/bsvc">
  <env:Body>
    <wd:Get_Workers_Request wd:version="{HR_VERSION}">
      <wd:Response_Filter>
        <wd:Page>{page}</wd:Page>
        <wd:Count>{count}</wd:Count>
      </wd:Response_Filter>
      <wd:Response_Group>
{rg}
      </wd:Response_Group>
    </wd:Get_Workers_Request>
  </env:Body>
</env:Envelope>
"""

def get_response_results(root):
    def t(n): return n.text.strip() if (n is not None and n.text) else None
    rr = root.find(".//wd:Response_Results", NS)
    return {
        "Total_Results": t(rr.find("wd:Total_Results", NS)) if rr is not None else None,
        "Total_Pages": t(rr.find("wd:Total_Pages", NS)) if rr is not None else None,
        "Page_Results": t(rr.find("wd:Page_Results", NS)) if rr is not None else None,
        "Page": t(rr.find("wd:Page", NS)) if rr is not None else None,
    }

# -------------------------
# 3) File + image parsing helpers
# -------------------------
def ensure_dir(path: str):
    os.makedirs(path, exist_ok=True)

def write_bytes(file_path: str, content: bytes):
    ensure_dir(os.path.dirname(file_path))
    with open(file_path, "wb") as f:
        f.write(content)

def looks_like_base64(s: str) -> bool:
    if not s:
        return False
    s2 = s.strip()
    if len(s2) < 200:
        return False
    if not BASE64_RE.match(s2):
        return False
    try:
        base64.b64decode(s2, validate=False)
        return True
    except Exception:
        return False

def detect_image_ext_and_mime(b: bytes):
    if b.startswith(b"\xFF\xD8\xFF"):
        return "jpg", "image/jpeg"
    if b.startswith(b"\x89PNG\r\n\x1a\n"):
        return "png", "image/png"
    if b.startswith(b"GIF87a") or b.startswith(b"GIF89a"):
        return "gif", "image/gif"
    return "bin", "application/octet-stream"

def id_by_type(parent, wd_type: str):
    if parent is None: return None
    for n in parent.findall("wd:ID", NS):
        if n.get(f"{{{NS['wd']}}}type") == wd_type:
            return n.text.strip() if n.text else None
    return None

def extract_worker_photo_bytes(worker_node) -> bytes | None:
    # We don’t know exact element name. Scan Worker_Data subtree for base64.
    worker_data = worker_node.find("wd:Worker_Data", NS)
    if worker_data is None:
        return None

    candidates = []
    for n in worker_data.iter():
        if n is not None and n.text and looks_like_base64(n.text):
            candidates.append(n.text.strip())

    if not candidates:
        return None

    b64 = max(candidates, key=len)
    try:
        return base64.b64decode(b64)
    except Exception:
        return None

# -------------------------
# 4) Metadata table
# -------------------------
META_SCHEMA = StructType([
    StructField("run_id", StringType(), True),
    StructField("extract_ts_utc", TimestampType(), True),
    StructField("employee_id", StringType(), True),
    StructField("worker_wid", StringType(), True),
    StructField("file_path", StringType(), True),
    StructField("file_name", StringType(), True),
    StructField("content_type", StringType(), True),
    StructField("bytes_len", LongType(), True),
    StructField("sha256", StringType(), True),
    StructField("status", StringType(), True),
    StructField("error_message", StringType(), True),
])

def ensure_meta_table():
    spark.sql(f"""
      CREATE TABLE IF NOT EXISTS {T_META} (
        run_id STRING,
        extract_ts_utc TIMESTAMP,
        employee_id STRING,
        worker_wid STRING,
        file_path STRING,
        file_name STRING,
        content_type STRING,
        bytes_len BIGINT,
        sha256 STRING,
        status STRING,
        error_message STRING
      ) USING DELTA
    """)
    info(f"✅ Ensured metadata table exists: {T_META}")

# -------------------------
# 5) Determine valid photo flag
# -------------------------
def choose_photo_flag():
    # Try base flags + candidate photo flag and see which one doesn’t fault
    for f in PHOTO_FLAG_CANDIDATES:
        flags = BASE_WORKER_FLAGS + [f]
        soap = build_get_workers_request(page=1, count=1, flags=flags)
        try:
            xml_text = soap_post(HR_SOAP_URL, soap, print_fault_excerpt=False)
            root = ET.fromstring(xml_text)
            # If it returned successfully, accept it
            info(f"✅ Photo flag supported: {f}")
            return f
        except Exception as e:
            # ignore and continue
            pass
    warn("⚠️ No photo flag candidate worked. Proceeding without photo flag (will likely produce no images).")
    return None

# -------------------------
# 6) Main load
# -------------------------
def run_worker_photos_to_onelake():
    run_id = str(uuid.uuid4())
    extract_ts_utc = datetime.now(timezone.utc).replace(tzinfo=None)

    info(f"HOST={HOST}")
    info(f"TENANT={TENANT}")
    info(f"HR_SOAP_URL={HR_SOAP_URL}")
    info(f"FILES_BASE_DIR={FILES_BASE_DIR}")
    info(f"run_id={run_id}")

    ensure_dir(FILES_BASE_DIR)
    ensure_meta_table()

    photo_flag = choose_photo_flag()
    flags = BASE_WORKER_FLAGS + ([photo_flag] if photo_flag else [])
    info(f"Using flags: {flags}")

    page = 1
    consec_page_fail = 0

    total_written = 0
    meta_buf = []

    while True:
        if MAX_PAGES is not None and page > int(MAX_PAGES):
            warn(f"MAX_PAGES hit ({MAX_PAGES}). stopping.")
            break

        soap = build_get_workers_request(page=page, count=PAGE_SIZE, flags=flags)

        # page-level retry
        attempt = 0
        xml_text = None
        while True:
            attempt += 1
            try:
                xml_text = soap_post(HR_SOAP_URL, soap, print_fault_excerpt=(attempt == 1))
                consec_page_fail = 0
                break
            except Exception as e:
                if attempt >= MAX_RETRIES_PER_PAGE:
                    consec_page_fail += 1
                    warn(f"Page {page} failed after {attempt} attempts: {e}")
                    xml_text = None
                    break
                backoff = min(BACKOFF_BASE_SECONDS * (2 ** (attempt - 1)), 15)
                warn(f"Page {page} attempt {attempt}/{MAX_RETRIES_PER_PAGE} failed: {e}. backoff={backoff:.1f}s")
                time.sleep(backoff)

        if xml_text is None:
            if consec_page_fail >= CIRCUIT_BREAKER_CONSEC_PAGE_FAIL:
                warn(f"CIRCUIT BREAKER: {consec_page_fail} consecutive page failures. stopping.")
                break
            page += 1
            continue

        root = ET.fromstring(xml_text)
        rr = get_response_results(root)

        workers = root.findall(".//wd:Response_Data/wd:Worker", NS)
        if not workers:
            warn(f"No Worker nodes on page {page}. stopping defensively.")
            break

        for w in workers:
            wref = w.find("wd:Worker_Reference", NS)
            worker_wid = id_by_type(wref, "WID")
            employee_id = id_by_type(wref, "Employee_ID")

            status = "NoImage"
            err = None
            file_name = None
            file_path = None
            content_type = None
            bytes_len = None
            sha256 = None

            try:
                img = extract_worker_photo_bytes(w)
                if img:
                    ext, mime = detect_image_ext_and_mime(img)
                    content_type = mime
                    bytes_len = int(len(img))
                    sha256 = hashlib.sha256(img).hexdigest()
                    if employee_id:
                        file_name = f"{employee_id}.{ext}"
                    else:
                        file_name = f"{worker_wid}.{ext}"
                    file_path = f"{FILES_BASE_DIR}/{file_name}"
                    write_bytes(file_path, img)
                    status = "Success"
                    total_written += 1
            except Exception as e:
                status = "Failed"
                err = str(e)[:3500]

            meta_buf.append({
                "run_id": run_id,
                "extract_ts_utc": extract_ts_utc,
                "employee_id": employee_id,
                "worker_wid": worker_wid,
                "file_path": file_path,
                "file_name": file_name,
                "content_type": content_type,
                "bytes_len": bytes_len,
                "sha256": sha256,
                "status": status,
                "error_message": err
            })

        if len(meta_buf) >= 1000:
            spark.createDataFrame(meta_buf, META_SCHEMA).write.format("delta").mode("append").saveAsTable(T_META)
            meta_buf = []

        info(f"Page {page}: Total_Results={rr.get('Total_Results')} Total_Pages={rr.get('Total_Pages')} Page_Results={rr.get('Page_Results')} | photos_written={total_written}")

        # stop at last page
        try:
            total_pages = int(rr["Total_Pages"]) if rr.get("Total_Pages") else None
            if total_pages and page >= total_pages:
                info(f"Reached last page {page}/{total_pages}.")
                break
        except:
            pass

        page += 1
        time.sleep(SLEEP_BETWEEN_PAGES)

    if meta_buf:
        spark.createDataFrame(meta_buf, META_SCHEMA).write.format("delta").mode("append").saveAsTable(T_META)

    info("✅ Done.")
    info(f"photos_written={total_written}")
    info(f"run_id={run_id}")

# -------------------------
# 7) RUN
# -------------------------
run_worker_photos_to_onelake()

display(
    spark.table(T_META)
         .orderBy(F.col("extract_ts_utc").desc())
         .select("extract_ts_utc","employee_id","worker_wid","file_name","content_type","bytes_len","status","error_message")
         .limit(50)
)


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }
