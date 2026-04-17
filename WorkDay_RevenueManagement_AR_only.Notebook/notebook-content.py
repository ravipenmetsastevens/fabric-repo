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

from lxml import etree
from pyspark.sql import Row, functions as F, types as T

# ----------------------------
# Source / Target names
# ----------------------------
SRC = "data_central_lh.workday_customer_invoices_raw_bronze"

TGT_HDR  = "data_central_lh.workday_customer_invoices_hdr_shred"
TGT_LINE = "data_central_lh.workday_customer_invoices_line_shred"
VW_DETAIL = "data_central_lh.vw_workday_customer_invoices_detail"

NS = {"env": "http://schemas.xmlsoap.org/soap/envelope/", "wd": "urn:com.workday/bsvc"}

# ----------------------------
# Helpers
# ----------------------------
def _txt(elem):
    if elem is None:
        return None
    t = (elem.text or "").strip()
    return t if t else None

def _ids(ref_elem):
    """Return dict of wd:type -> value for IDs under a *_Reference element."""
    out = {}
    if ref_elem is None:
        return out
    for i in ref_elem.findall("./wd:ID", NS):
        v = (i.text or "").strip()
        if not v:
            continue
        t = i.get("{urn:com.workday/bsvc}type") or i.get("type") or ""
        # keep first occurrence per type
        out.setdefault(t, v)
    return out

def _attr(elem, name):
    if elem is None:
        return None
    # Workday uses wd: attributes sometimes
    return elem.get(name)

def parse_one_raw_xml(raw_xml, pulled_at_utc=None, tenant=None, rm_version=None, page_num=None, page_size=None):
    """
    Returns: (hdr_rows, line_rows)
    """
    hdr_rows = []
    line_rows = []

    root = etree.fromstring(raw_xml.encode("utf-8"))
    invoices = root.findall(".//wd:Customer_Invoice", NS)

    for inv in invoices:
        inv_ref = inv.find("./wd:Customer_Invoice_Reference", NS)
        inv_ref_ids = _ids(inv_ref)

        inv_data = inv.find("./wd:Customer_Invoice_Data", NS)
        if inv_data is None:
            continue

        invoice_id = _txt(inv_data.find("./wd:Customer_Invoice_ID", NS)) or inv_ref_ids.get("Customer_Invoice_Reference_ID") or inv_ref_ids.get("WID")
        invoice_number = _txt(inv_data.find("./wd:Invoice_Number", NS))
        invoice_date = _txt(inv_data.find("./wd:Invoice_Date", NS))
        due_date = _txt(inv_data.find("./wd:Due_Date_Override", NS))
        amount_due = _txt(inv_data.find("./wd:Amount_Due", NS))
        payment_status = _txt(inv_data.find("./wd:Payment_Status", NS))
        document_status = _txt(inv_data.find("./wd:Document_Status", NS))
        customer_po = _txt(inv_data.find("./wd:Customer_PO_Number", NS))
        memo = _txt(inv_data.find("./wd:Memo", NS))

        company_ids = _ids(inv_data.find("./wd:Company_Reference", NS))
        currency_ids = _ids(inv_data.find("./wd:Currency_Reference", NS))
        customer_ids = _ids(inv_data.find("./wd:Customer_Reference", NS))
        sold_to_ids = _ids(inv_data.find("./wd:Sold_To_Customer_Reference", NS))

        # Bill-to basic address (from your sample structure)
        bill_to_ref_ids = _ids(inv_data.find("./wd:Bill_To_Address_Reference", NS))

        bill_to_data = inv_data.find("./wd:Bill_To_Address_Data/wd:Bill-To_Address_Data", NS)
        formatted_addr = bill_to_data.get("{urn:com.workday/bsvc}Formatted_Address") if bill_to_data is not None else None

        address_line1 = None
        if bill_to_data is not None:
            # take ADDRESS_LINE_1 if present
            for al in bill_to_data.findall("./wd:Address_Line_Data", NS):
                typ = al.get("{urn:com.workday/bsvc}Type") or al.get("wd:Type") or al.get("Type")
                if typ == "ADDRESS_LINE_1":
                    address_line1 = _txt(al)
                    break

        municipality = _txt(bill_to_data.find("./wd:Municipality", NS)) if bill_to_data is not None else None
        postal_code = _txt(bill_to_data.find("./wd:Postal_Code", NS)) if bill_to_data is not None else None
        country_region_desc = _txt(bill_to_data.find("./wd:Country_Region_Descriptor", NS)) if bill_to_data is not None else None
        country_ids = _ids(bill_to_data.find("./wd:Country_Reference", NS)) if bill_to_data is not None else {}

        hdr_rows.append(Row(
            pulled_at_utc=pulled_at_utc,
            tenant=tenant,
            rm_version=rm_version,
            page_num=page_num,
            page_size=page_size,

            invoice_wid=inv_ref_ids.get("WID"),
            invoice_reference_id=inv_ref_ids.get("Customer_Invoice_Reference_ID"),
            invoice_id=invoice_id,
            invoice_number=invoice_number,
            invoice_date=invoice_date,
            due_date_override=due_date,
            amount_due=float(amount_due) if amount_due else None,
            payment_status=payment_status,
            document_status=document_status,
            customer_po_number=customer_po,
            memo=memo,

            company_id=company_ids.get("Company_Reference_ID") or company_ids.get("Organization_Reference_ID"),
            company_wid=company_ids.get("WID"),
            currency_id=currency_ids.get("Currency_ID"),
            customer_id=customer_ids.get("Customer_ID"),
            customer_reference_id=customer_ids.get("Customer_Reference_ID"),
            customer_wid=customer_ids.get("WID"),
            sold_to_customer_id=sold_to_ids.get("Customer_ID"),
            sold_to_customer_reference_id=sold_to_ids.get("Customer_Reference_ID"),

            bill_to_address_id=bill_to_ref_ids.get("Address_ID"),
            bill_to_formatted_address=formatted_addr,
            bill_to_address_line1=address_line1,
            bill_to_city=municipality,
            bill_to_state=country_region_desc,   # in your sample "Texas" comes from Country_Region_Descriptor
            bill_to_postal_code=postal_code,
            bill_to_country_alpha2=country_ids.get("ISO_3166-1_Alpha-2_Code"),

            raw_invoice_xml=etree.tostring(inv, encoding="unicode")
        ))

        # Lines (repeat)
        line_blocks = inv_data.findall("./wd:Customer_Invoice_Line_Replacement_Data", NS)
        for idx, lb in enumerate(line_blocks):
            line_ref_ids = _ids(lb.find("./wd:Customer_Invoice_Line_Reference", NS))
            rev_cat_ids = _ids(lb.find("./wd:Revenue_Category_Reference", NS))

            qty = _txt(lb.find("./wd:Quantity", NS))
            unit_cost = _txt(lb.find("./wd:Unit_Cost", NS))
            ext_amt = _txt(lb.find("./wd:Extended_Amount", NS))
            line_memo = _txt(lb.find("./wd:Memo", NS))

            line_rows.append(Row(
                pulled_at_utc=pulled_at_utc,
                tenant=tenant,
                rm_version=rm_version,

                invoice_id=invoice_id,
                invoice_number=invoice_number,

                line_index=idx,
                invoice_line_wid=line_ref_ids.get("WID"),
                invoice_line_reference_id=line_ref_ids.get("Customer_Invoice_Line_Reference_ID"),
                revenue_category_id=rev_cat_ids.get("Revenue_Category_ID"),

                quantity=float(qty) if qty else None,
                unit_cost=float(unit_cost) if unit_cost else None,
                extended_amount=float(ext_amt) if ext_amt else None,
                line_memo=line_memo,

                raw_line_xml=etree.tostring(lb, encoding="unicode")
            ))

    return hdr_rows, line_rows


# ----------------------------
# Build shredded DataFrames
# ----------------------------
src_df = spark.table(SRC).select(
    F.col("pulled_at_utc"),
    F.col("tenant"),
    F.col("rm_version"),
    F.col("page_num"),
    F.col("page_size"),
    F.col("raw_xml")
)

hdr_all = []
line_all = []

# NOTE: This collects in driver. OK for a quick start on a small sample.
# For full-scale loads, I can give you a mapPartitions version (distributed).
rows = src_df.limit(5).collect()  # <-- change/remove limit when ready

for r in rows:
    hdr_rows, line_rows = parse_one_raw_xml(
        r["raw_xml"],
        pulled_at_utc=r["pulled_at_utc"],
        tenant=r["tenant"],
        rm_version=r["rm_version"],
        page_num=r["page_num"],
        page_size=r["page_size"],
    )
    hdr_all.extend(hdr_rows)
    line_all.extend(line_rows)

hdr_df = spark.createDataFrame(hdr_all)
line_df = spark.createDataFrame(line_all)

# ----------------------------
# Write tables
# ----------------------------
hdr_df.write.format("delta").mode("overwrite").saveAsTable(TGT_HDR)
line_df.write.format("delta").mode("overwrite").saveAsTable(TGT_LINE)

# ----------------------------
# Create view (header + lines)
# ----------------------------
spark.sql(f"""
CREATE OR REPLACE VIEW {VW_DETAIL} AS
SELECT
  h.pulled_at_utc,
  h.tenant,
  h.rm_version,
  h.invoice_id,
  h.invoice_number,
  h.invoice_date,
  h.due_date_override,
  h.amount_due,
  h.payment_status,
  h.document_status,
  h.customer_po_number,
  h.memo,
  h.company_id,
  h.currency_id,
  h.customer_id,
  h.customer_reference_id,
  h.customer_wid,
  h.sold_to_customer_id,
  h.bill_to_address_id,
  h.bill_to_formatted_address,
  h.bill_to_address_line1,
  h.bill_to_city,
  h.bill_to_state,
  h.bill_to_postal_code,
  h.bill_to_country_alpha2,

  l.line_index,
  l.invoice_line_reference_id,
  l.revenue_category_id,
  l.quantity,
  l.unit_cost,
  l.extended_amount,
  l.line_memo
FROM {TGT_HDR} h
LEFT JOIN {TGT_LINE} l
  ON h.invoice_id = l.invoice_id
""")

print("[DONE] Created/updated:")
print(" -", TGT_HDR)
print(" -", TGT_LINE)
print(" -", VW_DETAIL)


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

# ============================================================
# Workday Revenue_Management v45.2 - Get_Customer_Payments
# FULL RELOAD into Delta tables (no Response_Group available)
#
# Tables created:
#  1) rm_customer_payments_raw_v2         (raw XML + basic ids)
#  2) rm_customer_payments_v2             (payment header-level fields)
#  3) rm_customer_payment_remittance_advice_v2 (payment ↔ invoice apply lines)
# ============================================================

import os
import json
import uuid
from datetime import datetime, timedelta, timezone
from typing import Optional, List, Dict, Any

import requests
from lxml import etree
import jwt

from pyspark.sql import Row
from pyspark.sql.types import (
    StructType, StructField,
    StringType, TimestampType, DoubleType, BooleanType, IntegerType
)

# -----------------------------
# CONFIG
# -----------------------------
HOST = os.getenv("WORKDAY_HOST", "https://services1.wd503.myworkday.com").rstrip("/")
TENANT = os.getenv("WORKDAY_TENANT", "stevenstransport")

from notebookutils import mssparkutils

# --- Read secrets from Azure Key Vault ---
CLIENT_ID = mssparkutils.credentials.getSecret(
    "https://keyvault-fabric2.vault.azure.net/",
    "WORKDAYCLIENTID"
)
ISU_SUBJECT = os.getenv("WORKDAY_ISU_SUBJECT", "ISU_Ms_Fabric")

RM_VERSION = os.getenv("WORKDAY_RM_VERSION", "v45.2")
HTTP_TIMEOUT = int(os.getenv("WORKDAY_HTTP_TIMEOUT", "120"))

# Paging
PAGE_SIZE = int(os.getenv("WORKDAY_PAYMENTS_PAGE_SIZE", "200"))
MAX_PAGES = int(os.getenv("WORKDAY_PAYMENTS_MAX_PAGES", "2000"))  # safety

# Where to write tables (catalog.db.table) - edit as needed
DB_NAME = os.getenv("WORKDAY_TARGET_DB", "data_central_lh")

TBL_RAW   = f"{DB_NAME}.rm_customer_payments_raw_v2"
TBL_PAY   = f"{DB_NAME}.rm_customer_payments_v2"
TBL_APPLY = f"{DB_NAME}.rm_customer_payment_remittance_advice_v2"

# Private key locations
KEY_CANDIDATES = [
    os.getenv("WORKDAY_PRIVATE_KEY_PATH", "").strip(),
    "/lakehouse/data_central_lh/Files/workday_integration.key",
    "/lakehouse/default/Files/workday_integration.key",
]
KEY_CANDIDATES = [p for p in KEY_CANDIDATES if p]

NS = {"wd": "urn:com.workday/bsvc"}
SOAP_NS = {
    "soapenv": "http://schemas.xmlsoap.org/soap/envelope/",
    "wd": "urn:com.workday/bsvc"
}

# -----------------------------
# AUTH (ISU JWT Bearer)
# -----------------------------
_token_cache = {"token": None, "expires": datetime.min.replace(tzinfo=timezone.utc)}

def load_private_key_pem() -> str:
    for p in KEY_CANDIDATES:
        if p and os.path.exists(p):
            with open(p, "r", encoding="utf-8") as f:
                return f.read()
    raise FileNotFoundError("Workday private key not found. Tried:\n" + "\n".join(KEY_CANDIDATES))

def build_jwt_assertion(private_key_pem: str) -> str:
    now = datetime.now(timezone.utc)
    token_url = f"{HOST}/ccx/oauth2/{TENANT}/token"
    payload = {
        "iss": CLIENT_ID,
        "sub": ISU_SUBJECT,
        "aud": token_url,
        "iat": int(now.timestamp()),
        "exp": int((now + timedelta(minutes=5)).timestamp()),
        "jti": str(uuid.uuid4()),
    }
    return jwt.encode(payload, private_key_pem, algorithm="RS256")

def get_access_token() -> str:
    now = datetime.now(timezone.utc)
    if _token_cache["token"] and now < _token_cache["expires"]:
        return _token_cache["token"]

    private_key_pem = load_private_key_pem()
    assertion = build_jwt_assertion(private_key_pem)

    token_url = f"{HOST}/ccx/oauth2/{TENANT}/token"
    data = {"grant_type": "urn:ietf:params:oauth:grant-type:jwt-bearer", "assertion": assertion}

    resp = requests.post(token_url, data=data, timeout=HTTP_TIMEOUT)
    resp.raise_for_status()
    tok = resp.json()

    access_token = tok["access_token"]
    expires_in = int(tok.get("expires_in", 3600))
    _token_cache["token"] = access_token
    _token_cache["expires"] = now + timedelta(seconds=expires_in - 60)
    return access_token

