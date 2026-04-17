/***************************************************************************************************
Procedure:          dbo.usp_flrk_fact_maint_repair_order
Create Date:        2024-04-28
Author:             Tom Wolfenden
Description:        Create gold.fact_main_repair_order
Called by:          Fabric  
					Pipeline: Fleetrock\Pipeline\pl_flrk_repair_order
Affected table(s):  gold.fact_main_repair_order
Usage:              EXEC dbo.usp_flrk_fact_maint_repair_order

****************************************************************************************************
SUMMARY OF CHANGES
#             Date(yyyy-mm-dd)    Author              Comments
------------------- ------------------ ------------------------------------------------------------
1            
***************************************************************************************************/

CREATE PROCEDURE dbo.usp_flrk_fact_maint_repair_order
AS

DELETE FROM gold.fact_maint_repair_order

INSERT INTO gold.fact_maint_repair_order
SELECT 
		a.repair_order_id
      , a.ro_group
      , a.ro_group_hierarchy
      , a.ro_vin
      , a.ro_unit_number
      , a.ro_unit_type
      , a.ro_custom_asset_id
      , a.ro_vendor_name
      , a.ro_vendor_company_id
      , a.ro_vendor_city
      , a.ro_vendor_state
      , a.ro_vendor_zip_code
      , a.ro_vendor_timezone
      , a.ro_customer_name
      , a.ro_odometer_miles
      , a.ro_engine_hours
      , a.ro_tag
      , a.ro_status
      , a.ro_created_by
      , a.ro_created_datetime AT TIME ZONE 'UTC' AT TIME ZONE 'Central Standard Time'						AS ro_created_datetime
      , CONVERT(DATE, ro_created_datetime AT TIME ZONE 'UTC' AT TIME ZONE 'Central Standard Time')			AS ro_created_date
      , a.ro_started_datetime AT TIME ZONE 'UTC' AT TIME ZONE 'Central Standard Time'						AS ro_started_datetime
      , CONVERT(DATE, a.ro_started_datetime AT TIME ZONE 'UTC' AT TIME ZONE 'Central Standard Time')		AS ro_started_date
      , a.ro_expected_finish_datetime AT TIME ZONE 'UTC' AT TIME ZONE 'Central Standard Time'				AS ro_expected_finish_datetime
      , CONVERT(DATE, a.ro_expected_finish_datetime AT TIME ZONE 'UTC' AT TIME ZONE 'Central Standard Time')	AS ro_expected_finish_date
      , a.ro_finished_datetime AT TIME ZONE 'UTC' AT TIME ZONE 'Central Standard Time'						AS ro_finished_datetime
      , CONVERT(DATE, a.ro_finished_datetime AT TIME ZONE 'UTC' AT TIME ZONE 'Central Standard Time')			AS ro_finished_date
      , a.ro_invoiced_datetime AT TIME ZONE 'UTC' AT TIME ZONE 'Central Standard Time'						AS ro_invoiced_datetime
      , CONVERT(DATE, a.ro_invoiced_datetime AT TIME ZONE 'UTC' AT TIME ZONE 'Central Standard Time')			AS ro_invoiced_date
      , a.ro_invoice_paid_datetime AT TIME ZONE 'UTC' AT TIME ZONE 'Central Standard Time'					AS ro_invoice_paid_datetime
      , CONVERT(DATE, a.ro_invoice_paid_datetime AT TIME ZONE 'UTC' AT TIME ZONE 'Central Standard Time')		AS ro_invoice_paid_date
      , a.ro_po_number
      , a.ro_additional_charges
      , a.ro_tax_total
      , a.ro_credit_amount
      , a.ro_estimate
      , a.ro_grand_total
      , a.ro_paid_amount
FROM silver.flrk_repair_order a