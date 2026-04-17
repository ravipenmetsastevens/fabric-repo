/***************************************************************************************************
Procedure:          dbo.usp_ibmi_edi_reject_details_silver
Create Date:        2026-01-07
Author:             Jeremy Shahan
Description:        Truncate and load of EDI Rejection Details to Silver
Called by:          Fabric
					Pipeline: ibmi_edi_reject_details
Affected table(s):  silver.ibmi_edi_reject_details
Usage:              EXEC dbo.usp_ibmi_edi_reject_details_silver

****************************************************************************************************
SUMMARY OF CHANGES
#             Date(yyyy-mm-dd)    Author              Comments
------------------- ------------------ ------------------------------------------------------------
1            
***************************************************************************************************/

CREATE     PROCEDURE [dbo].[usp_ibmi_edi_reject_details_silver]
AS

SET NOCOUNT ON

DELETE FROM silver.ibmi_edi_reject_details

INSERT INTO silver.ibmi_edi_reject_details
SELECT 
	    TRIM(a.ELTNAM)												AS edi_rejects_customer_name
      , TRIM(a.ORICOD)												AS edi_rejects_origin
      , TRIM(a.DESCOD)												AS edi_rejects_destination
      , TRIM(a.EOODR)												AS edi_rejects_bol
      , TRIM(a.TOMGMT)												AS edi_rejects_comment
      , EOPDAT.date_key_pk											AS edi_rejects_pickup_date	
      , EODDAT.date_key_pk											AS edi_rejects_delivery_date	
      , a.RJDATE													AS edi_rejects_reject_date
      , EOTNDT.date_key_pk											AS edi_rejects_tender_date
	  , CASE 
			WHEN a.EOTNTM <= 2359 
				AND LEN(CONVERT(VARCHAR(4),CONVERT(INT,a.EOTNTM))) = 4 
			THEN TIMEFROMPARTS(LEFT(CONVERT(INT,a.EOTNTM),2),RIGHT(CONVERT(INT,a.EOTNTM),2),0,0,0)
			WHEN a.EOTNTM <= 2359 
				AND LEN(CONVERT(VARCHAR(4),CONVERT(INT,a.EOTNTM))) = 3 
			THEN TIMEFROMPARTS(LEFT(CONVERT(INT,a.EOTNTM),1),RIGHT(CONVERT(INT,a.EOTNTM),2),0,0,0)
			WHEN a.EOTNTM <= 2359 
				AND LEN(CONVERT(VARCHAR(4),CONVERT(INT,a.EOTNTM))) IN (1,2)
			THEN TIMEFROMPARTS(0,CONVERT(INT,a.EOTNTM),0,0,0)
			ELSE NULL END												AS edi_rejects_tender_time     
      , TRIM(a.EOBBOC)													AS edi_rejects_load_type
      , a.EOTMPL														AS edi_rejects_temp_low
      , a.EOTMPH														AS edi_rejects_temp_high
      , TRIM(a.USRNAM)													AS edi_rejects_user_code
      , a.EOMILE														AS edi_rejects_miles_billable
--INTO data_central_wh.silver.ibmi_edi_reject_details
FROM data_central_lh.dbo.ibmi_edi_reject_details_bronze a
LEFT JOIN gold.dim_date EOPDAT ON a.EOPDAT = EOPDAT.date_ordinal
LEFT JOIN gold.dim_date EODDAT ON a.EODDAT = EODDAT.date_ordinal
LEFT JOIN gold.dim_date EOTNDT ON a.EOTNDT = EOTNDT.date_ordinal