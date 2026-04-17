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

#!/usr/bin/env python3
"""
fabric_discover_workday_fm.py

Console-only output (no file writes).

Run inside Microsoft Fabric. This script:
- Uses JWT client-assertion flow to get an OAuth access token (reads private key from your lakehouse).
- Requests the Financial_Management WSDL and inspects redirect history / WSDL body for REST version strings.
- Probes a curated list of likely modern Workday REST versions (or version(s) discovered in the WSDL) for candidate Financial_Management resources.
- Retries on 5xx with exponential backoff.
- Waits between each endpoint probe (configurable DELAY_BETWEEN_REQUESTS and optional JITTER_SECONDS) to reduce throttling.
- Prints a concise actionable summary + JSON to console.
"""
from __future__ import print_function
import os
import time
import json
import re
import random
import requests
import jwt
from urllib.parse import urlparse
from typing import List, Dict

# -------------------------
# CONFIG - edit if needed
# -------------------------
CLIENT_ID = "N2ZkZWI1YjktOWM4Ni00ZDI2LTg0MzItNmY5YWMwMGMzYTUx"
ISU_SUBJECT = "ISU_Ms_Fabric"
TOKEN_URL = "https://services1.wd503.myworkday.com/ccx/oauth2/stevenstransport/token"

candidate_key_paths = [
    "/lakehouse/data_central_lh/Files/workday_integration.key",
    "/lakehouse/default/Files/workday_integration.key",
    "./workday_integration.key",
]

CANDIDATE_RESOURCES = [
    "Ledger_Balances",
    "Ledger_Balance",
    "Ledger",
    "Ledger_Entries",
    "Journal_Entries",
    "Journal_Entry",
    "Accounting_Journals",
    "Journal_Entry_Code",
    "Suppliers",
    "Supplier",
    "Payments",
    "Payment",
    "Invoices",
    "Invoice",
    "Accounting_Balances",
    "Expense_Reports",
    "Expense_Report",
]

CURATED_VERSIONS = ["v44.2", "v45.1", "v46.0", "v47.0", "v48.0", "v49.0", "v50.0"]
MAX_VERSIONS_TO_PROBE = 12

DELAY_BETWEEN_REQUESTS = 5.0
JITTER_SECONDS = 0.5

REQUEST_TIMEOUT = 30.0
MAX_RETRIES_ON_503 = 3
BACKOFF_FACTOR = 1.5

# If True, prints full results JSON at the end (can be big).
PRINT_FULL_JSON = False

# -------------------------
# Helpers
# -------------------------
def find_private_key_path() -> str:
    for p in candidate_key_paths:
        if os.path.exists(p):
            return p
    raise FileNotFoundError(f"Private key not found in candidate paths: {candidate_key_paths}")

def parse_host_tenant_from_token_url(token_url: str) -> (str, str):
    parsed = urlparse(token_url)
    host = parsed.netloc
    parts = [p for p in parsed.path.split("/") if p]
    # Expect path like /ccx/oauth2/<tenant>/token
    if len(parts) >= 3:
        tenant = parts[2]
        return host, tenant
    raise ValueError(f"Cannot parse tenant from TOKEN_URL path: {token_url}")

def get_oauth_session() -> requests.Session:
    key_path = find_private_key_path()
    with open(key_path, "r", encoding="utf-8") as f:
        private_key_pem = f.read()

    now = int(time.time())
    claims = {
        "iss": CLIENT_ID,
        "sub": ISU_SUBJECT,
        "aud": TOKEN_URL,
        "iat": now,
        "exp": now + 300
    }

    assertion = jwt.encode(claims, private_key_pem, algorithm="RS256")

    resp = requests.post(
        TOKEN_URL,
        headers={"Content-Type": "application/x-www-form-urlencoded"},
        data={
            "grant_type": "urn:ietf:params:oauth:grant-type:jwt-bearer",
            "assertion": assertion
        },
        timeout=REQUEST_TIMEOUT,
    )

    try:
        body = resp.json()
    except Exception:
        raise SystemExit(f"Auth failed; non-JSON response: {resp.status_code} {resp.text}")

    if "access_token" not in body:
        raise SystemExit(f"Auth failed: {body}")

    access_token = body["access_token"]
    sess = requests.Session()
    sess.headers.update({
        "Authorization": f"Bearer {access_token}",
        "Accept": "application/json",
        "User-Agent": "fabric-workday-fm-discovery/console-only"
    })
    return sess

def discover_versions_from_wsdl(session: requests.Session, host: str, tenant: str) -> Dict:
    wsdl_url = f"https://{host}/ccx/service/{tenant}/Financial_Management?wsdl"
    result = {
        "requested_wsdl": wsdl_url,
        "http_status": None,
        "final_url": None,
        "history_urls": [],
        "found_version_strings": [],
        "raw_matches": [],
        "wsdl_snippet": ""
    }
    try:
        resp = session.get(wsdl_url, timeout=REQUEST_TIMEOUT, allow_redirects=True)
    except Exception as e:
        result["error"] = str(e)
        return result

    result["http_status"] = resp.status_code
    history_urls = []
    for h in resp.history:
        loc = h.headers.get("Location")
        history_urls.append(loc if loc else h.url)
    result["history_urls"] = history_urls
    result["final_url"] = resp.url

    text = resp.text or ""
    result["wsdl_snippet"] = text[:4000]

    raw_matches = set()
    for m in re.finditer(r"/ccx/api/v\d+(?:\.\d+)?/[^\"'\s>]*", text, re.IGNORECASE):
        raw_matches.add(m.group(0))
    for m in re.finditer(r"/Financial_Management/v\d+(?:\.\d+)?/[^\"'\s>]*", text, re.IGNORECASE):
        raw_matches.add(m.group(0))

    combined = " ".join(history_urls + [resp.url])
    for m in re.finditer(r"/v\d+(?:\.\d+)?", combined, re.IGNORECASE):
        raw_matches.add(m.group(0))

    result["raw_matches"] = sorted(raw_matches)

    found_versions = sorted({
        re.search(r"v\d+(?:\.\d+)?", p, re.IGNORECASE).group(0)
        for p in raw_matches
        if re.search(r"v\d+(?:\.\d+)?", p, re.IGNORECASE)
    })
    result["found_version_strings"] = found_versions
    return result

def make_probe_versions(found_versions: List[str]) -> List[str]:
    if found_versions:
        candidates = []
        for v in found_versions:
            candidates.append(v)
            m = re.match(r"v(\d+)(?:\.(\d+))?", v)
            if m:
                major = int(m.group(1))
                candidates.append(f"v{major}.0")
                candidates.append(f"v{major}.1")
        seen = []
        for c in candidates:
            if c not in seen:
                seen.append(c)
        return seen[:MAX_VERSIONS_TO_PROBE]
    return CURATED_VERSIONS[:MAX_VERSIONS_TO_PROBE]

def probe_with_retries(session: requests.Session, urls: List[str]) -> List[Dict]:
    results = []
    for u in urls:
        attempt = 0
        delay = 1.0
        while True:
            try:
                r = session.get(u, timeout=REQUEST_TIMEOUT, allow_redirects=True)
                results.append({
                    "url": u,
                    "status_code": r.status_code,
                    "reason": r.reason,
                    "final_url": r.url,
                    "body_snippet": (r.text[:1000] + "...") if r.text else ""
                })
                break
            except requests.RequestException as e:
                attempt += 1
                if attempt > MAX_RETRIES_ON_503:
                    results.append({"url": u, "error": str(e)})
                    break
                time.sleep(delay)
                delay *= BACKOFF_FACTOR

        base_delay = DELAY_BETWEEN_REQUESTS
        jitter = random.uniform(0, JITTER_SECONDS) if JITTER_SECONDS and JITTER_SECONDS > 0 else 0.0
        time.sleep(base_delay + jitter)

    return results

# -------------------------
# Discovery flow
# -------------------------
def run_discovery():
    host, tenant = parse_host_tenant_from_token_url(TOKEN_URL)
    print(f"[+] Parsed host: {host}, tenant: {tenant}")

    session = get_oauth_session()
    print("[+] Obtained access token and prepared session")

    results = {
        "host": host,
        "tenant": tenant,
        "timestamp": int(time.time()),
        "wsdl_discovery": None,
        "probed_versions": [],
        "probe_results": [],
        "summary": {}
    }

    wsdl_info = discover_versions_from_wsdl(session, host, tenant)
    results["wsdl_discovery"] = wsdl_info
    found_versions = wsdl_info.get("found_version_strings", []) or []

    if found_versions:
        print(f"[+] Found version tokens in WSDL/history: {found_versions}")
    else:
        print("[+] No version tokens found in WSDL/history; will probe curated modern versions")

    probe_versions = make_probe_versions(found_versions)
    results["probed_versions"] = probe_versions
    print(f"[+] Versions to probe (limited): {probe_versions}")

    candidate_urls = []
    for ver in probe_versions:
        ver_label = ver if ver.startswith("v") else f"v{ver}"
        for res in CANDIDATE_RESOURCES:
            candidate_urls.append(f"https://{host}/ccx/api/{ver_label}/{tenant}/Financial_Management/{res}?limit=1")

    print(f"[+] Probing {len(candidate_urls)} endpoints (delay {DELAY_BETWEEN_REQUESTS}s + jitter up to {JITTER_SECONDS}s)...")
    probe_results = probe_with_retries(session, candidate_urls)
    results["probe_results"] = probe_results

    ok = [p for p in probe_results if p.get("status_code") == 200]
    forbidden = [p for p in probe_results if p.get("status_code") == 403]
    not_found = [p for p in probe_results if p.get("status_code") == 404]
    service_unavailable = [p for p in probe_results if p.get("status_code") in (502, 503, 504)]

    results["summary"] = {
        "total_probed": len(probe_results),
        "ok": len(ok),
        "forbidden": len(forbidden),
        "not_found": len(not_found),
        "service_unavailable": len(service_unavailable)
    }

    print("\n=== DISCOVERY SUMMARY ===")
    if ok:
        print(f"✅ Found {len(ok)} working endpoints (200). Top 5:")
        for e in ok[:5]:
            print(f"  200  {e['url']}")
    else:
        print("❌ No 200 responses found.")
        if forbidden:
            print(f"403 (permission) count: {len(forbidden)}. Example:")
            print(f"  403  {forbidden[0]['url']}")
            print("  -> likely missing domain permissions / security group access or pending activation.")
        if not_found:
            print(f"404 (path/version/resource mismatch) count: {len(not_found)}. Examples (first 5):")
            for n in not_found[:5]:
                print(f"  404  {n['url']}")
        if service_unavailable:
            print(f"5xx (service unavailable/throttling) count: {len(service_unavailable)}.")
            print("  -> increase DELAY_BETWEEN_REQUESTS/JITTER_SECONDS, or reduce versions/resources probed.")

    # Console JSON output (no file writes)
    print("\n=== RESULTS JSON (summary + key sections) ===")
    if PRINT_FULL_JSON:
        print(json.dumps(results, indent=2))
    else:
        compact = {
            "host": results["host"],
            "tenant": results["tenant"],
            "timestamp": results["timestamp"],
            "probed_versions": results["probed_versions"],
            "summary": results["summary"],
            "wsdl_discovery": {
                "requested_wsdl": wsdl_info.get("requested_wsdl"),
                "http_status": wsdl_info.get("http_status"),
                "final_url": wsdl_info.get("final_url"),
                "found_version_strings": wsdl_info.get("found_version_strings"),
            },
            "ok_endpoints_sample": ok[:10],
            "forbidden_endpoints_sample": forbidden[:5],
            "not_found_endpoints_sample": not_found[:5],
            "service_unavailable_sample": service_unavailable[:5],
        }
        print(json.dumps(compact, indent=2))

    return results

# -------------------------
# Entry
# -------------------------
if __name__ == "__main__":
    run_discovery()


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

#!/usr/bin/env python3
"""
fabric_discover_workday_fm.py

Updated: increased delay between probes and removed per-probe pause logging.

Run inside Microsoft Fabric. This script:
- Uses the JWT client-assertion flow to get an OAuth access token (reads private key from your lakehouse).
- Requests the Financial_Management WSDL (session.get) and inspects redirect history / WSDL body for REST version strings.
- Probes a curated list of likely modern Workday REST versions (or the version(s) discovered in the WSDL) for a set of candidate Financial_Management resources.
- Retries on 5xx with exponential backoff.
- Waits between each endpoint probe (configurable DELAY_BETWEEN_REQUESTS and optional JITTER_SECONDS) to reduce throttling.
- Saves results to a JSON file in the working directory (and optionally to a lakehouse writable path).
- Prints a concise summary for you to act on.

Changes in this version:
- DELAY_BETWEEN_REQUESTS increased from 1.5s to 5.0s (adjustable at top of file).
- Removed the "[+] Pausing ..." print so the script will pause silently between probes.
"""
from __future__ import print_function
import os
import time
import json
import re
import random
import requests
import jwt
from urllib.parse import urlparse
from typing import List, Dict, Optional

# -------------------------
# CONFIG - edit if needed
# -------------------------
CLIENT_ID = "N2ZkZWI1YjktOWM4Ni00ZDI2LTg0MzItNmY5YWMwMGMzYTUx"
ISU_SUBJECT = "ISU_Ms_Fabric"
TOKEN_URL = "https://services1.wd503.myworkday.com/ccx/oauth2/stevenstransport/token"
candidate_key_paths = [
    "/lakehouse/data_central_lh/Files/workday_integration.key",
    "/lakehouse/default/Files/workday_integration.key",
    "./workday_integration.key",
]

# Candidate Financial_Management resource names to probe.
CANDIDATE_RESOURCES = [
    "Ledger_Balances",
    "Ledger_Balance",
    "Ledger",
    "Ledger_Entries",
    "Journal_Entries",
    "Journal_Entry",
    "Accounting_Journals",
    "Journal_Entry_Code",
    "Suppliers",
    "Supplier",
    "Payments",
    "Payment",
    "Invoices",
    "Invoice",
    "Accounting_Balances",
    "Expense_Reports",
    "Expense_Report",
]

# Curated modern Workday FM versions to try if WSDL gives nothing.
CURATED_VERSIONS = ["v44.2", "v45.1", "v46.0", "v47.0", "v48.0", "v49.0", "v50.0"]

# How many version labels to probe at most (keeps execution bounded)
MAX_VERSIONS_TO_PROBE = 12

# Delay between requests to avoid throttling (in seconds).
# Increased to reduce 5xx responses. Adjust upward if you still see many 5xx.
DELAY_BETWEEN_REQUESTS = 5.0        # base delay in seconds (increased)
JITTER_SECONDS = 0.5                # add up to this many seconds of random jitter

# Output
RESULTS_OUT = "find_workday_fm_results.json"
LAKEHOUSE_OUT = "/lakehouse/default/Files/find_workday_fm_results.json"

# HTTP/request tuning
REQUEST_TIMEOUT = 30.0
MAX_RETRIES_ON_503 = 3
BACKOFF_FACTOR = 1.5

# -------------------------
# Helpers
# -------------------------
def find_private_key_path() -> str:
    for p in candidate_key_paths:
        if os.path.exists(p):
            return p
    raise FileNotFoundError(f"Private key not found in candidate paths: {candidate_key_paths}")

def parse_host_tenant_from_token_url(token_url: str) -> (str, str):
    parsed = urlparse(token_url)
    host = parsed.netloc
    parts = [p for p in parsed.path.split("/") if p]
    # Expect path like /ccx/oauth2/<tenant>/token
    if len(parts) >= 3:
        tenant = parts[2]
        return host, tenant
    raise ValueError(f"Cannot parse tenant from TOKEN_URL path: {token_url}")

def get_oauth_session() -> requests.Session:
    key_path = find_private_key_path()
    with open(key_path, "r", encoding="utf-8") as f:
        private_key_pem = f.read()

    now = int(time.time())
    claims = {
        "iss": CLIENT_ID,
        "sub": ISU_SUBJECT,
        "aud": TOKEN_URL,
        "iat": now,
        "exp": now + 300
    }

    assertion = jwt.encode(claims, private_key_pem, algorithm="RS256")

    resp = requests.post(
        TOKEN_URL,
        headers={"Content-Type": "application/x-www-form-urlencoded"},
        data={
            "grant_type": "urn:ietf:params:oauth:grant-type:jwt-bearer",
            "assertion": assertion
        },
        timeout=REQUEST_TIMEOUT,
    )

    try:
        body = resp.json()
    except Exception:
        raise SystemExit(f"Auth failed; non-JSON response: {resp.status_code} {resp.text}")

    if "access_token" not in body:
        raise SystemExit(f"Auth failed: {body}")

    access_token = body["access_token"]
    sess = requests.Session()
    sess.headers.update({
        "Authorization": f"Bearer {access_token}",
        "Accept": "application/json",
        "User-Agent": "fabric-workday-fm-discovery/1.2"
    })
    return sess

def discover_versions_from_wsdl(session: requests.Session, host: str, tenant: str) -> Dict:
    wsdl_url = f"https://{host}/ccx/service/{tenant}/Financial_Management?wsdl"
    result = {
        "requested_wsdl": wsdl_url,
        "http_status": None,
        "final_url": None,
        "history_urls": [],
        "found_version_strings": [],
        "raw_matches": [],
        "wsdl_snippet": ""
    }
    try:
        resp = session.get(wsdl_url, timeout=REQUEST_TIMEOUT, allow_redirects=True)
    except Exception as e:
        result["error"] = str(e)
        return result

    result["http_status"] = resp.status_code
    history_urls = []
    for h in resp.history:
        loc = h.headers.get("Location")
        history_urls.append(loc if loc else h.url)
    result["history_urls"] = history_urls
    result["final_url"] = resp.url
    text = resp.text or ""
    result["wsdl_snippet"] = text[:4000]

    raw_matches = set()
    for m in re.finditer(r"/ccx/api/v\d+(?:\.\d+)?/[^\"'\s>]*", text, re.IGNORECASE):
        raw_matches.add(m.group(0))
    for m in re.finditer(r"/Financial_Management/v\d+(?:\.\d+)?/[^\"'\s>]*", text, re.IGNORECASE):
        raw_matches.add(m.group(0))
    combined = " ".join(history_urls + [resp.url])
    for m in re.finditer(r"/v\d+(?:\.\d+)?", combined, re.IGNORECASE):
        raw_matches.add(m.group(0))

    result["raw_matches"] = sorted(raw_matches)
    found_versions = sorted({re.search(r"v\d+(?:\.\d+)?", p, re.IGNORECASE).group(0) for p in raw_matches if re.search(r"v\d+(?:\.\d+)?", p, re.IGNORECASE)})
    result["found_version_strings"] = found_versions
    return result

