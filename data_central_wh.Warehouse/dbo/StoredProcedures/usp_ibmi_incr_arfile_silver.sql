CREATE   PROCEDURE [dbo].[usp_ibmi_incr_arfile_silver]
AS
BEGIN
    SET NOCOUNT ON;

    /* ------------------------------------------------------------
       Step 0: Prepare & dedupe bronze on the natural key
       Notes:
         - Dates in bronze are YYMMDD (char/num). We normalize to DATE.
         - If bronze lacks loadDate/recordNumber, replace ORDER BY.
       ------------------------------------------------------------ */
    IF OBJECT_ID('tempdb..#AR_Deduped','U') IS NOT NULL DROP TABLE #AR_Deduped;

    WITH Prep AS (
        SELECT
            a.ARRECC,
            TRIM(a.ARCUST)   AS ARCUST_t,
            TRIM(a.ARINVN)   AS ARINVN_t,
            TRIM(a.ARCUS#)   AS ARCUS#_t,
            TRIM(a.ARTYPE)   AS ARTYPE_t,
            a.ARREC#         AS ARREC#_n,
            CASE
                WHEN TRIM(a.ARINVD) IN ('','000000') THEN NULL
                ELSE CONVERT(date,
                        RIGHT(a.ARINVD,2) + LEFT(a.ARINVD,2) + SUBSTRING(a.ARINVD,3,2)  -- ddMMyy -> DATE (assumes 20yy)
                     )
            END               AS ARINVD_d,
            TRIM(a.ARORD)    AS ARORD_t,
            CASE
                WHEN TRIM(a.ARDPDT) IN ('','000000') THEN NULL
                ELSE CONVERT(date,
                        RIGHT(a.ARDPDT,2) + LEFT(a.ARDPDT,2) + SUBSTRING(a.ARDPDT,3,2)
                     )
            END               AS ARDPDT_d,
            TRIM(a.ARCORD)   AS ARCORD_t,
            TRIM(a.ARBOMO)   AS ARBOMO_t,
            TRIM(a.ARBOYR)   AS ARBOYR_t,
            a.ARAMT,
            a.ARBFWD,
            CASE WHEN TRIM(a.ARDPRO) = 'Y' THEN 'TRUE' ELSE 'FALSE' END AS ARDPRO_b,
            CASE WHEN TRIM(a.ARWPRO) = 'Y' THEN 'TRUE' ELSE 'FALSE' END AS ARWPRO_b,
            CASE WHEN TRIM(a.ARMPRO) = 'Y' THEN 'TRUE' ELSE 'FALSE' END AS ARMPRO_b,
            CASE WHEN TRIM(a.ARNCUR) = 'Y' THEN 'TRUE' ELSE 'FALSE' END AS ARNCUR_b,
            TRIM(a.ARNAME)   AS ARNAME_t,
            TRIM(a.ARSEQ)    AS ARSEQ_t,
            TRIM(a.ARSTM#)   AS ARSTM#_t,
            CASE
                WHEN TRIM(a.ARDSPD) IN ('','000000') THEN NULL
                ELSE CONVERT(date,
                        RIGHT(a.ARDSPD,2) + LEFT(a.ARDSPD,2) + SUBSTRING(a.ARDSPD,3,2)
                     )
            END               AS ARDSPD_d,
            -- recency cols:
            a.loadDate,
            a.recordNumber
        FROM data_central_lh.dbo.ibmi_incr_arfile_bronze a
    )
    SELECT *
    INTO #AR_Deduped
    FROM (
        SELECT p.*,
               ROW_NUMBER() OVER (
                 PARTITION BY p.ARCUST_t, p.ARINVN_t, p.ARTYPE_t, p.[ARREC#_n], p.ARINVD_d, p.ARORD_t, p.ARSEQ_t
                 ORDER BY p.loadDate DESC, p.recordNumber DESC
               ) AS rn
        FROM Prep p
    ) x
    WHERE x.rn = 1;

    /* ------------------------------------------------------------
       Step 1: UPDATE matches on composite key
       ------------------------------------------------------------ */
    UPDATE T
       SET arfile_record_code                 = S.ARRECC,
           arfile_customer_code               = S.ARCUST_t,
           arfile_invoice_number              = S.ARINVN_t,
           arfile_adj_batch_code              = S.[ARCUS#_t],
           arfile_record_type                 = S.ARTYPE_t,
           arfile_record_number               = S.[ARREC#_n],
           arfile_invoice_date                = S.ARINVD_d,
           arfile_load_number                 = S.ARORD_t,
           arfile_deposit_date                = S.ARDPDT_d,
           arfile_cust_order_number           = S.ARCORD_t,
           arfile_book_month                  = S.ARBOMO_t,
           arfile_book_year                   = S.ARBOYR_t,
           arfile_amount                      = S.ARAMT,
           arfile_balance_forward             = S.ARBFWD,
           is_daily_pro_register              = S.ARDPRO_b,
           is_weekly_pro_register             = S.ARWPRO_b,
           is_monthly_pro_register            = S.ARMPRO_b,
           is_non_current                     = S.ARNCUR_b,
           arfile_customer_name               = S.ARNAME_t,
           arfile_sequence_code               = S.ARSEQ_t,
           arfile_statement_number            = S.[ARSTM#_t],
           arfile_dispatch_date               = S.ARDSPD_d
    FROM silver.ibmi_arfile T
    JOIN #AR_Deduped S
      ON T.arfile_customer_code  = S.ARCUST_t
     AND T.arfile_invoice_number = S.ARINVN_t
     AND T.arfile_record_type    = S.ARTYPE_t
     AND T.arfile_record_number  = S.[ARREC#_n]
     AND (
            (T.arfile_invoice_date IS NULL AND S.ARINVD_d IS NULL) OR
            (T.arfile_invoice_date = S.ARINVD_d)
         )
     AND (
            (T.arfile_load_number IS NULL AND S.ARORD_t IS NULL) OR
            (T.arfile_load_number = S.ARORD_t)
         )
     AND T.arfile_sequence_code  = S.ARSEQ_t;

    /* ------------------------------------------------------------
       Step 2: INSERT non-matches
       ------------------------------------------------------------ */
    INSERT INTO silver.ibmi_arfile
    (
        arfile_record_code,
        arfile_customer_code,
        arfile_invoice_number,
        arfile_adj_batch_code,
        arfile_record_type,
        arfile_record_number,
        arfile_invoice_date,
        arfile_load_number,
        arfile_deposit_date,
        arfile_cust_order_number,
        arfile_book_month,
        arfile_book_year,
        arfile_amount,
        arfile_balance_forward,
        is_daily_pro_register,
        is_weekly_pro_register,
        is_monthly_pro_register,
        is_non_current,
        arfile_customer_name,
        arfile_sequence_code,
        arfile_statement_number,
        arfile_dispatch_date
    )
    SELECT
        S.ARRECC,
        S.ARCUST_t,
        S.ARINVN_t,
        S.[ARCUS#_t],
        S.ARTYPE_t,
        S.[ARREC#_n],
        S.ARINVD_d,
        S.ARORD_t,
        S.ARDPDT_d,
        S.ARCORD_t,
        S.ARBOMO_t,
        S.ARBOYR_t,
        S.ARAMT,
        S.ARBFWD,
        S.ARDPRO_b,
        S.ARWPRO_b,
        S.ARMPRO_b,
        S.ARNCUR_b,
        S.ARNAME_t,
        S.ARSEQ_t,
        S.[ARSTM#_t],
        S.ARDSPD_d
    FROM #AR_Deduped S
    WHERE NOT EXISTS (
        SELECT 1
        FROM silver.ibmi_arfile T
        WHERE T.arfile_customer_code  = S.ARCUST_t
          AND T.arfile_invoice_number = S.ARINVN_t
          AND T.arfile_record_type    = S.ARTYPE_t
          AND T.arfile_record_number  = S.[ARREC#_n]
          AND (
                (T.arfile_invoice_date IS NULL AND S.ARINVD_d IS NULL) OR
                (T.arfile_invoice_date = S.ARINVD_d)
              )
          AND (
                (T.arfile_load_number IS NULL AND S.ARORD_t IS NULL) OR
                (T.arfile_load_number = S.ARORD_t)
              )
          AND T.arfile_sequence_code  = S.ARSEQ_t
    );

    DROP TABLE #AR_Deduped;
END;