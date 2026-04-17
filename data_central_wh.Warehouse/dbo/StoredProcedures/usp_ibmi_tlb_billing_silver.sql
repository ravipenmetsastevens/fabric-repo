/***************************************************************************************************
Procedure:          dbo.usp_ibmi_billing_silver
Create Date:        2024-06-11
Author:             Jeremy Shahan
Description:        Truncate and load of TLB Billing Silver
Called by:            Azure Data Factory
					Pipeline: ibmi_tlb_billing
Affected table(s):  silver.ibmi_tlb_billing
Usage:              EXEC dbo.usp_ibmi_tlb_billing_silver

****************************************************************************************************
SUMMARY OF CHANGES
#             Date(yyyy-mm-dd)    Author              Comments
------------------- ------------------ ------------------------------------------------------------
1            
***************************************************************************************************/

CREATE   PROCEDURE [dbo].[usp_ibmi_tlb_billing_silver]
AS

SET NOCOUNT ON

DELETE FROM silver.ibmi_tlb_billing

INSERT INTO silver.ibmi_tlb_billing
SELECT
	  TRIM(a.BIODR)																			AS tlb_billing_load_number
	, TRIM(a.BISEQ)																			AS tlb_billing_sequence_number
	, a.BICNT																				AS tlb_billing_record_number
	, TRIM(a.BICOMM)																		AS tlb_billing_commodity_code
	, TRIM(a.BIDESC)																		AS tlb_billing_commodity_description
	, a.BIPIEC																				AS tlb_billing_piece_count
	, a.BIAQTY																				AS tlb_billing_actual_quantity_count
	, a.BIBQTY																				AS tlb_billing_billed_quantity_count --Seems unused
	, a.BIRATE																				AS tlb_billing_billed_rate
	, a.BIAMT																				AS tlb_billing_billed_amount 
	, TRIM(a.BIMETH)																		AS tlb_billing_method_code
	, TRIM(a.BIERR)																			AS tlb_billing_error_code 
	, TRIM(a.BIACCT)																		AS tlb_billing_gl_account_number
	, TRIM(a.BICC)																			AS tlb_billing_gl_cost_center_code  
	--, TRIM(a.BIGSTC)																		Unused
	--, TRIM(a.BIGSTA)																		Unused
	, CAST(0 AS int) AS is_deleted
FROM data_central_lh.dbo.ibmi_tlb_billing_bronze a