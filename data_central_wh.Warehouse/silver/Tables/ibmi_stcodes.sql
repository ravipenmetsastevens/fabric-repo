CREATE TABLE [silver].[ibmi_stcodes] (

	[stcodes_settlement_code] varchar(8000) NULL, 
	[stcodes_description] varchar(8000) NULL, 
	[stcodes_credit_account_number] varchar(8000) NULL, 
	[stcodes_debit_account_number] varchar(8000) NULL, 
	[stcodes_settlement_type] varchar(7) NOT NULL, 
	[stcodes_deduction_code] varchar(8000) NULL, 
	[is_active] varchar(7) NOT NULL, 
	[stcodes_creation_date] date NULL, 
	[stcodes_creation_user_code] varchar(8000) NULL, 
	[stcodes_last_update_date] date NULL, 
	[stcodes_last_update_user_code] varchar(8000) NULL
);