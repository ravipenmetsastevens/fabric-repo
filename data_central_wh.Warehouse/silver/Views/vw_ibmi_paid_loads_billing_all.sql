-- Auto Generated (Do not modify) 5158348C5C681E23F1721D1AD172A8F89CA4949B0A1E3270990D0522CCDFE46B
CREATE VIEW [silver].[vw_ibmi_paid_loads_billing_all]
AS
SELECT       
	  a.billing_load_number						AS load_number
	, a.billing_commodity_code					AS commodity_code
	, a.billing_commodity_description			AS commodity_description
	, a.billing_billed_amount					AS billed_amount
FROM silver.ibmi_billing a 
INNER JOIN [silver].[vw_ibmi_paid_loads_last_7_days_validated] b ON a.billing_load_number = b.earnings_history_load_number
WHERE        (a.is_deleted = 'FALSE') AND a.billing_billed_amount <> 0

UNION ALL

SELECT        
	  a.cd_billing_load_number					AS load_number
	, a.cd_billing_commodity_code				AS commodity_code
	, a.cd_billing_commodity_description		AS commodity_description
	, a.cd_billing_billed_amount				AS billed_amount
FROM silver.ibmi_cd_billing a
INNER JOIN [silver].[vw_ibmi_paid_loads_last_7_days_validated] b ON a.cd_billing_load_number = b.earnings_history_load_number
WHERE        (a.is_deleted = 'FALSE') AND a.cd_billing_billed_amount <> 0