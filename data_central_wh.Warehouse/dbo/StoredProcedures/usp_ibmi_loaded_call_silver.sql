/***************************************************************************************************
Procedure:          dbo.usp_ibmi_loaded_call_silver
Create Date:        2025-10-30
Author:             Jeremy Shahan
Description:        Truncate and load of Loaded Call to Silver
Called by:          Fabric
					Pipeline: ibmi_loaded_call
Affected table(s):  silver.ibmi_loaded_call
Usage:              EXEC dbo.usp_ibmi_loaded_call_silver

****************************************************************************************************
SUMMARY OF CHANGES
#             Date(yyyy-mm-dd)    Author              Comments
------------------- ------------------ ------------------------------------------------------------
1				        
***************************************************************************************************/

CREATE    PROCEDURE [dbo].[usp_ibmi_loaded_call_silver]
AS

SET NOCOUNT ON

DELETE FROM silver.ibmi_loaded_call

INSERT INTO silver.ibmi_loaded_call

SELECT 
	  TRIM(a.CNUNIT)																		AS loaded_call_truck_number
	, TRIM(a.CNORD#)																		AS loaded_call_load_number
	, TRIM(a.CNDISP)																		AS loaded_call_dispatch
	, TRIM(a.CNCALL)																		AS loaded_call_call_number
	, TRIM(a.CNTRLR)																		AS loaded_call_trailer_number
	, TRIM(a.CNDRV1)																		AS loaded_call_seat_1_driver_code
	, TRIM(a.CNDRV2)																		AS loaded_call_seat_2_driver_code
	, CNDATE.date_key_pk																	AS loaded_call_contact_date
	, CASE 
		WHEN CONVERT(INT,  a.CNTIME) < 2400 AND LEN(TRIM(a.CNTIME)) = 4
			THEN TRY_CONVERT(TIME(0),CONCAT(LEFT(a.CNTIME,2),':',RIGHT(a.CNTIME,2)))
		ELSE NULL END																		AS loaded_call_contact_time
	, TRIM(a.CNCODE)																		AS loaded_call_type_code
	, TRIM(a.CNLOC)																			AS loaded_call_location_code
	, TRIM(a.CNSNM)																			AS loaded_call_city_short_name
	, TRIM(a.CNINIT)																		AS loaded_call_initials
	, TRIM(a.CNREST)																		AS loaded_call_message_details
	, a.CNHUB																				AS loaded_call_hub_reading
	, a.CNTEMP																				AS loaded_call_temp_reading
	, TRIM(a.CNHUBN)																		AS loaded_call_hub_flag
--INTO data_central_wh.silver.ibmi_loaded_call
FROM data_central_lh.dbo.ibmi_loaded_call_bronze a
LEFT JOIN gold.dim_date CNDATE ON a.CNDATE = CNDATE.date_ordinal