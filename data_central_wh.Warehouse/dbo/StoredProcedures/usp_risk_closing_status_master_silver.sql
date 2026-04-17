/***************************************************************************************************
Procedure:          dbo.usp_risk_closing_status_master_silver
Create Date:        2025-09-05
Author:             Jeremy Shahan
Description:        Truncate and load of Closing Status Master Silver
Called by:            Azure Data Factory
					Pipeline: risk_closing_status_master
Affected table(s):  silver.risk_closing_status_master
Usage:              EXEC dbo.usp_risk_closing_status_master_silver

****************************************************************************************************
SUMMARY OF CHANGES
#             Date(yyyy-mm-dd)    Author              Comments
------------------- ------------------ ------------------------------------------------------------
1            
***************************************************************************************************/

CREATE       PROCEDURE [dbo].[usp_risk_closing_status_master_silver]
AS

SET NOCOUNT ON

TRUNCATE TABLE silver.risk_closing_status_master

INSERT INTO silver.risk_closing_status_master
SELECT
		a.CLOSINGSTATUSRECORDID										AS closing_stat_mast_code
      , TRIM(a.STATUSDESCRIPTION)									AS closing_stat_mast_description
      , a.CREATEDATE												AS closing_stat_mast_create_datetime
      , TRIM(a.CREATEUSER)											AS closing_stat_mast_create_user_code
      , a.CHANGEDATE												AS closing_stat_mast_last_changed_datetime
      , TRIM(a.CHANGEUSER)											AS closing_stat_mast_last_changed_user_code
      , CASE TRIM(a.ZEROOUTSTANDINGYN)
			WHEN 'Y' THEN 'TRUE'
			WHEN 'N' THEN 'FALSE'
			ELSE 'unknown'	END										AS has_zero_outstanding
      , CASE TRIM(a.CLOSEDIARYYN)
			WHEN 'Y' THEN 'TRUE'
			WHEN 'N' THEN 'FALSE'
			ELSE 'unknown'	END										AS has_close_diary
      , CASE TRIM(a.ZERORECOVERIESYN)
			WHEN 'Y' THEN 'TRUE'
			WHEN 'N' THEN 'FALSE'
			ELSE 'unknown'	END										AS has_zero_recovery
      , TRIM(a.ACTIONCODE)											AS closing_stat_mast_action_code
      --, a.ACTION
      , CASE TRIM(a.CLSADJS)
			WHEN 'Y' THEN 'TRUE'
			WHEN 'N' THEN 'FALSE'
			ELSE 'unknown'	END										AS has_close_adjustments
--INTO data_central_wh.silver.risk_closing_status_master
FROM data_central_lh.dbo.risk_closing_status_master_bronze a