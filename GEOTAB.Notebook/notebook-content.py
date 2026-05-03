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

# Welcome to your new notebook
# Type here in the cell editor to add code!


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

import requests
import pandas as pd
import json
from datetime import datetime, timezone

# =========================================================
# CONFIG
# =========================================================

GEOTAB_USERNAME = "svc_fabric_geotab"
GEOTAB_PASSWORD = "Ns.p92JVK6Vd3dz"

GEOTAB_SERVER = "my.geotab.com"
api_url = f"https://{GEOTAB_SERVER}/apiv1"


# =========================================================
# HELPER: GEOTAB API CALL
# =========================================================

def geotab_call(method: str, params: dict, api_url: str):
    payload = {
        "method": method,
        "params": params
    }

    response = requests.post(api_url, json=payload, timeout=120)

    if response.status_code != 200:
        raise Exception(
            f"HTTP Error: {response.status_code}\nResponse: {response.text}"
        )

    data = response.json()

    if "error" in data:
        raise Exception(f"Geotab API Error: {json.dumps(data['error'], indent=2)}")

    return data.get("result")


# =========================================================
# STEP 1: AUTHENTICATE
# =========================================================

auth_result = geotab_call(
    method="Authenticate",
    params={
        "userName": GEOTAB_USERNAME,
        "password": GEOTAB_PASSWORD
    },
    api_url=api_url
)

credentials = auth_result["credentials"]

print("Authenticated successfully.")
print("Database returned:", credentials.get("database"))
print("User returned:", credentials.get("userName"))
print("Session ID returned:", credentials.get("sessionId")[:10] + "...")


# =========================================================
# STEP 2: HANDLE RETURNED PATH
# =========================================================

returned_path = auth_result.get("path")

if returned_path and returned_path.lower() != "thisserver":
    api_url = f"https://{returned_path}/apiv1"
    print("Using returned Geotab path:", returned_path)
else:
    print("Returned path is not a real server:", returned_path)
    print("Continuing with original server:", GEOTAB_SERVER)

print("Final API URL:", api_url)


# =========================================================
# STEP 3: GET ONLY A FEW DRIVER RECORDS
# =========================================================

drivers = geotab_call(
    method="Get",
    params={
        "typeName": "User",
        "credentials": credentials,
        "search": {
            "isDriver": True
        },
        "resultsLimit": 10
    },
    api_url=api_url
)

print("Driver records returned:", len(drivers))


# =========================================================
# STEP 4: FLATTEN SAMPLE DRIVER RECORDS
# =========================================================

driver_rows = []

for d in drivers:
    driver_rows.append({
        "driverId": d.get("id"),
        "driverLoginName": d.get("name"),
        "firstName": d.get("firstName"),
        "lastName": d.get("lastName"),
        "employeeNo": d.get("employeeNo"),
        "isDriver": d.get("isDriver"),
        "phoneNumber": d.get("phoneNumber"),
        "designation": d.get("designation"),
        "timeZoneId": d.get("timeZoneId"),
        "activeFrom": d.get("activeFrom"),
        "activeTo": d.get("activeTo"),
        "companyName": d.get("companyName"),
        "companyAddress": d.get("companyAddress"),
        "comment": d.get("comment"),
        "version": d.get("version"),
        "loadUtc": datetime.now(timezone.utc).isoformat()
    })

drivers_df = pd.DataFrame(driver_rows)

display(drivers_df)


# =========================================================
# STEP 5: OPTIONAL RAW JSON REVIEW
# =========================================================

if len(drivers) > 0:
    print("Sample raw driver record:")
    print(json.dumps(drivers[0], indent=2))
else:
    print("No driver records returned.")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

import requests
import pandas as pd
import json
from datetime import datetime, timezone

# =========================================================
# CONFIG
# =========================================================

GEOTAB_USERNAME = "svc_fabric_geotab"
GEOTAB_PASSWORD = "Ns.p92JVK6Vd3dz"

GEOTAB_SERVER = "my.geotab.com"
api_url = f"https://{GEOTAB_SERVER}/apiv1"


# =========================================================
# HELPER: GEOTAB API CALL
# =========================================================

def geotab_call(method: str, params: dict, api_url: str):
    payload = {
        "method": method,
        "params": params
    }

    response = requests.post(api_url, json=payload, timeout=120)

    if response.status_code != 200:
        raise Exception(
            f"HTTP Error: {response.status_code}\nResponse: {response.text}"
        )

    data = response.json()

    if "error" in data:
        raise Exception(json.dumps(data["error"], indent=2))

    return data.get("result")


# =========================================================
# STEP 1: AUTHENTICATE
# =========================================================

