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


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

from pyspark.sql import functions as F

SOURCE_TABLE = "data_central_lh.risk_manager_attachments_bronze"

keys = (spark.read.table(SOURCE_TABLE)
        .select(F.col("CLMRID").cast("string").alias("clmrid"),
                F.col("ATTACHRID").cast("long").alias("attachrid"),
                F.col("FILENAME").cast("string").alias("filename"))
        .where(F.col("attachrid").isNotNull())
        .orderBy("attachrid")
        .limit(5000)   # start small
        .collect())

print("Keys fetched:", len(keys))
print(keys[0])

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

import os, re
from pyspark.sql import functions as F

OUT_DIR = "/lakehouse/default/Files/risk_manager_attachments/"

def clean_name(name: str) -> str:
    if not name:
        return ""
    name = name.replace("\\","/").split("/")[-1]
    name = re.sub(r'[<>:"|?*\x00-\x1F]', "_", name).strip()
    return name

def split_base_ext(filename: str):
    if not filename:
        return ("", "")
    if "." in filename:
        base, ext = filename.rsplit(".", 1)
        return (base, "." + ext)
    return (filename, "")

df_base = spark.read.table("data_central_lh.risk_manager_attachments_bronze") \
    .select(
        F.col("CLMRID").cast("string").alias("clmrid"),
        F.col("ATTACHRID").cast("long").alias("attachrid"),
        F.col("FILENAME").cast("string").alias("filename"),
        F.col("ATTACHMENT").alias("bin")
    ).where(F.col("bin").isNotNull())

ok = 0
fail = 0

for k in keys:
    try:
        clmrid = k["clmrid"]
        attachrid = k["attachrid"]
        fname = clean_name(k["filename"])
        if not fname:
            fname = f"ATTACH_{clmrid}_{attachrid}.bin"
        base, ext = split_base_ext(fname)
        if not ext:
            ext = ".bin"
        fname_final = f"{base}_{attachrid}{ext}"

        folder = os.path.join(OUT_DIR, f"CLMRID={clmrid}")
        os.makedirs(folder, exist_ok=True)
        path = os.path.join(folder, fname_final)

        # Pull JUST this one attachment (single row)
        row = (df_base.where(F.col("attachrid") == attachrid)
                      .select("bin")
                      .limit(1)
                      .collect())

        if not row:
            raise Exception("No binary found")

        with open(path, "wb") as f:
            f.write(row[0]["bin"])

        ok += 1
        if ok % 50 == 0:
            print(f"OK={ok} FAIL={fail} last_attachrid={attachrid}")
    except Exception as e:
        fail += 1
        if fail <= 20:
            print(f"FAIL attachrid={attachrid} err={str(e)[:200]}")

print("DONE. OK=", ok, "FAIL=", fail)

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
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

import pyodbc

SERVER = "lofzv5bdxbxepf3ufbs6kug4du-dpb5fjqdbnqezisyyjteyvx6hu.datawarehouse.fabric.microsoft.com"
DATABASE = "data_central_lh"

conn_str = (
    "Driver={ODBC Driver 18 for SQL Server};"
    f"Server={SERVER};"
    f"Database={DATABASE};"
    "Encrypt=yes;"
    "TrustServerCertificate=no;"
    "Authentication=ActiveDirectoryInteractive;"
)

cn = pyodbc.connect(conn_str)
cur = cn.cursor()

cur.execute("""
SELECT TOP 1 CLMRID, ATTACHRID, FILENAME, DATALENGTH(ATTACHMENT) AS bytes_len
FROM dbo.risk_manager_attachments_bronze
WHERE ATTACHMENT IS NOT NULL
ORDER BY ATTACHRID
""")

print(cur.fetchone())

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

# Fabric Notebook (PySpark)
# One-time export of hex (0x...) attachments from a Lakehouse/Warehouse table to OneLake Files

from pyspark.sql import functions as F
from pyspark.sql.types import StringType
import re
import os
import uuid

# -----------------------------
# 1) SETTINGS (edit these)
# -----------------------------
SOURCE_TABLE = "data_central_lh.risk_manager_attachments_bronze"   # <-- your table
OUT_DIR      = "/lakehouse/default/Files/risk_manager_attachments/"    # <-- output folder in Lakehouse Files

