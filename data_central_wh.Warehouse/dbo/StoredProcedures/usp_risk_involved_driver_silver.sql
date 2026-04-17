/***************************************************************************************************
Procedure:          dbo.usp_risk_involved_driver_silver
Create Date:        2025-08-28
Author:             Jeremy Shahan
Description:        Truncate and load of Involved Driver Silver
Called by:            Azure Data Factory
					Pipeline: risk_involved_driver
Affected table(s):  silver.risk_involved_driver
Usage:              EXEC dbo.usp_risk_involved_driver_silver

****************************************************************************************************
SUMMARY OF CHANGES
#             Date(yyyy-mm-dd)    Author              Comments
------------------- ------------------ ------------------------------------------------------------
1            
***************************************************************************************************/

CREATE     PROCEDURE [dbo].[usp_risk_involved_driver_silver]
AS

SET NOCOUNT ON

TRUNCATE TABLE silver.risk_involved_driver

INSERT INTO silver.risk_involved_driver
SELECT
		a.CLAIMMASTERRECORDID							AS involved_drv_claim_record_code
      , a.INVOLVEDPARTYRECORDID							AS involved_drv_involved_party_code
      , CASE TRIM(a.SEATBELTINUSEYN)
			WHEN 'Y' THEN 'TRUE'
			WHEN 'N' THEN 'FALSE'
			ELSE 'unknown' END							AS was_seatbelt_used
      , CASE TRIM(a.DRUGTESTREQUIREDYN)
			WHEN 'Y' THEN 'TRUE'
			WHEN 'N' THEN 'FALSE'
			ELSE 'unknown' END							AS was_drug_test_required
      --, a.HOURSINSERVICEATACCIDENT
      , TRIM(a.DRIVERCODE)								AS involved_drv_driver_code
      , TRIM(a.SUPERVISORCODE)							AS involved_drv_dm_code
      , CASE TRIM(a.INJUREDYN)
			WHEN 'Y' THEN 'TRUE'
			WHEN 'N' THEN 'FALSE'
			ELSE 'unknown' END							AS was_injured
      , CASE TRIM(a.VEHICLEOWNER)
			WHEN 'Y' THEN 'TRUE'
			WHEN 'N' THEN 'FALSE'
			ELSE 'unknown' END							AS is_vehicle_owner
      --, a.POSITIONINVEHICLECODE
      , TRIM(a.DRIVERSLICENSESTATE)						AS involved_drv_license_state
      , a.SOCIALSECURITYNUMBER							AS involved_drv_social_security
      , CASE TRIM(a.GENDER)
			WHEN 'M' THEN 'MALE'
			WHEN 'F' THEN 'FEMALE'
			ELSE 'unknown' END							AS involved_drv_gender
      , CASE a.MARITALSTATUSCODE
			WHEN '60' THEN 'SINGLE'
			WHEN '61' THEN 'MARRIED'
			WHEN '62' THEN 'SEPARATED'
			WHEN '64' THEN 'DIVORCED'
			ELSE 'unknown' END							AS involved_drv_marital_status
      , a.DATEOFBIRTH									AS involved_drv_birth_date
      , a.DATEOFEMPLOYMENT								AS involved_drv_hire_date
      --, a.EXPERIENCESTATUS
      , a.CREATEDATE									AS involved_drv_create_datetime
      , TRIM(a.CREATEUSER)								AS involved_drv_create_user_code
      , a.CHANGEDATE									AS involved_drv_last_changed_datetime
      , TRIM(a.CHANGEUSER)								AS involved_drv_last_changed_user_code
      , CASE a.DRIVERTYPE
		WHEN 0 THEN 'COMPANY'
		WHEN 1 THEN 'OWNER'
		ELSE 'unknown'	END								AS involved_drv_driver_type
      , TRIM(a.TRAINER)									AS involved_drv_trainer_code
      --, a.DRVCLSID
      --, a.SSN
      , TRIM(a.DRIVERSLICENSENUMBER)					AS involved_drv_license_number
      --, a.HOURSLAST8DAYS
      --, a.PRIORDAYSWORKED
      --, a.LASTDAYOFF
      --, a.PIN
      --, a.GRADDATE
--INTO data_central_wh.silver.risk_involved_driver
FROM data_central_lh.dbo.risk_involved_driver_bronze a