CREATE   PROCEDURE [dbo].[usp_ibmi_incr_cd_ordbill_silver]
AS
BEGIN
    SET NOCOUNT ON;

    -- 1) Deduplicate bronze on (ORODR, ORSEQ). Prefer newest row.
    IF OBJECT_ID('tempdb..#DedupedCdOrdbill') IS NOT NULL DROP TABLE #DedupedCdOrdbill;
    SELECT *
    INTO #DedupedCdOrdbill
    FROM (
        SELECT b.*,
               ROW_NUMBER() OVER (
                   PARTITION BY b.ORODR, b.ORSEQ
                   ORDER BY b.loadDate DESC, b.recordNumber DESC
               ) AS rn
        FROM data_central_lh.dbo.ibmi_incr_cd_ordbill_bronze AS b
    ) d
    WHERE d.rn = 1;

    -- 2) Shape source with date lookups, cache as temp table
    IF OBJECT_ID('tempdb..#SrcCd') IS NOT NULL DROP TABLE #SrcCd;
    SELECT
          TRIM(a.ORODR)                                AS cd_ordbill_load_number
        , TRIM(a.ORSEQ)                                AS cd_ordbill_sequence_number
        , TRIM(a.ORBINT)                               AS cd_ordbill_rate_clerk_initials
        , TRIM(a.ORINV)                                AS cd_ordbill_invoice_number
        , TRIM(a.ORVINV)                               AS cd_ordbill_void_invoice_number
        , orbdat.date_key_pk                           AS cd_ordbill_billed_date
        , a.ORBAMT                                     AS cd_ordbill_load_bill_amount
        , a.ORTAMT                                     AS cd_ordbill_load_total_amount
        , TRIM(a.ORBOMO)                               AS cd_ordbill_load_book_month
        , TRIM(a.ORBOYR)                               AS cd_ordbill_load_book_year
        , CASE TRIM(a.ORBLST)
            WHEN 'Y' THEN 'TRUE'
            WHEN 'N' THEN 'FALSE'
            ELSE 'unknown'
          END                                          AS is_billing_flagged
        , TRIM(a.ORARST)                               AS cd_ordbill_ar_status_flag
        , TRIM(a.ORTARF)                               AS cd_ordbill_tariff_code
        , TRIM(a.ORITEM)                               AS cd_ordbill_item_code
        , TRIM(a.ORLINE)                               AS cd_ordbill_line_code
        , TRIM(a.ORRATC)                               AS cd_ordbill_rate_code
        , a.ORBAML                                     AS cd_ordbill_billed_amount_linehaul
        , a.ORBAMA                                     AS cd_ordbill_billed_amount_accessorial
        , a.ORTAML                                     AS cd_ordbill_total_amount_linehaul
        , a.ORTAMA                                     AS cd_ordbill_total_amount_accessorial
        , a.ORFSC                                      AS cd_ordbill_load_fuel_surcharge_amount
        , a.ORTFSC                                     AS cd_ordbill_total_fuel_surcharge_amount
        , oraudt.date_key_pk                           AS cd_ordbill_audit_date
        , TRIM(a.ORAUIN)                               AS cd_ordbill_audit_initials
        , orprdt.date_key_pk                           AS cd_ordbill_print_date
        , TRIM(a.ORCFLG)                               AS cd_ordbill_cost_record_flag
    INTO #SrcCd
    FROM #DedupedCdOrdbill AS a
    LEFT JOIN data_central_wh.gold.dim_date AS orbdat ON a.ORBDAT = orbdat.date_ordinal
    LEFT JOIN data_central_wh.gold.dim_date AS oraudt ON a.ORAUDT = oraudt.date_ordinal
    LEFT JOIN data_central_wh.gold.dim_date AS orprdt ON a.ORPRDT = orprdt.date_ordinal;

    -- 3) UPDATE existing rows
    UPDATE tgt
    SET
          tgt.cd_ordbill_rate_clerk_initials         = s.cd_ordbill_rate_clerk_initials
        , tgt.cd_ordbill_invoice_number              = s.cd_ordbill_invoice_number
        , tgt.cd_ordbill_void_invoice_number         = s.cd_ordbill_void_invoice_number
        , tgt.cd_ordbill_billed_date                 = s.cd_ordbill_billed_date
        , tgt.cd_ordbill_load_bill_amount            = s.cd_ordbill_load_bill_amount
        , tgt.cd_ordbill_load_total_amount           = s.cd_ordbill_load_total_amount
        , tgt.cd_ordbill_load_book_month             = s.cd_ordbill_load_book_month
        , tgt.cd_ordbill_load_book_year              = s.cd_ordbill_load_book_year
        , tgt.is_billing_flagged                     = s.is_billing_flagged
        , tgt.cd_ordbill_ar_status_flag              = s.cd_ordbill_ar_status_flag
        , tgt.cd_ordbill_tariff_code                 = s.cd_ordbill_tariff_code
        , tgt.cd_ordbill_item_code                   = s.cd_ordbill_item_code
        , tgt.cd_ordbill_line_code                   = s.cd_ordbill_line_code
        , tgt.cd_ordbill_rate_code                   = s.cd_ordbill_rate_code
        , tgt.cd_ordbill_billed_amount_linehaul      = s.cd_ordbill_billed_amount_linehaul
        , tgt.cd_ordbill_billed_amount_accessorial   = s.cd_ordbill_billed_amount_accessorial
        , tgt.cd_ordbill_total_amount_linehaul       = s.cd_ordbill_total_amount_linehaul
        , tgt.cd_ordbill_total_amount_accessorial    = s.cd_ordbill_total_amount_accessorial
        , tgt.cd_ordbill_load_fuel_surcharge_amount  = s.cd_ordbill_load_fuel_surcharge_amount
        , tgt.cd_ordbill_total_fuel_surcharge_amount = s.cd_ordbill_total_fuel_surcharge_amount
        , tgt.cd_ordbill_audit_date                  = s.cd_ordbill_audit_date
        , tgt.cd_ordbill_audit_initials              = s.cd_ordbill_audit_initials
        , tgt.cd_ordbill_print_date                  = s.cd_ordbill_print_date
        , tgt.cd_ordbill_cost_record_flag            = s.cd_ordbill_cost_record_flag
    FROM silver.ibmi_incr_cd_ordbill AS tgt
    JOIN #SrcCd AS s
      ON tgt.cd_ordbill_load_number     = s.cd_ordbill_load_number
     AND tgt.cd_ordbill_sequence_number = s.cd_ordbill_sequence_number;

    -- 4) INSERT new rows
    INSERT INTO silver.ibmi_incr_cd_ordbill (
          cd_ordbill_load_number
        , cd_ordbill_sequence_number
        , cd_ordbill_rate_clerk_initials
        , cd_ordbill_invoice_number
        , cd_ordbill_void_invoice_number
        , cd_ordbill_billed_date
        , cd_ordbill_load_bill_amount
        , cd_ordbill_load_total_amount
        , cd_ordbill_load_book_month
        , cd_ordbill_load_book_year
        , is_billing_flagged
        , cd_ordbill_ar_status_flag
        , cd_ordbill_tariff_code
        , cd_ordbill_item_code
        , cd_ordbill_line_code
        , cd_ordbill_rate_code
        , cd_ordbill_billed_amount_linehaul
        , cd_ordbill_billed_amount_accessorial
        , cd_ordbill_total_amount_linehaul
        , cd_ordbill_total_amount_accessorial
        , cd_ordbill_load_fuel_surcharge_amount
        , cd_ordbill_total_fuel_surcharge_amount
        , cd_ordbill_audit_date
        , cd_ordbill_audit_initials
        , cd_ordbill_print_date
        , cd_ordbill_cost_record_flag
    )
    SELECT
          s.cd_ordbill_load_number
        , s.cd_ordbill_sequence_number
        , s.cd_ordbill_rate_clerk_initials
        , s.cd_ordbill_invoice_number
        , s.cd_ordbill_void_invoice_number
        , s.cd_ordbill_billed_date
        , s.cd_ordbill_load_bill_amount
        , s.cd_ordbill_load_total_amount
        , s.cd_ordbill_load_book_month
        , s.cd_ordbill_load_book_year
        , s.is_billing_flagged
        , s.cd_ordbill_ar_status_flag
        , s.cd_ordbill_tariff_code
        , s.cd_ordbill_item_code
        , s.cd_ordbill_line_code
        , s.cd_ordbill_rate_code
        , s.cd_ordbill_billed_amount_linehaul
        , s.cd_ordbill_billed_amount_accessorial
        , s.cd_ordbill_total_amount_linehaul
        , s.cd_ordbill_total_amount_accessorial
        , s.cd_ordbill_load_fuel_surcharge_amount
        , s.cd_ordbill_total_fuel_surcharge_amount
        , s.cd_ordbill_audit_date
        , s.cd_ordbill_audit_initials
        , s.cd_ordbill_print_date
        , s.cd_ordbill_cost_record_flag
    FROM #SrcCd AS s
    WHERE NOT EXISTS (
        SELECT 1
        FROM silver.ibmi_incr_cd_ordbill AS t
        WHERE t.cd_ordbill_load_number     = s.cd_ordbill_load_number
          AND t.cd_ordbill_sequence_number = s.cd_ordbill_sequence_number
    );

    DROP TABLE IF EXISTS #SrcCd, #DedupedCdOrdbill;
END