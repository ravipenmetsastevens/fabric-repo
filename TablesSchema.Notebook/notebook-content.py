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

from pyspark.sql import SparkSession
spark = SparkSession.builder.getOrCreate()

import json

# get all managed tables in this Lakehouse (DEV)
tables = [
    (t.database, t.name)
    for t in spark.catalog.listTables()
    if t.tableType.lower() == "managed"
]

print("Tables found:", tables)

output_lines = []
output_lines.append("from pyspark.sql import SparkSession")
output_lines.append("spark = SparkSession.builder.getOrCreate()")
output_lines.append("")

for db, tbl in tables:
    df = spark.table(f"{db}.{tbl}")
    schema = df.schema

    col_defs = []
    for field in schema.fields:
        dt = field.dataType.simpleString().upper()

        # decimal types come as decimal(precision,scale)
        if "DECIMAL" in dt:
            # already formatted
            pass
        elif dt == "STRING":
            dt = "STRING"   # default
        elif dt == "INT":
            dt = "INT"
        elif dt == "BIGINT":
            dt = "BIGINT"
        elif dt == "DOUBLE":
            dt = "DOUBLE"
        elif dt == "DATE":
            dt = "DATE"
        elif dt == "TIMESTAMP":
            dt = "TIMESTAMP"

        nullability = "NULL" if field.nullable else "NOT NULL"

        col_defs.append(f"`{field.name}` {dt} {nullability}")

    ddl = ",\n    ".join(col_defs)

    create_stmt = f"""
spark.sql(\"\"\"
CREATE TABLE {db}.{tbl} (
    {ddl}
)
USING DELTA
\"\"\")
"""
    output_lines.append(create_stmt)

final_script = "\n".join(output_lines)
print(final_script)


# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }
