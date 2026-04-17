CREATE TABLE [gold].[fact_billing_all] (

	[billing_load_number] varchar(8000) NULL, 
	[billing_sequence_number] varchar(8000) NULL, 
	[billing_record_number] decimal(2,0) NULL, 
	[is_deleted] varchar(5) NULL, 
	[billing_commodity_code] varchar(8000) NULL, 
	[billing_commodity_description] varchar(8000) NULL, 
	[billing_piece_count] decimal(4,0) NULL, 
	[billing_actual_quantity_count] decimal(7,0) NULL, 
	[billing_billed_quantity_count] decimal(7,0) NULL, 
	[billing_billed_rate] decimal(6,0) NULL, 
	[billing_billed_amount] decimal(8,2) NULL, 
	[billing_method_code] varchar(8000) NULL, 
	[billing_error_code] varchar(8000) NULL, 
	[billing_gl_account_number] varchar(8000) NULL
);