# OPTIONAL: Create subfolders by claim id (keeps files organized)
USE_CLAIM_SUBFOLDERS = True   # True -> /.../CLMRID=<id>/filename  ; False -> flat folder

# If filename is missing, use this extension as fallback
DEFAULT_EXT = ".bin"

# -----------------------------
# 2) READ SOURCE
# -----------------------------
df = spark.read.table(SOURCE_TABLE).select(
    F.col("CLMRID").cast("string").alias("clmrid"),
    F.col("ATTACHRID").cast("string").alias("attachrid"),
    F.col("FILENAME").cast("string").alias("filename"),
    F.col("ATTACHMENT").cast("string").alias("attachment_hex")
)

# Keep only rows that look like 0x....
df = df.filter(F.col("attachment_hex").isNotNull() & F.col("attachment_hex").startswith("0x"))

# -----------------------------
# 3) SANITIZE + ENSURE UNIQUE FILENAMES
# -----------------------------
def sanitize_filename(name: str) -> str:
    if not name:
        return ""
    # Remove any path pieces users might have stored (security + clean)
    name = name.replace("\\", "/").split("/")[-1]
    # Replace illegal characters
    name = re.sub(r'[<>:"|?*\x00-\x1F]', "_", name)
    name = name.strip()
    return name

sanitize_udf = F.udf(sanitize_filename, StringType())

df = df.withColumn("filename_clean", sanitize_udf(F.col("filename")))

# If filename is empty, generate one from keys
df = df.withColumn(
    "filename_clean",
    F.when(
        (F.col("filename_clean").isNull()) | (F.length(F.col("filename_clean")) == 0),
        F.concat(F.lit("ATTACH_"), F.col("clmrid"), F.lit("_"), F.col("attachrid"), F.lit(DEFAULT_EXT))
    ).otherwise(F.col("filename_clean"))
)

# Add attachrid suffix always to avoid collisions (safe for one-time migration)
# If you don't want suffixes, remove this.
df = df.withColumn(
    "filename_final",
    F.concat(
        F.regexp_replace(F.col("filename_clean"), r"(\.[^.]*)?$", ""),   # base name (strip extension)
        F.lit("_"),
        F.col("attachrid"),
        F.when(F.col("filename_clean").rlike(r"\.[^\.]+$"), F.regexp_extract(F.col("filename_clean"), r"(\.[^\.]+)$", 1))
         .otherwise(F.lit(DEFAULT_EXT))
    )
)

# -----------------------------
# 4) BUILD TARGET PATH (OneLake)
# -----------------------------
if USE_CLAIM_SUBFOLDERS:
    df = df.withColumn("target_path", F.concat(F.lit(OUT_DIR), F.lit("CLMRID="), F.col("clmrid"), F.lit("/"), F.col("filename_final")))
else:
    df = df.withColumn("target_path", F.concat(F.lit(OUT_DIR), F.col("filename_final")))

# -----------------------------
# 5) HEX -> BYTES AND WRITE FILES (DISTRIBUTED)
# -----------------------------
def hex_to_bytes(hex_str: str) -> bytes:
    # hex_str like "0x25504446..."
    if not hex_str:
        return b""
    s = hex_str[2:] if hex_str.startswith("0x") else hex_str
    # Remove any whitespace just in case
    s = re.sub(r"\s+", "", s)
    return bytes.fromhex(s)

def write_one_file(partition_rows):
    # Runs on executor
    for r in partition_rows:
        try:
            data = hex_to_bytes(r["attachment_hex"])
            # Ensure folder exists (only works reliably for local fs; OneLake uses virtual fs)
            # In Fabric, opening the full path under /lakehouse/default/Files works fine.
            with open(r["target_path"], "wb") as f:
                f.write(data)
            yield (r["clmrid"], r["attachrid"], r["target_path"], "OK", None)
        except Exception as e:
            yield (r["clmrid"], r["attachrid"], r["target_path"], "FAIL", str(e)[:500])

# Use mapPartitions to avoid driver memory issues and reduce overhead
result_rdd = df.select("clmrid", "attachrid", "attachment_hex", "target_path").rdd.mapPartitions(write_one_file)

result_df = spark.createDataFrame(result_rdd, schema="clmrid string, attachrid string, target_path string, status string, error string")

# -----------------------------
# 6) QUICK SUMMARY
# -----------------------------
display(result_df.groupBy("status").count())