auth_result = geotab_call(
    method="Authenticate",
    params={
        "userName": GEOTAB_USERNAME,
        "password": GEOTAB_PASSWORD
    },
    api_url=api_url
)

credentials = auth_result["credentials"]

print("Authenticated successfully.")
print("Database returned:", credentials.get("database"))
print("User returned:", credentials.get("userName"))
print("Session ID returned:", credentials.get("sessionId")[:10] + "...")


# =========================================================
# STEP 2: HANDLE RETURNED PATH
# =========================================================

returned_path = auth_result.get("path")

if returned_path and returned_path.lower() != "thisserver":
    api_url = f"https://{returned_path}/apiv1"
    print("Using returned Geotab path:", returned_path)
else:
    print("Returned path is not a real server:", returned_path)
    print("Continuing with original server:", GEOTAB_SERVER)

print("Final API URL:", api_url)


# =========================================================
# STEP 3: OBJECTS TO PROBE
# =========================================================
# Start with common MyGeotab objects.
# We use resultsLimit = 1 to avoid heavy pulls.

object_types = [
    # Core master/reference data
    "User",
    "Device",
    "Group",
    "Zone",
    "ZoneType",
    "Rule",
    "Diagnostic",
    "FailureMode",
    "Source",
    "Controller",
    "UnitOfMeasure",
    
    # Driver / vehicle operational data
    "DriverChange",
    "Trip",
    "LogRecord",
    "StatusData",
    "FaultData",
    "ExceptionEvent",
    
    # Fuel / maintenance / inspection
    "FuelTransaction",
    "FuelTaxDetail",
    "DVIRLog",
    "DutyStatusLog",
    "AnnotationLog",
    
    # Text / messaging / notes
    "TextMessage",
    "Route",
    "RoutePlan",
    
    # Other useful entities
    "Trailer",
    "ShipmentLog",
    "IoxAddOn",
    "CustomData",
    "MediaFile"
]


# =========================================================
# STEP 4: PROBE EACH OBJECT
# =========================================================

probe_results = []

for type_name in object_types:
    print(f"Checking: {type_name}")

    try:
        result = geotab_call(
            method="Get",
            params={
                "typeName": type_name,
                "credentials": credentials,
                "resultsLimit": 1
            },
            api_url=api_url
        )

        has_data = len(result) > 0

        sample_keys = []
        sample_id = None

        if has_data:
            sample_record = result[0]
            sample_keys = list(sample_record.keys())
            sample_id = sample_record.get("id")

        probe_results.append({
            "objectType": type_name,
            "status": "Success",
            "hasData": has_data,
            "sampleRecordCount": len(result),
            "sampleId": sample_id,
            "sampleColumns": ", ".join(sample_keys[:25]),
            "errorMessage": None,
            "checkedUtc": datetime.now(timezone.utc).isoformat()
        })

    except Exception as e:
        probe_results.append({
            "objectType": type_name,
            "status": "Error",
            "hasData": False,
            "sampleRecordCount": None,
            "sampleId": None,
            "sampleColumns": None,
            "errorMessage": str(e)[:1000],
            "checkedUtc": datetime.now(timezone.utc).isoformat()
        })


# =========================================================
# STEP 5: DISPLAY PROBE SUMMARY
# =========================================================

probe_df = pd.DataFrame(probe_results)

display(probe_df.sort_values(["status", "hasData", "objectType"], ascending=[True, False, True]))


# =========================================================
# STEP 6: SHOW ONLY OBJECTS THAT HAVE DATA
# =========================================================

objects_with_data_df = probe_df[
    (probe_df["status"] == "Success") &
    (probe_df["hasData"] == True)
].copy()

display(objects_with_data_df[["objectType", "sampleRecordCount", "sampleId", "sampleColumns"]])


# =========================================================
# STEP 7: SHOW OBJECTS THAT FAILED
# =========================================================

objects_failed_df = probe_df[
    probe_df["status"] == "Error"
].copy()

display(objects_failed_df[["objectType", "errorMessage"]])

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

import requests
import pandas as pd
import json
from datetime import datetime, timezone

# =========================================================
# CONFIG
# =========================================================

GEOTAB_USERNAME = "svc_fabric_geotab"
GEOTAB_PASSWORD = "Ns.p92JVK6Vd3dz"


GEOTAB_SERVER = "my.geotab.com"
api_url = f"https://{GEOTAB_SERVER}/apiv1"

# Master/reference objects from your successful probe
master_objects = [
    "Device",
    "User",
    "Group",
    "Zone",
    "Rule",
    "Diagnostic",
    "Controller",
    "FailureMode",
    "Trailer"
]