# -----------------------------
# SOAP helpers
# -----------------------------
def extract_soap_fault(xml_text: str) -> Optional[str]:
    try:
        root = etree.fromstring(xml_text.encode("utf-8"))
        fault = root.find(".//soapenv:Fault", SOAP_NS)
        if fault is not None:
            fs = fault.findtext("faultstring") or fault.findtext("soapenv:faultstring", namespaces=SOAP_NS)
            detail = fault.find(".//detail")
            det_txt = etree.tostring(detail, encoding="unicode") if detail is not None else None
            return f"{fs}\n{det_txt}" if det_txt else (fs or "SOAP Fault")
        vf = root.find(".//wd:Validation_Fault", SOAP_NS)
        if vf is not None:
            return etree.tostring(vf, encoding="unicode")
    except Exception:
        return None
    return None

def build_get_customer_payments_request(page: int, count: int) -> str:
    # No Response_Group (not supported in your tenant/version)
    return f"""
    <soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/"
                      xmlns:wd="urn:com.workday/bsvc">
      <soapenv:Body>
        <wd:Get_Customer_Payments_Request wd:version="{RM_VERSION}">
          <wd:Response_Filter>
            <wd:Page>{page}</wd:Page>
            <wd:Count>{count}</wd:Count>
          </wd:Response_Filter>
        </wd:Get_Customer_Payments_Request>
      </soapenv:Body>
    </soapenv:Envelope>
    """.strip()

def fetch_payments_xml(session: requests.Session, page: int, count: int) -> str:
    endpoint = f"{HOST}/ccx/service/{TENANT}/Revenue_Management/{RM_VERSION}"
    payload = build_get_customer_payments_request(page, count)
    r = session.post(endpoint, data=payload, timeout=HTTP_TIMEOUT)

    if r.status_code >= 400:
        fault = extract_soap_fault(r.text)
        if fault:
            print("\n[SOAP FAULT SNIPPET]")
            print(fault[:1500])
        r.raise_for_status()

    return r.text

# -----------------------------
# XML extraction helpers
# -----------------------------
def text(node: Optional[etree._Element]) -> Optional[str]:
    if node is None:
        return None
    v = node.text
    if v is None:
        return None
    v = v.strip()
    return v if v != "" else None

def find_text(parent: etree._Element, xpath: str) -> Optional[str]:
    return text(parent.find(xpath, NS))

def find_bool(parent: etree._Element, xpath: str) -> Optional[bool]:
    v = find_text(parent, xpath)
    if v is None:
        return None
    if v.lower() in ("true", "1", "yes"):
        return True
    if v.lower() in ("false", "0", "no"):
        return False
    return None

def find_float(parent: etree._Element, xpath: str) -> Optional[float]:
    v = find_text(parent, xpath)
    if v is None:
        return None
    try:
        return float(v)
    except Exception:
        return None

def ref_id(parent: etree._Element, ref_xpath: str) -> Optional[str]:
    # returns the first ID value under a *_Reference
    ref = parent.find(ref_xpath, NS)
    if ref is None:
        return None
    id_node = ref.find("./wd:ID", NS)
    return text(id_node)

def ref_ids_json(parent: etree._Element, ref_xpath: str) -> Optional[str]:
    ref = parent.find(ref_xpath, NS)
    if ref is None:
        return None
    ids = []
    for id_node in ref.findall("./wd:ID", NS):
        ids.append({
            "type": id_node.get(f'{{{NS["wd"]}}}type') or id_node.get("type"),
            "value": text(id_node)
        })
    return json.dumps(ids) if ids else None

# -----------------------------
# Schemas
# -----------------------------
raw_schema = StructType([
    StructField("pulled_at_utc", TimestampType(), False),
    StructField("tenant", StringType(), False),
    StructField("rm_version", StringType(), False),
    StructField("payment_wid", StringType(), True),
    StructField("payment_reference_id", StringType(), True),
    StructField("payment_id", StringType(), True),
    StructField("customer_key", StringType(), True),
    StructField("payment_xml", StringType(), False),
])

pay_schema = StructType([
    StructField("pulled_at_utc", TimestampType(), False),
    StructField("tenant", StringType(), False),
    StructField("rm_version", StringType(), False),

    StructField("payment_wid", StringType(), True),
    StructField("payment_reference_id", StringType(), True),
    StructField("payment_id", StringType(), True),

    StructField("locked_in_workday", BooleanType(), True),
    StructField("payment_date", StringType(), True),
    StructField("payment_status", StringType(), True),
    StructField("payment_application_status", StringType(), True),

    StructField("payment_number", StringType(), True),
    StructField("payment_amount", DoubleType(), True),
    StructField("payment_memo", StringType(), True),

    StructField("ready_to_auto_apply", BooleanType(), True),
    StructField("do_not_apply_to_invoices_on_hold", BooleanType(), True),
    StructField("show_only_matched_invoices_when_applying", BooleanType(), True),

    StructField("company_id", StringType(), True),
    StructField("payment_currency_id", StringType(), True),
    StructField("invoice_currency_id", StringType(), True),
    StructField("payment_type_id", StringType(), True),

    StructField("remit_from_customer_id", StringType(), True),
    StructField("customer_deposit_id", StringType(), True),

    # Keep reference id sets for later enrichment/debug
    StructField("company_reference_ids_json", StringType(), True),
    StructField("payment_currency_reference_ids_json", StringType(), True),
    StructField("invoice_currency_reference_ids_json", StringType(), True),
    StructField("payment_type_reference_ids_json", StringType(), True),
    StructField("customer_reference_ids_json", StringType(), True),
    StructField("customer_deposit_reference_ids_json", StringType(), True),

    StructField("payment_json", StringType(), False),
])

apply_schema = StructType([
    StructField("pulled_at_utc", TimestampType(), False),
    StructField("tenant", StringType(), False),
    StructField("rm_version", StringType(), False),

    StructField("payment_wid", StringType(), True),
    StructField("payment_reference_id", StringType(), True),
    StructField("payment_id", StringType(), True),

    StructField("remit_from_customer_id", StringType(), True),

    StructField("customer_invoice_id", StringType(), True),
    StructField("amount_to_pay", DoubleType(), True),
    StructField("amount_to_pay_in_invoice_currency", DoubleType(), True),
])

# -----------------------------
# Table utilities
# -----------------------------
def drop_table_if_exists(tbl: str):
    spark.sql(f"DROP TABLE IF EXISTS {tbl}")

def create_empty_table(tbl: str, schema: StructType):
    empty_df = spark.createDataFrame([], schema)
    empty_df.write.format("delta").mode("overwrite").saveAsTable(tbl)

def append_rows(rows: List[dict], schema: StructType, tbl: str):
    if not rows:
        return
    df = spark.createDataFrame(rows, schema=schema)
    df.write.format("delta").mode("append").saveAsTable(tbl)

# -----------------------------
# Parsing
# -----------------------------
def parse_payment(payment_node: etree._Element, pulled_at, tenant: str, rm_version: str):
    # Core container
    p_data = payment_node.find("./wd:Customer_Payment_Data", NS)
    if p_data is None:
        return None, None, None

    # IDs / keys
    payment_wid = ref_id(p_data, "./wd:Customer_Payment_for_Invoices_Reference") or None
    # Some tenants place WID in the Reference element ID type=WID; our helper grabs first ID
    # If first ID isn't WID, we keep as-is.

    payment_reference_id = find_text(p_data, "./wd:Customer_Payment_for_Invoices_Reference_ID")
    payment_id = find_text(p_data, "./wd:Payment_Number")
    remit_from_customer_id = ref_id(p_data, "./wd:Remit-from_Customer_Reference")
    customer_deposit_id = ref_id(p_data, "./wd:Customer_Deposit_Reference")

    # Scalars
    row_pay = {
        "pulled_at_utc": pulled_at,
        "tenant": tenant,
        "rm_version": rm_version,

        "payment_wid": payment_wid,
        "payment_reference_id": payment_reference_id,
        "payment_id": payment_id,

        "locked_in_workday": find_bool(p_data, "./wd:Locked_in_Workday"),
        "payment_date": find_text(p_data, "./wd:Payment_Date"),
        "payment_status": find_text(p_data, "./wd:Payment_Status"),
        "payment_application_status": find_text(p_data, "./wd:Payment_Application_Status"),

        "payment_number": find_text(p_data, "./wd:Payment_Number"),
        "payment_amount": find_float(p_data, "./wd:Payment_Amount"),
        "payment_memo": find_text(p_data, "./wd:Payment_Memo"),

        "ready_to_auto_apply": find_bool(p_data, "./wd:Ready_to_Auto-Apply"),
        "do_not_apply_to_invoices_on_hold": find_bool(p_data, "./wd:Do_Not_Apply_Payment_to_Invoices_on_Hold"),
        "show_only_matched_invoices_when_applying": find_bool(p_data, "./wd:Show_Only_Matched_Invoices_when_Applying"),

        "company_id": ref_id(p_data, "./wd:Company_Reference"),
        "payment_currency_id": ref_id(p_data, "./wd:Payment_Currency_Reference"),
        "invoice_currency_id": ref_id(p_data, "./wd:Invoice_Currency_Reference"),
        "payment_type_id": ref_id(p_data, "./wd:Payment_Type_Reference"),

        "remit_from_customer_id": remit_from_customer_id,
        "customer_deposit_id": customer_deposit_id,

        "company_reference_ids_json": ref_ids_json(p_data, "./wd:Company_Reference"),
        "payment_currency_reference_ids_json": ref_ids_json(p_data, "./wd:Payment_Currency_Reference"),
        "invoice_currency_reference_ids_json": ref_ids_json(p_data, "./wd:Invoice_Currency_Reference"),
        "payment_type_reference_ids_json": ref_ids_json(p_data, "./wd:Payment_Type_Reference"),
        "customer_reference_ids_json": ref_ids_json(p_data, "./wd:Remit-from_Customer_Reference"),
        "customer_deposit_reference_ids_json": ref_ids_json(p_data, "./wd:Customer_Deposit_Reference"),
    }

    # Applications / remittance advice lines
    apply_rows = []
    for ra in p_data.findall("./wd:Customer_Payment_Remittance_Advice_Data", NS):
        inv_id = ref_id(ra, "./wd:Customer_Invoice_Reference")
        row_apply = {
            "pulled_at_utc": pulled_at,
            "tenant": tenant,
            "rm_version": rm_version,

            "payment_wid": payment_wid,
            "payment_reference_id": payment_reference_id,
            "payment_id": payment_id,

            "remit_from_customer_id": remit_from_customer_id,

            "customer_invoice_id": inv_id,
            "amount_to_pay": find_float(ra, "./wd:Amount_to_Pay"),
            "amount_to_pay_in_invoice_currency": find_float(ra, "./wd:Amount_to_Pay_in_Invoice_Currency"),
        }
        apply_rows.append(row_apply)

    # Raw row
    # Store the whole payment node as XML; also store a JSON "payment_json" for curated table
    payment_xml = etree.tostring(payment_node, encoding="unicode")
    row_raw = {
        "pulled_at_utc": pulled_at,
        "tenant": tenant,
        "rm_version": rm_version,
        "payment_wid": payment_wid,
        "payment_reference_id": payment_reference_id,
        "payment_id": payment_id,
        "customer_key": remit_from_customer_id,
        "payment_xml": payment_xml,
    }

    # lightweight json for curated table debugging
    row_pay["payment_json"] = json.dumps({
        "payment_wid": payment_wid,
        "payment_reference_id": payment_reference_id,
        "payment_id": payment_id,
        "remit_from_customer_id": remit_from_customer_id,
        "customer_deposit_id": customer_deposit_id,
    })

    return row_raw, row_pay, apply_rows

# -----------------------------
# MAIN full reload
# -----------------------------
def run_payments_full_reload():
    pulled_at = datetime.utcnow()
    token = get_access_token()
    session = requests.Session()
    session.headers.update({
        "Authorization": f"Bearer {token}",
        "Accept": "text/xml, application/xml",
        "Content-Type": "text/xml; charset=utf-8",
    })

    # Drop + create empty tables (prevents schema mismatch)
    print("[INFO] Dropping and recreating tables:")
    for t in [TBL_RAW, TBL_PAY, TBL_APPLY]:
        print(" -", t)
        drop_table_if_exists(t)

    create_empty_table(TBL_RAW, raw_schema)
    create_empty_table(TBL_PAY, pay_schema)
    create_empty_table(TBL_APPLY, apply_schema)

    total_payments = 0
    total_apply = 0

    for page in range(1, MAX_PAGES + 1):
        xml_text = fetch_payments_xml(session, page, PAGE_SIZE)
        root = etree.fromstring(xml_text.encode("utf-8"))

        payments = root.findall(".//wd:Customer_Payment", NS)
        if not payments:
            print(f"[INFO] No payments returned at page {page}. Stopping.")
            break

        raw_rows = []
        pay_rows = []
        apply_rows = []

        for p in payments:
            row_raw, row_pay, rows_apply = parse_payment(p, pulled_at, TENANT, RM_VERSION)
            if row_raw:
                raw_rows.append(row_raw)
            if row_pay:
                pay_rows.append(row_pay)
            if rows_apply:
                apply_rows.extend(rows_apply)

        append_rows(raw_rows, raw_schema, TBL_RAW)
        append_rows(pay_rows, pay_schema, TBL_PAY)
        append_rows(apply_rows, apply_schema, TBL_APPLY)

        total_payments += len(pay_rows)
        total_apply += len(apply_rows)

        if page % 10 == 0:
            print(f"[INFO] Pages={page} payments={total_payments} remittance_rows={total_apply}")

    print(f"[DONE] Payments loaded: {total_payments}")
    print(f"[DONE] Remittance advice rows loaded: {total_apply}")
    print("[DONE] Tables:")
    print(" -", TBL_RAW)
    print(" -", TBL_PAY)
    print(" -", TBL_APPLY)

run_payments_full_reload()


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

# ============================================================
# Workday Revenue_Management v45.2 - Get_Customer_Payments
# FULL PROBE (with Response_Group) + RAW XML SAVE
#
# What this does:
# 1) Auth via ISU JWT bearer (same pattern)
# 2) Calls Get_Customer_Payments with a Response_Group (tries to expand attrs)
# 3) Inspects N payments across M pages
# 4) Prints:
#    - Top leaf XML paths under Customer_Payment_Data
#    - Paths that appear once vs repeating (arrays)
#    - Reference ID types (wd:type)
# 5) Saves raw XML pages + CSV outputs + manifest to lakehouse Files
#
# NOTE:
# - Workday may ignore unsupported Response_Group flags; probe will show.
# ============================================================

import os
import json
import uuid
from datetime import datetime, timedelta, timezone
from collections import Counter
from typing import Any, Dict, List, Optional

import requests
from lxml import etree

# If jwt import fails, run once:
# %pip install pyjwt cryptography
import jwt

import pandas as pd

# -----------------------------
# 0) CONFIG
# -----------------------------
HOST = os.getenv("WORKDAY_HOST", "https://services1.wd503.myworkday.com").rstrip("/")
TENANT = os.getenv("WORKDAY_TENANT", "stevenstransport")

from notebookutils import mssparkutils

