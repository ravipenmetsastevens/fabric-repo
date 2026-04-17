-- Auto Generated (Do not modify) F307B1AB209674AE9A3AEFC6FB565D73CC683A2B324457F4C245695DD23E43EB





-- ===============================================================
-- Create View template for Azure Synapse SQL Analytics on-demand
-- ===============================================================


CREATE VIEW [silver].[vw_ibmi_unload_billing_export] AS

SELECT a.order_load_number								AS load_number
, a.order_division_code									AS division
, a.order_early_pickup_date								AS pickup_date
, a.cust_name											AS billto_name
, b.billing_commodity_code								AS rate_type
, a.order_miles_billable								AS order_miles
, f.miles_paid											AS paid_miles
, b.billed_miles										AS billed_miles
, c.billed_amount										AS revenue_amt
, c.last_date_billed									AS latest_billed_date
, d.total_unloading_billed								AS unloading_billed_amt
, h.driver_amount										AS amount_to_driver
, h.early_check_date									AS earliest_check_date
, h.late_check_date										AS latest_check_date
, e.amount_collected									AS collected_amount
, e.early_collected_date								AS earliest_collected_date
, e.late_collected_date									AS latest_collected_date	
, g.team_flag
FROM (((((([silver].[vw_ibmi_unloading_order_list] a
LEFT OUTER JOIN [silver].[vw_ibmi_billing_rate_type_miles] b ON b.billing_load_number = a.order_load_number)
LEFT OUTER JOIN [silver].[vw_ibmi_gross_revenue_all] c ON c.load_number = a.order_load_number)
LEFT OUTER JOIN [silver].[vw_ibmi_billing_unloading] d ON d.billing_load_number = a.order_load_number)
LEFT OUTER JOIN [silver].[vw_ibmi_arfile_collections] e ON e.load_number = a.order_load_number)
LEFT OUTER JOIN [silver].[vw_ibmi_paid_miles_all] f ON f.load_number = a.order_load_number)
LEFT OUTER JOIN [silver].[vw_ibmi_team_loads] g ON g.load_load_number = a.order_load_number)
LEFT OUTER JOIN [silver].[vw_ibmi_unload_to_driver] h ON h.load_number = a.order_load_number