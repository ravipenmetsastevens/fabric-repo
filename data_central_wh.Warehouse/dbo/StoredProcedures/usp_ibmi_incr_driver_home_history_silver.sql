CREATE   PROCEDURE [dbo].[usp_ibmi_incr_driver_home_history_silver]
AS
BEGIN
    SET NOCOUNT ON;

    /* ------------------------------------------------------------
       Step 0: Prep + dedupe bronze on key
       ------------------------------------------------------------ */
    IF OBJECT_ID('tempdb..#DRV_HOME_HIST_Deduped','U') IS NOT NULL DROP TABLE #DRV_HOME_HIST_Deduped;

    WITH Prep AS (
        SELECT
            TRIM(a.DPCODE)        AS drv_home_hist_driver_code,
            DPPHAD.date_key_pk    AS drv_home_hist_previous_arrival_date,
            DPHDDT.date_key_pk    AS drv_home_hist_departure_date,
            a.loadDate,
            a.recordNumber
        FROM data_central_lh.dbo.ibmi_incr_driver_home_history_bronze a
        LEFT JOIN data_central_wh.gold.dim_date DPPHAD ON a.DPPHAD = DPPHAD.date_ordinal
        LEFT JOIN data_central_wh.gold.dim_date DPHDDT ON a.DPHDDT = DPHDDT.date_ordinal
    )
    SELECT *
    INTO #DRV_HOME_HIST_Deduped
    FROM (
        SELECT p.*,
               ROW_NUMBER() OVER (
                   PARTITION BY p.drv_home_hist_driver_code, p.drv_home_hist_previous_arrival_date
                   ORDER BY p.loadDate DESC, p.recordNumber DESC
               ) AS rn
        FROM Prep p
    ) x
    WHERE x.rn = 1;

    /* ------------------------------------------------------------
       Step 1: UPDATE matches
       ------------------------------------------------------------ */
    UPDATE T
       SET T.drv_home_hist_departure_date = S.drv_home_hist_departure_date
    FROM silver.ibmi_driver_home_history T
    JOIN #DRV_HOME_HIST_Deduped S
      ON T.drv_home_hist_driver_code          = S.drv_home_hist_driver_code
     AND T.drv_home_hist_previous_arrival_date = S.drv_home_hist_previous_arrival_date;

    /* ------------------------------------------------------------
       Step 2: INSERT new rows
       ------------------------------------------------------------ */
    INSERT INTO silver.ibmi_driver_home_history
    (
        drv_home_hist_driver_code,
        drv_home_hist_previous_arrival_date,
        drv_home_hist_departure_date
    )
    SELECT
        S.drv_home_hist_driver_code,
        S.drv_home_hist_previous_arrival_date,
        S.drv_home_hist_departure_date
    FROM #DRV_HOME_HIST_Deduped S
    WHERE NOT EXISTS (
        SELECT 1
        FROM silver.ibmi_driver_home_history T
        WHERE T.drv_home_hist_driver_code          = S.drv_home_hist_driver_code
          AND T.drv_home_hist_previous_arrival_date = S.drv_home_hist_previous_arrival_date
    );

    DROP TABLE #DRV_HOME_HIST_Deduped;
END;