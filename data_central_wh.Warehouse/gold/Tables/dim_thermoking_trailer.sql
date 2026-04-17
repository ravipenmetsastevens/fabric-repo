CREATE TABLE [gold].[dim_thermoking_trailer] (

	[vehicleName] varchar(8000) NULL, 
	[reeferSerialNumber] varchar(8000) NULL, 
	[trailer_VIN] varchar(8000) NULL, 
	[truck_VIN] varchar(8000) NULL, 
	[wirelessGen] varchar(8000) NULL, 
	[isDoorLockFitted] bit NULL, 
	[fuelTankSize] bigint NULL
);