# --- Read secrets from Azure Key Vault ---
CLIENT_ID = mssparkutils.credentials.getSecret(
    "https://keyvault-fabric2.vault.azure.net/",
    "WORKDAYCLIENTID"
)
ISU_SUBJECT = os.getenv("WORKDAY_ISU_SUBJECT", "ISU_Ms_Fabric")

RM_VERSION = os.getenv("WORKDAY_RM_VERSION", "v45.2")
HTTP_TIMEOUT = int(os.getenv("WORKDAY_HTTP_TIMEOUT", "120"))

# Probe controls
PROBE_PAGES = int(os.getenv("WORKDAY_PAYMENTS_PROBE_PAGES", "3"))
PROBE_PAGE_SIZE = int(os.getenv("WORKDAY_PAYMENTS_PROBE_PAGE_SIZE", "5"))
SAMPLE_PAYMENT_LIMIT = int(os.getenv("WORKDAY_PAYMENTS_SAMPLE_LIMIT", "25"))

SAVE_RAW_XML = os.getenv("WORKDAY_SAVE_RAW_XML", "true").lower() == "true"
RAW_XML_DIR = os.getenv(
    "WORKDAY_PAYMENTS_RAW_XML_DIR", "/lakehouse/default/Files/workday_payments/schema_probe_v2/raw_xml"
)

SAVE_RESULTS = os.getenv("WORKDAY_SAVE_RESULTS", "true").lower() == "true"
RESULTS_DIR = os.getenv(
    "WORKDAY_PAYMENTS_RESULTS_DIR", "/lakehouse/default/Files/workday_payments/schema_probe_v2/results"
)

# Private key locations
KEY_CANDIDATES = [
    "/lakehouse/data_central_lh/Files/workday_integration.key",
    "/lakehouse/default/Files/workday_integration.key",
]
env_key_path = os.getenv("WORKDAY_PRIVATE_KEY_PATH", "").strip()
if env_key_path:
    KEY_CANDIDATES.insert(0, env_key_path)

NS = {"wd": "urn:com.workday/bsvc"}

# -----------------------------
# 1) Auth (ISU JWT Bearer)
# -----------------------------
_token_cache = {"token": None, "expires": datetime.min.replace(tzinfo=timezone.utc)}

def load_private_key_pem() -> str:
    for p in KEY_CANDIDATES:
        if p and os.path.exists(p):
            with open(p, "r", encoding="utf-8") as f:
                return f.read()
    raise FileNotFoundError("Workday private key not found. Tried:\n" + "\n".join(KEY_CANDIDATES))

def build_jwt_assertion(private_key_pem: str) -> str:
    now = datetime.now(timezone.utc)
    token_url = f"{HOST}/ccx/oauth2/{TENANT}/token"
    payload = {
        "iss": CLIENT_ID,
        "sub": ISU_SUBJECT,
        "aud": token_url,
        "iat": int(now.timestamp()),
        "exp": int((now + timedelta(minutes=5)).timestamp()),
        "jti": str(uuid.uuid4()),
    }
    return jwt.encode(payload, private_key_pem, algorithm="RS256")

def get_access_token() -> str:
    now = datetime.now(timezone.utc)
    if _token_cache["token"] and now < _token_cache["expires"]:
        return _token_cache["token"]

    private_key_pem = load_private_key_pem()
    assertion = build_jwt_assertion(private_key_pem)

    token_url = f"{HOST}/ccx/oauth2/{TENANT}/token"
    data = {"grant_type": "urn:ietf:params:oauth:grant-type:jwt-bearer", "assertion": assertion}

    resp = requests.post(token_url, data=data, timeout=HTTP_TIMEOUT)
    resp.raise_for_status()
    tok = resp.json()

    access_token = tok["access_token"]
    expires_in = int(tok.get("expires_in", 3600))
    _token_cache["token"] = access_token
    _token_cache["expires"] = now + timedelta(seconds=expires_in - 60)
    return access_token

# -----------------------------
# 2) SOAP request with Response_Group (expanded)
# -----------------------------
def build_get_customer_payments_request(page: int, count: int) -> str:
    # IMPORTANT:
    # Some Response_Group flags may not be supported. Workday may ignore or error.
    # This is a "best attempt" profile request.
    return f"""
    <soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/"
                      xmlns:wd="urn:com.workday/bsvc">
      <soapenv:Body>
        <wd:Get_Customer_Payments_Request wd:version="{RM_VERSION}">

          <wd:Response_Filter>
            <wd:Page>{page}</wd:Page>
            <wd:Count>{count}</wd:Count>
          </wd:Response_Filter>

          <wd:Response_Group>
            <wd:Include_References>true</wd:Include_References>

            <!-- Remittance advice links to invoices -->
            <wd:Include_Remittance_Advice_Data>true</wd:Include_Remittance_Advice_Data>

            <!-- Try to expand related objects -->
            <wd:Include_Customer_Data>true</wd:Include_Customer_Data>
            <wd:Include_Company_Data>true</wd:Include_Company_Data>
            <wd:Include_Currency_Data>true</wd:Include_Currency_Data>
            <wd:Include_Payment_Type_Data>true</wd:Include_Payment_Type_Data>

            <!-- Try to pull operational details (may be ignored) -->
            <wd:Include_Bank_Account_Data>true</wd:Include_Bank_Account_Data>
            <wd:Include_Check_and_Reference_Data>true</wd:Include_Check_and_Reference_Data>
            <wd:Include_Audit_Information>true</wd:Include_Audit_Information>
          </wd:Response_Group>

        </wd:Get_Customer_Payments_Request>
      </soapenv:Body>
    </soapenv:Envelope>
    """.strip()

def fetch_payments_xml(session: requests.Session, page: int, count: int) -> str:
    endpoint = f"{HOST}/ccx/service/{TENANT}/Revenue_Management/{RM_VERSION}"
    payload = build_get_customer_payments_request(page, count)
    r = session.post(endpoint, data=payload, timeout=HTTP_TIMEOUT)
    # If Workday rejects any Response_Group flags you'll see it here.
    r.raise_for_status()
    return r.text

# -----------------------------
# 3) Path profiling helpers
# -----------------------------
def local_name(tag: str) -> str:
    if not tag:
        return ""
    return tag.split("}", 1)[1] if tag.startswith("{") else tag

def has_element_children(e: etree._Element) -> bool:
    return any(isinstance(ch.tag, str) for ch in e)

def path_from(stop_elem: etree._Element, elem: etree._Element, stop_at_local: str = "Customer_Payment_Data") -> str:
    parts = []
    cur = elem
    while cur is not None:
        parts.append(local_name(cur.tag))
        if local_name(cur.tag) == stop_at_local:
            break
        cur = cur.getparent()
    parts.reverse()
    if stop_at_local in parts:
        parts = parts[parts.index(stop_at_local):]
    return "/".join(parts)

def iter_leaf_paths(payment_data: etree._Element) -> List[str]:
    out = []
    for e in payment_data.iter():
        if e is payment_data:
            continue
        if has_element_children(e):
            continue
        pth = path_from(payment_data, e, stop_at_local="Customer_Payment_Data")
        if pth:
            out.append(pth)
    return out

def collect_reference_id_types(payment_data: etree._Element) -> Counter:
    c = Counter()
    for ref in payment_data.iter():
        if not local_name(ref.tag).endswith("_Reference"):
            continue
        for id_elem in ref.findall("./wd:ID", NS):
            t = id_elem.get(f'{{{NS["wd"]}}}type') or id_elem.get("type")
            if t:
                c[t] += 1
    return c

# -----------------------------
# 4) Probe runner
# -----------------------------
def run_payments_probe():
    os.makedirs(RAW_XML_DIR, exist_ok=True)
    os.makedirs(RESULTS_DIR, exist_ok=True)

    token = get_access_token()
    session = requests.Session()
    session.headers.update({
        "Authorization": f"Bearer {token}",
        "Accept": "text/xml, application/xml",
        "Content-Type": "text/xml; charset=utf-8",
    })

    all_leaf_paths = Counter()
    per_payment_once = Counter()
    per_payment_repeat = Counter()
    ref_id_types = Counter()

    payment_seen = 0
    raw_files = []
    started_utc = datetime.utcnow().isoformat() + "Z"

    for page in range(1, PROBE_PAGES + 1):
        xml_text = fetch_payments_xml(session, page, PROBE_PAGE_SIZE)

        if SAVE_RAW_XML:
            raw_path = os.path.join(RAW_XML_DIR, f"customer_payments_page_{page}_count_{PROBE_PAGE_SIZE}.xml")
            with open(raw_path, "w", encoding="utf-8") as f:
                f.write(xml_text)
            raw_files.append(raw_path)

        root = etree.fromstring(xml_text.encode("utf-8"))
        payments = root.findall(".//wd:Customer_Payment", NS)
        if not payments:
            print(f"[WARN] No Customer_Payment elements found on page {page}. Stopping.")
            break

        for p in payments:
            if payment_seen >= SAMPLE_PAYMENT_LIMIT:
                break

            p_data = p.find("./wd:Customer_Payment_Data", NS)
            if p_data is None:
                continue

            leafs = iter_leaf_paths(p_data)
            local_counts = Counter(leafs)

            for k, v in local_counts.items():
                all_leaf_paths[k] += v
                if v == 1:
                    per_payment_once[k] += 1
                else:
                    per_payment_repeat[k] += 1

            ref_id_types.update(collect_reference_id_types(p_data))

            payment_seen += 1

        if payment_seen >= SAMPLE_PAYMENT_LIMIT:
            break

    print(f"[INFO] Inspected {payment_seen} payments across up to {PROBE_PAGES} pages.")

    all_df = pd.DataFrame([{"leaf_xml_path": k, "total_occurrences": v} for k, v in all_leaf_paths.most_common()])
    once_df = pd.DataFrame([{"leaf_xml_path": k, "payments_where_once": v} for k, v in per_payment_once.most_common()])
    repeat_df = pd.DataFrame([{"leaf_xml_path": k, "payments_where_repeating": v} for k, v in per_payment_repeat.most_common()])
    types_df = pd.DataFrame([{"wd_type": k, "occurrences": v} for k, v in ref_id_types.most_common()])

    print("\n=== TOP 50 LEAF XML PATHS (by total occurrences) ===")
    print(all_df.head(50).to_string(index=False))

    print("\n=== TOP 50 LEAF XML PATHS that appear ONCE per payment ===")
    print(once_df.head(50).to_string(index=False))

    print("\n=== TOP 50 LEAF XML PATHS that REPEAT within a payment (arrays) ===")
    print(repeat_df.head(50).to_string(index=False))

    print("\n=== Reference ID types observed (wd:type) ===")
    print(types_df.to_string(index=False))

    if SAVE_RESULTS:
        all_csv = os.path.join(RESULTS_DIR, "all_leaf_paths.csv")
        once_csv = os.path.join(RESULTS_DIR, "leaf_paths_once_per_payment.csv")
        repeat_csv = os.path.join(RESULTS_DIR, "leaf_paths_repeating_within_payment.csv")
        types_csv = os.path.join(RESULTS_DIR, "reference_id_types.csv")
        manifest_path = os.path.join(RESULTS_DIR, "probe_manifest.json")

        all_df.to_csv(all_csv, index=False)
        once_df.to_csv(once_csv, index=False)
        repeat_df.to_csv(repeat_csv, index=False)
        types_df.to_csv(types_csv, index=False)

        manifest = {
            "host": HOST,
            "tenant": TENANT,
            "rm_version": RM_VERSION,
            "client_id": CLIENT_ID,
            "isu_subject": ISU_SUBJECT,
            "inspected_payments": payment_seen,
            "probe_pages": PROBE_PAGES,
            "probe_page_size": PROBE_PAGE_SIZE,
            "sample_payment_limit": SAMPLE_PAYMENT_LIMIT,
            "raw_xml_files": raw_files if SAVE_RAW_XML else [],
            "outputs": [all_csv, once_csv, repeat_csv, types_csv],
            "generated_utc": datetime.utcnow().isoformat() + "Z",
            "started_utc": started_utc,
            "response_group_enabled": True,
        }
        with open(manifest_path, "w", encoding="utf-8") as f:
            json.dump(manifest, f, indent=2)

        print(f"\n[INFO] Saved results to: {RESULTS_DIR}")
        print(f"[INFO] Manifest: {manifest_path}")

run_payments_probe()


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

# ============================================================
# Workday Revenue_Management v45.2 - Get_Customer_Payments
# FULL LOAD → NEW TABLES
#
# Creates (Delta):
# - data_central_lh.workday_customer_payments_raw_bronze
# - data_central_lh.workday_customer_payments_bronze
# - data_central_lh.workday_customer_payment_applications_bronze
#
# Strategy:
# - Store entire Customer_Payment_Data as JSON (no attribute loss)
# - Extract key IDs for joins (Payment_ID / Payment_Reference_ID / WID)
# - Extract Customer reference IDs (for DimCustomer join)
# - Extract payment applications (for Invoice join) when present
# ============================================================

import os
import json
import uuid
from datetime import datetime, timedelta, timezone
from typing import Any, Dict, List, Optional, Tuple

import requests
from lxml import etree
import jwt

from pyspark.sql import Row
from pyspark.sql.types import (
    StructType, StructField, StringType, TimestampType, LongType, DoubleType
)

# -----------------------------
# 0) CONFIG (same pattern)
# -----------------------------
HOST = os.getenv("WORKDAY_HOST", "https://services1.wd503.myworkday.com").rstrip("/")
TENANT = os.getenv("WORKDAY_TENANT", "stevenstransport")

from notebookutils import mssparkutils

# --- Read secrets from Azure Key Vault ---
CLIENT_ID = mssparkutils.credentials.getSecret(
    "https://keyvault-fabric2.vault.azure.net/",
    "WORKDAYCLIENTID"
)
ISU_SUBJECT = os.getenv("WORKDAY_ISU_SUBJECT", "ISU_Ms_Fabric")

RM_VERSION = os.getenv("WORKDAY_RM_VERSION", "v45.2")
HTTP_TIMEOUT = int(os.getenv("WORKDAY_HTTP_TIMEOUT", "120"))

PAGE_SIZE = int(os.getenv("WORKDAY_PAYMENTS_PAGE_SIZE", "200"))
MAX_PAGES = int(os.getenv("WORKDAY_PAYMENTS_MAX_PAGES", "2000"))

TARGET_DB = os.getenv("WORKDAY_TARGET_DB", "data_central_lh")

TBL_RAW   = f"{TARGET_DB}.workday_customer_payments_raw_bronze_v2"
TBL_PAY   = f"{TARGET_DB}.workday_customer_payments_bronze_v2"
TBL_APPLY = f"{TARGET_DB}.workday_customer_payment_applications_bronze_v2"

KEY_CANDIDATES = [
    "/lakehouse/data_central_lh/Files/workday_integration.key",
    "/lakehouse/default/Files/workday_integration.key",
]
env_key_path = os.getenv("WORKDAY_PRIVATE_KEY_PATH", "").strip()
if env_key_path:
    KEY_CANDIDATES.insert(0, env_key_path)

NS = {"wd": "urn:com.workday/bsvc"}

