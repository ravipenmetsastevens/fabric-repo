/***************************************************************************************************
Procedure:          dbo.usp_flrk_repair_order_silver
Create Date:        2024-04-28
Author:             Tom Wolfenden
Description:        Takes the raw data from the bronze lakehouse table for Fleetrock repair orders 
					and splits it into normalized tables
						- Repair Order (main)
						- Repair Order Notes
						- Tasks
						- Task Parts
Called by:          Fabric  
					Pipeline: Fleetrock\Pipeline\pl_flrk_repair_order
Affected table(s):  silver.flrk_repair_order
					silver.flrk_repair_order_note
					silver.flrk_repair_order_task
					silver.flrk_repair_order_task_part
Usage:              EXEC dbo.usp_flrk_repair_order_silver

****************************************************************************************************
SUMMARY OF CHANGES
#             Date(yyyy-mm-dd)    Author              Comments
------------------- ------------------ ------------------------------------------------------------
1            
***************************************************************************************************/

CREATE PROCEDURE [dbo].[usp_flrk_repair_order_silver]
AS

-- MASTER REPAIR ORDER
INSERT INTO silver.flrk_repair_order
SELECT DISTINCT
		a.id
      , a.[group]
      , a.ro_group_hierarchy
      , a.vin
      , a.unit_number
      , a.unit_type
      , a.custom_asset_id
      , a.vendor_name
      , a.vendor_company_id
      , a.vendor_city
      , a.vendor_state
      , a.vendor_province
      , a.vendor_zip_code
      , a.vendor_timezone
      , a.customer_name
      , a.customer_company_id
      , a.odometer_miles
      , a.engine_hours
      , a.priority_code
      , a.cost_center
      , a.tag
      , a.[status]
      , a.created_by
      , a.date_created
      , a.date_started
      , a.date_expected_finish
      , a.date_finished
      , a.date_invoiced
      , a.date_invoice_paid
      , a.po_number
      , a.additional_charges
      , a.tax_total
      , a.credit_amount
      , a.estimate
      , a.grand_total
      , a.paid_amount
      , a.remit_to
      , a.remit_to_company_id
FROM data_central_lh.dbo.flrk_repair_order_bronze a
LEFT JOIN silver.flrk_repair_order b ON CONVERT(INT, a.id) = b.repair_order_id
WHERE b.repair_order_id IS NULL


--  REPAIR ORDER NOTES
INSERT INTO silver.flrk_repair_order_note
SELECT DISTINCT 
	    a.id
	  ,	a.[notes.note_id]
      , a.[notes.note]
      , a.[notes.added_by]
      , a.[notes.date_added]
FROM data_central_lh.dbo.flrk_repair_order_bronze a
LEFT JOIN silver.flrk_repair_order_note b ON CONVERT(INT, a.[notes.note_id]) = b.ro_note_id
WHERE a.[notes.note_id] IS NOT NULL
AND	  b.ro_note_id IS NULL

--  REPAIR ORDER TASKS
INSERT INTO silver.flrk_repair_order_task
SELECT DISTINCT	
		a.id
	  , a.[tasks.task_id]
      , a.[tasks.labor_hourly_rate]
      , a.[tasks.labor_hours]
      , a.[tasks.labor_subtotal]
      , a.[tasks.labor_tax_rate]
      , a.[tasks.labor_complaint]
      , a.[tasks.labor_cause_code]
      , a.[tasks.labor_correction_code]
      , a.[tasks.labor_system_code]
      , a.[tasks.labor_system_component_code]
      , a.[tasks.scheduled_maintenance_id]
      , a.[tasks.issue_id]
      , a.[tasks.assigned_to]
      , a.[tasks.date_added]
FROM data_central_lh.dbo.flrk_repair_order_bronze a
LEFT JOIN silver.flrk_repair_order_task b ON CONVERT(INT, a.[tasks.task_id]) = b.ro_task_id
WHERE a.[tasks.task_id] IS NOT NULL
AND   b.ro_task_id IS NULL

--  TASK PARTS
INSERT INTO silver.flrk_repair_order_task_part
SELECT DISTINCT
		a.[tasks.task_id]
	  , a.[tasks.parts.task_part_id]
      , a.[tasks.parts.part_id]
      , a.[tasks.parts.part_number]
      , a.[tasks.parts.part_description]
      , a.[tasks.parts.part_system_code]
      , a.[tasks.parts.part_type]
      , a.[tasks.parts.part_price]
      , a.[tasks.parts.part_quantity]
      , a.[tasks.parts.part_tax_rate]
      , a.[tasks.parts.part_location]
      , a.[tasks.parts.tire_brand]
      , a.[tasks.parts.tire_product_line]
      , a.[tasks.parts.tire_size]
      , a.[tasks.parts.tire_type]
      , a.[tasks.parts.date_added]
FROM data_central_lh.dbo.flrk_repair_order_bronze a
LEFT JOIN silver.flrk_repair_order_task_part b ON CONVERT(INT, a.[tasks.parts.task_part_id]) = b.ro_task_part_id
WHERE a.[tasks.parts.task_part_id] IS NOT NULL
AND	  b.ro_task_part_id IS NULL