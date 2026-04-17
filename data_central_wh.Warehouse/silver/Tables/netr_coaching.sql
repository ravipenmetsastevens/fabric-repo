CREATE TABLE [silver].[netr_coaching] (

	[coaching_id] bigint NULL, 
	[coaching_create_date] date NULL, 
	[coaching_create_time] time(0) NULL, 
	[coaching_complete_date] date NULL, 
	[coaching_complete_time] time(0) NULL, 
	[coaching_status_id] bigint NULL, 
	[configDescription] varchar(8000) NULL, 
	[coaching_driver_firstname] varchar(8000) NULL, 
	[coaching_driver_lastname] varchar(8000) NULL, 
	[coaching_driver_id] varchar(8000) NULL, 
	[coaching_update_date] date NULL, 
	[coaching_update_time] time(0) NULL, 
	[coaching_type] varchar(8000) NULL
);