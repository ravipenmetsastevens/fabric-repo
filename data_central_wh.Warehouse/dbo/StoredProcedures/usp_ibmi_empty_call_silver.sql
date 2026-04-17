/***************************************************************************************************
Procedure:          dbo.usp_ibmi_empty_call_silver
Create Date:        2026-02-20
Author:             Jeremy Shahan
Description:        Truncate and load of Empty Call to Silver
Called by:          Fabric
					Pipeline: ibmi_empty_call
Affected table(s):  silver.ibmi_empty_call
Usage:              EXEC dbo.usp_ibmi_empty_call_silver

****************************************************************************************************
SUMMARY OF CHANGES
#             Date(yyyy-mm-dd)    Author              Comments
------------------- ------------------ ------------------------------------------------------------
1            
***************************************************************************************************/

CREATE     PROCEDURE [dbo].[usp_ibmi_empty_call_silver]
AS

SET NOCOUNT ON

DELETE FROM silver.ibmi_empty_call

INSERT INTO silver.ibmi_empty_call

SELECT 
	  TRIM(a.CNUNIT)																		AS empty_call_truck_number
	, TRIM(a.CNORD)																		AS empty_call_load_number
	, TRIM(a.CNDISP)																		AS empty_call_dispatch
	, TRIM(a.CNCALL)																		AS empty_call_call_number
	, TRIM(a.CNTRLR)																		AS empty_call_trailer_number
	, TRIM(a.CNDRV1)																		AS empty_call_seat_1_driver_code
	, TRIM(a.CNDRV2)																		AS empty_call_seat_2_driver_code
	, CNDATE.date_key_pk																	AS empty_call_contact_date
	, CASE 
		WHEN CONVERT(INT,  a.CNTIME) < 2400 AND LEN(TRIM(a.CNTIME)) = 4
			THEN TRY_CONVERT(TIME(0),CONCAT(LEFT(a.CNTIME,2),':',RIGHT(a.CNTIME,2)))
		ELSE NULL END																		AS empty_call_contact_time
	, TRIM(a.CNCODE)																		AS empty_call_type_code
	, TRIM(a.CNLOC)																			AS empty_call_location_code
	, TRIM(a.CNSNM)																			AS empty_call_city_short_name
	, TRIM(a.CNINIT)																		AS empty_call_initials
	, TRIM(a.CNREST)																		AS empty_call_message_details
	, a.CNHUB																				AS empty_call_hub_reading
	, a.CNTEMP																				AS empty_call_temp_reading
	, TRIM(a.CNHUBN)																		AS empty_call_hub_flag
--INTO data_central_wh.silver.ibmi_empty_call
FROM data_central_lh.dbo.ibmi_empty_call_bronze a
LEFT JOIN gold.dim_date CNDATE ON a.CNDATE = CNDATE.date_ordinal