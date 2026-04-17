CREATE TABLE [gold].[fact_thermoking_alarm] (

	[vehicleName] varchar(8000) NULL, 
	[dataDate] date NULL, 
	[dataTime] time(0) NULL, 
	[alarmCode] bigint NULL, 
	[alarmDescription] varchar(8000) NULL, 
	[alarmSeverity] varchar(8000) NULL, 
	[alarmRecommendation] varchar(8000) NULL, 
	[alarmZone] bigint NULL
);