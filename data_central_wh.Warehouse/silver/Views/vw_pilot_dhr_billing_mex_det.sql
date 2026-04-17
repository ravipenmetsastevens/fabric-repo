-- Auto Generated (Do not modify) EAE241D109379ABD235BD7C3AE7D3F8B7276E580F74951622633AF6B0BA75D1B







CREATE VIEW [silver].[vw_pilot_dhr_billing_mex_det]
AS
SELECT 
	  a.billing_load_number
	, SUM(a.billing_billed_amount) AS mex_det_amount
FROM   [gold].[vw_fact_incr_billing_all] a
INNER JOIN [gold].[dim_billing_categories] b ON a.billing_commodity_code = b.type_code 
INNER JOIN [silver].[vw_ibmi_incr_order_all] c ON a.billing_load_number = c.order_load_number
WHERE (a.is_deleted = 0) AND (b.billing_category IN ('Detention', 'Mexico Charge'))
GROUP BY a.billing_load_number