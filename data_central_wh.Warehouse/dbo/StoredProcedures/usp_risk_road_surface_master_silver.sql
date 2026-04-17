/***************************************************************************************************
Procedure:          dbo.usp_risk_road_surface_master_silver
Create Date:        2025-09-05
Author:             Jeremy Shahan
Description:        Truncate and load of Road Surface Master Silver
Called by:            Azure Data Factory
					Pipeline: risk_road_surface_master
Affected table(s):  silver.risk_road_surface_master
Usage:              EXEC dbo.usp_risk_road_surface_master_silver

****************************************************************************************************
SUMMARY OF CHANGES
#             Date(yyyy-mm-dd)    Author              Comments
------------------- ------------------ ------------------------------------------------------------
1            
***************************************************************************************************/

CREATE       PROCEDURE [dbo].[usp_risk_road_surface_master_silver]
AS

SET NOCOUNT ON

TRUNCATE TABLE silver.risk_road_surface_master

INSERT INTO silver.risk_road_surface_master
SELECT
		a.ROADSURFACETYPECODE										AS road_surf_mast_code
      , TRIM(a.ROADSURFACEDESCRIPTION)								AS road_surf_mast_description
      , a.CREATEDATE												AS road_surf_mast_create_datetime
      , TRIM(a.CREATEUSER)											AS road_surf_mast_create_user_code
      , a.CHANGEDATE												AS road_surf_mast_last_changed_datetime
      , TRIM(a.CHANGEUSER)											AS road_surf_mast_last_changed_user_code
      , CASE TRIM(a.ACTSTS)
			WHEN 'Y' THEN 'TRUE'
			WHEN 'N' THEN 'FALSE'
			ELSE 'unknown'	END										AS has_act_status
      , a.SAFETYCODE												AS road_surf_mast_safety_code
--INTO data_central_wh.silver.risk_road_surface_master
FROM data_central_lh.dbo.risk_road_surface_master_bronze a