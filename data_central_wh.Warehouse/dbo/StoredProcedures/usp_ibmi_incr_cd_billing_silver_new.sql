/*========================================================
  usp_ibmi_incr_cd_billing_silver_new
  - ONLY change: add delete step based on DISTINCT cd_billing_load_number (BIODR)
  - Ignore other keys for deletion (BISEQ/BICNT not used in delete)
  - Everything else unchanged
========================================================*/
CREATE   PROCEDURE [dbo].[usp_ibmi_incr_cd_billing_silver_new]
AS
BEGIN
    SET NOCOUNT ON;

    -- Step 1: Deduplicate source by BIODR, BISEQ, BICNT using latest loadDate/recordNumber
    IF OBJECT_ID('tempdb..#DedupedCDBilling') IS NOT NULL DROP TABLE #DedupedCDBilling;

    SELECT *
    INTO #DedupedCDBilling
    FROM (
        SELECT *,
            ROW_NUMBER() OVER (
                PARTITION BY BIODR, BISEQ, BICNT
                ORDER BY loadDate DESC, recordNumber DESC
            ) AS rn
        FROM data_central_lh.dbo.ibmi_incr_cd_billing_bronze_new
    ) a
    WHERE rn = 1;

    /*========================================================
      NEW Step 1.5: Delete from target ONLY for DISTINCT cd_billing_load_number in this run
    ========================================================*/
    IF OBJECT_ID('tempdb..#CDBillingLoadsToDelete') IS NOT NULL DROP TABLE #CDBillingLoadsToDelete;

    SELECT DISTINCT TRIM(BIODR) AS cd_billing_load_number
    INTO #CDBillingLoadsToDelete
    FROM #DedupedCDBilling
    WHERE BIODR IS NOT NULL;

    DELETE TGT
    FROM silver.ibmi_incr_cd_billing_new TGT
    JOIN #CDBillingLoadsToDelete D
      ON TGT.cd_billing_load_number = D.cd_billing_load_number;

    -- Step 2: UPDATE existing
    UPDATE TGT
    SET
        cd_billing_load_number           = TRIM(SRC.BIODR),
        cd_billing_sequence_number       = TRIM(SRC.BISEQ),
        cd_billing_record_number         = SRC.BICNT,
        is_deleted                       = CASE WHEN TRIM(SRC.BIDLT) = 'D' THEN 1 ELSE 0 END,
        cd_billing_commodity_code        = TRIM(SRC.BICOMM),
        cd_billing_commodity_description = SRC.BIDESC,
        cd_billing_piece_count           = SRC.BIPIEC,
        cd_billing_actual_quantity_count = SRC.BIAQTY,
        cd_billing_billed_quantity_count = SRC.BIBQTY,
        cd_billing_billed_rate           = SRC.BIRATE,
        cd_billing_billed_amount         = SRC.BIAMT,
        cd_billing_method_code           = TRIM(SRC.BIMETH),
        cd_billing_error_code            = TRIM(SRC.BIERR),
        cd_billing_gl_account_number     = TRIM(SRC.BIACCT)
    FROM silver.ibmi_incr_cd_billing_new TGT
    JOIN #DedupedCDBilling SRC
        ON TGT.cd_billing_load_number = TRIM(SRC.BIODR)
        AND TGT.cd_billing_sequence_number = TRIM(SRC.BISEQ)
        AND TGT.cd_billing_record_number = SRC.BICNT;

    -- Step 3: INSERT new
    INSERT INTO silver.ibmi_incr_cd_billing_new (
        cd_billing_load_number,
        cd_billing_sequence_number,
        cd_billing_record_number,
        is_deleted,
        cd_billing_commodity_code,
        cd_billing_commodity_description,
        cd_billing_piece_count,
        cd_billing_actual_quantity_count,
        cd_billing_billed_quantity_count,
        cd_billing_billed_rate,
        cd_billing_billed_amount,
        cd_billing_method_code,
        cd_billing_error_code,
        cd_billing_gl_account_number
    )
    SELECT
        TRIM(SRC.BIODR),
        TRIM(SRC.BISEQ),
        SRC.BICNT,
        CASE WHEN TRIM(SRC.BIDLT) = 'D' THEN 1 ELSE 0 END,
        TRIM(SRC.BICOMM),
        SRC.BIDESC,
        SRC.BIPIEC,
        SRC.BIAQTY,
        SRC.BIBQTY,
        SRC.BIRATE,
        SRC.BIAMT,
        TRIM(SRC.BIMETH),
        TRIM(SRC.BIERR),
        TRIM(SRC.BIACCT)
    FROM #DedupedCDBilling SRC
    WHERE NOT EXISTS (
        SELECT 1 FROM silver.ibmi_incr_cd_billing_new TGT
        WHERE TGT.cd_billing_load_number = TRIM(SRC.BIODR)
          AND TGT.cd_billing_sequence_number = TRIM(SRC.BISEQ)
          AND TGT.cd_billing_record_number = SRC.BICNT
    );

    DROP TABLE #DedupedCDBilling;
    DROP TABLE #CDBillingLoadsToDelete;
END