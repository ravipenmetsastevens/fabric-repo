/***************************************************************************************************
Procedure:          dbo.usp_ibmi_utlfile_silver
Create Date:        2025-08-15
Author:             Jeremy Shahan
Description:        Truncate and load of UTLFILE Silver
Called by:            Azure Data Factory
					Pipeline: ibmi_utlfile
Affected table(s):  silver.ibmi_utlfile
Usage:              EXEC dbo.usp_ibmi_utlfile_silver

****************************************************************************************************
SUMMARY OF CHANGES
#             Date(yyyy-mm-dd)    Author              Comments
------------------- ------------------ ------------------------------------------------------------
1             2025-11-17        Jeremy Shahan       Added Business Class/Description
2             2025-11-24        Jeremy Shahan       Adjusted Business Class/Desc to account for bad data
***************************************************************************************************/

CREATE       PROCEDURE [dbo].[usp_ibmi_utlfile_silver]
AS

SET NOCOUNT ON

DELETE FROM silver.ibmi_utlfile

INSERT INTO silver.ibmi_utlfile
SELECT
	    TRIM(a.UWUNIT)							AS utlfile_truck_number
      , TRIM(a.UWCODE)							AS utlfile_driver_code							
      , CASE a.UWTYPE 
			WHEN 0 THEN 'COMPANY'
			WHEN 1 THEN 'OWNER'
			ELSE 'unknown'	END					AS utlfile_driver_type
      , TRIM(a.UWSUPR)							AS utlfile_truck_dm_code
      , TRIM(a.UWDMGR)							AS utlfile_driver_dm_code
      , TRIM(a.UWFMGR)							AS utlfile_dmol_code
      , TRIM(a.UWSFMG)							AS utlfile_safety_manager_code
	  , TRIM(a.UWCOUN)							AS utlfile_counselor_code
      , TRIM(a.UWSEAT)							AS utlfile_seat
      , TRIM(a.UWDRS1)							AS utlfile_first_seat_code
      , TRIM(a.UWDRS2)							AS utlfile_second_seat_code
      , TRIM(a.UWTLVL)							AS utlfile_training_level_code
      , CASE 
			WHEN TRIM(a.UWTMYN) = 'Y'
			THEN 'TRUE'
			ELSE 'FALSE' END					AS is_team_truck
      , CASE 
			WHEN TRIM(a.UWTRTM) = 'Y'
			THEN 'TRUE'
			ELSE 'FALSE' END					AS is_training_team
      , a.UWMILS								AS utlfile_miles_hub
      , a.UWAMLS								AS utlfile_miles_adj_hub
      , a.UWGOAL								AS utlfile_miles_goal
      , a.UWPERF								AS utlfile_utilization_ratio
      --, a.UWUDAT								
      , UWPDA.date_key_pk						AS utlfile_projected_date_available						
      , TRIM(a.UWPTA)							AS utlfile_projected_time_available
      --,a.UWWEEK
      --,a.UWPRD
      --,a.UWYEAR
      , CASE a.UWHOME 
			WHEN 'Y' THEN 'TRUE'
			WHEN 'N' THEN 'FALSE'
			ELSE 'unknown'	END					AS is_home_time
      ,TRIM(a.UWHOLD)							AS utlfile_hold_codes
      ,TRIM(a.UWBRKD)							AS utlfile_equipment_breakdown
      , CASE 
		WHEN TRIM(a.UWFLAG) = 'Y'
		THEN 'TRUE'
		ELSE 'FALSE' END						AS is_resweep
      --,a.UWDATE
      --,a.UWTRK
      ,	TRIM(a.UWLOAD)							AS utlfile_load_number
      , CASE a.UWGRHD 
			WHEN 'Y' THEN 'TRUE'
			WHEN 'N' THEN 'FALSE'
			ELSE 'unknown'	END					AS is_grad_hold
      , CASE a.UWOMIT 
			WHEN 'Y' THEN 'TRUE'
			WHEN 'N' THEN 'FALSE'
			ELSE 'unknown'	END					AS is_omitted
      ,	TRIM(a.UWDIV)							AS utlfile_division
      ,	a.UWRDO									AS utlfile_requested_days_out
	  , CASE a.UWTRNR 
			WHEN 'Y' THEN 'TRUE'
			WHEN 'N' THEN 'FALSE'
			ELSE 'unknown'	END					AS is_trainer							
      , TRIM(a.UWTRAV)							AS utlfile_trainer_availability_code
      , TRIM(a.UWTRCD)							AS utlfile_trainer_status_code
	  , CASE a.UWCNDV 
			WHEN 'Y' THEN 'TRUE'
			WHEN 'N' THEN 'FALSE'
			ELSE 'unknown'	END					AS is_allowed_to_drive					
      , UWDAT2.date_key_pk						AS utlfile_record_date	
      , TRIM(a.UWCMZN)							AS utlfile_comfort_zone_code
      --, a.UWDATJ
	  , CASE a.UWYARD 
			WHEN 'Y' THEN 'TRUE'
			WHEN 'N' THEN 'FALSE'
			ELSE 'unknown'	END					AS is_on_yard	
      , TRIM(a.UWBUNT)							AS utlfile_business_unit_code
      , CASE 
            WHEN TRIM(a.UWBUNT) = ''
                THEN NULL
            ELSE TRIM(LEFT(a.UWXFLD,13)) END    AS utlfile_business_class
      , CASE 
            WHEN TRIM(a.UWBUNT) = ''
                THEN NULL
            ELSE TRIM(RIGHT(a.UWXFLD,17)) END  AS utlfile_business_description
FROM data_central_lh.dbo.ibmi_utlfile_bronze a
LEFT JOIN gold.dim_date UWPDA ON a.UWPDA = UWPDA.date_key_pk
LEFT JOIN gold.dim_date UWDAT2 ON a.UWDAT2 = UWDAT2.date_key_pk