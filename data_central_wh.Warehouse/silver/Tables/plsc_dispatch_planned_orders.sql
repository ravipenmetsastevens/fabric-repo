CREATE TABLE [silver].[plsc_dispatch_planned_orders] (

	[planned_order_id_raw] varchar(20) NOT NULL, 
	[dispatch_status_raw] varchar(4) NULL, 
	[driver_code_raw] varchar(12) NULL, 
	[mh_date_raw] varchar(20) NULL, 
	[mh_date_iso_raw] varchar(20) NULL, 
	[mh_time_raw] varchar(8) NULL
);