# -----------------------------
# 1) Auth (ISU JWT Bearer)
# -----------------------------
_token_cache = {"token": None, "expires": datetime.min.replace(tzinfo=timezone.utc)}

def load_private_key_pem() -> str:
    for p in KEY_CANDIDATES:
        if p and os.path.exists(p):
            with open(p, "r", encoding="utf-8") as f:
                return f.read()
    raise FileNotFoundError("Workday private key not found. Tried:\n" + "\n".join(KEY_CANDIDATES))

def build_jwt_assertion(private_key_pem: str) -> str:
    now = datetime.now(timezone.utc)
    token_url = f"{HOST}/ccx/oauth2/{TENANT}/token"
    payload = {
        "iss": CLIENT_ID,
        "sub": ISU_SUBJECT,
        "aud": token_url,
        "iat": int(now.timestamp()),
        "exp": int((now + timedelta(minutes=5)).timestamp()),
        "jti": str(uuid.uuid4()),
    }
    return jwt.encode(payload, private_key_pem, algorithm="RS256")

def get_access_token() -> str:
    now = datetime.now(timezone.utc)
    if _token_cache["token"] and now < _token_cache["expires"]:
        return _token_cache["token"]

    private_key_pem = load_private_key_pem()
    assertion = build_jwt_assertion(private_key_pem)

    token_url = f"{HOST}/ccx/oauth2/{TENANT}/token"
    data = {"grant_type": "urn:ietf:params:oauth:grant-type:jwt-bearer", "assertion": assertion}

    resp = requests.post(token_url, data=data, timeout=HTTP_TIMEOUT)
    resp.raise_for_status()
    tok = resp.json()

    access_token = tok["access_token"]
    expires_in = int(tok.get("expires_in", 3600))
    _token_cache["token"] = access_token
    _token_cache["expires"] = now + timedelta(seconds=expires_in - 60)
    return access_token

# -----------------------------
# 2) SOAP request + fetch (Get_Customer_Payments)
# -----------------------------
def build_get_customer_payments_request(page: int, count: int) -> str:
    # Minimal request. Add date filters later if needed.
    return f"""
    <soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/"
                      xmlns:wd="urn:com.workday/bsvc">
      <soapenv:Body>
        <wd:Get_Customer_Payments_Request wd:version="{RM_VERSION}">
          <wd:Response_Filter>
            <wd:Page>{page}</wd:Page>
            <wd:Count>{count}</wd:Count>
          </wd:Response_Filter>
        </wd:Get_Customer_Payments_Request>
      </soapenv:Body>
    </soapenv:Envelope>
    """.strip()

def fetch_payments_xml(session: requests.Session, page: int, count: int) -> str:
    endpoint = f"{HOST}/ccx/service/{TENANT}/Revenue_Management/{RM_VERSION}"
    payload = build_get_customer_payments_request(page, count)
    r = session.post(endpoint, data=payload, timeout=HTTP_TIMEOUT)
    r.raise_for_status()
    return r.text

# -----------------------------
# 3) XML -> dict helpers (keep everything)
# -----------------------------
def _local(tag: str) -> str:
    return tag.split("}", 1)[1] if tag and tag.startswith("{") else tag

def elem_to_obj(elem: etree._Element) -> Any:
    obj: Dict[str, Any] = {}
    if elem.attrib:
        obj["@"] = {k: v for k, v in elem.attrib.items()}

    children = list(elem)
    if children:
        grouped: Dict[str, List[Any]] = {}
        for ch in children:
            k = _local(ch.tag)
            grouped.setdefault(k, []).append(elem_to_obj(ch))
        for k, vals in grouped.items():
            obj[k] = vals[0] if len(vals) == 1 else vals

    txt = (elem.text or "").strip()
    if txt and (children or elem.attrib):
        obj["#text"] = txt
    elif txt and not children and not elem.attrib:
        return txt
    return obj

def safe_json(obj: Any) -> str:
    return json.dumps(obj, ensure_ascii=False, separators=(",", ":"), default=str)

def extract_ref_ids(ref_elem: Optional[etree._Element]) -> List[Dict[str, str]]:
    out = []
    if ref_elem is None:
        return out
    for i in ref_elem.findall("./wd:ID", NS):
        v = (i.text or "").strip()
        if not v:
            continue
        t = i.get(f'{{{NS["wd"]}}}type') or i.get("type") or ""
        out.append({"type": t, "value": v})
    return out

def pick_id(ids: List[Dict[str, str]], preferred: List[str]) -> Optional[str]:
    for p in preferred:
        for it in ids:
            if it.get("type") == p and it.get("value"):
                return it["value"]
    for it in ids:
        if it.get("value"):
            return it["value"]
    return None

def extract_text(parent: etree._Element, tag_name: str) -> Optional[str]:
    e = parent.find(f"./wd:{tag_name}", NS)
    if e is None:
        return None
    t = (e.text or "").strip()
    return t if t else None

def extract_float(parent: etree._Element, tag_name: str) -> Optional[float]:
    v = extract_text(parent, tag_name)
    if v is None:
        return None
    try:
        return float(v)
    except Exception:
        return None

# -----------------------------
# 4) Parse page -> rows
# -----------------------------
def parse_payments(xml_text: str, pulled_at_utc: datetime, page_num: int):
    root = etree.fromstring(xml_text.encode("utf-8"))

    raw_rows = [Row(
        pulled_at_utc=pulled_at_utc,
        tenant=TENANT,
        rm_version=RM_VERSION,
        page_num=page_num,
        page_size=PAGE_SIZE,
        raw_xml=xml_text
    )]

    pay_rows: List[Row] = []
    app_rows: List[Row] = []

    payments = root.findall(".//wd:Customer_Payment", NS)

    for p in payments:
        pay_ref = p.find("./wd:Customer_Payment_Reference", NS)
        pay_ref_ids = extract_ref_ids(pay_ref)

        payment_wid = pick_id(pay_ref_ids, ["WID"])
        payment_reference_id = pick_id(pay_ref_ids, ["Customer_Payment_Reference_ID", "Payment_Reference_ID"])
        payment_id = pick_id(pay_ref_ids, ["Customer_Payment_ID", "Payment_ID"])

        pay_data = p.find("./wd:Customer_Payment_Data", NS)

        if pay_data is None:
            pay_rows.append(Row(
                pulled_at_utc=pulled_at_utc,
                tenant=TENANT,
                rm_version=RM_VERSION,
                payment_wid=payment_wid,
                payment_reference_id=payment_reference_id,
                payment_id=payment_id,
                customer_key=None,
                payment_date=None,
                payment_amount=None,
                currency=None,
                status=None,
                payment_reference_ids_json=safe_json(pay_ref_ids),
                payment_json=None
            ))
            continue

        # pull a few common top-level fields if present (safe even if missing)
        payment_date = extract_text(pay_data, "Payment_Date") or extract_text(pay_data, "Customer_Payment_Date")
        payment_amount = extract_float(pay_data, "Payment_Amount") or extract_float(pay_data, "Amount")
        status = extract_text(pay_data, "Payment_Status") or extract_text(pay_data, "Status")

        # currency ref
        currency_ref_ids = extract_ref_ids(pay_data.find("./wd:Currency_Reference", NS))
        currency = pick_id(currency_ref_ids, ["Currency_ID", "Currency_Numeric_Code", "WID"])

        # customer ref
        cust_ref_ids = extract_ref_ids(pay_data.find("./wd:Customer_Reference", NS))
        customer_key = pick_id(cust_ref_ids, ["Customer_ID", "Customer_Reference_ID", "WID"])

        pay_obj = elem_to_obj(pay_data)

        pay_rows.append(Row(
            pulled_at_utc=pulled_at_utc,
            tenant=TENANT,
            rm_version=RM_VERSION,
            payment_wid=payment_wid,
            payment_reference_id=payment_reference_id,
            payment_id=payment_id,
            customer_key=customer_key,
            payment_date=payment_date,
            payment_amount=payment_amount,
            currency=currency,
            status=status,
            payment_reference_ids_json=safe_json(pay_ref_ids),
            customer_reference_ids_json=safe_json(cust_ref_ids),
            currency_reference_ids_json=safe_json(currency_ref_ids),
            payment_json=safe_json(pay_obj)
        ))

        # Payment applications (link to invoices) - structure varies by tenant/config
        # We'll look for any nodes that reference Customer Invoice.
        # Common patterns include: Applied_To_Reference, Customer_Invoice_Reference, or Invoice_Reference in nested blocks.
        # We'll walk descendants and capture any Customer_Invoice_Reference IDs.
        invoice_refs = pay_data.findall(".//wd:Customer_Invoice_Reference", NS)
        for inv_ref in invoice_refs:
            inv_ids = extract_ref_ids(inv_ref)
            invoice_key = pick_id(inv_ids, ["Customer_Invoice_ID", "Customer_Invoice_Reference_ID", "WID"])

            app_rows.append(Row(
                pulled_at_utc=pulled_at_utc,
                tenant=TENANT,
                rm_version=RM_VERSION,
                payment_id=payment_id,
                payment_reference_id=payment_reference_id,
                payment_wid=payment_wid,
                customer_key=customer_key,
                invoice_key=invoice_key,
                invoice_reference_ids_json=safe_json(inv_ids)
            ))

    return raw_rows, pay_rows, app_rows

# -----------------------------
# 5) Spark schemas + writer
# -----------------------------
raw_schema = StructType([
    StructField("pulled_at_utc", TimestampType(), False),
    StructField("tenant", StringType(), True),
    StructField("rm_version", StringType(), True),
    StructField("page_num", LongType(), True),
    StructField("page_size", LongType(), True),
    StructField("raw_xml", StringType(), True),
])

pay_schema = StructType([
    StructField("pulled_at_utc", TimestampType(), False),
    StructField("tenant", StringType(), True),
    StructField("rm_version", StringType(), True),

    StructField("payment_wid", StringType(), True),
    StructField("payment_reference_id", StringType(), True),
    StructField("payment_id", StringType(), True),

    StructField("customer_key", StringType(), True),

    StructField("payment_date", StringType(), True),
    StructField("payment_amount", DoubleType(), True),
    StructField("currency", StringType(), True),
    StructField("status", StringType(), True),

    StructField("payment_reference_ids_json", StringType(), True),
    StructField("customer_reference_ids_json", StringType(), True),
    StructField("currency_reference_ids_json", StringType(), True),

    StructField("payment_json", StringType(), True),
])

app_schema = StructType([
    StructField("pulled_at_utc", TimestampType(), False),
    StructField("tenant", StringType(), True),
    StructField("rm_version", StringType(), True),

    StructField("payment_id", StringType(), True),
    StructField("payment_reference_id", StringType(), True),
    StructField("payment_wid", StringType(), True),

    StructField("customer_key", StringType(), True),

    StructField("invoice_key", StringType(), True),
    StructField("invoice_reference_ids_json", StringType(), True),
])

def append_rows(rows: List[Row], schema: StructType, table_name: str):
    if not rows:
        return
    df = spark.createDataFrame(rows, schema=schema)
    df.write.format("delta").mode("append").saveAsTable(table_name)

# -----------------------------
# 6) Main loop
# -----------------------------
def run_payments_full_load():
    token = get_access_token()
    sess = requests.Session()
    sess.headers.update({
        "Authorization": f"Bearer {token}",
        "Accept": "text/xml, application/xml",
        "Content-Type": "text/xml; charset=utf-8",
    })

    pulled_at_utc = datetime.utcnow()

    total_pay = 0
    total_app = 0

    for page in range(1, MAX_PAGES + 1):
        xml_text = fetch_payments_xml(sess, page, PAGE_SIZE)

        raw_rows, pay_rows, app_rows = parse_payments(xml_text, pulled_at_utc, page)

        if not pay_rows:
            print(f"[INFO] No payments found on page {page}. Stopping.")
            break

        append_rows(raw_rows, raw_schema, TBL_RAW)
        append_rows(pay_rows, pay_schema, TBL_PAY)
        append_rows(app_rows, app_schema, TBL_APPLY)

        total_pay += len(pay_rows)
        total_app += len(app_rows)

        if page % 10 == 0:
            print(f"[INFO] Page {page}: payments_written={total_pay}, invoice_links={total_app}")

    print("[DONE] Payments load complete")
    print(f"Payments written   : {total_pay}")
    print(f"Invoice link rows  : {total_app}")
    print("Tables:")
    print(" -", TBL_RAW)
    print(" -", TBL_PAY)
    print(" -", TBL_APPLY)

run_payments_full_load()


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

spark.sql("DROP TABLE IF EXISTS data_central_lh.workday_rm_customer_invoices_hdr_bronze")
spark.sql("DROP TABLE IF EXISTS data_central_lh.workday_rm_customer_invoices_line_bronze")
spark.sql("DROP TABLE IF EXISTS data_central_lh.workday_rm_customer_invoices_line_worktags_bronze")
spark.sql("DROP TABLE IF EXISTS data_central_lh.workday_rm_customer_invoices_raw_bronze")


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

# ============================================================
# Workday Revenue_Management v45.2 - Get_Customers
# FULL LOAD → NEW TABLES
#
# Creates (Delta):
# - data_central_lh.workday_customers_raw_bronze
# - data_central_lh.workday_customers_bronze
#
# Strategy:
# - Store the entire Customer_Data payload as JSON (no attribute loss)
# - Extract key IDs for joins (Customer_ID, Customer_Reference_ID, WID)
# ============================================================

import os
import json
import uuid
from datetime import datetime, timedelta, timezone
from typing import Any, Dict, List, Optional, Tuple

import requests
from lxml import etree
import jwt

from pyspark.sql import Row
from pyspark.sql.types import (
    StructType, StructField, StringType, TimestampType, LongType
)

# -----------------------------
# 0) CONFIG (matches your header pattern)
# -----------------------------
HOST = os.getenv("WORKDAY_HOST", "https://services1.wd503.myworkday.com").rstrip("/")
TENANT = os.getenv("WORKDAY_TENANT", "stevenstransport")

from notebookutils import mssparkutils

# --- Read secrets from Azure Key Vault ---
CLIENT_ID = mssparkutils.credentials.getSecret(
    "https://keyvault-fabric2.vault.azure.net/",
    "WORKDAYCLIENTID"
)
ISU_SUBJECT = os.getenv("WORKDAY_ISU_SUBJECT", "ISU_Ms_Fabric")

# Per your link: Revenue_Management/v45.2/Get_Customers.html
RM_VERSION = os.getenv("WORKDAY_RM_VERSION", "v45.2")

HTTP_TIMEOUT = int(os.getenv("WORKDAY_HTTP_TIMEOUT", "120"))

# Paging
PAGE_SIZE = int(os.getenv("WORKDAY_CUSTOMERS_PAGE_SIZE", "200"))
MAX_PAGES = int(os.getenv("WORKDAY_CUSTOMERS_MAX_PAGES", "2000"))  # safety cap

TARGET_DB = os.getenv("WORKDAY_TARGET_DB", "data_central_lh")

TBL_RAW = f"{TARGET_DB}.workday_customers_raw_bronze"
TBL_DIM = f"{TARGET_DB}.workday_customers_bronze"

