-- Auto Generated (Do not modify) 71F675ACC6D19C109D7F4822A9279BA888C1156F5F2F8504661B84FD35A2C465






CREATE VIEW [silver].[vw_pilot_dhr_total_revenue]
AS

SELECT 
	  b.order_load_number
	, CASE WHEN a.total_revenue_amount IS NULL
		THEN b.order_revenue_estimation
		ELSE a.total_revenue_amount END							AS revenue_amount
FROM 
	(
	SELECT 
		  billing_load_number
		, SUM(billing_billed_amount) AS total_revenue_amount
	FROM 
		gold.vw_fact_incr_billing_all
	WHERE
		is_deleted = 0
	GROUP BY
		billing_load_number
	) a
	RIGHT OUTER JOIN 
		silver.vw_ibmi_incr_order_all b ON a.billing_load_number = b.order_load_number