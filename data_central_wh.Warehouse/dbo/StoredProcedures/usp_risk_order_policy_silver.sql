/***************************************************************************************************
Procedure:          dbo.usp_risk_order_policy_silver
Create Date:        2025-08-28
Author:             Jeremy Shahan
Description:        Truncate and load of Order Policy Silver
Called by:            Azure Data Factory
					Pipeline: risk_order_policy
Affected table(s):  silver.risk_order_policy
Usage:              EXEC dbo.usp_risk_order_policy_silver

****************************************************************************************************
SUMMARY OF CHANGES
#             Date(yyyy-mm-dd)    Author              Comments
------------------- ------------------ ------------------------------------------------------------
1            
***************************************************************************************************/

CREATE   PROCEDURE dbo.usp_risk_order_policy_silver
AS

SET NOCOUNT ON

TRUNCATE TABLE silver.risk_order_policy

INSERT INTO silver.risk_order_policy
SELECT
		a.ATTACHEDTORECORDID								AS order_policy_claim_record_code
      , a.ORDERPOLICYRECORDID								AS order_policy_record_code
      , a.ORDERNUMBER										AS order_policy_load_number
      , a.DISPATCH											AS order_policy_dispatch
      , a.CREATEDATE										AS order_policy_create_datetime
      , TRIM(a.CREATEUSER)									AS order_policy_create_user_code
      , a.CHANGEDATE										AS order_policy_last_change_datetime
      , TRIM(a.CHANGEUSER)									AS order_policy_last_change_user_code
--INTO data_central_wh.silver.risk_order_policy
FROM data_central_lh.dbo.risk_order_policynumber_bronze a