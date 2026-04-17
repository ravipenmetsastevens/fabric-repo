CREATE     PROCEDURE [dbo].[usp_ibmi_incr_service_exceptions_edi_silver]
AS
BEGIN
    SET NOCOUNT ON;

    IF OBJECT_ID('tempdb..#DedupedServiceExceptions', 'U') IS NOT NULL
        DROP TABLE #DedupedServiceExceptions;

    ---------------------------------------------------------------------
    -- Step 0: Deduplicate incremental source on business key
    --   Key (bronze): ERORD, ERSTOP, ERCODE, ERSEQ
    ---------------------------------------------------------------------
    SELECT *
    INTO #DedupedServiceExceptions
    FROM (
        SELECT  *,
                ROW_NUMBER() OVER (
                    PARTITION BY TRIM(ERORD), ERSTOP, TRIM(ERCODE), ERSEQ
                    ORDER BY loadDate DESC, recordNumber DESC
                ) AS rn
        FROM data_central_lh.dbo.ibmi_incr_service_exceptions_edi_bronze
    ) a
    WHERE rn = 1;

    ---------------------------------------------------------------------
    -- Step 1: UPDATE existing silver rows
    --   Key (silver): se_load_number, se_stop_number, se_edi_code, se_record_number
    ---------------------------------------------------------------------
    UPDATE TGT
    SET
          se_edi_code        = TRIM(SRC.ERCODE)
        , se_status_type     = TRIM(SRC.ERSTYP)
        , se_create_date     = TRY_CONVERT(
                                   DATE,
                                   CONVERT(VARCHAR(6), CONVERT(INT, SRC.EREDAT)),
                                   12
                               )
        , se_create_time     = CASE 
                                  WHEN SRC.ERETIM <= 2359 
                                       AND LEN(CONVERT(VARCHAR(4), CONVERT(INT, SRC.ERETIM))) = 4 
                                      THEN TIMEFROMPARTS(
                                               LEFT(CONVERT(INT, SRC.ERETIM), 2),
                                               RIGHT(CONVERT(INT, SRC.ERETIM), 2),
                                               0, 0, 0
                                           )
                                  WHEN SRC.ERETIM <= 2359 
                                       AND LEN(CONVERT(VARCHAR(4), CONVERT(INT, SRC.ERETIM))) = 3 
                                      THEN TIMEFROMPARTS(
                                               LEFT(CONVERT(INT, SRC.ERETIM), 1),
                                               RIGHT(CONVERT(INT, SRC.ERETIM), 2),
                                               0, 0, 0
                                           )
                                  WHEN SRC.ERETIM <= 2359 
                                       AND LEN(CONVERT(VARCHAR(4), CONVERT(INT, SRC.ERETIM))) IN (1,2)
                                      THEN TIMEFROMPARTS(0, CONVERT(INT, SRC.ERETIM), 0, 0, 0)
                                  ELSE NULL 
                              END
        , se_remarks         = TRIM(SRC.ERREM)
        , se_changed_date    = CASE 
                                  WHEN SRC.ERSDAT > 0
                                       AND LEN(CONVERT(VARCHAR(6), CONVERT(INT, SRC.ERSDAT))) = 6
                                      THEN DATEFROMPARTS(
                                               '20' + RIGHT(CONVERT(VARCHAR(6), CONVERT(INT, SRC.ERSDAT)), 2),
                                               LEFT(CONVERT(VARCHAR(6), CONVERT(INT, SRC.ERSDAT)), 2),
                                               SUBSTRING(CONVERT(VARCHAR(6), CONVERT(INT, SRC.ERSDAT)), 3, 2)
                                           )
                                  WHEN SRC.ERSDAT > 0
                                       AND LEN(CONVERT(VARCHAR(6), CONVERT(INT, SRC.ERSDAT))) = 5
                                      THEN DATEFROMPARTS(
                                               '20' + RIGHT(CONVERT(VARCHAR(6), CONVERT(INT, SRC.ERSDAT)), 2),
                                               LEFT(CONVERT(VARCHAR(6), CONVERT(INT, SRC.ERSDAT)), 1),
                                               SUBSTRING(CONVERT(VARCHAR(6), CONVERT(INT, SRC.ERSDAT)), 2, 2)
                                           )
                                  ELSE NULL 
                              END
        , se_changed_time    = CASE 
                                  WHEN SRC.ERSTIM <= 2359 
                                       AND LEN(CONVERT(VARCHAR(4), CONVERT(INT, SRC.ERSTIM))) = 4 
                                      THEN TIMEFROMPARTS(
                                               LEFT(CONVERT(INT, SRC.ERSTIM), 2),
                                               RIGHT(CONVERT(INT, SRC.ERSTIM), 2),
                                               0, 0, 0
                                           )
                                  WHEN SRC.ERSTIM <= 2359 
                                       AND LEN(CONVERT(VARCHAR(4), CONVERT(INT, SRC.ERSTIM))) = 3 
                                      THEN TIMEFROMPARTS(
                                               LEFT(CONVERT(INT, SRC.ERSTIM), 1),
                                               RIGHT(CONVERT(INT, SRC.ERSTIM), 2),
                                               0, 0, 0
                                           )
                                  WHEN SRC.ERSTIM <= 2359 
                                       AND LEN(CONVERT(VARCHAR(4), CONVERT(INT, SRC.ERSTIM))) IN (1,2)
                                      THEN TIMEFROMPARTS(0, CONVERT(INT, SRC.ERSTIM), 0, 0, 0)
                                  ELSE NULL 
                              END
        , se_reason_code     = RIGHT(SRC.ERLATE, 2)
        , se_audit_user_code = TRIM(SRC.ERINIT)
        , se_stop_time_zone  = SRC.ERTMZN
        , is_daylight_savings_time =
              CASE TRIM(SRC.ERDSTM)
                  WHEN 'Y' THEN 'TRUE'
                  WHEN 'N' THEN 'FALSE'
                  ELSE 'unknown'
              END
    FROM silver.ibmi_service_exceptions_edi AS TGT
    JOIN #DedupedServiceExceptions          AS SRC
      ON TGT.se_load_number      = TRIM(SRC.ERORD)
     AND TGT.se_stop_number   = SRC.ERSTOP
     AND TGT.se_edi_code         = TRIM(SRC.ERCODE)
     AND TGT.se_record_number      = SRC.ERSEQ;

    ---------------------------------------------------------------------
    -- Step 2: INSERT new rows that are not in silver
    ---------------------------------------------------------------------
    INSERT INTO silver.ibmi_service_exceptions_edi
    (
          se_load_number
        , se_stop_number
        , se_edi_code
        , se_record_number
        , se_status_type
        , se_create_date
        , se_create_time
        , se_remarks
        , se_changed_date
        , se_changed_time
        , se_reason_code
        , se_audit_user_code
        , se_stop_time_zone
        , is_daylight_savings_time
    )
    SELECT
          TRIM(SRC.ERORD)                                                AS se_load_number
        , SRC.ERSTOP                                                     AS se_stop_number
        , TRIM(SRC.ERCODE)                                               AS se_edi_code
        , SRC.ERSEQ                                                      AS se_record_number
        , TRIM(SRC.ERSTYP)                                               AS se_status_type
        , TRY_CONVERT(
              DATE,
              CONVERT(VARCHAR(6), CONVERT(INT, SRC.EREDAT)),
              12
          )                                                              AS se_create_date
        , CASE 
              WHEN SRC.ERETIM <= 2359 
                   AND LEN(CONVERT(VARCHAR(4), CONVERT(INT, SRC.ERETIM))) = 4 
                  THEN TIMEFROMPARTS(
                           LEFT(CONVERT(INT, SRC.ERETIM), 2),
                           RIGHT(CONVERT(INT, SRC.ERETIM), 2),
                           0, 0, 0
                       )
              WHEN SRC.ERETIM <= 2359 
                   AND LEN(CONVERT(VARCHAR(4), CONVERT(INT, SRC.ERETIM))) = 3 
                  THEN TIMEFROMPARTS(
                           LEFT(CONVERT(INT, SRC.ERETIM), 1),
                           RIGHT(CONVERT(INT, SRC.ERETIM), 2),
                           0, 0, 0
                       )
              WHEN SRC.ERETIM <= 2359 
                   AND LEN(CONVERT(VARCHAR(4), CONVERT(INT, SRC.ERETIM))) IN (1,2)
                  THEN TIMEFROMPARTS(0, CONVERT(INT, SRC.ERETIM), 0, 0, 0)
              ELSE NULL 
          END                                                            AS se_create_time
        , TRIM(SRC.ERREM)                                                AS se_remarks
        , CASE 
              WHEN SRC.ERSDAT > 0
                   AND LEN(CONVERT(VARCHAR(6), CONVERT(INT, SRC.ERSDAT))) = 6
                  THEN DATEFROMPARTS(
                           '20' + RIGHT(CONVERT(VARCHAR(6), CONVERT(INT, SRC.ERSDAT)), 2),
                           LEFT(CONVERT(VARCHAR(6), CONVERT(INT, SRC.ERSDAT)), 2),
                           SUBSTRING(CONVERT(VARCHAR(6), CONVERT(INT, SRC.ERSDAT)), 3, 2)
                       )
              WHEN SRC.ERSDAT > 0
                   AND LEN(CONVERT(VARCHAR(6), CONVERT(INT, SRC.ERSDAT))) = 5
                  THEN DATEFROMPARTS(
                           '20' + RIGHT(CONVERT(VARCHAR(6), CONVERT(INT, SRC.ERSDAT)), 2),
                           LEFT(CONVERT(VARCHAR(6), CONVERT(INT, SRC.ERSDAT)), 1),
                           SUBSTRING(CONVERT(VARCHAR(6), CONVERT(INT, SRC.ERSDAT)), 2, 2)
                       )
              ELSE NULL 
          END                                                            AS se_changed_date
        , CASE 
              WHEN SRC.ERSTIM <= 2359 
                   AND LEN(CONVERT(VARCHAR(4), CONVERT(INT, SRC.ERSTIM))) = 4 
                  THEN TIMEFROMPARTS(
                           LEFT(CONVERT(INT, SRC.ERSTIM), 2),
                           RIGHT(CONVERT(INT, SRC.ERSTIM), 2),
                           0, 0, 0
                       )
              WHEN SRC.ERSTIM <= 2359 
                   AND LEN(CONVERT(VARCHAR(4), CONVERT(INT, SRC.ERSTIM))) = 3 
                  THEN TIMEFROMPARTS(
                           LEFT(CONVERT(INT, SRC.ERSTIM), 1),
                           RIGHT(CONVERT(INT, SRC.ERSTIM), 2),
                           0, 0, 0
                       )
              WHEN SRC.ERSTIM <= 2359 
                   AND LEN(CONVERT(VARCHAR(4), CONVERT(INT, SRC.ERSTIM))) IN (1,2)
                  THEN TIMEFROMPARTS(0, CONVERT(INT, SRC.ERSTIM), 0, 0, 0)
              ELSE NULL 
          END                                                            AS se_changed_time
        , RIGHT(SRC.ERLATE, 2)                                           AS se_reason_code
        , TRIM(SRC.ERINIT)                                               AS se_audit_user_code
        , SRC.ERTMZN                                                     AS se_stop_time_zone
        , CASE TRIM(SRC.ERDSTM)
              WHEN 'Y' THEN 'TRUE'
              WHEN 'N' THEN 'FALSE'
              ELSE 'unknown'
          END                                                            AS is_daylight_savings_time
    FROM #DedupedServiceExceptions AS SRC
    WHERE NOT EXISTS (
        SELECT 1
        FROM silver.ibmi_service_exceptions_edi AS T
        WHERE T.se_load_number     = TRIM(SRC.ERORD)
          AND T.se_stop_number  = SRC.ERSTOP
          AND T.se_edi_code        = TRIM(SRC.ERCODE)
          AND T.se_record_number     = SRC.ERSEQ
    );

    DROP TABLE #DedupedServiceExceptions;
END;