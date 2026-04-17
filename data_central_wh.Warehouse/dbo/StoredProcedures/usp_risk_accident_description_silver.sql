/***************************************************************************************************
Procedure:          dbo.usp_risk_accident_description_silver
Create Date:        2025-08-29
Author:             Jeremy Shahan
Description:        Truncate and load of Accident Description Silver
Called by:            Azure Data Factory
					Pipeline: risk_accident_description
Affected table(s):  silver.risk_accident_description
Usage:              EXEC dbo.usp_risk_accident_description_silver

****************************************************************************************************
SUMMARY OF CHANGES
#             Date(yyyy-mm-dd)    Author              Comments
------------------- ------------------ ------------------------------------------------------------
1            
***************************************************************************************************/

CREATE   PROCEDURE [dbo].[usp_risk_accident_description_silver]
AS

SET NOCOUNT ON

TRUNCATE TABLE silver.risk_accident_description

INSERT INTO silver.risk_accident_description

SELECT
		a.CLAIMMASTERRECORDID							AS accident_desc_claim_record_code
      , TRIM(a.ACCIDENTDESCR)							AS accident_desc_description
      , a.CREATEDATE									AS accident_desc_create_datetime
      , TRIM(a.CREATEUSER)								AS accident_desc_create_user_code
      , a.CHANGEDATE									AS accident_desc_last_change_datetime
      , TRIM(a.CHANGEUSER)								AS accident_desc_last_change_user_code
--INTO data_central_wh.silver.risk_accident_description
FROM data_central_lh.dbo.risk_accident_description_bronze a