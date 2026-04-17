/***************************************************************************************************
Procedure:          dbo.usp_flrk_scheduled_maint_silver
Create Date:        2024-04-28
Author:             Tom Wolfenden
Description:        Add data for Fleetrock scheduled maintenance from bronze to silver
Called by:          Fabric  
					Pipeline: Fleetrock\Pipeline\pl_flrk_scheduled_maint
Affected table(s):  silver.flrk_scheduled_maint
Usage:              EXEC dbo.usp_flrk_scheduled_maint_silver

****************************************************************************************************
SUMMARY OF CHANGES
#             Date(yyyy-mm-dd)    Author              Comments
------------------- ------------------ ------------------------------------------------------------
1            
***************************************************************************************************/

CREATE PROCEDURE dbo.usp_flrk_scheduled_maint_silver
AS

DELETE FROM silver.flrk_scheduled_maint

INSERT INTO silver.flrk_scheduled_maint
SELECT 
		a.id
      , a.[group]
      , a.vin
      , a.unit_number
      , a.[start_date]
      , a.start_miles
      , a.start_engine_hours
      , a.recurring
      , a.scheduled_days
      , a.scheduled_miles
      , a.scheduled_engine_hours
      , a.system_component_code
      , a.tag
      , a.notes
      , a.became_due
      , a.ro_number
FROM data_central_lh.dbo.flrk_scheduled_maint_bronze a