/***************************************************************************************************
Procedure:          dbo.usp_ibmi_service_exceptions_silver
Create Date:        2025-10-13
Author:             Jeremy Shahan
Description:        Truncate and load of Service Exceptions to Silver
Called by:          Fabric
					Pipeline: ibmi_service_exceptions
Affected table(s):  silver.ibmi_service_exceptions
Usage:              EXEC dbo.usp_ibmi_service_exceptions_silver

****************************************************************************************************
SUMMARY OF CHANGES
#             Date(yyyy-mm-dd)    Author              Comments
------------------- ------------------ ------------------------------------------------------------
1            
***************************************************************************************************/

CREATE     PROCEDURE [dbo].[usp_ibmi_service_exceptions_silver]
AS

SET NOCOUNT ON

DELETE FROM silver.ibmi_service_exceptions

INSERT INTO silver.ibmi_service_exceptions
SELECT 
		TRIM(a.SEORD)													AS serv_exc_load_number
      , a.SESEQ															AS serv_exc_sequence_number
      , CASE TRIM(a.SETYPE)
			WHEN 'AC' THEN 'Appointment Change'
			WHEN 'LA' THEN 'Late Arrival'
			WHEN 'ME' THEN 'Manual Entry'
			WHEN 'LU' THEN 'Low Utilization'
			WHEN 'RP' THEN 'Repower'
			WHEN 'DL' THEN 'Driver Late'
			WHEN 'LP' THEN 'Late Preplan'
			ELSE 'unknown'	END											AS serv_exc_type
      , TRIM(a.SEDISP)													AS serv_exc_dispatch
      , TRIM(a.SESTAT)													AS serv_exc_order_status_code
      , TRIM(a.SEUNIT)													AS serv_exc_truck_number
      , TRIM(a.SETRLR)													AS serv_exc_trailer_number
      , TRIM(a.SEDRV1)													AS serv_exc_seat_1_driver_code
      , TRIM(a.SEDM)													AS serv_exc_dm_code
      , TRIM(a.SEFM)													AS serv_exc_dmol_code
      , TRIM(a.SECSR)													AS serv_exc_csr_code
      , a.SESTP															AS serv_exc_stop_number
      , CASE TRIM(a.SERPT)
			WHEN 'Y' THEN 'TRUE'
			WHEN 'N' THEN 'FALSE'
			ELSE 'unknown'	END											AS is_customer_reportable
      , CASE TRIM(a.SESOCSR)
			WHEN 'Y' THEN 'TRUE'
			WHEN 'N' THEN 'FALSE'
			ELSE 'unknown'	END											AS has_csr_signoff
      , CASE TRIM(a.SESOCSR)
			WHEN 'Y' THEN 'TRUE'
			WHEN 'N' THEN 'FALSE'
			ELSE 'unknown'	END											AS has_dm_signoff
      , CASE TRIM(a.SERPCU)
			WHEN 'X' THEN 'TRUE'
			ELSE 'FALSE'	END											AS is_customer_responsible
      , CASE TRIM(a.SERPSH)
			WHEN 'X' THEN 'TRUE'
			ELSE 'FALSE'	END											AS is_shipper_responsible
      , CASE TRIM(a.SERPLD)
			WHEN 'X' THEN 'TRUE'
			ELSE 'FALSE'	END											AS is_loadat_responsible
      , CASE TRIM(a.SERPCN)
			WHEN 'X' THEN 'TRUE'
			ELSE 'FALSE'	END											AS is_consignee_responsible
      , CASE TRIM(a.SERPDR)
			WHEN 'X' THEN 'TRUE'
			ELSE 'FALSE'	END											AS is_driver_responsible
      , CASE TRIM(a.SERPEQ)
			WHEN 'X' THEN 'TRUE'
			ELSE 'FALSE'	END											AS is_equipment_responsible
      , CASE TRIM(a.SERPWE)
			WHEN 'X' THEN 'TRUE'
			ELSE 'FALSE'	END											AS is_weather_responsible
      , CASE TRIM(a.SERPSL)
			WHEN 'X' THEN 'TRUE'
			ELSE 'FALSE'	END											AS is_sales_responsible
      , CASE TRIM(a.SERPCS)
			WHEN 'X' THEN 'TRUE'
			ELSE 'FALSE'	END											AS is_csr_responsible
      , CASE TRIM(a.SERPPL)
			WHEN 'X' THEN 'TRUE'
			ELSE 'FALSE'	END											AS is_planner_responsible
      , CASE TRIM(a.SERPDM)
			WHEN 'X' THEN 'TRUE'
			ELSE 'FALSE'	END											AS is_dm_responsible
      , CASE TRIM(a.SERPBR)
			WHEN 'X' THEN 'TRUE'
			ELSE 'FALSE'	END											AS is_brokerage_responsible
      , SEDATE.date_key_pk												AS serv_exc_occurance_date
	  , CASE 
			WHEN a.SETIME <= 2359 
				AND LEN(CONVERT(VARCHAR(4),a.SETIME)) = 4 
			THEN TIMEFROMPARTS(LEFT(a.SETIME,2),RIGHT(a.SETIME,2),0,0,0)
			WHEN a.SETIME <= 2359 
				AND LEN(CONVERT(VARCHAR(4),a.SETIME)) = 3 
			THEN TIMEFROMPARTS(LEFT(a.SETIME,1),RIGHT(a.SETIME,2),0,0,0)
			WHEN a.SETIME <= 2359 
				AND LEN(CONVERT(VARCHAR(4),a.SETIME)) IN (1,2)
			THEN TIMEFROMPARTS(0,a.SETIME,0,0,0)
			ELSE NULL END												AS serv_exc_occurance_time
      , SECRED.date_key_pk												AS serv_exc_create_date
	  , CASE 
			WHEN a.SECRET <= 2359 
				AND LEN(CONVERT(VARCHAR(4),a.SECRET)) = 4 
			THEN TIMEFROMPARTS(LEFT(a.SECRET,2),RIGHT(a.SECRET,2),0,0,0)
			WHEN a.SECRET <= 2359 
				AND LEN(CONVERT(VARCHAR(4),a.SECRET)) = 3 
			THEN TIMEFROMPARTS(LEFT(a.SECRET,1),RIGHT(a.SECRET,2),0,0,0)
			WHEN a.SECRET <= 2359 
				AND LEN(CONVERT(VARCHAR(4),a.SECRET)) IN (1,2)
			THEN TIMEFROMPARTS(0,a.SECRET,0,0,0)
			ELSE NULL END												AS serv_exc_create_time
      , TRIM(a.SECREI)													AS serv_exc_create_user_code
      , TRIM(a.SEPGM)													AS serv_exc_create_program_code
      , SEUPDD.date_key_pk												AS serv_exc_last_update_date
	  , CASE 
			WHEN a.SEUPDT <= 2359 
				AND LEN(CONVERT(VARCHAR(4),a.SEUPDT)) = 4
				AND a.SEUPDD <> 0
			THEN TIMEFROMPARTS(LEFT(a.SEUPDT,2),RIGHT(a.SEUPDT,2),0,0,0)
			WHEN a.SEUPDT <= 2359 
				AND LEN(CONVERT(VARCHAR(4),a.SEUPDT)) = 3 
				AND a.SEUPDD <> 0
			THEN TIMEFROMPARTS(LEFT(a.SEUPDT,1),RIGHT(a.SEUPDT,2),0,0,0)
			WHEN a.SEUPDT <= 2359 
				AND LEN(CONVERT(VARCHAR(4),a.SEUPDT)) IN (1,2)
				AND a.SEUPDD <> 0
			THEN TIMEFROMPARTS(0,a.SEUPDT,0,0,0)
			ELSE NULL END												AS serv_exc_last_update_time
      , TRIM(a.SEUPDI)													AS serv_exc_last_update_user_code
      , CASE TRIM(a.SERPNC)
			WHEN 'X' THEN 'TRUE'
			ELSE 'FALSE'	END											AS is_no_charge
      , CASE TRIM(a.SERPRL)
			WHEN 'X' THEN 'TRUE'
			ELSE 'FALSE'	END											AS is_rail_responsible
      , CASE TRIM(a.SESOUSR)
			WHEN 'Y' THEN 'TRUE'
			WHEN 'N' THEN 'FALSE'
			ELSE 'unknown'	END											AS has_planner_signoff
      , TRIM(a.SEPLAN)													AS serv_exc_planner_code
      , CASE TRIM(a.SESEV)
			WHEN 'E' THEN 'Exception'
			WHEN 'F' THEN 'Failure'
			ELSE 'unknown'	END											AS serv_exc_severity
      , TRIM(a.SEACRSN)													AS serv_exc_appt_change_reason_code
      , CASE TRIM(a.SERPTDR)
			WHEN 'Y' THEN 'TRUE'
			WHEN 'N' THEN 'FALSE'
			ELSE 'unknown'	END											AS is_driver_reportable
      , TRIM(a.SESESTAT)												AS serv_exc_exception_status_code
      , TRIM(a.SERM)													AS serv_exc_regional_manager_code
      , CASE TRIM(a.SERPRC)
			WHEN 'X' THEN 'TRUE'
			ELSE 'FALSE'	END											AS is_road_condition_responsible
      , TRIM(a.SEREGN)													AS serv_exc_region_code
--INTO data_central_wh.silver.ibmi_service_exceptions
FROM data_central_lh.dbo.ibmi_service_exceptions_bronze a
LEFT JOIN data_central_wh.gold.dim_date SEDATE ON a.SEDATE = SEDATE.date_ordinal
LEFT JOIN data_central_wh.gold.dim_date SECRED ON a.SECRED = SECRED.date_ordinal
LEFT JOIN data_central_wh.gold.dim_date SEUPDD ON a.SEUPDD = SEUPDD.date_ordinal