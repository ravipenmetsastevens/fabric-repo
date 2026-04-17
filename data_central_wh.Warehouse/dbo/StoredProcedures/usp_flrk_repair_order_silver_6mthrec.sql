/***************************************************************************************************
Procedure:          dbo.[usp_flrk_repair_order_silver_6mthrec]
Create Date:        2024-04-28
Author:             Tom Wolfenden
Description:        This procedure is written to update all the repair order data on a rolling 6 month
					cycle, because FleetRock does not allow us to download all the ROs at once.
					We can only download 1 month at a time, so we have a pipeline that gets the last 6
					month's worth of data, and this procedure updates the main tables to keep them
					reconciled.
Called by:          Fabric  
					Pipeline: Fleetrock\Pipeline\pl_flrk_repair_order_6mthrec
Affected table(s):  silver.flrk_repair_order_6mthrec
					silver.flrk_repair_order_note_6mthrec
					silver.flrk_repair_order_task_6mthrec
					silver.flrk_repair_order_task_part_6mthrec
Usage:              EXEC dbo.usp_flrk_repair_order_silver_6mthrec

****************************************************************************************************
SUMMARY OF CHANGES
#             Date(yyyy-mm-dd)    Author              Comments
------------------- ------------------ ------------------------------------------------------------
1            
***************************************************************************************************/

CREATE PROCEDURE [dbo].[usp_flrk_repair_order_silver_6mthrec]
AS

--REPAIR ORDERS
DELETE FROM silver.flrk_repair_order_6mthrec
INSERT INTO silver.flrk_repair_order_6mthrec
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
FROM data_central_lh.dbo.flrk_repair_order_6mthrec_bronze a


--  REPAIR ORDER NOTES
DELETE FROM silver.flrk_repair_order_note_6mthrec
INSERT INTO silver.flrk_repair_order_note_6mthrec
SELECT DISTINCT 
	    a.id
	  ,	a.[notes.note_id]
      , a.[notes.note]
      , a.[notes.added_by]
      , a.[notes.date_added]
FROM data_central_lh.dbo.flrk_repair_order_6mthrec_bronze a
WHERE a.[notes.note_id] IS NOT NULL


--  REPAIR ORDER TASKS
DELETE FROM silver.flrk_repair_order_task_6mthrec
INSERT INTO silver.flrk_repair_order_task_6mthrec
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
FROM data_central_lh.dbo.flrk_repair_order_6mthrec_bronze a
WHERE a.[tasks.task_id] IS NOT NULL


--  TASK PARTS
DELETE FROM silver.flrk_repair_order_task_part_6mthrec
INSERT INTO silver.flrk_repair_order_task_part_6mthrec
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
FROM data_central_lh.dbo.flrk_repair_order_6mthrec_bronze a
WHERE a.[tasks.parts.task_part_id] IS NOT NULL


/**************************************************************
*	RECONCILE SECTION										  *
**************************************************************/
-- RECONCILE THE REPAIR ORDERS
UPDATE a
SET
	    a.ro_group						=	b.ro_group
      , a.ro_group_hierarchy			=	b.ro_group_hierarchy
      , a.ro_vin						=	b.ro_vin
      , a.ro_unit_number				=	b.ro_unit_number
      , a.ro_unit_type					=	b.ro_unit_type
      , a.ro_custom_asset_id			=	b.ro_custom_asset_id
      , a.ro_vendor_name				=	b.ro_vendor_name
      , a.ro_vendor_company_id			=	b.ro_vendor_company_id
	  , a.ro_vendor_city				=   b.ro_vendor_city
      , a.ro_vendor_state				=	b.ro_vendor_state
      , a.ro_vendor_province			=	b.ro_vendor_province
      , a.ro_vendor_zip_code			=	b.ro_vendor_zip_code
      , a.ro_vendor_timezone			=   b.ro_vendor_timezone
      , a.ro_customer_name				=   b.ro_customer_name
      , a.ro_customer_company_id		=	b.ro_customer_company_id
      , a.ro_odometer_miles				=	b.ro_odometer_miles
      , a.ro_engine_hours				=	b.ro_engine_hours
      , a.ro_priority_code				=	b.ro_priority_code
      , a.ro_cost_center				=	b.ro_cost_center
      , a.ro_tag						=   b.ro_tag
      , a.ro_status						=	b.ro_status
      , a.ro_created_by					=	b.ro_created_by
      , a.ro_created_datetime			=	b.ro_created_datetime	
      , a.ro_started_datetime			=	b.ro_started_datetime
      , a.ro_expected_finish_datetime	=	b.ro_expected_finish_datetime
      , a.ro_finished_datetime			=	b.ro_finished_datetime
      , a.ro_invoiced_datetime			=	b.ro_invoiced_datetime
      , a.ro_invoice_paid_datetime		=	b.ro_invoice_paid_datetime
      , a.ro_po_number					=	b.ro_po_number
      , a.ro_additional_charges			=	b.ro_additional_charges
      , a.ro_tax_total					=	b.ro_tax_total
      , a.ro_credit_amount				=	b.ro_credit_amount
      , a.ro_estimate					=	b.ro_estimate
      , a.ro_grand_total				=	b.ro_grand_total
      , a.ro_paid_amount				=	b.ro_paid_amount
      , a.ro_remit_to					=	b.ro_remit_to
      , a.ro_remit_to_company_id		=	b.ro_remit_to_company_id
