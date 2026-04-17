/***************************************************************************************************
Procedure:          dbo.usp_ibmi_commodity_silver
Create Date:        2024-03-21
Author:             Tom Wolfenden
Description:        Truncate and load of Cities Silver
Called by:            Azure Data Factory
					Pipeline: ibmi_commodity_master
Affected table(s):  silver.ibmi_commodity_master
Usage:              EXEC dbo.usp_ibmi_commodity_silver

****************************************************************************************************
SUMMARY OF CHANGES
#             Date(yyyy-mm-dd)    Author              Comments
------------------- ------------------ ------------------------------------------------------------
1            
***************************************************************************************************/

CREATE PROCEDURE [dbo].[usp_ibmi_commodity_silver]
AS

SET NOCOUNT ON

DELETE FROM silver.ibmi_commodity

INSERT INTO silver.ibmi_commodity
SELECT 
	   CONCAT(TRIM(COMCDE), '-', 
		TRIM(COMDIV))										AS	commodity_key
	  , TRIM(COMCDE)										AS  commodity_code
      , TRIM(COMDIV)										AS	division_code
      , CASE WHEN TRIM(COMDEL) = 'D' THEN 'TRUE'
		ELSE 'FALSE' END									AS	is_commodity_deleted
      , TRIM(COMDES)										AS	commodity_description
	  , CASE WHEN LEN(TRIM(COMCLS)) = 0 OR COMCLS IS NULL
			THEN 'unknown'
			ELSE COMCLS END									AS	commodity_class
      , TRIM(COMACC)										AS	commodity_cost_center
      , TRIM(COSHDS)										AS	commodity_short_descr
	  , CASE WHEN LEN(TRIM(COMTDC)) = 0 OR COMTDC IS NULL
			THEN 'unknown'
			ELSE COMTDC END									AS	commodity_tdcc_charge_code
	  , CASE WHEN LEN(TRIM(COMSTC)) = 0 OR COMSTC IS NULL
			THEN 'unknown'
			ELSE COMSTC END									AS	commodity_stcc_code
      , CASE WHEN LEN(TRIM(COMNMF)) = 0 OR COMNMF IS NULL
			THEN 'unknown'
			ELSE COMNMF END									AS	commodity_nmfc_code									
      , TRIM(CORTYP)										AS	commodity_revenue_type
      --, COMWGT Commodity Weight
      --, COMHGT Commodity Height
      --, COMLGT Commodity Length
      --, COMWDT Commodity Width
	  , CASE WHEN LEN(TRIM(COGSTC)) = 0 OR COGSTC IS NULL
			THEN 'unknown'
			ELSE COGSTC END									AS	commodity_gst_status	
      --, COOSTP SETTLEMENT TYPE 
      --, COPRTP PAYROLL TYPE
	  , CASE WHEN LEN(TRIM(COOSGL)) = 0 OR COOSGL IS NULL
			THEN 'unknown'
			ELSE COOSGL END									AS	commodity_gl_account
      --, COOSPC SETTLEMENT %
      --, COPRPC PAYROLL % 
      --, COOFC FUND CODE
      --, COTEMP TEMPERATURE
      --, COUNIT UNIT OF MEASURE
	  , CASE WHEN LEN(TRIM(COWASH)) = 0 OR COWASH IS NULL
			THEN 'unknown'
			ELSE COWASH END									AS	is_washout_required
      --, COGRAV GRAVITY OF COMODITY
      --, COPLAC PLACARD
      --, COHZFL HAZARDOUS FLAG
      --, COHZCD HAZARDOUS MATERIALS CODE
  FROM data_central_lh.dbo.ibmi_commodity_bronze