CREATE TABLE [gold].[dim_maint_unit] (

	[unit_vin] varchar(8000) NULL, 
	[unit_group] varchar(8000) NULL, 
	[unit_number] varchar(8000) NULL, 
	[unit_custom_id] varchar(8000) NULL, 
	[unit_type] varchar(8000) NULL, 
	[unit_year] bigint NULL, 
	[unit_make] varchar(8000) NULL, 
	[unit_model] varchar(8000) NULL, 
	[unit_manufacturer] varchar(8000) NULL, 
	[unit_odometer_miles] bigint NULL, 
	[unit_engine_hours] bigint NULL, 
	[unit_in_service_date] date NULL, 
	[unit_tag] varchar(8000) NULL, 
	[unit_status] varchar(8000) NULL
);