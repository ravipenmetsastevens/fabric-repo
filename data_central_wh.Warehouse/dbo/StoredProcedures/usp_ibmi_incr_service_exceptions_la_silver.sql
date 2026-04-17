CREATE   PROCEDURE [dbo].[usp_ibmi_incr_service_exceptions_la_silver]
AS
BEGIN
    SET NOCOUNT ON;

    /*==============================================================
      STEP 1: Deduplicate the bronze source
      Keys: TRIM(a.[LAORD#]) AS serv_exc_la_load_number, a.[LASEQ#] AS serv_exc_la_sequence_number
    ==============================================================*/
    IF OBJECT_ID('tempdb..#DedupedServiceExceptionsLA') IS NOT NULL 
        DROP TABLE #DedupedServiceExceptionsLA;

    SELECT *
    INTO #DedupedServiceExceptionsLA
    FROM (
        SELECT *,
               ROW_NUMBER() OVER (
                    PARTITION BY TRIM([LAORD#]), [LASEQ#]
                    ORDER BY loadDate DESC, recordNumber DESC
               ) AS rn
        FROM data_central_lh.dbo.ibmi_incr_service_exceptions_la_bronze
    ) a
    WHERE rn = 1;

    /*==============================================================
      STEP 2: UPDATE existing rows in silver.ibmi_service_exceptions_la
    ==============================================================*/
    UPDATE TGT
    SET
        serv_exc_la_stop_number = CONVERT(INT, SRC.[LASTP#]),
        serv_exc_la_late_appt_date = LAADT2.date_key_pk,
        serv_exc_la_late_appt_time =
            CASE 
                WHEN TRY_CAST(TRIM(SRC.LAATM2) AS INT) BETWEEN 0 AND 2359
                     AND LEN(TRIM(SRC.LAATM2)) = 4
                THEN TIMEFROMPARTS(LEFT(SRC.LAATM2,2), RIGHT(SRC.LAATM2,2), 0, 0, 0)
                ELSE NULL 
            END,
        serv_exc_la_arrival_date = LAARDT.date_key_pk,
        serv_exc_la_arrival_time =
            CASE 
                WHEN TRY_CAST(TRIM(SRC.LAARTM) AS INT) BETWEEN 0 AND 2359
                     AND LEN(TRIM(SRC.LAARTM)) = 4
                THEN TIMEFROMPARTS(LEFT(SRC.LAARTM,2), RIGHT(SRC.LAARTM,2), 0, 0, 0)
                ELSE NULL 
            END
    FROM silver.ibmi_service_exceptions_la AS TGT
    JOIN #DedupedServiceExceptionsLA AS SRC
        ON TGT.serv_exc_la_load_number = TRIM(SRC.[LAORD#])
       AND TGT.serv_exc_la_sequence_number = CONVERT(INT, SRC.[LASEQ#])
    LEFT JOIN data_central_wh.gold.dim_date AS LAADT2 ON SRC.LAADT2 = LAADT2.date_ordinal
    LEFT JOIN data_central_wh.gold.dim_date AS LAARDT ON SRC.LAARDT = LAARDT.date_ordinal;

    /*==============================================================
      STEP 3: INSERT new rows
    ==============================================================*/
    INSERT INTO silver.ibmi_service_exceptions_la (
        serv_exc_la_load_number,
        serv_exc_la_sequence_number,
        serv_exc_la_stop_number,
        serv_exc_la_late_appt_date,
        serv_exc_la_late_appt_time,
        serv_exc_la_arrival_date,
        serv_exc_la_arrival_time
    )
    SELECT
        TRIM(SRC.[LAORD#]),
        CONVERT(INT, SRC.[LASEQ#]),
        CONVERT(INT, SRC.[LASTP#]),
        LAADT2.date_key_pk,
        CASE 
            WHEN TRY_CAST(TRIM(SRC.LAATM2) AS INT) BETWEEN 0 AND 2359
                 AND LEN(TRIM(SRC.LAATM2)) = 4
            THEN TIMEFROMPARTS(LEFT(SRC.LAATM2,2), RIGHT(SRC.LAATM2,2), 0, 0, 0)
            ELSE NULL 
        END,
        LAARDT.date_key_pk,
        CASE 
            WHEN TRY_CAST(TRIM(SRC.LAARTM) AS INT) BETWEEN 0 AND 2359
                 AND LEN(TRIM(SRC.LAARTM)) = 4
            THEN TIMEFROMPARTS(LEFT(SRC.LAARTM,2), RIGHT(SRC.LAARTM,2), 0, 0, 0)
            ELSE NULL 
        END
    FROM #DedupedServiceExceptionsLA AS SRC
    LEFT JOIN data_central_wh.gold.dim_date AS LAADT2 ON SRC.LAADT2 = LAADT2.date_ordinal
    LEFT JOIN data_central_wh.gold.dim_date AS LAARDT ON SRC.LAARDT = LAARDT.date_ordinal
    WHERE NOT EXISTS (
        SELECT 1 FROM silver.ibmi_service_exceptions_la AS TGT
        WHERE TGT.serv_exc_la_load_number = TRIM(SRC.[LAORD#])
          AND TGT.serv_exc_la_sequence_number = CONVERT(INT, SRC.[LASEQ#])
    );

    DROP TABLE #DedupedServiceExceptionsLA;
END;