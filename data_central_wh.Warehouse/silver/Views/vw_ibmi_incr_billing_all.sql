-- Auto Generated (Do not modify) 697A62D22119CE28E422F742E5AEA2EA93BA38A68E8809AD9E0EB1BB89CF5AC4
CREATE           VIEW silver.vw_ibmi_incr_billing_all
AS

SELECT 
	   [cd_billing_load_number]           AS billing_load_number
      ,[cd_billing_sequence_number]       AS billing_sequence_number
      ,[cd_billing_record_number]         AS billing_record_number
      ,[is_deleted]
      ,[cd_billing_commodity_code]        AS billing_commodity_code
      ,[cd_billing_commodity_description] AS billing_commodity_description
      ,[cd_billing_piece_count]           AS billing_piece_count
      ,[cd_billing_actual_quantity_count] AS billing_actual_quantity_count
      ,[cd_billing_billed_quantity_count] AS billing_billed_quantity_count
      ,[cd_billing_billed_rate]           AS billing_billed_rate
      ,[cd_billing_billed_amount]         AS billing_billed_amount
      ,[cd_billing_method_code]           AS billing_method_code
      ,[cd_billing_error_code]            AS billing_error_code
      ,[cd_billing_gl_account_number]     AS billing_gl_account_number
FROM silver.ibmi_incr_cd_billing_new

UNION ALL

SELECT
	   [tlb_billing_load_number]
      ,[tlb_billing_sequence_number]
      ,[tlb_billing_record_number]
      ,[is_deleted]
      ,[tlb_billing_commodity_code]
      ,[tlb_billing_commodity_description]
      ,[tlb_billing_piece_count]
      ,[tlb_billing_actual_quantity_count]
      ,[tlb_billing_billed_quantity_count]
      ,[tlb_billing_billed_rate]
      ,[tlb_billing_billed_amount]
      ,[tlb_billing_method_code]
      ,[tlb_billing_error_code]
      ,[tlb_billing_gl_account_number]
FROM silver.ibmi_incr_tlb_billing_new
WHERE tlb_billing_load_number NOT IN (SELECT cd_billing_load_number FROM [silver].[ibmi_incr_cd_billing_new])

UNION ALL

SELECT
	   [billing_load_number]
      ,[billing_sequence_number]
      ,[billing_record_number]
      ,[is_deleted]
      ,[billing_commodity_code]
      ,[billing_commodity_description]
      ,[billing_piece_count]
      ,[billing_actual_quantity_count]
      ,[billing_billed_quantity_count]
      ,[billing_billed_rate]
      ,[billing_billed_amount]
      ,[billing_method_code]
      ,[billing_error_code]
      ,[billing_gl_account_number]
FROM silver.ibmi_incr_billing_new
WHERE billing_load_number NOT IN (SELECT cd_billing_load_number FROM [silver].[ibmi_incr_cd_billing_new])
  AND billing_load_number NOT IN (SELECT tlb_billing_load_number FROM [silver].[ibmi_incr_tlb_billing_new])
;