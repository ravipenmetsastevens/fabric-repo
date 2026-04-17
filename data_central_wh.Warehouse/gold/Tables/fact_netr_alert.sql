CREATE TABLE [gold].[fact_netr_alert] (

	[alert_id] bigint NULL, 
	[alert_driver_id] varchar(8000) NULL, 
	[alert_vehicle_vin] varchar(8000) NULL, 
	[alert_device_id] varchar(8000) NULL, 
	[alert_date] date NULL, 
	[alert_time] time(0) NULL, 
	[alert_duration] bigint NULL, 
	[alert_type] varchar(8000) NULL, 
	[alert_sub_type] varchar(8000) NULL, 
	[alert_severity] varchar(8000) NULL, 
	[alert_category] varchar(8000) NULL, 
	[alert_cause] varchar(8000) NULL, 
	[alert_weather] varchar(8000) NOT NULL, 
	[alert_vehicle_status] varchar(8000) NULL, 
	[alert_gps_date] date NULL, 
	[alert_gps_time] time(0) NULL, 
	[alert_gps_latitude] float NULL, 
	[alert_gps_longitude] float NULL, 
	[alert_speed] float NULL, 
	[alert_speed_limit] float NULL, 
	[alert_status] varchar(8000) NULL
);