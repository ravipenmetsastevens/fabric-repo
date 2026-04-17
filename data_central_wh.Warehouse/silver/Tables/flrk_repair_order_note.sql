CREATE TABLE [silver].[flrk_repair_order_note] (

	[repair_order_id] bigint NULL, 
	[ro_note_id] bigint NULL, 
	[ro_note] varchar(8000) NULL, 
	[ro_note_added_by] varchar(8000) NULL, 
	[ro_note_added_datetime] datetime2(6) NULL
);