-- Auto Generated (Do not modify) E774A70FDC1135A2DDACA48E08CA4DD29F41EB151C8AA508C158D897AF4863EB
CREATE   VIEW gold.vw_ibmi_ar_extension_combined
AS

-- =========================
-- MMC
-- =========================
SELECT
    [ar_ext_create_date]                    AS create_date,
    [ar_ext_create_time]                    AS create_time,
    [ar_ext_customer_code]                  AS customer_code,
    [ar_ext_invoice_number]                 AS invoice_number,
    [ar_ext_load_number]                    AS load_number,
    [ar_ext_sequence_code]                  AS sequence_code,
    [ar_ext_ar_code]                        AS ar_code,
    [ar_ext_record_type_code]               AS record_type_code,
    [ar_ext_record_number]                  AS record_number,
    [ar_ext_invoice_amount]                 AS invoice_amount,
    [ar_ext_record_code]                    AS record_code,
    [ar_ext_invoice_date]                   AS invoice_date,
    [ar_ext_deposit_or_adjustment_date]     AS deposit_or_adjustment_date,
    [ar_ext_bol]                            AS bol,
    [ar_ext_book_month]                     AS book_month,
    [ar_ext_book_year]                      AS book_year,
    [ar_ext_balance_forward_amount]         AS balance_forward_amount,
    [ar_ext_customer_name]                  AS customer_name,
    [ar_ext_statement_number]               AS statement_number,
    [ar_ext_dispatch_date]                  AS dispatch_date,
    [ar_ext_create_user_code]               AS create_user_code,
    [ar_ext_create_program_code]            AS create_program_code,
    [ar_ext_last_change_date]               AS last_change_date,
    [ar_ext_last_change_time]               AS last_change_time,
    [ar_ext_last_change_user_code]          AS last_change_user_code,
    [ar_ext_last_change_program_code]       AS last_change_program_code,
    [ar_ext_delete_date]                    AS delete_date,
    [ar_ext_delete_time]                    AS delete_time,
    [ar_ext_delete_user_code]               AS delete_user_code,
    [ar_ext_delete_program_code]            AS delete_program_code
FROM [data_central_wh].[silver].[ibmi_ar_extension]

UNION ALL

-- =========================
-- CD
-- =========================
SELECT
    [cd_ar_ext_create_date]                 AS create_date,
    [cd_ar_ext_create_time]                 AS create_time,
    [cd_ar_ext_customer_code]               AS customer_code,
    [cd_ar_ext_invoice_number]              AS invoice_number,
    [cd_ar_ext_load_number]                 AS load_number,
    [cd_ar_ext_sequence_code]               AS sequence_code,
    [cd_ar_ext_ar_code]                     AS ar_code,
    [cd_ar_ext_record_type_code]            AS record_type_code,
    [cd_ar_ext_record_number]               AS record_number,
    [cd_ar_ext_invoice_amount]              AS invoice_amount,
    [cd_ar_ext_record_code]                 AS record_code,
    [cd_ar_ext_invoice_date]                AS invoice_date,
    [cd_ar_ext_deposit_or_adjustment_date]  AS deposit_or_adjustment_date,
    [cd_ar_ext_bol]                         AS bol,
    [cd_ar_ext_book_month]                  AS book_month,
    [cd_ar_ext_book_year]                   AS book_year,
    [cd_ar_ext_balance_forward_amount]      AS balance_forward_amount,
    [cd_ar_ext_customer_name]               AS customer_name,
    [cd_ar_ext_statement_number]            AS statement_number,
    [cd_ar_ext_dispatch_date]               AS dispatch_date,
    [cd_ar_ext_create_user_code]            AS create_user_code,
    [cd_ar_ext_create_program_code]         AS create_program_code,
    [cd_ar_ext_last_change_date]            AS last_change_date,
    [cd_ar_ext_last_change_time]            AS last_change_time,
    [cd_ar_ext_last_change_user_code]       AS last_change_user_code,
    [cd_ar_ext_last_change_program_code]    AS last_change_program_code,
    [cd_ar_ext_delete_date]                 AS delete_date,
    [cd_ar_ext_delete_time]                 AS delete_time,
    [cd_ar_ext_delete_user_code]            AS delete_user_code,
    [cd_ar_ext_delete_program_code]         AS delete_program_code
FROM [data_central_wh].[silver].[ibmi_cd_ar_extension]

UNION ALL

-- =========================
-- TLB
-- =========================
SELECT
    [tlb_ar_ext_create_date]                AS create_date,
    [tlb_ar_ext_create_time]                AS create_time,
    [tlb_ar_ext_customer_code]              AS customer_code,
    [tlb_ar_ext_invoice_number]             AS invoice_number,
    [tlb_ar_ext_load_number]                AS load_number,
    [tlb_ar_ext_sequence_code]              AS sequence_code,
    [tlb_ar_ext_ar_code]                    AS ar_code,
    [tlb_ar_ext_record_type_code]           AS record_type_code,
    [tlb_ar_ext_record_number]              AS record_number,
    [tlb_ar_ext_invoice_amount]             AS invoice_amount,
    [tlb_ar_ext_record_code]                AS record_code,
    [tlb_ar_ext_invoice_date]               AS invoice_date,
    [tlb_ar_ext_deposit_or_adjustment_date] AS deposit_or_adjustment_date,
    [tlb_ar_ext_bol]                        AS bol,
    [tlb_ar_ext_book_month]                 AS book_month,
    [tlb_ar_ext_book_year]                  AS book_year,
    [tlb_ar_ext_balance_forward_amount]     AS balance_forward_amount,
    [tlb_ar_ext_customer_name]              AS customer_name,
    [tlb_ar_ext_statement_number]           AS statement_number,
    [tlb_ar_ext_dispatch_date]              AS dispatch_date,
    [tlb_ar_ext_create_user_code]           AS create_user_code,
    [tlb_ar_ext_create_program_code]        AS create_program_code,
    [tlb_ar_ext_last_change_date]           AS last_change_date,
    [tlb_ar_ext_last_change_time]           AS last_change_time,
    [tlb_ar_ext_last_change_user_code]      AS last_change_user_code,
    [tlb_ar_ext_last_change_program_code]   AS last_change_program_code,
    [tlb_ar_ext_delete_date]                AS delete_date,
    [tlb_ar_ext_delete_time]                AS delete_time,
    [tlb_ar_ext_delete_user_code]           AS delete_user_code,
    [tlb_ar_ext_delete_program_code]        AS delete_program_code
FROM [data_central_wh].[silver].[ibmi_tlb_ar_extension];