# Private key locations (same pattern you referenced earlier)
KEY_CANDIDATES = [
    "/lakehouse/data_central_lh/Files/workday_integration.key",
    "/lakehouse/default/Files/workday_integration.key",
]
env_key_path = os.getenv("WORKDAY_PRIVATE_KEY_PATH", "").strip()
if env_key_path:
    KEY_CANDIDATES.insert(0, env_key_path)

NS = {"wd": "urn:com.workday/bsvc"}

# -----------------------------
# 1) Auth helpers (ISU JWT Bearer)
# -----------------------------
_token_cache = {"token": None, "expires": datetime.min.replace(tzinfo=timezone.utc)}

def load_private_key_pem() -> str:
    for p in KEY_CANDIDATES:
        if p and os.path.exists(p):
            with open(p, "r", encoding="utf-8") as f:
                return f.read()
    raise FileNotFoundError("Workday private key not found. Tried:\n" + "\n".join(KEY_CANDIDATES))

def build_jwt_assertion(private_key_pem: str) -> str:
    now = datetime.now(timezone.utc)
    token_url = f"{HOST}/ccx/oauth2/{TENANT}/token"
    payload = {
        "iss": CLIENT_ID,
        "sub": ISU_SUBJECT,
        "aud": token_url,
        "iat": int(now.timestamp()),
        "exp": int((now + timedelta(minutes=5)).timestamp()),
        "jti": str(uuid.uuid4()),
    }
    return jwt.encode(payload, private_key_pem, algorithm="RS256")

def get_access_token() -> str:
    now = datetime.now(timezone.utc)
    if _token_cache["token"] and now < _token_cache["expires"]:
        return _token_cache["token"]

    private_key_pem = load_private_key_pem()
    assertion = build_jwt_assertion(private_key_pem)

    token_url = f"{HOST}/ccx/oauth2/{TENANT}/token"
    data = {
        "grant_type": "urn:ietf:params:oauth:grant-type:jwt-bearer",
        "assertion": assertion,
    }

    resp = requests.post(token_url, data=data, timeout=HTTP_TIMEOUT)
    resp.raise_for_status()
    tok = resp.json()

    access_token = tok["access_token"]
    expires_in = int(tok.get("expires_in", 3600))

    _token_cache["token"] = access_token
    _token_cache["expires"] = now + timedelta(seconds=expires_in - 60)
    return access_token

# -----------------------------
# 2) SOAP request + fetch (Get_Customers)
# -----------------------------
def build_get_customers_request(page: int, count: int) -> str:
    # Minimal request to return customers with paging.
    # If you later want to control what comes back (response groups),
    # add <wd:Response_Group> ... </wd:Response_Group> here.
    return f"""
    <soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/"
                      xmlns:wd="urn:com.workday/bsvc">
      <soapenv:Body>
        <wd:Get_Customers_Request wd:version="{RM_VERSION}">
          <wd:Response_Filter>
            <wd:Page>{page}</wd:Page>
            <wd:Count>{count}</wd:Count>
          </wd:Response_Filter>
        </wd:Get_Customers_Request>
      </soapenv:Body>
    </soapenv:Envelope>
    """.strip()

def fetch_customers_xml(session: requests.Session, page: int, count: int) -> str:
    endpoint = f"{HOST}/ccx/service/{TENANT}/Revenue_Management/{RM_VERSION}"
    payload = build_get_customers_request(page, count)
    r = session.post(endpoint, data=payload, timeout=HTTP_TIMEOUT)
    r.raise_for_status()
    return r.text

# -----------------------------
# 3) XML → dict (keep everything)
# -----------------------------
def _local(tag: str) -> str:
    return tag.split("}", 1)[1] if tag and tag.startswith("{") else tag

def elem_to_obj(elem: etree._Element) -> Any:
    """
    Convert XML element to JSON-serializable object.
    - attributes under "@"
    - text under "#text" when mixed
    - repeated child tags become lists
    """
    obj: Dict[str, Any] = {}

    if elem.attrib:
        obj["@"] = {k: v for k, v in elem.attrib.items()}

    children = list(elem)
    if children:
        grouped: Dict[str, List[Any]] = {}
        for ch in children:
            k = _local(ch.tag)
            grouped.setdefault(k, []).append(elem_to_obj(ch))
        for k, vals in grouped.items():
            obj[k] = vals[0] if len(vals) == 1 else vals

    txt = (elem.text or "").strip()
    if txt and (children or elem.attrib):
        obj["#text"] = txt
    elif txt and not children and not elem.attrib:
        return txt

    return obj

def safe_json(obj: Any) -> str:
    return json.dumps(obj, ensure_ascii=False, separators=(",", ":"), default=str)

def extract_ref_ids(ref_elem: Optional[etree._Element]) -> List[Dict[str, str]]:
    out = []
    if ref_elem is None:
        return out
    for i in ref_elem.findall("./wd:ID", NS):
        v = (i.text or "").strip()
        if not v:
            continue
        t = i.get(f'{{{NS["wd"]}}}type') or i.get("type") or ""
        out.append({"type": t, "value": v})
    return out

def pick_id(ids: List[Dict[str, str]], preferred: List[str]) -> Optional[str]:
    for p in preferred:
        for it in ids:
            if it.get("type") == p and it.get("value"):
                return it["value"]
    for it in ids:
        if it.get("value"):
            return it["value"]
    return None

def extract_text(parent: etree._Element, tag_name: str) -> Optional[str]:
    e = parent.find(f"./wd:{tag_name}", NS)
    if e is None:
        return None
    t = (e.text or "").strip()
    return t if t else None

# -----------------------------
# 4) Parse page → rows
# -----------------------------
def parse_customers(xml_text: str, pulled_at_utc: datetime, page_num: int):
    root = etree.fromstring(xml_text.encode("utf-8"))

    raw_rows = [Row(
        pulled_at_utc=pulled_at_utc,
        tenant=TENANT,
        rm_version=RM_VERSION,
        page_num=page_num,
        page_size=PAGE_SIZE,
        raw_xml=xml_text
    )]

    cust_rows: List[Row] = []

    # Typical response nodes:
    # <wd:Get_Customers_Response> ... <wd:Customer> ... <wd:Customer_Data> ...
    customers = root.findall(".//wd:Customer", NS)

    for c in customers:
        cust_ref = c.find("./wd:Customer_Reference", NS)
        cust_ref_ids = extract_ref_ids(cust_ref)

        customer_wid = pick_id(cust_ref_ids, ["WID"])
        customer_reference_id = pick_id(cust_ref_ids, ["Customer_Reference_ID"])
        customer_id = pick_id(cust_ref_ids, ["Customer_ID"])

        cust_data = c.find("./wd:Customer_Data", NS)
        if cust_data is None:
            # still store reference-only row
            cust_rows.append(Row(
                pulled_at_utc=pulled_at_utc,
                tenant=TENANT,
                rm_version=RM_VERSION,
                customer_wid=customer_wid,
                customer_reference_id=customer_reference_id,
                customer_id=customer_id,
                customer_name=None,
                customer_reference_ids_json=safe_json(cust_ref_ids),
                customer_json=None
            ))
            continue

        # Sometimes name exists as Customer_Name or Name – keep both if present
        customer_name = extract_text(cust_data, "Customer_Name") or extract_text(cust_data, "Name")

        cust_obj = elem_to_obj(cust_data)

        cust_rows.append(Row(
            pulled_at_utc=pulled_at_utc,
            tenant=TENANT,
            rm_version=RM_VERSION,
            customer_wid=customer_wid,
            customer_reference_id=customer_reference_id,
            customer_id=customer_id,
            customer_name=customer_name,
            customer_reference_ids_json=safe_json(cust_ref_ids),
            customer_json=safe_json(cust_obj)
        ))

    return raw_rows, cust_rows

# -----------------------------
# 5) Spark schemas + append helper
# -----------------------------
raw_schema = StructType([
    StructField("pulled_at_utc", TimestampType(), False),
    StructField("tenant", StringType(), True),
    StructField("rm_version", StringType(), True),
    StructField("page_num", LongType(), True),
    StructField("page_size", LongType(), True),
    StructField("raw_xml", StringType(), True),
])

cust_schema = StructType([
    StructField("pulled_at_utc", TimestampType(), False),
    StructField("tenant", StringType(), True),
    StructField("rm_version", StringType(), True),

    # Join keys / identifiers
    StructField("customer_wid", StringType(), True),
    StructField("customer_reference_id", StringType(), True),
    StructField("customer_id", StringType(), True),

    # Handy display
    StructField("customer_name", StringType(), True),

    # Full payload
    StructField("customer_reference_ids_json", StringType(), True),
    StructField("customer_json", StringType(), True),
])

def append_rows(rows: List[Row], schema: StructType, table_name: str):
    if not rows:
        return
    df = spark.createDataFrame(rows, schema=schema)
    df.write.format("delta").mode("append").saveAsTable(table_name)

# -----------------------------
# 6) Main loop
# -----------------------------
def run_customers_full_load():
    token = get_access_token()

    sess = requests.Session()
    sess.headers.update({
        "Authorization": f"Bearer {token}",
        "Accept": "text/xml, application/xml",
        "Content-Type": "text/xml; charset=utf-8",
    })

    pulled_at_utc = datetime.utcnow()

    total_customers = 0

    for page in range(1, MAX_PAGES + 1):
        xml_text = fetch_customers_xml(sess, page, PAGE_SIZE)

        raw_rows, cust_rows = parse_customers(xml_text, pulled_at_utc, page)

        # Stop when response has no customers
        if not cust_rows:
            print(f"[INFO] No customers found on page {page}. Stopping.")
            break

        append_rows(raw_rows, raw_schema, TBL_RAW)
        append_rows(cust_rows, cust_schema, TBL_DIM)

        total_customers += len(cust_rows)

        if page % 10 == 0:
            print(f"[INFO] Page {page}: customers_written={total_customers}")

    print("[DONE] Customers load complete")
    print(f"Customers written: {total_customers}")
    print("Tables:")
    print(" -", TBL_RAW)
    print(" -", TBL_DIM)

run_customers_full_load()


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

# ============================================================
# Workday Revenue Management - Customer Invoices
# FULL LOAD → NEW TABLES (RAW + HEADER + LINES + LINE_WORKTAGS)
# (Removed "_rm_" from table names as requested)
#
# Key improvement vs earlier:
# - Extract Customer IDs from Customer_Reference and Sold_To_Customer_Reference
#   so you have stable join keys to DimCustomer (Get_Customers).
# ============================================================

import os
import json
import uuid
from datetime import datetime, timedelta, timezone
from typing import Any, Dict, List, Optional, Tuple

import requests
from lxml import etree
import jwt

from pyspark.sql import Row
from pyspark.sql.types import (
    StructType, StructField, StringType, TimestampType, LongType
)

# -----------------------------
# 0) CONFIG (matches your header pattern)
# -----------------------------
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
RM_VERSION = os.getenv("WORKDAY_RM_VERSION", HR_VERSION)

HTTP_TIMEOUT = int(os.getenv("WORKDAY_HTTP_TIMEOUT", "120"))

# Paging
PAGE_SIZE = int(os.getenv("WORKDAY_RM_PAGE_SIZE", "200"))
MAX_PAGES = int(os.getenv("WORKDAY_RM_MAX_PAGES", "2000"))  # safety cap

# Target Lakehouse
TARGET_DB = os.getenv("WORKDAY_TARGET_DB", "data_central_lh")

# ---- Table names (NO _rm_) ----
TBL_RAW  = f"{TARGET_DB}.workday_customer_invoices_raw_bronze"
TBL_HDR  = f"{TARGET_DB}.workday_customer_invoices_hdr_bronze"
TBL_LINE = f"{TARGET_DB}.workday_customer_invoices_line_bronze"
TBL_WT   = f"{TARGET_DB}.workday_customer_invoices_line_worktags_bronze"

# Key file paths
KEY_CANDIDATES = [
    "/lakehouse/data_central_lh/Files/workday_integration.key",
    "/lakehouse/default/Files/workday_integration.key",
]
env_key_path = os.getenv("WORKDAY_PRIVATE_KEY_PATH", "").strip()
if env_key_path:
    KEY_CANDIDATES.insert(0, env_key_path)

NS = {"wd": "urn:com.workday/bsvc"}

# -----------------------------
# 1) Auth helpers (ISU JWT Bearer)
# -----------------------------
_token_cache = {"token": None, "expires": datetime.min.replace(tzinfo=timezone.utc)}

def load_private_key_pem() -> str:
    for p in KEY_CANDIDATES:
        if p and os.path.exists(p):
            with open(p, "r", encoding="utf-8") as f:
                return f.read()
    raise FileNotFoundError("Workday private key not found. Tried:\n" + "\n".join(KEY_CANDIDATES))

def build_jwt_assertion(private_key_pem: str) -> str:
    now = datetime.now(timezone.utc)
    token_url = f"{HOST}/ccx/oauth2/{TENANT}/token"
    payload = {
        "iss": CLIENT_ID,
        "sub": ISU_SUBJECT,
        "aud": token_url,
        "iat": int(now.timestamp()),
        "exp": int((now + timedelta(minutes=5)).timestamp()),
        "jti": str(uuid.uuid4()),
    }
    return jwt.encode(payload, private_key_pem, algorithm="RS256")

def get_access_token() -> str:
    now = datetime.now(timezone.utc)
    if _token_cache["token"] and now < _token_cache["expires"]:
        return _token_cache["token"]

    private_key_pem = load_private_key_pem()
    assertion = build_jwt_assertion(private_key_pem)

    token_url = f"{HOST}/ccx/oauth2/{TENANT}/token"
    data = {
        "grant_type": "urn:ietf:params:oauth:grant-type:jwt-bearer",
        "assertion": assertion,
    }

    resp = requests.post(token_url, data=data, timeout=HTTP_TIMEOUT)
    resp.raise_for_status()
    tok = resp.json()

    access_token = tok["access_token"]
    expires_in = int(tok.get("expires_in", 3600))

    _token_cache["token"] = access_token
    _token_cache["expires"] = now + timedelta(seconds=expires_in - 60)
    return access_token

# -----------------------------
# 2) SOAP request + fetch
# -----------------------------
def build_soap_request(page: int, count: int) -> str:
    return f"""
    <soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/"
                      xmlns:wd="urn:com.workday/bsvc">
      <soapenv:Body>
        <wd:Get_Customer_Invoices_Request wd:version="{RM_VERSION}">
          <wd:Response_Filter>
            <wd:Page>{page}</wd:Page>
            <wd:Count>{count}</wd:Count>
          </wd:Response_Filter>
        </wd:Get_Customer_Invoices_Request>
      </soapenv:Body>
    </soapenv:Envelope>
    """.strip()

def fetch_customer_invoices_xml(session: requests.Session, page: int, count: int) -> str:
    endpoint = f"{HOST}/ccx/service/{TENANT}/Revenue_Management/{RM_VERSION}"
    payload = build_soap_request(page, count)
    r = session.post(endpoint, data=payload, timeout=HTTP_TIMEOUT)
    r.raise_for_status()
    return r.text