def make_probe_versions(found_versions: List[str]) -> List[str]:
    if found_versions:
        candidates = []
        for v in found_versions:
            candidates.append(v)
            m = re.match(r"v(\d+)(?:\.(\d+))?", v)
            if m:
                major = int(m.group(1))
                candidates.append(f"v{major}.0")
                candidates.append(f"v{major}.1")
        seen = []
        for c in candidates:
            if c not in seen:
                seen.append(c)
        return seen[:MAX_VERSIONS_TO_PROBE]
    else:
        return CURATED_VERSIONS[:MAX_VERSIONS_TO_PROBE]

def probe_with_retries(session: requests.Session, urls: List[str]) -> List[Dict]:
    results = []
    for idx, u in enumerate(urls, start=1):
        attempt = 0
        delay = 1.0
        while True:
            try:
                r = session.get(u, timeout=REQUEST_TIMEOUT, allow_redirects=True)
                results.append({
                    "url": u,
                    "status_code": r.status_code,
                    "reason": r.reason,
                    "final_url": r.url,
                    "body_snippet": (r.text[:1000] + "...") if r.text else ""
                })
                break
            except requests.RequestException as e:
                attempt += 1
                if attempt > MAX_RETRIES_ON_503:
                    results.append({"url": u, "error": str(e)})
                    break
                # backoff on retry
                time.sleep(delay)
                delay *= BACKOFF_FACTOR

        # after finishing attempts for this URL, wait before next URL to avoid throttling
        base_delay = DELAY_BETWEEN_REQUESTS
        jitter = random.uniform(0, JITTER_SECONDS) if JITTER_SECONDS and JITTER_SECONDS > 0 else 0.0
        total_sleep = base_delay + jitter
        time.sleep(total_sleep)
    return results

# -------------------------
# Discovery flow
# -------------------------
def run_discovery():
    host, tenant = parse_host_tenant_from_token_url(TOKEN_URL)
    print(f"[+] Parsed host: {host}, tenant: {tenant}")

    session = get_oauth_session()
    print("[+] Obtained access token and prepared session")

    results = {
        "host": host,
        "tenant": tenant,
        "timestamp": int(time.time()),
        "wsdl_discovery": None,
        "probed_versions": [],
        "probe_results": [],
    }

    # 1) discover via WSDL
    wsdl_info = discover_versions_from_wsdl(session, host, tenant)
    results["wsdl_discovery"] = wsdl_info
    found_versions = wsdl_info.get("found_version_strings", []) or []
    if found_versions:
        print(f"[+] Found version tokens in WSDL/history: {found_versions}")
    else:
        print("[+] No version tokens found in WSDL/history; will probe curated modern versions")

    # 2) prepare list of versions to probe
    probe_versions = make_probe_versions(found_versions)
    print(f"[+] Versions to probe (limited): {probe_versions}")

    # 3) build candidate URLs to probe
    candidate_urls = []
    for ver in probe_versions:
        ver_label = ver if ver.startswith("v") else f"v{ver}"
        for res in CANDIDATE_RESOURCES:
            candidate_urls.append(f"https://{host}/ccx/api/{ver_label}/{tenant}/Financial_Management/{res}?limit=1")

    # 4) probe candidate URLs (with retries/backoff and silent delay between requests)
    print(f"[+] Probing {len(candidate_urls)} candidate endpoints with a base delay of {DELAY_BETWEEN_REQUESTS}s (+ jitter up to {JITTER_SECONDS}s)...")
    probe_results = probe_with_retries(session, candidate_urls)
    results["probe_results"] = probe_results

    # 5) summarise
    ok = [p for p in probe_results if p.get("status_code") == 200]
    forbidden = [p for p in probe_results if p.get("status_code") == 403]
    not_found = [p for p in probe_results if p.get("status_code") == 404]
    service_unavailable = [p for p in probe_results if p.get("status_code") in (502, 503, 504)]
    results["summary"] = {
        "total_probed": len(probe_results),
        "ok": len(ok),
        "forbidden": len(forbidden),
        "not_found": len(not_found),
        "service_unavailable": len(service_unavailable)
    }

    # Save results locally and optionally to lakehouse path
    with open(RESULTS_OUT, "w", encoding="utf-8") as f:
        json.dump(results, f, indent=2)
    print(f"[+] Saved results to {RESULTS_OUT}")

    try:
        with open(LAKEHOUSE_OUT, "w", encoding="utf-8") as f2:
            json.dump(results, f2, indent=2)
        print(f"[+] Also wrote results to {LAKEHOUSE_OUT}")
    except Exception:
        pass

    # Print actionable summary
    print("\n=== DISCOVERY SUMMARY ===")
    if ok:
        print(f"Found {len(ok)} working endpoints. Example:")
        e = ok[0]
        print(f"  {e['url']} -> 200")
    else:
        print("No 200 responses found.")
        if forbidden:
            print(f"{len(forbidden)} endpoints returned 403 (permission). Example:")
            print(f"  {forbidden[0]['url']} -> 403 - you need to grant domain permissions to your SG and activate pending changes.")
        if not_found:
            print(f"{len(not_found)} endpoints returned 404 (path/version/resource mismatch). Examples:")
            for n in not_found[:5]:
                print(f"  {n['url']} -> 404")
        if service_unavailable:
            print(f"{len(service_unavailable)} endpoints returned 5xx (Service Unavailable) - throttling or inappropriate version probing.")
            print("Consider increasing DELAY_BETWEEN_REQUESTS, increasing JITTER_SECONDS, or reducing the number of versions/resources probed.")

    print("\nSaved full JSON results to:", RESULTS_OUT)
    return results

# -------------------------
# Entry
# -------------------------
if __name__ == "__main__":
    res = run_discovery()

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

import pandas as pd
# Load data into pandas DataFrame from "/lakehouse/default/Files/find_workday_fm_results.json"
df = pd.read_json("/lakehouse/default/Files/find_workday_fm_results.json",typ="series")
display(df)


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

import os
from pathlib import Path
p = Path("/data_central_lh/Files")
print("exists:", p.exists(), "writable:", p.exists() and os.access(str(p), os.W_OK))

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

import pandas as pd
from pyspark.sql import SparkSession

# Show sample data
print("\nSample from workday_journals_bronze:")
spark.sql("SELECT journal_number, accounting_date, total_ledger_debits, total_ledger_credits FROM workday_journals_bronze order by accounting_date desc LIMIT 5").show(truncate=False)

print("\nSample from workday_journal_lines_bronze:")
spark.sql("SELECT journal_wid, line_order, ledger_account_id, amount FROM workday_journal_lines_bronze LIMIT 5").show(truncate=False)

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# MARKDOWN ********************


# CELL ********************

# Complete verification of all performance libraries
print("=" * 70)
print("PERFORMANCE LIBRARIES VERIFICATION FOR FABRIC")
print("=" * 70)
print()

# Check orjson
print("orjson (faster JSON - 2-3x speedup):")
try:
    import orjson
    print("   ✅ INSTALLED and working")
    test = orjson.dumps({"test": "data"})
    orjson.loads(test)
    print("   ✅ Functional")
except ImportError:
    print("   ❌ NOT installed")
except Exception as e:
    print(f"   ⚠️  Error: {e}")

print()

# Check lxml
print("lxml (faster XML - 2-5x speedup):")
try:
    from lxml import etree
    print("   ✅ INSTALLED and working")
    test_xml = b'<root><item>test</item></root>'
    etree.fromstring(test_xml)
    print("   ✅ Functional")
except ImportError:
    print("   ❌ NOT installed")
except Exception as e:
    print(f"   ⚠️  Error: {e}")

print()

# Check pandas
print("pandas (data processing):")
try:
    import pandas as pd
    print(f"   ✅ INSTALLED - version {pd.__version__}")
except ImportError:
    print("   ❌ NOT installed")

print()

# Check PySpark
print("PySpark (Spark tables):")
try:
    from pyspark.sql import SparkSession
    spark = SparkSession.builder.getOrCreate()
    print(f"   ✅ INSTALLED - version {spark.version}")
except Exception as e:
    print(f"   ⚠️  Error: {e}")

print()
print("=" * 70)
print("SUMMARY")
print("=" * 70)

# Check what's installed
has_orjson = False
has_lxml = False

try:
    import orjson
    has_orjson = True
except:
    pass

try:
    from lxml import etree
    has_lxml = True
except:
    pass

if has_orjson and has_lxml:
    print("✅✅ EXCELLENT! All performance libraries ready!")
    print("   Expected speedup: 2.5-3x vs sequential")
    print()
    print("   Script will use:")
    print("   • orjson for JSON (3x faster)")
    print("   • lxml for XML (4x faster)")
    print("   • Parallel fetching (4 workers)")
    print("   • Background bronze writing")
elif has_orjson:
    print("✅ GOOD! orjson installed")
    print("   Expected speedup: 2-2.5x vs sequential")
elif has_lxml:
    print("✅ GOOD! lxml installed")  
    print("   Expected speedup: 2-2.5x vs sequential")
else:
    print("⚠️  Standard libraries only")

print()
print("🚀 Ready to run the optimized safe script!")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

"""
Workday Journals Fetcher - Enhanced Field Extraction
VERSION: 10.5 (December 11, 2024)

MAJOR ENHANCEMENTS:
- Added HIGH and MEDIUM priority fields with actual Workday data
- WORKTAGS extraction (cost_center, spend_category, revenue_category, division, full JSON)
- Separate debit_amount and credit_amount (plus ledger amounts)
- Journal status, source, company, currency, ledger, period
- Originated by, sequence number
- REMOVED: line_description (doesn't exist in API)
- Field coverage increased from 28% to 60%

FEATURES:
- Memory-safe batching (50k lines max)
- Adaptive page sizing (target=50)
- Quick recovery (SUCCESS_THRESHOLD=5)
- Sequential processing
- Proper offset tracking
"""
import os
import sys
import time
import json
import traceback
import requests
import jwt
import warnings
from typing import List, Dict, Any, Optional, Tuple
from pathlib import Path
from datetime import datetime

warnings.filterwarnings('ignore')

# PySpark
try:
    from pyspark.sql import SparkSession
    from pyspark.sql.types import StructType, StructField, StringType, DoubleType
    HAS_SPARK = True
except Exception:
    HAS_SPARK = False

# ============================================================================
# CONFIGURATION
# ============================================================================
HOST = os.getenv("WORKDAY_HOST", "https://services1.wd503.myworkday.com").rstrip("/")
TENANT = os.getenv("WORKDAY_TENANT", "stevenstransport")
CLIENT_ID = os.getenv("WORKDAY_CLIENT_ID", "N2ZkZWI1YjktOWM4Ni00ZDI2LTg0MzItNmY5YWMwMGMzYTUx")
ISU_SUBJECT = os.getenv("WORKDAY_ISU_SUBJECT", "ISU_Ms_Fabric")
FM_VERSION = os.getenv("WORKDAY_FM_VERSION", "v45.0")

TOKEN_URL = f"{HOST}/ccx/oauth2/{TENANT}/token"
SERVICE_ENDPOINT = f"{HOST}/ccx/service/{TENANT}/Financial_Management/{FM_VERSION}"

# Adaptive page sizing (tuned for giant payroll journals)
TARGET_PAGE_SIZE = 50
RETRY_SIZES = [50, 25, 10]
SUCCESS_THRESHOLD = 5

# Memory-safe batching
MAX_BATCH_LINES = 50000
MIN_BATCH_PAGES = 1
LOG_INTERVAL = 10
PROGRESS_SAVE_INTERVAL = 25

# HTTP settings
HTTP_TIMEOUT = 120

# Output paths
OUTPUT_PATH = "/lakehouse/default/Files/workday_journals"
PROGRESS_FILE = os.path.join(OUTPUT_PATH, "simple_progress.json")

# Bronze table names
BRONZE_JOURNALS_PATH = "workday_journals_bronze"
BRONZE_LINES_PATH = "workday_journal_lines_bronze"

NS = {"wd": "urn:com.workday/bsvc"}

DEFAULT_KEY_PATHS = [
    "/lakehouse/data_central_lh/Files/workday_integration.key",
    "/lakehouse/default/Files/workday_integration.key"
]

# -------------------------
# Logging
# -------------------------
def info(msg: str):
    print(f"[INFO] {msg}", flush=True)

def warn(msg: str):
    print(f"[WARN] {msg}", flush=True)

def error(msg: str):
    print(f"[ERROR] {msg}", flush=True)

# -------------------------
# Auth
# -------------------------
_token_cache = {"token": None, "expires_at": 0}

def read_private_key() -> str:
    for p in DEFAULT_KEY_PATHS:
        if p and Path(p).is_file():
            return Path(p).read_text(encoding="utf-8")
    raise FileNotFoundError(f"Private key not found. Paths checked: {DEFAULT_KEY_PATHS}")

def get_access_token() -> str:
    now = int(time.time())
    if _token_cache["token"] and _token_cache["expires_at"] > now + 60:
        return _token_cache["token"]
    
    private_key = read_private_key()
    claims = {"iss": CLIENT_ID, "sub": ISU_SUBJECT, "aud": TOKEN_URL, "iat": now, "exp": now + 300}
    assertion = jwt.encode(claims, private_key, algorithm="RS256")
    if isinstance(assertion, bytes):
        assertion = assertion.decode("utf-8")
    
    headers = {"Content-Type": "application/x-www-form-urlencoded"}
    data = {"grant_type": "urn:ietf:params:oauth:grant-type:jwt-bearer", "assertion": assertion}
    
    resp = requests.post(TOKEN_URL, headers=headers, data=data, timeout=HTTP_TIMEOUT)
    
    if resp.status_code != 200:
        error(f"Token request failed {resp.status_code}: {resp.text[:1000]}")
        resp.raise_for_status()
    
    body = resp.json()
    _token_cache["token"] = body["access_token"]
    _token_cache["expires_at"] = now + 240
    
    return _token_cache["token"]

# -------------------------
# XML Building & Parsing
# -------------------------
def build_get_journals_request(page: int, count: int) -> bytes:
    soap = (
        '<?xml version="1.0" encoding="UTF-8"?>'
        '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:wd="urn:com.workday/bsvc">'
        "<soapenv:Header/>"
        "<soapenv:Body>"
        f'<wd:Get_Journals_Request wd:version="{FM_VERSION}">'
        "<wd:Response_Filter>"
        f"<wd:Page>{page}</wd:Page>"
        f"<wd:Count>{count}</wd:Count>"
        "</wd:Response_Filter>"
        "</wd:Get_Journals_Request>"
        "</soapenv:Body></soapenv:Envelope>"
    )
    return soap.encode("utf-8")

def get_text(parent, tag: str) -> Optional[str]:
    try:
        from lxml import etree as ET
        el = parent.find(f"wd:{tag}", NS)
        return el.text.strip() if el is not None and el.text else None
    except ImportError:
        import xml.etree.ElementTree as ET
        el = parent.find(f"wd:{tag}", NS)
        return el.text.strip() if el is not None and el.text else None

def id_text_by_type(parent, path: str, desired_type: Optional[str] = None) -> Optional[str]:
    ids = parent.findall(path, NS)
    for id_el in ids:
        txt = (id_el.text or "").strip()
        for k, v in id_el.attrib.items():
            if k.lower().endswith("type"):
                if desired_type is None or v == desired_type:
                    return txt
    return (ids[0].text or "").strip() if ids else None

def safe_float(text: Optional[str]) -> Optional[float]:
    try:
        return float(text) if text else None
    except Exception:
        return None

def extract_worktags(line_el) -> Dict[str, Any]:
    """Extract worktags from Journal_Entry_Line_Data element"""
    worktags = {
        'cost_center': None,
        'revenue_category': None,
        'spend_category': None,
        'division': None,
        'all_worktags': {}
    }
    
    # Find all Worktags_Reference elements
    worktag_refs = line_el.findall('./wd:Worktags_Reference', NS)
    
    for wt_ref in worktag_refs:
        # Get all ID elements within this worktag reference
        id_elements = wt_ref.findall('./wd:ID', NS)
        
        for id_el in id_elements:
            worktag_type = None
            worktag_value = (id_el.text or "").strip()
            
            # Get the type attribute
            for k, v in id_el.attrib.items():
                if k.lower().endswith("type"):
                    worktag_type = v
                    break
            
            if worktag_type and worktag_value:
                # Store in all_worktags
                worktags['all_worktags'][worktag_type] = worktag_value
                
                # Map to specific fields
                if worktag_type == 'Cost_Center':
                    worktags['cost_center'] = worktag_value
                elif worktag_type == 'Revenue_Category':
                    worktags['revenue_category'] = worktag_value
                elif worktag_type == 'Spend_Category':
                    worktags['spend_category'] = worktag_value
                elif worktag_type in ('Division', 'Organization'):
                    worktags['division'] = worktag_value
    
    # Convert all_worktags dict to JSON string
    worktags['worktags_json'] = json.dumps(worktags['all_worktags']) if worktags['all_worktags'] else None
    
    return worktags

