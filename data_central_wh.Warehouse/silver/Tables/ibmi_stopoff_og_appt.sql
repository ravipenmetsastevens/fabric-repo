CREATE TABLE [silver].[ibmi_stopoff_og_appt] (

	[stopoff_og_load_number] varchar(8000) NULL, 
	[stopoff_og_stop_number] decimal(34,6) NULL, 
	[stopoff_og_appt_early_date] date NULL, 
	[stopoff_og_appt_late_date] date NULL, 
	[stopoff_og_appt_early_time] time(0) NULL, 
	[stopoff_og_appt_late_time] time(0) NULL
);