# Optional: save a log table for audit
# result_df.write.mode("overwrite").saveAsTable("data_central_lh.dbo.risk_attachment_export_log")


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

from pyspark.sql import functions as F

SOURCE_TABLE = "data_central_lh.risk_manager_attachments_bronze"

df0 = spark.read.table(SOURCE_TABLE)
df0.printSchema()

# Show 5 rows with attachment preview (first 40 chars if string)
sample = (df0
          .select("CLMRID","ATTACHRID","FILENAME","ATTACHMENT")
          .limit(5))

display(sample)


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

from pyspark.sql import functions as F
import base64, os, re

SOURCE_TABLE = "data_central_lh.risk_manager_attachments_bronze"
OUT_DIR      = "/lakehouse/default/Files/_debug_write_test/"

df = spark.read.table(SOURCE_TABLE).select(
    F.col("CLMRID").cast("string").alias("clmrid"),
    F.col("ATTACHRID").cast("string").alias("attachrid"),
    F.col("FILENAME").cast("string").alias("filename"),
    F.col("ATTACHMENT").cast("string").alias("b64")
)

# Pick 1 likely-JPEG row (base64 starts with /9j/)
row = (df
       .where(F.col("b64").isNotNull() & F.col("b64").startswith("/9j/"))
       .limit(1)
       .collect())

if not row:
    raise Exception("No row found starting with '/9j/' (JPEG base64). We'll pick a different pattern next.")

r = row[0]

# Clean filename
fname = r["filename"] or f"ATTACH_{r['clmrid']}_{r['attachrid']}.jpg"
fname = fname.replace("\\","/").split("/")[-1]
fname = re.sub(r'[<>:"|?*\x00-\x1F]', "_", fname).strip()
if not fname.lower().endswith((".jpg",".jpeg")):
    fname = fname + ".jpg"

# Decode base64 -> bytes
data = base64.b64decode(r["b64"], validate=False)

# Write file
os.makedirs(OUT_DIR, exist_ok=True)
out_path = os.path.join(OUT_DIR, fname)
with open(out_path, "wb") as f:
    f.write(data)

print("Wrote:", out_path)
print("Bytes:", len(data))
print("Row keys:", {"CLMRID": r["clmrid"], "ATTACHRID": r["attachrid"], "FILENAME": r["filename"]})


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

from pyspark.sql import functions as F

SOURCE_TABLE = "data_central_lh.risk_manager_attachments_bronze"

df = spark.read.table(SOURCE_TABLE).select(
    F.col("CLMRID").cast("string").alias("clmrid"),
    F.col("ATTACHRID").cast("string").alias("attachrid"),
    F.col("FILENAME").cast("string").alias("filename"),
    F.col("ATTACHMENT").cast("string").alias("b64")
).where(F.col("b64").isNotNull())

# Show a few prefixes so we know what we're dealing with
probe = df.select(
    "clmrid","attachrid","filename",
    F.substring(F.trim(F.col("b64")), 1, 30).alias("b64_prefix"),
    F.length(F.trim(F.col("b64"))).alias("b64_len")
).limit(10)

display(probe)


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

from pyspark.sql import functions as F
import os, re

SOURCE_TABLE = "data_central_lh.risk_manager_attachments_bronze"
OUT_DIR = "/lakehouse/default/Files/_debug_write_test/"

df = spark.read.table(SOURCE_TABLE).select(
    F.col("CLMRID").cast("string").alias("clmrid"),
    F.col("ATTACHRID").cast("string").alias("attachrid"),
    F.col("FILENAME").cast("string").alias("filename"),
    F.col("ATTACHMENT").alias("binary_data")   # DO NOT cast to string
).where(F.col("binary_data").isNotNull())

row = df.limit(1).collect()[0]

# Clean filename
fname = row["filename"] or f"ATTACH_{row['clmrid']}_{row['attachrid']}.bin"
fname = fname.replace("\\","/").split("/")[-1]
fname = re.sub(r'[<>:"|?*\x00-\x1F]', "_", fname).strip()

# Ensure folder exists
os.makedirs(OUT_DIR, exist_ok=True)

out_path = os.path.join(OUT_DIR, fname)

# Write bytes directly
with open(out_path, "wb") as f:
    f.write(row["binary_data"])

print("Wrote:", out_path)
print("Bytes:", len(row["binary_data"]))


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

