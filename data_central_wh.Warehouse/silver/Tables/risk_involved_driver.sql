CREATE TABLE [silver].[risk_involved_driver] (

	[involved_drv_claim_record_code] float NULL, 
	[involved_drv_involved_party_code] float NULL, 
	[was_seatbelt_used] varchar(7) NOT NULL, 
	[was_drug_test_required] varchar(7) NOT NULL, 
	[involved_drv_driver_code] varchar(8000) NULL, 
	[involved_drv_dm_code] varchar(8000) NULL, 
	[was_injured] varchar(7) NOT NULL, 
	[is_vehicle_owner] varchar(7) NOT NULL, 
	[involved_drv_license_state] varchar(8000) NULL, 
	[involved_drv_social_security] int NULL, 
	[involved_drv_gender] varchar(7) NOT NULL, 
	[involved_drv_marital_status] varchar(9) NOT NULL, 
	[involved_drv_birth_date] datetime2(6) NULL, 
	[involved_drv_hire_date] datetime2(6) NULL, 
	[involved_drv_create_datetime] datetime2(6) NULL, 
	[involved_drv_create_user_code] varchar(8000) NULL, 
	[involved_drv_last_changed_datetime] datetime2(6) NULL, 
	[involved_drv_last_changed_user_code] varchar(8000) NULL, 
	[involved_drv_driver_type] varchar(7) NOT NULL, 
	[involved_drv_trainer_code] varchar(8000) NULL, 
	[involved_drv_license_number] varchar(8000) NULL
);