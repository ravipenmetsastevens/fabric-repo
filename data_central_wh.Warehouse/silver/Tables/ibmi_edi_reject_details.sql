CREATE TABLE [silver].[ibmi_edi_reject_details] (

	[edi_rejects_customer_name] varchar(8000) NULL, 
	[edi_rejects_origin] varchar(8000) NULL, 
	[edi_rejects_destination] varchar(8000) NULL, 
	[edi_rejects_bol] varchar(8000) NULL, 
	[edi_rejects_comment] varchar(8000) NULL, 
	[edi_rejects_pickup_date] date NULL, 
	[edi_rejects_delivery_date] date NULL, 
	[edi_rejects_reject_date] date NULL, 
	[edi_rejects_tender_date] date NULL, 
	[edi_rejects_tender_time] time(0) NULL, 
	[edi_rejects_load_type] varchar(8000) NULL, 
	[edi_rejects_temp_low] decimal(34,6) NULL, 
	[edi_rejects_temp_high] decimal(34,6) NULL, 
	[edi_rejects_user_code] varchar(8000) NULL, 
	[edi_rejects_miles_billable] decimal(34,6) NULL
);