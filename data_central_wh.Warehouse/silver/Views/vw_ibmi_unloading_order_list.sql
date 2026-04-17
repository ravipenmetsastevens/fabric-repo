-- Auto Generated (Do not modify) 88AA8CF76569C594E2A9531DFD7E4374A13B8FB2B94C1F3CB7687C3CA396E09B



-- ===============================================================
-- Create View template for Azure Synapse SQL Analytics on-demand
-- ===============================================================

CREATE VIEW [silver].[vw_ibmi_unloading_order_list] AS

SELECT 
	  order_load_number
	, order_division_code
	, order_early_pickup_date
	, cust_name
	, order_miles_billable
FROM (silver.ibmi_order a INNER JOIN 
(
SELECT DISTINCT billing_load_number 
FROM [gold].[fact_billing_all]
WHERE billing_commodity_code IN ('ULC','LAB','UND','UNL','L5')
) b
ON b.billing_load_number = a.order_load_number) LEFT OUTER JOIN
gold.dim_customer ON order_billto_code = customer_code
WHERE order_early_pickup_date BETWEEN '2024-01-01' and '2024-07-31'