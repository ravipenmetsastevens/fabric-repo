CREATE TABLE [silver].[RecordCount_config] (

	[object_schema] varchar(128) NOT NULL, 
	[object_name] varchar(128) NOT NULL, 
	[object_type] varchar(10) NOT NULL, 
	[is_enabled] bit NOT NULL, 
	[created_utc] datetime2(3) NOT NULL, 
	[database_name] varchar(128) NULL
);