# -----------------------------
# 3) XML → dict helpers (keep *everything*)
# -----------------------------
def _local(tag: str) -> str:
    return tag.split("}", 1)[1] if tag and tag.startswith("{") else tag

def elem_to_obj(elem: etree._Element) -> Any:
    obj: Dict[str, Any] = {}
    if elem.attrib:
        obj["@"] = {k: v for k, v in elem.attrib.items()}

    children = list(elem)
    if children:
        grouped: Dict[str, List[Any]] = {}
        for ch in children:
            k = _local(ch.tag)
            grouped.setdefault(k, []).append(elem_to_obj(ch))
        for k, vals in grouped.items():
            obj[k] = vals[0] if len(vals) == 1 else vals

    txt = (elem.text or "").strip()
    if txt and (children or elem.attrib):
        obj["#text"] = txt
    elif txt and not children and not elem.attrib:
        return txt
    return obj

def safe_json(obj: Any) -> str:
    return json.dumps(obj, ensure_ascii=False, separators=(",", ":"), default=str)

def extract_text(parent: etree._Element, tag_name: str) -> Optional[str]:
    e = parent.find(f"./wd:{tag_name}", NS)
    if e is None:
        return None
    t = (e.text or "").strip()
    return t if t else None

def extract_ref_ids(ref_elem: Optional[etree._Element]) -> List[Dict[str, str]]:
    out = []
    if ref_elem is None:
        return out
    for i in ref_elem.findall("./wd:ID", NS):
        v = (i.text or "").strip()
        if not v:
            continue
        t = i.get(f'{{{NS["wd"]}}}type') or i.get("type") or ""
        out.append({"type": t, "value": v})
    return out

def pick_best_id(ids: List[Dict[str, str]], preferred=("Customer_ID","Customer_Reference_ID","WID")) -> Optional[str]:
    if not ids:
        return None
    # pick in preferred order
    for p in preferred:
        for it in ids:
            if it.get("type") == p and it.get("value"):
                return it["value"]
    # else first non-empty
    for it in ids:
        if it.get("value"):
            return it["value"]
    return None

def find_invoice_id(inv_elem: etree._Element, inv_data: etree._Element) -> Optional[str]:
    # Customer_Invoice_ID leaf is usually present
    cid = extract_text(inv_data, "Customer_Invoice_ID")
    if cid:
        return cid
    # else try Customer_Invoice_Reference IDs
    ref_ids = inv_elem.findall(".//wd:Customer_Invoice_Reference/wd:ID", NS)
    for i in ref_ids:
        v = (i.text or "").strip()
        if v:
            return v
    return None

# -----------------------------
# 4) Parse page into rows
# -----------------------------
def parse_customer_invoices(xml_text: str, pulled_at_utc: datetime, page_num: int):
    root = etree.fromstring(xml_text.encode("utf-8"))
    invoices = root.findall(".//wd:Customer_Invoice", NS)

    raw_rows = [Row(
        pulled_at_utc=pulled_at_utc,
        tenant=TENANT,
        rm_version=RM_VERSION,
        page_num=page_num,
        page_size=PAGE_SIZE,
        raw_xml=xml_text
    )]

    hdr_rows, line_rows, wt_rows = [], [], []

    for inv in invoices:
        inv_data = inv.find("./wd:Customer_Invoice_Data", NS)
        if inv_data is None:
            continue

        invoice_id = find_invoice_id(inv, inv_data)
        invoice_number = extract_text(inv_data, "Invoice_Number")
        invoice_date = extract_text(inv_data, "Invoice_Date")

        # CUSTOMER refs (critical for downstream joins)
        customer_ref = inv_data.find("./wd:Customer_Reference", NS)
        sold_to_ref = inv_data.find("./wd:Sold_To_Customer_Reference", NS)

        customer_ids = extract_ref_ids(customer_ref)
        sold_to_ids = extract_ref_ids(sold_to_ref)

        customer_key = pick_best_id(customer_ids)
        sold_to_customer_key = pick_best_id(sold_to_ids)

        # COMPANY / CURRENCY (often needed for reporting)
        company_ids = extract_ref_ids(inv_data.find("./wd:Company_Reference", NS))
        currency_ids = extract_ref_ids(inv_data.find("./wd:Currency_Reference", NS))

        hdr_obj = elem_to_obj(inv_data)

        hdr_rows.append(Row(
            pulled_at_utc=pulled_at_utc,
            tenant=TENANT,
            rm_version=RM_VERSION,
            invoice_id=invoice_id,
            invoice_number=invoice_number,
            invoice_date=invoice_date,
            customer_key=customer_key,
            sold_to_customer_key=sold_to_customer_key,
            customer_ids_json=safe_json(customer_ids),
            sold_to_customer_ids_json=safe_json(sold_to_ids),
            company_ids_json=safe_json(company_ids),
            currency_ids_json=safe_json(currency_ids),
            header_json=safe_json(hdr_obj)
        ))

        # Lines
        line_blocks = inv_data.findall("./wd:Customer_Invoice_Line_Replacement_Data", NS)
        for idx, lb in enumerate(line_blocks):
            line_obj = elem_to_obj(lb)

            line_ref_ids = extract_ref_ids(lb.find("./wd:Customer_Invoice_Line_Reference", NS))
            rev_cat_ids = extract_ref_ids(lb.find("./wd:Revenue_Category_Reference", NS))

            line_ref_id_text = extract_text(lb, "Customer_Invoice_Line_Reference_ID")

            line_rows.append(Row(
                pulled_at_utc=pulled_at_utc,
                tenant=TENANT,
                rm_version=RM_VERSION,
                invoice_id=invoice_id,
                invoice_number=invoice_number,
                customer_key=customer_key,
                sold_to_customer_key=sold_to_customer_key,
                line_index=idx,
                customer_invoice_line_reference_id=line_ref_id_text,
                line_ref_ids_json=safe_json(line_ref_ids),
                revenue_category_ids_json=safe_json(rev_cat_ids),
                line_json=safe_json(line_obj)
            ))

            # Worktags exploded
            wt_refs = lb.findall("./wd:Worktags_Reference", NS)
            for wt_ref in wt_refs:
                for item in extract_ref_ids(wt_ref):
                    wt_rows.append(Row(
                        pulled_at_utc=pulled_at_utc,
                        tenant=TENANT,
                        rm_version=RM_VERSION,
                        invoice_id=invoice_id,
                        invoice_number=invoice_number,
                        customer_key=customer_key,
                        sold_to_customer_key=sold_to_customer_key,
                        line_index=idx,
                        worktag_type=item.get("type", ""),
                        worktag_value=item.get("value", "")
                    ))

    return raw_rows, hdr_rows, line_rows, wt_rows

# -----------------------------
# 5) Spark schemas + writers
# -----------------------------
raw_schema = StructType([
    StructField("pulled_at_utc", TimestampType(), False),
    StructField("tenant", StringType(), True),
    StructField("rm_version", StringType(), True),
    StructField("page_num", LongType(), True),
    StructField("page_size", LongType(), True),
    StructField("raw_xml", StringType(), True),
])

hdr_schema = StructType([
    StructField("pulled_at_utc", TimestampType(), False),
    StructField("tenant", StringType(), True),
    StructField("rm_version", StringType(), True),
    StructField("invoice_id", StringType(), True),
    StructField("invoice_number", StringType(), True),
    StructField("invoice_date", StringType(), True),
    StructField("customer_key", StringType(), True),
    StructField("sold_to_customer_key", StringType(), True),
    StructField("customer_ids_json", StringType(), True),
    StructField("sold_to_customer_ids_json", StringType(), True),
    StructField("company_ids_json", StringType(), True),
    StructField("currency_ids_json", StringType(), True),
    StructField("header_json", StringType(), True),
])

line_schema = StructType([
    StructField("pulled_at_utc", TimestampType(), False),
    StructField("tenant", StringType(), True),
    StructField("rm_version", StringType(), True),
    StructField("invoice_id", StringType(), True),
    StructField("invoice_number", StringType(), True),
    StructField("customer_key", StringType(), True),
    StructField("sold_to_customer_key", StringType(), True),
    StructField("line_index", LongType(), True),
    StructField("customer_invoice_line_reference_id", StringType(), True),
    StructField("line_ref_ids_json", StringType(), True),
    StructField("revenue_category_ids_json", StringType(), True),
    StructField("line_json", StringType(), True),
])

wt_schema = StructType([
    StructField("pulled_at_utc", TimestampType(), False),
    StructField("tenant", StringType(), True),
    StructField("rm_version", StringType(), True),
    StructField("invoice_id", StringType(), True),
    StructField("invoice_number", StringType(), True),
    StructField("customer_key", StringType(), True),
    StructField("sold_to_customer_key", StringType(), True),
    StructField("line_index", LongType(), True),
    StructField("worktag_type", StringType(), True),
    StructField("worktag_value", StringType(), True),
])

def append_rows(rows, schema, table_name):
    if not rows:
        return
    df = spark.createDataFrame(rows, schema=schema)
    df.write.format("delta").mode("append").saveAsTable(table_name)

# -----------------------------
# 6) Run full load
# -----------------------------
def run_full_load():
    token = get_access_token()
    sess = requests.Session()
    sess.headers.update({
        "Authorization": f"Bearer {token}",
        "Accept": "text/xml, application/xml",
        "Content-Type": "text/xml; charset=utf-8",
    })

    pulled_at_utc = datetime.utcnow()

    total_hdr = total_line = total_wt = 0

    for page in range(1, MAX_PAGES + 1):
        xml_text = fetch_customer_invoices_xml(sess, page, PAGE_SIZE)

        raw_rows, hdr_rows, line_rows, wt_rows = parse_customer_invoices(xml_text, pulled_at_utc, page)

        if not hdr_rows:
            print(f"[INFO] No invoices found on page {page}. Stopping.")
            break

        append_rows(raw_rows, raw_schema, TBL_RAW)
        append_rows(hdr_rows, hdr_schema, TBL_HDR)
        append_rows(line_rows, line_schema, TBL_LINE)
        append_rows(wt_rows, wt_schema, TBL_WT)

        total_hdr += len(hdr_rows)
        total_line += len(line_rows)
        total_wt += len(wt_rows)

        if page % 10 == 0:
            print(f"[INFO] Page {page}: hdr={total_hdr}, line={total_line}, worktags={total_wt}")

    print("[DONE] Load complete")
    print("Tables:")
    print(" -", TBL_RAW)
    print(" -", TBL_HDR)
    print(" -", TBL_LINE)
    print(" -", TBL_WT)

run_full_load()


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

# ============================================================
# Workday RM (Revenue Management) - Customer Invoices
# FULL LOAD → NEW TABLES (RAW + HEADER + LINES + LINE_WORKTAGS)
#
# What this does:
# 1) Pulls Customer Invoices pages from Workday RM SOAP API
# 2) Writes raw SOAP XML to a RAW bronze table
# 3) Parses *all* invoice header data into a JSON blob + a few key columns
# 4) Parses *all* line replacement data into JSON blob + key columns
# 5) Explodes Worktags into a separate table (one row per worktag id per line)
#
# Tables created (Delta):
# - data_central_lh.workday_rm_customer_invoices_raw_bronze
# - data_central_lh.workday_rm_customer_invoices_hdr_bronze
# - data_central_lh.workday_rm_customer_invoices_line_bronze
# - data_central_lh.workday_rm_customer_invoices_line_worktags_bronze
#
# Notes:
# - “Bring all data” is achieved by storing the complete nested structures as JSON.
# - You can later flatten selectively without losing anything.
# ============================================================

import os
import json
import uuid
from datetime import datetime, timedelta, timezone
from typing import Any, Dict, List, Optional, Tuple

import requests
from lxml import etree

# If jwt import fails, run once:
# %pip install pyjwt cryptography
import jwt

from pyspark.sql import Row
from pyspark.sql import functions as F
from pyspark.sql.types import (
    StructType, StructField, StringType, TimestampType, LongType
)

# -----------------------------
# 0) CONFIG (matches your header pattern)
# -----------------------------
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
RM_VERSION = os.getenv("WORKDAY_RM_VERSION", HR_VERSION)

HTTP_TIMEOUT = int(os.getenv("WORKDAY_HTTP_TIMEOUT", "120"))

# Paging
PAGE_SIZE = int(os.getenv("WORKDAY_RM_PAGE_SIZE", "200"))
MAX_PAGES = int(os.getenv("WORKDAY_RM_MAX_PAGES", "2000"))  # safety cap

# Target Lakehouse (adjust schema if you want)
TARGET_DB = os.getenv("WORKDAY_TARGET_DB", "data_central_lh")

TBL_RAW  = f"{TARGET_DB}.workday_rm_customer_invoices_raw_bronze"
TBL_HDR  = f"{TARGET_DB}.workday_rm_customer_invoices_hdr_bronze"
TBL_LINE = f"{TARGET_DB}.workday_rm_customer_invoices_line_bronze"
TBL_WT   = f"{TARGET_DB}.workday_rm_customer_invoices_line_worktags_bronze"

# Key file paths (same pattern you referenced earlier)
KEY_CANDIDATES = [
    "/lakehouse/data_central_lh/Files/workday_integration.key",
    "/lakehouse/default/Files/workday_integration.key",
]
env_key_path = os.getenv("WORKDAY_PRIVATE_KEY_PATH", "").strip()
if env_key_path:
    KEY_CANDIDATES.insert(0, env_key_path)

NS = {"wd": "urn:com.workday/bsvc"}

# -----------------------------
# 1) Auth helpers (ISU JWT Bearer)
# -----------------------------
_token_cache = {"token": None, "expires": datetime.min.replace(tzinfo=timezone.utc)}

def load_private_key_pem() -> str:
    for p in KEY_CANDIDATES:
        if p and os.path.exists(p):
            with open(p, "r", encoding="utf-8") as f:
                return f.read()
    raise FileNotFoundError("Workday private key not found. Tried:\n" + "\n".join(KEY_CANDIDATES))

def build_jwt_assertion(private_key_pem: str) -> str:
    now = datetime.now(timezone.utc)
    token_url = f"{HOST}/ccx/oauth2/{TENANT}/token"
    payload = {
        "iss": CLIENT_ID,
        "sub": ISU_SUBJECT,
        "aud": token_url,
        "iat": int(now.timestamp()),
        "exp": int((now + timedelta(minutes=5)).timestamp()),
        "jti": str(uuid.uuid4()),
    }
    return jwt.encode(payload, private_key_pem, algorithm="RS256")

def get_access_token() -> str:
    now = datetime.now(timezone.utc)
    if _token_cache["token"] and now < _token_cache["expires"]:
        return _token_cache["token"]

    private_key_pem = load_private_key_pem()
    assertion = build_jwt_assertion(private_key_pem)

    token_url = f"{HOST}/ccx/oauth2/{TENANT}/token"
    data = {
        "grant_type": "urn:ietf:params:oauth:grant-type:jwt-bearer",
        "assertion": assertion,
    }

    resp = requests.post(token_url, data=data, timeout=HTTP_TIMEOUT)
    resp.raise_for_status()
    tok = resp.json()

    access_token = tok["access_token"]
    expires_in = int(tok.get("expires_in", 3600))

    _token_cache["token"] = access_token
    _token_cache["expires"] = now + timedelta(seconds=expires_in - 60)
    return access_token

