/***************************************************************************************************
Procedure:          dbo.usp_ibmi_service_exceptions_edi_silver
Create Date:        2025-12-18
Author:             Jeremy Shahan
Description:        Truncate and load of Service Exceptions from EDISRH to Silver
Called by:          Fabric
					Pipeline: ibmi_service_exceptions_edi
Affected table(s):  silver.ibmi_service_exceptions_edi
Usage:              EXEC dbo.usp_ibmi_service_exceptions_edi_silver

****************************************************************************************************
SUMMARY OF CHANGES
#             Date(yyyy-mm-dd)    Author              Comments
------------------- ------------------ ------------------------------------------------------------
1            
***************************************************************************************************/

CREATE     PROCEDURE [dbo].[usp_ibmi_service_exceptions_edi_silver]
AS

SET NOCOUNT ON

DELETE FROM silver.ibmi_service_exceptions_edi

INSERT INTO silver.ibmi_service_exceptions_edi
SELECT 
        TRIM(a.ERORD)													AS se_load_number
      , a.ERSTOP														AS se_stop_number
      , TRIM(a.ERCODE)													AS se_edi_code
      , a.ERSEQ															AS se_record_number
      , TRIM(a.ERSTYP)													AS se_status_type
      , TRY_CONVERT(DATE,CONVERT(VARCHAR(6),CONVERT(INT,a.EREDAT)),12)	AS se_create_date
	  , CASE 
			WHEN a.ERETIM <= 2359 
				AND LEN(CONVERT(VARCHAR(4),CONVERT(INT,a.ERETIM))) = 4 
			THEN TIMEFROMPARTS(LEFT(CONVERT(INT,a.ERETIM),2),RIGHT(CONVERT(INT,a.ERETIM),2),0,0,0)
			WHEN a.ERETIM <= 2359 
				AND LEN(CONVERT(VARCHAR(4),CONVERT(INT,a.ERETIM))) = 3 
			THEN TIMEFROMPARTS(LEFT(CONVERT(INT,a.ERETIM),1),RIGHT(CONVERT(INT,a.ERETIM),2),0,0,0)
			WHEN a.ERETIM <= 2359 
				AND LEN(CONVERT(VARCHAR(4),CONVERT(INT,a.ERETIM))) IN (1,2)
			THEN TIMEFROMPARTS(0,CONVERT(INT,a.ERETIM),0,0,0)
			ELSE NULL END												AS se_create_time
      , TRIM(a.ERREM)													AS se_remarks
	  , CASE 
			WHEN a.ERSDAT > 0
			AND LEN(CONVERT(VARCHAR(6),CONVERT(INT,a.ERSDAT))) = 6
				THEN DATEFROMPARTS('20'+
				  RIGHT(CONVERT(VARCHAR(6),CONVERT(INT,a.ERSDAT)),2)
				, LEFT(CONVERT(VARCHAR(6),CONVERT(INT,a.ERSDAT)),2)
				, SUBSTRING(CONVERT(VARCHAR(6),CONVERT(INT,a.ERSDAT)),3,2)
				)
			WHEN a.ERSDAT > 0
			AND LEN(CONVERT(VARCHAR(6),CONVERT(INT,a.ERSDAT))) = 5
				THEN DATEFROMPARTS('20'+
				  RIGHT(CONVERT(VARCHAR(6),CONVERT(INT,a.ERSDAT)),2)
				, LEFT(CONVERT(VARCHAR(6),CONVERT(INT,a.ERSDAT)),1)
				, SUBSTRING(CONVERT(VARCHAR(6),CONVERT(INT,a.ERSDAT)),2,2)
				)
			ELSE NULL END												AS se_changed_date
	  , CASE 
			WHEN a.ERSTIM <= 2359 
				AND LEN(CONVERT(VARCHAR(4),CONVERT(INT,a.ERSTIM))) = 4 
			THEN TIMEFROMPARTS(LEFT(CONVERT(INT,a.ERSTIM),2),RIGHT(CONVERT(INT,a.ERSTIM),2),0,0,0)
			WHEN a.ERSTIM <= 2359 
				AND LEN(CONVERT(VARCHAR(4),CONVERT(INT,a.ERSTIM))) = 3 
			THEN TIMEFROMPARTS(LEFT(CONVERT(INT,a.ERSTIM),1),RIGHT(CONVERT(INT,a.ERSTIM),2),0,0,0)
			WHEN a.ERSTIM <= 2359 
				AND LEN(CONVERT(VARCHAR(4),CONVERT(INT,a.ERSTIM))) IN (1,2)
			THEN TIMEFROMPARTS(0,CONVERT(INT,a.ERSTIM),0,0,0)
			ELSE NULL END												AS se_changed_time
	  --, CASE 
			--WHEN a.ERTDAT > 0
			--AND LEN(CONVERT(VARCHAR(6),CONVERT(INT,a.ERTDAT))) = 6
			--	THEN DATEFROMPARTS('20'+
			--	  RIGHT(CONVERT(VARCHAR(6),CONVERT(INT,a.ERTDAT)),2)
			--	, LEFT(CONVERT(VARCHAR(6),CONVERT(INT,a.ERTDAT)),2)
			--	, SUBSTRING(CONVERT(VARCHAR(6),CONVERT(INT,a.ERTDAT)),3,2)
			--	)
			--WHEN a.ERTDAT > 0
			--AND LEN(CONVERT(VARCHAR(6),CONVERT(INT,a.ERTDAT))) = 5
			--	THEN DATEFROMPARTS('20'+
			--	  RIGHT(CONVERT(VARCHAR(6),CONVERT(INT,a.ERTDAT)),2)
			--	, LEFT(CONVERT(VARCHAR(6),CONVERT(INT,a.ERTDAT)),1)
			--	, SUBSTRING(CONVERT(VARCHAR(6),CONVERT(INT,a.ERTDAT)),2,2)
			--	)
			--ELSE NULL END												AS se_download_date
	  --, CASE 
			--WHEN a.ERTTIM <= 2359 
			--	AND LEN(CONVERT(VARCHAR(4),CONVERT(INT,a.ERTTIM))) = 4 
			--THEN TIMEFROMPARTS(LEFT(CONVERT(INT,a.ERTTIM),2),RIGHT(CONVERT(INT,a.ERTTIM),2),0,0,0)
			--WHEN a.ERTTIM <= 2359 
			--	AND LEN(CONVERT(VARCHAR(4),CONVERT(INT,a.ERTTIM))) = 3 
			--THEN TIMEFROMPARTS(LEFT(CONVERT(INT,a.ERTTIM),1),RIGHT(CONVERT(INT,a.ERTTIM),2),0,0,0)
			--WHEN a.ERTTIM <= 2359 
			--	AND LEN(CONVERT(VARCHAR(4),CONVERT(INT,a.ERTTIM))) IN (1,2)
			--THEN TIMEFROMPARTS(0,CONVERT(INT,a.ERTTIM),0,0,0)
			--ELSE NULL END												AS se_download_time
      , RIGHT(a.ERLATE,2)											AS se_reason_code
      , TRIM(a.ERINIT)													AS se_audit_user_code
	  --, CASE 
			--WHEN a.ERADAT > 0
			--AND LEN(CONVERT(VARCHAR(6),CONVERT(INT,a.ERADAT))) = 6
			--	THEN DATEFROMPARTS('20'+
			--	  RIGHT(CONVERT(VARCHAR(6),CONVERT(INT,a.ERADAT)),2)
			--	, LEFT(CONVERT(VARCHAR(6),CONVERT(INT,a.ERADAT)),2)
			--	, SUBSTRING(CONVERT(VARCHAR(6),CONVERT(INT,a.ERADAT)),3,2)
			--	)
			--WHEN a.ERADAT > 0
			--AND LEN(CONVERT(VARCHAR(6),CONVERT(INT,a.ERADAT))) = 5
			--	THEN DATEFROMPARTS('20'+
			--	  RIGHT(CONVERT(VARCHAR(6),CONVERT(INT,a.ERADAT)),2)
			--	, LEFT(CONVERT(VARCHAR(6),CONVERT(INT,a.ERADAT)),1)
			--	, SUBSTRING(CONVERT(VARCHAR(6),CONVERT(INT,a.ERADAT)),2,2)
			--	)
			--ELSE NULL END												AS se_audit_date
	  --, CASE 
			--WHEN a.ERATIM <= 2359 
			--	AND LEN(CONVERT(VARCHAR(4),CONVERT(INT,a.ERATIM))) = 4 
			--THEN TIMEFROMPARTS(LEFT(CONVERT(INT,a.ERATIM),2),RIGHT(CONVERT(INT,a.ERATIM),2),0,0,0)
			--WHEN a.ERATIM <= 2359 
			--	AND LEN(CONVERT(VARCHAR(4),CONVERT(INT,a.ERATIM))) = 3 
			--THEN TIMEFROMPARTS(LEFT(CONVERT(INT,a.ERATIM),1),RIGHT(CONVERT(INT,a.ERATIM),2),0,0,0)
			--WHEN a.ERATIM <= 2359 
			--	AND LEN(CONVERT(VARCHAR(4),CONVERT(INT,a.ERATIM))) IN (1,2)
			--THEN TIMEFROMPARTS(0,CONVERT(INT,a.ERATIM),0,0,0)
			--ELSE NULL END												AS se_audit_time
      , a.ERTMZN														AS se_stop_time_zone
      , CASE TRIM(a.ERDSTM)
			WHEN 'Y' THEN 'TRUE'
			WHEN 'N' THEN 'FALSE'
			ELSE 'unknown' END											AS is_daylight_savings_time
--INTO data_central_wh.silver.ibmi_service_exceptions_edi
FROM data_central_lh.dbo.ibmi_service_exceptions_edi_bronze a