CREATE TABLE [silver].[netr_device] (

	[device_id] bigint NULL, 
	[device_product_type] varchar(8000) NULL, 
	[device_vehicle_vin] varchar(8000) NULL, 
	[device_vehicle_number] varchar(8000) NULL, 
	[device_vehicle_status] bigint NULL, 
	[device_vehicle_license_plate_number] varchar(8000) NULL, 
	[device_driver_firstname] varchar(8000) NULL, 
	[device_driver_lastname] varchar(8000) NULL, 
	[device_driver_id] varchar(8000) NULL, 
	[device_updated_date] date NULL, 
	[device_updated_time] time(0) NULL, 
	[device_groupname] varchar(8000) NULL, 
	[device_unique_groupname] varchar(8000) NULL
);