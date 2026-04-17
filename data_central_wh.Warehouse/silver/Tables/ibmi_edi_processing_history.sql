CREATE TABLE [silver].[ibmi_edi_processing_history] (

	[edi_proc_hist_customer_code] varchar(8000) NULL, 
	[edi_proc_hist_customer_ship_number] varchar(8000) NULL, 
	[edi_proc_hist_sequence_number] decimal(34,6) NULL, 
	[edi_proc_hist_stv_load_number] varchar(8000) NULL, 
	[edi_proc_hist_action] varchar(8) NOT NULL, 
	[edi_proc_hist_action_date] date NULL, 
	[edi_proc_hist_action_time] time(0) NULL, 
	[edi_proc_hist_event_code] varchar(8000) NULL, 
	[edi_proc_hist_event_date] date NULL, 
	[edi_proc_hist_event_time] time(0) NULL, 
	[edi_proc_hist_event_description] varchar(8000) NULL, 
	[edi_proc_hist_trasmit_date] date NULL, 
	[edi_proc_hist_transmit_time] time(0) NULL, 
	[edi_proc_hist_pillsbury_load_number] varchar(8000) NULL
);