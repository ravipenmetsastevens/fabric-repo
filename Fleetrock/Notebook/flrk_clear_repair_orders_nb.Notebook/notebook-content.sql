-- Fabric notebook source

-- METADATA ********************

-- META {
-- META   "kernel_info": {
-- META     "name": "synapse_pyspark"
-- META   },
-- META   "dependencies": {
-- META     "lakehouse": {
-- META       "default_lakehouse": "f9a73da1-08e4-4f3d-a67f-74623bfde721",
-- META       "default_lakehouse_name": "data_central_lh",
-- META       "default_lakehouse_workspace_id": "a6d2c31b-0b03-4c60-a258-c2664c56fe3d",
-- META       "known_lakehouses": [
-- META         {
-- META           "id": "f9a73da1-08e4-4f3d-a67f-74623bfde721"
-- META         }
-- META       ]
-- META     }
-- META   }
-- META }

-- CELL ********************

-- MAGIC %%sql
-- MAGIC DELETE FROM data_central_lh.flrk_repair_order_bronze
-- MAGIC 


-- METADATA ********************

-- META {
-- META   "language": "sparksql",
-- META   "language_group": "synapse_pyspark"
-- META }

-- CELL ********************

-- MAGIC %%spark
-- MAGIC 
-- MAGIC import org.apache.spark.sql.delta.DeltaLog
-- MAGIC DeltaLog.forTable(spark,"Tables/flrk_repair_order_bronze").checkpoint()


-- METADATA ********************

-- META {
-- META   "language": "scala",
-- META   "language_group": "synapse_pyspark"
-- META }

-- CELL ********************

-- MAGIC %%spark
-- MAGIC 
-- MAGIC import org.apache.spark.sql.delta.DeltaLog
-- MAGIC DeltaLog.forTable(spark,"Tables/flrk_supplier_bronze").checkpoint()


-- METADATA ********************

-- META {
-- META   "language": "scala",
-- META   "language_group": "synapse_pyspark"
-- META }

-- CELL ********************

-- MAGIC %%spark
-- MAGIC import org.apache.spark.sql.delta.DeltaLog
-- MAGIC DeltaLog.forTable(spark,"Tables/flrk_driver_bronze").checkpoint()

-- METADATA ********************

-- META {
-- META   "language": "scala",
-- META   "language_group": "synapse_pyspark"
-- META }

-- CELL ********************

-- MAGIC %%spark
-- MAGIC import org.apache.spark.sql.delta.DeltaLog
-- MAGIC DeltaLog.forTable(spark,"Tables/flrk_group_bronze").checkpoint()

-- METADATA ********************

-- META {
-- META   "language": "scala",
-- META   "language_group": "synapse_pyspark"
-- META }

-- CELL ********************

-- MAGIC %%spark
-- MAGIC import org.apache.spark.sql.delta.DeltaLog
-- MAGIC DeltaLog.forTable(spark,"Tables/flrk_scheduled_maint_bronze").checkpoint()

-- METADATA ********************

-- META {
-- META   "language": "scala",
-- META   "language_group": "synapse_pyspark"
-- META }

-- CELL ********************

-- MAGIC %%spark
-- MAGIC import org.apache.spark.sql.delta.DeltaLog
-- MAGIC DeltaLog.forTable(spark,"Tables/flrk_unit_bronze").checkpoint()

-- METADATA ********************

-- META {
-- META   "language": "scala",
-- META   "language_group": "synapse_pyspark"
-- META }
