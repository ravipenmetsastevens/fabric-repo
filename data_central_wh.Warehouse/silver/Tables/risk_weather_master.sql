CREATE TABLE [silver].[risk_weather_master] (

	[weather_mast_code] float NULL, 
	[weather_mast_description] varchar(8000) NULL, 
	[weather_mast_create_datetime] datetime2(6) NULL, 
	[weather_mast_create_user_code] varchar(8000) NULL, 
	[weather_mast_last_changed_datetime] datetime2(6) NULL, 
	[weather_mast_last_changed_user_code] varchar(8000) NULL, 
	[weather_mast_safety_code] int NULL
);