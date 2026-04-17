/***************************************************************************************************
Procedure:          dbo.usp_ibmi_incr_load_silver
Create Date:        2024-08-31
Author:             Jeremy Shahan
Description:        Truncate and load of Incremental load to Silver
Called by:          Fabric
					Pipeline: ibmi_incr_load_master
Affected table(s):  silver.ibmi_incr_load_master
Usage:              EXEC dbo.usp_ibmi_incr_load_silver

****************************************************************************************************
SUMMARY OF CHANGES
#             Date(yyyy-mm-dd)    Author              Comments
------------------- ------------------ ------------------------------------------------------------
1            
***************************************************************************************************/

CREATE   PROCEDURE [dbo].[usp_ibmi_incr_load_silver]
AS

SET NOCOUNT ON

DELETE FROM silver.ibmi_incr_load

INSERT INTO silver.ibmi_incr_load
SELECT 
	  TRIM(a.DIARA)																			AS load_origin_area_code
	, TRIM(a.DIODR)																			AS load_load_number
    , TRIM(a.DIDISP)																		AS load_dispatch
	, TRIM(a.DILDST)																		AS load_status
	--, TRIM(a.DIRCST)																		Unused
	, DIDATE.date_key_pk																	AS load_dispatch_date
	--, CASE WHEN CONVERT(INT, a.DITIME) < 2400 AND LEN(TRIM(a.DITIME)) = 4
	--	THEN CONVERT(TIME, (CONCAT(LEFT(TRIM(a.DITIME),2)
	--	     ,':',RIGHT(TRIM(a.DITIME),2))))
	--	ELSE NULL END																		AS load_dispatch_time				   NEED TO LOOK INTO THIS.  Bad data, column includes alphas like 'Q123'
	, TRIM(a.DITIME)																		AS load_dispatch_time
	, TRIM(a.DIUNIT)																		AS load_truck_number
	, TRIM(a.DITRLR)																		AS load_trailer_number
	, TRIM(a.DIDR1)																			AS load_seat_1_driver_code
	, TRIM(a.DIDR2)																			AS load_seat_2_driver_code
	, TRIM(a.DIROUT)																		AS load_route_line_codes
	, TRIM(a.DIRTST)																		AS load_route_status
	, a.DIEMIL																				AS load_miles_dead_head
	, a.DITMIL																				AS load_miles_total
	, a.DISMNF																				AS load_miles_loaded
	--, a.DIMTAF																			Unused
	, TRIM(a.DIMIFL)																		AS load_mile_flag
	, TRIM(a.DIINIT)																		AS load_initials
	, TRIM(a.DIAREA)																		AS load_destination_area_code
	--, TRIM(a.DITRIP)																		Unused
	, TRIM(a.DICONT)																		AS load_route_line_extension
	--, TRIM(a.DIMULT)																		Unused
	--, TRIM(a.DIPORD)																		Unused
	--, TRIM(a.DIPDSP)																		Unused
	, DIETAD.date_key_pk																	AS load_dispatch_end_date 
	--, CASE WHEN CONVERT(INT, a.DIETAT) < 2400 AND LEN(TRIM(a.DIETAT)) = 4
	--	THEN CONVERT(TIME, (CONCAT(LEFT(TRIM(a.DIETAT),2)
	--	     ,':',RIGHT(TRIM(a.DIETAT),2))))
	--	ELSE NULL END																		AS load_dispatch_end_time			NEED TO LOOK INTO THIS.  Bad data, column includes alphas like 'Q123'
	, TRIM(a.DIETAT)																		AS load_dispatch_end_time
	, TRIM(a.DIMTRL)																		AS load_multiple_trailers_on_dispatch
	, TRIM(a.DISTST)																		AS load_settlement_flag
	, TRIM(a.DIAPRV)																		AS load_payroll_approval_flag
	, TRIM(a.DIUFMG)																		AS load_truck_dmol_code
	, TRIM(a.DIUDMG)																		AS load_truck_dm_code
	, TRIM(a.DIDFMG)																		AS load_driver_dmol_code
	, TRIM(a.DIDDMG)																		AS load_driver_dm_code
	, TRIM(a.DITJR)																			AS load_trip_jacket_received_flag
	, DITJD.date_key_pk																		AS load_trip_jacket_received_date
	, a.DIBHUB																				AS load_miles_hub_start
	, a.DIEHUB																				AS load_miles_hub_end
	--, a.DIBODO																			Unused
	--, a.DIEODO																			Unused
	, TRIM(LEFT(a.DIOWNR,3))																AS load_unit_division_code
	, TRIM(RIGHT(a.DIOWNR,2))																AS load_team_status_code 
	, TRIM(a.DITRN2)																		AS load_trainer_team_code --Y/N/S/Blank
FROM data_central_lh.dbo.ibmi_incr_load_bronze a
LEFT JOIN gold.dim_date DIDATE ON a.DIDATE = DIDATE.date_ordinal
LEFT JOIN gold.dim_date DIETAD ON a.DIETAD = DIETAD.date_ordinal
LEFT JOIN gold.dim_date DITJD ON a.DITJD = DITJD.date_ordinal