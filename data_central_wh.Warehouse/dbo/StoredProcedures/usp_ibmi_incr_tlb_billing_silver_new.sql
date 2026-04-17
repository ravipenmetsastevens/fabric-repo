/*========================================================
  usp_ibmi_incr_tlb_billing_silver_new
  - ONLY change: add delete step based on DISTINCT tlb_billing_load_number (BIODR)
  - Ignore other keys for deletion (BISEQ/BICNT not used in delete)
  - Everything else unchanged
========================================================*/
CREATE   PROCEDURE [dbo].[usp_ibmi_incr_tlb_billing_silver_new]
AS
BEGIN
    SET NOCOUNT ON;

    -- Deduplicate source using latest loadDate/recordNumber by composite key
    IF OBJECT_ID('tempdb..#DedupedTLBBilling') IS NOT NULL DROP TABLE #DedupedTLBBilling;

    SELECT *
    INTO #DedupedTLBBilling
    FROM (
        SELECT *,
            ROW_NUMBER() OVER (
                PARTITION BY BIODR, BISEQ, BICNT
                ORDER BY loadDate DESC, recordNumber DESC
            ) AS rn
        FROM data_central_lh.dbo.ibmi_incr_tlb_billing_bronze_new
    ) a
    WHERE rn = 1;

    /*========================================================
      NEW Step 1.5: Delete from target ONLY for DISTINCT tlb_billing_load_number in this run
    ========================================================*/
    IF OBJECT_ID('tempdb..#TLBBillingLoadsToDelete') IS NOT NULL DROP TABLE #TLBBillingLoadsToDelete;

    SELECT DISTINCT TRIM(BIODR) AS tlb_billing_load_number
    INTO #TLBBillingLoadsToDelete
    FROM #DedupedTLBBilling
    WHERE BIODR IS NOT NULL;

    DELETE TGT
    FROM silver.ibmi_incr_tlb_billing_new TGT
    JOIN #TLBBillingLoadsToDelete D
      ON TGT.tlb_billing_load_number = D.tlb_billing_load_number;

    -- UPDATE existing records
    UPDATE TGT
    SET
        tlb_billing_load_number             = TRIM(SRC.BIODR),
        tlb_billing_sequence_number         = TRIM(SRC.BISEQ),
        tlb_billing_record_number           = SRC.BICNT,
        is_deleted                         = CASE WHEN TRIM(SRC.BIDLT) = 'D' THEN 1 ELSE 0 END,
        tlb_billing_commodity_code         = TRIM(SRC.BICOMM),
        tlb_billing_commodity_description  = TRIM(SRC.BIDESC),
        tlb_billing_piece_count            = SRC.BIPIEC,
        tlb_billing_actual_quantity_count  = SRC.BIAQTY,
        tlb_billing_billed_quantity_count  = SRC.BIBQTY,
        tlb_billing_billed_rate            = SRC.BIRATE,
        tlb_billing_billed_amount          = SRC.BIAMT,
        tlb_billing_method_code            = TRIM(SRC.BIMETH),
        tlb_billing_error_code             = TRIM(SRC.BIERR),
        tlb_billing_gl_account_number      = TRIM(SRC.BIACCT),
        tlb_billing_gl_cost_center_code    = TRIM(SRC.BICC)
    FROM silver.ibmi_incr_tlb_billing_new TGT
    JOIN #DedupedTLBBilling SRC
        ON TGT.tlb_billing_load_number = TRIM(SRC.BIODR)
        AND TGT.tlb_billing_sequence_number = TRIM(SRC.BISEQ)
        AND TGT.tlb_billing_record_number = SRC.BICNT;

    -- INSERT new records
    INSERT INTO silver.ibmi_incr_tlb_billing_new (
        tlb_billing_load_number,
        tlb_billing_sequence_number,
        tlb_billing_record_number,
        is_deleted,
        tlb_billing_commodity_code,
        tlb_billing_commodity_description,
        tlb_billing_piece_count,
        tlb_billing_actual_quantity_count,
        tlb_billing_billed_quantity_count,
        tlb_billing_billed_rate,
        tlb_billing_billed_amount,
        tlb_billing_method_code,
        tlb_billing_error_code,
        tlb_billing_gl_account_number,
        tlb_billing_gl_cost_center_code
    )
    SELECT
        TRIM(SRC.BIODR),
        TRIM(SRC.BISEQ),
        SRC.BICNT,
        CASE WHEN TRIM(SRC.BIDLT) = 'D' THEN 1 ELSE 0 END,
        TRIM(SRC.BICOMM),
        TRIM(SRC.BIDESC),
        SRC.BIPIEC,
        SRC.BIAQTY,
        SRC.BIBQTY,
        SRC.BIRATE,
        SRC.BIAMT,
        TRIM(SRC.BIMETH),
        TRIM(SRC.BIERR),
        TRIM(SRC.BIACCT),
        TRIM(SRC.BICC)
    FROM #DedupedTLBBilling SRC
    WHERE NOT EXISTS (
        SELECT 1 FROM silver.ibmi_incr_tlb_billing_new TGT
        WHERE TGT.tlb_billing_load_number = TRIM(SRC.BIODR)
          AND TGT.tlb_billing_sequence_number = TRIM(SRC.BISEQ)
          AND TGT.tlb_billing_record_number = SRC.BICNT
    );

    DROP TABLE #DedupedTLBBilling;
    DROP TABLE #TLBBillingLoadsToDelete;
END