FROM [silver].[flrk_repair_order] a
JOIN [silver].[flrk_repair_order_6mthrec] b ON a.repair_order_id = b.repair_order_id

-- RECONCILE THE NOTES
-- UPDATE EXISTING NOTES (removed this because it's more efficient to delete them all and re-pop
/*
UPDATE a
SET
	    --a.repair_order_id
      --, [ro_note_id]
        a.ro_note							=	b.ro_note
      , a.ro_note_added_by					=	b.ro_note_added_by
      , a.ro_note_added_datetime			=	b.ro_note_added_datetime
FROM [silver].[flrk_repair_order_note] a
JOIN [silver].[flrk_repair_order_note_6mthrec] b ON a.repair_order_id = b.repair_order_id
												AND a.ro_note_id = b.ro_note_id */

-- ADD NEW NOTES

DELETE FROM silver.flrk_repair_order_note
WHERE repair_order_id IN(SELECT repair_order_id FROM [silver].[flrk_repair_order_note_6mthrec])

INSERT INTO silver.flrk_repair_order_note
SELECT DISTINCT 
	    a.repair_order_id
	  ,	a.ro_note_id
      , a.ro_note
      , a.ro_note_added_by
      , a.ro_note_added_datetime
FROM [silver].[flrk_repair_order_note_6mthrec] a
LEFT JOIN silver.flrk_repair_order_note b ON a.ro_note_id = b.ro_note_id
WHERE b.ro_note_id IS NULL

--RECONCILE TASKS
UPDATE a
SET
	   --[repair_order_id]
      --,[ro_task_id]
        a.task_labor_hourly_rate					=	b.task_labor_hourly_rate
      , a.task_labor_hours							=	b.task_labor_hours
      , a.task_labor_subtotal						=	b.task_labor_subtotal
      , a.task_labor_tax_rate						=	b.task_labor_tax_rate
      , a.task_labor_complaint						=	b.task_labor_complaint
      , a.task_labor_cause_code						=	b.task_labor_cause_code
      , a.task_labor_correction_code				=	b.task_labor_correction_code
      , a.task_labor_system_code					=	b.task_labor_system_code
      , a.task_labor_system_component_code			=	b.task_labor_system_component_code
      , a.task_scheduled_maintenance_id				=	b.task_scheduled_maintenance_id
      , a.task_issue_id								=	b.task_issue_id
      , a.task_assigned_to							=	b.task_assigned_to
      , a.task_added_datetime						=	b.task_added_datetime
FROM [silver].[flrk_repair_order_task] a
JOIN [silver].[flrk_repair_order_task_6mthrec] b ON a.repair_order_id = b.repair_order_id
												AND	a.ro_task_id = b.ro_task_id

INSERT INTO [silver].[flrk_repair_order_task]
SELECT DISTINCT
		a.repair_order_id
	  ,	a.ro_task_id
      , a.task_labor_hourly_rate
      , a.task_labor_hours	
      , a.task_labor_subtotal
      , a.task_labor_tax_rate	
      , a.task_labor_complaint
      , a.task_labor_cause_code	
      , a.task_labor_correction_code
      , a.task_labor_system_code	
      , a.task_labor_system_component_code	
      , a.task_scheduled_maintenance_id			
      , a.task_issue_id						
      , a.task_assigned_to					
      , a.task_added_datetime
FROM [silver].[flrk_repair_order_task_6mthrec] a
LEFT JOIN [silver].[flrk_repair_order_task] b on a.ro_task_id = b.ro_task_id
WHERE b.ro_task_id IS NULL

--RECONCILE TASK PARTS

--NEED TO DELETE ALL THE TASK PART RECORDS FOR EACH TASK THAT WE HAVE, AND THEN
--ADD THEM BACK IN BECAUSE THERE IS NO UNIQUE ID FOR PARTS ROWS.

DELETE FROM [silver].[flrk_repair_order_task_part]
WHERE ro_task_id IN(SELECT DISTINCT ro_task_id FROM [silver].[flrk_repair_order_task_part_6mthrec])

INSERT INTO [silver].[flrk_repair_order_task_part]
SELECT * FROM [silver].[flrk_repair_order_task_part_6mthrec]