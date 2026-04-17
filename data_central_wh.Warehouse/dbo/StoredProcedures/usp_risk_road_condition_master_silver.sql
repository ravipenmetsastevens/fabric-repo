/***************************************************************************************************
Procedure:          dbo.usp_risk_road_condition_master_silver
Create Date:        2025-09-05
Author:             Jeremy Shahan
Description:        Truncate and load of Road Condition Master Silver
Called by:            Azure Data Factory
					Pipeline: risk_road_condition_master
Affected table(s):  silver.risk_road_condition_master
Usage:              EXEC dbo.usp_risk_road_condition_master_silver

****************************************************************************************************
SUMMARY OF CHANGES
#             Date(yyyy-mm-dd)    Author              Comments
------------------- ------------------ ------------------------------------------------------------
1            
***************************************************************************************************/

CREATE       PROCEDURE [dbo].[usp_risk_road_condition_master_silver]
AS

SET NOCOUNT ON

TRUNCATE TABLE silver.risk_road_condition_master

INSERT INTO silver.risk_road_condition_master
SELECT
		a.ROADCONDITIONCODE											AS road_cond_mast_code
      , TRIM(a.ROADCONDITIONDESCRIPTION)							AS road_cond_mast_description
      , a.CREATEDATE												AS road_cond_mast_create_datetime
      , TRIM(a.CREATEUSER)											AS road_cond_mast_create_user_code
      , a.CHANGEDATE												AS road_cond_mast_last_changed_datetime
      , TRIM(a.CHANGEUSER)											AS road_cond_mast_last_changed_user_code
      --, a.ACTSTS
      , a.SAFETYCODE												AS road_cond_mast_safety_code
--INTO data_central_wh.silver.risk_road_condition_master
FROM data_central_lh.dbo.risk_road_condition_master_bronze a