CREATE TABLE [silver].[netr_driver_report_daily] (

	[driver_id] varchar(8000) NOT NULL, 
	[first_name] varchar(8000) NULL, 
	[last_name] varchar(8000) NULL, 
	[driver_score] float NULL, 
	[minutes_analyzed] bigint NULL, 
	[green_minutes_pct] float NULL, 
	[overspeeding_pct] float NULL, 
	[snapshot_date] date NOT NULL, 
	[loaded_at_utc] datetime2(6) NOT NULL
);