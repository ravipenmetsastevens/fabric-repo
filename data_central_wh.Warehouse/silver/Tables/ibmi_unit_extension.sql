CREATE TABLE [silver].[ibmi_unit_extension] (

	[unit_extn_truck_number] varchar(8000) NULL, 
	[unit_extn_mobile_serial_number] varchar(8000) NULL, 
	[is_automatic_trans] varchar(7) NOT NULL, 
	[unit_extn_truck_category] varchar(7) NOT NULL, 
	[unit_extn_carb_reg_code] varchar(8) NULL, 
	[unit_extn_business_unit_code] varchar(16) NULL, 
	[has_digital_mirrors] varchar(7) NOT NULL
);