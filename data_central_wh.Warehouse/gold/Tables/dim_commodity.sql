CREATE TABLE [gold].[dim_commodity] (

	[commodity_id_pk] int NULL, 
	[commodity_key] varchar(8000) NULL, 
	[commodity_code] varchar(8000) NULL, 
	[commodity_division_code] varchar(8000) NULL, 
	[commodity_division_name] varchar(8000) NULL, 
	[commodity_division_status] varchar(7) NULL, 
	[is_commodity_deleted] varchar(5) NULL, 
	[commodity_short_descr] varchar(8000) NULL, 
	[commodity_description] varchar(8000) NULL, 
	[commodity_gl_acct] varchar(8000) NULL, 
	[commodity_gl_acct_description] varchar(8000) NULL, 
	[commodity_revenue_type] varchar(8000) NULL, 
	[is_washout_required] varchar(8000) NULL
);