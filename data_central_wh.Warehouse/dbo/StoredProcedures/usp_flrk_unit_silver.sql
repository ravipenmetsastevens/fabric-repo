/***************************************************************************************************
Procedure:          dbo.usp_flrk_unit_silver
Create Date:        2024-04-28
Author:             Tom Wolfenden
Description:        Add data for Fleetrock units from bronze to silver
Called by:          Fabric  
					Pipeline: Fleetrock\Pipeline\pl_flrk_unit
Affected table(s):  silver.flrk_unit
Usage:              EXEC dbo.usp_flrk_unit_silver

****************************************************************************************************
SUMMARY OF CHANGES
#             Date(yyyy-mm-dd)    Author              Comments
------------------- ------------------ ------------------------------------------------------------
1            
***************************************************************************************************/

CREATE PROCEDURE dbo.usp_flrk_unit_silver
AS

DELETE FROM silver.flrk_unit

INSERT INTO silver.flrk_unit
SELECT DISTINCT
		a.vin
      , a.[group]
      , a.unit_number
      , a.custom_id
      , a.[type]
      , a.[year]
      , a.make
      , a.model
      , a.manufacturer
      , a.odometer_miles
      , a.engine_hours
      , a.cost_center
      , a.in_service_date
      , a.tag
      , a.[status]
  FROM data_central_lh.dbo.flrk_unit_bronze a