CREATE TABLE [silver].[risk_transportation_master] (

	[trans_mast_claim_record_code] float NULL, 
	[is_accident_or_incident] varchar(8) NOT NULL, 
	[trans_mast_carrier_claim_code] varchar(8000) NULL, 
	[trans_mast_accident_type_code] float NULL, 
	[trans_mast_weather_condition_code] float NULL, 
	[is_dot_reportable] varchar(7) NOT NULL, 
	[is_preventable] varchar(7) NOT NULL, 
	[trans_mast_dm_code] varchar(8000) NULL, 
	[trans_mast_terminal_location] varchar(8000) NULL, 
	[trans_mast_dmol_code] varchar(8000) NULL, 
	[trans_mast_road_surface_code] float NULL, 
	[trans_mast_road_condition_code] float NULL, 
	[is_divided_highway] varchar(7) NOT NULL, 
	[trans_mast_lane_count] smallint NULL, 
	[trans_mast_create_datetime] datetime2(6) NULL, 
	[trans_mast_create_user_code] varchar(8000) NULL, 
	[trans_mast_last_change_datetime] datetime2(6) NULL, 
	[trans_mast_last_change_user_code] varchar(8000) NULL, 
	[trans_mast_near_city] varchar(8000) NULL, 
	[trans_mast_near_state] varchar(8000) NULL
);