CREATE TABLE [silver].[risk_claim_reserve_total] (

	[reserve_ttl_claim_record_code] float NULL, 
	[reserve_ttl_reserve_total_amount] float NULL, 
	[reserve_ttl_paid_loss_total_amount] float NULL, 
	[reserve_ttl_paid_expense_total_amount] float NULL, 
	[reserve_ttl_recovered_total_amount] float NULL, 
	[reserve_ttl_create_datetime] datetime2(6) NULL, 
	[reserve_ttl_create_user_code] varchar(8000) NULL, 
	[reserve_ttl_last_change_datetime] datetime2(6) NULL, 
	[reserve_ttl_last_change_user_code] varchar(8000) NULL
);