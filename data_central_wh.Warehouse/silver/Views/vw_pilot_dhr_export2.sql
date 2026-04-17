-- Auto Generated (Do not modify) 8639C427863DFB7B8501559C0CAFAE0C0F81E59103073B7065D5A9CF59B6EA49









CREATE VIEW [silver].[vw_pilot_dhr_export2]
AS 
SELECT
	  o.order_load_number
	, o.order_customer_code
	, o.order_billto_code
	, o.order_loadat_code
	, o.order_early_pickup_date
	, o.order_pallet_count
	, c1.city_name						AS origin_city
	, o.order_origin_state
	, c2.city_name						AS destination_city
	, o.order_destination_state
	, c3.city_name						AS deadhead_city
	, dh.load_dead_head_origin_state
	, dh.load_miles_dead_head
	, r.adjusted_revenue_amount
	, u.unloading_amount
	, f.adjusted_fsc_amount
	, o.order_miles_billable
	, o.order_temp_low
	, o.order_division_code
	, o.order_destination_area_code
	, s.state_name
	, s.state_area
	, m.region_name
	, o.bill_to_name
	, o.cust_name
	, o.load_at_name
FROM silver.vw_pilot_dhr_order_all o 
	LEFT OUTER JOIN silver.ibmi_city_master c1 
		ON o.order_origin_city_code = c1.city_short_code 
		AND o.order_origin_state = c1.city_state
	LEFT OUTER JOIN silver.ibmi_city_master c2
		ON o.order_destination_city_code = c2.city_short_code 
		AND o.order_destination_state = c2.city_state
	LEFT OUTER JOIN silver.vw_pilot_dhr_load_dh_origin dh
		ON o.order_load_number = dh.load_load_number
	LEFT OUTER JOIN silver.ibmi_city_master c3
		ON dh.load_dead_head_origin_city_code = c3.city_short_code 
		AND dh.load_dead_head_origin_state = c3.city_state
	LEFT OUTER JOIN silver.vw_pilot_dhr_revenue_adjusted r
		ON o.order_load_number = r.order_load_number
	LEFT OUTER JOIN silver.vw_pilot_dhr_billing_fsc_adjusted f
		ON o.order_load_number = f.order_load_number
	LEFT OUTER JOIN silver.vw_pilot_dhr_billing_unloading u
		ON o.order_load_number = u.billing_load_number
	LEFT OUTER JOIN gold.dim_state s
		ON o.order_destination_state = s.state_state_code
	LEFT OUTER JOIN silver.ibmi_region_master m
		ON o.order_destination_region_code = m.region_code