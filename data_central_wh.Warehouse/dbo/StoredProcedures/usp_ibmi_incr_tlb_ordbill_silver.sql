CREATE   PROCEDURE [dbo].[usp_ibmi_incr_tlb_ordbill_silver]
AS
BEGIN
    SET NOCOUNT ON;

    -- 1) Dedupe bronze on (ORODR, ORSEQ)
    IF OBJECT_ID('tempdb..#DedupedTlbOrdbill') IS NOT NULL DROP TABLE #DedupedTlbOrdbill;
    SELECT *
    INTO #DedupedTlbOrdbill
    FROM (
        SELECT b.*,
               ROW_NUMBER() OVER (
                   PARTITION BY b.ORODR, b.ORSEQ
                   ORDER BY b.loadDate DESC, b.recordNumber DESC
               ) AS rn
        FROM data_central_lh.dbo.ibmi_incr_tlb_ordbill_bronze AS b
    ) d
    WHERE d.rn = 1;

    -- 2) Shape and cache in a temp table (instead of a CTE)
    IF OBJECT_ID('tempdb..#Src') IS NOT NULL DROP TABLE #Src;
    SELECT
          TRIM(a.ORODR)  AS tlb_ordbill_load_number
        , TRIM(a.ORSEQ)  AS tlb_ordbill_sequence_number
        , TRIM(a.ORBINT) AS tlb_ordbill_rate_clerk_initials
        , TRIM(a.ORINV)  AS tlb_ordbill_invoice_number
        , TRIM(a.ORVINV) AS tlb_ordbill_void_invoice_number
        , orbdat.date_key_pk AS tlb_ordbill_billed_date
        , a.ORBAMT       AS tlb_ordbill_load_bill_amount
        , a.ORTAMT       AS tlb_ordbill_load_total_amount
        , TRIM(a.ORBOMO) AS tlb_ordbill_load_book_month
        , TRIM(a.ORBOYR) AS tlb_ordbill_load_book_year
        , CASE TRIM(a.ORBLST) WHEN 'Y' THEN 'TRUE' WHEN 'N' THEN 'FALSE' ELSE 'unknown' END AS is_billing_flagged
        , TRIM(a.ORARST) AS tlb_ordbill_ar_status_flag
        , TRIM(a.ORTARF) AS tlb_ordbill_tariff_code
        , TRIM(a.ORITEM) AS tlb_ordbill_item_code
        , TRIM(a.ORLINE) AS tlb_ordbill_line_code
        , TRIM(a.ORRATC) AS tlb_ordbill_rate_code
        , a.ORBAML       AS tlb_ordbill_billed_amount_linehaul
        , a.ORBAMA       AS tlb_ordbill_billed_amount_accessorial
        , a.ORTAML       AS tlb_ordbill_total_amount_linehaul
        , a.ORTAMA       AS tlb_ordbill_total_amount_accessorial
        , a.ORFSC        AS tlb_ordbill_load_fuel_surcharge_amount
        , a.ORTFSC       AS tlb_ordbill_total_fuel_surcharge_amount
        , oraudt.date_key_pk AS tlb_ordbill_audit_date
        , TRIM(a.ORAUIN) AS tlb_ordbill_audit_initials
        , orprdt.date_key_pk AS tlb_ordbill_print_date
        , TRIM(a.ORCFLG) AS tlb_ordbill_cost_record_flag
    INTO #Src
    FROM #DedupedTlbOrdbill AS a
    LEFT JOIN data_central_wh.gold.dim_date AS orbdat ON a.ORBDAT = orbdat.date_ordinal
    LEFT JOIN data_central_wh.gold.dim_date AS oraudt ON a.ORAUDT = oraudt.date_ordinal
    LEFT JOIN data_central_wh.gold.dim_date AS orprdt ON a.ORPRDT = orprdt.date_ordinal;

    -- 3) UPDATE existing rows
    UPDATE tgt
    SET
          tgt.tlb_ordbill_rate_clerk_initials         = s.tlb_ordbill_rate_clerk_initials
        , tgt.tlb_ordbill_invoice_number              = s.tlb_ordbill_invoice_number
        , tgt.tlb_ordbill_void_invoice_number         = s.tlb_ordbill_void_invoice_number
        , tgt.tlb_ordbill_billed_date                 = s.tlb_ordbill_billed_date
        , tgt.tlb_ordbill_load_bill_amount            = s.tlb_ordbill_load_bill_amount
        , tgt.tlb_ordbill_load_total_amount           = s.tlb_ordbill_load_total_amount
        , tgt.tlb_ordbill_load_book_month             = s.tlb_ordbill_load_book_month
        , tgt.tlb_ordbill_load_book_year              = s.tlb_ordbill_load_book_year
        , tgt.is_billing_flagged                      = s.is_billing_flagged
        , tgt.tlb_ordbill_ar_status_flag              = s.tlb_ordbill_ar_status_flag
        , tgt.tlb_ordbill_tariff_code                 = s.tlb_ordbill_tariff_code
        , tgt.tlb_ordbill_item_code                   = s.tlb_ordbill_item_code
        , tgt.tlb_ordbill_line_code                   = s.tlb_ordbill_line_code
        , tgt.tlb_ordbill_rate_code                   = s.tlb_ordbill_rate_code
        , tgt.tlb_ordbill_billed_amount_linehaul      = s.tlb_ordbill_billed_amount_linehaul
        , tgt.tlb_ordbill_billed_amount_accessorial   = s.tlb_ordbill_billed_amount_accessorial
        , tgt.tlb_ordbill_total_amount_linehaul       = s.tlb_ordbill_total_amount_linehaul
        , tgt.tlb_ordbill_total_amount_accessorial    = s.tlb_ordbill_total_amount_accessorial
        , tgt.tlb_ordbill_load_fuel_surcharge_amount  = s.tlb_ordbill_load_fuel_surcharge_amount
        , tgt.tlb_ordbill_total_fuel_surcharge_amount = s.tlb_ordbill_total_fuel_surcharge_amount
        , tgt.tlb_ordbill_audit_date                  = s.tlb_ordbill_audit_date
        , tgt.tlb_ordbill_audit_initials              = s.tlb_ordbill_audit_initials
        , tgt.tlb_ordbill_print_date                  = s.tlb_ordbill_print_date
        , tgt.tlb_ordbill_cost_record_flag            = s.tlb_ordbill_cost_record_flag
    FROM silver.ibmi_incr_tlb_ordbill AS tgt
    JOIN #Src AS s
      ON tgt.tlb_ordbill_load_number     = s.tlb_ordbill_load_number
     AND tgt.tlb_ordbill_sequence_number = s.tlb_ordbill_sequence_number;

    -- 4) INSERT new rows
    INSERT INTO silver.ibmi_incr_tlb_ordbill (
          tlb_ordbill_load_number
        , tlb_ordbill_sequence_number
        , tlb_ordbill_rate_clerk_initials
        , tlb_ordbill_invoice_number
        , tlb_ordbill_void_invoice_number
        , tlb_ordbill_billed_date
        , tlb_ordbill_load_bill_amount
        , tlb_ordbill_load_total_amount
        , tlb_ordbill_load_book_month
        , tlb_ordbill_load_book_year
        , is_billing_flagged
        , tlb_ordbill_ar_status_flag
        , tlb_ordbill_tariff_code
        , tlb_ordbill_item_code
        , tlb_ordbill_line_code
        , tlb_ordbill_rate_code
        , tlb_ordbill_billed_amount_linehaul
        , tlb_ordbill_billed_amount_accessorial
        , tlb_ordbill_total_amount_linehaul
        , tlb_ordbill_total_amount_accessorial
        , tlb_ordbill_load_fuel_surcharge_amount
        , tlb_ordbill_total_fuel_surcharge_amount
        , tlb_ordbill_audit_date
        , tlb_ordbill_audit_initials
        , tlb_ordbill_print_date
        , tlb_ordbill_cost_record_flag
    )
    SELECT
          s.tlb_ordbill_load_number
        , s.tlb_ordbill_sequence_number
        , s.tlb_ordbill_rate_clerk_initials
        , s.tlb_ordbill_invoice_number
        , s.tlb_ordbill_void_invoice_number
        , s.tlb_ordbill_billed_date
        , s.tlb_ordbill_load_bill_amount
        , s.tlb_ordbill_load_total_amount
        , s.tlb_ordbill_load_book_month
        , s.tlb_ordbill_load_book_year
        , s.is_billing_flagged
        , s.tlb_ordbill_ar_status_flag
        , s.tlb_ordbill_tariff_code
        , s.tlb_ordbill_item_code
        , s.tlb_ordbill_line_code
        , s.tlb_ordbill_rate_code
        , s.tlb_ordbill_billed_amount_linehaul
        , s.tlb_ordbill_billed_amount_accessorial
        , s.tlb_ordbill_total_amount_linehaul
        , s.tlb_ordbill_total_amount_accessorial
        , s.tlb_ordbill_load_fuel_surcharge_amount
        , s.tlb_ordbill_total_fuel_surcharge_amount
        , s.tlb_ordbill_audit_date
        , s.tlb_ordbill_audit_initials
        , s.tlb_ordbill_print_date
        , s.tlb_ordbill_cost_record_flag
    FROM #Src AS s
    WHERE NOT EXISTS (
        SELECT 1
        FROM silver.ibmi_incr_tlb_ordbill AS t
        WHERE t.tlb_ordbill_load_number     = s.tlb_ordbill_load_number
          AND t.tlb_ordbill_sequence_number = s.tlb_ordbill_sequence_number
    );

    DROP TABLE IF EXISTS #Src, #DedupedTlbOrdbill;
END