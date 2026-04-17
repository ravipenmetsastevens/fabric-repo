CREATE TABLE [dbo].[flrk_driver] (

	[drv_username] varchar(8000) NULL, 
	[drv_last_name] varchar(8000) NULL, 
	[drv_first_name] varchar(8000) NULL, 
	[drv_street_address] varchar(8000) NULL, 
	[drv_zip_code] varchar(8000) NULL, 
	[drv_city] varchar(8000) NULL, 
	[drv_state] varchar(8000) NULL, 
	[drv_vin] varchar(8000) NULL, 
	[drv_odometer_miles] bigint NULL, 
	[drv_escrow_balance] float NULL, 
	[drv_start_date] date NULL, 
	[drv_end_date] date NULL, 
	[drv_status] varchar(8000) NULL
);