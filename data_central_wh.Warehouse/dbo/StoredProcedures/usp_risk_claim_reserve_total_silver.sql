/***************************************************************************************************
Procedure:          dbo.usp_risk_claim_reserve_total_silver
Create Date:        2025-08-28
Author:             Jeremy Shahan
Description:        Truncate and load of Claim Reserve Total Silver
Called by:            Azure Data Factory
					Pipeline: risk_claim_reserve_total
Affected table(s):  silver.risk_claim_reserve_total
Usage:              EXEC dbo.usp_risk_claim_reserve_total_silver

****************************************************************************************************
SUMMARY OF CHANGES
#             Date(yyyy-mm-dd)    Author              Comments
------------------- ------------------ ------------------------------------------------------------
1            
***************************************************************************************************/

CREATE   PROCEDURE dbo.usp_risk_claim_reserve_total_silver
AS

SET NOCOUNT ON

TRUNCATE TABLE silver.risk_claim_reserve_total

INSERT INTO silver.risk_claim_reserve_total

SELECT
		a.CLAIMMASTERRECORDID								AS reserve_ttl_claim_record_code
      --, a.FUNDCODE
      , a.RESERVETOTAL										AS reserve_ttl_reserve_total_amount
      , a.PAIDLOSSTOTAL										AS reserve_ttl_paid_loss_total_amount
      , a.PAIDEXPENSETOTAL									AS reserve_ttl_paid_expense_total_amount
      , a.RECOVEREDTOTAL									AS reserve_ttl_recovered_total_amount
      , a.CREATEDATE										AS reserve_ttl_create_datetime
      , TRIM(a.CREATEUSER)									AS reserve_ttl_create_user_code			
      , a.CHANGEDATE										AS reserve_ttl_last_change_datetime
      , TRIM(a.CHANGEUSER)									AS reserve_ttl_last_change_user_code
--INTO data_central_wh.silver.risk_claim_reserve_total
FROM data_central_lh.dbo.risk_claim_reserve_total_bronze a