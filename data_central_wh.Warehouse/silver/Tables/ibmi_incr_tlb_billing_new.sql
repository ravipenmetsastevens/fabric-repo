CREATE TABLE [silver].[ibmi_incr_tlb_billing_new] (

	[tlb_billing_load_number] varchar(8000) NULL, 
	[tlb_billing_sequence_number] varchar(8000) NULL, 
	[tlb_billing_record_number] decimal(34,6) NULL, 
	[tlb_billing_commodity_code] varchar(8000) NULL, 
	[tlb_billing_commodity_description] varchar(8000) NULL, 
	[tlb_billing_piece_count] decimal(34,6) NULL, 
	[tlb_billing_actual_quantity_count] decimal(34,6) NULL, 
	[tlb_billing_billed_quantity_count] decimal(34,6) NULL, 
	[tlb_billing_billed_rate] decimal(34,6) NULL, 
	[tlb_billing_billed_amount] decimal(34,6) NULL, 
	[tlb_billing_method_code] varchar(8000) NULL, 
	[tlb_billing_error_code] varchar(8000) NULL, 
	[tlb_billing_gl_account_number] varchar(8000) NULL, 
	[tlb_billing_gl_cost_center_code] varchar(8000) NULL, 
	[is_deleted] int NULL
);