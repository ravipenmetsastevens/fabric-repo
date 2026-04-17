-- Auto Generated (Do not modify) 4039B1A3B6698E9F3C7188917ED1C72B083CD9AD4B6F53AFDEB7A550D9A101F2








CREATE VIEW [silver].[vw_pilot_dhr_load_dh_origin]
AS
SELECT 
	  a.load_load_number
	, CASE WHEN SUBSTRING(a.[load_route_line_codes], 43, 1) <> 'U' 
		THEN SUBSTRING(a.[load_route_line_codes], 1, 4) 
		ELSE 
			CASE WHEN SUBSTRING(a.[load_route_line_codes], 44, 1) <> 'U' 
				THEN SUBSTRING(a.[load_route_line_codes], 7, 4) 
				ELSE 
					CASE WHEN SUBSTRING(a.[load_route_line_codes], 45, 1) <> 'U' THEN SUBSTRING(a.[load_route_line_codes], 13, 4) 
					ELSE 
						CASE WHEN SUBSTRING(a.[load_route_line_codes], 46, 1) <> 'U' THEN SUBSTRING(a.[load_route_line_codes], 19, 4)
						ELSE 
							CASE WHEN SUBSTRING(a.[load_route_line_codes], 47, 1) <> 'U' THEN SUBSTRING(a.[load_route_line_codes], 25, 4) 
							ELSE 
								CASE WHEN SUBSTRING(a.[load_route_line_codes], 48, 1) <> 'U' THEN SUBSTRING(a.[load_route_line_codes], 31, 4) 
								ELSE 
									CASE WHEN SUBSTRING(a.[load_route_line_codes], 49, 1) <> 'U' THEN SUBSTRING(a.[load_route_line_codes], 37, 4) 
									ELSE 
										NULL 
									END 
							END 
					END
				END 
			END 
		END 
	  END																							AS load_dead_head_origin_city_code
	, CASE WHEN SUBSTRING(a.[load_route_line_codes], 43, 1) <> 'U' THEN SUBSTRING(a.[load_route_line_codes], 5, 2) 
		ELSE 
			CASE WHEN SUBSTRING(a.[load_route_line_codes], 44, 1) <> 'U' THEN SUBSTRING(a.[load_route_line_codes], 11, 2) 
			ELSE 
				CASE WHEN SUBSTRING(a.[load_route_line_codes], 45, 1) <> 'U' THEN SUBSTRING(a.[load_route_line_codes], 17, 2) 
				ELSE 
					CASE WHEN SUBSTRING(a.[load_route_line_codes], 46, 1) <> 'U' THEN SUBSTRING(a.[load_route_line_codes], 23, 2) 
					ELSE 
						CASE WHEN SUBSTRING(a.[load_route_line_codes], 47, 1) <> 'U' THEN SUBSTRING(a.[load_route_line_codes], 29, 2) 
						ELSE 
							CASE WHEN SUBSTRING(a.[load_route_line_codes], 48, 1) <> 'U' THEN SUBSTRING(a.[load_route_line_codes], 35, 2) 
							ELSE 
								CASE WHEN SUBSTRING(a.[load_route_line_codes], 49, 1) <> 'U' THEN SUBSTRING(a.[load_route_line_codes], 41, 2) 
								ELSE 
									NULL 
								END 
							END 
						END
					END
				END
			END 
		 END																							AS load_dead_head_origin_state
	, a.load_miles_dead_head
FROM   
(
SELECT a.load_load_number,
a.load_dispatch,
a.load_route_line_codes,
a.load_miles_dead_head,
a.load_truck_number
FROM
(
SELECT 
a.load_load_number,
a.load_dispatch,
a.load_route_line_codes,
a.load_miles_dead_head,
a.load_truck_number,
ROW_NUMBER() OVER (PARTITION BY load_load_number ORDER BY load_dispatch) as rn
FROM data_central_wh.silver.ibmi_incr_load_new a
INNER JOIN data_central_wh.silver.vw_ibmi_incr_order_all ON order_load_number = load_load_number
WHERE isnumeric(trim(load_truck_number)) = 1
AND a.load_route_line_extension IN ('0','1')
AND order_billto_code = 'MILO2'
) AS a
WHERE rn = 1) as a

UNION

SELECT 
	  a.load_load_number
	, CASE WHEN SUBSTRING(a.[load_route_line_codes], 43, 1) <> 'U' 
		THEN SUBSTRING(a.[load_route_line_codes], 1, 4) 
		ELSE 
			CASE WHEN SUBSTRING(a.[load_route_line_codes], 44, 1) <> 'U' 
				THEN SUBSTRING(a.[load_route_line_codes], 7, 4) 
				ELSE 
					CASE WHEN SUBSTRING(a.[load_route_line_codes], 45, 1) <> 'U' THEN SUBSTRING(a.[load_route_line_codes], 13, 4) 
					ELSE 
						CASE WHEN SUBSTRING(a.[load_route_line_codes], 46, 1) <> 'U' THEN SUBSTRING(a.[load_route_line_codes], 19, 4)
						ELSE 
							CASE WHEN SUBSTRING(a.[load_route_line_codes], 47, 1) <> 'U' THEN SUBSTRING(a.[load_route_line_codes], 25, 4) 
							ELSE 
								CASE WHEN SUBSTRING(a.[load_route_line_codes], 48, 1) <> 'U' THEN SUBSTRING(a.[load_route_line_codes], 31, 4) 
								ELSE 
									CASE WHEN SUBSTRING(a.[load_route_line_codes], 49, 1) <> 'U' THEN SUBSTRING(a.[load_route_line_codes], 37, 4) 
									ELSE 
										NULL 
									END 
							END 
					END
				END 
			END 
		END 
	  END																							AS load_dead_head_origin_city_code
	, CASE WHEN SUBSTRING(a.[load_route_line_codes], 43, 1) <> 'U' THEN SUBSTRING(a.[load_route_line_codes], 5, 2) 
		ELSE 
			CASE WHEN SUBSTRING(a.[load_route_line_codes], 44, 1) <> 'U' THEN SUBSTRING(a.[load_route_line_codes], 11, 2) 
			ELSE 
				CASE WHEN SUBSTRING(a.[load_route_line_codes], 45, 1) <> 'U' THEN SUBSTRING(a.[load_route_line_codes], 17, 2) 
				ELSE 
					CASE WHEN SUBSTRING(a.[load_route_line_codes], 46, 1) <> 'U' THEN SUBSTRING(a.[load_route_line_codes], 23, 2) 
					ELSE 
						CASE WHEN SUBSTRING(a.[load_route_line_codes], 47, 1) <> 'U' THEN SUBSTRING(a.[load_route_line_codes], 29, 2) 
						ELSE 
							CASE WHEN SUBSTRING(a.[load_route_line_codes], 48, 1) <> 'U' THEN SUBSTRING(a.[load_route_line_codes], 35, 2) 
							ELSE 
								CASE WHEN SUBSTRING(a.[load_route_line_codes], 49, 1) <> 'U' THEN SUBSTRING(a.[load_route_line_codes], 41, 2) 
								ELSE 
									NULL 
								END 
							END 
						END
					END
				END
			END 
		 END																							AS load_dead_head_origin_state
	, a.load_miles_dead_head
FROM   silver.ibmi_incr_load_new a 
INNER JOIN [silver].[vw_ibmi_incr_order_all] b ON a.load_load_number = b.order_load_number
WHERE (a.load_dispatch = '01')
AND a.load_route_line_extension IN ('0','1')
AND order_billto_code <> 'MILO2'