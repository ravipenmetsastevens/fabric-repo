/***************************************************************************************************
Procedure:          dbo.usp_risk_transportation_master_silver
Create Date:        2025-08-28
Author:             Jeremy Shahan
Description:        Truncate and load of Transportation Master Silver
Called by:            Azure Data Factory
					Pipeline: risk_transportation_master
Affected table(s):  silver.risk_transportation_master
Usage:              EXEC dbo.usp_risk_transportation_master_silver

****************************************************************************************************
SUMMARY OF CHANGES
#             Date(yyyy-mm-dd)    Author              Comments
------------------- ------------------ ------------------------------------------------------------
1            
***************************************************************************************************/

CREATE   PROCEDURE dbo.usp_risk_transportation_master_silver
AS

SET NOCOUNT ON

TRUNCATE TABLE silver.risk_transportation_master

INSERT INTO silver.risk_transportation_master
SELECT
		a.CLAIMMASTERRECORDID								AS trans_mast_claim_record_code
      , CASE TRIM(a.ACCIDENTINCIDENTINDICATOR)
			WHEN 'A' THEN 'ACCIDENT'
			WHEN 'I' THEN 'INCIDENT'
			ELSE 'unknown'	END								AS is_accident_or_incident
      , TRIM(a.CARRIERSCLAIMNUMBER)							AS trans_mast_carrier_claim_code
      , a.ACCIDENTTYPE										AS trans_mast_accident_type_code
      , a.WEATHERCONDITIONCODE								AS trans_mast_weather_condition_code
      , CASE TRIM(a.DOTREPORTABLE)
			WHEN 'Y' THEN 'TRUE'
			WHEN 'N' THEN 'FALSE'
			ELSE 'unknown'	END								AS is_dot_reportable
      , CASE TRIM(a.PREVENTABLE)
			WHEN 'Y' THEN 'TRUE'
			WHEN 'N' THEN 'FALSE'
			ELSE 'unknown'	END								AS is_preventable
      --, a.FLEETCODE
      , TRIM(a.DRIVERSUPERVISOR)							AS trans_mast_dm_code
      , TRIM(a.TERMINALLOCATION)							AS trans_mast_terminal_location
      , TRIM(a.FLEETMANAGER)								AS trans_mast_dmol_code
      , a.ROADSURFACECODE									AS trans_mast_road_surface_code
      , a.ROADCONDITIONCODE									AS trans_mast_road_condition_code
      , CASE TRIM(a.DIVIDEDHIWAYYN)
			WHEN 'Y' THEN 'TRUE'
			WHEN 'N' THEN 'FALSE'
			ELSE 'unknown'	END								AS is_divided_highway
      , a.NUMBEROFLANES										AS trans_mast_lane_count
      , a.CREATEDATE										AS trans_mast_create_datetime
      , TRIM(a.CREATEUSER)									AS trans_mast_create_user_code
      , a.CHANGEDATE										AS trans_mast_last_change_datetime
      , TRIM(a.CHANGEUSER)									AS trans_mast_last_change_user_code
      , TRIM(a.NEARCITY)									AS trans_mast_near_city
      , TRIM(a.NEARSTATE)									AS trans_mast_near_state
      --, a.UDFA1
      --, a.UDFA2
      --, a.UDFA3
      --, a.UDFA4
      --, a.UDFD1
      --, a.UDFD2
      --, a.UDFD3
      --, a.UDFD4
      --, a.UDFN1
      --, a.UDFN2
      --, a.UDFN3
      --, a.UDFN4
      --, a.UDFL1
      --, a.UDFL2
      --, a.UDFL3
      --, a.UDFL4
      --, a.UDFL5
      --, a.UDFL6
      --, a.UDFL7
      --, a.UDFL8
      --, a.V1SPEED
      --, a.V2SPEED
      --, a.POSTEDSPEED
      --, a.POSTEDSPEEDN
      --, a.V1SPEEDN
      --, a.V2SPEEDN
      --, a.DIVISION
      --, a.CONSTRCUTIONSITE
      --, a.REVIEWSTATUSRID
      --, a.FMCSAREGISTER
      --, a.SAFETYMATRIXCODE
      --, a.CITATIONMATRIXCODE
      --, a.CARRIERCLAIMNUMBER
--INTO data_central_wh.silver.risk_transportation_master
FROM data_central_lh.dbo.risk_transportation_specific_master_bronze a