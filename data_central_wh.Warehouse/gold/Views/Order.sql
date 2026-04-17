-- Auto Generated (Do not modify) 90917B3F11B2DDF46F016E9AC5AC4FAAC6F20C334DB13870182B22EE4A6A38AB
create view [gold].[Order] as 
SELECT -- removed a lot of columns. Can be modified as requirements evolve
	[order_load_number]
	,case when [order_status_code] = 'E' then 'Empty'
		  when [order_status_code] = 'A' then 'Active'
		  when [order_status_code] = 'D' then 'Dispatched'
		  when [order_status_code] = 'C' then 'Cancelled'
		  else null end as OrderStatus -- values translated to George by Jeremy on 6/9/25
	,[order_date] -- using as date dim join 
	,[order_customer_code] -- joins to Customer dimension
	,[order_creation_initials]
	,[order_origin_city_code]
	,[order_destination_city_code]
	,[order_miles_billable]
	,[order_load_type]
	,[order_revenue_estimation] -- potential use for estimate to actual calculations
	,[order_load_volume]
	,[order_ship_date] -- could potentially be a duplicate on what occurs on Load fact (To be tested)
	,[is_delivery_receipt_signed]
	,[order_delivery_receipt_req]
FROM 
	[silver].[ibmi_incr_order_all] a
where
	[order_date] >= '2024-01-01' --Brittany said 2 years is good for YOY calcs, we can get specific later