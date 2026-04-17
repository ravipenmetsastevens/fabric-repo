-- Auto Generated (Do not modify) 02872071FEABC3AF7F92F29539660CBB350125ED67E299C1A384D56F3A2C7426









-- ===============================================================
-- Create View template for Azure Synapse SQL Analytics on-demand
-- ===============================================================


CREATE VIEW [silver].[vw_pilot_dhr_order_all] AS

SELECT
  order_load_number
, order_status_code
, order_customer_code
, order_consignee_code
, order_billto_code
, order_loadat_code	
, order_early_pickup_date
, order_pallet_count	
, CASE 
	WHEN order_origin_state IN ('NL','JA')
	THEN 'LARE'
	ELSE order_origin_city_code END					AS order_origin_city_code
, CASE
	WHEN order_origin_state IN ('NL','JA')
	THEN 'TX'
	ELSE order_origin_state END						AS order_origin_state
, CASE
	WHEN order_destination_state IN ('NL','JA')
	THEN 'LARE'
	ELSE order_destination_city_code END			AS order_destination_city_code
, CASE
	WHEN order_destination_state IN ('NL','JA')
	THEN 'TX'
	ELSE order_destination_state END				AS order_destination_state
, order_miles_billable
, order_revenue_estimation
, order_ship_date	
, order_temp_high	
, order_temp_low	
, order_division_code
, order_destination_area_code
, order_destination_region_code	
, b.cust_name										AS bill_to_name
, c.cust_name										AS cust_name
, d.cust_name										AS load_at_name
FROM	
		[silver].[vw_ibmi_incr_order_all] a 
LEFT OUTER JOIN 
		[gold].[dim_customer] b 
			ON a.order_billto_code = b.customer_code
LEFT OUTER JOIN 
		[gold].dim_customer c 
			ON a.order_customer_code = c.customer_code
LEFT OUTER JOIN 
		[gold].dim_customer d 
			ON a.order_loadat_code = d.customer_code
WHERE 
	order_status_code <> 'C'
	AND order_load_number NOT IN 
	(
		SELECT order_load_number
		FROM   [silver].[vw_ibmi_incr_order_all]
		WHERE order_consignee_code = order_loadat_code 
			AND order_miles_billable <= 1
	)