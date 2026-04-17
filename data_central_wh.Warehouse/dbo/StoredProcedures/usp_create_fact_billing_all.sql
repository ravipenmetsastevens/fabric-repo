/***************************************************************************************************
Procedure:          dbo.usp_create_fact_billing_all
Create Date:        2024-06-21
Author:             Tom Wolfenden
Description:        Combine all billing data into a single fact table
Called by:            fabric
					Pipeline: pl_ibmi_billing
Affected table(s):  gold.fact_billing_all
Usage:              EXEC dbo.usp_create_fact_billing_all

****************************************************************************************************
SUMMARY OF CHANGES
#             Date(yyyy-mm-dd)    Author              Comments
------------------- ------------------ ------------------------------------------------------------
1            
***************************************************************************************************/

CREATE PROCEDURE [dbo].[usp_create_fact_billing_all]
AS

SET NOCOUNT ON
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED

DELETE FROM gold.fact_billing_all

INSERT INTO gold.fact_billing_all
SELECT
	   [cd_billing_load_number]					AS billing_load_number
      ,[cd_billing_sequence_number]				AS billing_sequence_number
      ,[cd_billing_record_number]				AS billing_record_number
      ,[is_deleted]
      ,[cd_billing_commodity_code]				AS billing_commodity_code
      ,[cd_billing_commodity_description]		AS billing_commodity_description
      ,[cd_billing_piece_count]					AS billing_piece_count
      ,[cd_billing_actual_quantity_count]		AS billing_actual_quantity_count
      ,[cd_billing_billed_quantity_count]		AS billing_billed_quantity_count
      ,[cd_billing_billed_rate]					AS billing_billed_rate
      ,[cd_billing_billed_amount]				AS billing_billed_amount
      ,[cd_billing_method_code]					AS billing_method_code
      ,[cd_billing_error_code]					AS billing_error_code
      ,[cd_billing_gl_account_number]			AS billing_gl_account_number
FROM silver.ibmi_cd_billing

UNION

SELECT
	   [tlb_billing_load_number]				AS billing_load_number
      ,[tlb_billing_sequence_number]			AS billing_sequence_number
      ,[tlb_billing_record_number]				AS billing_record_number
      ,[is_deleted]
      ,[tlb_billing_commodity_code]				AS billing_commodity_code
      ,[tlb_billing_commodity_description]		AS billing_commodity_description
      ,[tlb_billing_piece_count]				AS billing_piece_count
      ,[tlb_billing_actual_quantity_count]		AS billing_actual_quantity_count
      ,[tlb_billing_billed_quantity_count]		AS billing_billed_quantity_count
      ,[tlb_billing_billed_rate]				AS billing_billed_rate
      ,[tlb_billing_billed_amount]				AS billing_billed_amount
      ,[tlb_billing_method_code]				AS billing_method_code
      ,[tlb_billing_error_code]					AS billing_error_code
      ,[tlb_billing_gl_account_number]			AS billing_gl_account_number
FROM silver.ibmi_tlb_billing a
WHERE NOT EXISTS
(
SELECT DISTINCT b.cd_billing_load_number
FROM silver.ibmi_cd_billing b
WHERE b.cd_billing_load_number = a.tlb_billing_load_number
)

UNION

SELECT 
	   [billing_load_number]					AS billing_load_number
      ,[billing_sequence_number]				AS billing_sequence_number
      ,[billing_record_number]					AS billing_record_number
      ,[is_deleted]
      ,[billing_commodity_code]					AS billing_commodity_code
      ,[billing_commodity_description]			AS billing_commodity_description
      ,[billing_piece_count]					AS billing_piece_count
      ,[billing_actual_quantity_count]			AS billing_actual_quantity_count
      ,[billing_billed_quantity_count]			AS billing_billed_quantity_count
      ,[billing_billed_rate]					AS billing_billed_rate
      ,[billing_billed_amount]					AS billing_billed_amount
      ,[billing_method_code]					AS billing_method_code
      ,[billing_error_code]						AS billing_error_code
      ,[billing_gl_account_number]				AS billing_gl_account_number
FROM silver.ibmi_billing a
WHERE NOT EXISTS
(
SELECT DISTINCT b.cd_billing_load_number
FROM silver.ibmi_cd_billing b
WHERE b.cd_billing_load_number = a.billing_load_number
)
AND NOT EXISTS
(
SELECT DISTINCT  c.tlb_billing_load_number
FROM silver.ibmi_tlb_billing c
WHERE c.tlb_billing_load_number = a.billing_load_number
)