CREATE     PROCEDURE [dbo].[usp_ibmi_incr_stopoff_og_appt_silver]
AS
BEGIN
    SET NOCOUNT ON;

    IF OBJECT_ID('tempdb..#DedupedStopoffOgAppt', 'U') IS NOT NULL
        DROP TABLE #DedupedStopoffOgAppt;

    ---------------------------------------------------------------------
    -- Step 0: Deduplicate incremental source on business key
    --   Key (bronze): S2ORD, S2STP
    ---------------------------------------------------------------------
    SELECT
        a.*,
        S2ADT1.date_key_pk AS S2ADT1_key,
        S2ADT2.date_key_pk AS S2ADT2_key
    INTO #DedupedStopoffOgAppt
    FROM (
        SELECT *,
               ROW_NUMBER() OVER (
                   PARTITION BY TRIM(S2ORD), S2STP
                   ORDER BY loadDate DESC, recordNumber DESC
               ) AS rn
        FROM data_central_lh.dbo.ibmi_incr_stopoff_og_appt_bronze2
    ) a
    LEFT JOIN data_central_wh.gold.dim_date S2ADT1
        ON a.S2ADT1 = S2ADT1.date_ordinal
    LEFT JOIN data_central_wh.gold.dim_date S2ADT2
        ON a.S2ADT2 = S2ADT2.date_ordinal
    WHERE a.rn = 1;

    ---------------------------------------------------------------------
    -- Step 1: UPDATE existing rows in silver
    --   Key (silver): stopoff_og_load_number, stopoff_og_stop_number
    ---------------------------------------------------------------------
    UPDATE TGT
    SET
          stopoff_og_load_number       = TRIM(SRC.S2ORD)
        , stopoff_og_stop_number       = SRC.S2STP
        , stopoff_og_appt_early_date   = SRC.S2ADT1_key
        , stopoff_og_appt_late_date    = SRC.S2ADT2_key
        , stopoff_og_appt_early_time   = CASE 
                                            WHEN CONVERT(INT, SRC.S2ATM1) <= 2359 
                                                 AND LEN(TRIM(SRC.S2ATM1)) = 4 
                                                 AND CONVERT(INT, RIGHT(TRIM(SRC.S2ATM1), 2)) < 60
                                            THEN CONVERT(
                                                     TIME(0),
                                                     CONCAT(
                                                         LEFT(SRC.S2ATM1, 2),
                                                         ':',
                                                         RIGHT(SRC.S2ATM1, 2)
                                                     )
                                                 )
                                            ELSE NULL 
                                          END
        , stopoff_og_appt_late_time    = CASE 
                                            WHEN CONVERT(INT, SRC.S2ATM2) <= 2359 
                                                 AND LEN(TRIM(SRC.S2ATM2)) = 4 
                                                 AND CONVERT(INT, RIGHT(TRIM(SRC.S2ATM2), 2)) < 60
                                            THEN CONVERT(
                                                     TIME(0),
                                                     CONCAT(
                                                         LEFT(SRC.S2ATM2, 2),
                                                         ':',
                                                         RIGHT(SRC.S2ATM2, 2)
                                                     )
                                                 )
                                            ELSE NULL 
                                          END
    FROM silver.ibmi_stopoff_og_appt AS TGT
    JOIN #DedupedStopoffOgAppt       AS SRC
      ON TGT.stopoff_og_load_number = TRIM(SRC.S2ORD)
     AND TGT.stopoff_og_stop_number = SRC.S2STP;

    ---------------------------------------------------------------------
    -- Step 2: INSERT new rows that are not in silver
    ---------------------------------------------------------------------
    INSERT INTO silver.ibmi_stopoff_og_appt
    (
          stopoff_og_load_number
        , stopoff_og_stop_number
        , stopoff_og_appt_early_date
        , stopoff_og_appt_late_date
        , stopoff_og_appt_early_time
        , stopoff_og_appt_late_time
    )
    SELECT
          TRIM(SRC.S2ORD)                                              AS stopoff_og_load_number
        , SRC.S2STP                                                    AS stopoff_og_stop_number
        , SRC.S2ADT1_key                                               AS stopoff_og_appt_early_date
        , SRC.S2ADT2_key                                               AS stopoff_og_appt_late_date
        , CASE 
              WHEN CONVERT(INT, SRC.S2ATM1) <= 2359 
                   AND LEN(TRIM(SRC.S2ATM1)) = 4 
                   AND CONVERT(INT, RIGHT(TRIM(SRC.S2ATM1), 2)) < 60
              THEN CONVERT(
                       TIME(0),
                       CONCAT(
                           LEFT(SRC.S2ATM1, 2),
                           ':',
                           RIGHT(SRC.S2ATM1, 2)
                       )
                   )
              ELSE NULL 
          END                                                          AS stopoff_og_appt_early_time
        , CASE 
              WHEN CONVERT(INT, SRC.S2ATM2) <= 2359 
                   AND LEN(TRIM(SRC.S2ATM2)) = 4 
                   AND CONVERT(INT, RIGHT(TRIM(SRC.S2ATM2), 2)) < 60
              THEN CONVERT(
                       TIME(0),
                       CONCAT(
                           LEFT(SRC.S2ATM2, 2),
                           ':',
                           RIGHT(SRC.S2ATM2, 2)
                       )
                   )
              ELSE NULL 
          END                                                          AS stopoff_og_appt_late_time
    FROM #DedupedStopoffOgAppt AS SRC
    WHERE NOT EXISTS (
        SELECT 1
        FROM silver.ibmi_stopoff_og_appt AS T
        WHERE T.stopoff_og_load_number = TRIM(SRC.S2ORD)
          AND T.stopoff_og_stop_number = SRC.S2STP
    );

    DROP TABLE #DedupedStopoffOgAppt;
END;