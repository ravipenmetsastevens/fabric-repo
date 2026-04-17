CREATE TABLE [gold].[dim_netr_vehicle] (

	[vehicle_vin] varchar(8000) NULL, 
	[vehicle_number] varchar(8000) NULL, 
	[vehicle_device_id] varchar(8000) NOT NULL, 
	[vehicle_licence_plate_number] varchar(8000) NULL, 
	[vehicle_class] varchar(8000) NULL, 
	[vehicle_gvm] varchar(8000) NOT NULL, 
	[vehicle_group] varchar(8000) NOT NULL, 
	[vehicle_battery_disconnect] varchar(8) NULL, 
	[vehicle_reg_date] date NULL, 
	[vehicle_reg_time] time(0) NULL, 
	[vehicle_update_date] date NULL, 
	[vehicle_update_time] time(0) NULL, 
	[vehicle_status] varchar(8) NULL, 
	[vehicle_location_date] date NULL, 
	[vehicle_location_time] time(0) NULL, 
	[vehicle_location_latitude] float NULL, 
	[vehicle_location_longitude] float NULL
);