def parse_journals(xml_text: str) -> Tuple[List[Dict[str, Any]], List[Dict[str, Any]]]:
    """Parse Get_Journals response with enhanced fields"""
    try:
        from lxml import etree as ET
        root = ET.fromstring(xml_text.encode('utf-8'))
    except ImportError:
        import xml.etree.ElementTree as ET
        root = ET.fromstring(xml_text)
    except Exception as e:
        warn(f"XML parse error: {e}")
        return [], []
    
    journals: List[Dict[str, Any]] = []
    journal_lines: List[Dict[str, Any]] = []
    
    response_data = root.find('.//wd:Response_Data', NS)
    if response_data is None:
        return [], []
    
    seen_journals = {}
    
    for jel in response_data.findall('./wd:Journal_Entry', NS):
        je_data = jel.find('./wd:Journal_Entry_Data', NS)
        if je_data is None:
            continue
        
        journal_wid = id_text_by_type(je_data, './wd:Journal_Entry_Reference/wd:ID', 'WID')
        if not journal_wid:
            continue
        
        if journal_wid not in seen_journals:
            header = {
                'journal_wid': journal_wid,
                'journal_id': id_text_by_type(je_data, './wd:Journal_Entry_Reference/wd:ID', 'Journal_Entry_ID'),
                'journal_number': get_text(je_data, 'Journal_Number'),
                'journal_sequence_number': get_text(je_data, 'Journal_Sequence_Number'),
                'journal_status': id_text_by_type(je_data, './wd:Journal_Status_Reference/wd:ID'),
                'company_reference_id': id_text_by_type(je_data, './wd:Company_Reference/wd:ID'),
                'currency_id': id_text_by_type(je_data, './wd:Currency_Reference/wd:ID'),
                'ledger_reference_id': id_text_by_type(je_data, './wd:Ledger_Reference/wd:ID'),
                'ledger_period_id': id_text_by_type(je_data, './wd:Ledger_Period_Reference/wd:ID'),
                'accounting_date': get_text(je_data, 'Accounting_Date'),
                'journal_source': id_text_by_type(je_data, './wd:Journal_Source_Reference/wd:ID'),
                'originated_by_id': id_text_by_type(je_data, './wd:Originated_By_Reference/wd:ID'),
                'creation_date': get_text(je_data, 'Creation_Date'),
                'total_ledger_debits': safe_float(get_text(je_data, 'Total_Ledger_Debits')),
                'total_ledger_credits': safe_float(get_text(je_data, 'Total_Ledger_Credits')),
            }
            seen_journals[journal_wid] = header
        else:
            continue
        
        line_elements = je_data.findall('./wd:Journal_Entry_Line_Data', NS)
        
        for line_el in line_elements:
            # Extract amounts
            debit_amt = None
            credit_amt = None
            ledger_debit_amt = None
            ledger_credit_amt = None
            
            # Get Debit Amount (transaction currency)
            for cand in ('Debit_Amount',):
                v = get_text(line_el, cand)
                if v:
                    val = safe_float(v)
                    if val and val != 0:
                        debit_amt = val
                        break
            
            # Get Credit Amount (transaction currency)
            for cand in ('Credit_Amount',):
                v = get_text(line_el, cand)
                if v:
                    val = safe_float(v)
                    if val and val != 0:
                        credit_amt = val
                        break
            
            # Get Ledger Debit Amount (company currency)
            for cand in ('Ledger_Debit_Amount', 'Accounted_Debit_Amount'):
                v = get_text(line_el, cand)
                if v:
                    val = safe_float(v)
                    if val and val != 0:
                        ledger_debit_amt = val
                        break
            
            # Get Ledger Credit Amount (company currency)
            for cand in ('Ledger_Credit_Amount', 'Accounted_Credit_Amount'):
                v = get_text(line_el, cand)
                if v:
                    val = safe_float(v)
                    if val and val != 0:
                        ledger_credit_amt = val
                        break
            
            # Calculate combined amount (debit positive, credit negative)
            if debit_amt is not None:
                amt = debit_amt
            elif credit_amt is not None:
                amt = -credit_amt
            elif ledger_debit_amt is not None:
                amt = ledger_debit_amt
            elif ledger_credit_amt is not None:
                amt = -ledger_credit_amt
            else:
                amt = None
            
            # Extract worktags
            worktags = extract_worktags(line_el)
            
            lr = {
                'journal_wid': journal_wid,
                'line_order': get_text(line_el, 'Line_Order'),
                'line_company_reference_id': id_text_by_type(line_el, './wd:Line_Company_Reference/wd:ID'),
                'ledger_account_id': id_text_by_type(line_el, './wd:Ledger_Account_Reference/wd:ID'),
                'currency_id': id_text_by_type(line_el, './wd:Currency_Reference/wd:ID'),
                'debit_amount': debit_amt,
                'credit_amount': credit_amt,
                'ledger_debit_amount': ledger_debit_amt,
                'ledger_credit_amount': ledger_credit_amt,
                'amount': amt,
                'memo': get_text(line_el, 'Memo'),
                'cost_center': worktags['cost_center'],
                'revenue_category': worktags['revenue_category'],
                'spend_category': worktags['spend_category'],
                'division': worktags['division'],
                'worktags_json': worktags['worktags_json'],
            }
            journal_lines.append(lr)
    
    journals = list(seen_journals.values())
    return journals, journal_lines

# -------------------------
# Data Writing
# -------------------------
JOURNALS_SCHEMA = StructType([
    StructField("journal_wid", StringType(), False),
    StructField("journal_id", StringType(), True),
    StructField("journal_number", StringType(), True),
    StructField("journal_sequence_number", StringType(), True),
    StructField("journal_status", StringType(), True),
    StructField("company_reference_id", StringType(), True),
    StructField("currency_id", StringType(), True),
    StructField("ledger_reference_id", StringType(), True),
    StructField("ledger_period_id", StringType(), True),
    StructField("accounting_date", StringType(), True),
    StructField("journal_source", StringType(), True),
    StructField("originated_by_id", StringType(), True),
    StructField("creation_date", StringType(), True),
    StructField("total_ledger_debits", DoubleType(), True),
    StructField("total_ledger_credits", DoubleType(), True),
])

LINES_SCHEMA = StructType([
    StructField("journal_wid", StringType(), False),
    StructField("line_order", StringType(), True),
    StructField("line_company_reference_id", StringType(), True),
    StructField("ledger_account_id", StringType(), True),
    StructField("currency_id", StringType(), True),
    StructField("debit_amount", DoubleType(), True),
    StructField("credit_amount", DoubleType(), True),
    StructField("ledger_debit_amount", DoubleType(), True),
    StructField("ledger_credit_amount", DoubleType(), True),
    StructField("amount", DoubleType(), True),
    StructField("memo", StringType(), True),
    StructField("cost_center", StringType(), True),
    StructField("revenue_category", StringType(), True),
    StructField("spend_category", StringType(), True),
    StructField("division", StringType(), True),
    StructField("worktags_json", StringType(), True),
])

def write_batch_to_bronze(spark, all_journals: List[Dict], all_lines: List[Dict]) -> bool:
    """Write accumulated batch to Delta tables"""
    try:
        if all_journals:
            j_df = spark.createDataFrame(all_journals, JOURNALS_SCHEMA)
            j_df.write.format("delta").mode("append").saveAsTable(BRONZE_JOURNALS_PATH)
        
        if all_lines:
            l_df = spark.createDataFrame(all_lines, LINES_SCHEMA)
            l_df.write.format("delta").mode("append").saveAsTable(BRONZE_LINES_PATH)
        
        return True
    except Exception as e:
        error(f"Write error: {e}")
        error(traceback.format_exc())
        return False

# -------------------------
# Progress Management
# -------------------------
def load_progress() -> Tuple[int, int]:
    if not os.path.exists(PROGRESS_FILE):
        return 0, TARGET_PAGE_SIZE
    
    try:
        with open(PROGRESS_FILE, 'r') as f:
            data = json.load(f)
            return data.get('next_offset', 0), data.get('page_size', TARGET_PAGE_SIZE)
    except Exception:
        return 0, TARGET_PAGE_SIZE

def save_progress(offset: int, page_size: int, total_journals: int):
    try:
        os.makedirs(OUTPUT_PATH, exist_ok=True)
        data = {
            'next_offset': offset,
            'page_size': page_size,
            'total_journals': total_journals,
            'timestamp': datetime.now().isoformat()
        }
        with open(PROGRESS_FILE, 'w') as f:
            json.dump(data, f, indent=2)
    except Exception:
        pass

