/***************************************************************************************************
Procedure:          dbo.usp_ibmi_autorated_loads_silver
Create Date:        2026-03-27
Author:             Jeremy Shahan
Description:        Truncate and load of Auto Rated Load Records to Silver
Called by:          Fabric
					Pipeline: ibmi_autorated_loads
Affected table(s):  silver.ibmi_autorated_loads
Usage:              EXEC dbo.usp_autorated_loads_silver

****************************************************************************************************
SUMMARY OF CHANGES
#             Date(yyyy-mm-dd)    Author              Comments
------------------- ------------------ ------------------------------------------------------------
1            
***************************************************************************************************/

CREATE     PROCEDURE [dbo].[usp_ibmi_autorated_loads_silver]
AS

SET NOCOUNT ON

DELETE FROM silver.ibmi_autorated_loads

INSERT INTO silver.ibmi_autorated_loads
SELECT 
		TRIM(a.CFORDER)																											AS autorated_load_number
	  , CASE
			WHEN LEN(CONVERT(VARCHAR(8),a.CFDATE)) = 8
                THEN DATEFROMPARTS(LEFT(a.CFDATE,4),SUBSTRING(CONVERT(VARCHAR(8),a.CFDATE),5,2),RIGHT(a.CFDATE,2))
                ELSE NULL END																									AS autorated_rated_date      
      , TRIM(a.CFCONFIRM)																										AS autorated_status_code
      , TRIM(a.CFCONTRID)																										AS autorated_contract_code
	  , CASE
			WHEN LEN(CONVERT(VARCHAR(8),a.CFCONTDT)) = 8
                THEN DATEFROMPARTS(LEFT(a.CFCONTDT,4),SUBSTRING(CONVERT(VARCHAR(8),a.CFCONTDT),5,2),RIGHT(a.CFCONTDT,2))
                ELSE NULL END																									AS autorated_contract_date      
	  , CASE
			WHEN LEN(CONVERT(VARCHAR(8),a.CFEXPIREDT)) = 8
                THEN DATEFROMPARTS(LEFT(a.CFEXPIREDT,4),SUBSTRING(CONVERT(VARCHAR(8),a.CFEXPIREDT),5,2),RIGHT(a.CFEXPIREDT,2))
                ELSE NULL END																									AS autorated_rate_expiration_date      
	  , CASE
			WHEN LEN(CONVERT(VARCHAR(8),a.CFEFFECTDT)) = 8
                THEN DATEFROMPARTS(LEFT(a.CFEFFECTDT,4),SUBSTRING(CONVERT(VARCHAR(8),a.CFEFFECTDT),5,2),RIGHT(a.CFEFFECTDT,2))
                ELSE NULL END																									AS autorated_rate_effective_date      
      , TRIM(a.CFBILLTO)																										AS autorated_billto_code
      , TRIM(a.CFOST)																											AS autorated_origin_state
      , TRIM(a.CFOCITY)																											AS autorated_origin_city_code
      , TRIM(a.CFDST)																											AS autorated_destination_state
      , TRIM(a.CFDCITY)																											AS autorated_destination_city_code
      , TRIM(a.CFOZIP)																											AS autorated_origin_zip
      , TRIM(a.CFDZIP)																											AS autorated_destination_zip
      , TRIM(a.CFRATETYP)																										AS autorated_rate_type_code
      , a.CFPERMILE																												AS autorated_rate_per_mile
      , a.CFMINIMUM																												AS autorated_minimum_rate
      , a.CFFLATRATE																											AS autorated_flat_rate
      , TRIM(a.CFRATERTN)																										AS autorated_rate_match_note
	  , CASE
			WHEN LEN(CONVERT(VARCHAR(8),a.CFADDDATE)) = 8
                THEN DATEFROMPARTS(LEFT(a.CFADDDATE,4),SUBSTRING(CONVERT(VARCHAR(8),a.CFADDDATE),5,2),RIGHT(a.CFADDDATE,2))
                ELSE NULL END																									AS autorated_create_date      
	  , CASE 
			WHEN LEN(CONVERT(VARCHAR(6),a.CFADDTIME)) = 6 
			    THEN TIMEFROMPARTS(LEFT(a.CFADDTIME,2),SUBSTRING(CONVERT(VARCHAR(6),a.CFADDTIME),3,2),RIGHT(a.CFADDTIME,2),0,0)
            WHEN LEN(CONVERT(VARCHAR(6),a.CFADDTIME)) = 5 
			    THEN TIMEFROMPARTS(LEFT(a.CFADDTIME,1),SUBSTRING(CONVERT(VARCHAR(6),a.CFADDTIME),2,2),RIGHT(a.CFADDTIME,2),0,0)
            ELSE NULL END																										AS autorated_create_time     
      , TRIM(a.CFADDUSER)																										AS autorated_create_user_code
--INTO data_central_wh.silver.ibmi_autorated_loads
FROM data_central_lh.dbo.ibmi_autorated_loads_bronze a