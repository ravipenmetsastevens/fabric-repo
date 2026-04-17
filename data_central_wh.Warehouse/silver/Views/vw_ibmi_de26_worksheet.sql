-- Auto Generated (Do not modify) EA3EF1877DBC3FE2A56554E0092613913396F47C8C14A3A5A00980AFB1F970A0




-- ===============================================================
-- Create View template for Azure Synapse SQL Analytics on-demand
-- ===============================================================

CREATE VIEW [silver].[vw_ibmi_de26_worksheet] AS

SELECT 
  rnk1												AS load_count
, rnk2												AS unit_group_count
, order_lane_code									AS lane_code
, order_truck_type_requirement_code					AS scac_code
, order_load_number									AS load_number
, order_division_code								AS order_division
, load_truck_number									AS truck_number
, load_unit_division_code							AS truck_division
, load_truck_dm_code								AS truck_dm_code
, order_load_type_revised							AS protection_class
, order_temp_low									
, order_temp_high									
, order_bill_of_lading								AS bol_number
, order_purchase_order								AS po_number
, order_ship_date
, origin_name
, order_origin_city_short_name						AS origin_city
, order_origin_state								AS origin_state
, CASE WHEN origin_zip_revised IS NULL
	THEN origin_lead_zip
	ELSE origin_zip_revised END						AS dh_origin_zip
, origin_zip
, destination_name
, order_destination_city_short_name					AS destination_city
, order_destination_state							AS destination_state
, destination_zip
, load_miles_dead_head								AS dh_miles
, load_miles_loaded									AS loaded_miles
FROM
(
SELECT
  ROW_NUMBER() OVER(ORDER BY load_truck_number, load_dispatch_date) AS rnk1 
, ROW_NUMBER() OVER(PARTITION BY load_truck_number ORDER BY load_dispatch_date) AS rnk2
, LAG(destination_zip) OVER(PARTITION BY load_truck_number ORDER BY load_dispatch_date) AS origin_zip_revised
, *
FROM
(
SELECT
  o.order_lane_code
, o.order_truck_type_requirement_code
, o.order_load_number
, o.order_division_code
, l.load_truck_number
, l.load_unit_division_code
, l.load_truck_dm_code
, CASE WHEN o.order_load_type = 'D' 
	THEN 'U'
	ELSE o.order_load_type END					AS order_load_type_revised
, o.order_temp_low
, o.order_temp_high
, o.order_bill_of_lading
, o.order_purchase_order
, o.order_ship_date
, c1.cust_name									AS origin_name
, o.order_origin_city_short_name
, o.order_origin_state
, c1.cust_address_zip							AS origin_zip
, c2.cust_name									AS destination_name
, o.order_destination_city_short_name
, o.order_destination_state
, c2.cust_address_zip							AS destination_zip
, x.city_zip									AS origin_lead_zip
, l.load_miles_dead_head
, l.load_miles_loaded
, l.load_dispatch_date
FROM silver.ibmi_order o
LEFT OUTER JOIN 
(
SELECT 
  load_load_number
, load_truck_number
, load_unit_division_code
, load_truck_dm_code
, CASE WHEN SUBSTRING([load_route_line_codes], 43, 1) <> 'U' 
		THEN SUBSTRING([load_route_line_codes], 1, 4) 
		ELSE 
			CASE WHEN SUBSTRING([load_route_line_codes], 44, 1) <> 'U' 
				THEN SUBSTRING([load_route_line_codes], 7, 4) 
				ELSE 
					CASE WHEN SUBSTRING([load_route_line_codes], 45, 1) <> 'U' THEN SUBSTRING([load_route_line_codes], 13, 4) 
					ELSE 
						CASE WHEN SUBSTRING([load_route_line_codes], 46, 1) <> 'U' THEN SUBSTRING([load_route_line_codes], 19, 4)
						ELSE 
							CASE WHEN SUBSTRING([load_route_line_codes], 47, 1) <> 'U' THEN SUBSTRING([load_route_line_codes], 25, 4) 
							ELSE 
								CASE WHEN SUBSTRING([load_route_line_codes], 48, 1) <> 'U' THEN SUBSTRING([load_route_line_codes], 31, 4) 
								ELSE 
									CASE WHEN SUBSTRING([load_route_line_codes], 49, 1) <> 'U' THEN SUBSTRING([load_route_line_codes], 37, 4) 
									ELSE 
										NULL 
									END 
							END 
					END
				END 
			END 
		END 
	  END																							AS load_dead_head_origin_city_code
	, CASE WHEN SUBSTRING([load_route_line_codes], 43, 1) <> 'U' THEN SUBSTRING([load_route_line_codes], 5, 2) 
		ELSE 
			CASE WHEN SUBSTRING([load_route_line_codes], 44, 1) <> 'U' THEN SUBSTRING([load_route_line_codes], 11, 2) 
			ELSE 
				CASE WHEN SUBSTRING([load_route_line_codes], 45, 1) <> 'U' THEN SUBSTRING([load_route_line_codes], 17, 2) 
				ELSE 
					CASE WHEN SUBSTRING([load_route_line_codes], 46, 1) <> 'U' THEN SUBSTRING([load_route_line_codes], 23, 2) 
					ELSE 
						CASE WHEN SUBSTRING([load_route_line_codes], 47, 1) <> 'U' THEN SUBSTRING([load_route_line_codes], 29, 2) 
						ELSE 
							CASE WHEN SUBSTRING([load_route_line_codes], 48, 1) <> 'U' THEN SUBSTRING([load_route_line_codes], 35, 2) 
							ELSE 
								CASE WHEN SUBSTRING([load_route_line_codes], 49, 1) <> 'U' THEN SUBSTRING([load_route_line_codes], 41, 2) 
								ELSE 
									NULL 
								END 
							END 
						END
					END
				END
			END 
		 END																							AS load_dead_head_origin_state
	, load_miles_dead_head
	, load_miles_loaded
	, load_dispatch_date
FROM silver.ibmi_load l
WHERE load_dispatch = '01'
) l
ON l.load_load_number = o.order_load_number
LEFT JOIN gold.dim_customer c1
ON c1.customer_code = o.order_loadat_code
LEFT JOIN gold.dim_customer c2
ON c2.customer_code = o.order_consignee_code
LEFT JOIN gold.dim_city x
ON x.city_short_code = l.load_dead_head_origin_city_code AND x.city_state = l.load_dead_head_origin_state
WHERE order_ship_date BETWEEN '2024-09-01' and '2024-09-07'
AND (order_lane_code LIKE 'KFMW%' OR order_lane_code LIKE 'KFTX%')
AND order_status_code <> 'C'
AND order_division_code = '7'
) x
) xx