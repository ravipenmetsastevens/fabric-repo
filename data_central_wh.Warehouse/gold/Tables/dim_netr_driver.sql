CREATE TABLE [gold].[dim_netr_driver] (

	[driver_id] varchar(8000) NULL, 
	[driver_firstname] varchar(8000) NULL, 
	[driver_lastname] varchar(8000) NULL, 
	[driver_status_descr] varchar(8000) NULL, 
	[driver_username] varchar(8000) NULL, 
	[driver_email] varchar(8000) NULL, 
	[driver_licence_number] varchar(8000) NULL, 
	[driver_licence_state] varchar(8000) NULL, 
	[driver_licence_country] varchar(8000) NULL, 
	[driver_group_name] varchar(8000) NULL, 
	[driver_group_unique_name] varchar(8000) NULL, 
	[driver_create_date] date NULL, 
	[driver_create_time] time(0) NULL, 
	[driver_update_date] date NULL, 
	[driver_update_time] time(0) NULL
);