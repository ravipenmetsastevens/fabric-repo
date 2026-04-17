CREATE TABLE [silver].[RecordCount_log] (

	[run_id] uniqueidentifier NOT NULL, 
	[object_schema] varchar(128) NOT NULL, 
	[object_name] varchar(128) NOT NULL, 
	[run_datetime_utc] datetime2(3) NOT NULL, 
	[record_count] bigint NULL, 
	[is_zero_count] bit NOT NULL, 
	[duration_ms] int NOT NULL, 
	[status] varchar(10) NOT NULL, 
	[error_message] varchar(4000) NULL, 
	[database_name] varchar(128) NULL
);