CREATE       PROCEDURE [dbo].[usp_ibmi_incr_driver_bio_silver]
AS
BEGIN
    SET NOCOUNT ON;

    /* ------------------------------------------------------------
       Step 0: Prep + dedupe bronze on (drv_bio_driver_code)
       ------------------------------------------------------------ */
    IF OBJECT_ID('tempdb..#DRV_BIO_Deduped','U') IS NOT NULL DROP TABLE #DRV_BIO_Deduped;

    WITH Prep AS (
        SELECT
            TRIM(a.DBDRVR)     AS drv_bio_driver_code,
            TRIM(a.DBJOIN)     AS drv_bio_why_join,
            TRIM(a.DBEXPR)     AS drv_bio_satisfaction_level,
            TRIM(a.DBEXPT)     AS drv_bio_expectations_met,
            TRIM(a.DBSHTG)     AS drv_bio_short_term_goals,
            TRIM(a.DBLNTG)     AS drv_bio_long_term_goals,
            TRIM(a.DBSUCC)     AS drv_bio_success,
            TRIM(a.DBFMLY)     AS drv_bio_family_life,
            TRIM(a.DBHTMC)     AS drv_bio_preferred_home_city,
            TRIM(a.DBHTMS)     AS drv_bio_preferred_home_state,
            TRIM(a.DBSAFE)     AS drv_bio_safe_haven,
            TRIM(a.DBHOBY)     AS drv_bio_hobbies,
            TRIM(a.DBSTVG)     AS drv_bio_stevens_goals,
            DBDATE.date_key_pk AS drv_bio_last_update_date,
            TRIM(a.DBUSER)     AS drv_bio_last_update_user_code,
            a.loadDate,
            a.recordNumber
        FROM data_central_lh.dbo.ibmi_incr_drivers_bio a
        LEFT JOIN gold.dim_date DBDATE ON a.DBDATE = DBDATE.date_key_pk
    )
    SELECT *
    INTO #DRV_BIO_Deduped
    FROM (
        SELECT p.*,
               ROW_NUMBER() OVER (
                   PARTITION BY p.drv_bio_driver_code
                   ORDER BY p.loadDate DESC, p.recordNumber DESC
               ) AS rn
        FROM Prep p
    ) x
    WHERE x.rn = 1;

    /* ------------------------------------------------------------
       Step 1: UPDATE existing rows
       ------------------------------------------------------------ */
    UPDATE T
       SET T.drv_bio_why_join              = S.drv_bio_why_join,
           T.drv_bio_satisfaction_level    = S.drv_bio_satisfaction_level,
           T.drv_bio_expectations_met      = S.drv_bio_expectations_met,
           T.drv_bio_short_term_goals      = S.drv_bio_short_term_goals,
           T.drv_bio_long_term_goals       = S.drv_bio_long_term_goals,
           T.drv_bio_success               = S.drv_bio_success,
           T.drv_bio_family_life           = S.drv_bio_family_life,
           T.drv_bio_preferred_home_city   = S.drv_bio_preferred_home_city,
           T.drv_bio_preferred_home_state  = S.drv_bio_preferred_home_state,
           T.drv_bio_safe_haven            = S.drv_bio_safe_haven,
           T.drv_bio_hobbies               = S.drv_bio_hobbies,
           T.drv_bio_stevens_goals         = S.drv_bio_stevens_goals,
           T.drv_bio_last_update_date      = S.drv_bio_last_update_date,
           T.drv_bio_last_update_user_code = S.drv_bio_last_update_user_code
    FROM silver.ibmi_driver_bio T
    JOIN #DRV_BIO_Deduped S
      ON T.drv_bio_driver_code = S.drv_bio_driver_code;

    /* ------------------------------------------------------------
       Step 2: INSERT new rows
       ------------------------------------------------------------ */
    INSERT INTO silver.ibmi_driver_bio
    (
        drv_bio_driver_code,
        drv_bio_why_join,
        drv_bio_satisfaction_level,
        drv_bio_expectations_met,
        drv_bio_short_term_goals,
        drv_bio_long_term_goals,
        drv_bio_success,
        drv_bio_family_life,
        drv_bio_preferred_home_city,
        drv_bio_preferred_home_state,
        drv_bio_safe_haven,
        drv_bio_hobbies,
        drv_bio_stevens_goals,
        drv_bio_last_update_date,
        drv_bio_last_update_user_code
    )
    SELECT
        S.drv_bio_driver_code,
        S.drv_bio_why_join,
        S.drv_bio_satisfaction_level,
        S.drv_bio_expectations_met,
        S.drv_bio_short_term_goals,
        S.drv_bio_long_term_goals,
        S.drv_bio_success,
        S.drv_bio_family_life,
        S.drv_bio_preferred_home_city,
        S.drv_bio_preferred_home_state,
        S.drv_bio_safe_haven,
        S.drv_bio_hobbies,
        S.drv_bio_stevens_goals,
        S.drv_bio_last_update_date,
        S.drv_bio_last_update_user_code
    FROM #DRV_BIO_Deduped S
    WHERE NOT EXISTS (
        SELECT 1
        FROM silver.ibmi_driver_bio T
        WHERE T.drv_bio_driver_code = S.drv_bio_driver_code
    );

    DROP TABLE #DRV_BIO_Deduped;
END;