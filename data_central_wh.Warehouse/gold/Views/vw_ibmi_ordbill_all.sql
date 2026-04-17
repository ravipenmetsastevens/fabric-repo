-- Auto Generated (Do not modify) 7600382848696D19CAD3B7EFD0804D9E4D9C2087E4261770A48E239EA1143728
CREATE         VIEW gold.vw_ibmi_ordbill_all
AS

/* 1) CD ORDBILL (preferred) */
SELECT
     cd.cd_ordbill_load_number                AS ordbill_load_number
   , cd.cd_ordbill_sequence_number            AS ordbill_sequence_number
   , cd.cd_ordbill_rate_clerk_initials        AS ordbill_rate_clerk_initials
   , cd.cd_ordbill_invoice_number             AS ordbill_invoice_number
   , cd.cd_ordbill_void_invoice_number        AS ordbill_void_invoice_number
   , cd.cd_ordbill_billed_date                AS ordbill_billed_date
   , cd.cd_ordbill_print_date                 AS ordbill_print_date
   , cd.cd_ordbill_cost_record_flag           AS ordbill_cost_record_flag
   , cd.cd_ordbill_total_amount_linehaul      AS ordbill_total_amount_linehaul
   , cd.cd_ordbill_total_amount_accessorial   AS ordbill_total_amount_accessorial
   , cd.cd_ordbill_load_fuel_surcharge_amount AS ordbill_load_fuel_surcharge_amount
   , cd.cd_ordbill_total_fuel_surcharge_amount AS ordbill_total_fuel_surcharge_amount
   , cd.cd_ordbill_audit_date                 AS ordbill_audit_date
   , cd.cd_ordbill_audit_initials             AS ordbill_audit_initials
   , cd.cd_ordbill_tariff_code                AS ordbill_tariff_code
   , cd.cd_ordbill_item_code                  AS ordbill_item_code
   , cd.cd_ordbill_line_code                  AS ordbill_line_code
   , cd.cd_ordbill_rate_code                  AS ordbill_rate_code
   , cd.cd_ordbill_billed_amount_linehaul     AS ordbill_billed_amount_linehaul
   , cd.cd_ordbill_billed_amount_accessorial  AS ordbill_billed_amount_accessorial
   , cd.cd_ordbill_load_bill_amount           AS ordbill_load_bill_amount
   , cd.cd_ordbill_load_total_amount          AS ordbill_load_total_amount
   , cd.cd_ordbill_load_book_month            AS ordbill_load_book_month
   , cd.cd_ordbill_load_book_year             AS ordbill_load_book_year
   , cd.is_billing_flagged                    AS is_billing_flagged
   , cd.cd_ordbill_ar_status_flag             AS ordbill_ar_status_flag
FROM silver.ibmi_cd_ordbill_v2 cd

UNION ALL

/* 2) TLB ORDBILL — only if no CD record exists for same keys */
SELECT
     tlb.tlb_ordbill_load_number
   , tlb.tlb_ordbill_sequence_number
   , tlb.tlb_ordbill_rate_clerk_initials
   , tlb.tlb_ordbill_invoice_number
   , tlb.tlb_ordbill_void_invoice_number
   , tlb.tlb_ordbill_billed_date
   , tlb.tlb_ordbill_print_date
   , tlb.tlb_ordbill_cost_record_flag
   , tlb.tlb_ordbill_total_amount_linehaul
   , tlb.tlb_ordbill_total_amount_accessorial
   , tlb.tlb_ordbill_load_fuel_surcharge_amount
   , tlb.tlb_ordbill_total_fuel_surcharge_amount
   , tlb.tlb_ordbill_audit_date
   , tlb.tlb_ordbill_audit_initials
   , tlb.tlb_ordbill_tariff_code
   , tlb.tlb_ordbill_item_code
   , tlb.tlb_ordbill_line_code
   , tlb.tlb_ordbill_rate_code
   , tlb.tlb_ordbill_billed_amount_linehaul
   , tlb.tlb_ordbill_billed_amount_accessorial
   , tlb.tlb_ordbill_load_bill_amount
   , tlb.tlb_ordbill_load_total_amount
   , tlb.tlb_ordbill_load_book_month
   , tlb.tlb_ordbill_load_book_year
   , tlb.is_billing_flagged
   , tlb.tlb_ordbill_ar_status_flag
FROM silver.ibmi_tlb_ordbill tlb
WHERE NOT EXISTS (
    SELECT 1
    FROM silver.ibmi_cd_ordbill_v2 cd
    WHERE cd.cd_ordbill_load_number     = tlb.tlb_ordbill_load_number
      AND cd.cd_ordbill_sequence_number = tlb.tlb_ordbill_sequence_number
)

UNION ALL

/* 3) BASE ORDBILL — only if no CD or TLB record exists for same keys */
SELECT
     b.ordbill_load_number
   , b.ordbill_sequence_number
   , b.ordbill_rate_clerk_initials
   , b.ordbill_invoice_number
   , b.ordbill_void_invoice_number
   , b.ordbill_billed_date
   , b.ordbill_print_date
   , b.ordbill_cost_record_flag
   , b.ordbill_total_amount_linehaul
   , b.ordbill_total_amount_accessorial
   , b.ordbill_load_fuel_surcharge_amount
   , b.ordbill_total_fuel_surcharge_amount
   , b.ordbill_audit_date
   , b.ordbill_audit_initials
   , b.ordbill_tariff_code
   , b.ordbill_item_code
   , b.ordbill_line_code
   , b.ordbill_rate_code
   , b.ordbill_billed_amount_linehaul
   , b.ordbill_billed_amount_accessorial
   , b.ordbill_load_bill_amount
   , b.ordbill_load_total_amount
   , b.ordbill_load_book_month
   , b.ordbill_load_book_year
   , b.is_billing_flagged
   , b.ordbill_ar_status_flag
FROM silver.ibmi_ordbill b
WHERE NOT EXISTS (
    SELECT 1
    FROM silver.ibmi_cd_ordbill_v2 cd
    WHERE cd.cd_ordbill_load_number     = b.ordbill_load_number
      AND cd.cd_ordbill_sequence_number = b.ordbill_sequence_number
)
AND NOT EXISTS (
    SELECT 1
    FROM silver.ibmi_tlb_ordbill tlb
    WHERE tlb.tlb_ordbill_load_number     = b.ordbill_load_number
      AND tlb.tlb_ordbill_sequence_number = b.ordbill_sequence_number
);