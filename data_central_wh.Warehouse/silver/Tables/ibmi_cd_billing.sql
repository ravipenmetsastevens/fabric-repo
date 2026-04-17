CREATE TABLE [silver].[ibmi_cd_billing] (

	[cd_billing_load_number] varchar(8000) NULL, 
	[cd_billing_sequence_number] varchar(8000) NULL, 
	[cd_billing_record_number] decimal(2,0) NULL, 
	[cd_billing_commodity_code] varchar(8000) NULL, 
	[cd_billing_commodity_description] varchar(8000) NULL, 
	[cd_billing_piece_count] decimal(4,0) NULL, 
	[cd_billing_actual_quantity_count] decimal(7,0) NULL, 
	[cd_billing_billed_quantity_count] decimal(7,0) NULL, 
	[cd_billing_billed_rate] decimal(6,0) NULL, 
	[cd_billing_billed_amount] decimal(8,2) NULL, 
	[cd_billing_method_code] varchar(8000) NULL, 
	[cd_billing_error_code] varchar(8000) NULL, 
	[cd_billing_gl_account_number] varchar(8000) NULL, 
	[is_deleted] int NULL
);