-- Auto Generated (Do not modify) B9B43FD594A0BA781B09F1808679B397184C0B4B1FFA6C69B09B4E733E61D28A







CREATE VIEW [silver].[vw_pilot_dhr_billing_fsc]
AS
SELECT 
	  a.billing_load_number
	, SUM(a.billing_billed_amount) AS fsc_amount
FROM [gold].[vw_fact_incr_billing_all] a 
INNER JOIN [gold].[dim_billing_categories] b ON a.billing_commodity_code = b.type_code
INNER JOIN [silver].[vw_ibmi_incr_order_all] c ON a.billing_load_number = c.order_load_number
WHERE (a.is_deleted = 0) 
AND (b.billing_category = 'Fuel Surcharge')
GROUP BY a.billing_load_number