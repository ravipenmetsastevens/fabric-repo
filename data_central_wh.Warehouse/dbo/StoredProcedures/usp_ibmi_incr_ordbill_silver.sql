CREATE   PROCEDURE [dbo].[usp_ibmi_incr_ordbill_silver]
AS
BEGIN
    SET NOCOUNT ON;

    -- 1) Deduplicate bronze on (ORODR, ORSEQ). Prefer newest row.
    IF OBJECT_ID('tempdb..#DedupedOrdbill') IS NOT NULL DROP TABLE #DedupedOrdbill;
    SELECT *
    INTO #DedupedOrdbill
    FROM (
        SELECT b.*,
               ROW_NUMBER() OVER (
                   PARTITION BY b.ORODR, b.ORSEQ
                   ORDER BY b.loadDate DESC, b.recordNumber DESC
               ) AS rn
        FROM data_central_lh.dbo.ibmi_incr_ordbill_bronze AS b
    ) d
    WHERE d.rn = 1;

    -- 2) Shape source with date lookups, cache as temp table
    IF OBJECT_ID('tempdb..#Src') IS NOT NULL DROP TABLE #Src;
    SELECT
          TRIM(a.ORODR)                                AS ordbill_load_number
        , TRIM(a.ORSEQ)                                AS ordbill_sequence_number
        , TRIM(a.ORBINT)                               AS ordbill_rate_clerk_initials
        , TRIM(a.ORINV)                                AS ordbill_invoice_number
        , TRIM(a.ORVINV)                               AS ordbill_void_invoice_number
        , orbdat.date_key_pk                           AS ordbill_billed_date
        , a.ORBAMT                                     AS ordbill_load_bill_amount
        , a.ORTAMT                                     AS ordbill_load_total_amount
        , TRIM(a.ORBOMO)                               AS ordbill_load_book_month
        , TRIM(a.ORBOYR)                               AS ordbill_load_book_year
        , CASE TRIM(a.ORBLST)
            WHEN 'Y' THEN 'TRUE'
            WHEN 'N' THEN 'FALSE'
            ELSE 'unknown'
          END                                          AS is_billing_flagged
        , TRIM(a.ORARST)                               AS ordbill_ar_status_flag
        , TRIM(a.ORTARF)                               AS ordbill_tariff_code
        , TRIM(a.ORITEM)                               AS ordbill_item_code
        , TRIM(a.ORLINE)                               AS ordbill_line_code
        , TRIM(a.ORRATC)                               AS ordbill_rate_code
        , a.ORBAML                                     AS ordbill_billed_amount_linehaul
        , a.ORBAMA                                     AS ordbill_billed_amount_accessorial
        , a.ORTAML                                     AS ordbill_total_amount_linehaul
        , a.ORTAMA                                     AS ordbill_total_amount_accessorial
        , a.ORFSC                                      AS ordbill_load_fuel_surcharge_amount
        , a.ORTFSC                                     AS ordbill_total_fuel_surcharge_amount
        , oraudt.date_key_pk                           AS ordbill_audit_date
        , TRIM(a.ORAUIN)                               AS ordbill_audit_initials
        , orprdt.date_key_pk                           AS ordbill_print_date
        , TRIM(a.ORCFLG)                               AS ordbill_cost_record_flag
    INTO #Src
    FROM #DedupedOrdbill AS a
    LEFT JOIN gold.dim_date AS orbdat ON a.ORBDAT = orbdat.date_ordinal
    LEFT JOIN gold.dim_date AS oraudt ON a.ORAUDT = oraudt.date_ordinal
    LEFT JOIN gold.dim_date AS orprdt ON a.ORPRDT = orprdt.date_ordinal;

    -- 3) UPDATE existing rows
    UPDATE tgt
    SET
          tgt.ordbill_rate_clerk_initials         = s.ordbill_rate_clerk_initials
        , tgt.ordbill_invoice_number              = s.ordbill_invoice_number
        , tgt.ordbill_void_invoice_number         = s.ordbill_void_invoice_number
        , tgt.ordbill_billed_date                 = s.ordbill_billed_date
        , tgt.ordbill_load_bill_amount            = s.ordbill_load_bill_amount
        , tgt.ordbill_load_total_amount           = s.ordbill_load_total_amount
        , tgt.ordbill_load_book_month             = s.ordbill_load_book_month
        , tgt.ordbill_load_book_year              = s.ordbill_load_book_year
        , tgt.is_billing_flagged                  = s.is_billing_flagged
        , tgt.ordbill_ar_status_flag              = s.ordbill_ar_status_flag
        , tgt.ordbill_tariff_code                 = s.ordbill_tariff_code
        , tgt.ordbill_item_code                   = s.ordbill_item_code
        , tgt.ordbill_line_code                   = s.ordbill_line_code
        , tgt.ordbill_rate_code                   = s.ordbill_rate_code
        , tgt.ordbill_billed_amount_linehaul      = s.ordbill_billed_amount_linehaul
        , tgt.ordbill_billed_amount_accessorial   = s.ordbill_billed_amount_accessorial
        , tgt.ordbill_total_amount_linehaul       = s.ordbill_total_amount_linehaul
        , tgt.ordbill_total_amount_accessorial    = s.ordbill_total_amount_accessorial
        , tgt.ordbill_load_fuel_surcharge_amount  = s.ordbill_load_fuel_surcharge_amount
        , tgt.ordbill_total_fuel_surcharge_amount = s.ordbill_total_fuel_surcharge_amount
        , tgt.ordbill_audit_date                  = s.ordbill_audit_date
        , tgt.ordbill_audit_initials              = s.ordbill_audit_initials
        , tgt.ordbill_print_date                  = s.ordbill_print_date
        , tgt.ordbill_cost_record_flag            = s.ordbill_cost_record_flag
    FROM silver.ibmi_incr_ordbill AS tgt
    JOIN #Src AS s
      ON tgt.ordbill_load_number     = s.ordbill_load_number
     AND tgt.ordbill_sequence_number = s.ordbill_sequence_number;

    -- 4) INSERT new rows
    INSERT INTO silver.ibmi_incr_ordbill (
          ordbill_load_number
        , ordbill_sequence_number
        , ordbill_rate_clerk_initials
        , ordbill_invoice_number
        , ordbill_void_invoice_number
        , ordbill_billed_date
        , ordbill_load_bill_amount
        , ordbill_load_total_amount
        , ordbill_load_book_month
        , ordbill_load_book_year
        , is_billing_flagged
        , ordbill_ar_status_flag
        , ordbill_tariff_code
        , ordbill_item_code
        , ordbill_line_code
        , ordbill_rate_code
        , ordbill_billed_amount_linehaul
        , ordbill_billed_amount_accessorial
        , ordbill_total_amount_linehaul
        , ordbill_total_amount_accessorial
        , ordbill_load_fuel_surcharge_amount
        , ordbill_total_fuel_surcharge_amount
        , ordbill_audit_date
        , ordbill_audit_initials
        , ordbill_print_date
        , ordbill_cost_record_flag
    )
    SELECT
          s.ordbill_load_number
        , s.ordbill_sequence_number
        , s.ordbill_rate_clerk_initials
        , s.ordbill_invoice_number
        , s.ordbill_void_invoice_number
        , s.ordbill_billed_date
        , s.ordbill_load_bill_amount
        , s.ordbill_load_total_amount
        , s.ordbill_load_book_month
        , s.ordbill_load_book_year
        , s.is_billing_flagged
        , s.ordbill_ar_status_flag
        , s.ordbill_tariff_code
        , s.ordbill_item_code
        , s.ordbill_line_code
        , s.ordbill_rate_code
        , s.ordbill_billed_amount_linehaul
        , s.ordbill_billed_amount_accessorial
        , s.ordbill_total_amount_linehaul
        , s.ordbill_total_amount_accessorial
        , s.ordbill_load_fuel_surcharge_amount
        , s.ordbill_total_fuel_surcharge_amount
        , s.ordbill_audit_date
        , s.ordbill_audit_initials
        , s.ordbill_print_date
        , s.ordbill_cost_record_flag
    FROM #Src AS s
    WHERE NOT EXISTS (
        SELECT 1
        FROM silver.ibmi_incr_ordbill AS t
        WHERE t.ordbill_load_number     = s.ordbill_load_number
          AND t.ordbill_sequence_number = s.ordbill_sequence_number
    );

    DROP TABLE IF EXISTS #Src, #DedupedOrdbill;
END