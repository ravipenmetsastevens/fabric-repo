/***************************************************************************************************
Procedure:          dbo.usp_risk_accident_type_master_silver
Create Date:        2025-09-05
Author:             Jeremy Shahan
Description:        Truncate and load of Accident Type Master Silver
Called by:            Azure Data Factory
					Pipeline: risk_accident_type_master
Affected table(s):  silver.risk_accident_type_master
Usage:              EXEC dbo.usp_risk_accident_type_master_silver

****************************************************************************************************
SUMMARY OF CHANGES
#             Date(yyyy-mm-dd)    Author              Comments
------------------- ------------------ ------------------------------------------------------------
1            
***************************************************************************************************/

CREATE       PROCEDURE [dbo].[usp_risk_accident_type_master_silver]
AS

SET NOCOUNT ON

TRUNCATE TABLE silver.risk_accident_type_master

INSERT INTO silver.risk_accident_type_master
SELECT
		a.ACCIDENTTYPECODE								AS accident_type_code
      , a.ACCIDENTTYPEDESC								AS accident_type_description
      , a.CREATEDATE									AS accident_type_create_datetime
      , TRIM(a.CREATEUSER)								AS accident_type_create_user_code
      , a.CHANGEDATE									AS accident_type_last_changed_datetime
      , TRIM(a.CHANGEUSER)								AS accident_type_last_changed_user_code
      --, a.POINTS
      , TRIM(a.LONGDESC)								AS accident_type_category
      --, a.ACTSTS
      --, a.IPOINTS
      , CASE TRIM(a.ONROAD)
			WHEN 'Y' THEN 'TRUE'
			WHEN 'N' THEN 'FALSE'
			ELSE 'unknown'	END							AS is_on_road
      , TRIM(a.SAFETYACCDTYPE)							AS accident_type_safety_type_code
--INTO data_central_wh.silver.risk_accident_type_master
FROM data_central_lh.dbo.risk_accident_type_master_bronze a