CREATE TABLE [silver].[ibmi_service_exceptions_edi] (

	[se_load_number] varchar(8000) NULL, 
	[se_stop_number] decimal(34,6) NULL, 
	[se_edi_code] varchar(8000) NULL, 
	[se_record_number] decimal(34,6) NULL, 
	[se_status_type] varchar(8000) NULL, 
	[se_create_date] date NULL, 
	[se_create_time] time(0) NULL, 
	[se_remarks] varchar(8000) NULL, 
	[se_changed_date] date NULL, 
	[se_changed_time] time(0) NULL, 
	[se_reason_code] varchar(16) NULL, 
	[se_audit_user_code] varchar(8000) NULL, 
	[se_stop_time_zone] decimal(34,6) NULL, 
	[is_daylight_savings_time] varchar(7) NOT NULL
);