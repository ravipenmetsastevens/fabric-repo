/*========================================================
  usp_ibmi_incr_billing_silver_new
  - ONLY change: add delete step based on DISTINCT billing_load_number (BIODR)
  - Ignore other keys for deletion (BISEQ/BICNT not used in delete)
  - Everything else unchanged
========================================================*/
CREATE   PROCEDURE [dbo].[usp_ibmi_incr_billing_silver_new]
AS
BEGIN
    SET NOCOUNT ON;

    -- 1. Prepare deduplicated source in a temp table using the correct keys (BIODR, BISEQ, BICNT)
    IF OBJECT_ID('tempdb..#DedupedBilling') IS NOT NULL DROP TABLE #DedupedBilling;

    SELECT *
    INTO #DedupedBilling
    FROM (
        SELECT *,
            ROW_NUMBER() OVER (
                PARTITION BY BIODR, BISEQ, BICNT
                ORDER BY loadDate DESC, recordNumber DESC
            ) AS rn
        FROM data_central_lh.dbo.ibmi_incr_billing_bronze_new
    ) a
    WHERE rn = 1;

    /*========================================================
      NEW Step 1.5: Delete from target ONLY for DISTINCT billing_load_number in this run
    ========================================================*/
    IF OBJECT_ID('tempdb..#BillingLoadsToDelete') IS NOT NULL DROP TABLE #BillingLoadsToDelete;

    SELECT DISTINCT TRIM(BIODR) AS billing_load_number
    INTO #BillingLoadsToDelete
    FROM #DedupedBilling
    WHERE BIODR IS NOT NULL;

    DELETE TGT
    FROM silver.ibmi_incr_billing_new TGT
    JOIN #BillingLoadsToDelete D
      ON TGT.billing_load_number = D.billing_load_number;

    -- 2. UPDATE existing records in the target
    UPDATE TGT
    SET
        billing_load_number           = TRIM(SRC.BIODR),
        billing_sequence_number       = TRIM(SRC.BISEQ),
        billing_record_number         = SRC.BICNT,
        is_deleted                    = CASE WHEN TRIM(SRC.BIDLT) = 'D' THEN 1 ELSE 0 END,
        billing_commodity_code        = TRIM(SRC.BICOMM),
        billing_commodity_description = TRIM(SRC.BIDESC),
        billing_piece_count           = SRC.BIPIEC,
        billing_actual_quantity_count = SRC.BIAQTY,
        billing_billed_quantity_count = SRC.BIBQTY,
        billing_billed_rate           = SRC.BIRATE,
        billing_billed_amount         = SRC.BIAMT,
        billing_method_code           = TRIM(SRC.BIMETH),
        billing_error_code            = TRIM(SRC.BIERR),
        billing_gl_account_number     = TRIM(SRC.BIACCT),
        billing_gl_cost_center_code   = TRIM(SRC.BICC)
    FROM silver.ibmi_incr_billing_new TGT
    JOIN #DedupedBilling SRC
        ON TGT.billing_load_number = TRIM(SRC.BIODR)
        AND TGT.billing_sequence_number = TRIM(SRC.BISEQ)
        AND TGT.billing_record_number = SRC.BICNT;

    -- 3. INSERT new records into the target
    INSERT INTO silver.ibmi_incr_billing_new (
        billing_load_number,
        billing_sequence_number,
        billing_record_number,
        is_deleted,
        billing_commodity_code,
        billing_commodity_description,
        billing_piece_count,
        billing_actual_quantity_count,
        billing_billed_quantity_count,
        billing_billed_rate,
        billing_billed_amount,
        billing_method_code,
        billing_error_code,
        billing_gl_account_number,
        billing_gl_cost_center_code
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
    FROM #DedupedBilling SRC
    WHERE NOT EXISTS (
        SELECT 1 FROM silver.ibmi_incr_billing_new TGT
        WHERE TGT.billing_load_number = TRIM(SRC.BIODR)
          AND TGT.billing_sequence_number = TRIM(SRC.BISEQ)
          AND TGT.billing_record_number = SRC.BICNT
    );

    DROP TABLE #DedupedBilling;
    DROP TABLE #BillingLoadsToDelete;
END