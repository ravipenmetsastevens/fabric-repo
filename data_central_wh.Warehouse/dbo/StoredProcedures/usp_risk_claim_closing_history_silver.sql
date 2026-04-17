/***************************************************************************************************
Procedure:          dbo.usp_risk_claim_closing_history_silver
Create Date:        2025-08-29
Author:             Jeremy Shahan
Description:        Truncate and load of Claim Closing History Silver
Called by:            Azure Data Factory
					Pipeline: risk_claim_closing_history
Affected table(s):  silver.risk_claim_closing_history
Usage:              EXEC dbo.usp_risk_claim_closing_history_silver

****************************************************************************************************
SUMMARY OF CHANGES
#             Date(yyyy-mm-dd)    Author              Comments
------------------- ------------------ ------------------------------------------------------------
1            
***************************************************************************************************/

CREATE   PROCEDURE dbo.usp_risk_claim_closing_history_silver
AS

SET NOCOUNT ON

TRUNCATE TABLE silver.risk_claim_closing_history

INSERT INTO silver.risk_claim_closing_history

SELECT
		a.CLAIMMASTERRECORDID								AS claim_closing_hist_claim_record_code
      , a.CLAIMCLOSINGRECORDID								AS claim_closing_hist_record_code
      , a.CLOSINGSTATUSRECORDID								AS claim_closing_hist_status_code
      , CASE TRIM(a.ZEROOUSTANDING)
			WHEN 'Y' THEN 'TRUE'
			WHEN 'N' THEN 'FALSE'
			ELSE 'unknown'	END								AS has_zero_outstanding
      , CASE TRIM(a.ZERORECOVERIES)
			WHEN 'Y' THEN 'TRUE'
			WHEN 'N' THEN 'FALSE'
			ELSE 'unknown'	END								AS has_zero_recoveries
      , CASE TRIM(a.CLOSEACTIVEDIARY)
			WHEN 'Y' THEN 'TRUE'
			WHEN 'N' THEN 'FALSE'
			ELSE 'unknown'	END								AS has_active_diary
      , a.ARCHIVEDATE										AS claim_closing_hist_archive_date
      , a.DESTRUCTIONDATE									AS claim_closing_hist_destruction_date
      --, a.STORAGELOCATION
      , a.CREATEDATE										AS claim_closing_hist_create_datetime
      , TRIM(a.CREATEUSER)									AS claim_closing_hist_create_user_code
      , a.CHANGEDATE										AS claim_closing_hist_last_change_datetime
      , TRIM(a.CHANGEUSER)									AS claim_closing_hist_last_change_user_code
      --, a.CLSADJS
--INTO data_central_wh.silver.risk_claim_closing_history
FROM data_central_lh.dbo.risk_claim_closing_history_bronze a