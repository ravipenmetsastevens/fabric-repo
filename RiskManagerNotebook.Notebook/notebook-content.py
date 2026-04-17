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

import os
import re
from datetime import datetime
from pyspark.sql import functions as F

SOURCE_TABLE = "data_central_lh.risk_manager_attachments_bronze"
OUT_DIR      = "/lakehouse/default/Files/risk_manager_attachments/"

# Used only if no state file exists yet
INITIAL_ATTACHRID = 1099296
BATCH_SIZE = 8000

# Log + state paths
LOG_DIR    = OUT_DIR + "_logs/"
LOG_FILE   = LOG_DIR + "export_log.csv"
STATE_FILE = OUT_DIR + "_state_last_attachrid.txt"

os.makedirs(LOG_DIR, exist_ok=True)

# Create log header if missing
if not os.path.exists(LOG_FILE):
    with open(LOG_FILE, "w") as f:
        f.write("timestamp,clmrid,attachrid,filename,target_path,status,error,bytes\n")

def get_resume_attachrid(state_file: str, fallback: int) -> int:
    """
    Read last successful ATTACHRID from state file.
    If state file is missing/blank/bad, use fallback.
    """
    if os.path.exists(state_file):
        try:
            with open(state_file, "r") as sf:
                content = sf.read().strip()
                if content:
                    return int(content)
        except Exception as e:
            print(f"Warning: could not read state file, using fallback {fallback}. Error: {e}")
    return fallback

def write_state(state_file: str, attachrid: int):
    with open(state_file, "w") as sf:
        sf.write(str(attachrid))

def clean_name(name: str) -> str:
    if not name:
        return ""
    name = name.replace("\\", "/").split("/")[-1]
    name = re.sub(r'[<>:"|?*\x00-\x1F]', "_", name).strip()
    return name

def split_base_ext(filename: str):
    if not filename:
        return ("", "")
    if "." in filename:
        base, ext = filename.rsplit(".", 1)
        return (base, "." + ext)
    return (filename, "")

# Dynamic resume point
LAST_DONE_ATTACHRID = get_resume_attachrid(STATE_FILE, INITIAL_ATTACHRID)
print("Starting from LAST_DONE_ATTACHRID =", LAST_DONE_ATTACHRID)

# 1) Fetch next batch of KEYS only
keys = (
    spark.read.table(SOURCE_TABLE)
    .select(
        F.col("CLMRID").cast("string").alias("clmrid"),
        F.col("ATTACHRID").cast("long").alias("attachrid"),
        F.col("FILENAME").cast("string").alias("filename")
    )
    .where(
        F.col("ATTACHRID").isNotNull() &
        (F.col("ATTACHRID").cast("long") > LAST_DONE_ATTACHRID)
    )
    .orderBy(F.col("ATTACHRID").cast("long"))
    .limit(BATCH_SIZE)
    .collect()
)

print("Fetched keys:", len(keys), "First attachrid:", keys[0]["attachrid"] if keys else None)

# Base DF with binary column
df_base = (
    spark.read.table(SOURCE_TABLE)
    .select(
        F.col("CLMRID").cast("string").alias("clmrid"),
        F.col("ATTACHRID").cast("long").alias("attachrid"),
        F.col("FILENAME").cast("string").alias("filename"),
        F.col("ATTACHMENT").alias("bin")
    )
    .where(F.col("ATTACHMENT").isNotNull())
)

ok = 0
fail = 0
skip = 0
last_success = LAST_DONE_ATTACHRID

for k in keys:
    clmrid = k["clmrid"]
    attachrid = k["attachrid"]
    filename = k["filename"]

    try:
        fname = clean_name(filename)
        if not fname:
            fname = f"ATTACH_{clmrid}_{attachrid}.bin"

        base, ext = split_base_ext(fname)
        if not ext:
            ext = ".bin"

        fname_final = f"{base}_{attachrid}{ext}"

        folder = os.path.join(OUT_DIR, f"CLMRID={clmrid}")
        os.makedirs(folder, exist_ok=True)

        path = os.path.join(folder, fname_final)

        # Skip if already exists
        if os.path.exists(path):
            skip += 1
            last_success = attachrid

            # Optional: advance checkpoint on skip too
            if (ok + skip) % 50 == 0:
                write_state(STATE_FILE, last_success)
                print(f"OK={ok} SKIP={skip} FAIL={fail} last_attachrid={last_success}")

            continue

        # Pull only this one attachment
        row = (
            df_base.where(F.col("attachrid") == attachrid)
                   .select("bin")
                   .limit(1)
                   .collect()
        )

        if not row:
            raise Exception("No binary found")

        data = row[0]["bin"]
        if data is None:
            raise Exception("Binary is null")

        with open(path, "wb") as f:
            f.write(data)

        ok += 1
        last_success = attachrid

        # Log success
        ts = datetime.utcnow().isoformat()
        with open(LOG_FILE, "a") as lf:
            lf.write(f"{ts},{clmrid},{attachrid},{fname},{path},OK,,{len(data)}\n")

        # Checkpoint every 50 processed successfully/skipped
        if (ok + skip) % 50 == 0:
            write_state(STATE_FILE, last_success)
            print(f"OK={ok} SKIP={skip} FAIL={fail} last_attachrid={last_success}")

    except Exception as e:
        fail += 1
        ts = datetime.utcnow().isoformat()
        err = str(e).replace("\n", " ").replace(",", " ")[:300]

        with open(LOG_FILE, "a") as lf:
            lf.write(f"{ts},{clmrid},{attachrid},{clean_name(filename)},,FAIL,{err},\n")

        if fail <= 20:
            print(f"FAIL attachrid={attachrid} err={err}")

# Final checkpoint
write_state(STATE_FILE, last_success)

print("DONE.")
print("OK   =", ok)
print("SKIP =", skip)
print("FAIL =", fail)
print("Last success ATTACHRID:", last_success)
print("Log file:", LOG_FILE)
print("State file:", STATE_FILE)

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }
