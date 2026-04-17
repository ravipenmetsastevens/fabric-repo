CREATE TABLE [silver].[ibmi_toll_history] (

	[toll_history_tag_number] varchar(8000) NULL, 
	[toll_history_truck_number] varchar(8000) NULL, 
	[toll_history_toll_date] datetime2(6) NULL, 
	[toll_history_location] varchar(8000) NULL, 
	[toll_history_amount] decimal(7,2) NULL, 
	[toll_history_owner_code] varchar(8000) NULL, 
	[toll_history_division_code] varchar(8000) NULL, 
	[toll_history_load_number] varchar(8000) NULL, 
	[toll_history_dispatch_number] varchar(8000) NULL, 
	[toll_history_bill_to_code] varchar(8000) NULL, 
	[toll_history_upload_date] datetime2(6) NULL
);