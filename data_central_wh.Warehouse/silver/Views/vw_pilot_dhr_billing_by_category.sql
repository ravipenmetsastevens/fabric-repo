-- Auto Generated (Do not modify) 43491DCC9CC50A1A928B10B85514021BF71A0A392ABAE60511387FF77F2FF1B5





CREATE VIEW [silver].[vw_pilot_dhr_billing_by_category]
AS
SELECT a.billing_load_number
	,  b.billing_category
	,  SUM(a.billing_billed_amount) AS billed_amount
FROM  gold.vw_fact_incr_billing_all a
	INNER JOIN
             gold.dim_billing_categories b ON a.billing_commodity_code = b.type_code 
			 INNER JOIN [silver].[vw_ibmi_incr_order_all] c ON a.billing_load_number = c.order_load_number
WHERE (a.is_deleted = 0)
GROUP BY a.billing_load_number, b.billing_category