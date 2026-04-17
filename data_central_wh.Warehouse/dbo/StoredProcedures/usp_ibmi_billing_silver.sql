/***************************************************************************************************
Procedure:          dbo.usp_ibmi_billing_silver
Create Date:        2024-05-06
Author:             Jeremy Shahan
Description:        Truncate and load of Billing Silver
Called by:            Azure Data Factory
					Pipeline: ibmi_billing
Affected table(s):  silver.ibmi_billing
Usage:              EXEC dbo.usp_ibmi_billing_silver

****************************************************************************************************
SUMMARY OF CHANGES
#             Date(yyyy-mm-dd)    Author              Comments
------------------- ------------------ ------------------------------------------------------------
1            
***************************************************************************************************/

CREATE     PROCEDURE [dbo].[usp_ibmi_billing_silver]
AS

SET NOCOUNT ON

DELETE FROM silver.ibmi_billing

INSERT INTO silver.ibmi_billing
SELECT
	  TRIM(a.BIODR)																			AS billing_load_number
	, TRIM(a.BISEQ)																			AS billing_sequence_number
	, a.BICNT																				AS billing_record_number
	, TRIM(a.BICOMM)																		AS billing_commodity_code
	, TRIM(a.BIDESC)																		AS billing_commodity_description
	, a.BIPIEC																				AS billing_piece_count
	, a.BIAQTY																				AS billing_actual_quantity_count
	, a.BIBQTY																				AS billing_billed_quantity_count --Seems unused
	, a.BIRATE																				AS billing_billed_rate
	, a.BIAMT																				AS billing_billed_amount 
	, TRIM(a.BIMETH)																		AS billing_method_code
	, TRIM(a.BIERR)																			AS billing_error_code 
	, TRIM(a.BIACCT)																		AS billing_gl_account_number
	, TRIM(a.BICC)																			AS billing_gl_cost_center_code  
	--, TRIM(a.BIGSTC)																		Unused
	--, TRIM(a.BIGSTA)																		Unused
	, CAST(0 AS int) AS is_deleted
FROM data_central_lh.dbo.ibmi_billing_bronze a