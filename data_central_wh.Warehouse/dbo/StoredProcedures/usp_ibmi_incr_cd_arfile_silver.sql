CREATE   PROCEDURE [dbo].[usp_ibmi_incr_cd_arfile_silver]
AS
BEGIN
    SET NOCOUNT ON;

    /* ------------------------------------------------------------
       Step 0: Prep + dedupe bronze on the composite key
       ------------------------------------------------------------ */
    IF OBJECT_ID('tempdb..#CD_AR_Deduped','U') IS NOT NULL DROP TABLE #CD_AR_Deduped;

    WITH Prep AS (
        SELECT
            a.ARRECC,
            TRIM(a.ARCUST) AS ARCUST_t,
            TRIM(a.ARINVN) AS ARINVN_t,
            TRIM(a.[ARCUS#]) AS ARCUSNUM_t,
            TRIM(a.ARTYPE) AS ARTYPE_t,
            a.[ARREC#]     AS ARRECNUM_n,
            CASE
                WHEN TRIM(a.ARINVD) IN ('','000000') THEN NULL
                ELSE CONVERT(date, RIGHT(a.ARINVD,2)+LEFT(a.ARINVD,2)+SUBSTRING(a.ARINVD,3,2))
            END AS ARINVD_d,
            TRIM(a.ARORD)  AS ARORD_t,
            CASE
                WHEN TRIM(a.ARDPDT) IN ('','000000') THEN NULL
                ELSE CONVERT(date, RIGHT(a.ARDPDT,2)+LEFT(a.ARDPDT,2)+SUBSTRING(a.ARDPDT,3,2))
            END AS ARDPDT_d,
            TRIM(a.ARCORD) AS ARCORD_t,
            TRIM(a.ARBOMO) AS ARBOMO_t,
            TRIM(a.ARBOYR) AS ARBOYR_t,
            a.ARAMT,
            a.ARBFWD,
            CASE WHEN TRIM(a.ARDPRO) = 'Y' THEN 'TRUE' ELSE 'FALSE' END AS ARDPRO_b,
            CASE WHEN TRIM(a.ARWPRO) = 'Y' THEN 'TRUE' ELSE 'FALSE' END AS ARWPRO_b,
            CASE WHEN TRIM(a.ARMPRO) = 'Y' THEN 'TRUE' ELSE 'FALSE' END AS ARMPRO_b,
            CASE WHEN TRIM(a.ARNCUR) = 'Y' THEN 'TRUE' ELSE 'FALSE' END AS ARNCUR_b,
            TRIM(a.ARNAME) AS ARNAME_t,
            TRIM(a.ARSEQ)  AS ARSEQ_t,
            TRIM(a.[ARSTM#]) AS ARSTMNUM_t,
            CASE
                WHEN TRIM(a.ARDSPD) IN ('','000000') THEN NULL
                ELSE CONVERT(date, RIGHT(a.ARDSPD,2)+LEFT(a.ARDSPD,2)+SUBSTRING(a.ARDSPD,3,2))
            END AS ARDSPD_d,
            -- recency
            a.loadDate,
            a.recordNumber
        FROM data_central_lh.dbo.ibmi_incr_cd_arfile_bronze a
    )
    SELECT *
    INTO #CD_AR_Deduped
    FROM (
        SELECT p.*,
               ROW_NUMBER() OVER (
                   PARTITION BY p.ARCUST_t, p.ARINVN_t, p.ARTYPE_t, p.ARRECNUM_n, p.ARINVD_d, p.ARORD_t, p.ARSEQ_t
                   ORDER BY p.loadDate DESC, p.recordNumber DESC
               ) AS rn
        FROM Prep p
    ) x
    WHERE x.rn = 1;

    /* ------------------------------------------------------------
       Step 1: UPDATE matches
       ------------------------------------------------------------ */
    UPDATE T
       SET cd_arfile_record_code           = S.ARRECC,
           cd_arfile_customer_code         = S.ARCUST_t,
           cd_arfile_invoice_number        = S.ARINVN_t,
           cd_arfile_adj_batch_code        = S.ARCUSNUM_t,
           cd_arfile_record_type           = S.ARTYPE_t,
           cd_arfile_record_number         = S.ARRECNUM_n,
           cd_arfile_invoice_date          = S.ARINVD_d,
           cd_arfile_load_number           = S.ARORD_t,
           cd_arfile_deposit_date          = S.ARDPDT_d,
           cd_arfile_cust_order_number     = S.ARCORD_t,
           cd_arfile_book_month            = S.ARBOMO_t,
           cd_arfile_book_year             = S.ARBOYR_t,
           cd_arfile_amount                = S.ARAMT,
           cd_arfile_balance_forward       = S.ARBFWD,
           is_daily_pro_register           = S.ARDPRO_b,
           is_weekly_pro_register          = S.ARWPRO_b,
           is_monthly_pro_register         = S.ARMPRO_b,
           is_non_current                  = S.ARNCUR_b,
           cd_arfile_customer_name         = S.ARNAME_t,
           cd_arfile_sequence_code         = S.ARSEQ_t,
           cd_arfile_statement_number      = S.ARSTMNUM_t,
           cd_arfile_dispatch_date         = S.ARDSPD_d
    FROM silver.ibmi_cd_arfile T
    JOIN #CD_AR_Deduped S
      ON T.cd_arfile_customer_code  = S.ARCUST_t
     AND T.cd_arfile_invoice_number = S.ARINVN_t
     AND T.cd_arfile_record_type    = S.ARTYPE_t
     AND T.cd_arfile_record_number  = S.ARRECNUM_n
     AND (
            (T.cd_arfile_invoice_date IS NULL AND S.ARINVD_d IS NULL) OR
            (T.cd_arfile_invoice_date = S.ARINVD_d)
         )
     AND (
            (T.cd_arfile_load_number IS NULL AND S.ARORD_t IS NULL) OR
            (T.cd_arfile_load_number = S.ARORD_t)
         )
     AND T.cd_arfile_sequence_code  = S.ARSEQ_t;

    /* ------------------------------------------------------------
       Step 2: INSERT non-matches
       ------------------------------------------------------------ */
    INSERT INTO silver.ibmi_cd_arfile
    (
        cd_arfile_record_code,
        cd_arfile_customer_code,
        cd_arfile_invoice_number,
        cd_arfile_adj_batch_code,
        cd_arfile_record_type,
        cd_arfile_record_number,
        cd_arfile_invoice_date,
        cd_arfile_load_number,
        cd_arfile_deposit_date,
        cd_arfile_cust_order_number,
        cd_arfile_book_month,
        cd_arfile_book_year,
        cd_arfile_amount,
        cd_arfile_balance_forward,
        is_daily_pro_register,
        is_weekly_pro_register,
        is_monthly_pro_register,
        is_non_current,
        cd_arfile_customer_name,
        cd_arfile_sequence_code,
        cd_arfile_statement_number,
        cd_arfile_dispatch_date
    )
    SELECT
        S.ARRECC,
        S.ARCUST_t,
        S.ARINVN_t,
        S.ARCUSNUM_t,
        S.ARTYPE_t,
        S.ARRECNUM_n,
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
        S.ARSTMNUM_t,
        S.ARDSPD_d
    FROM #CD_AR_Deduped S
    WHERE NOT EXISTS (
        SELECT 1
        FROM silver.ibmi_cd_arfile T
        WHERE T.cd_arfile_customer_code  = S.ARCUST_t
          AND T.cd_arfile_invoice_number = S.ARINVN_t
          AND T.cd_arfile_record_type    = S.ARTYPE_t
          AND T.cd_arfile_record_number  = S.ARRECNUM_n
          AND (
                (T.cd_arfile_invoice_date IS NULL AND S.ARINVD_d IS NULL) OR
                (T.cd_arfile_invoice_date = S.ARINVD_d)
              )
          AND (
                (T.cd_arfile_load_number IS NULL AND S.ARORD_t IS NULL) OR
                (T.cd_arfile_load_number = S.ARORD_t)
              )
          AND T.cd_arfile_sequence_code  = S.ARSEQ_t
    );

    DROP TABLE #CD_AR_Deduped;
END;