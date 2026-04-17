-- Auto Generated (Do not modify) CAF8E19CB99009C3FA8F5912E5506E536D6A4B269BEE3F82456351FFEF0945FC

CREATE   VIEW [silver].[vw_ibmi_active_trucks_business_unit] AS

SELECT 
	  u1.unit_truck_number
	, u1.unit_seat_1_driver_code
	, u1.unit_seat_2_driver_code
	, b1.business_unit_class
	, b1.business_unit_description
FROM 
	data_central_wh.silver.ibmi_unit u1
		LEFT OUTER JOIN data_central_wh.silver.ibmi_unit_extension u2
			ON u1.unit_truck_number = u2.unit_extn_truck_number
		LEFT OUTER JOIN data_central_wh.silver.ibmi_business_unit_master b1
			ON u2.unit_extn_business_unit_code = b1.business_unit_code
WHERE u1.is_truck_deleted = 'FALSE'
;