SAMPLE_LIMIT = 100


# =========================================================
# HELPER: GEOTAB API CALL
# =========================================================

def geotab_call(method: str, params: dict, api_url: str):
    payload = {
        "method": method,
        "params": params
    }

    response = requests.post(api_url, json=payload, timeout=120)

    if response.status_code != 200:
        raise Exception(
            f"HTTP Error: {response.status_code}\nResponse: {response.text}"
        )

    data = response.json()

    if "error" in data:
        raise Exception(json.dumps(data["error"], indent=2))

    return data.get("result")


# =========================================================
# HELPER: CLASSIFY FIELD TYPE
# =========================================================

def classify_value(value):
    if value is None:
        return {
            "pythonType": "NoneType",
            "schemaType": "null",
            "isNested": False
        }

    if isinstance(value, bool):
        return {
            "pythonType": "bool",
            "schemaType": "boolean",
            "isNested": False
        }

    if isinstance(value, int):
        return {
            "pythonType": "int",
            "schemaType": "integer",
            "isNested": False
        }

    if isinstance(value, float):
        return {
            "pythonType": "float",
            "schemaType": "decimal",
            "isNested": False
        }

    if isinstance(value, str):
        # Some Geotab date fields come back as ISO-style strings
        if "T" in value and ("Z" in value or "+" in value or "-" in value):
            schema_type = "string_or_datetime"
        else:
            schema_type = "string"

        return {
            "pythonType": "str",
            "schemaType": schema_type,
            "isNested": False
        }

    if isinstance(value, dict):
        return {
            "pythonType": "dict",
            "schemaType": "struct",
            "isNested": True
        }

    if isinstance(value, list):
        return {
            "pythonType": "list",
            "schemaType": "array",
            "isNested": True
        }

    return {
        "pythonType": type(value).__name__,
        "schemaType": "unknown",
        "isNested": True
    }


def sample_value_to_string(value, max_len=500):
    if isinstance(value, (dict, list)):
        text = json.dumps(value)
    else:
        text = str(value)

    if len(text) > max_len:
        return text[:max_len] + "..."

    return text


# =========================================================
# STEP 1: AUTHENTICATE
# =========================================================

auth_result = geotab_call(
    method="Authenticate",
    params={
        "userName": GEOTAB_USERNAME,
        "password": GEOTAB_PASSWORD
    },
    api_url=api_url
)

credentials = auth_result["credentials"]

print("Authenticated successfully.")
print("Database returned:", credentials.get("database"))
print("User returned:", credentials.get("userName"))
print("Session ID returned:", credentials.get("sessionId")[:10] + "...")


# =========================================================
# STEP 2: HANDLE RETURNED PATH
# =========================================================

returned_path = auth_result.get("path")

if returned_path and returned_path.lower() != "thisserver":
    api_url = f"https://{returned_path}/apiv1"
    print("Using returned Geotab path:", returned_path)
else:
    print("Returned path is not a real server:", returned_path)
    print("Continuing with original server:", GEOTAB_SERVER)

print("Final API URL:", api_url)


# =========================================================
# STEP 3: PROFILE SCHEMA FOR EACH MASTER OBJECT
# =========================================================

schema_rows = []
raw_samples = {}

for type_name in master_objects:
    print(f"\nProfiling schema for: {type_name}")

    try:
        records = geotab_call(
            method="Get",
            params={
                "typeName": type_name,
                "credentials": credentials,
                "resultsLimit": SAMPLE_LIMIT
            },
            api_url=api_url
        )

        raw_samples[type_name] = records

        print(f"{type_name}: {len(records)} sample records returned")

        if not records:
            schema_rows.append({
                "objectType": type_name,
                "fieldName": None,
                "pythonType": None,
                "schemaType": None,
                "isNested": None,
                "fieldPresenceCount": 0,
                "sampleRecordCount": 0,
                "presencePercent": 0,
                "sampleValue": None,
                "checkedUtc": datetime.now(timezone.utc).isoformat()
            })
            continue

        # Collect all fields from all sampled records
        all_fields = set()

        for record in records:
            if isinstance(record, dict):
                all_fields.update(record.keys())

        for field in sorted(all_fields):
            values = []

            for record in records:
                if isinstance(record, dict) and field in record:
                    values.append(record.get(field))

            non_null_values = [v for v in values if v is not None]

            if non_null_values:
                first_value = non_null_values[0]
            else:
                first_value = values[0] if values else None

            classification = classify_value(first_value)

            schema_rows.append({
                "objectType": type_name,
                "fieldName": field,
                "pythonType": classification["pythonType"],
                "schemaType": classification["schemaType"],
                "isNested": classification["isNested"],
                "fieldPresenceCount": len(values),
                "sampleRecordCount": len(records),
                "presencePercent": round((len(values) / len(records)) * 100, 2),
                "sampleValue": sample_value_to_string(first_value),
                "checkedUtc": datetime.now(timezone.utc).isoformat()
            })

    except Exception as e:
        print(f"{type_name}: ERROR")
        print(str(e)[:1000])

        schema_rows.append({
            "objectType": type_name,
            "fieldName": None,
            "pythonType": None,
            "schemaType": None,
            "isNested": None,
            "fieldPresenceCount": None,
            "sampleRecordCount": None,
            "presencePercent": None,
            "sampleValue": None,
            "errorMessage": str(e)[:1000],
            "checkedUtc": datetime.now(timezone.utc).isoformat()
        })


