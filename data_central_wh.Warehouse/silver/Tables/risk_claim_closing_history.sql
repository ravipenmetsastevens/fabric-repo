CREATE TABLE [silver].[risk_claim_closing_history] (

	[claim_closing_hist_claim_record_code] float NULL, 
	[claim_closing_hist_record_code] float NULL, 
	[claim_closing_hist_status_code] float NULL, 
	[has_zero_outstanding] varchar(7) NOT NULL, 
	[has_zero_recoveries] varchar(7) NOT NULL, 
	[has_active_diary] varchar(7) NOT NULL, 
	[claim_closing_hist_archive_date] datetime2(6) NULL, 
	[claim_closing_hist_destruction_date] datetime2(6) NULL, 
	[claim_closing_hist_create_datetime] datetime2(6) NULL, 
	[claim_closing_hist_create_user_code] varchar(8000) NULL, 
	[claim_closing_hist_last_change_datetime] datetime2(6) NULL, 
	[claim_closing_hist_last_change_user_code] varchar(8000) NULL
);