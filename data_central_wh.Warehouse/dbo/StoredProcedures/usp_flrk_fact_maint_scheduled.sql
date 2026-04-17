/***************************************************************************************************
Procedure:          dbo.usp_flrk_fact_maint_scheduled
Create Date:        2024-05-19
Author:             Tom Wolfenden
Description:        Create gold.fact_maint_scheduled
Called by:          Fabric  
					Pipeline: Fleetrock\Pipeline\pl_flrk_scheduled
Affected table(s):  gold.fact_maint_scheduled
Usage:              EXEC dbo.usp_flrk_fact_maint_scheduled

****************************************************************************************************
SUMMARY OF CHANGES
#             Date(yyyy-mm-dd)    Author              Comments
------------------- ------------------ ------------------------------------------------------------
1            
***************************************************************************************************/

CREATE PROCEDURE dbo.usp_flrk_fact_maint_scheduled
AS

DELETE FROM gold.fact_maint_scheduled

INSERT INTO gold.fact_maint_scheduled
SELECT 
		a.sched_maint_id
	  , CASE WHEN a.sm_ro_number = 0
			THEN NULL
			ELSE a.sm_ro_number END
	  , CASE WHEN a.sm_ro_number = 0
			THEN 0
			ELSE 1 END
      , a.sm_group
      , a.sm_vin
      , a.sm_unit_number
      , a.sm_start_date
      , a.sm_start_miles
      , a.sm_start_engine_hours
      , a.sm_is_recurring
      , a.scheduled_days
      , a.scheduled_miles
      , a.scheduled_engine_hours
      , a.sm_system_component_code
      , a.sm_tag
      , a.sm_notes
      , a.sm_became_due_datetime
	  , CONVERT(DATE, a.sm_became_due_datetime)
FROM silver.flrk_scheduled_maint a