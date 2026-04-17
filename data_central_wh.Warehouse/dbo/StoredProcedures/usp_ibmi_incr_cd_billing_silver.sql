/***************************************************************************************************
Procedure:          dbo.usp_ibmi_incr_cd_billing_silver
Create Date:        2024-08-13
Author:             Jeremy Shahan
Description:        Truncate and load of Incremental CD Billing to Silver
Called by:          Fabric
					Pipeline: ibmi_incr_cd_billing
Affected table(s):  silver.ibmi_incr_cd_billing
Usage:              EXEC dbo.usp_ibmi_incr_cd_billing_silver

****************************************************************************************************
SUMMARY OF CHANGES
#             Date(yyyy-mm-dd)    Author              Comments
------------------- ------------------ ------------------------------------------------------------
1            
***************************************************************************************************/

CREATE   PROCEDURE [dbo].[usp_ibmi_incr_cd_billing_silver]
AS

SET NOCOUNT ON

DELETE FROM silver.ibmi_incr_cd_billing

INSERT INTO silver.ibmi_incr_cd_billing
SELECT
	  TRIM(a.BIODR)																			AS cd_billing_load_number
	, TRIM(a.BISEQ)																			AS cd_billing_sequence_number
	, a.BICNT																				AS cd_billing_record_number
	, CASE WHEN TRIM(a.BIDLT) = 'D'
			THEN 'TRUE'
			ELSE 'FALSE' END																AS is_deleted 
	, TRIM(a.BICOMM)																		AS cd_billing_commodity_code
	, a.BIDESC																				AS cd_billing_commodity_description
	, a.BIPIEC																				AS cd_billing_piece_count
	, a.BIAQTY																				AS cd_billing_actual_quantity_count
	, a.BIBQTY																				AS cd_billing_billed_quantity_count --Seems unused
	, a.BIRATE																				AS cd_billing_billed_rate
	, a.BIAMT																				AS cd_billing_billed_amount 
	, TRIM(a.BIMETH)																		AS cd_billing_method_code
	, TRIM(a.BIERR)																			AS cd_billing_error_code 
	, TRIM(a.BIACCT)																		AS cd_billing_gl_account_number
	--, TRIM(a.BICC)																		Unused	  
	--, TRIM(a.BIGSTC)																		Unused
	--, TRIM(a.BIGSTA)																		Unused
FROM data_central_lh.dbo.ibmi_incr_cd_billing_bronze a