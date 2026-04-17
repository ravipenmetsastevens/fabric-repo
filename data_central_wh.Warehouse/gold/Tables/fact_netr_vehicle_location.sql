CREATE TABLE [gold].[fact_netr_vehicle_location] (

	[location_vin] varchar(8000) NULL, 
	[location_vehicle_number] varchar(8000) NULL, 
	[location_date] date NULL, 
	[location_time] time(0) NULL, 
	[location_latitude] float NULL, 
	[location_longitude] float NULL
);