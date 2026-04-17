CREATE TABLE [silver].[risk_closing_status_master] (

	[closing_stat_mast_code] float NULL, 
	[closing_stat_mast_description] varchar(8000) NULL, 
	[closing_stat_mast_create_datetime] datetime2(6) NULL, 
	[closing_stat_mast_create_user_code] varchar(8000) NULL, 
	[closing_stat_mast_last_changed_datetime] datetime2(6) NULL, 
	[closing_stat_mast_last_changed_user_code] varchar(8000) NULL, 
	[has_zero_outstanding] varchar(7) NOT NULL, 
	[has_close_diary] varchar(7) NOT NULL, 
	[has_zero_recovery] varchar(7) NOT NULL, 
	[closing_stat_mast_action_code] varchar(8000) NULL, 
	[has_close_adjustments] varchar(7) NOT NULL
);