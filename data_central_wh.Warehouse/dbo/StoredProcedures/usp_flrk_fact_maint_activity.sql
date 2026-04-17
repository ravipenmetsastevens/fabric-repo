/***************************************************************************************************
Procedure:          dbo.usp_flrk_fact_maint_activity
Create Date:        2024-04-28
Author:             Tom Wolfenden
Description:        Create gold.fact_maint_activity
Called by:          Fabric  
					Pipeline: Fleetrock\Pipeline\pl_flrk_repair_order
Affected table(s):  gold.fact_maint_activity
Usage:              EXEC dbo.usp_flrk_fact_maint_activity

****************************************************************************************************
SUMMARY OF CHANGES
#             Date(yyyy-mm-dd)    Author              Comments
------------------- ------------------ ------------------------------------------------------------
1            
***************************************************************************************************/

CREATE PROCEDURE [dbo].[usp_flrk_fact_maint_activity]
AS

DELETE FROM gold.fact_maint_activity

INSERT INTO gold.fact_maint_activity
SELECT DISTINCT
	  a.repair_order_id
	, a.ro_group
	, a.ro_vin
	, a.ro_unit_number
	, a.ro_unit_type
	, a.ro_vendor_name
	, CASE WHEN LEN(a.ro_vendor_company_id) > 0
		THEN 'VENDOR'
		ELSE 'SHOP' END																						AS ro_location_type
	, ro_status
	, CASE WHEN ro_status IN('Finished', 'Paid', 'Invoiced')
		THEN 'CLOSED' ELSE 'OPEN' END																		AS ro_open_closed
	, a.ro_created_datetime AT TIME ZONE 'UTC' AT TIME ZONE 'Central Standard Time'							AS ro_created_datetime
    , CONVERT(DATE, ro_created_datetime AT TIME ZONE 'UTC' AT TIME ZONE 'Central Standard Time')			AS ro_created_date
    , a.ro_started_datetime AT TIME ZONE 'UTC' AT TIME ZONE 'Central Standard Time'							AS ro_started_datetime
    , CONVERT(DATE, a.ro_started_datetime AT TIME ZONE 'UTC' AT TIME ZONE 'Central Standard Time')			AS ro_started_date
    , a.ro_expected_finish_datetime AT TIME ZONE 'UTC' AT TIME ZONE 'Central Standard Time'					AS ro_expected_finish_datetime
    , CONVERT(DATE, a.ro_expected_finish_datetime AT TIME ZONE 'UTC' AT TIME ZONE 'Central Standard Time')	AS ro_expected_finish_date
    , a.ro_finished_datetime AT TIME ZONE 'UTC' AT TIME ZONE 'Central Standard Time'						AS ro_finished_datetime
    , CONVERT(DATE, a.ro_finished_datetime AT TIME ZONE 'UTC' AT TIME ZONE 'Central Standard Time')			AS ro_finished_date
    , a.ro_invoiced_datetime AT TIME ZONE 'UTC' AT TIME ZONE 'Central Standard Time'						AS ro_invoiced_datetime
    , CONVERT(DATE, a.ro_invoiced_datetime AT TIME ZONE 'UTC' AT TIME ZONE 'Central Standard Time')			AS ro_invoiced_date
    , a.ro_invoice_paid_datetime AT TIME ZONE 'UTC' AT TIME ZONE 'Central Standard Time'					AS ro_invoice_paid_datetime
    , CONVERT(DATE, a.ro_invoice_paid_datetime AT TIME ZONE 'UTC' AT TIME ZONE 'Central Standard Time')		AS ro_invoice_paid_date
	, DATEDIFF(hour, a.ro_started_datetime, a.ro_finished_datetime)											AS ro_down_hours
	, ro_additional_charges
	, ro_tax_total
	, ro_credit_amount
	, ro_estimate
	, ro_grand_total
	, ro_paid_amount
FROM [silver].[flrk_repair_order] a
WHERE a.ro_status <> 'Deleted'