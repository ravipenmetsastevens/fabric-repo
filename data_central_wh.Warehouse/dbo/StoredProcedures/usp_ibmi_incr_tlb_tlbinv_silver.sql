CREATE   PROCEDURE [dbo].[usp_ibmi_incr_tlb_tlbinv_silver]
AS
BEGIN
    SET NOCOUNT ON;

    IF OBJECT_ID('tempdb..#TLB_Deduped','U') IS NOT NULL DROP TABLE #TLB_Deduped;

    WITH Prep AS (
        SELECT
            TRIM(TRY_CAST(a.TNSTAT AS VARCHAR(50))) AS TNSTAT_t,
            TRIM(TRY_CAST(a.TNCARR AS VARCHAR(50))) AS TNCARR_t,
            TRIM(TRY_CAST(a.TNDIV AS VARCHAR(50))) AS TNDIV_t,
            TRIM(TRY_CAST(a.TNORD AS VARCHAR(50))) AS TNORD_t,
            TRIM(TRY_CAST(a.TNDISP AS VARCHAR(50))) AS TNDISP_t,
            TRIM(TRY_CAST(a.TNOORD AS VARCHAR(50))) AS TNOORD_t,
            TRIM(TRY_CAST(a.TNODIS AS VARCHAR(50))) AS TNODIS_t,
            TRIM(TRY_CAST(a.TNINV AS VARCHAR(50))) AS TNINV_t,
            CASE WHEN TRIM(TRY_CAST(a.TNIDAT AS VARCHAR(50))) IN ('','000000') THEN NULL 
                 ELSE TRY_CONVERT(DATE, CONVERT(VARCHAR(8), CONVERT(INT, a.TNIDAT))) END AS TNIDAT_d,
            CASE WHEN TRIM(TRY_CAST(a.TNUDAT AS VARCHAR(50))) IN ('','000000') THEN NULL 
                 ELSE TRY_CONVERT(DATE, CONVERT(VARCHAR(8), CONVERT(INT, a.TNUDAT))) END AS TNUDAT_d,
            CASE WHEN TRIM(TRY_CAST(a.TNPDAT AS VARCHAR(50))) IN ('','000000') THEN NULL 
                 ELSE TRY_CONVERT(DATE, CONVERT(VARCHAR(8), CONVERT(INT, a.TNPDAT))) END AS TNPDAT_d,
            CONVERT(DECIMAL(18,2), a.TNIAMT) AS TNIAMT_n,
            TRIM(TRY_CAST(a.TNREF AS VARCHAR(50))) AS TNREF_t,
            TRIM(TRY_CAST(a.TNFC AS VARCHAR(50))) AS TNFC_t,
            a.TNCHK AS TNCHK_n,
            CASE WHEN TRIM(TRY_CAST(a.TNCDAT AS VARCHAR(50))) IN ('','000000') THEN NULL 
                 ELSE TRY_CONVERT(DATE, CONVERT(VARCHAR(8), CONVERT(INT, a.TNCDAT))) END AS TNCDAT_d,
            CONVERT(DECIMAL(18,2), a.TNCAMT) AS TNCAMT_n,
            CASE WHEN TRIM(TRY_CAST(a.TNEXPF AS VARCHAR(50))) = 'Y' THEN 'TRUE' ELSE 'FALSE' END AS TNEXPF_b,
            CASE WHEN TRIM(TRY_CAST(a.TNVOID AS VARCHAR(50))) = 'Y' THEN 'TRUE' ELSE 'FALSE' END AS TNVOID_b,
            TRIM(TRY_CAST(a.TNBKMO AS VARCHAR(50))) AS TNBKMO_t,
            TRIM(TRY_CAST(a.TNBKYR AS VARCHAR(50))) AS TNBKYR_t,
            TRIM(TRY_CAST(a.TNVBKM AS VARCHAR(50))) AS TNVBKM_t,
            TRIM(TRY_CAST(a.TNVBKY AS VARCHAR(50))) AS TNVBKY_t,
            TRIM(TRY_CAST(a.TNPBKM AS VARCHAR(50))) AS TNPBKM_t,
            TRIM(TRY_CAST(a.TNPBKY AS VARCHAR(50))) AS TNPBKY_t,
            TRIM(TRY_CAST(a.TNEUSE AS VARCHAR(50))) AS TNEUSE_t,
            CASE WHEN TRIM(TRY_CAST(a.TNEDAT AS VARCHAR(50))) IN ('','000000') THEN NULL 
                 ELSE TRY_CONVERT(DATE, CONVERT(VARCHAR(8), CONVERT(INT, a.TNEDAT))) END AS TNEDAT_d,
            TRIM(TRY_CAST(a.TNMUSE AS VARCHAR(50))) AS TNMUSE_t,
            CASE WHEN TRIM(TRY_CAST(a.TNMDAT AS VARCHAR(50))) IN ('','000000') THEN NULL 
                 ELSE TRY_CONVERT(DATE, CONVERT(VARCHAR(8), CONVERT(INT, a.TNMDAT))) END AS TNMDAT_d,
            a.loadDate,
            a.recordNumber
        FROM [data_central_lh].[dbo].[ibmi_incr_tlb_tlbinv_bronze] a
    )
    SELECT *
    INTO #TLB_Deduped
    FROM (
        SELECT p.*,
               ROW_NUMBER() OVER (
                   PARTITION BY p.TNORD_t, p.TNDISP_t
                   ORDER BY p.loadDate DESC, p.recordNumber DESC
               ) AS rn
        FROM Prep p
    ) x
    WHERE x.rn = 1;

    UPDATE T
       SET tlb_tlbinv_status_code       = S.TNSTAT_t,
           tlb_tlbinv_carrier_code      = S.TNCARR_t,
           tlb_tlbinv_division_code     = S.TNDIV_t,
           tlb_tlbinv_original_load_number = S.TNOORD_t,
           tlb_tlbinv_original_dispatch = S.TNODIS_t,
           tlb_tlbinv_carrier_invoice_number = S.TNINV_t,
           tlb_tlbinv_invoice_date      = S.TNIDAT_d,
           tlb_tlbinv_due_date          = S.TNUDAT_d,
           tlb_tlbinv_to_pay_date       = S.TNPDAT_d,
           tlb_tlbinv_invoice_amount    = S.TNIAMT_n,
           tlb_tlbinv_reference         = S.TNREF_t,
           tlb_tlbinv_fund_code         = S.TNFC_t,
           tlb_tlbinv_check_number      = S.TNCHK_n,
           tlb_tlbinv_check_date        = S.TNCDAT_d,
           tlb_tlbinv_check_amount      = S.TNCAMT_n,
           is_expensed                  = S.TNEXPF_b,
           is_voided                    = S.TNVOID_b,
           tlb_tlbinv_expensed_month    = S.TNBKMO_t,
           tlb_tlbinv_expensed_year     = S.TNBKYR_t,
           tlb_tlbinv_voided_month      = S.TNVBKM_t,
           tlb_tlbinv_voided_year       = S.TNVBKY_t,
           tlb_tlbinv_paid_month        = S.TNPBKM_t,
           tlb_tlbinv_paid_year         = S.TNPBKY_t,
           tlb_tlbinv_create_user_code  = S.TNEUSE_t,
           tlb_tlbinv_create_date       = S.TNEDAT_d,
           tlb_tlbinv_maint_user_code   = S.TNMUSE_t,
           tlb_tlbinv_maint_date        = S.TNMDAT_d
    FROM [data_central_wh].[silver].[ibmi_incr_tlb_tlbinv] T
    JOIN #TLB_Deduped S
      ON T.tlb_tlbinv_load_number = S.TNORD_t
     AND T.tlb_tlbinv_dispatch = S.TNDISP_t;

    INSERT INTO [data_central_wh].[silver].[ibmi_incr_tlb_tlbinv]
    (
        tlb_tlbinv_status_code,
        tlb_tlbinv_carrier_code,
        tlb_tlbinv_division_code,
        tlb_tlbinv_load_number,
        tlb_tlbinv_dispatch,
        tlb_tlbinv_original_load_number,
        tlb_tlbinv_original_dispatch,
        tlb_tlbinv_carrier_invoice_number,
        tlb_tlbinv_invoice_date,
        tlb_tlbinv_due_date,
        tlb_tlbinv_to_pay_date,
        tlb_tlbinv_invoice_amount,
        tlb_tlbinv_reference,
        tlb_tlbinv_fund_code,
        tlb_tlbinv_check_number,
        tlb_tlbinv_check_date,
        tlb_tlbinv_check_amount,
        is_expensed,
        is_voided,
        tlb_tlbinv_expensed_month,
        tlb_tlbinv_expensed_year,
        tlb_tlbinv_voided_month,
        tlb_tlbinv_voided_year,
        tlb_tlbinv_paid_month,
        tlb_tlbinv_paid_year,
        tlb_tlbinv_create_user_code,
        tlb_tlbinv_create_date,
        tlb_tlbinv_maint_user_code,
        tlb_tlbinv_maint_date
    )
    SELECT
        S.TNSTAT_t,
        S.TNCARR_t,
        S.TNDIV_t,
        S.TNORD_t,
        S.TNDISP_t,
        S.TNOORD_t,
        S.TNODIS_t,
        S.TNINV_t,
        S.TNIDAT_d,
        S.TNUDAT_d,
        S.TNPDAT_d,
        S.TNIAMT_n,
        S.TNREF_t,
        S.TNFC_t,
        S.TNCHK_n,
        S.TNCDAT_d,
        S.TNCAMT_n,
        S.TNEXPF_b,
        S.TNVOID_b,
        S.TNBKMO_t,
        S.TNBKYR_t,
        S.TNVBKM_t,
        S.TNVBKY_t,
        S.TNPBKM_t,
        S.TNPBKY_t,
        S.TNEUSE_t,
        S.TNEDAT_d,
        S.TNMUSE_t,
        S.TNMDAT_d
    FROM #TLB_Deduped S
    WHERE NOT EXISTS (
        SELECT 1
        FROM [data_central_wh].[silver].[ibmi_incr_tlb_tlbinv] T
        WHERE T.tlb_tlbinv_load_number = S.TNORD_t
          AND T.tlb_tlbinv_dispatch = S.TNDISP_t
    );

    DROP TABLE #TLB_Deduped;
END;