CREATE TABLE [silver].[flrk_repair_order_task_part] (

	[ro_task_id] bigint NULL, 
	[ro_task_part_id] bigint NULL, 
	[part_id] varchar(8000) NULL, 
	[part_number] varchar(8000) NULL, 
	[part_description] varchar(8000) NULL, 
	[part_system_code] varchar(8000) NULL, 
	[part_type] varchar(8000) NULL, 
	[part_price] float NULL, 
	[part_quantity] bigint NULL, 
	[part_tax_rate] float NULL, 
	[part_location] varchar(8000) NULL, 
	[part_tire_brand] varchar(8000) NULL, 
	[part_tire_product_line] varchar(8000) NULL, 
	[part_tire_size] varchar(8000) NULL, 
	[part_tire_type] varchar(8000) NULL, 
	[part_added_datetime] datetime2(6) NULL
);