/***************************************************************************************************
Procedure:          dbo.usp_risk_weather_master_silver
Create Date:        2025-09-05
Author:             Jeremy Shahan
Description:        Truncate and load of Weather Master Silver
Called by:            Azure Data Factory
					Pipeline: risk_weather_master
Affected table(s):  silver.risk_weather_master
Usage:              EXEC dbo.usp_risk_weather_master_silver

****************************************************************************************************
SUMMARY OF CHANGES
#             Date(yyyy-mm-dd)    Author              Comments
------------------- ------------------ ------------------------------------------------------------
1            
***************************************************************************************************/

CREATE       PROCEDURE [dbo].[usp_risk_weather_master_silver]
AS

SET NOCOUNT ON

TRUNCATE TABLE silver.risk_weather_master

INSERT INTO silver.risk_weather_master
SELECT
		a.WEATHERCONDITIONCODE										AS weather_mast_code
      , TRIM(a.WEATHERCONDITIONDESC)								AS weather_mast_description
      , a.CREATEDATE												AS weather_mast_create_datetime
      , TRIM(a.CREATEUSER)											AS weather_mast_create_user_code
      , a.CHANGEDATE												AS weather_mast_last_changed_datetime
      , TRIM(a.CHANGEUSER)											AS weather_mast_last_changed_user_code
      --, a.ACTSTS
      , a.SAFETYCODE												AS weather_mast_safety_code
--INTO data_central_wh.silver.risk_weather_master
FROM data_central_lh.dbo.risk_weather_master_bronze a