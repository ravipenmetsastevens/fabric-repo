/***************************************************************************************************
Procedure:          dbo.usp_ibmi_stopoff_og_appt_silver
Create Date:        2025-12-18
Author:             Jeremy Shahan
Description:        Truncate and load of Stopoff with Original Appointments to Silver
Called by:          Fabric
					Pipeline: ibmi_stopoff_og_appt
Affected table(s):  silver.ibmi_stopoff_og_appt
Usage:              EXEC dbo.usp_ibmi_stopoff_og_appt_silver

****************************************************************************************************
SUMMARY OF CHANGES
#             Date(yyyy-mm-dd)    Author              Comments
------------------- ------------------ ------------------------------------------------------------
1            
***************************************************************************************************/

CREATE   PROCEDURE [dbo].[usp_ibmi_stopoff_og_appt_silver]
AS

SET NOCOUNT ON

DELETE FROM silver.ibmi_stopoff_og_appt

INSERT INTO silver.ibmi_stopoff_og_appt
SELECT 
	    TRIM(a.S2ORD)																	AS stopoff_og_load_number
      , a.S2STP																			AS stopoff_og_stop_number
      , S2ADT1.date_key_pk																AS stopoff_og_appt_early_date
      , S2ADT2.date_key_pk																AS stopoff_og_appt_late_date
	  , CASE 
			WHEN CONVERT(INT, a.S2ATM1) <= 2359 
				AND LEN(TRIM(a.S2ATM1)) = 4 
				AND CONVERT(INT,RIGHT(TRIM(a.S2ATM1),2)) < 60
			THEN CONVERT(TIME(0),CONCAT(LEFT(a.S2ATM1,2),':',RIGHT(a.S2ATM1,2)))
			ELSE NULL END																AS stopoff_og_appt_early_time
	  , CASE 
			WHEN CONVERT(INT, a.S2ATM2) <= 2359 
				AND LEN(TRIM(a.S2ATM2)) = 4 
				AND CONVERT(INT,RIGHT(TRIM(a.S2ATM2),2)) < 60
			THEN CONVERT(TIME(0),CONCAT(LEFT(a.S2ATM2,2),':',RIGHT(a.S2ATM2,2)))
			ELSE NULL END																AS stopoff_og_appt_late_time
--INTO data_central_wh.silver.ibmi_stopoff_og_appt
FROM data_central_lh.dbo.ibmi_stopoff_og_appt_bronze a
LEFT JOIN data_central_wh.gold.dim_date S2ADT1 ON a.S2ADT1 = S2ADT1.date_ordinal
LEFT JOIN data_central_wh.gold.dim_date S2ADT2 ON a.S2ADT2 = S2ADT2.date_ordinal