import binascii

path = "/lakehouse/default/Files/_debug_write_test/RE Claim 2025-310-002776.msg"

with open(path, "rb") as f:
    head = f.read(32)

print("First 32 bytes (hex):", binascii.hexlify(head).decode())
print("First 8 bytes:", head[:8])


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

from pyspark.sql import functions as F
import os, re, binascii

SOURCE_TABLE = "data_central_lh.risk_manager_attachments_bronze"
OUT_DIR = "/lakehouse/default/Files/_debug_write_test/"

df = spark.read.table(SOURCE_TABLE).select(
    F.col("CLMRID").cast("string").alias("clmrid"),
    F.col("ATTACHRID").cast("string").alias("attachrid"),
    F.col("FILENAME").cast("string").alias("filename"),
    F.col("ATTACHMENT").alias("binary_data")
).where(F.col("binary_data").isNotNull() & F.lower(F.col("filename")).endswith(".jpeg"))

r = df.limit(1).collect()[0]

fname = r["filename"].replace("\\","/").split("/")[-1]
fname = re.sub(r'[<>:"|?*\x00-\x1F]', "_", fname).strip()
out_path = os.path.join(OUT_DIR, fname)

with open(out_path, "wb") as f:
    f.write(r["binary_data"])

with open(out_path, "rb") as f:
    head = f.read(16)

print("Wrote:", out_path)
print("Header hex:", binascii.hexlify(head).decode())
print("Size:", len(r["binary_data"]))


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

from pyspark.sql import functions as F
import os, re

SOURCE_TABLE = "data_central_lh.risk_manager_attachments_bronze"
OUT_DIR      = "/lakehouse/default/Files/risk_manager_attachments/"
LOG_TABLE    = "data_central_lh.risk_attachment_export_log"  # change if you want

# ---------- helpers ----------
def clean_name(name: str) -> str:
    if not name:
        return ""
    name = name.replace("\\","/").split("/")[-1]
    name = re.sub(r'[<>:"|?*\x00-\x1F]', "_", name).strip()
    return name

def split_base_ext(filename: str):
    # returns (base, ext) where ext includes dot
    if not filename:
        return ("", "")
    if "." in filename:
        base, ext = filename.rsplit(".", 1)
        return (base, "." + ext)
    return (filename, "")

def write_partition(rows):
    for r in rows:
        clmrid    = r["clmrid"]
        attachrid = r["attachrid"]
        fname     = r["filename"]
        data      = r["binary_data"]

        try:
            fname = clean_name(fname)
            if not fname:
                fname = f"ATTACH_{clmrid}_{attachrid}.bin"

            base, ext = split_base_ext(fname)
            if not ext:
                ext = ".bin"

            # make unique
            fname_final = f"{base}_{attachrid}{ext}"

            # folder by CLMRID
            folder = os.path.join(OUT_DIR, f"CLMRID={clmrid}")
            os.makedirs(folder, exist_ok=True)

            path = os.path.join(folder, fname_final)

            with open(path, "wb") as f:
                f.write(data)

            yield (clmrid, attachrid, fname, path, "OK", None, len(data))
        except Exception as e:
            yield (clmrid, attachrid, fname, None, "FAIL", str(e)[:500], None)

# ---------- read data ----------
df = (spark.read.table(SOURCE_TABLE)
      .select(
          F.col("CLMRID").cast("string").alias("clmrid"),
          F.col("ATTACHRID").cast("string").alias("attachrid"),
          F.col("FILENAME").cast("string").alias("filename"),
          F.col("ATTACHMENT").alias("binary_data")   # keep binary
      )
      .where(F.col("binary_data").isNotNull())
)

# ---------- export ----------
rdd = df.rdd.mapPartitions(write_partition)

log_df = spark.createDataFrame(
    rdd,
    schema="clmrid string, attachrid string, source_filename string, target_path string, status string, error string, bytes long"
)

display(log_df.groupBy("status").count())

# Save log (overwrite for one-time run; use append if you prefer)
log_df.write.mode("overwrite").saveAsTable(LOG_TABLE)
print("Log saved to:", LOG_TABLE)
print("Output folder:", OUT_DIR)


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

from pyspark.sql import functions as F
import os, re

SOURCE_TABLE = "data_central_lh.risk_manager_attachments_bronze"
OUT_DIR      = "/lakehouse/default/Files/risk_manager_attachments/"

