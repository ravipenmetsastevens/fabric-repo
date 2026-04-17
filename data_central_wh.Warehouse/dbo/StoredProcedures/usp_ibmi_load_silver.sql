/***************************************************************************************************
Procedure:          dbo.usp_ibmi_load_silver
Create Date:        2024-03-21
Author:             Tom Wolfenden
Description:        Truncate and load of load Silver
Called by:            Azure Data Factory
					Pipeline: ibmi_load_master
Affected table(s):  silver.ibmi_load_master
Usage:              EXEC dbo.usp_ibmi_load_silver

****************************************************************************************************
SUMMARY OF CHANGES
#             Date(yyyy-mm-dd)    Author              Comments
------------------- ------------------ ------------------------------------------------------------
1            
***************************************************************************************************/

CREATE PROCEDURE [dbo].[usp_ibmi_load_silver]
AS

SET NOCOUNT ON

DELETE FROM silver.ibmi_load

INSERT INTO silver.ibmi_load (
    load_origin_area_code,
    load_load_number,
    load_dispatch,
    load_status,
    load_dispatch_date,
    load_dispatch_time,
    load_truck_number,
    load_trailer_number,
    load_seat_1_driver_code,
    load_seat_2_driver_code,
    load_route_line_codes,
    load_route_status,
    load_miles_dead_head,
    load_miles_total,
    load_miles_loaded,
    load_mile_flag,
    load_initials,
    load_destination_area_code,
    load_route_line_extension,
    load_dispatch_end_date,
    load_dispatch_end_time,
    load_multiple_trailers_on_dispatch,
    load_settlement_flag,
    load_payroll_approval_flag,
    load_truck_dmol_code,
    load_truck_dm_code,
    load_driver_dmol_code,
    load_driver_dm_code,
    load_trip_jacket_received_flag,
    load_trip_jacket_received_date,
    load_miles_hub_start,
    load_miles_hub_end,
    load_unit_division_code,
    load_team_status_code,
    load_trainer_team_code
)
SELECT 
    TRIM(a.DIARA),
    TRIM(a.DIODR),
    TRIM(a.DIDISP),
    TRIM(a.DILDST),
    DIDATE.date_key_pk,
    TRIM(a.DITIME),
    TRIM(a.DIUNIT),
    TRIM(a.DITRLR),
    TRIM(a.DIDR1),
    TRIM(a.DIDR2),
    TRIM(a.DIROUT),
    TRIM(a.DIRTST),
    a.DIEMIL,
    a.DITMIL,
    a.DISMNF,
    TRIM(a.DIMIFL),
    TRIM(a.DIINIT),
    TRIM(a.DIAREA),
    TRIM(a.DICONT),
    DIETAD.date_key_pk,
    TRIM(a.DIETAT),
    TRIM(a.DIMTRL),
    TRIM(a.DISTST),
    TRIM(a.DIAPRV),
    TRIM(a.DIUFMG),
    TRIM(a.DIUDMG),
    TRIM(a.DIDFMG),
    TRIM(a.DIDDMG),
    TRIM(a.DITJR),
    DITJD.date_key_pk,
    a.DIBHUB,
    a.DIEHUB,
    TRIM(LEFT(a.DIOWNR,3)),
    TRIM(RIGHT(a.DIOWNR,2)),
    TRIM(a.DITRN2)
FROM data_central_lh.dbo.ibmi_load_bronze a
LEFT JOIN gold.dim_date DIDATE ON a.DIDATE = DIDATE.date_ordinal
LEFT JOIN gold.dim_date DIETAD ON a.DIETAD = DIETAD.date_ordinal
LEFT JOIN gold.dim_date DITJD ON a.DITJD = DITJD.date_ordinal;