def calculate_api_page(offset: int, page_size: int) -> int:
    return (offset // page_size) + 1

# -------------------------
# Adaptive Page Sizing
# -------------------------
class PageSizeManager:
    def __init__(self):
        self.current_size = TARGET_PAGE_SIZE
        self.consecutive_successes = 0
        self.retry_index = 0
    
    def record_success(self):
        self.consecutive_successes += 1
        if self.consecutive_successes >= SUCCESS_THRESHOLD and self.retry_index > 0:
            self.retry_index = max(0, self.retry_index - 1)
            self.current_size = RETRY_SIZES[self.retry_index]
            self.consecutive_successes = 0
    
    def record_failure(self) -> Optional[int]:
        self.consecutive_successes = 0
        if self.retry_index < len(RETRY_SIZES) - 1:
            self.retry_index += 1
            self.current_size = RETRY_SIZES[self.retry_index]
            return self.current_size
        else:
            return None
    
    def get_current_size(self) -> int:
        return self.current_size

# -------------------------
# Main Fetch Logic
# -------------------------
def fetch_journals(spark):
    """Memory-safe sequential fetch with enhanced field extraction"""
    
    try:
        token = get_access_token()
    except Exception as e:
        error(f"Failed to get token: {e}")
        return
    
    session = requests.Session()
    session.headers.update({
        "Authorization": f"Bearer {token}",
        "Accept": "text/xml, application/xml",
        "Content-Type": "text/xml; charset=utf-8"
    })
    
    current_offset, saved_page_size = load_progress()
    
    # Always start with TARGET_PAGE_SIZE, ignore saved page size
    psm = PageSizeManager()
    psm.current_size = TARGET_PAGE_SIZE
    
    info(f"Starting from offset {current_offset:,}")
    info(f"Page size reset to {TARGET_PAGE_SIZE} (ignoring saved size {saved_page_size})")
    info(f"Memory-safe mode: Will flush batch when lines exceed {MAX_BATCH_LINES:,}")
    info(f"Enhanced extraction: Worktags, Status, Source, Currency, Ledger, etc.")
    
    consecutive_empty = 0
    total_journals = 0
    total_lines = 0
    iteration = 0
    
    # Batch accumulators
    batch_journals = []
    batch_lines = []
    batch_count = 0
    
    start_time = time.time()
    
    while True:
        iteration += 1
        
        if consecutive_empty >= 3:
            # Flush remaining batch
            if batch_journals or batch_lines:
                info(f"Flushing final batch: {len(batch_journals):,} journals, {len(batch_lines):,} lines")
                write_batch_to_bronze(spark, batch_journals, batch_lines)
            info(f"Complete: {total_journals:,} journals, {total_lines:,} lines")
            break
        
        page_size = psm.get_current_size()
        api_page = calculate_api_page(current_offset, page_size)
        body = build_get_journals_request(api_page, page_size)
        
        # Fetch
        try:
            resp = session.post(SERVICE_ENDPOINT, data=body, timeout=HTTP_TIMEOUT)
            
            if resp.status_code != 200:
                error(f"HTTP {resp.status_code} at page {api_page}")
                next_size = psm.record_failure()
                if not next_size:
                    return
                time.sleep(2)
                continue
            
            if 'soap:Fault' in resp.text:
                error(f"SOAP fault at page {api_page}")
                next_size = psm.record_failure()
                if not next_size:
                    return
                time.sleep(2)
                continue
            
        except Exception as e:
            error(f"Request error: {e}")
            next_size = psm.record_failure()
            if not next_size:
                return
            time.sleep(2)
            continue
        
        # Parse
        journals, lines = parse_journals(resp.text)
        
        if not journals:
            consecutive_empty += 1
            current_offset += page_size
            continue
        
        consecutive_empty = 0
        
        # MEMORY-SAFE: Check if this page is huge and would push us over limit
        if len(batch_lines) > 0 and len(batch_lines) + len(lines) > MAX_BATCH_LINES and batch_count >= MIN_BATCH_PAGES:
            # Flush current batch before adding this large page
            info(f"🔄 Flushing batch ({len(batch_lines):,} lines) before adding {len(lines):,} line page")
            success = write_batch_to_bronze(spark, batch_journals, batch_lines)
            if not success:
                error("Batch write failed")
                return
            
            batch_journals = []
            batch_lines = []
            batch_count = 0
        
        # Accumulate in batch
        batch_journals.extend(journals)
        batch_lines.extend(lines)
        batch_count += 1
        
        total_journals += len(journals)
        total_lines += len(lines)
        current_offset += len(journals)
        
        # MEMORY-SAFE: Also check total lines in batch
        if len(batch_lines) >= MAX_BATCH_LINES and batch_count >= MIN_BATCH_PAGES:
            info(f"✓ Writing batch: {len(batch_journals):,} journals, {len(batch_lines):,} lines")
            success = write_batch_to_bronze(spark, batch_journals, batch_lines)
            if not success:
                error("Batch write failed")
                return
            
            # Log progress
            if iteration % LOG_INTERVAL == 0:
                elapsed = time.time() - start_time
                rate = total_journals / elapsed if elapsed > 0 else 0
                info(f"Progress: offset {current_offset:,} | {total_journals:,} journals | {total_lines:,} lines | {rate:.1f} j/sec")
            
            # Clear batch
            batch_journals = []
            batch_lines = []
            batch_count = 0
        
        # Save progress periodically
        if iteration % PROGRESS_SAVE_INTERVAL == 0:
            save_progress(current_offset, psm.get_current_size(), total_journals)
        
        psm.record_success()
    
    # Final progress save
    save_progress(current_offset, psm.get_current_size(), total_journals)
    
    elapsed = time.time() - start_time
    rate = total_journals / elapsed if elapsed > 0 else 0
    info(f"\n" + "="*70)
    info(f"Runtime: {elapsed:.1f}s ({elapsed/60:.1f} min)")
    info(f"Average rate: {rate:.1f} journals/sec")
    info("="*70)

# -------------------------
# Main
# -------------------------
def main():
    VERSION = "10.5"
    info("="*70)
    info(f"Workday Journals Fetcher v{VERSION} - Enhanced Field Extraction")
    info("="*70)
    
    if not HAS_SPARK:
        error("PySpark not available")
        return
    
    try:
        spark = SparkSession.getActiveSession()
        if not spark:
            error("No active Spark session")
            return
        info("✓ Spark session ready")
        spark.conf.set("spark.sql.adaptive.enabled", "true")
        spark.conf.set("spark.databricks.delta.optimizeWrite.enabled", "true")
        spark.conf.set("spark.databricks.delta.autoCompact.enabled", "true")
    except Exception as e:
        error(f"Spark error: {e}")
        return
    
    try:
        fetch_journals(spark)
    except KeyboardInterrupt:
        warn("\nInterrupted by user")
    except Exception as e:
        error(f"\nFatal error: {e}")
        error(traceback.format_exc())
        raise

if __name__ == "__main__":
    main()

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

#!/usr/bin/env python3
"""
Workday Customers Fetcher
VERSION: 1.2 (December 16, 2025)

FEATURES:
- Extracts ALL customer data from Workday Revenue_Management SOAP API
- Comprehensive field extraction including contact info, addresses, status, balances
- FULL REFRESH on every run (clears bronze table, balances are current state)
- Memory-safe batching (50k customers max per batch)
- Adaptive page sizing (target=100)
- Sequential processing
- OAuth2 JWT authentication
"""
import os
import sys
import time
import json
import traceback
import requests
import jwt
import warnings
from typing import List, Dict, Any, Optional, Tuple
from pathlib import Path
from datetime import datetime

warnings.filterwarnings('ignore')

# PySpark
try:
    from pyspark.sql import SparkSession
    from pyspark.sql.types import StructType, StructField, StringType, DoubleType, IntegerType
    HAS_SPARK = True
except Exception:
    HAS_SPARK = False

# ============================================================================
# CONFIGURATION
# ============================================================================
HOST = os.getenv("WORKDAY_HOST", "https://services1.wd503.myworkday.com").rstrip("/")
TENANT = os.getenv("WORKDAY_TENANT", "stevenstransport")
CLIENT_ID = os.getenv("WORKDAY_CLIENT_ID", "N2ZkZWI1YjktOWM4Ni00ZDI2LTg0MzItNmY5YWMwMGMzYTUx")
ISU_SUBJECT = os.getenv("WORKDAY_ISU_SUBJECT", "ISU_Ms_Fabric")
RM_VERSION = os.getenv("WORKDAY_RM_VERSION", "v45.0")

TOKEN_URL = f"{HOST}/ccx/oauth2/{TENANT}/token"
SERVICE_ENDPOINT = f"{HOST}/ccx/service/{TENANT}/Revenue_Management/{RM_VERSION}"

# Adaptive page sizing
TARGET_PAGE_SIZE = 100
RETRY_SIZES = [100, 50, 25]
SUCCESS_THRESHOLD = 5

# Memory-safe batching
MAX_BATCH_CUSTOMERS = 50000
MIN_BATCH_PAGES = 1
LOG_INTERVAL = 10
PROGRESS_SAVE_INTERVAL = 25

# HTTP settings
HTTP_TIMEOUT = 120

# Output paths
OUTPUT_PATH = "/lakehouse/default/Files/workday_customers"
PROGRESS_FILE = os.path.join(OUTPUT_PATH, "customer_progress.json")

# Bronze table name
BRONZE_CUSTOMERS_PATH = "workday_customers_bronze"

NS = {"wd": "urn:com.workday/bsvc"}

DEFAULT_KEY_PATHS = [
    "/lakehouse/data_central_lh/Files/workday_integration.key",
    "/lakehouse/default/Files/workday_integration.key"
]

# -------------------------
# Logging
# -------------------------
def info(msg: str):
    print(f"[INFO] {msg}", flush=True)

def warn(msg: str):
    print(f"[WARN] {msg}", flush=True)

def error(msg: str):
    print(f"[ERROR] {msg}", flush=True)

# -------------------------
# Auth
# -------------------------
_token_cache = {"token": None, "expires_at": 0}

def read_private_key() -> str:
    for p in DEFAULT_KEY_PATHS:
        if p and Path(p).is_file():
            return Path(p).read_text(encoding="utf-8")
    raise FileNotFoundError(f"Private key not found. Paths checked: {DEFAULT_KEY_PATHS}")

def get_access_token() -> str:
    now = int(time.time())
    if _token_cache["token"] and _token_cache["expires_at"] > now + 60:
        return _token_cache["token"]
    
    private_key = read_private_key()
    claims = {"iss": CLIENT_ID, "sub": ISU_SUBJECT, "aud": TOKEN_URL, "iat": now, "exp": now + 300}
    assertion = jwt.encode(claims, private_key, algorithm="RS256")
    if isinstance(assertion, bytes):
        assertion = assertion.decode("utf-8")
    
    headers = {"Content-Type": "application/x-www-form-urlencoded"}
    data = {"grant_type": "urn:ietf:params:oauth:grant-type:jwt-bearer", "assertion": assertion}
    
    resp = requests.post(TOKEN_URL, headers=headers, data=data, timeout=HTTP_TIMEOUT)
    
    if resp.status_code != 200:
        error(f"Token request failed {resp.status_code}: {resp.text[:1000]}")
        resp.raise_for_status()
    
    body = resp.json()
    _token_cache["token"] = body["access_token"]
    _token_cache["expires_at"] = now + 240
    
    return _token_cache["token"]

# -------------------------
# XML Building & Parsing
# -------------------------
def build_get_customers_request(page: int, count: int) -> bytes:
    soap = (
        '<?xml version="1.0" encoding="UTF-8"?>'
        '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:wd="urn:com.workday/bsvc">'
        "<soapenv:Header/>"
        "<soapenv:Body>"
        f'<wd:Get_Customers_Request wd:version="{RM_VERSION}">'
        "<wd:Response_Filter>"
        f"<wd:Page>{page}</wd:Page>"
        f"<wd:Count>{count}</wd:Count>"
        "</wd:Response_Filter>"
        "</wd:Get_Customers_Request>"
        "</soapenv:Body></soapenv:Envelope>"
    )
    return soap.encode("utf-8")

def get_text(parent, tag: str) -> Optional[str]:
    try:
        from lxml import etree as ET
        el = parent.find(f"wd:{tag}", NS)
        return el.text.strip() if el is not None and el.text else None
    except ImportError:
        import xml.etree.ElementTree as ET
        el = parent.find(f"wd:{tag}", NS)
        return el.text.strip() if el is not None and el.text else None

def get_attrib(parent, tag: str, attrib: str) -> Optional[str]:
    try:
        from lxml import etree as ET
        el = parent.find(f"wd:{tag}", NS)
        return el.attrib.get(attrib) if el is not None else None
    except ImportError:
        import xml.etree.ElementTree as ET
        el = parent.find(f"wd:{tag}", NS)
        return el.attrib.get(attrib) if el is not None else None

def id_text_by_type(parent, path: str, desired_type: Optional[str] = None) -> Optional[str]:
    ids = parent.findall(path, NS)
    for id_el in ids:
        txt = (id_el.text or "").strip()
        for k, v in id_el.attrib.items():
            if k.lower().endswith("type"):
                if desired_type is None or v == desired_type:
                    return txt
    return (ids[0].text or "").strip() if ids else None

def safe_float(text: Optional[str]) -> Optional[float]:
    try:
        return float(text) if text else None
    except Exception:
        return None

def safe_int(text: Optional[str]) -> Optional[int]:
    try:
        return int(text) if text else None
    except Exception:
        return None

def extract_contact_info(contact_data) -> Dict[str, Any]:
    """Extract contact information including addresses, phones, emails"""
    contact = {
        'primary_address_line1': None,
        'primary_address_line2': None,
        'primary_address_city': None,
        'primary_address_state': None,
        'primary_address_postal_code': None,
        'primary_address_country': None,
        'primary_phone': None,
        'primary_email': None,
        'address_json': None,
        'phone_json': None,
        'email_json': None
    }
    
    if contact_data is None:
        return contact
    
    # Extract addresses
    addresses = []
    for addr_data in contact_data.findall('./wd:Address_Data', NS):
        addr_info = {}
        addr_info['formatted'] = get_text(addr_data, 'Formatted_Address')
        addr_info['line1'] = get_text(addr_data, 'Address_Line_Data_1')
        addr_info['line2'] = get_text(addr_data, 'Address_Line_Data_2')
        addr_info['city'] = get_text(addr_data, 'Municipality')
        addr_info['state'] = get_text(addr_data, 'Country_Region_Descriptor')
        addr_info['postal_code'] = get_text(addr_data, 'Postal_Code')
        addr_info['country'] = id_text_by_type(addr_data, './wd:Country_Reference/wd:ID')
        
        # Get usage type properly - can't use @ in find()
        usage_data = addr_data.find('./wd:Usage_Data', NS)
        if usage_data is not None:
            type_data = usage_data.find('./wd:Type_Data', NS)
            if type_data is not None:
                type_ref = type_data.find('./wd:Type_Reference', NS)
                if type_ref is not None:
                    # Attributes don't use namespace prefix in .get()
                    addr_info['usage'] = type_ref.get('Descriptor', 'BUSINESS')
                else:
                    addr_info['usage'] = 'BUSINESS'
            else:
                addr_info['usage'] = 'BUSINESS'
        else:
            addr_info['usage'] = 'BUSINESS'
        
        # Check if primary
        public_elem = addr_data.find('./wd:Usage_Data/wd:Public', NS)
        is_public = public_elem is not None and public_elem.text == '1'
        
        if is_public and not contact['primary_address_line1']:
            contact['primary_address_line1'] = addr_info['line1']
            contact['primary_address_line2'] = addr_info['line2']
            contact['primary_address_city'] = addr_info['city']
            contact['primary_address_state'] = addr_info['state']
            contact['primary_address_postal_code'] = addr_info['postal_code']
            contact['primary_address_country'] = addr_info['country']
        
        addresses.append(addr_info)
    
    if addresses:
        contact['address_json'] = json.dumps(addresses)
    
    # Extract phones
    phones = []
    for phone_data in contact_data.findall('./wd:Phone_Data', NS):
        phone_info = {}
        phone_info['number'] = get_text(phone_data, 'Formatted_Phone')
        phone_info['country_code'] = get_text(phone_data, 'International_Phone_Code')
        phone_info['area_code'] = get_text(phone_data, 'Area_Code')
        phone_info['phone_number'] = get_text(phone_data, 'Phone_Number')
        phone_info['extension'] = get_text(phone_data, 'Phone_Extension')
        
        public_elem = phone_data.find('./wd:Usage_Data/wd:Public', NS)
        is_public = public_elem is not None and public_elem.text == '1'
        
        if is_public and not contact['primary_phone']:
            contact['primary_phone'] = phone_info['number']
        
        phones.append(phone_info)
    
    if phones:
        contact['phone_json'] = json.dumps(phones)
    
    # Extract emails
    emails = []
    for email_data in contact_data.findall('./wd:Email_Address_Data', NS):
        email_info = {}
        email_info['address'] = get_text(email_data, 'Email_Address')
        
        public_elem = email_data.find('./wd:Usage_Data/wd:Public', NS)
        is_public = public_elem is not None and public_elem.text == '1'
        
        if is_public and not contact['primary_email']:
            contact['primary_email'] = email_info['address']
        
        emails.append(email_info)
    
    if emails:
        contact['email_json'] = json.dumps(emails)
    
    return contact

def parse_customers(xml_text: str) -> List[Dict[str, Any]]:
    """Parse Get_Customers response with comprehensive fields"""
    try:
        from lxml import etree as ET
        root = ET.fromstring(xml_text.encode('utf-8'))
    except ImportError:
        import xml.etree.ElementTree as ET
        root = ET.fromstring(xml_text)
    except Exception as e:
        warn(f"XML parse error: {e}")
        return []
    
    customers: List[Dict[str, Any]] = []
    
    response_data = root.find('.//wd:Response_Data', NS)
    if response_data is None:
        return []
    
    for cust_elem in response_data.findall('./wd:Customer', NS):
        # Customer Reference is at Customer level, not Customer_Data level
        customer_wid = id_text_by_type(cust_elem, './wd:Customer_Reference/wd:ID', 'WID')
        if not customer_wid:
            continue
        
        customer_id = id_text_by_type(cust_elem, './wd:Customer_Reference/wd:ID', 'Customer_ID')
        customer_ref_id = id_text_by_type(cust_elem, './wd:Customer_Reference/wd:ID', 'Customer_Reference_ID')
        customer_descriptor = get_attrib(cust_elem, 'Customer_Reference', 'Descriptor')
        
        # Now get Customer_Data
        cust_data = cust_elem.find('./wd:Customer_Data', NS)
        if cust_data is None:
            continue
        
        # Basic Info
        customer_name = get_text(cust_data, 'Customer_Name')
        worktag_only = get_text(cust_data, 'Worktag_Only')
        
        # Approval Status
        approval_status = id_text_by_type(cust_data, './wd:Approval_Status_Reference/wd:ID')
        
        # Categories and Groups
        customer_category = id_text_by_type(cust_data, './wd:Customer_Category_Reference/wd:ID')
        customer_group = id_text_by_type(cust_data, './wd:Customer_Group_Reference/wd:ID')
        
        # Payment Terms
        payment_terms = id_text_by_type(cust_data, './wd:Payment_Terms_Reference/wd:ID')
        default_payment_type = id_text_by_type(cust_data, './wd:Default_Payment_Type_Reference/wd:ID')
        
        # Credit Info
        credit_limit_currency = id_text_by_type(cust_data, './wd:Credit_Limit_Currency_Reference/wd:ID')
        credit_limit = safe_float(get_text(cust_data, 'Credit_Limit'))
        hierarchy_credit_limit = safe_float(get_text(cust_data, 'Hierarchy_Credit_Limit'))
        credit_verification_date = get_text(cust_data, 'Credit_Verification_Date')
        
        # Scores
        commercial_credit_score = safe_int(get_text(cust_data, 'Commercial_Credit_Score'))
        commercial_credit_score_date = get_text(cust_data, 'Commercial_Credit_Score_Date')
        composite_risk_score = safe_int(get_text(cust_data, 'Composite_Risk_Score'))
        composite_risk_date = get_text(cust_data, 'Composite_Risk_Date')
        
        # Other Info
        duns_number = get_text(cust_data, 'DUNS_Number')
        exempt_from_fees = get_text(cust_data, 'Exempt')
        always_separate_payments = get_text(cust_data, 'Always_Separate_Payments')
        currency = id_text_by_type(cust_data, './wd:Currency_Reference/wd:ID')
        
        # Business Entity Data
        business_entity_data = cust_data.find('./wd:Business_Entity_Data', NS)
        business_entity_name = None
        external_entity_id = None
        tax_id = None
        contact_info = {}
        
        if business_entity_data is not None:
            business_entity_name = get_text(business_entity_data, 'Business_Entity_Name')
            external_entity_id = get_text(business_entity_data, 'External_Entity_ID')
            
            # Tax IDs
            for tax_id_elem in business_entity_data.findall('./wd:Tax_ID_Data', NS):
                tax_id = get_text(tax_id_elem, 'Tax_ID')
                if tax_id:
                    break
            
            # Contact Information
            contact_data = business_entity_data.find('./wd:Contact_Data', NS)
            if contact_data is not None:
                contact_info = extract_contact_info(contact_data)
        
        # Customer Status
        customer_status = None
        customer_status_date = None
        status_reason = None
        status_data = cust_data.find('./wd:Customer_Status_Data', NS)
        if status_data is not None:
            customer_status = id_text_by_type(status_data, './wd:Customer_Status_Value_Reference/wd:ID')
            customer_status_date = get_text(status_data, 'Customer_Status_Date')
            status_reason = id_text_by_type(status_data, './wd:Customer_Status_Change_Reason_Reference/wd:ID')
        
        # Balance Information (from summary data if available)
        total_balance = None
        ytd_sales = None
        last_12_months_sales = None
        overdue_balance = None
        
        # Try to find balance in various places
        for elem in cust_data.findall('.//wd:Total_Balance', NS):
            total_balance = safe_float(elem.text)
            break
        
        for elem in cust_data.findall('.//wd:YTD_Sales_Amount', NS):
            ytd_sales = safe_float(elem.text)
            break
        
        for elem in cust_data.findall('.//wd:Last_12_Months_Sales_Amount', NS):
            last_12_months_sales = safe_float(elem.text)
            break
        
        for elem in cust_data.findall('.//wd:Overdue_Balance', NS):
            overdue_balance = safe_float(elem.text)
            break
        
        # Build customer record
        customer = {
            # IDs
            'customer_wid': customer_wid,
            'customer_id': customer_id,
            'customer_reference_id': customer_ref_id,
            'customer_descriptor': customer_descriptor,
            
            # Basic Info
            'customer_name': customer_name,
            'business_entity_name': business_entity_name,
            'external_entity_id': external_entity_id,
            'worktag_only': worktag_only,
            
            # Status
            'approval_status': approval_status,
            'customer_status': customer_status,
            'customer_status_date': customer_status_date,
            'status_reason': status_reason,
            
            # Categories
            'customer_category': customer_category,
            'customer_group': customer_group,
            
            # Payment Terms
            'payment_terms': payment_terms,
            'default_payment_type': default_payment_type,
            'currency': currency,
            'always_separate_payments': always_separate_payments,
            
            # Credit Info
            'credit_limit_currency': credit_limit_currency,
            'credit_limit': credit_limit,
            'hierarchy_credit_limit': hierarchy_credit_limit,
            'credit_verification_date': credit_verification_date,
            'commercial_credit_score': commercial_credit_score,
            'commercial_credit_score_date': commercial_credit_score_date,
            'composite_risk_score': composite_risk_score,
            'composite_risk_date': composite_risk_date,
            
            # Other
            'tax_id': tax_id,
            'duns_number': duns_number,
            'exempt_from_fees': exempt_from_fees,
            
            # Balances
            'total_balance': total_balance,
            'ytd_sales_amount': ytd_sales,
            'last_12_months_sales_amount': last_12_months_sales,
            'overdue_balance': overdue_balance,
            
            # Contact Info (from extract_contact_info)
            'primary_address_line1': contact_info.get('primary_address_line1'),
            'primary_address_line2': contact_info.get('primary_address_line2'),
            'primary_address_city': contact_info.get('primary_address_city'),
            'primary_address_state': contact_info.get('primary_address_state'),
            'primary_address_postal_code': contact_info.get('primary_address_postal_code'),
            'primary_address_country': contact_info.get('primary_address_country'),
            'primary_phone': contact_info.get('primary_phone'),
            'primary_email': contact_info.get('primary_email'),
            'all_addresses_json': contact_info.get('address_json'),
            'all_phones_json': contact_info.get('phone_json'),
            'all_emails_json': contact_info.get('email_json'),
        }
        
        customers.append(customer)
    
    return customers

# -------------------------
# Data Writing
# -------------------------
CUSTOMERS_SCHEMA = StructType([
    # IDs
    StructField("customer_wid", StringType(), False),
    StructField("customer_id", StringType(), True),
    StructField("customer_reference_id", StringType(), True),
    StructField("customer_descriptor", StringType(), True),
    
    # Basic Info
    StructField("customer_name", StringType(), True),
    StructField("business_entity_name", StringType(), True),
    StructField("external_entity_id", StringType(), True),
    StructField("worktag_only", StringType(), True),
    
    # Status
    StructField("approval_status", StringType(), True),
    StructField("customer_status", StringType(), True),
    StructField("customer_status_date", StringType(), True),
    StructField("status_reason", StringType(), True),
    
    # Categories
    StructField("customer_category", StringType(), True),
    StructField("customer_group", StringType(), True),
    
    # Payment Terms
    StructField("payment_terms", StringType(), True),
    StructField("default_payment_type", StringType(), True),
    StructField("currency", StringType(), True),
    StructField("always_separate_payments", StringType(), True),
    
    # Credit Info
    StructField("credit_limit_currency", StringType(), True),
    StructField("credit_limit", DoubleType(), True),
    StructField("hierarchy_credit_limit", DoubleType(), True),
    StructField("credit_verification_date", StringType(), True),
    StructField("commercial_credit_score", IntegerType(), True),
    StructField("commercial_credit_score_date", StringType(), True),
    StructField("composite_risk_score", IntegerType(), True),
    StructField("composite_risk_date", StringType(), True),
    
    # Other
    StructField("tax_id", StringType(), True),
    StructField("duns_number", StringType(), True),
    StructField("exempt_from_fees", StringType(), True),
    
    # Balances
    StructField("total_balance", DoubleType(), True),
    StructField("ytd_sales_amount", DoubleType(), True),
    StructField("last_12_months_sales_amount", DoubleType(), True),
    StructField("overdue_balance", DoubleType(), True),
    
    # Contact Info
    StructField("primary_address_line1", StringType(), True),
    StructField("primary_address_line2", StringType(), True),
    StructField("primary_address_city", StringType(), True),
    StructField("primary_address_state", StringType(), True),
    StructField("primary_address_postal_code", StringType(), True),
    StructField("primary_address_country", StringType(), True),
    StructField("primary_phone", StringType(), True),
    StructField("primary_email", StringType(), True),
    StructField("all_addresses_json", StringType(), True),
    StructField("all_phones_json", StringType(), True),
    StructField("all_emails_json", StringType(), True),
])

def write_batch_to_bronze(spark, all_customers: List[Dict]) -> bool:
    """Write accumulated batch to Delta table"""
    try:
        if all_customers:
            df = spark.createDataFrame(all_customers, CUSTOMERS_SCHEMA)
            df.write.format("delta").mode("append").saveAsTable(BRONZE_CUSTOMERS_PATH)
        return True
    except Exception as e:
        error(f"Write error: {e}")
        error(traceback.format_exc())
        return False

# -------------------------
# Progress Management
# -------------------------
def load_progress() -> Tuple[int, int]:
    if not os.path.exists(PROGRESS_FILE):
        return 0, TARGET_PAGE_SIZE
    
    try:
        with open(PROGRESS_FILE, 'r') as f:
            data = json.load(f)
            return data.get('next_offset', 0), data.get('page_size', TARGET_PAGE_SIZE)
    except Exception:
        return 0, TARGET_PAGE_SIZE

def save_progress(offset: int, page_size: int, total_customers: int):
    try:
        os.makedirs(OUTPUT_PATH, exist_ok=True)
        data = {
            'next_offset': offset,
            'page_size': page_size,
            'total_customers': total_customers,
            'timestamp': datetime.now().isoformat()
        }
        with open(PROGRESS_FILE, 'w') as f:
            json.dump(data, f, indent=2)
    except Exception:
        pass

def calculate_api_page(offset: int, page_size: int) -> int:
    return (offset // page_size) + 1

# -------------------------
# Adaptive Page Sizing
# -------------------------
class PageSizeManager:
    def __init__(self):
        self.current_size = TARGET_PAGE_SIZE
        self.consecutive_successes = 0
        self.retry_index = 0
    
    def record_success(self):
        self.consecutive_successes += 1
        if self.consecutive_successes >= SUCCESS_THRESHOLD and self.retry_index > 0:
            self.retry_index = max(0, self.retry_index - 1)
            self.current_size = RETRY_SIZES[self.retry_index]
            self.consecutive_successes = 0
    
    def record_failure(self) -> Optional[int]:
        self.consecutive_successes = 0
        if self.retry_index < len(RETRY_SIZES) - 1:
            self.retry_index += 1
            self.current_size = RETRY_SIZES[self.retry_index]
            return self.current_size
        else:
            return None
    
    def get_current_size(self) -> int:
        return self.current_size

# -------------------------
# Main Fetch Logic
# -------------------------
def fetch_customers(spark):
    """Memory-safe sequential fetch with comprehensive field extraction"""
    
    try:
        token = get_access_token()
    except Exception as e:
        error(f"Failed to get token: {e}")
        return
    
    # Clear bronze table for full refresh (balances are current state)
    info("Clearing bronze table for full refresh...")
    try:
        spark.sql(f"DELETE FROM {BRONZE_CUSTOMERS_PATH}")
        info("✓ Bronze table cleared")
    except Exception as e:
        warn(f"Could not clear table (may not exist yet): {e}")
    
    session = requests.Session()
    session.headers.update({
        "Authorization": f"Bearer {token}",
        "Accept": "text/xml, application/xml",
        "Content-Type": "text/xml; charset=utf-8"
    })
    
    # Always start from beginning (full refresh)
    current_offset = 0
    
    # Always start with TARGET_PAGE_SIZE
    psm = PageSizeManager()
    psm.current_size = TARGET_PAGE_SIZE
    
    info(f"Starting full refresh from offset 0")
    info(f"Page size: {TARGET_PAGE_SIZE}")
    info(f"Memory-safe mode: Will flush batch when customers exceed {MAX_BATCH_CUSTOMERS:,}")
    info(f"Comprehensive extraction: Status, Balances, Contact Info, Credit, etc.")
    
    consecutive_empty = 0
    total_customers = 0
    iteration = 0
    
    # Batch accumulators
    batch_customers = []
    batch_count = 0
    
    start_time = time.time()
    
    while True:
        iteration += 1
        
        if consecutive_empty >= 3:
            # Flush remaining batch
            if batch_customers:
                info(f"Flushing final batch: {len(batch_customers):,} customers")
                write_batch_to_bronze(spark, batch_customers)
            info(f"Complete: {total_customers:,} customers")
            break
        
        page_size = psm.get_current_size()
        api_page = calculate_api_page(current_offset, page_size)
        body = build_get_customers_request(api_page, page_size)
        
        # Fetch
        try:
            resp = session.post(SERVICE_ENDPOINT, data=body, timeout=HTTP_TIMEOUT)
            
            if resp.status_code != 200:
                error(f"HTTP {resp.status_code} at page {api_page}")
                next_size = psm.record_failure()
                if not next_size:
                    return
                time.sleep(2)
                continue
            
            if 'soap:Fault' in resp.text:
                error(f"SOAP fault at page {api_page}")
                next_size = psm.record_failure()
                if not next_size:
                    return
                time.sleep(2)
                continue
            
        except Exception as e:
            error(f"Request error: {e}")
            next_size = psm.record_failure()
            if not next_size:
                return
            time.sleep(2)
            continue
        
        # Parse
        customers = parse_customers(resp.text)
        
        if not customers:
            consecutive_empty += 1
            current_offset += page_size
            continue
        
        consecutive_empty = 0
        
        # MEMORY-SAFE: Check if this page would push us over limit
        if len(batch_customers) > 0 and len(batch_customers) + len(customers) > MAX_BATCH_CUSTOMERS and batch_count >= MIN_BATCH_PAGES:
            # Flush current batch before adding this large page
            info(f"🔄 Flushing batch ({len(batch_customers):,} customers) before adding {len(customers):,} customer page")
            success = write_batch_to_bronze(spark, batch_customers)
            if not success:
                error("Batch write failed")
                return
            
            batch_customers = []
            batch_count = 0
        
        # Accumulate in batch
        batch_customers.extend(customers)
        batch_count += 1
        
        total_customers += len(customers)
        current_offset += len(customers)
        
        # MEMORY-SAFE: Also check total customers in batch
        if len(batch_customers) >= MAX_BATCH_CUSTOMERS and batch_count >= MIN_BATCH_PAGES:
            info(f"✓ Writing batch: {len(batch_customers):,} customers")
            success = write_batch_to_bronze(spark, batch_customers)
            if not success:
                error("Batch write failed")
                return
            
            # Log progress
            if iteration % LOG_INTERVAL == 0:
                elapsed = time.time() - start_time
                rate = total_customers / elapsed if elapsed > 0 else 0
                info(f"Progress: offset {current_offset:,} | {total_customers:,} customers | {rate:.1f} cust/sec")
            
            # Clear batch
            batch_customers = []
            batch_count = 0
        
        psm.record_success()
    
    # No need to save progress - we always do full refresh
    
    elapsed = time.time() - start_time
    rate = total_customers / elapsed if elapsed > 0 else 0
    info(f"\n" + "="*70)
    info(f"Runtime: {elapsed:.1f}s ({elapsed/60:.1f} min)")
    info(f"Average rate: {rate:.1f} customers/sec")
    info("="*70)

# -------------------------
# Main
# -------------------------
def main():
    VERSION = "1.2"
    info("="*70)
    info(f"Workday Customers Fetcher v{VERSION} - Comprehensive Field Extraction")
    info("="*70)
    
    if not HAS_SPARK:
        error("PySpark not available")
        return
    
    try:
        spark = SparkSession.getActiveSession()
        if not spark:
            error("No active Spark session")
            return
        info("✓ Spark session ready")
        spark.conf.set("spark.sql.adaptive.enabled", "true")
        spark.conf.set("spark.databricks.delta.optimizeWrite.enabled", "true")
        spark.conf.set("spark.databricks.delta.autoCompact.enabled", "true")
    except Exception as e:
        error(f"Spark error: {e}")
        return
    
    try:
        fetch_customers(spark)
    except KeyboardInterrupt:
        warn("\nInterrupted by user")
    except Exception as e:
        error(f"\nFatal error: {e}")
        error(traceback.format_exc())
        raise

if __name__ == "__main__":
    main()

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

"""
Workday Customer Invoices Fetcher
VERSION: 1.2 (December 16, 2025)

FEATURES:
- Extracts ALL customer invoices from Workday Revenue_Management SOAP API
- Comprehensive field extraction: amounts, dates, status, customer info, PO numbers
- Memory-safe batching (10k invoices max per batch)
- Adaptive page sizing (target=100)
- Progress tracking with resume capability
- OAuth2 JWT authentication
"""

import requests
import json
import time
import jwt
import os
from datetime import datetime, timezone
from lxml import etree
from pyspark.sql import SparkSession
from pyspark.sql.types import *

# ===========================
# CONFIGURATION
# ===========================

HOST = "services1.wd503.myworkday.com"
TENANT = "stevenstransport"
CLIENT_ID = "N2ZkZWI1YjktOWM4Ni00ZDI2LTg0MzItNmY5YWMwMGMzYTUx"
ISU = "ISU_Ms_Fabric"
RM_VERSION = "v45.0"

# Paths
KEY_FILE_PATHS = [
    "/lakehouse/data_central_lh/Files/workday_integration.key",
    "/lakehouse/default/Files/workday_integration.key"
]
PROGRESS_FILE = "/lakehouse/default/Files/workday_invoices/invoice_progress.json"
BRONZE_INVOICES_PATH = "data_central_lh.workday_invoices_bronze"

# Fetch parameters
TARGET_PAGE_SIZE = 100
MAX_BATCH_INVOICES = 10000
PROGRESS_SAVE_INTERVAL = 5
HTTP_TIMEOUT = 120

# XML Namespaces
NS = {"wd": f"urn:com.workday/bsvc"}

# ===========================
# HELPER FUNCTIONS
# ===========================

def info(msg):
    print(f"[INFO] {msg}")

def warn(msg):
    print(f"[WARN] {msg}")

def error(msg):
    print(f"[ERROR] {msg}")

def get_text(parent, tag):
    """Get text from child element"""
    try:
        el = parent.find(f"wd:{tag}", NS)
        return el.text.strip() if el is not None and el.text else None
    except:
        return None

def id_text_by_type(parent, xpath, id_type='WID'):
    """Extract ID text by type attribute"""
    try:
        for id_elem in parent.findall(xpath, NS):
            type_attr = id_elem.get(f'{{{NS["wd"]}}}type')
            if not type_attr:
                type_attr = id_elem.get('type')
            if type_attr == id_type:
                return id_elem.text.strip() if id_elem.text else None
        return None
    except:
        return None

def get_decimal(parent, tag):
    """Get decimal value"""
    text = get_text(parent, tag)
    if text:
        try:
            return float(text)
        except:
            pass
    return None

def get_date(parent, tag):
    """Get date value"""
    text = get_text(parent, tag)
    if text:
        try:
            return datetime.fromisoformat(text.replace('Z', '+00:00')).strftime('%Y-%m-%d')
        except:
            pass
    return None

# ===========================
# AUTHENTICATION
# ===========================

def get_access_token():
    """Get OAuth2 JWT access token"""
    # Try multiple key file paths
    private_key = None
    for key_path in KEY_FILE_PATHS:
        try:
            with open(key_path, 'r') as f:
                private_key = f.read()
            info(f"✓ Found key file: {key_path}")
            break
        except FileNotFoundError:
            continue
    
    if not private_key:
        raise FileNotFoundError(f"Private key not found. Tried: {KEY_FILE_PATHS}")
    
    token_endpoint = f"https://{HOST}/ccx/oauth2/{TENANT}/token"
    
    now = int(time.time())
    claims = {
        "iss": CLIENT_ID,
        "sub": ISU,
        "aud": token_endpoint,
        "iat": now,
        "exp": now + 300
    }
    
    assertion = jwt.encode(claims, private_key, algorithm='RS256')
    if isinstance(assertion, bytes):
        assertion = assertion.decode('utf-8')
    
    headers = {"Content-Type": "application/x-www-form-urlencoded"}
    data = {
        "grant_type": "urn:ietf:params:oauth:grant-type:jwt-bearer",
        "assertion": assertion
    }
    
    resp = requests.post(token_endpoint, headers=headers, data=data, timeout=HTTP_TIMEOUT)
    
    if resp.status_code != 200:
        error(f"Token request failed {resp.status_code}: {resp.text[:1000]}")
        resp.raise_for_status()
    
    return resp.json()['access_token']

# ===========================
# SOAP REQUEST
# ===========================

def build_soap_request(page_number, page_size):
    """Build SOAP request for Get_Customer_Invoices"""
    soap = (
        '<?xml version="1.0" encoding="UTF-8"?>'
        '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:wd="urn:com.workday/bsvc">'
        "<soapenv:Header/>"
        "<soapenv:Body>"
        f'<wd:Get_Customer_Invoices_Request wd:version="{RM_VERSION}">'
        "<wd:Response_Filter>"
        f"<wd:Page>{page_number}</wd:Page>"
        f"<wd:Count>{page_size}</wd:Count>"
        "</wd:Response_Filter>"
        "</wd:Get_Customer_Invoices_Request>"
        "</soapenv:Body></soapenv:Envelope>"
    )
    return soap.encode("utf-8")

# ===========================
# PROGRESS MANAGEMENT
# ===========================

def load_progress():
    """Load progress from file"""
    try:
        os.makedirs(os.path.dirname(PROGRESS_FILE), exist_ok=True)
        with open(PROGRESS_FILE, 'r') as f:
            data = json.load(f)
            return data.get('offset', 0), data.get('page_size', TARGET_PAGE_SIZE)
    except:
        return 0, TARGET_PAGE_SIZE

def save_progress(offset, page_size, total_invoices):
    """Save progress to file"""
    try:
        os.makedirs(os.path.dirname(PROGRESS_FILE), exist_ok=True)
        with open(PROGRESS_FILE, 'w') as f:
            json.dump({
                'offset': offset,
                'page_size': page_size,
                'total_invoices': total_invoices,
                'last_updated': datetime.now(timezone.utc).isoformat()
            }, f, indent=2)
    except Exception as e:
        warn(f"Could not save progress: {e}")

# ===========================
# PAGE SIZE MANAGER
# ===========================

class PageSizeManager:
    def __init__(self):
        self.current_size = TARGET_PAGE_SIZE
        self.consecutive_failures = 0
        
    def get_current_size(self):
        return self.current_size
    
    def record_failure(self):
        self.consecutive_failures += 1
        if self.consecutive_failures >= 2 and self.current_size > 25:
            old_size = self.current_size
            self.current_size = max(25, self.current_size // 2)
            warn(f"Reducing page size: {old_size} → {self.current_size}")
        return self.current_size
    
    def record_success(self):
        self.consecutive_failures = 0

# ===========================
# XML PARSING
# ===========================

def parse_invoices(xml_text):
    """Parse invoice XML response"""
    try:
        root = etree.fromstring(xml_text.encode('utf-8'))
    except Exception as e:
        error(f"XML parse error: {e}")
        return []
    
    invoices = []
    
    for inv_elem in root.findall('.//wd:Customer_Invoice', NS):
        try:
            invoice = {}
            
            # References
            inv_ref = inv_elem.find('./wd:Customer_Invoice_Reference', NS)
            if inv_ref is not None:
                invoice['invoice_wid'] = id_text_by_type(inv_ref, './wd:ID', 'WID')
                invoice['invoice_id'] = id_text_by_type(inv_ref, './wd:ID', 'Customer_Invoice_ID')
            
            # Get Customer_Invoice_Data
            inv_data = inv_elem.find('./wd:Customer_Invoice_Data', NS)
            if inv_data is None:
                continue
            
            # Basic fields
            invoice['customer_invoice_id'] = get_text(inv_data, 'Customer_Invoice_ID')
            invoice['invoice_number'] = get_text(inv_data, 'Invoice_Number')
            invoice['gapless_invoice_number'] = get_text(inv_data, 'Gapless_Invoice_Number')
            
            # Dates
            invoice['invoice_date'] = get_date(inv_data, 'Invoice_Date')
            invoice['due_date'] = get_date(inv_data, 'Due_Date_Override')
            invoice['accounting_date'] = get_date(inv_data, 'Accounting_Date')
            invoice['from_date'] = get_date(inv_data, 'From_Date')
            invoice['to_date'] = get_date(inv_data, 'To_Date')
            
            # Company
            comp_ref = inv_data.find('./wd:Company_Reference', NS)
            if comp_ref is not None:
                invoice['company_id'] = id_text_by_type(comp_ref, './wd:ID', 'Company_Reference_ID')
                invoice['company_name'] = comp_ref.get('Descriptor')
            
            # Currency
            curr_ref = inv_data.find('./wd:Currency_Reference', NS)
            if curr_ref is not None:
                invoice['currency'] = id_text_by_type(curr_ref, './wd:ID', 'Currency_ID')
            
            # Customers
            sold_to_ref = inv_data.find('./wd:Sold_To_Customer_Reference', NS)
            if sold_to_ref is not None:
                invoice['sold_to_customer_id'] = id_text_by_type(sold_to_ref, './wd:ID', 'Customer_ID')
                invoice['sold_to_customer_name'] = sold_to_ref.get('Descriptor')
            
            bill_to_ref = inv_data.find('./wd:Bill_To_Customer_Reference', NS)
            if bill_to_ref is not None:
                invoice['bill_to_customer_id'] = id_text_by_type(bill_to_ref, './wd:ID', 'Customer_ID')
                invoice['bill_to_customer_name'] = bill_to_ref.get('Descriptor')
            
            # Project
            proj_ref = inv_data.find('./wd:Billable_Project_Reference', NS)
            if proj_ref is not None:
                invoice['project_id'] = id_text_by_type(proj_ref, './wd:ID')
                invoice['project_name'] = proj_ref.get('Descriptor')
            
            # Amounts
            invoice['control_amount_total'] = get_decimal(inv_data, 'Control_Amount_Total')
            invoice['amount_due'] = get_decimal(inv_data, 'Amount_Due')
            
            # Status and Type
            invoice['payment_status'] = get_text(inv_data, 'Payment_Status')
            invoice['document_status'] = get_text(inv_data, 'Document_Status')
            
            inv_type_ref = inv_data.find('./wd:Customer_Invoice_Type_Reference', NS)
            if inv_type_ref is not None:
                invoice['invoice_type'] = id_text_by_type(inv_type_ref, './wd:ID')
                invoice['invoice_type_name'] = inv_type_ref.get('Descriptor')
            
            # Payment Terms
            terms_ref = inv_data.find('./wd:Payment_Terms_Reference', NS)
            if terms_ref is not None:
                invoice['payment_terms'] = id_text_by_type(terms_ref, './wd:ID')
                invoice['payment_terms_name'] = terms_ref.get('Descriptor')
            
            # Additional fields
            invoice['po_number'] = get_text(inv_data, 'PO_Number')
            invoice['reference_number'] = get_text(inv_data, 'Reference_Number')
            invoice['memo'] = get_text(inv_data, 'Memo')
            
            # Collection info
            invoice['collection_date'] = get_date(inv_data, 'Collection_Date')
            invoice['payment_amount_promised'] = get_decimal(inv_data, 'Payment_Amount_Promised')
            invoice['dispute_date'] = get_date(inv_data, 'Dispute_Date')
            invoice['dispute_amount'] = get_decimal(inv_data, 'Dispute_Amount')
            invoice['followup_date'] = get_date(inv_data, 'Followup_Date')
            
            # Submit flag
            invoice['submit'] = get_text(inv_data, 'Submit')
            invoice['locked_in_workday'] = get_text(inv_data, 'Locked_in_Workday')
            
            invoices.append(invoice)
            
        except Exception as e:
            warn(f"Error parsing invoice: {e}")
            continue
    
    return invoices

# ===========================
# DELTA TABLE OPERATIONS
# ===========================

def get_schema():
    """Define schema for invoices bronze table"""
    return StructType([
        StructField("invoice_wid", StringType(), True),
        StructField("invoice_id", StringType(), True),
        StructField("customer_invoice_id", StringType(), True),
        StructField("invoice_number", StringType(), True),
        StructField("gapless_invoice_number", StringType(), True),
        StructField("invoice_date", StringType(), True),
        StructField("due_date", StringType(), True),
        StructField("accounting_date", StringType(), True),
        StructField("from_date", StringType(), True),
        StructField("to_date", StringType(), True),
        StructField("company_id", StringType(), True),
        StructField("company_name", StringType(), True),
        StructField("currency", StringType(), True),
        StructField("sold_to_customer_id", StringType(), True),
        StructField("sold_to_customer_name", StringType(), True),
        StructField("bill_to_customer_id", StringType(), True),
        StructField("bill_to_customer_name", StringType(), True),
        StructField("project_id", StringType(), True),
        StructField("project_name", StringType(), True),
        StructField("control_amount_total", DoubleType(), True),
        StructField("amount_due", DoubleType(), True),
        StructField("payment_status", StringType(), True),
        StructField("document_status", StringType(), True),
        StructField("invoice_type", StringType(), True),
        StructField("invoice_type_name", StringType(), True),
        StructField("payment_terms", StringType(), True),
        StructField("payment_terms_name", StringType(), True),
        StructField("po_number", StringType(), True),
        StructField("reference_number", StringType(), True),
        StructField("memo", StringType(), True),
        StructField("collection_date", StringType(), True),
        StructField("payment_amount_promised", DoubleType(), True),
        StructField("dispute_date", StringType(), True),
        StructField("dispute_amount", DoubleType(), True),
        StructField("followup_date", StringType(), True),
        StructField("submit", StringType(), True),
        StructField("locked_in_workday", StringType(), True),
    ])

def write_to_delta(spark, invoices):
    """Write invoices to Delta table"""
    if not invoices:
        return
    
    schema = get_schema()
    df = spark.createDataFrame(invoices, schema)
    df.write.format("delta").mode("append").saveAsTable(BRONZE_INVOICES_PATH)
    info(f"Wrote {len(invoices)} invoices to Delta")

# ===========================
# MAIN FETCH LOGIC
# ===========================

def fetch_invoices(spark):
    """Memory-safe sequential fetch with progress tracking"""
    
    try:
        token = get_access_token()
    except Exception as e:
        error(f"Failed to get token: {e}")
        return
    
    session = requests.Session()
    session.headers.update({
        "Authorization": f"Bearer {token}",
        "Accept": "text/xml, application/xml",
        "Content-Type": "text/xml; charset=utf-8"
    })
    
    current_offset, saved_page_size = load_progress()
    
    psm = PageSizeManager()
    psm.current_size = TARGET_PAGE_SIZE
    
    info(f"Starting from offset {current_offset:,}")
    info(f"Page size reset to {TARGET_PAGE_SIZE} (ignoring saved size {saved_page_size})")
    info(f"Memory-safe mode: Will flush batch when invoices exceed {MAX_BATCH_INVOICES:,}")
    
    endpoint = f"https://{HOST}/ccx/service/{TENANT}/Revenue_Management/{RM_VERSION}"
    
    total_invoices = 0
    batch_invoices = []
    batch_count = 0
    consecutive_empty = 0
    iteration = 0
    start_time = time.time()
    
    while True:
        iteration += 1
        page_number = (current_offset // psm.get_current_size()) + 1
        page_size = psm.get_current_size()
        
        soap_body = build_soap_request(page_number, page_size)
        
        try:
            resp = session.post(endpoint, data=soap_body, timeout=120)
            
            if resp.status_code != 200:
                error(f"HTTP {resp.status_code}")
                error(f"Response: {resp.text[:1500]}")
                psm.record_failure()
                continue
        
        except Exception as e:
            warn(f"Request error: {e}")
            psm.record_failure()
            continue
        
        # Parse
        invoices = parse_invoices(resp.text)
        
        if not invoices:
            consecutive_empty += 1
            if consecutive_empty >= 3:
                info("No more invoices found (3 consecutive empty pages)")
                break
            current_offset += page_size
            continue
        
        consecutive_empty = 0
        info(f"Fetched {len(invoices)} invoices (offset {current_offset:,})")
        
        # Add to batch
        batch_invoices.extend(invoices)
        batch_count += len(invoices)
        total_invoices += len(invoices)
        current_offset += len(invoices)
        
        # Flush if batch too large
        if batch_count >= MAX_BATCH_INVOICES:
            info(f"Flushing batch: {batch_count:,} invoices")
            write_to_delta(spark, batch_invoices)
            batch_invoices = []
            batch_count = 0
        
        # Save progress periodically
        if iteration % PROGRESS_SAVE_INTERVAL == 0:
            save_progress(current_offset, psm.get_current_size(), total_invoices)
        
        psm.record_success()
    
    # Flush final batch
    if batch_invoices:
        info(f"Flushing final batch: {batch_count:,} invoices")
        write_to_delta(spark, batch_invoices)
    
    # Final progress save
    save_progress(current_offset, psm.get_current_size(), total_invoices)
    
    elapsed = time.time() - start_time
    info(f"Complete: {total_invoices:,} invoices")
    info("="*70)
    info(f"Runtime: {elapsed:.1f}s ({elapsed/60:.1f} min)")
    if total_invoices > 0:
        info(f"Average rate: {total_invoices/elapsed:.1f} invoices/sec")
    info("="*70)

# ===========================
# MAIN
# ===========================

def main():
    VERSION = "1.2"
    info("="*70)
    info(f"Workday Invoices Fetcher v{VERSION} - Comprehensive Field Extraction")
    info("="*70)
    
    spark = SparkSession.builder.getOrCreate()
    info("✓ Spark session ready")
    
    try:
        fetch_invoices(spark)
    except KeyboardInterrupt:
        warn("\nInterrupted by user")
        return
    except Exception as e:
        error(f"Fatal error: {e}")
        import traceback
        traceback.print_exc()
        raise

if __name__ == "__main__":
    main()

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

df = spark.sql("""
    SELECT * 
    FROM data_central_lh.workday_journal_lines_bronze 
    ORDER BY journal_wid DESC 
    LIMIT 100
""")
display(df)

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

"""
Workday Customer Payments Fetcher - Enhanced for Analysis
VERSION: 2.3 (January 22, 2025)

FEATURES:
- Extracts customer payments from Workday Revenue_Management SOAP API
- *** PAYMENT APPLICATIONS: Links payments to invoices via remittance advice ***
- Comprehensive field extraction for Microsoft Fabric analysis
- TWO output tables:
  * workday_customer_payments_bronze (payment headers)
  * workday_customer_payment_applications_bronze (invoice applications)
- SMART INCREMENTAL MODE: Auto-detects last run, catches up automatically
  * Checks table for last extracted_timestamp
  * Pulls from last run date minus safety buffer
  * Handles missed runs (catches up regardless of days missed)
  * NO DUPLICATES: Dedup + MERGE ensures unique records
- FULL REFRESH MODE: Rebuild entire table from scratch
- Memory-safe batching (10k payments max per batch)
- Adaptive page sizing (target=100)
- Progress tracking with resume capability
- OAuth2 JWT authentication
"""

import requests
import json
import time
import jwt
import os
from datetime import datetime, timezone, timedelta
from lxml import etree
from pyspark.sql import SparkSession
from pyspark.sql.types import *

# ===========================
# CONFIGURATION
# ===========================

HOST = "services1.wd503.myworkday.com"
TENANT = "stevenstransport"
CLIENT_ID = "N2ZkZWI1YjktOWM4Ni00ZDI2LTg0MzItNmY5YWMwMGMzYTUx"
ISU = "ISU_Ms_Fabric"
RM_VERSION = "v45.0"

# RUN MODE
INCREMENTAL_MODE = True  # True = daily incremental (auto-detects last run), False = full refresh
INCREMENTAL_LOOKBACK_DAYS = 7  # Safety buffer: go back N extra days from last run to catch updates

# Date range (only used if INCREMENTAL_MODE = False)
FULL_REFRESH_START_DATE = "2020-01-01"  # For full refresh mode only

# Paths
KEY_FILE_PATHS = [
    "/lakehouse/data_central_lh/Files/workday_integration.key",
    "/lakehouse/default/Files/workday_integration.key"
]
PROGRESS_FILE = "/lakehouse/default/Files/workday_payments/payment_progress.json"
BRONZE_PAYMENTS_PATH = "data_central_lh.workday_customer_payments_bronze"
BRONZE_APPLICATIONS_PATH = "data_central_lh.workday_customer_payment_applications_bronze"

# Fetch parameters
TARGET_PAGE_SIZE = 100
MAX_BATCH_PAYMENTS = 10000
PROGRESS_SAVE_INTERVAL = 5
HTTP_TIMEOUT = 120

# XML Namespaces
NS = {"wd": f"urn:com.workday/bsvc"}

# ===========================
# HELPER FUNCTIONS
# ===========================

def info(msg):
    print(f"[INFO] {msg}")

def warn(msg):
    print(f"[WARN] {msg}")

def error(msg):
    print(f"[ERROR] {msg}")

def get_text(parent, tag):
    """Get text from child element"""
    try:
        el = parent.find(f"wd:{tag}", NS)
        return el.text.strip() if el is not None and el.text else None
    except:
        return None

def id_text_by_type(parent, xpath, id_type='WID'):
    """Extract ID text by type attribute"""
    try:
        for id_elem in parent.findall(xpath, NS):
            type_attr = id_elem.get(f'{{{NS["wd"]}}}type')
            if not type_attr:
                type_attr = id_elem.get('type')
            if type_attr == id_type:
                return id_elem.text.strip() if id_elem.text else None
        return None
    except:
        return None

def get_decimal(parent, tag):
    """Get decimal value"""
    text = get_text(parent, tag)
    if text:
        try:
            return float(text)
        except:
            pass
    return None

def get_date(parent, tag):
    """Get date value"""
    text = get_text(parent, tag)
    if text:
        try:
            return datetime.fromisoformat(text.replace('Z', '+00:00')).strftime('%Y-%m-%d')
        except:
            pass
    return None

def get_boolean(parent, tag):
    """Get boolean value"""
    text = get_text(parent, tag)
    if text:
        return text == '1' or text.lower() == 'true'
    return None

# ===========================
# AUTHENTICATION
# ===========================

def get_access_token():
    """Get OAuth2 JWT access token"""
    # Try multiple key file paths
    private_key = None
    for key_path in KEY_FILE_PATHS:
        try:
            with open(key_path, 'r') as f:
                private_key = f.read()
            info(f"✓ Found key file: {key_path}")
            break
        except FileNotFoundError:
            continue
    
    if not private_key:
        raise FileNotFoundError(f"Private key not found. Tried: {KEY_FILE_PATHS}")
    
    token_endpoint = f"https://{HOST}/ccx/oauth2/{TENANT}/token"
    
    now = int(time.time())
    claims = {
        "iss": CLIENT_ID,
        "sub": ISU,
        "aud": token_endpoint,
        "iat": now,
        "exp": now + 300
    }
    
    assertion = jwt.encode(claims, private_key, algorithm='RS256')
    if isinstance(assertion, bytes):
        assertion = assertion.decode('utf-8')
    
    headers = {"Content-Type": "application/x-www-form-urlencoded"}
    data = {
        "grant_type": "urn:ietf:params:oauth:grant-type:jwt-bearer",
        "assertion": assertion
    }
    
    resp = requests.post(token_endpoint, headers=headers, data=data, timeout=HTTP_TIMEOUT)
    
    if resp.status_code != 200:
        error(f"Token request failed {resp.status_code}: {resp.text[:1000]}")
        resp.raise_for_status()
    
    return resp.json()['access_token']

# ===========================
# SOAP REQUEST
# ===========================

def build_soap_request(page_number, page_size, from_date=None, to_date=None):
    """Build SOAP request for Get_Customer_Payments with date range filter"""
    
    # Default date range: last 5 years to today
    if not from_date:
        from_date = "2020-01-01"
    if not to_date:
        to_date = datetime.now().strftime("%Y-%m-%d")
    
    soap = (
        '<?xml version="1.0" encoding="UTF-8"?>'
        '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:wd="urn:com.workday/bsvc">'
        "<soapenv:Header/>"
        "<soapenv:Body>"
        f'<wd:Get_Customer_Payments_Request wd:version="{RM_VERSION}">'
        "<wd:Request_Criteria>"
        f"<wd:Payment_Date_On_or_After>{from_date}</wd:Payment_Date_On_or_After>"
        f"<wd:Payment_Date_On_or_Before>{to_date}</wd:Payment_Date_On_or_Before>"
        "</wd:Request_Criteria>"
        "<wd:Response_Filter>"
        f"<wd:Page>{page_number}</wd:Page>"
        f"<wd:Count>{page_size}</wd:Count>"
        "</wd:Response_Filter>"
        "</wd:Get_Customer_Payments_Request>"
        "</soapenv:Body></soapenv:Envelope>"
    )
    return soap.encode("utf-8")

# ===========================
# PROGRESS MANAGEMENT
# ===========================

def load_progress():
    """Load progress from file"""
    try:
        os.makedirs(os.path.dirname(PROGRESS_FILE), exist_ok=True)
        with open(PROGRESS_FILE, 'r') as f:
            data = json.load(f)
            return data.get('offset', 0), data.get('page_size', TARGET_PAGE_SIZE)
    except:
        return 0, TARGET_PAGE_SIZE

def save_progress(offset, page_size, total_payments):
    """Save progress to file"""
    try:
        os.makedirs(os.path.dirname(PROGRESS_FILE), exist_ok=True)
        with open(PROGRESS_FILE, 'w') as f:
            json.dump({
                'offset': offset,
                'page_size': page_size,
                'total_payments': total_payments,
                'last_updated': datetime.now(timezone.utc).isoformat()
            }, f, indent=2)
    except Exception as e:
        warn(f"Could not save progress: {e}")

# ===========================
# PAGE SIZE MANAGER
# ===========================

class PageSizeManager:
    def __init__(self):
        self.current_size = TARGET_PAGE_SIZE
        self.consecutive_failures = 0
        
    def get_current_size(self):
        return self.current_size
    
    def record_failure(self):
        self.consecutive_failures += 1
        if self.consecutive_failures >= 2 and self.current_size > 25:
            old_size = self.current_size
            self.current_size = max(25, self.current_size // 2)
            warn(f"Reducing page size: {old_size} → {self.current_size}")
        return self.current_size
    
    def record_success(self):
        self.consecutive_failures = 0

# ===========================
# XML PARSING
# ===========================

def parse_payments(xml_text):
    """Parse payment XML response - returns (payments, applications)"""
    try:
        root = etree.fromstring(xml_text.encode('utf-8'))
    except Exception as e:
        error(f"XML parse error: {e}")
        return [], []
    
    payments = []
    applications = []
    
    for pmt_elem in root.findall('.//wd:Customer_Payment', NS):
        try:
            payment = {}
            
            # References
            pmt_ref = pmt_elem.find('./wd:Customer_Payment_Reference', NS)
            if pmt_ref is not None:
                payment['payment_wid'] = id_text_by_type(pmt_ref, './wd:ID', 'WID')
                payment['payment_id'] = id_text_by_type(pmt_ref, './wd:ID', 'Customer_Payment_ID')
            
            # Get Customer_Payment_Data
            pmt_data = pmt_elem.find('./wd:Customer_Payment_Data', NS)
            if pmt_data is None:
                continue
            
            # Basic fields
            payment['payment_reference_id'] = get_text(pmt_data, 'Customer_Payment_for_Invoices_Reference_ID')
            payment['locked_in_workday'] = get_boolean(pmt_data, 'Locked_in_Workday')
            
            # Company
            comp_ref = pmt_data.find('./wd:Company_Reference', NS)
            if comp_ref is not None:
                payment['company_id'] = id_text_by_type(comp_ref, './wd:ID', 'Company_Reference_ID')
                payment['company_name'] = comp_ref.get('Descriptor')
            
            # Currency
            curr_ref = pmt_data.find('./wd:Payment_Currency_Reference', NS)
            if curr_ref is not None:
                payment['currency'] = id_text_by_type(curr_ref, './wd:ID', 'Currency_ID')
                payment['currency_name'] = curr_ref.get('Descriptor')
            
            # Payment Date
            payment['payment_date'] = get_date(pmt_data, 'Payment_Date')
            
            # Payment Type
            pmt_type_ref = pmt_data.find('./wd:Payment_Type_Reference', NS)
            if pmt_type_ref is not None:
                payment['payment_type'] = id_text_by_type(pmt_type_ref, './wd:ID')
                payment['payment_type_name'] = pmt_type_ref.get('Descriptor')
            
            # Payment Amounts
            payment['payment_amount'] = get_decimal(pmt_data, 'Payment_Amount')
            payment['unapplied_amount'] = get_decimal(pmt_data, 'Unapplied_Amount')
            
            # Customer (Remit-From)
            customer_ref = pmt_data.find('./wd:Remit-From_Customer_Reference', NS)
            if customer_ref is not None:
                payment['customer_id'] = id_text_by_type(customer_ref, './wd:ID', 'Customer_ID')
                payment['customer_name'] = customer_ref.get('Descriptor')
            
            # Bank Account
            bank_ref = pmt_data.find('./wd:Bank_Account_Reference', NS)
            if bank_ref is not None:
                payment['bank_account_id'] = id_text_by_type(bank_ref, './wd:ID')
                payment['bank_account_name'] = bank_ref.get('Descriptor')
            
            # Check/Reference Numbers
            payment['check_number'] = get_text(pmt_data, 'Check_Number')
            payment['reference_number'] = get_text(pmt_data, 'Reference_Number')
            
            # Payment Memo
            payment['payment_memo'] = get_text(pmt_data, 'Payment_Memo')
            
            # Flags
            payment['ready_to_auto_apply'] = get_boolean(pmt_data, 'Ready_to_Auto-Apply')
            payment['do_not_apply_to_invoices_on_hold'] = get_boolean(pmt_data, 'Do_Not_Apply_Payment_to_Invoices_on_Hold')
            payment['show_only_matched_invoices'] = get_boolean(pmt_data, 'Show_Only_Matched_Invoices_when_Applying')
            
            # Electronic File Information
            elec_file = pmt_data.find('./wd:Electronic_File_Information_Data', NS)
            if elec_file is not None:
                payment['electronic_file_name'] = get_text(elec_file, 'Electronic_File_Name')
                payment['electronic_file_date'] = get_date(elec_file, 'Electronic_File_Date')
            
            # Customer Deposit Reference (if applicable)
            deposit_ref = pmt_data.find('./wd:Customer_Deposit_Reference', NS)
            if deposit_ref is not None:
                payment['customer_deposit_wid'] = id_text_by_type(deposit_ref, './wd:ID', 'WID')
                payment['customer_deposit_id'] = id_text_by_type(deposit_ref, './wd:ID', 'Customer_Deposit_ID')
            
            # Receivables Reason (On-Account)
            reason_ref = pmt_data.find('./wd:Receivables_Reason_Reference', NS)
            if reason_ref is not None:
                payment['receivables_reason_id'] = id_text_by_type(reason_ref, './wd:ID')
                payment['receivables_reason_name'] = reason_ref.get('Descriptor')
            payment['receivables_reason_description'] = get_text(pmt_data, 'Receivables_Reason_Description')
            
            # Status/Processing info
            payment['payment_status'] = get_text(pmt_data, 'Payment_Status')
            payment['submit'] = get_boolean(pmt_data, 'Submit')
            
            # Extraction timestamp
            payment['extracted_timestamp'] = datetime.now(timezone.utc).isoformat()
            
            # *** CRITICAL: Parse Remittance Advice (Payment Applications) ***
            remit_advices = pmt_data.findall('./wd:Customer_Payment_Remittance_Advice_Data', NS)
            payment['remittance_advice_count'] = len(remit_advices) if remit_advices else 0
            
            # Extract invoice applications from remittance advice
            for remit_advice in remit_advices:
                # Get remittance advice type
                remit_type_ref = remit_advice.find('./wd:Customer_Payment_Remittance_Advice_Type_Reference', NS)
                remit_type = None
                remit_type_name = None
                if remit_type_ref is not None:
                    remit_type = id_text_by_type(remit_type_ref, './wd:ID')
                    remit_type_name = remit_type_ref.get('Descriptor')
                
                # Find all invoice references in this remittance advice
                invoice_refs = remit_advice.findall('./wd:Customer_Invoice_Reference', NS)
                if invoice_refs:
                    for inv_ref in invoice_refs:
                        app = {}
                        app['payment_wid'] = payment['payment_wid']
                        app['payment_id'] = payment['payment_id']
                        app['payment_date'] = payment['payment_date']
                        app['payment_amount'] = payment['payment_amount']
                        app['customer_id'] = payment.get('customer_id')
                        app['company_id'] = payment.get('company_id')
                        
                        # Invoice reference
                        app['invoice_wid'] = id_text_by_type(inv_ref, './wd:ID', 'WID')
                        app['invoice_id'] = id_text_by_type(inv_ref, './wd:ID', 'Customer_Invoice_ID')
                        app['invoice_descriptor'] = inv_ref.get('Descriptor')
                        
                        # Amount applied to this invoice
                        app['amount_applied'] = get_decimal(remit_advice, 'Amount_to_Pay')
                        app['amount_in_invoice_currency'] = get_decimal(remit_advice, 'Amount_to_Pay_in_Invoice_Currency')
                        
                        # Remittance advice type
                        app['remittance_advice_type'] = remit_type
                        app['remittance_advice_type_name'] = remit_type_name
                        
                        # Bill-to customer (if specified in remittance)
                        billto_ref = remit_advice.find('./wd:Bill-to_Customer_Reference', NS)
                        if billto_ref is not None:
                            app['billto_customer_id'] = id_text_by_type(billto_ref, './wd:ID', 'Customer_ID')
                            app['billto_customer_name'] = billto_ref.get('Descriptor')
                        
                        # Extraction timestamp
                        app['extracted_timestamp'] = datetime.now(timezone.utc).isoformat()
                        
                        applications.append(app)
            
            payments.append(payment)
            
        except Exception as e:
            warn(f"Error parsing payment: {e}")
            import traceback
            traceback.print_exc()
            continue
    
    return payments, applications

# ===========================
# DELTA TABLE OPERATIONS
# ===========================

def get_last_extraction_date(spark):
    """Get the last extraction date from the payments table for incremental runs"""
    try:
        from delta.tables import DeltaTable
        delta_table = DeltaTable.forName(spark, BRONZE_PAYMENTS_PATH)
        
        # Get max extracted_timestamp
        result = spark.sql(f"""
            SELECT MAX(extracted_timestamp) as last_extraction
            FROM {BRONZE_PAYMENTS_PATH}
        """).collect()
        
        if result and result[0]['last_extraction']:
            last_extraction = result[0]['last_extraction']
            # Parse the ISO timestamp and convert to date
            last_date = datetime.fromisoformat(last_extraction.replace('Z', '+00:00'))
            return last_date.strftime('%Y-%m-%d')
        else:
            return None
            
    except Exception as e:
        # Table doesn't exist or is empty
        return None

def get_payment_schema():
    """Define schema for payments bronze table"""
    return StructType([
        StructField("payment_wid", StringType(), True),
        StructField("payment_id", StringType(), True),
        StructField("payment_reference_id", StringType(), True),
        StructField("locked_in_workday", BooleanType(), True),
        StructField("company_id", StringType(), True),
        StructField("company_name", StringType(), True),
        StructField("currency", StringType(), True),
        StructField("currency_name", StringType(), True),
        StructField("payment_date", StringType(), True),
        StructField("payment_type", StringType(), True),
        StructField("payment_type_name", StringType(), True),
        StructField("payment_amount", DoubleType(), True),
        StructField("unapplied_amount", DoubleType(), True),
        StructField("customer_id", StringType(), True),
        StructField("customer_name", StringType(), True),
        StructField("bank_account_id", StringType(), True),
        StructField("bank_account_name", StringType(), True),
        StructField("check_number", StringType(), True),
        StructField("reference_number", StringType(), True),
        StructField("payment_memo", StringType(), True),
        StructField("ready_to_auto_apply", BooleanType(), True),
        StructField("do_not_apply_to_invoices_on_hold", BooleanType(), True),
        StructField("show_only_matched_invoices", BooleanType(), True),
        StructField("electronic_file_name", StringType(), True),
        StructField("electronic_file_date", StringType(), True),
        StructField("customer_deposit_wid", StringType(), True),
        StructField("customer_deposit_id", StringType(), True),
        StructField("receivables_reason_id", StringType(), True),
        StructField("receivables_reason_name", StringType(), True),
        StructField("receivables_reason_description", StringType(), True),
        StructField("payment_status", StringType(), True),
        StructField("submit", BooleanType(), True),
        StructField("remittance_advice_count", IntegerType(), True),
        StructField("extracted_timestamp", StringType(), True),
    ])

def get_application_schema():
    """Define schema for payment applications (invoice links) bronze table"""
    return StructType([
        StructField("payment_wid", StringType(), True),
        StructField("payment_id", StringType(), True),
        StructField("payment_date", StringType(), True),
        StructField("payment_amount", DoubleType(), True),
        StructField("customer_id", StringType(), True),
        StructField("company_id", StringType(), True),
        StructField("invoice_wid", StringType(), True),
        StructField("invoice_id", StringType(), True),
        StructField("invoice_descriptor", StringType(), True),
        StructField("amount_applied", DoubleType(), True),
        StructField("amount_in_invoice_currency", DoubleType(), True),
        StructField("remittance_advice_type", StringType(), True),
        StructField("remittance_advice_type_name", StringType(), True),
        StructField("billto_customer_id", StringType(), True),
        StructField("billto_customer_name", StringType(), True),
        StructField("extracted_timestamp", StringType(), True),
    ])

def write_to_delta(spark, payments, applications, mode='merge'):
    """Write payments and applications to Delta tables with merge capability"""
    from delta.tables import DeltaTable
    
    if payments:
        # DEDUPLICATION: Keep only the most recent version of each payment_wid
        # Group by payment_wid, keep last occurrence (most recent extracted_timestamp)
        unique_payments = {}
        for pmt in payments:
            wid = pmt['payment_wid']
            if wid:  # Only process if we have a valid WID
                # Always keep the latest version
                unique_payments[wid] = pmt
        
        payments_to_write = list(unique_payments.values())
        info(f"Deduplicated: {len(payments)} → {len(payments_to_write)} unique payments")
        
        schema = get_payment_schema()
        df = spark.createDataFrame(payments_to_write, schema)
        
        if mode == 'merge':
            # MERGE: Update existing, insert new
            try:
                delta_table = DeltaTable.forName(spark, BRONZE_PAYMENTS_PATH)
                
                # Merge on payment_wid (unique identifier)
                delta_table.alias("target").merge(
                    df.alias("source"),
                    "target.payment_wid = source.payment_wid"
                ).whenMatchedUpdateAll(
                ).whenNotMatchedInsertAll(
                ).execute()
                
                info(f"✓ Merged {len(payments_to_write)} payments")
            except Exception as e:
                # Table doesn't exist yet, create it
                if "not found" in str(e).lower() or "does not exist" in str(e).lower():
                    df.write.format("delta").mode("overwrite").saveAsTable(BRONZE_PAYMENTS_PATH)
                    info(f"✓ Created table with {len(payments_to_write)} payments")
                else:
                    raise
        else:
            # APPEND: For full refresh mode
            df.write.format("delta").mode("append").saveAsTable(BRONZE_PAYMENTS_PATH)
            info(f"✓ Appended {len(payments_to_write)} payments")
    
    if applications:
        # DEDUPLICATION: Keep only unique payment_wid + invoice_wid combinations
        unique_apps = {}
        for app in applications:
            key = (app['payment_wid'], app['invoice_wid'])
            if app['payment_wid'] and app['invoice_wid']:  # Only if both IDs exist
                unique_apps[key] = app
        
        apps_to_write = list(unique_apps.values())
        info(f"Deduplicated: {len(applications)} → {len(apps_to_write)} unique applications")
        
        schema = get_application_schema()
        df = spark.createDataFrame(apps_to_write, schema)
        
        if mode == 'merge':
            # MERGE: Update existing, insert new
            # Applications are uniquely identified by payment_wid + invoice_wid
            try:
                delta_table = DeltaTable.forName(spark, BRONZE_APPLICATIONS_PATH)
                
                delta_table.alias("target").merge(
                    df.alias("source"),
                    "target.payment_wid = source.payment_wid AND target.invoice_wid = source.invoice_wid"
                ).whenMatchedUpdateAll(
                ).whenNotMatchedInsertAll(
                ).execute()
                
                info(f"✓ Merged {len(apps_to_write)} applications")
            except Exception as e:
                # Table doesn't exist yet, create it
                if "not found" in str(e).lower() or "does not exist" in str(e).lower():
                    df.write.format("delta").mode("overwrite").saveAsTable(BRONZE_APPLICATIONS_PATH)
                    info(f"✓ Created table with {len(apps_to_write)} applications")
                else:
                    raise
        else:
            # APPEND: For full refresh mode
            df.write.format("delta").mode("append").saveAsTable(BRONZE_APPLICATIONS_PATH)
            info(f"✓ Appended {len(apps_to_write)} applications")

# ===========================
# MAIN FETCH LOGIC
# ===========================

def fetch_payments(spark, from_date=None, to_date=None, incremental=True):
    """Memory-safe sequential fetch with progress tracking"""
    
    # Determine write mode
    write_mode = 'merge' if incremental else 'append'
    
    # Default date range: last 5 years to today
    if not from_date:
        from_date = "2020-01-01"
    if not to_date:
        to_date = datetime.now().strftime("%Y-%m-%d")
    
    try:
        token = get_access_token()
    except Exception as e:
        error(f"Failed to get token: {e}")
        return
    
    session = requests.Session()
    session.headers.update({
        "Authorization": f"Bearer {token}",
        "Accept": "text/xml, application/xml",
        "Content-Type": "text/xml; charset=utf-8"
    })
    
    current_offset, saved_page_size = load_progress()
    
    psm = PageSizeManager()
    psm.current_size = TARGET_PAGE_SIZE
    
    mode_label = "INCREMENTAL" if incremental else "FULL REFRESH"
    info(f"Run mode: {mode_label} (write mode: {write_mode})")
    info(f"Date range: {from_date} to {to_date}")
    info(f"Starting from offset {current_offset:,}")
    info(f"Page size reset to {TARGET_PAGE_SIZE} (ignoring saved size {saved_page_size})")
    info(f"Memory-safe mode: Will flush batch when payments exceed {MAX_BATCH_PAYMENTS:,}")
    
    endpoint = f"https://{HOST}/ccx/service/{TENANT}/Revenue_Management/{RM_VERSION}"
    
    total_payments = 0
    total_applications = 0
    batch_payments = []
    batch_applications = []
    batch_count = 0
    consecutive_empty = 0
    iteration = 0
    start_time = time.time()
    
    while True:
        iteration += 1
        page_number = (current_offset // psm.get_current_size()) + 1
        page_size = psm.get_current_size()
        
        soap_body = build_soap_request(page_number, page_size, from_date, to_date)
        
        try:
            resp = session.post(endpoint, data=soap_body, timeout=120)
            
            if resp.status_code != 200:
                error(f"HTTP {resp.status_code}")
                error(f"Response: {resp.text[:1500]}")
                psm.record_failure()
                continue
        
        except Exception as e:
            warn(f"Request error: {e}")
            psm.record_failure()
            continue
        
        # Parse
        payments, applications = parse_payments(resp.text)
        
        if not payments:
            consecutive_empty += 1
            if consecutive_empty >= 3:
                info("No more payments found (3 consecutive empty pages)")
                break
            current_offset += page_size
            continue
        
        consecutive_empty = 0
        info(f"Fetched {len(payments)} payments, {len(applications)} applications (offset {current_offset:,})")
        
        # Add to batch
        batch_payments.extend(payments)
        batch_applications.extend(applications)
        batch_count += len(payments)
        total_payments += len(payments)
        total_applications += len(applications)
        current_offset += len(payments)
        
        # Flush if batch too large
        if batch_count >= MAX_BATCH_PAYMENTS:
            info(f"Flushing batch: {batch_count:,} payments, {len(batch_applications):,} applications")
            write_to_delta(spark, batch_payments, batch_applications, write_mode)
            batch_payments = []
            batch_applications = []
            batch_count = 0
        
        # Save progress periodically
        if iteration % PROGRESS_SAVE_INTERVAL == 0:
            save_progress(current_offset, psm.get_current_size(), total_payments)
        
        psm.record_success()
    
    # Flush final batch
    if batch_payments or batch_applications:
        info(f"Flushing final batch: {batch_count:,} payments, {len(batch_applications):,} applications")
        write_to_delta(spark, batch_payments, batch_applications, write_mode)
    
    # Final progress save
    save_progress(current_offset, psm.get_current_size(), total_payments)
    
    elapsed = time.time() - start_time
    info("="*70)
    info(f"COMPLETE: {total_payments:,} payments | {total_applications:,} invoice applications")
    info("="*70)
    info(f"Runtime: {elapsed:.1f}s ({elapsed/60:.1f} min)")
    if total_payments > 0:
        info(f"Average rate: {total_payments/elapsed:.1f} payments/sec")
    info("="*70)

# ===========================
# MAIN
# ===========================

def main():
    VERSION = "2.3"
    info("="*70)
    info(f"Workday Customer Payments Fetcher v{VERSION} - SMART INCREMENTAL MODE")
    info("="*70)
    
    spark = SparkSession.builder.getOrCreate()
    info("✓ Spark session ready")
    
    # Calculate date range based on mode
    TO_DATE = datetime.now().strftime("%Y-%m-%d")
    
    if INCREMENTAL_MODE:
        # SMART INCREMENTAL: Check table for last extraction date
        last_extraction_date = get_last_extraction_date(spark)
        
        if last_extraction_date:
            # Table exists with data - calculate incremental start date
            last_run = datetime.strptime(last_extraction_date, "%Y-%m-%d")
            # Go back INCREMENTAL_LOOKBACK_DAYS before last run to catch updates
            start_with_buffer = last_run - timedelta(days=INCREMENTAL_LOOKBACK_DAYS)
            FROM_DATE = start_with_buffer.strftime("%Y-%m-%d")
            
            days_since_last = (datetime.now() - last_run).days
            info(f"📅 INCREMENTAL MODE: Last run was {days_since_last} days ago")
            info(f"   Pulling from {FROM_DATE} (with {INCREMENTAL_LOOKBACK_DAYS}-day buffer for updates)")
        else:
            # Table doesn't exist or is empty - do initial load
            FROM_DATE = FULL_REFRESH_START_DATE
            info(f"📅 INITIAL LOAD: Table not found, pulling all history from {FROM_DATE}")
    else:
        # Full refresh: Pull all history, rebuild tables
        FROM_DATE = FULL_REFRESH_START_DATE
        info(f"📅 FULL REFRESH MODE: Rebuilding from {FROM_DATE}")
        info("   ⚠️  This will take longer than incremental runs")
    
    try:
        fetch_payments(spark, FROM_DATE, TO_DATE, INCREMENTAL_MODE)
    except KeyboardInterrupt:
        warn("\nInterrupted by user")
        return
    except Exception as e:
        error(f"Fatal error: {e}")
        import traceback
        traceback.print_exc()
        raise

if __name__ == "__main__":
    main()

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

"""
Workday Chart of Accounts Fetcher
Uses Get_Account_Sets operation to extract ledger account structure
Same pattern as journals fetcher - outputs to bronze table and JSON
"""
from __future__ import annotations

import os
import sys
import time
import json
import traceback
import requests
import jwt
from typing import List, Dict, Any, Optional
from pathlib import Path
from datetime import datetime, timedelta
from threading import Lock
import warnings
import subprocess

_file_write_lock = Lock()
warnings.filterwarnings('ignore')

def ensure_libs():
    print("="*70, flush=True)
    print("CHECKING LIBRARIES", flush=True)
    print("="*70, flush=True)
    
    to_install = []
    try:
        from lxml import etree
        print("✅ lxml OK", flush=True)
    except:
        print("⚠️  lxml missing", flush=True)
        to_install.append("lxml")
    
    try:
        import jwt
        print("✅ PyJWT OK", flush=True)
    except:
        print("⚠️  PyJWT missing", flush=True)
        to_install.append("PyJWT")
    
    if to_install:
        print(f"\nInstalling: {', '.join(to_install)}", flush=True)
        for lib in to_install:
            print(f"Installing {lib}...", flush=True)
            try:
                subprocess.run([sys.executable, "-m", "pip", "install", lib, "--break-system-packages"],
                             capture_output=True, timeout=60)
                print(f"✅ {lib} installed", flush=True)
            except Exception as e:
                print(f"⚠️  {lib} failed: {e}", flush=True)
    
    print("✅ Libraries ready!", flush=True)
    print("="*70, flush=True)
    print(flush=True)

ensure_libs()

try:
    from lxml import etree as ET
    HAS_LXML = True
except ImportError:
    import xml.etree.ElementTree as ET
    HAS_LXML = False

try:
    from pyspark.sql import SparkSession
    from pyspark.sql.types import StructType, StructField, StringType, BooleanType, IntegerType
    HAS_SPARK = True
except Exception:
    HAS_SPARK = False

from urllib3.util.retry import Retry
from requests.adapters import HTTPAdapter

HOST = os.getenv("WORKDAY_HOST", "https://services1.wd503.myworkday.com").rstrip("/")
TENANT = os.getenv("WORKDAY_TENANT", "stevenstransport")
CLIENT_ID = os.getenv("WORKDAY_CLIENT_ID", "N2ZkZWI1YjktOWM4Ni00ZDI2LTg0MzItNmY5YWMwMGMzYTUx")
ISU_SUBJECT = os.getenv("WORKDAY_ISU_SUBJECT", "ISU_Ms_Fabric")
FM_VERSION = os.getenv("WORKDAY_FM_VERSION", "v45.0")

TOKEN_URL = f"{HOST}/ccx/oauth2/{TENANT}/token"
SERVICE_ENDPOINT = f"{HOST}/ccx/service/{TENANT}/Financial_Management/{FM_VERSION}"

HTTP_TIMEOUT = int(os.getenv("WORKDAY_HTTP_TIMEOUT", "120"))
BACKOFF_FACTOR = float(os.getenv("WORKDAY_BACKOFF_FACTOR", "2"))
PAGE_SIZE = int(os.getenv("WORKDAY_COA_PAGE_SIZE", "100"))

OUTPUT_PATH = "/lakehouse/default/Files/workday_coa"
COA_FILE = os.path.join(OUTPUT_PATH, "chart_of_accounts.json")
PROGRESS_FILE = os.path.join(OUTPUT_PATH, "coa_extraction_progress.json")

BRONZE_COA = "workday_coa_bronze"

NS = {"wd": "urn:com.workday/bsvc"}

DEFAULT_KEY_PATHS = [
    "/lakehouse/data_central_lh/Files/workday_integration.key",
    "/lakehouse/default/Files/workday_integration.key"
]

LOG_LEVEL = os.getenv("WORKDAY_LOG_LEVEL", "INFO").upper()
LOG_LEVELS = {"DEBUG": 0, "INFO": 1, "WARN": 2, "ERROR": 3, "FATAL": 4}
CURRENT_LOG_LEVEL = LOG_LEVELS.get(LOG_LEVEL, 1)

def log(level: str, msg: str):
    if LOG_LEVELS.get(level, 1) >= CURRENT_LOG_LEVEL:
        print(f"[{level.lower()}] {msg}", flush=True)

def debug(msg: str): log("DEBUG", msg)
def info(msg: str): log("INFO", msg)
def warn(msg: str): log("WARN", msg)
def error(msg: str): log("ERROR", msg)
def fatal(msg: str): log("FATAL", msg)

def find_private_key() -> Optional[str]:
    for path in DEFAULT_KEY_PATHS:
        if Path(path).exists():
            debug(f"Found private key at {path}")
            return path
    return None

def generate_jwt_token(client_id: str, isu_subject: str, private_key_path: str) -> str:
    try:
        with open(private_key_path, 'r') as f:
            private_key = f.read()
        
        now = datetime.utcnow()
        payload = {
            'iss': client_id,
            'sub': isu_subject,
            'aud': TOKEN_URL,
            'exp': now + timedelta(minutes=5),
            'iat': now
        }
        
        token = jwt.encode(payload, private_key, algorithm='RS256')
        debug("JWT token generated successfully")
        return token
        
    except Exception as e:
        fatal(f"Failed to generate JWT token: {e}")
        raise

def get_access_token(jwt_token: str) -> str:
    payload = {
        'grant_type': 'urn:ietf:params:oauth:grant-type:jwt-bearer',
        'assertion': jwt_token
    }
    
    try:
        response = requests.post(TOKEN_URL, data=payload, timeout=30)
        response.raise_for_status()
        
        token_data = response.json()
        access_token = token_data.get('access_token')
        
        if not access_token:
            fatal("No access token in response")
            raise ValueError("No access token received")
        
        debug("Access token obtained successfully")
        return access_token
        
    except Exception as e:
        fatal(f"Failed to get access token: {e}")
        raise

def create_session() -> requests.Session:
    session = requests.Session()
    
    retry = Retry(
        total=5,
        read=5,
        connect=5,
        backoff_factor=BACKOFF_FACTOR,
        status_forcelist=[429, 500, 502, 503, 504],
        allowed_methods=["POST"]
    )
    
    adapter = HTTPAdapter(max_retries=retry)
    session.mount("https://", adapter)
    session.mount("http://", adapter)
    
    return session

def build_get_account_sets_request(page: int) -> bytes:
    """Build SOAP request using Get_Account_Sets - NO Response_Group (causes 500)"""
    soap = (
        '<?xml version="1.0" encoding="UTF-8"?>'
        '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/" xmlns:wd="urn:com.workday/bsvc">'
        '<soapenv:Header/>'
        '<soapenv:Body>'
        f'<wd:Get_Account_Sets_Request wd:version="{FM_VERSION}">'
        '<wd:Response_Filter>'
        f'<wd:Page>{page}</wd:Page>'
        f'<wd:Count>{PAGE_SIZE}</wd:Count>'
        '</wd:Response_Filter>'
        '</wd:Get_Account_Sets_Request>'
        '</soapenv:Body>'
        '</soapenv:Envelope>'
    )
    return soap.encode('utf-8')

def parse_account_sets(xml_text: str) -> List[Dict[str, Any]]:
    """Parse Get_Account_Sets response - extracts Ledger_Account_Data elements"""
    try:
        if HAS_LXML:
            root = ET.fromstring(xml_text.encode('utf-8'))
        else:
            root = ET.fromstring(xml_text)
        
        accounts = []
        seen = set()
        
        # Get_Account_Sets returns Ledger_Account_Data elements
        for acct_data in root.findall('.//wd:Ledger_Account_Data', NS):
            # Account Identifier (account number)
            identifier = acct_data.find('.//wd:Ledger_Account_Identifier', NS)
            if identifier is None or not identifier.text:
                continue
            
            account_number = identifier.text.strip()
            if account_number in seen:
                continue
            seen.add(account_number)
            
            account_data = {
                'account_number': account_number
            }
            
            # Account Name
            name = acct_data.find('.//wd:Ledger_Account_Name', NS)
            if name is not None and name.text:
                account_data['ledger_account_name'] = name.text.strip()
            
            # Account Type (Asset, Liability, Revenue, Expense)
            acct_type = acct_data.find('.//wd:Ledger_Account_Type_Reference/wd:ID[@wd:type="Ledger_Account_Type_ID"]', NS)
            if acct_type is not None and acct_type.text:
                account_data['account_type_name'] = acct_type.text.strip()
            
            # Active status (Retired: 0=active, 1=retired)
            retired = acct_data.find('.//wd:Retired', NS)
            if retired is not None and retired.text:
                account_data['active'] = (retired.text.strip() == '0')
            else:
                account_data['active'] = True
            
            account_data['extracted_timestamp'] = datetime.now().isoformat()
            account_data['extraction_method'] = 'SOAP_Get_Account_Sets'
            
            accounts.append(account_data)
        
        info(f"Parsed {len(accounts)} unique ledger accounts")
        return accounts
        
    except Exception as e:
        error(f"Error parsing XML: {e}")
        debug(traceback.format_exc())
        raise

def fetch_all_account_sets(access_token: str, session: requests.Session) -> List[Dict[str, Any]]:
    """Fetch all account sets with pagination - same pattern as journals"""
    info("="*70)
    info("Fetching Chart of Accounts via Get_Account_Sets")
    info(f"Endpoint: {SERVICE_ENDPOINT}")
    info(f"Page size: {PAGE_SIZE}")
    info("="*70)
    
    headers = {
        'Authorization': f'Bearer {access_token}',
        'Content-Type': 'text/xml; charset=utf-8'
    }
    
    all_accounts = []
    page = 1
    
    while True:
        soap_request = build_get_account_sets_request(page)
        
        try:
            info(f"Fetching page {page}...")
            debug(f"Request length: {len(soap_request)} bytes")
            
            response = session.post(
                SERVICE_ENDPOINT,
                data=soap_request,
                headers=headers,
                timeout=HTTP_TIMEOUT
            )
            
            debug(f"Response received: {response.status_code}")
            
            if response.status_code != 200:
                error(f"HTTP {response.status_code}")
                error(f"Response: {response.text[:1000]}")
                response.raise_for_status()
            
            accounts = parse_account_sets(response.text)
            
            if not accounts:
                info(f"Page {page} returned 0 accounts - reached end")
                break
            
            all_accounts.extend(accounts)
            info(f"✅ Page {page}: {len(accounts)} accounts (total: {len(all_accounts)})")
            
            page += 1
            
        except Exception as e:
            error(f"Error fetching page {page}: {e}")
            debug(traceback.format_exc())
            raise
    
    info(f"Successfully extracted {len(all_accounts)} total ledger accounts")
    return all_accounts

def save_to_json(accounts: List[Dict[str, Any]]):
    info(f"Saving {len(accounts)} accounts to {COA_FILE}")
    
    try:
        with _file_write_lock:
            temp_file = COA_FILE + ".tmp"
            
            with open(temp_file, 'w') as f:
                json.dump({
                    'extraction_timestamp': datetime.now().isoformat(),
                    'total_accounts': len(accounts),
                    'accounts': accounts
                }, f, indent=2)
            
            Path(temp_file).replace(COA_FILE)
            
        info(f"✅ Saved to {COA_FILE}")
        
    except Exception as e:
        error(f"Error saving JSON: {e}")
        raise

def save_to_bronze_table(accounts: List[Dict[str, Any]], spark: SparkSession):
    info(f"Saving {len(accounts)} accounts to bronze table: {BRONZE_COA}")
    
    try:
        schema = StructType([
            StructField("account_number", StringType(), True),
            StructField("ledger_account_name", StringType(), True),
            StructField("account_type_name", StringType(), True),
            StructField("active", BooleanType(), True),
            StructField("extracted_timestamp", StringType(), True),
            StructField("extraction_method", StringType(), True)
        ])
        
        df = spark.createDataFrame(accounts, schema=schema)
        df.write.format("delta").mode("overwrite").saveAsTable(BRONZE_COA)
        
        info(f"✅ Saved to bronze table: {BRONZE_COA}")
        info(f"  Total accounts: {len(accounts)}")
        
        # Show account type breakdown
        type_counts = {}
        for a in accounts:
            acct_type = a.get('account_type_name', 'Unknown')
            type_counts[acct_type] = type_counts.get(acct_type, 0) + 1
        
        info(f"  Account types:")
        for acct_type, count in sorted(type_counts.items()):
            info(f"    {acct_type}: {count}")
        
    except Exception as e:
        error(f"Error saving to bronze table: {e}")
        debug(traceback.format_exc())
        raise

def save_progress(accounts_count: int):
    progress = {
        'extraction_timestamp': datetime.now().isoformat(),
        'total_accounts': accounts_count,
        'status': 'complete'
    }
    
    try:
        with _file_write_lock:
            with open(PROGRESS_FILE, 'w') as f:
                json.dump(progress, f, indent=2)
        debug(f"Progress saved to {PROGRESS_FILE}")
    except Exception as e:
        warn(f"Could not save progress: {e}")

def main():
    info("="*70)
    info("Workday Chart of Accounts Fetcher")
    info("="*70)
    info(f"Tenant: {TENANT}")
    info(f"Service: {SERVICE_ENDPOINT}")
    info(f"Output: {OUTPUT_PATH}")
    info(f"Bronze Table: {BRONZE_COA}")
    info(f"Operation: Get_Account_Sets")
    info(f"Page Size: {PAGE_SIZE}")
    info(f"Optimizations: {'lxml' if HAS_LXML else 'stdlib xml'}")
    info("="*70)
    
    try:
        Path(OUTPUT_PATH).mkdir(parents=True, exist_ok=True)
        info(f"Output directory ready: {OUTPUT_PATH}")
    except Exception as e:
        warn(f"Could not create output directory: {e}")
    
    spark = None
    if HAS_SPARK:
        try:
            spark = SparkSession.getActiveSession()
            if spark:
                spark.conf.set("spark.sql.adaptive.enabled", "true")
                spark.conf.set("spark.databricks.delta.optimizeWrite.enabled", "true")
                info("Spark session configured")
            else:
                warn("No active Spark session found")
        except Exception as e:
            warn(f"Could not get Spark session: {e}")
    else:
        warn("PySpark not available - bronze table will not be created")
    
    try:
        start_time = time.time()
        
        info("Step 1: Finding private key...")
        private_key_path = find_private_key()
        if not private_key_path:
            fatal("Private key not found in any default location")
            fatal(f"Searched: {DEFAULT_KEY_PATHS}")
            raise FileNotFoundError("Private key not found")
        info(f"✅ Private key found: {private_key_path}")
        
        info("Step 2: Generating JWT token...")
        jwt_token = generate_jwt_token(CLIENT_ID, ISU_SUBJECT, private_key_path)
        info("✅ JWT token generated")
        
        info("Step 3: Getting access token...")
        access_token = get_access_token(jwt_token)
        info("✅ Access token obtained")
        
        info("Step 4: Creating HTTP session...")
        session = create_session()
        info("✅ Session ready")
        
        info("Step 5: Fetching all account sets...")
        accounts = fetch_all_account_sets(access_token, session)
        info(f"✅ Fetched {len(accounts)} ledger accounts")
        
        info("Step 6: Saving to JSON...")
        save_to_json(accounts)
        info("✅ JSON saved")
        
        if spark:
            info("Step 7: Saving to bronze table...")
            save_to_bronze_table(accounts, spark)
            info("✅ Bronze table saved")
        else:
            warn("Step 7: Skipped (no Spark session)")
        
        save_progress(len(accounts))
        
        elapsed = time.time() - start_time
        info("="*70)
        info("EXTRACTION COMPLETE")
        info(f"Total accounts: {len(accounts)}")
        info(f"Time elapsed: {elapsed:.1f}s")
        info(f"JSON file: {COA_FILE}")
        if spark:
            info(f"Bronze table: {BRONZE_COA}")
        info("="*70)
        
    except Exception as e:
        fatal(f"Unhandled error: {e}")
        debug(traceback.format_exc())
        raise

if __name__ == "__main__":
    main()

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

import pandas as pd
# Load data into pandas DataFrame from "/lakehouse/default/Files/workday_rest/workers.json"
df = pd.read_json("/lakehouse/default/Files/workday_rest/workers.json",typ="series")
display(df)


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }
