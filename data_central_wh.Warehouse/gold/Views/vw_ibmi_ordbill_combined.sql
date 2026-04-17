-- Auto Generated (Do not modify) 49BDF29B2CE7B480958E724B32FDAC4A1EEA003D61C17DF61D1C58E3E5E9BD74
CREATE   VIEW [gold].[vw_ibmi_ordbill_combined] AS

SELECT
      i.[ordbill_ar_status_flag]
    , i.[ordbill_billed_amount_accessorial]
    , i.[ordbill_load_bill_amount]
    , i.[ordbill_load_total_amount]
    , i.[ordbill_load_book_month]
    , i.[ordbill_load_book_year]
    , i.[is_billing_flagged]
    , i.[ordbill_audit_initials]
    , i.[ordbill_tariff_code]
    , i.[ordbill_item_code]
    , i.[ordbill_line_code]
    , i.[ordbill_rate_code]
    , i.[ordbill_billed_amount_linehaul]
    , i.[ordbill_cost_record_flag]
    , i.[ordbill_total_amount_linehaul]
    , i.[ordbill_total_amount_accessorial]
    , i.[ordbill_load_fuel_surcharge_amount]
    , i.[ordbill_total_fuel_surcharge_amount]
    , i.[ordbill_audit_date]
    , i.[ordbill_sequence_number]
    , i.[ordbill_rate_clerk_initials]
    , i.[ordbill_invoice_number]
    , i.[ordbill_void_invoice_number]
    , i.[ordbill_billed_date]
    , i.[ordbill_print_date]
    , i.[ordbill_load_number]
FROM [data_central_wh].[gold].[vw_ibmi_incr_ordbill_all] i
INNER JOIN [data_central_wh].[gold].[vw_ibmi_order_combined] o
    ON i.ordbill_load_number = o.order_load_number
WHERE o.order_status_code <> 'C'

UNION ALL

SELECT
      b.[ordbill_ar_status_flag]
    , b.[ordbill_billed_amount_accessorial]
    , b.[ordbill_load_bill_amount]
    , b.[ordbill_load_total_amount]
    , b.[ordbill_load_book_month]
    , b.[ordbill_load_book_year]
    , b.[is_billing_flagged]
    , b.[ordbill_audit_initials]
    , b.[ordbill_tariff_code]
    , b.[ordbill_item_code]
    , b.[ordbill_line_code]
    , b.[ordbill_rate_code]
    , b.[ordbill_billed_amount_linehaul]
    , b.[ordbill_cost_record_flag]
    , b.[ordbill_total_amount_linehaul]
    , b.[ordbill_total_amount_accessorial]
    , b.[ordbill_load_fuel_surcharge_amount]
    , b.[ordbill_total_fuel_surcharge_amount]
    , b.[ordbill_audit_date]
    , b.[ordbill_sequence_number]
    , b.[ordbill_rate_clerk_initials]
    , b.[ordbill_invoice_number]
    , b.[ordbill_void_invoice_number]
    , b.[ordbill_billed_date]
    , b.[ordbill_print_date]
    , b.[ordbill_load_number]
FROM [data_central_wh].[gold].[vw_ibmi_ordbill_all] b
INNER JOIN [data_central_wh].[gold].[vw_ibmi_order_combined] o
    ON b.ordbill_load_number = o.order_load_number
WHERE o.order_status_code <> 'C'
  AND NOT EXISTS (
        SELECT 1
        FROM [data_central_wh].[gold].[vw_ibmi_incr_ordbill_all] i
        WHERE i.ordbill_load_number     = b.ordbill_load_number
          AND i.ordbill_sequence_number = b.ordbill_sequence_number
  );