CREATE TABLE [gold].[fact_thermoking_reefer_zones] (

	[vehicleName] varchar(8000) NULL, 
	[dataDate] date NULL, 
	[dataTime] time(0) NULL, 
	[isZone1Active] bit NULL, 
	[isZone1Configured] bit NULL, 
	[isZone1DoorOpen] bit NULL, 
	[isZone2Active] bit NULL, 
	[isZone2Configured] bit NULL, 
	[isZone2DoorOpen] bit NULL, 
	[isZone3Active] bit NULL, 
	[isZone3Configured] bit NULL, 
	[isZone3DoorOpen] bit NULL
);