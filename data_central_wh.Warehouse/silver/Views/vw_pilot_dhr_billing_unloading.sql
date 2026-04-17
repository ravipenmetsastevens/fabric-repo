-- Auto Generated (Do not modify) 1D87F72631B4261CBA79100DFA5AD864D0991E6634BB093F80B07858444BDC7B







CREATE VIEW [silver].[vw_pilot_dhr_billing_unloading]
AS
SELECT   
	  a.billing_load_number
	, SUM(a.billing_billed_amount)				AS unloading_amount
FROM  [gold].[vw_fact_incr_billing_all] a
INNER JOIN [gold].[dim_billing_categories] b ON a.billing_commodity_code = b.type_code 
INNER JOIN [silver].[vw_ibmi_incr_order_all] c ON a.billing_load_number = c.order_load_number
WHERE     (a.is_deleted = 0) AND (b.billing_category = 'Unloading')
GROUP BY a.billing_load_number