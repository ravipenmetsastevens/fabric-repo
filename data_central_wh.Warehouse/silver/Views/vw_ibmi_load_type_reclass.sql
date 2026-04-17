-- Auto Generated (Do not modify) 080E296ECA369503B26F30992823C2150A8FF07B0937D33E504875634A24C12E



CREATE VIEW [silver].[vw_ibmi_load_type_reclass]
AS
SELECT 
	  b.order_load_number
	, b.order_status_code
	, b.order_customer_code
	, b.order_consignee_code
	, b.order_billto_code
	, b.order_loadat_code
	, b.order_early_pickup_date
	, b.order_early_pickup_time
	, b.order_pallet_count
	, b.order_origin_city_code
	, b.order_origin_state
	, b.order_origin_city_short_name
	, b.order_destination_city_code
	, b.order_destination_state
	, b.order_destination_city_short_name
	, b.order_miles_billable
	, b.order_revenue_estimation
	, b.order_late_delivery_date
	, b.order_late_delivery_time
	, b.order_required_pallet_count
	, b.order_temp_high
	, b.order_temp_low
	, b.order_ship_date
	, b.order_ship_time
	, b.order_division_code
	, b.order_load_type
	, iif(a.comments_intermodal_load_number IS NOT NULL, 'I', iif(b.order_load_type IN ('D', 'R'), b.order_load_type, iif(b.order_load_type NOT IN ('D', 'R') AND 
             b.order_temp_low >= 998, 'D', 'R'))) AS true_load_type
FROM   silver.ibmi_comments_intermodal a
RIGHT OUTER JOIN [silver].[vw_ibmi_incr_order_all] b ON a.comments_intermodal_load_number = b.order_load_number