CREATE TABLE [silver].[plsc_asset_master] (

	[asset_id] bigint NOT NULL, 
	[unit_number] varchar(200) NULL, 
	[vin] varchar(50) NULL, 
	[license_plate] varchar(100) NULL, 
	[plate_state] varchar(20) NULL, 
	[terminal] varchar(100) NULL, 
	[make] varchar(100) NULL, 
	[model] varchar(150) NULL, 
	[telematics_guid] varchar(256) NULL
);