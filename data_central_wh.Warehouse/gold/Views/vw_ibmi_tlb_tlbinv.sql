-- Auto Generated (Do not modify) 9C55D2A8D868B1131389AF8BDEE721FA375F5F01D8AA42589FFEA10005EE4A53
CREATE   VIEW [gold].[vw_ibmi_tlb_tlbinv] AS
SELECT
    -- Incremental first (priority)
    S.tlb_tlbinv_status_code        AS status_code,
    S.tlb_tlbinv_carrier_code       AS carrier_code,
    S.tlb_tlbinv_division_code      AS division_code,
    S.tlb_tlbinv_load_number        AS load_number,
    S.tlb_tlbinv_dispatch           AS dispatch,
    S.tlb_tlbinv_original_load_number AS original_load_number,
    S.tlb_tlbinv_original_dispatch  AS original_dispatch,
    S.tlb_tlbinv_carrier_invoice_number AS carrier_invoice_number,
    S.tlb_tlbinv_invoice_date       AS invoice_date,
    S.tlb_tlbinv_due_date           AS due_date,
    S.tlb_tlbinv_to_pay_date        AS to_pay_date,
    S.tlb_tlbinv_invoice_amount     AS invoice_amount,
    S.tlb_tlbinv_reference          AS reference,
    S.tlb_tlbinv_fund_code          AS fund_code,
    S.tlb_tlbinv_check_number       AS check_number,
    S.tlb_tlbinv_check_date         AS check_date,
    S.tlb_tlbinv_check_amount       AS check_amount,
    S.is_expensed                   AS is_expensed,
    S.is_voided                     AS is_voided,
    S.tlb_tlbinv_expensed_month     AS expensed_month,
    S.tlb_tlbinv_expensed_year      AS expensed_year,
    S.tlb_tlbinv_voided_month       AS voided_month,
    S.tlb_tlbinv_voided_year        AS voided_year,
    S.tlb_tlbinv_paid_month         AS paid_month,
    S.tlb_tlbinv_paid_year          AS paid_year,
    S.tlb_tlbinv_create_user_code   AS create_user_code,
    S.tlb_tlbinv_create_date        AS create_date,
    S.tlb_tlbinv_maint_user_code    AS maint_user_code,
    S.tlb_tlbinv_maint_date         AS maint_date
FROM [data_central_wh].[silver].[ibmi_incr_tlb_tlbinv] AS S

UNION ALL

SELECT
    B.tlb_tlbinv_status_code        AS status_code,
    B.tlb_tlbinv_carrier_code       AS carrier_code,
    B.tlb_tlbinv_division_code      AS division_code,
    B.tlb_tlbinv_load_number        AS load_number,
    B.tlb_tlbinv_dispatch           AS dispatch,
    B.tlb_tlbinv_original_load_number AS original_load_number,
    B.tlb_tlbinv_original_dispatch  AS original_dispatch,
    B.tlb_tlbinv_carrier_invoice_number AS carrier_invoice_number,
    B.tlb_tlbinv_invoice_date       AS invoice_date,
    B.tlb_tlbinv_due_date           AS due_date,
    B.tlb_tlbinv_to_pay_date        AS to_pay_date,
    B.tlb_tlbinv_invoice_amount     AS invoice_amount,
    B.tlb_tlbinv_reference          AS reference,
    B.tlb_tlbinv_fund_code          AS fund_code,
    B.tlb_tlbinv_check_number       AS check_number,
    B.tlb_tlbinv_check_date         AS check_date,
    B.tlb_tlbinv_check_amount       AS check_amount,
    B.is_expensed                   AS is_expensed,
    B.is_voided                     AS is_voided,
    B.tlb_tlbinv_expensed_month     AS expensed_month,
    B.tlb_tlbinv_expensed_year      AS expensed_year,
    B.tlb_tlbinv_voided_month       AS voided_month,
    B.tlb_tlbinv_voided_year        AS voided_year,
    B.tlb_tlbinv_paid_month         AS paid_month,
    B.tlb_tlbinv_paid_year          AS paid_year,
    B.tlb_tlbinv_create_user_code   AS create_user_code,
    B.tlb_tlbinv_create_date        AS create_date,
    B.tlb_tlbinv_maint_user_code    AS maint_user_code,
    B.tlb_tlbinv_maint_date         AS maint_date
FROM [data_central_wh].[silver].[ibmi_tlb_tlbinv] AS B
WHERE NOT EXISTS (
    SELECT 1
    FROM [data_central_wh].[silver].[ibmi_incr_tlb_tlbinv] AS I
    WHERE I.tlb_tlbinv_load_number = B.tlb_tlbinv_load_number
      AND I.tlb_tlbinv_dispatch    = B.tlb_tlbinv_dispatch
);