def clean_name(name: str) -> str:
    if not name:
        return ""
    name = name.replace("\\","/").split("/")[-1]
    name = re.sub(r'[<>:"|?*\x00-\x1F]', "_", name).strip()
    return name

def split_base_ext(filename: str):
    if not filename:
        return ("", "")
    if "." in filename:
        base, ext = filename.rsplit(".", 1)
        return (base, "." + ext)
    return (filename, "")

df = (spark.read.table(SOURCE_TABLE)
      .select(
          F.col("CLMRID").cast("string").alias("clmrid"),
          F.col("ATTACHRID").cast("string").alias("attachrid"),
          F.col("FILENAME").cast("string").alias("filename"),
          F.col("ATTACHMENT").alias("binary_data")
      )
      .where(F.col("binary_data").isNotNull())
      .orderBy("ATTACHRID")
      .limit(100)
)

rows = df.collect()

ok = 0
fail = 0

for r in rows:
    try:
        clmrid = r["clmrid"]
        attachrid = r["attachrid"]
        fname = clean_name(r["filename"])
        if not fname:
            fname = f"ATTACH_{clmrid}_{attachrid}.bin"

        base, ext = split_base_ext(fname)
        if not ext:
            ext = ".bin"

        fname_final = f"{base}_{attachrid}{ext}"

        folder = os.path.join(OUT_DIR, f"CLMRID={clmrid}")
        os.makedirs(folder, exist_ok=True)

        path = os.path.join(folder, fname_final)
        with open(path, "wb") as f:
            f.write(r["binary_data"])

        ok += 1
        if ok % 10 == 0:
            print(f"OK: {ok} files written...")
    except Exception as e:
        fail += 1
        print(f"FAIL attachrid={r['attachrid']} err={str(e)[:200]}")

print("DONE. OK =", ok, " FAIL =", fail)
print("Output folder:", OUT_DIR)


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

from notebookutils import mssparkutils
print("mssparkutils loaded:", mssparkutils)


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

from pyspark.sql import functions as F
import os, re

SOURCE_TABLE = "data_central_lh.risk_manager_attachments_bronze"
OUT_DIR      = "/lakehouse/default/Files/risk_manager_attachments/"

def clean_name(name: str) -> str:
    if not name:
        return ""
    name = name.replace("\\","/").split("/")[-1]
    name = re.sub(r'[<>:"|?*\x00-\x1F]', "_", name).strip()
    return name

def split_base_ext(filename: str):
    if not filename:
        return ("", "")
    if "." in filename:
        base, ext = filename.rsplit(".", 1)
        return (base, "." + ext)
    return (filename, "")

df = (spark.read.table(SOURCE_TABLE)
      .select(
          F.col("CLMRID").cast("string").alias("clmrid"),
          F.col("ATTACHRID").cast("string").alias("attachrid"),
          F.col("FILENAME").cast("string").alias("filename"),
          F.col("ATTACHMENT").alias("bin")   # keep binary
      )
      .where(F.col("bin").isNotNull())
      .orderBy(F.col("ATTACHRID").cast("long"))
      .repartition(1)   # IMPORTANT: avoid many partitions pushing big results concurrently
)

ok = 0
fail = 0

# Stream rows to driver without collecting everything
for r in df.toLocalIterator():
    try:
        clmrid    = r["clmrid"]
        attachrid = r["attachrid"]
        fname     = clean_name(r["filename"])

        if not fname:
            fname = f"ATTACH_{clmrid}_{attachrid}.bin"

        base, ext = split_base_ext(fname)
        if not ext:
            ext = ".bin"

        # unique filename
        fname_final = f"{base}_{attachrid}{ext}"

        folder = os.path.join(OUT_DIR, f"CLMRID={clmrid}")
        os.makedirs(folder, exist_ok=True)

        path = os.path.join(folder, fname_final)

        with open(path, "wb") as f:
            f.write(r["bin"])

        ok += 1
        if ok % 100 == 0:
            print(f"OK={ok}  FAIL={fail}  last={path}")
    except Exception as e:
        fail += 1
        if fail <= 20:
            print(f"FAIL attachrid={r['attachrid']} err={str(e)[:200]}")

print("DONE. OK =", ok, " FAIL =", fail)
print("Output folder:", OUT_DIR)


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }
