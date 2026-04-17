CREATE TABLE [silver].[risk_road_surface_master] (

	[road_surf_mast_code] float NULL, 
	[road_surf_mast_description] varchar(8000) NULL, 
	[road_surf_mast_create_datetime] datetime2(6) NULL, 
	[road_surf_mast_create_user_code] varchar(8000) NULL, 
	[road_surf_mast_last_changed_datetime] datetime2(6) NULL, 
	[road_surf_mast_last_changed_user_code] varchar(8000) NULL, 
	[has_act_status] varchar(7) NOT NULL, 
	[road_surf_mast_safety_code] varchar(8000) NULL
);