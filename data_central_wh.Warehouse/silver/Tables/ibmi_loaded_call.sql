CREATE TABLE [silver].[ibmi_loaded_call] (

	[loaded_call_truck_number] varchar(8000) NULL, 
	[loaded_call_load_number] varchar(8000) NULL, 
	[loaded_call_dispatch] varchar(8000) NULL, 
	[loaded_call_call_number] varchar(8000) NULL, 
	[loaded_call_trailer_number] varchar(8000) NULL, 
	[loaded_call_seat_1_driver_code] varchar(8000) NULL, 
	[loaded_call_seat_2_driver_code] varchar(8000) NULL, 
	[loaded_call_contact_date] date NULL, 
	[loaded_call_contact_time] time(0) NULL, 
	[loaded_call_type_code] varchar(8000) NULL, 
	[loaded_call_location_code] varchar(8000) NULL, 
	[loaded_call_city_short_name] varchar(8000) NULL, 
	[loaded_call_initials] varchar(8000) NULL, 
	[loaded_call_message_details] varchar(8000) NULL, 
	[loaded_call_hub_reading] decimal(34,6) NULL, 
	[loaded_call_temp_reading] decimal(34,6) NULL, 
	[loaded_call_hub_flag] varchar(8000) NULL
);