# =========================================================
# STEP 4: DISPLAY SCHEMA PROFILE
# =========================================================

schema_df = pd.DataFrame(schema_rows)

display(schema_df)


# =========================================================
# STEP 5: DISPLAY SIMPLE VS NESTED FIELDS
# =========================================================

simple_fields_df = schema_df[
    (schema_df["isNested"] == False)
].copy()

nested_fields_df = schema_df[
    (schema_df["isNested"] == True)
].copy()

print("Simple fields:")
display(simple_fields_df[[
    "objectType",
    "fieldName",
    "schemaType",
    "pythonType",
    "presencePercent",
    "sampleValue"
]])

print("Nested fields:")
display(nested_fields_df[[
    "objectType",
    "fieldName",
    "schemaType",
    "pythonType",
    "presencePercent",
    "sampleValue"
]])


# =========================================================
# STEP 6: FIELD COUNT SUMMARY BY OBJECT
# =========================================================

field_summary_df = (
    schema_df
    .groupby("objectType", dropna=False)
    .agg(
        totalFields=("fieldName", "count"),
        simpleFields=("isNested", lambda x: (x == False).sum()),
        nestedFields=("isNested", lambda x: (x == True).sum())
    )
    .reset_index()
)

display(field_summary_df)

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

import requests
import pandas as pd
import json
from datetime import datetime, timezone

# =========================================================
# CONFIG
# =========================================================

GEOTAB_USERNAME = "svc_fabric_geotab"
GEOTAB_PASSWORD = "Ns.p92JVK6Vd3dz"

GEOTAB_SERVER = "my.geotab.com"
api_url = f"https://{GEOTAB_SERVER}/apiv1"

SOURCE_SYSTEM = "Geotab"
RESULTS_LIMIT = 100000

# If True:
#   - table exists     -> delete existing rows, then reload
#   - table not exists -> create table, then load
RELOAD_BRONZE = True


# =========================================================
# BRONZE TABLE NAMES
# =========================================================

BRONZE_TABLES = {
    "Device": "geotab_device_bronze",
    "User": "geotab_user_bronze",
    "Group": "geotab_group_bronze",
    "Zone": "geotab_zone_bronze",
    "Rule": "geotab_rule_bronze",
    "Diagnostic": "geotab_diagnostic_bronze",
    "Controller": "geotab_controller_bronze",
    "FailureMode": "geotab_failuremode_bronze",
    "Trailer": "geotab_trailer_bronze"
}


# =========================================================
# TABLE HELPERS
# =========================================================

def table_exists(table_name: str) -> bool:
    try:
        return spark.catalog.tableExists(table_name)
    except Exception:
        try:
            spark.sql(f"DESCRIBE TABLE {table_name}")
            return True
        except Exception:
            return False


def clear_table_if_exists(table_name: str):
    """
    If table exists, remove existing data.
    If table does not exist, do nothing.
    """
    if table_exists(table_name):
        print(f"Table exists. Clearing data: {table_name}")
        spark.sql(f"DELETE FROM {table_name}")
        return "cleared_existing_table"
    else:
        print(f"Table does not exist. It will be created: {table_name}")
        return "create_new_table"


# =========================================================
# GEOTAB API CALL HELPER
# =========================================================

def geotab_call(method: str, params: dict, api_url: str):
    payload = {
        "method": method,
        "params": params
    }

    response = requests.post(api_url, json=payload, timeout=120)

    if response.status_code != 200:
        raise Exception(
            f"HTTP Error: {response.status_code}\nResponse: {response.text}"
        )

    data = response.json()

    if "error" in data:
        raise Exception(
            f"Geotab API Error:\n{json.dumps(data['error'], indent=2)}"
        )

    return data.get("result")


# =========================================================
# AUTHENTICATE
# =========================================================

auth_result = geotab_call(
    method="Authenticate",
    params={
        "userName": GEOTAB_USERNAME,
        "password": GEOTAB_PASSWORD
    },
    api_url=api_url
)

credentials = auth_result["credentials"]
database_name = credentials.get("database")

print("Authenticated successfully.")
print("Database returned:", database_name)
print("User returned:", credentials.get("userName"))
print("Session ID returned:", credentials.get("sessionId")[:10] + "...")


# =========================================================
# HANDLE RETURNED PATH
# =========================================================

returned_path = auth_result.get("path")

if returned_path and returned_path.lower() != "thisserver":
    api_url = f"https://{returned_path}/apiv1"
    print("Using returned Geotab path:", returned_path)
else:
    print("Returned path is not a real server:", returned_path)
    print("Continuing with original server:", GEOTAB_SERVER)

print("Final API URL:", api_url)


# =========================================================
# CONVERT GEOTAB RECORDS TO BRONZE DATAFRAME
# =========================================================

def build_bronze_df(object_type: str, records: list):
    load_utc = datetime.now(timezone.utc).isoformat()

    rows = []

    for record in records:
        record_id = None

        if isinstance(record, dict):
            record_id = record.get("id")

        rows.append({
            "objectType": object_type,
            "recordId": record_id,
            "rawJson": json.dumps(record),
            "sourceSystem": SOURCE_SYSTEM,
            "databaseName": database_name,
            "apiMethod": "Get",
            "loadUtc": load_utc
        })

    pdf = pd.DataFrame(rows)

    if pdf.empty:
        pdf = pd.DataFrame(columns=[
            "objectType",
            "recordId",
            "rawJson",
            "sourceSystem",
            "databaseName",
            "apiMethod",
            "loadUtc"
        ])

    return spark.createDataFrame(pdf)


# =========================================================
# PREPARE BRONZE TABLES
# =========================================================
# Existing table  -> clear data
# Missing table   -> create automatically during write

table_actions = {}

if RELOAD_BRONZE:
    print("RELOAD_BRONZE is True. Existing table data will be cleared before reload.")

    for table_name in BRONZE_TABLES.values():
        table_actions[table_name] = clear_table_if_exists(table_name)
else:
    print("RELOAD_BRONZE is False. Data will be appended.")
    for table_name in BRONZE_TABLES.values():
        table_actions[table_name] = "append_only"


# =========================================================
# PULL MASTER OBJECTS AND WRITE TO BRONZE TABLES
# =========================================================

load_summary = []

for object_type, table_name in BRONZE_TABLES.items():
    print(f"\nPulling {object_type}...")

    try:
        records = geotab_call(
            method="Get",
            params={
                "typeName": object_type,
                "credentials": credentials,
                "resultsLimit": RESULTS_LIMIT
            },
            api_url=api_url
        )

        print(f"{object_type}: {len(records)} records returned")

        df_bronze = build_bronze_df(object_type, records)

        df_bronze.write \
            .format("delta") \
            .mode("append") \
            .saveAsTable(table_name)

        print(f"Loaded Bronze table: {table_name}")

        load_summary.append({
            "objectType": object_type,
            "tableName": table_name,
            "status": "Success",
            "recordsReturned": len(records),
            "tableAction": table_actions.get(table_name),
            "errorMessage": None,
            "loadUtc": datetime.now(timezone.utc).isoformat()
        })

    except Exception as e:
        print(f"{object_type}: ERROR")
        print(str(e)[:1000])

        load_summary.append({
            "objectType": object_type,
            "tableName": table_name,
            "status": "Error",
            "recordsReturned": None,
            "tableAction": table_actions.get(table_name),
            "errorMessage": str(e)[:1000],
            "loadUtc": datetime.now(timezone.utc).isoformat()
        })


# =========================================================
# DISPLAY LOAD SUMMARY
# =========================================================

load_summary_df = pd.DataFrame(load_summary)
display(load_summary_df)


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

import requests
import pandas as pd
import json
from datetime import datetime, timezone

# =========================================================
# CONFIG
# =========================================================

GEOTAB_USERNAME = "svc_fabric_geotab"
GEOTAB_PASSWORD = "Ns.p92JVK6Vd3dz"

GEOTAB_SERVER = "my.geotab.com"
api_url = f"https://{GEOTAB_SERVER}/apiv1"

# Operational / fact-style objects to profile
NEXT_OBJECTS = [
    "Trip",
    "LogRecord",
    "StatusData",
    "FaultData",
    "ExceptionEvent",
    "FuelTaxDetail",
    "DutyStatusLog",
    "AnnotationLog",
    "TextMessage",
    "IoxAddOn"
]

# Keep this small for schema discovery
SAMPLE_LIMIT = 100


# =========================================================
# GEOTAB API CALL HELPER
# =========================================================

def geotab_call(method: str, params: dict, api_url: str):
    payload = {
        "method": method,
        "params": params
    }

    response = requests.post(api_url, json=payload, timeout=120)

    if response.status_code != 200:
        raise Exception(
            f"HTTP Error: {response.status_code}\nResponse: {response.text}"
        )

    data = response.json()

    if "error" in data:
        raise Exception(
            f"Geotab API Error:\n{json.dumps(data['error'], indent=2)}"
        )

    return data.get("result")


# =========================================================
# CLASSIFY FIELD TYPE
# =========================================================

def classify_value(value):
    if value is None:
        return {
            "pythonType": "NoneType",
            "schemaType": "null",
            "isNested": False
        }

    if isinstance(value, bool):
        return {
            "pythonType": "bool",
            "schemaType": "boolean",
            "isNested": False
        }

    if isinstance(value, int):
        return {
            "pythonType": "int",
            "schemaType": "integer",
            "isNested": False
        }

    if isinstance(value, float):
        return {
            "pythonType": "float",
            "schemaType": "decimal",
            "isNested": False
        }

    if isinstance(value, str):
        # Many Geotab date/time fields come as ISO-style strings
        if "T" in value:
            schema_type = "string_or_datetime"
        else:
            schema_type = "string"

        return {
            "pythonType": "str",
            "schemaType": schema_type,
            "isNested": False
        }

    if isinstance(value, dict):
        return {
            "pythonType": "dict",
            "schemaType": "struct",
            "isNested": True
        }

    if isinstance(value, list):
        return {
            "pythonType": "list",
            "schemaType": "array",
            "isNested": True
        }

    return {
        "pythonType": type(value).__name__,
        "schemaType": "unknown",
        "isNested": True
    }


def sample_value_to_string(value, max_len=700):
    if isinstance(value, (dict, list)):
        text = json.dumps(value)
    else:
        text = str(value)

    if len(text) > max_len:
        return text[:max_len] + "..."

    return text


# =========================================================
# STEP 1: AUTHENTICATE
# =========================================================

auth_result = geotab_call(
    method="Authenticate",
    params={
        "userName": GEOTAB_USERNAME,
        "password": GEOTAB_PASSWORD
    },
    api_url=api_url
)

credentials = auth_result["credentials"]
database_name = credentials.get("database")

print("Authenticated successfully.")
print("Database returned:", database_name)
print("User returned:", credentials.get("userName"))
print("Session ID returned:", credentials.get("sessionId")[:10] + "...")


# =========================================================
# STEP 2: HANDLE RETURNED PATH
# =========================================================

returned_path = auth_result.get("path")

if returned_path and returned_path.lower() != "thisserver":
    api_url = f"https://{returned_path}/apiv1"
    print("Using returned Geotab path:", returned_path)
else:
    print("Returned path is not a real server:", returned_path)
    print("Continuing with original server:", GEOTAB_SERVER)

print("Final API URL:", api_url)


# =========================================================
# STEP 3: PROFILE SCHEMA FOR NEXT OBJECTS
# =========================================================

schema_rows = []
object_summary_rows = []
raw_samples = {}

for object_type in NEXT_OBJECTS:
    print(f"\nProfiling schema for: {object_type}")

    try:
        records = geotab_call(
            method="Get",
            params={
                "typeName": object_type,
                "credentials": credentials,
                "resultsLimit": SAMPLE_LIMIT
            },
            api_url=api_url
        )

        raw_samples[object_type] = records

        print(f"{object_type}: {len(records)} sample records returned")

        if not records:
            object_summary_rows.append({
                "objectType": object_type,
                "sampleRecordCount": 0,
                "totalFields": 0,
                "simpleFields": 0,
                "nestedFields": 0,
                "status": "No Data",
                "errorMessage": None,
                "checkedUtc": datetime.now(timezone.utc).isoformat()
            })
            continue

        all_fields = set()

        for record in records:
            if isinstance(record, dict):
                all_fields.update(record.keys())

        simple_count = 0
        nested_count = 0

        for field_name in sorted(all_fields):
            values = []

            for record in records:
                if isinstance(record, dict) and field_name in record:
                    values.append(record.get(field_name))

            non_null_values = [v for v in values if v is not None]

            if non_null_values:
                first_value = non_null_values[0]
            else:
                first_value = values[0] if values else None

            classification = classify_value(first_value)

            if classification["isNested"]:
                nested_count += 1
            else:
                simple_count += 1

            schema_rows.append({
                "objectType": object_type,
                "fieldName": field_name,
                "pythonType": classification["pythonType"],
                "schemaType": classification["schemaType"],
                "isNested": classification["isNested"],
                "fieldPresenceCount": len(values),
                "sampleRecordCount": len(records),
                "presencePercent": round((len(values) / len(records)) * 100, 2),
                "sampleValue": sample_value_to_string(first_value),
                "checkedUtc": datetime.now(timezone.utc).isoformat()
            })

        object_summary_rows.append({
            "objectType": object_type,
            "sampleRecordCount": len(records),
            "totalFields": len(all_fields),
            "simpleFields": simple_count,
            "nestedFields": nested_count,
            "status": "Success",
            "errorMessage": None,
            "checkedUtc": datetime.now(timezone.utc).isoformat()
        })

    except Exception as e:
        print(f"{object_type}: ERROR")
        print(str(e)[:1000])

        object_summary_rows.append({
            "objectType": object_type,
            "sampleRecordCount": None,
            "totalFields": None,
            "simpleFields": None,
            "nestedFields": None,
            "status": "Error",
            "errorMessage": str(e)[:1000],
            "checkedUtc": datetime.now(timezone.utc).isoformat()
        })


# =========================================================
# STEP 4: CREATE DATAFRAMES
# =========================================================

schema_df = pd.DataFrame(schema_rows)
object_summary_df = pd.DataFrame(object_summary_rows)

display(object_summary_df)

display(schema_df)


# =========================================================
# STEP 5: SPLIT SIMPLE AND NESTED FIELDS
# =========================================================

simple_fields_df = schema_df[schema_df["isNested"] == False].copy()
nested_fields_df = schema_df[schema_df["isNested"] == True].copy()

print("Simple fields:")
display(simple_fields_df[[
    "objectType",
    "fieldName",
    "schemaType",
    "pythonType",
    "presencePercent",
    "sampleValue"
]])

print("Nested fields:")
display(nested_fields_df[[
    "objectType",
    "fieldName",
    "schemaType",
    "pythonType",
    "presencePercent",
    "sampleValue"
]])


# =========================================================
# STEP 6: OPTIONAL RAW JSON INSPECTION
# =========================================================
# Change this to any object you want to inspect deeply.

OBJECT_TO_INSPECT = "Trip"

if OBJECT_TO_INSPECT in raw_samples and len(raw_samples[OBJECT_TO_INSPECT]) > 0:
    print(f"\nRaw JSON sample for {OBJECT_TO_INSPECT}:")
    print(json.dumps(raw_samples[OBJECT_TO_INSPECT][0], indent=2))
else:
    print(f"No raw sample available for {OBJECT_TO_INSPECT}")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

import requests
import pandas as pd
import json
from datetime import datetime, timezone

# =========================================================
# CONFIG
# =========================================================

GEOTAB_USERNAME = "svc_fabric_geotab"
GEOTAB_PASSWORD = "Ns.p92JVK6Vd3dz"

GEOTAB_SERVER = "my.geotab.com"
api_url = f"https://{GEOTAB_SERVER}/apiv1"

SOURCE_SYSTEM = "Geotab"

# Keep small for POC.
# Later, these event/fact tables need incremental logic.
RESULTS_LIMIT = 1000000

# True = if table exists, clear rows and reload
# False = append new rows
RELOAD_BRONZE = True


# =========================================================
# EVENT / FACT BRONZE TABLE NAMES
# =========================================================

BRONZE_EVENT_TABLES = {
    "Trip": "geotab_trip_bronze",
    "LogRecord": "geotab_logrecord_bronze",
    "StatusData": "geotab_statusdata_bronze",
    "FaultData": "geotab_faultdata_bronze",
    "ExceptionEvent": "geotab_exceptionevent_bronze",
    "FuelTaxDetail": "geotab_fueltaxdetail_bronze",
    "DutyStatusLog": "geotab_dutystatuslog_bronze",
    "AnnotationLog": "geotab_annotationlog_bronze",
    "TextMessage": "geotab_textmessage_bronze",
    "IoxAddOn": "geotab_ioxaddon_bronze"
}


# =========================================================
# TABLE HELPERS
# =========================================================

def table_exists(table_name: str) -> bool:
    try:
        return spark.catalog.tableExists(table_name)
    except Exception:
        try:
            spark.sql(f"DESCRIBE TABLE {table_name}")
            return True
        except Exception:
            return False


def clear_table_if_exists(table_name: str):
    """
    If table exists, delete existing data.
    If table does not exist, do nothing.
    """
    if table_exists(table_name):
        print(f"Table exists. Clearing data: {table_name}")
        spark.sql(f"DELETE FROM {table_name}")
        return "cleared_existing_table"
    else:
        print(f"Table does not exist. It will be created: {table_name}")
        return "create_new_table"


# =========================================================
# GEOTAB API CALL HELPER
# =========================================================

def geotab_call(method: str, params: dict, api_url: str):
    payload = {
        "method": method,
        "params": params
    }

    response = requests.post(api_url, json=payload, timeout=120)

    if response.status_code != 200:
        raise Exception(
            f"HTTP Error: {response.status_code}\nResponse: {response.text}"
        )

    data = response.json()

    if "error" in data:
        raise Exception(
            f"Geotab API Error:\n{json.dumps(data['error'], indent=2)}"
        )

    return data.get("result")


# =========================================================
# AUTHENTICATE
# =========================================================

auth_result = geotab_call(
    method="Authenticate",
    params={
        "userName": GEOTAB_USERNAME,
        "password": GEOTAB_PASSWORD
    },
    api_url=api_url
)

credentials = auth_result["credentials"]
database_name = credentials.get("database")

print("Authenticated successfully.")
print("Database returned:", database_name)
print("User returned:", credentials.get("userName"))
print("Session ID returned:", credentials.get("sessionId")[:10] + "...")


# =========================================================
# HANDLE RETURNED PATH
# =========================================================

returned_path = auth_result.get("path")

if returned_path and returned_path.lower() != "thisserver":
    api_url = f"https://{returned_path}/apiv1"
    print("Using returned Geotab path:", returned_path)
else:
    print("Returned path is not a real server:", returned_path)
    print("Continuing with original server:", GEOTAB_SERVER)

print("Final API URL:", api_url)


# =========================================================
# BUILD BRONZE DATAFRAME
# =========================================================

def build_bronze_df(object_type: str, records: list):
    load_utc = datetime.now(timezone.utc).isoformat()

    rows = []

    for record in records:
        record_id = None

        if isinstance(record, dict):
            record_id = record.get("id")

        rows.append({
            "objectType": object_type,
            "recordId": record_id,
            "rawJson": json.dumps(record),
            "sourceSystem": SOURCE_SYSTEM,
            "databaseName": database_name,
            "apiMethod": "Get",
            "loadUtc": load_utc
        })

    pdf = pd.DataFrame(rows)

    if pdf.empty:
        pdf = pd.DataFrame(columns=[
            "objectType",
            "recordId",
            "rawJson",
            "sourceSystem",
            "databaseName",
            "apiMethod",
            "loadUtc"
        ])

    return spark.createDataFrame(pdf)


# =========================================================
# PREPARE BRONZE TABLES
# =========================================================

table_actions = {}

if RELOAD_BRONZE:
    print("RELOAD_BRONZE is True. Existing event Bronze table data will be cleared before reload.")

    for table_name in BRONZE_EVENT_TABLES.values():
        table_actions[table_name] = clear_table_if_exists(table_name)
else:
    print("RELOAD_BRONZE is False. Event Bronze tables will be appended.")

    for table_name in BRONZE_EVENT_TABLES.values():
        table_actions[table_name] = "append_only"


# =========================================================
# PULL EVENT OBJECTS AND WRITE TO BRONZE TABLES
# =========================================================

load_summary = []

for object_type, table_name in BRONZE_EVENT_TABLES.items():
    print(f"\nPulling {object_type}...")

    try:
        records = geotab_call(
            method="Get",
            params={
                "typeName": object_type,
                "credentials": credentials,
                "resultsLimit": RESULTS_LIMIT
            },
            api_url=api_url
        )

        print(f"{object_type}: {len(records)} records returned")

        df_bronze = build_bronze_df(object_type, records)

        df_bronze.write \
            .format("delta") \
            .mode("append") \
            .saveAsTable(table_name)

        print(f"Loaded Bronze table: {table_name}")

        load_summary.append({
            "objectType": object_type,
            "tableName": table_name,
            "status": "Success",
            "recordsReturned": len(records),
            "tableAction": table_actions.get(table_name),
            "errorMessage": None,
            "loadUtc": datetime.now(timezone.utc).isoformat()
        })

    except Exception as e:
        print(f"{object_type}: ERROR")
        print(str(e)[:1000])

        load_summary.append({
            "objectType": object_type,
            "tableName": table_name,
            "status": "Error",
            "recordsReturned": None,
            "tableAction": table_actions.get(table_name),
            "errorMessage": str(e)[:1000],
            "loadUtc": datetime.now(timezone.utc).isoformat()
        })


# =========================================================
# DISPLAY LOAD SUMMARY
# =========================================================

load_summary_df = pd.DataFrame(load_summary)
display(load_summary_df)

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }
