-- Auto Generated (Do not modify) D0F1603DDB5A1B8FF97DFDB9732240591BE43A69D525197E4305EF9B9714FF74
CREATE   VIEW gold.vw_ibmi_arfile_combined AS
SELECT
    [arfile_record_code]       AS record_code,
    [arfile_customer_code]     AS customer_code,
    [arfile_invoice_number]    AS invoice_number,
    [arfile_adj_batch_code]    AS adj_batch_code,
    [arfile_record_type]       AS record_type,
    [arfile_record_number]     AS record_number,
    [arfile_customer_name]     AS customer_name,
    [arfile_sequence_code]     AS sequence_code,
    [arfile_statement_number]  AS statement_number,
    [arfile_dispatch_date]     AS dispatch_date,
    [arfile_amount]            AS amount,
    [arfile_balance_forward]   AS balance_forward,
    [is_daily_pro_register],
    [is_weekly_pro_register],
    [is_monthly_pro_register],
    [is_non_current],
    [arfile_invoice_date]      AS invoice_date,
    [arfile_load_number]       AS load_number,
    [arfile_deposit_date]      AS deposit_date,
    [arfile_cust_order_number] AS cust_order_number,
    [arfile_book_month]        AS book_month,
    [arfile_book_year]         AS book_year
FROM [data_central_wh].[silver].[ibmi_arfile]

UNION ALL
SELECT
    [cd_arfile_record_code]    AS record_code,
    [cd_arfile_customer_code]  AS customer_code,
    [cd_arfile_invoice_number] AS invoice_number,
    [cd_arfile_adj_batch_code] AS adj_batch_code,
    [cd_arfile_record_type]    AS record_type,
    [cd_arfile_record_number]  AS record_number,
    [cd_arfile_customer_name]  AS customer_name,
    [cd_arfile_sequence_code]  AS sequence_code,
    [cd_arfile_statement_number] AS statement_number,
    [cd_arfile_dispatch_date]  AS dispatch_date,
    [cd_arfile_amount]         AS amount,
    [cd_arfile_balance_forward] AS balance_forward,
    [is_daily_pro_register],
    [is_weekly_pro_register],
    [is_monthly_pro_register],
    [is_non_current],
    [cd_arfile_invoice_date]   AS invoice_date,
    [cd_arfile_load_number]    AS load_number,
    [cd_arfile_deposit_date]   AS deposit_date,
    [cd_arfile_cust_order_number] AS cust_order_number,
    [cd_arfile_book_month]     AS book_month,
    [cd_arfile_book_year]      AS book_year
FROM [data_central_wh].[silver].[ibmi_cd_arfile]

UNION ALL
SELECT
    [tlb_arfile_record_code]   AS record_code,
    [tlb_arfile_customer_code] AS customer_code,
    [tlb_arfile_invoice_number] AS invoice_number,
    [tlb_arfile_adj_batch_code] AS adj_batch_code,
    [tlb_arfile_record_type]   AS record_type,
    [tlb_arfile_record_number] AS record_number,
    [tlb_arfile_customer_name] AS customer_name,
    [tlb_arfile_sequence_code] AS sequence_code,
    [tlb_arfile_statement_number] AS statement_number,
    [tlb_arfile_dispatch_date] AS dispatch_date,
    [tlb_arfile_amount]        AS amount,
    [tlb_arfile_balance_forward] AS balance_forward,
    [is_daily_pro_register],
    [is_weekly_pro_register],
    [is_monthly_pro_register],
    [is_non_current],
    [tlb_arfile_invoice_date]  AS invoice_date,
    [tlb_arfile_load_number]   AS load_number,
    [tlb_arfile_deposit_date]  AS deposit_date,
    [tlb_arfile_cust_order_number] AS cust_order_number,
    [tlb_arfile_book_month]    AS book_month,
    [tlb_arfile_book_year]     AS book_year
FROM [data_central_wh].[silver].[ibmi_tlb_arfile];