# -----------------------------
# 2) SOAP request + fetch
# -----------------------------
def build_soap_request(page: int, count: int) -> str:
    return f"""
    <soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/"
                      xmlns:wd="urn:com.workday/bsvc">
      <soapenv:Body>
        <wd:Get_Customer_Invoices_Request wd:version="{RM_VERSION}">
          <wd:Response_Filter>
            <wd:Page>{page}</wd:Page>
            <wd:Count>{count}</wd:Count>
          </wd:Response_Filter>
        </wd:Get_Customer_Invoices_Request>
      </soapenv:Body>
    </soapenv:Envelope>
    """.strip()

def fetch_customer_invoices_xml(session: requests.Session, page: int, count: int) -> str:
    endpoint = f"{HOST}/ccx/service/{TENANT}/Revenue_Management/{RM_VERSION}"
    payload = build_soap_request(page, count)
    r = session.post(endpoint, data=payload, timeout=HTTP_TIMEOUT)
    r.raise_for_status()
    return r.text

# -----------------------------
# 3) XML → dict helpers (keeps *everything*)
# -----------------------------
def _local(tag: str) -> str:
    return tag.split("}", 1)[1] if tag and tag.startswith("{") else tag

def elem_to_obj(elem: etree._Element) -> Any:
    """
    Convert XML element to a JSON-serializable object.
    - Attributes are stored under "@"
    - Text under "#text" (only if meaningful)
    - Child elements grouped; repeated tags become lists
    """
    obj: Dict[str, Any] = {}

    # attrs
    if elem.attrib:
        # keep attribute names as-is (including namespaced ones)
        obj["@"] = {k: v for k, v in elem.attrib.items()}

    # children
    children = list(elem)
    if children:
        grouped: Dict[str, List[Any]] = {}
        for ch in children:
            k = _local(ch.tag)
            grouped.setdefault(k, []).append(elem_to_obj(ch))
        for k, vals in grouped.items():
            obj[k] = vals[0] if len(vals) == 1 else vals

    # text
    txt = (elem.text or "").strip()
    if txt and (children or elem.attrib):
        obj["#text"] = txt
    elif txt and not children and not elem.attrib:
        return txt  # leaf text only

    return obj

def find_first_id(invoice_elem: etree._Element) -> Optional[str]:
    # Try common places for invoice identifier
    # 1) Customer_Invoice_ID (text)
    cid = invoice_elem.find(".//wd:Customer_Invoice_ID", NS)
    if cid is not None and (cid.text or "").strip():
        return cid.text.strip()

    # 2) Customer_Invoice_Reference/ID of any type (prefer WID if present)
    ref_ids = invoice_elem.findall(".//wd:Customer_Invoice_Reference/wd:ID", NS)
    if ref_ids:
        wid = None
        for i in ref_ids:
            t = i.get(f'{{{NS["wd"]}}}type') or i.get("type")
            v = (i.text or "").strip()
            if not v:
                continue
            if t == "WID":
                wid = v
                break
        return wid or (ref_ids[0].text or "").strip() or None

    return None

def extract_text(invoice_data: etree._Element, tag_name: str) -> Optional[str]:
    e = invoice_data.find(f"./wd:{tag_name}", NS)
    if e is None:
        return None
    t = (e.text or "").strip()
    return t if t else None

def extract_ref_ids(ref_elem: etree._Element) -> List[Dict[str, str]]:
    """
    Return all IDs under a *_Reference element as list of dicts:
      [{"type": "...", "value":"..."}]
    """
    out = []
    if ref_elem is None:
        return out
    ids = ref_elem.findall("./wd:ID", NS)
    for i in ids:
        v = (i.text or "").strip()
        if not v:
            continue
        t = i.get(f'{{{NS["wd"]}}}type') or i.get("type") or ""
        out.append({"type": t, "value": v})
    return out

def safe_json(obj: Any) -> str:
    return json.dumps(obj, ensure_ascii=False, separators=(",", ":"), default=str)

# -----------------------------
# 4) Parse page into rows for 4 tables
# -----------------------------
def parse_customer_invoices(xml_text: str, pulled_at_utc: datetime, page_num: int) -> Tuple[List[Row], List[Row], List[Row], List[Row]]:
    """
    Returns: raw_rows, hdr_rows, line_rows, worktag_rows
    """
    root = etree.fromstring(xml_text.encode("utf-8"))

    invoices = root.findall(".//wd:Customer_Invoice", NS)
    raw_rows: List[Row] = []
    hdr_rows: List[Row] = []
    line_rows: List[Row] = []
    wt_rows: List[Row] = []

    # RAW table row (one per page pull)
    raw_rows.append(Row(
        pulled_at_utc=pulled_at_utc,
        tenant=TENANT,
        rm_version=RM_VERSION,
        page_num=page_num,
        page_size=PAGE_SIZE,
        raw_xml=xml_text
    ))

    for inv in invoices:
        inv_data = inv.find("./wd:Customer_Invoice_Data", NS)
        if inv_data is None:
            continue

        invoice_id = find_first_id(inv) or extract_text(inv_data, "Customer_Invoice_ID")
        invoice_number = extract_text(inv_data, "Invoice_Number")
        invoice_date = extract_text(inv_data, "Invoice_Date")

        # Some common references you’ll likely want as join keys
        company_ref = inv_data.find("./wd:Company_Reference", NS)
        customer_ref = inv_data.find("./wd:Customer_Reference", NS)

        company_ids = extract_ref_ids(company_ref)
        customer_ids = extract_ref_ids(customer_ref)

        # HEADER JSON = entire Customer_Invoice_Data minus nothing (store all)
        hdr_obj = elem_to_obj(inv_data)
        hdr_rows.append(Row(
            pulled_at_utc=pulled_at_utc,
            tenant=TENANT,
            rm_version=RM_VERSION,
            invoice_id=invoice_id,
            invoice_number=invoice_number,
            invoice_date=invoice_date,
            company_ids_json=safe_json(company_ids),
            customer_ids_json=safe_json(customer_ids),
            header_json=safe_json(hdr_obj)
        ))

        # LINE replacement data (0..n per invoice)
        # Workday returns this element as repeating blocks
        line_blocks = inv_data.findall("./wd:Customer_Invoice_Line_Replacement_Data", NS)

        for idx, lb in enumerate(line_blocks):
            line_obj = elem_to_obj(lb)

            # useful keys if present
            line_ref = lb.find("./wd:Customer_Invoice_Line_Reference", NS)
            line_ref_ids = extract_ref_ids(line_ref)

            rev_cat_ref = lb.find("./wd:Revenue_Category_Reference", NS)
            rev_cat_ids = extract_ref_ids(rev_cat_ref)

            origins_ref = lb.find("./wd:Origins_Reference", NS)
            origins_ids = extract_ref_ids(origins_ref)

            # line reference id (if there is an explicit *_ID element in block)
            line_ref_id_text = None
            t = lb.find("./wd:Customer_Invoice_Line_Reference_ID", NS)
            if t is not None and (t.text or "").strip():
                line_ref_id_text = t.text.strip()

            line_rows.append(Row(
                pulled_at_utc=pulled_at_utc,
                tenant=TENANT,
                rm_version=RM_VERSION,
                invoice_id=invoice_id,
                invoice_number=invoice_number,
                line_index=idx,
                customer_invoice_line_reference_id=line_ref_id_text,
                line_ref_ids_json=safe_json(line_ref_ids),
                revenue_category_ids_json=safe_json(rev_cat_ids),
                origins_ids_json=safe_json(origins_ids),
                line_json=safe_json(line_obj)
            ))

            # WORKTAGS explosion (0..n per line)
            # Worktags_Reference can appear multiple times
            wt_refs = lb.findall("./wd:Worktags_Reference", NS)
            for wt_ref in wt_refs:
                for item in extract_ref_ids(wt_ref):
                    wt_rows.append(Row(
                        pulled_at_utc=pulled_at_utc,
                        tenant=TENANT,
                        rm_version=RM_VERSION,
                        invoice_id=invoice_id,
                        invoice_number=invoice_number,
                        line_index=idx,
                        worktag_type=item.get("type", ""),
                        worktag_value=item.get("value", "")
                    ))

    return raw_rows, hdr_rows, line_rows, wt_rows

# -----------------------------
# 5) Spark write helpers (create tables automatically)
# -----------------------------
raw_schema = StructType([
    StructField("pulled_at_utc", TimestampType(), False),
    StructField("tenant", StringType(), True),
    StructField("rm_version", StringType(), True),
    StructField("page_num", LongType(), True),
    StructField("page_size", LongType(), True),
    StructField("raw_xml", StringType(), True),
])

hdr_schema = StructType([
    StructField("pulled_at_utc", TimestampType(), False),
    StructField("tenant", StringType(), True),
    StructField("rm_version", StringType(), True),
    StructField("invoice_id", StringType(), True),
    StructField("invoice_number", StringType(), True),
    StructField("invoice_date", StringType(), True),  # keep string; cast later if needed
    StructField("company_ids_json", StringType(), True),
    StructField("customer_ids_json", StringType(), True),
    StructField("header_json", StringType(), True),
])

line_schema = StructType([
    StructField("pulled_at_utc", TimestampType(), False),
    StructField("tenant", StringType(), True),
    StructField("rm_version", StringType(), True),
    StructField("invoice_id", StringType(), True),
    StructField("invoice_number", StringType(), True),
    StructField("line_index", LongType(), True),
    StructField("customer_invoice_line_reference_id", StringType(), True),
    StructField("line_ref_ids_json", StringType(), True),
    StructField("revenue_category_ids_json", StringType(), True),
    StructField("origins_ids_json", StringType(), True),
    StructField("line_json", StringType(), True),
])

wt_schema = StructType([
    StructField("pulled_at_utc", TimestampType(), False),
    StructField("tenant", StringType(), True),
    StructField("rm_version", StringType(), True),
    StructField("invoice_id", StringType(), True),
    StructField("invoice_number", StringType(), True),
    StructField("line_index", LongType(), True),
    StructField("worktag_type", StringType(), True),
    StructField("worktag_value", StringType(), True),
])

def append_rows_to_table(rows: List[Row], schema: StructType, table_name: str):
    if not rows:
        return
    df = spark.createDataFrame(rows, schema=schema)
    df.write.format("delta").mode("append").saveAsTable(table_name)

# -----------------------------
# 6) Main pull loop
# -----------------------------
def run_full_load():
    token = get_access_token()
    sess = requests.Session()
    sess.headers.update({
        "Authorization": f"Bearer {token}",
        "Accept": "text/xml, application/xml",
        "Content-Type": "text/xml; charset=utf-8",
    })

    total_invoices = 0
    total_lines = 0
    total_worktags = 0

    pulled_at_utc = datetime.utcnow()

    for page in range(1, MAX_PAGES + 1):
        xml_text = fetch_customer_invoices_xml(sess, page, PAGE_SIZE)

        raw_rows, hdr_rows, line_rows, wt_rows = parse_customer_invoices(xml_text, pulled_at_utc, page)

        # If Workday returns empty invoices, stop
        # (We detect it by checking parsed hdr_rows; raw_rows always has 1 row)
        if not hdr_rows:
            print(f"[INFO] No invoices found on page {page}. Stopping.")
            break

        append_rows_to_table(raw_rows, raw_schema, TBL_RAW)
        append_rows_to_table(hdr_rows, hdr_schema, TBL_HDR)
        append_rows_to_table(line_rows, line_schema, TBL_LINE)
        append_rows_to_table(wt_rows, wt_schema, TBL_WT)

        total_invoices += len(hdr_rows)
        total_lines += len(line_rows)
        total_worktags += len(wt_rows)

        if page % 10 == 0:
            print(f"[INFO] Page {page}: invoices={total_invoices}, lines={total_lines}, worktags={total_worktags}")

    print("====================================================")
    print("[DONE] Full load completed")
    print(f"Invoices written : {total_invoices}")
    print(f"Lines written    : {total_lines}")
    print(f"Worktags written : {total_worktags}")
    print("Tables:")
    print(" -", TBL_RAW)
    print(" -", TBL_HDR)
    print(" -", TBL_LINE)
    print(" -", TBL_WT)

# Execute
run_full_load()


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

import os
from collections import Counter, defaultdict
from lxml import etree
import pandas as pd

NS = {"wd": "urn:com.workday/bsvc"}

RESULTS_DIR = "/lakehouse/default/Files/workday_invoices/schema_probe/results"
RAW_XML_DIR = "/lakehouse/default/Files/workday_invoices/schema_probe/raw_xml"

def local_name(tag: str) -> str:
    if not tag:
        return ""
    return tag.split("}", 1)[1] if tag.startswith("{") else tag

def is_leaf(elem) -> bool:
    return not any(isinstance(ch.tag, str) for ch in elem)

def leaf_paths_under(root_elem, stop_at="Customer_Invoice_Data"):
    out = []
    for e in root_elem.iter():
        if e is root_elem:
            continue
        if not is_leaf(e):
            continue

        # build a simple relative path under stop_at
        parts = []
        cur = e
        while cur is not None and cur is not root_elem:
            parts.append(local_name(cur.tag))
            if local_name(cur.tag) == stop_at:
                break
            cur = cur.getparent()
        parts.reverse()
        if stop_at in parts:
            parts = parts[parts.index(stop_at):]
        out.append("/".join(parts))
    return out

header_leaf_once_counter = Counter()
header_leaf_repeat_counter = Counter()
line_leaf_counter = Counter()
top_repeating_counter = Counter()

xml_files = sorted([os.path.join(RAW_XML_DIR, f) for f in os.listdir(RAW_XML_DIR) if f.endswith(".xml")])
if not xml_files:
    raise ValueError(f"No XML files found in {RAW_XML_DIR}. Make sure SAVE_RAW_XML=True in the probe.")

invoice_seen = 0

for xf in xml_files:
    with open(xf, "r", encoding="utf-8") as f:
        xml_text = f.read()

    root = etree.fromstring(xml_text.encode("utf-8"))
    invoices = root.findall(".//wd:Customer_Invoice", NS)

    for inv in invoices:
        inv_data = inv.find("./wd:Customer_Invoice_Data", NS)
        if inv_data is None:
            continue

        # HEADER LEAVES = leaf paths that are NOT under Customer_Invoice_Line_Replacement_Data
        # We do this by counting occurrences per invoice
        per_invoice_leaf_counts = Counter()

        # collect all leaf paths
        all_leafs = leaf_paths_under(inv_data, stop_at="Customer_Invoice_Data")
        for p in all_leafs:
            per_invoice_leaf_counts[p] += 1

        # split header vs line by path prefix
        for pth, cnt in per_invoice_leaf_counts.items():
            if pth.startswith("Customer_Invoice_Line_Replacement_Data/"):
                line_leaf_counter[pth] += cnt
                top_repeating_counter[pth] += cnt
            else:
                if cnt == 1:
                    header_leaf_once_counter[pth] += 1
                else:
                    header_leaf_repeat_counter[pth] += 1
                    top_repeating_counter[pth] += cnt

        invoice_seen += 1

