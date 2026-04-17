CREATE     PROCEDURE [dbo].[usp_ibmi_incr_earnings_history_silver]
AS
BEGIN
    SET NOCOUNT ON;

    /* -------------------------------
       Step 0: Dedupe bronze on key
       ------------------------------- */
    IF OBJECT_ID('tempdb..#DedupedEH', 'U') IS NOT NULL DROP TABLE #DedupedEH;

    SELECT
        a.*,
        -- Resolve date ordinals to keys used in silver
        EHPAYD.date_key_pk AS EHPAYD_key,
        EHERND.date_key_pk AS EHERND_key,
        EHCKDT.date_key_pk AS EHCKDT_key,
        EHADAT.date_key_pk AS EHADAT_key
    INTO #DedupedEH
    FROM (
        SELECT *,
               ROW_NUMBER() OVER (
                   PARTITION BY TRIM(EHEMP), EHPAYD, EHSEQ, TRIM(EHCLAS), EHCKDT, TRIM(EHCKNO)
                   ORDER BY loadDate DESC, recordNumber DESC
               ) AS rn
        FROM data_central_lh.dbo.ibmi_incr_earnings_history_bronze
    ) a
    LEFT JOIN gold.dim_date EHPAYD ON a.EHPAYD = EHPAYD.date_ordinal
    LEFT JOIN gold.dim_date EHERND ON a.EHERND = EHERND.date_ordinal
    LEFT JOIN gold.dim_date EHCKDT ON a.EHCKDT = EHCKDT.date_ordinal
    LEFT JOIN gold.dim_date EHADAT ON a.EHADAT = EHADAT.date_ordinal
    WHERE a.rn = 1;

    /* -------------------------------
       Step 1: UPDATE matches
       ------------------------------- */
    UPDATE T
    SET
        earnings_history_employee_code                  = TRIM(S.EHEMP),
        earnings_history_company_code                   = TRIM(S.EHCOMP),
        earnings_history_run_code                       = TRIM(S.EHRUN),
        earnings_history_benefit_package_code           = TRIM(S.EHBPKG),
        earnings_history_department_code                = TRIM(S.EHDEPT),
        earnings_history_division_code                  = TRIM(S.EHDVSN),
        earnings_history_job_description                = TRIM(S.EHJOB),
        earnings_history_pay_date                       = S.EHPAYD_key,
        earnings_history_pay_week_number                = S.EHWEEK,
        earnings_history_sequence_number                = S.EHSEQ,
        earnings_history_quantity                       = S.EHQTY,
        earnings_history_unit_type_code                 = TRIM(S.EHUNTY),
        is_paid_hours                                   = CASE WHEN TRIM(S.EHPAID) = 'Y' THEN 'TRUE' ELSE 'FALSE' END,
        earnings_history_pay_class_code                 = TRIM(S.EHCLAS),
        earnings_history_pay_rate                       = TRIM(S.EHRATC),
        earnings_history_per_unit_rate                  = S.EHRATE,
        earnings_history_gross_amount                   = S.EHGROS,
        earnings_history_pay_quantity_worked            = S.EHQTYW,
        earnings_history_load_number                    = TRIM(S.EHORD),
        earnings_history_dispatch_number                = TRIM(S.EHDSP),
        earnings_history_miles_loaded                   = S.EHLMIL,
        earnings_history_miles_dead_head                = S.EHEMIL,
        earnings_history_truck_number                   = TRIM(S.EHUNIT),
        earnings_history_owner_code                     = TRIM(S.EHOWNR),
        earnings_history_origin_city                    = TRIM(S.EHORGC),
        earnings_history_origin_state                   = TRIM(S.EHORGS),
        earnings_history_destination_city               = TRIM(S.EHDSTC),
        earnings_history_destination_state              = TRIM(S.EHDSTS),
        earnings_history_description                    = TRIM(S.EHDESC),
        is_solo_or_team                                 = CASE TRIM(S.EHSTCD) WHEN 'S' THEN 'SOLO'
                                                                             WHEN 'T' THEN 'TEAM'
                                                                             ELSE 'unknown' END,
        has_additional_pay                              = CASE TRIM(S.EHADDP) WHEN 'T' THEN 'TRUE'
                                                                             WHEN 'N' THEN 'FALSE'
                                                                             ELSE 'unknown' END,
        is_wage_dump                                    = CASE WHEN TRIM(S.EHWDMP) = 'Y' THEN 'TRUE' ELSE 'FALSE' END,
        earnings_history_truck_expense_account_number   = TRIM(S.EHTEXC),
        earnings_history_pay_period_end_date            = S.EHERND_key,
        earnings_history_expense_account_number         = TRIM(S.EHEXAC),
        is_expensed                                     = CASE WHEN TRIM(S.EHEXPF) = 'E' THEN 'TRUE' ELSE 'FALSE' END,
        earnings_history_expensed_book_month            = S.EHPYPD,
        earnings_history_expensed_book_year             = S.EHPYYR,
        earnings_history_check_date                     = S.EHCKDT_key,
        earnings_history_check_number                   = TRIM(S.EHCKNO),
        earnings_history_paid_book_month                = S.EHPBKM,
        earnings_history_paid_book_year                 = S.EHPBKY,
        is_voided                                       = CASE WHEN TRIM(S.EHSTAT) = 'V' THEN 'TRUE' ELSE 'FALSE' END,
        earnings_history_taxable_days_for_retroactivity = S.EHTXDY,
        is_on_hold                                      = CASE WHEN TRIM(S.EHHOLD) = 'H' THEN 'TRUE' ELSE 'FALSE' END,
        earnings_history_audit_user_code                = TRIM(S.EHAUSR),
        earnings_history_audit_date                     = S.EHADAT_key,
        earnings_history_audit_time                     = CASE LEN(CONVERT(VARCHAR, S.EHATIM))
                                                            WHEN 5 THEN CONVERT(TIME, CONCAT(LEFT(CONCAT('0',CONVERT(VARCHAR, S.EHATIM)),2),':',SUBSTRING(CONCAT('0',CONVERT(VARCHAR, S.EHATIM)),3,2)))
                                                            WHEN 6 THEN CONVERT(TIME, CONCAT(LEFT(CONVERT(VARCHAR, S.EHATIM),2),':',SUBSTRING(CONVERT(VARCHAR, S.EHATIM),3,2)))
                                                            ELSE NULL END
    FROM silver.ibmi_earnings_history T
    JOIN #DedupedEH S
      ON T.earnings_history_employee_code   = TRIM(S.EHEMP)
     AND T.earnings_history_pay_date        = S.EHPAYD_key
     AND T.earnings_history_sequence_number = S.EHSEQ
     AND T.earnings_history_pay_class_code  = TRIM(S.EHCLAS)
     AND T.earnings_history_check_date      = S.EHCKDT_key
     AND T.earnings_history_check_number    = TRIM(S.EHCKNO);

    /* -------------------------------
       Step 2: INSERT new rows
       ------------------------------- */
    INSERT INTO silver.ibmi_earnings_history
    (
      earnings_history_employee_code,
      earnings_history_company_code,
      earnings_history_run_code,
      earnings_history_benefit_package_code,
      earnings_history_department_code,
      earnings_history_division_code,
      earnings_history_job_description,
      earnings_history_pay_date,
      earnings_history_pay_week_number,
      earnings_history_sequence_number,
      earnings_history_quantity,
      earnings_history_unit_type_code,
      is_paid_hours,
      earnings_history_pay_class_code,
      earnings_history_pay_rate,
      earnings_history_per_unit_rate,
      earnings_history_gross_amount,
      earnings_history_pay_quantity_worked,
      earnings_history_load_number,
      earnings_history_dispatch_number,
      earnings_history_miles_loaded,
      earnings_history_miles_dead_head,
      earnings_history_truck_number,
      earnings_history_owner_code,
      earnings_history_origin_city,
      earnings_history_origin_state,
      earnings_history_destination_city,
      earnings_history_destination_state,
      earnings_history_description,
      is_solo_or_team,
      has_additional_pay,
      is_wage_dump,
      earnings_history_truck_expense_account_number,
      earnings_history_pay_period_end_date,
      earnings_history_expense_account_number,
      is_expensed,
      earnings_history_expensed_book_month,
      earnings_history_expensed_book_year,
      earnings_history_check_date,
      earnings_history_check_number,
      earnings_history_paid_book_month,
      earnings_history_paid_book_year,
      is_voided,
      earnings_history_taxable_days_for_retroactivity,
      is_on_hold,
      earnings_history_audit_user_code,
      earnings_history_audit_date,
      earnings_history_audit_time
    )
    SELECT
      TRIM(S.EHEMP),
      TRIM(S.EHCOMP),
      TRIM(S.EHRUN),
      TRIM(S.EHBPKG),
      TRIM(S.EHDEPT),
      TRIM(S.EHDVSN),
      TRIM(S.EHJOB),
      S.EHPAYD_key,
      S.EHWEEK,
      S.EHSEQ,
      S.EHQTY,
      TRIM(S.EHUNTY),
      CASE WHEN TRIM(S.EHPAID) = 'Y' THEN 'TRUE' ELSE 'FALSE' END,
      TRIM(S.EHCLAS),
      TRIM(S.EHRATC),
      S.EHRATE,
      S.EHGROS,
      S.EHQTYW,
      TRIM(S.EHORD),
      TRIM(S.EHDSP),
      S.EHLMIL,
      S.EHEMIL,
      TRIM(S.EHUNIT),
      TRIM(S.EHOWNR),
      TRIM(S.EHORGC),
      TRIM(S.EHORGS),
      TRIM(S.EHDSTC),
      TRIM(S.EHDSTS),
      TRIM(S.EHDESC),
      CASE TRIM(S.EHSTCD) WHEN 'S' THEN 'SOLO'
                          WHEN 'T' THEN 'TEAM'
                          ELSE 'unknown' END,
      CASE TRIM(S.EHADDP) WHEN 'T' THEN 'TRUE'
                          WHEN 'N' THEN 'FALSE'
                          ELSE 'unknown' END,
      CASE WHEN TRIM(S.EHWDMP) = 'Y' THEN 'TRUE' ELSE 'FALSE' END,
      TRIM(S.EHTEXC),
      S.EHERND_key,
      TRIM(S.EHEXAC),
      CASE WHEN TRIM(S.EHEXPF) = 'E' THEN 'TRUE' ELSE 'FALSE' END,
      S.EHPYPD,
      S.EHPYYR,
      S.EHCKDT_key,
      TRIM(S.EHCKNO),
      S.EHPBKM,
      S.EHPBKY,
      CASE WHEN TRIM(S.EHSTAT) = 'V' THEN 'TRUE' ELSE 'FALSE' END,
      S.EHTXDY,
      CASE WHEN TRIM(S.EHHOLD) = 'H' THEN 'TRUE' ELSE 'FALSE' END,
      TRIM(S.EHAUSR),
      S.EHADAT_key,
      CASE LEN(CONVERT(VARCHAR, S.EHATIM))
        WHEN 5 THEN CONVERT(TIME, CONCAT(LEFT(CONCAT('0',CONVERT(VARCHAR, S.EHATIM)),2),':',SUBSTRING(CONCAT('0',CONVERT(VARCHAR, S.EHATIM)),3,2)))
        WHEN 6 THEN CONVERT(TIME, CONCAT(LEFT(CONVERT(VARCHAR, S.EHATIM),2),':',SUBSTRING(CONVERT(VARCHAR, S.EHATIM),3,2)))
        ELSE NULL END
    FROM #DedupedEH S
    WHERE NOT EXISTS (
        SELECT 1
        FROM silver.ibmi_earnings_history T
        WHERE T.earnings_history_employee_code   = TRIM(S.EHEMP)
          AND T.earnings_history_pay_date        = S.EHPAYD_key
          AND T.earnings_history_sequence_number = S.EHSEQ
          AND T.earnings_history_pay_class_code  = TRIM(S.EHCLAS)
          AND T.earnings_history_check_date      = S.EHCKDT_key
          AND T.earnings_history_check_number    = TRIM(S.EHCKNO)
    );

    DROP TABLE #DedupedEH;
END;