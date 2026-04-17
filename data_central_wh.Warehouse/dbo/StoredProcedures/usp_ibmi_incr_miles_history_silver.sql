CREATE   PROCEDURE [dbo].[usp_ibmi_incr_miles_history_silver]
AS
BEGIN
    SET NOCOUNT ON;

    /* ------------------------------------------------------------
       Step 0: Prep + dedupe bronze on the composite key
       Key = DDDATE, DDDRCODE, DDUNIT, DDORDER, DDDISP
       ------------------------------------------------------------ */
    IF OBJECT_ID('tempdb..#MILES_HISTORY_Deduped','U') IS NOT NULL
        DROP TABLE #MILES_HISTORY_Deduped;

    WITH Prep AS
    (
        SELECT
              a.DDDATE                     AS mile_hist_date
            , TRIM(a.DDDRCODE)             AS mile_hist_driver_code
            , TRIM(a.DDUNIT)               AS mile_hist_truck_number
            , TRIM(a.DDORDER)              AS mile_hist_load_number
            , TRIM(a.DDDISP)               AS mile_hist_dispatch
            , a.DDPDMILES                  AS mile_hist_distributed_dispatch_miles
            , a.DDHMILES                   AS mile_hist_hub_miles
            , a.DDHRATIO                   AS mile_hist_hub_ratio
            , a.DDDISPTCH                  AS mile_hist_adj_dispatch_miles
            , a.DDGOALMILE                 AS mile_hist_goal_miles
            , a.loadDate
            , a.recordNumber
        FROM data_central_lh.dbo.ibmi_incr_miles_history_bronze a
    )
    SELECT *
    INTO #MILES_HISTORY_Deduped
    FROM
    (
        SELECT
              p.*
            , ROW_NUMBER() OVER
              (
                  PARTITION BY
                        p.mile_hist_date
                      , p.mile_hist_driver_code
                      , p.mile_hist_truck_number
                      , p.mile_hist_load_number
                      , p.mile_hist_dispatch
                  ORDER BY p.loadDate DESC, p.recordNumber DESC
              ) AS rn
        FROM Prep p
    ) x
    WHERE x.rn = 1;

    /* ------------------------------------------------------------
       Step 1: UPDATE matches
       ------------------------------------------------------------ */
    UPDATE T
       SET T.mile_hist_distributed_dispatch_miles = S.mile_hist_distributed_dispatch_miles
         , T.mile_hist_hub_miles                  = S.mile_hist_hub_miles
         , T.mile_hist_hub_ratio                  = S.mile_hist_hub_ratio
         , T.mile_hist_adj_dispatch_miles         = S.mile_hist_adj_dispatch_miles
         , T.mile_hist_goal_miles                 = S.mile_hist_goal_miles
    FROM silver.ibmi_miles_history T
    INNER JOIN #MILES_HISTORY_Deduped S
        ON T.mile_hist_date         = S.mile_hist_date
       AND T.mile_hist_driver_code  = S.mile_hist_driver_code
       AND T.mile_hist_truck_number = S.mile_hist_truck_number
       AND T.mile_hist_load_number  = S.mile_hist_load_number
       AND T.mile_hist_dispatch     = S.mile_hist_dispatch;

    /* ------------------------------------------------------------
       Step 2: INSERT non-matches
       ------------------------------------------------------------ */
    INSERT INTO silver.ibmi_miles_history
    (
          mile_hist_date
        , mile_hist_driver_code
        , mile_hist_truck_number
        , mile_hist_load_number
        , mile_hist_dispatch
        , mile_hist_distributed_dispatch_miles
        , mile_hist_hub_miles
        , mile_hist_hub_ratio
        , mile_hist_adj_dispatch_miles
        , mile_hist_goal_miles
    )
    SELECT
          S.mile_hist_date
        , S.mile_hist_driver_code
        , S.mile_hist_truck_number
        , S.mile_hist_load_number
        , S.mile_hist_dispatch
        , S.mile_hist_distributed_dispatch_miles
        , S.mile_hist_hub_miles
        , S.mile_hist_hub_ratio
        , S.mile_hist_adj_dispatch_miles
        , S.mile_hist_goal_miles
    FROM #MILES_HISTORY_Deduped S
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM silver.ibmi_miles_history T
        WHERE T.mile_hist_date         = S.mile_hist_date
          AND T.mile_hist_driver_code  = S.mile_hist_driver_code
          AND T.mile_hist_truck_number = S.mile_hist_truck_number
          AND T.mile_hist_load_number  = S.mile_hist_load_number
          AND T.mile_hist_dispatch     = S.mile_hist_dispatch
    );

    DROP TABLE #MILES_HISTORY_Deduped;
END;