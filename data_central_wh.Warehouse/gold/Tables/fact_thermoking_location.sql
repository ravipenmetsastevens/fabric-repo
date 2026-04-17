CREATE TABLE [gold].[fact_thermoking_location] (

	[vehicleName] varchar(8000) NULL, 
	[dataDate] date NULL, 
	[dataTime] time(0) NULL, 
	[thermoking_latitude] float NULL, 
	[thermoking_longitude] float NULL, 
	[locationDescription] varchar(8000) NULL, 
	[speed_kmph] bigint NULL, 
	[speed_mph] int NULL, 
	[geoFenceName] varchar(8000) NULL, 
	[geoAccessTypeDescription] varchar(8000) NULL
);