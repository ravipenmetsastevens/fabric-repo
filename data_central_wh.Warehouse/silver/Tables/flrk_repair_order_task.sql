CREATE TABLE [silver].[flrk_repair_order_task] (

	[repair_order_id] bigint NULL, 
	[ro_task_id] bigint NULL, 
	[task_labor_hourly_rate] float NULL, 
	[task_labor_hours] float NULL, 
	[task_labor_subtotal] float NULL, 
	[task_labor_tax_rate] float NULL, 
	[task_labor_complaint] varchar(8000) NULL, 
	[task_labor_cause_code] varchar(8000) NULL, 
	[task_labor_correction_code] varchar(8000) NULL, 
	[task_labor_system_code] varchar(8000) NULL, 
	[task_labor_system_component_code] varchar(8000) NULL, 
	[task_scheduled_maintenance_id] bigint NULL, 
	[task_issue_id] bigint NULL, 
	[task_assigned_to] varchar(8000) NULL, 
	[task_added_datetime] datetime2(6) NULL
);