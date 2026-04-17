CREATE TABLE [silver].[flrk_scheduled_maint] (

	[sched_maint_id] bigint NULL, 
	[sm_group] varchar(8000) NULL, 
	[sm_vin] varchar(8000) NULL, 
	[sm_unit_number] varchar(8000) NULL, 
	[sm_start_date] date NULL, 
	[sm_start_miles] float NULL, 
	[sm_start_engine_hours] bigint NULL, 
	[sm_is_recurring] bit NULL, 
	[scheduled_days] bigint NULL, 
	[scheduled_miles] float NULL, 
	[scheduled_engine_hours] bigint NULL, 
	[sm_system_component_code] varchar(8000) NULL, 
	[sm_tag] varchar(8000) NULL, 
	[sm_notes] varchar(8000) NULL, 
	[sm_became_due_datetime] datetime2(6) NULL, 
	[sm_ro_number] bigint NULL
);