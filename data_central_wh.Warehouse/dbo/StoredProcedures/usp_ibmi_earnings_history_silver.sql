/***************************************************************************************************
Procedure:          dbo.usp_ibmi_earnings_history_silver
Create Date:        2024-05-07
Author:             Jeremy Shahan
Description:        Truncate and load of Earnings History Silver
Called by:          Azure Data Factory
Pipeline:           ibmi_earnings_history
Affected table(s):  silver.ibmi_earnings_history
Usage:              EXEC dbo.usp_ibmi_earnings_history
****************************************************************************************************
SUMMARY OF CHANGES
Date(yyyy-mm-dd)    Author              Comments
------------------- ------------------ ------------------------------------------------------------
1                   
***************************************************************************************************/

CREATE   PROCEDURE [dbo].[usp_ibmi_earnings_history_silver]
AS
BEGIN
    SET NOCOUNT ON;

    DELETE FROM silver.ibmi_earnings_history;

    INSERT INTO silver.ibmi_earnings_history
    SELECT
          TRIM(a.EHEMP)   AS earnings_history_employee_code
        , TRIM(a.EHCOMP)  AS earnings_history_company_code
        , TRIM(a.EHRUN)   AS earnings_history_run_code
        , TRIM(a.EHBPKG)  AS earnings_history_benefit_package_code
        , TRIM(a.EHDEPT)  AS earnings_history_department_code
        , TRIM(a.EHDVSN)  AS earnings_history_division_code
        , TRIM(a.EHJOB)   AS earnings_history_job_description
        , EHPAYD.date_key_pk   AS earnings_history_pay_date
        , a.EHWEEK        AS earnings_history_pay_week_number
        , a.EHSEQ         AS earnings_history_sequence_number
        , a.EHQTY         AS earnings_history_quantity
        , TRIM(a.EHUNTY)  AS earnings_history_unit_type_code
        -- , EHTYPE Unused
        , CASE WHEN TRIM(a.EHPAID) = 'Y' THEN 'TRUE' ELSE 'FALSE' END AS is_paid_hours
        , TRIM(a.EHCLAS)  AS earnings_history_pay_class_code
        , TRIM(a.EHRATC)  AS earnings_history_pay_rate  -- Can be alpha or numeric
        -- , EHWDCD Unused
        , a.EHRATE        AS earnings_history_per_unit_rate
        , a.EHGROS        AS earnings_history_gross_amount
        , a.EHQTYW        AS earnings_history_pay_quantity_worked
        , TRIM(a.EHORD)   AS earnings_history_load_number
        , TRIM(a.EHDSP)   AS earnings_history_dispatch_number
        , a.EHLMIL        AS earnings_history_miles_loaded
        , a.EHEMIL        AS earnings_history_miles_dead_head
        , TRIM(a.EHUNIT)  AS earnings_history_truck_number
        , TRIM(a.EHOWNR)  AS earnings_history_owner_code
        , TRIM(a.EHORGC)  AS earnings_history_origin_city
        , TRIM(a.EHORGS)  AS earnings_history_origin_state
        , TRIM(a.EHDSTC)  AS earnings_history_destination_city
        , TRIM(a.EHDSTS)  AS earnings_history_destination_state
        , TRIM(a.EHDESC)  AS earnings_history_description
        , CASE TRIM(a.EHSTCD)
              WHEN 'S' THEN 'SOLO'
              WHEN 'T' THEN 'TEAM'
              ELSE 'unknown'
          END AS is_solo_or_team
        , CASE TRIM(a.EHADDP)
              WHEN 'T' THEN 'TRUE'
              WHEN 'N' THEN 'FALSE'
              ELSE 'unknown'
          END AS has_additional_pay
        , CASE WHEN TRIM(a.EHWDMP) = 'Y' THEN 'TRUE' ELSE 'FALSE' END AS is_wage_dump
        , TRIM(a.EHTEXC)  AS earnings_history_truck_expense_account_number
        -- , EHTCC Unused
        -- , EHBGDT Unused
        , EHERND.date_key_pk AS earnings_history_pay_period_end_date
        -- , EHLACT Unused
        , TRIM(a.EHEXAC)  AS earnings_history_expense_account_number
        -- , EHCC Unused
        -- , EHPC1 Unused
        -- , EHEXA2 Unused
        -- , EHCC2 Unused
        -- , EHPC2 Unused
        -- , EHEXA3 Unused
        -- , EHCC3 Unused
        -- , EHPC3 Unused
        , CASE WHEN TRIM(a.EHEXPF) = 'E' THEN 'TRUE' ELSE 'FALSE' END AS is_expensed
        , a.EHPYPD        AS earnings_history_expensed_book_month
        , a.EHPYYR        AS earnings_history_expensed_book_year
        , EHCKDT.date_key_pk AS earnings_history_check_date
        -- , EHCKCD Unused
        , TRIM(a.EHCKNO)  AS earnings_history_check_number
        , a.EHPBKM        AS earnings_history_paid_book_month
        , a.EHPBKY        AS earnings_history_paid_book_year
        , CASE WHEN TRIM(a.EHSTAT) = 'V' THEN 'TRUE' ELSE 'FALSE' END AS is_voided
        -- , EHVDDT Unused
        -- , EHVBKM Unused
        -- , EHVBKY Unused
        , a.EHTXDY        AS earnings_history_taxable_days_for_retroactivity -- Need clarification
        , CASE WHEN TRIM(a.EHHOLD) = 'H' THEN 'TRUE' ELSE 'FALSE' END AS is_on_hold
        , TRIM(a.EHAUSR)  AS earnings_history_audit_user_code
        , EHADAT.date_key_pk AS earnings_history_audit_date
        , CASE LEN(CONVERT(VARCHAR, a.EHATIM))
              WHEN 5 THEN CONVERT(TIME, CONCAT(
                                LEFT(CONCAT('0', CONVERT(VARCHAR, a.EHATIM)), 2), ':',
                                SUBSTRING(CONCAT('0', CONVERT(VARCHAR, a.EHATIM)), 3, 2)))
              WHEN 6 THEN CONVERT(TIME, CONCAT(
                                LEFT(CONVERT(VARCHAR, a.EHATIM), 2), ':',
                                SUBSTRING(CONVERT(VARCHAR, a.EHATIM), 3, 2)))
              ELSE NULL
          END AS earnings_history_audit_time
    FROM data_central_lh.dbo.ibmi_earnings_history_bronze a
    LEFT JOIN gold.dim_date EHPAYD ON a.EHPAYD = EHPAYD.date_ordinal
    LEFT JOIN gold.dim_date EHERND ON a.EHERND = EHERND.date_ordinal
    LEFT JOIN gold.dim_date EHCKDT ON a.EHCKDT = EHCKDT.date_ordinal
    LEFT JOIN gold.dim_date EHADAT ON a.EHADAT = EHADAT.date_ordinal;
END;