print(f"[INFO] Processed invoices in raw xml: {invoice_seen}")

# Build outputs
header_once_df = pd.DataFrame(
    [{"leaf_xml_path": k, "invoices_with_path_once": v} for k, v in header_leaf_once_counter.most_common()]
)
header_repeat_df = pd.DataFrame(
    [{"leaf_xml_path": k, "invoices_with_path_repeating": v} for k, v in header_leaf_repeat_counter.most_common()]
)
line_df = pd.DataFrame(
    [{"leaf_xml_path": k, "total_occurrences": v} for k, v in line_leaf_counter.most_common()]
)
repeating_df = pd.DataFrame(
    [{"leaf_xml_path": k, "total_occurrences": v} for k, v in top_repeating_counter.most_common(100)]
)

# Save
os.makedirs(RESULTS_DIR, exist_ok=True)
header_once_path = os.path.join(RESULTS_DIR, "invoice_header_leaf_paths.csv")
header_repeat_path = os.path.join(RESULTS_DIR, "invoice_header_repeating_leaf_paths.csv")
line_path = os.path.join(RESULTS_DIR, "invoice_line_leaf_paths.csv")
repeat_path = os.path.join(RESULTS_DIR, "top_repeating_paths.csv")

header_once_df.to_csv(header_once_path, index=False)
header_repeat_df.to_csv(header_repeat_path, index=False)
line_df.to_csv(line_path, index=False)
repeating_df.to_csv(repeat_path, index=False)

print("[INFO] Saved:")
print(" -", header_once_path)
print(" -", header_repeat_path)
print(" -", line_path)
print(" -", repeat_path)


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

import pandas as pd
# Load data into pandas DataFrame from "/lakehouse/default/Files/workday_invoices/schema_probe/results/invoice_header_leaf_paths.csv"
df = pd.read_csv("/lakehouse/default/Files/workday_invoices/schema_probe/results/invoice_header_leaf_paths.csv")
display(df)


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

import pandas as pd
# Load data into pandas DataFrame from "/lakehouse/default/Files/workday_invoices/schema_probe/results/invoice_header_repeating_leaf_paths.csv"
df = pd.read_csv("/lakehouse/default/Files/workday_invoices/schema_probe/results/invoice_header_repeating_leaf_paths.csv")
display(df)


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

import pandas as pd
# Load data into pandas DataFrame from "/lakehouse/default/Files/workday_invoices/schema_probe/results/invoice_line_leaf_paths.csv"
df = pd.read_csv("/lakehouse/default/Files/workday_invoices/schema_probe/results/invoice_line_leaf_paths.csv")
display(df)


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

import pandas as pd
# Load data into pandas DataFrame from "/lakehouse/default/Files/workday_invoices/schema_probe/results/leaf_paths.csv"
df = pd.read_csv("/lakehouse/default/Files/workday_invoices/schema_probe/results/leaf_paths.csv")
display(df)


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

import os
import time
import json
import uuid
from datetime import datetime, timedelta, timezone
from collections import Counter

import requests
from lxml import etree
import pandas as pd

# If PyJWT isn't installed in your environment, install once:
# %pip install pyjwt cryptography
import jwt


# =========================================================
# 1) Header / Env settings (matches what you shared)
# =========================================================
HOST = os.getenv("WORKDAY_HOST", "https://services1.wd503.myworkday.com").rstrip("/")
TENANT = os.getenv("WORKDAY_TENANT", "stevenstransport")

from notebookutils import mssparkutils

# --- Read secrets from Azure Key Vault ---
CLIENT_ID = mssparkutils.credentials.getSecret(
    "https://keyvault-fabric2.vault.azure.net/",
    "WORKDAYCLIENTID"
)
ISU_SUBJECT = os.getenv("WORKDAY_ISU_SUBJECT", "ISU_Ms_Fabric")

# Use HR_VERSION as your default version var (you can override to RM_VERSION below if needed)
HR_VERSION = os.getenv("WORKDAY_HR_VERSION", "v45.0")
RM_VERSION = os.getenv("WORKDAY_RM_VERSION", HR_VERSION)

HTTP_TIMEOUT = int(os.getenv("WORKDAY_HTTP_TIMEOUT", "120"))

# Workday XML namespace
NS = {"wd": "urn:com.workday/bsvc"}


# =========================================================
# 2) Where the private key is (same pattern you referenced)
# =========================================================
KEY_CANDIDATES = [
    "/lakehouse/data_central_lh/Files/workday_integration.key",
    "/lakehouse/default/Files/workday_integration.key",
    os.getenv("WORKDAY_PRIVATE_KEY_PATH", "").strip() or None,
]
KEY_CANDIDATES = [p for p in KEY_CANDIDATES if p]  # remove None/empty


def load_private_key_pem() -> str:
    for p in KEY_CANDIDATES:
        if p and os.path.exists(p):
            with open(p, "r", encoding="utf-8") as f:
                return f.read()
    raise FileNotFoundError(
        "Could not find Workday private key file. Tried:\n" + "\n".join(KEY_CANDIDATES)
    )


# =========================================================
# 3) JWT Bearer token flow for Workday OAuth
# =========================================================
_token_cache = {"token": None, "expires": datetime.min.replace(tzinfo=timezone.utc)}


def build_jwt_assertion(private_key_pem: str) -> str:
    """
    Workday JWT bearer: typical claims:
      iss = client_id
      sub = ISU subject
      aud = token endpoint
      iat/exp, jti
    """
    now = datetime.now(timezone.utc)
    token_url = f"{HOST}/ccx/oauth2/{TENANT}/token"

    payload = {
        "iss": CLIENT_ID,
        "sub": ISU_SUBJECT,
        "aud": token_url,
        "iat": int(now.timestamp()),
        "exp": int((now + timedelta(minutes=5)).timestamp()),  # short-lived assertion
        "jti": str(uuid.uuid4()),
    }

    # RS256 is the common Workday setup when using a private key
    assertion = jwt.encode(payload, private_key_pem, algorithm="RS256")
    return assertion


def get_access_token() -> str:
    global _token_cache

    now = datetime.now(timezone.utc)
    if _token_cache["token"] and now < _token_cache["expires"]:
        return _token_cache["token"]

    private_key_pem = load_private_key_pem()
    assertion = build_jwt_assertion(private_key_pem)

    token_url = f"{HOST}/ccx/oauth2/{TENANT}/token"
    data = {
        "grant_type": "urn:ietf:params:oauth:grant-type:jwt-bearer",
        "assertion": assertion,
    }

    resp = requests.post(token_url, data=data, timeout=HTTP_TIMEOUT)
    resp.raise_for_status()
    tok = resp.json()

    access_token = tok["access_token"]
    expires_in = int(tok.get("expires_in", 3600))
    _token_cache["token"] = access_token
    _token_cache["expires"] = now + timedelta(seconds=expires_in - 60)
    return access_token


# =========================================================
# 4) SOAP request builder + fetcher (Customer Invoices)
# =========================================================
def build_soap_request(page: int, count: int) -> str:
    # Keep minimal. Add filters later (date range, updated-since, etc.)
    return f"""
    <soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/"
                      xmlns:wd="urn:com.workday/bsvc">
      <soapenv:Body>
        <wd:Get_Customer_Invoices_Request wd:version="{RM_VERSION}">
          <wd:Response_Filter>
            <wd:Page>{page}</wd:Page>
            <wd:Count>{count}</wd:Count>
          </wd:Response_Filter>
        </wd:Get_Customer_Invoices_Request>
      </soapenv:Body>
    </soapenv:Envelope>
    """.strip()


def fetch_customer_invoices_xml(session: requests.Session, page: int, count: int) -> str:
    endpoint = f"{HOST}/ccx/service/{TENANT}/Revenue_Management/{RM_VERSION}"
    payload = build_soap_request(page, count)
    resp = session.post(endpoint, data=payload, timeout=HTTP_TIMEOUT)
    resp.raise_for_status()
    return resp.text


# =========================================================
# 5) XML path probing helpers
# =========================================================
def local_name(tag: str) -> str:
    if not tag:
        return ""
    if tag.startswith("{"):
        return tag.split("}", 1)[1]
    return tag


def path_from(root, elem, stop_at_local="Customer_Invoice_Data") -> str:
    parts = []
    cur = elem
    while cur is not None and cur is not root:
        parts.append(local_name(cur.tag))
        if local_name(cur.tag) == stop_at_local:
            break
        cur = cur.getparent()
    parts.reverse()
    if stop_at_local in parts:
        parts = parts[parts.index(stop_at_local):]
    return "/".join(parts)


def parse_root(xml_text: str):
    return etree.fromstring(xml_text.encode("utf-8"))


# =========================================================
# 6) Run probe
# =========================================================
PROBE_PAGES = int(os.getenv("WORKDAY_PROBE_PAGES", "3"))
PROBE_PAGE_SIZE = int(os.getenv("WORKDAY_PROBE_PAGE_SIZE", "5"))
SAMPLE_INVOICE_LIMIT = int(os.getenv("WORKDAY_SAMPLE_INVOICE_LIMIT", "25"))

SAVE_RAW_XML = os.getenv("WORKDAY_SAVE_RAW_XML", "true").lower() == "true"
RAW_XML_DIR = os.getenv(
    "WORKDAY_RAW_XML_DIR", "/lakehouse/default/Files/workday_invoices/schema_probe/raw_xml"
)

SAVE_RESULTS = os.getenv("WORKDAY_SAVE_RESULTS", "true").lower() == "true"
RESULTS_DIR = os.getenv(
    "WORKDAY_RESULTS_DIR", "/lakehouse/default/Files/workday_invoices/schema_probe/results"
)


def run_probe():
    os.makedirs(RAW_XML_DIR, exist_ok=True)
    os.makedirs(RESULTS_DIR, exist_ok=True)

    token = get_access_token()

    session = requests.Session()
    session.headers.update(
        {
            "Authorization": f"Bearer {token}",
            "Accept": "text/xml, application/xml",
            "Content-Type": "text/xml; charset=utf-8",
        }
    )

    all_paths = Counter()
    leaf_paths = Counter()
    reference_id_types = Counter()
    reference_descriptor_presence = Counter()

    invoice_count = 0
    raw_files = []

    for p in range(1, PROBE_PAGES + 1):
        xml_text = fetch_customer_invoices_xml(session, p, PROBE_PAGE_SIZE)

        if SAVE_RAW_XML:
            raw_path = os.path.join(RAW_XML_DIR, f"customer_invoices_page_{p}_count_{PROBE_PAGE_SIZE}.xml")
            with open(raw_path, "w", encoding="utf-8") as f:
                f.write(xml_text)
            raw_files.append(raw_path)

        root = parse_root(xml_text)

        inv_elems = root.findall(".//wd:Customer_Invoice", NS)
        if not inv_elems:
            print(f"[WARN] No Customer_Invoice elements found on page {p}. Stopping.")
            break

        for inv in inv_elems:
            if invoice_count >= SAMPLE_INVOICE_LIMIT:
                break

            inv_data = inv.find("./wd:Customer_Invoice_Data", NS)
            if inv_data is None:
                continue

            for e in inv_data.iter():
                if e is inv_data:
                    continue

                pth = path_from(inv_data, e, stop_at_local="Customer_Invoice_Data")
                if not pth:
                    continue

                all_paths[pth] += 1

                has_element_children = any(isinstance(ch.tag, str) for ch in e)
                if not has_element_children:
                    leaf_paths[pth] += 1

                if local_name(e.tag).endswith("_Reference"):
                    if e.get("Descriptor") is not None:
                        reference_descriptor_presence[local_name(e.tag)] += 1

                    for id_elem in e.findall("./wd:ID", NS):
                        # Workday uses namespaced 'type' attribute on ID sometimes
                        type_attr = id_elem.get(f'{{{NS["wd"]}}}type') or id_elem.get("type")
                        if type_attr:
                            reference_id_types[type_attr] += 1

            invoice_count += 1

        if invoice_count >= SAMPLE_INVOICE_LIMIT:
            break

    print(f"[INFO] Inspected {invoice_count} invoices across up to {PROBE_PAGES} pages.")

    # Build outputs
    paths_df = pd.DataFrame([{"xml_path": k, "present_in_invoices_count": v} for k, v in all_paths.most_common()])
    leaf_df = pd.DataFrame([{"leaf_xml_path": k, "present_in_invoices_count": v} for k, v in leaf_paths.most_common()])
    id_types_df = pd.DataFrame([{"wd_type": k, "occurrences": v} for k, v in reference_id_types.most_common()])
    descriptor_df = pd.DataFrame(
        [{"reference_node": k, "descriptor_present_count": v} for k, v in reference_descriptor_presence.most_common()]
    )

    print("\n=== TOP 50 XML PATHS UNDER Customer_Invoice_Data ===")
    print(paths_df.head(50).to_string(index=False))

    print("\n=== TOP 50 LEAF XML PATHS (best candidates for columns) ===")
    print(leaf_df.head(50).to_string(index=False))

    print("\n=== Reference ID types observed (wd:type) ===")
    print(id_types_df.to_string(index=False))

    print("\n=== Reference nodes where Descriptor attr showed up ===")
    print(descriptor_df.to_string(index=False))

    if SAVE_RESULTS:
        paths_csv = os.path.join(RESULTS_DIR, "all_paths.csv")
        leaf_csv = os.path.join(RESULTS_DIR, "leaf_paths.csv")
        id_csv = os.path.join(RESULTS_DIR, "reference_id_types.csv")
        desc_csv = os.path.join(RESULTS_DIR, "descriptor_presence.csv")
        manifest_path = os.path.join(RESULTS_DIR, "probe_manifest.json")

        paths_df.to_csv(paths_csv, index=False)
        leaf_df.to_csv(leaf_csv, index=False)
        id_types_df.to_csv(id_csv, index=False)
        descriptor_df.to_csv(desc_csv, index=False)

        manifest = {
            "host": HOST,
            "tenant": TENANT,
            "rm_version": RM_VERSION,
            "client_id": CLIENT_ID,
            "isu_subject": ISU_SUBJECT,
            "inspected_invoices": invoice_count,
            "probe_pages": PROBE_PAGES,
            "probe_page_size": PROBE_PAGE_SIZE,
            "sample_invoice_limit": SAMPLE_INVOICE_LIMIT,
            "raw_xml_files": raw_files if SAVE_RAW_XML else [],
            "outputs": [paths_csv, leaf_csv, id_csv, desc_csv],
            "generated_utc": datetime.utcnow().isoformat() + "Z",
        }
        with open(manifest_path, "w", encoding="utf-8") as f:
            json.dump(manifest, f, indent=2)

        print(f"\n[INFO] Saved results to: {RESULTS_DIR}")
        print(f"[INFO] Manifest: {manifest_path}")


if __name__ == "__main__":
    run_probe()


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
