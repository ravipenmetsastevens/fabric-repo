CREATE TABLE [silver].[ibmi_service_exceptions_la] (

	[serv_exc_la_load_number] varchar(8000) NULL, 
	[serv_exc_la_sequence_number] int NULL, 
	[serv_exc_la_stop_number] int NULL, 
	[serv_exc_la_late_appt_date] date NULL, 
	[serv_exc_la_late_appt_time] time(0) NULL, 
	[serv_exc_la_arrival_date] date NULL, 
	[serv_exc_la_arrival_time] time(0) NULL
);