/***************************************************************************************************
Procedure:          dbo.usp_ibmi_service_exceptions_la_silver
Create Date:        2025-10-14
Author:             Jeremy Shahan
Description:        Truncate and load of Service Exceptions for Late Arrivals to Silver
Called by:          Fabric
					Pipeline: ibmi_service_exceptions_la
Affected table(s):  silver.ibmi_service_exceptions_la
Usage:              EXEC dbo.usp_ibmi_service_exceptions_la_silver

****************************************************************************************************
SUMMARY OF CHANGES
#             Date(yyyy-mm-dd)    Author              Comments
------------------- ------------------ ------------------------------------------------------------
1            
***************************************************************************************************/

CREATE     PROCEDURE [dbo].[usp_ibmi_service_exceptions_la_silver]
AS

SET NOCOUNT ON

DELETE FROM silver.ibmi_service_exceptions_la

INSERT INTO silver.ibmi_service_exceptions_la
SELECT 
		TRIM(a.LAORD)													AS serv_exc_la_load_number
      , CONVERT(INT,a.LASEQ)															AS serv_exc_la_sequence_number
      ,	CONVERT(INT,a.LASTP)															AS serv_exc_la_stop_number
      , LAADT2.date_key_pk												AS serv_exc_la_late_appt_date
	  , CASE 
			WHEN CONVERT(INT,TRIM(a.LAATM2)) <= 2359 
				AND CONVERT(INT,LEFT(a.LAATM2,2)) < 60
				AND LEN(TRIM(a.LAATM2)) = 4 
			THEN TIMEFROMPARTS(LEFT(a.LAATM2,2),RIGHT(a.LAATM2,2),0,0,0)
			ELSE NULL END												AS serv_exc_la_late_appt_time
      , LAARDT.date_key_pk												AS serv_exc_la_arrival_date
	  , CASE 
			WHEN CONVERT(INT,TRIM(a.LAARTM)) <= 2359 
				AND CONVERT(INT,LEFT(a.LAARTM,2)) < 60
				AND LEN(TRIM(a.LAARTM)) = 4 
			THEN TIMEFROMPARTS(LEFT(a.LAARTM,2),RIGHT(a.LAARTM,2),0,0,0)
			ELSE NULL END												AS serv_exc_la_arrival_time
--INTO data_central_wh.silver.ibmi_service_exceptions_la
FROM data_central_lh.dbo.ibmi_service_exceptions_la_bronze a
LEFT JOIN data_central_wh.gold.dim_date LAADT2 ON a.LAADT2 = LAADT2.date_ordinal
LEFT JOIN data_central_wh.gold.dim_date LAARDT ON a.LAARDT = LAARDT.date_ordinal