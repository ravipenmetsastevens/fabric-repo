CREATE TABLE [silver].[risk_accident_type_master] (

	[accident_type_code] float NULL, 
	[accident_type_description] varchar(8000) NULL, 
	[accident_type_create_datetime] datetime2(6) NULL, 
	[accident_type_create_user_code] varchar(8000) NULL, 
	[accident_type_last_changed_datetime] datetime2(6) NULL, 
	[accident_type_last_changed_user_code] varchar(8000) NULL, 
	[accident_type_category] varchar(8000) NULL, 
	[is_on_road] varchar(7) NOT NULL, 
	[accident_type_safety_type_code] varchar(8000) NULL
);