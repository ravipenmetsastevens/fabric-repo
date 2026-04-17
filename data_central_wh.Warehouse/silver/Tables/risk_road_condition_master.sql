CREATE TABLE [silver].[risk_road_condition_master] (

	[road_cond_mast_code] float NULL, 
	[road_cond_mast_description] varchar(8000) NULL, 
	[road_cond_mast_create_datetime] datetime2(6) NULL, 
	[road_cond_mast_create_user_code] varchar(8000) NULL, 
	[road_cond_mast_last_changed_datetime] datetime2(6) NULL, 
	[road_cond_mast_last_changed_user_code] varchar(8000) NULL, 
	[road_cond_mast_safety_code] int NULL
);