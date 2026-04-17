CREATE TABLE [silver].[risk_involved_vehicle] (

	[involved_veh_claim_record_code] float NULL, 
	[involved_veh_involved_party_code] float NULL, 
	[involved_veh_record_code] float NULL, 
	[involved_veh_equipment_type] varchar(7) NOT NULL, 
	[involved_veh_equipment_code] varchar(8000) NULL, 
	[involved_veh_year] smallint NULL, 
	[involved_veh_make] varchar(8000) NULL, 
	[involved_veh_model] varchar(8000) NULL, 
	[has_damage] varchar(7) NOT NULL, 
	[has_pictures] varchar(7) NOT NULL, 
	[was_towed] varchar(7) NOT NULL, 
	[involved_veh_tag_number] varchar(8000) NULL, 
	[involved_veh_registration_state] varchar(8000) NULL, 
	[involved_veh_damage_description] varchar(8000) NULL, 
	[involved_veh_detail_description] varchar(8000) NULL, 
	[involved_veh_create_datetime] datetime2(6) NULL, 
	[involved_veh_create_user_code] varchar(8000) NULL, 
	[involved_veh_last_update_datetime] datetime2(6) NULL, 
	[involved_veh_last_update_user_code] varchar(8000) NULL, 
	[involved_veh_vin] varchar(8000) NULL
);