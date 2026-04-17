/***************************************************************************************************
Procedure:          dbo.usp_risk_involved_vehicle_silver
Create Date:        2025-08-28
Author:             Jeremy Shahan
Description:        Truncate and load of Involved Vehicle Silver
Called by:            Azure Data Factory
					Pipeline: risk_involved_vehicle
Affected table(s):  silver.risk_involved_vehicle
Usage:              EXEC dbo.usp_risk_involved_vehicle_silver

****************************************************************************************************
SUMMARY OF CHANGES
#             Date(yyyy-mm-dd)    Author              Comments
------------------- ------------------ ------------------------------------------------------------
1            
***************************************************************************************************/

CREATE   PROCEDURE dbo.usp_risk_involved_vehicle_silver
AS

SET NOCOUNT ON

TRUNCATE TABLE silver.risk_involved_vehicle

INSERT INTO silver.risk_involved_vehicle
SELECT
		a.CLAIMMASTERRECORDID								AS involved_veh_claim_record_code
      , a.INVOLVEDPARTYRECORDID								AS involved_veh_involved_party_code
      , a.INVOLVEDVEHICLERECORDID							AS involved_veh_record_code
      , CASE TRIM(a.EQUIPMENTTYPE)
			WHEN 'T' THEN 'TRAILER'
			WHEN 'U' THEN 'TRUCK'
			WHEN 'M' THEN 'MISC'
			ELSE 'unknown'	END								AS involved_veh_equipment_type
      , TRIM(a.EQUIPMENTCODE)								AS involved_veh_equipment_code
      , a.VEHICLEYEAR										AS involved_veh_year
      --, a.VEHICLEIDNUMBER
      , TRIM(a.VEHICLEMAKE)									AS involved_veh_make
      , TRIM(a.VEHICLEMODEL)								AS involved_veh_model
      , CASE TRIM(a.DAMAGEYN)
			WHEN 'Y' THEN 'TRUE'
			WHEN 'N' THEN 'FALSE'
			ELSE 'unknown'	END								AS has_damage
      , CASE TRIM(a.PICTURESYN)
			WHEN 'Y' THEN 'TRUE'
			WHEN 'N' THEN 'FALSE'
			ELSE 'unknown'	END								AS has_pictures
      , CASE TRIM(a.TOWEDYN)
			WHEN 'Y' THEN 'TRUE'
			WHEN 'N' THEN 'FALSE'
			ELSE 'unknown'	END								AS was_towed
      , TRIM(a.TAGNUMBER)									AS involved_veh_tag_number
      --, a.MILEAGE
      , TRIM(a.REGISTRATIONSTATE)							AS involved_veh_registration_state
      , TRIM(a.DAMAGEDESCRIPTION)							AS involved_veh_damage_description
      --, a.LOSSPAYEE
      , TRIM(a.DETAILDESCRIPTION)							AS involved_veh_detail_description
      , a.CREATEDATE										AS involved_veh_create_datetime
      , TRIM(a.CREATEUSER)									AS involved_veh_create_user_code
      , a.CHANGEDATE										AS involved_veh_last_update_datetime
      , TRIM(a.CHANGEUSER)									AS involved_veh_last_update_user_code
      --, a.STRLOCID
      , TRIM(a.VIN)											AS involved_veh_vin
      --, a.EQPCLSID
      --, a.LAT
      --, a.LON
      --, a.DASHCAM
--INTO data_central_wh.silver.risk_involved_vehicle
FROM data_central_lh.dbo.risk_involved_vehicle_bronze a