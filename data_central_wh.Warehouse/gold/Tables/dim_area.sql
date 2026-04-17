CREATE TABLE [gold].[dim_area] (

	[area_code] varchar(3) NOT NULL, 
	[area_name] varchar(25) NULL, 
	[area_short_name] varchar(10) NULL, 
	[area_zone_code] varchar(2) NULL, 
	[area_region_code] varchar(3) NULL
);


GO
ALTER TABLE [gold].[dim_area] ADD CONSTRAINT PK_area_code primary key NONCLUSTERED ([area_code]);