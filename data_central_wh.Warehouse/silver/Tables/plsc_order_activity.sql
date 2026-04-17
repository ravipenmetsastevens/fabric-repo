CREATE TABLE [silver].[plsc_order_activity] (

	[ao_date_raw] varchar(32) NULL, 
	[ao_time_raw] varchar(16) NULL, 
	[ao_pr_date_raw] varchar(40) NULL, 
	[ao_proc_code_raw] varchar(8) NULL, 
	[ao_return_type_raw] varchar(8) NULL, 
	[ao_order_id_raw] varchar(20) NOT NULL, 
	[ao_movement_type_raw] varchar(8) NULL, 
	[ao_unit_raw] varchar(16) NULL
);