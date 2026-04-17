-- Auto Generated (Do not modify) 987BD4CF3A62FB4C634D23AB3EBF74BFC1A0C5840F0C6390F9879BF45158E63F
CREATE VIEW [silver].[vw_pilot_dhr_revenue_adjusted]
AS
SELECT 
	  a.order_load_number
	, CASE WHEN b.mex_det_amount IS NULL 
		THEN revenue_amount 
		ELSE (revenue_amount - mex_det_amount) END							AS adjusted_revenue_amount
FROM   [silver].[vw_pilot_dhr_total_revenue] a 
LEFT OUTER JOIN [silver].[vw_pilot_dhr_billing_mex_det] b ON a.order_load_number = b.billing_load_number