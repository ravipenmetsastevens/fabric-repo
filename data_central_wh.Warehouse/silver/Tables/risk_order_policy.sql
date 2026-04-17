CREATE TABLE [silver].[risk_order_policy] (

	[order_policy_claim_record_code] float NULL, 
	[order_policy_record_code] float NULL, 
	[order_policy_load_number] varchar(8000) NULL, 
	[order_policy_dispatch] smallint NULL, 
	[order_policy_create_datetime] datetime2(6) NULL, 
	[order_policy_create_user_code] varchar(8000) NULL, 
	[order_policy_last_change_datetime] datetime2(6) NULL, 
	[order_policy_last_change_user_code] varchar(8000) NULL
);