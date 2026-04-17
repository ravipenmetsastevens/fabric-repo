/***************************************************************************************************
Procedure:          dbo.usp_ibmi_cd_billing_silver
Create Date:        2024-05-06
Author:             Jeremy Shahan
Description:        Truncate and load of CD Billing Silver
Called by:            Azure Data Factory
					Pipeline: ibmi_cd_billing
Affected table(s):  silver.ibmi_cd_billing
Usage:              EXEC dbo.usp_ibmi_cd_billing_silver

****************************************************************************************************
SUMMARY OF CHANGES
#             Date(yyyy-mm-dd)    Author              Comments
------------------- ------------------ ------------------------------------------------------------
1            
***************************************************************************************************/

CREATE     PROCEDURE [dbo].[usp_ibmi_cd_billing_silver]
AS

SET NOCOUNT ON

DELETE FROM silver.ibmi_cd_billing

INSERT INTO silver.ibmi_cd_billing
SELECT
	  TRIM(a.BIODR)																			AS cd_billing_load_number
	, TRIM(a.BISEQ)																			AS cd_billing_sequence_number
	, a.BICNT																				AS cd_billing_record_number
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
	, CAST(0 AS int) AS is_deleted
FROM data_central_lh.dbo.ibmi_cd_billing_bronze a