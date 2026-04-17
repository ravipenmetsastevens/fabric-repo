/***************************************************************************************************
Procedure:          dbo.usp_ibmi_unit_extension_silver
Create Date:        2025-09-11
Author:             Jeremy Shahan
Description:        Truncate and load of Unit Extension Silver
Called by:            Azure Data Factory
					Pipeline: ibmi_unit_extension
Affected table(s):  silver.ibmi_unit_extension
Usage:              EXEC dbo.usp_ibmi_unit_extension_silver

****************************************************************************************************
SUMMARY OF CHANGES
#             Date(yyyy-mm-dd)    Author              Comments
------------------- ------------------ ------------------------------------------------------------
1            
***************************************************************************************************/

CREATE   PROCEDURE [dbo].[usp_ibmi_unit_extension_silver]
AS

SET NOCOUNT ON

TRUNCATE TABLE  silver.ibmi_unit_extension

INSERT INTO silver.ibmi_unit_extension
SELECT
		TRIM(a.UXUNIT)											AS unit_extn_truck_number
      , TRIM(a.UXMCS#)											AS unit_extn_mobile_serial_number
      --, a.UXLOCT
      , CASE TRIM(a.UXAUTO)
			WHEN 'Y' THEN 'TRUE'
			WHEN 'N' THEN 'FALSE'
			ELSE 'unknown'	END									AS is_automatic_trans
      , CASE TRIM(SUBSTRING(a.UXXTRA,3,1))
			WHEN 'M' THEN 'Mentor'
			WHEN 'T' THEN 'Team'
			WHEN 'S' THEN 'Solo'
			WHEN 'X' THEN 'X-Team'
			ELSE 'unknown'	END									AS unit_extn_truck_category
	  , TRIM(SUBSTRING(a.UXXTRA,4,1))							AS unit_extn_carb_reg_code
	  , TRIM(SUBSTRING(a.UXXTRA,5,2))							AS unit_extn_business_unit_code
	  , CASE TRIM(SUBSTRING(a.UXXTRA,7,1))	
			WHEN 'Y' THEN 'TRUE'
			WHEN 'N' THEN 'FALSE'
			ELSE 'unknown'	END									AS has_digital_mirrors
--INTO data_central_wh.silver.ibmi_unit_extension
FROM data_central_lh.dbo.ibmi_unit_extension_bronze a