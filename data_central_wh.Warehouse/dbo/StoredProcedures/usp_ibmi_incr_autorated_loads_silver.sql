CREATE   PROCEDURE [dbo].[usp_ibmi_incr_autorated_loads_silver]
AS
BEGIN
    SET NOCOUNT ON;

    /* ------------------------------------------------------------
       Step 0: Prep + dedupe bronze on the business key
       Key = CFORDER (autorated_load_number)
       ------------------------------------------------------------ */
    IF OBJECT_ID('tempdb..#AUTORATED_Deduped','U') IS NOT NULL
        DROP TABLE #AUTORATED_Deduped;

    WITH Prep AS
    (
        SELECT
              TRIM(a.CFORDER) AS autorated_load_number
            , CASE
                WHEN LEN(CONVERT(VARCHAR(8), a.CFDATE)) = 8
                    THEN DATEFROMPARTS(
                            LEFT(a.CFDATE,4),
                            SUBSTRING(CONVERT(VARCHAR(8),a.CFDATE),5,2),
                            RIGHT(a.CFDATE,2)
                         )
                ELSE NULL
              END AS autorated_rated_date
            , TRIM(a.CFCONFIRM) AS autorated_status_code
            , TRIM(a.CFCONTRID) AS autorated_contract_code
            , CASE
                WHEN LEN(CONVERT(VARCHAR(8), a.CFCONTDT)) = 8
                    THEN DATEFROMPARTS(
                            LEFT(a.CFCONTDT,4),
                            SUBSTRING(CONVERT(VARCHAR(8),a.CFCONTDT),5,2),
                            RIGHT(a.CFCONTDT,2)
                         )
                ELSE NULL
              END AS autorated_contract_date
            , CASE
                WHEN LEN(CONVERT(VARCHAR(8), a.CFEXPIREDT)) = 8
                    THEN DATEFROMPARTS(
                            LEFT(a.CFEXPIREDT,4),
                            SUBSTRING(CONVERT(VARCHAR(8),a.CFEXPIREDT),5,2),
                            RIGHT(a.CFEXPIREDT,2)
                         )
                ELSE NULL
              END AS autorated_rate_expiration_date
            , CASE
                WHEN LEN(CONVERT(VARCHAR(8), a.CFEFFECTDT)) = 8
                    THEN DATEFROMPARTS(
                            LEFT(a.CFEFFECTDT,4),
                            SUBSTRING(CONVERT(VARCHAR(8),a.CFEFFECTDT),5,2),
                            RIGHT(a.CFEFFECTDT,2)
                         )
                ELSE NULL
              END AS autorated_rate_effective_date
            , TRIM(a.CFBILLTO) AS autorated_billto_code
            , TRIM(a.CFOST) AS autorated_origin_state
            , TRIM(a.CFOCITY) AS autorated_origin_city_code
            , TRIM(a.CFDST) AS autorated_destination_state
            , TRIM(a.CFDCITY) AS autorated_destination_city_code
            , TRIM(a.CFOZIP) AS autorated_origin_zip
            , TRIM(a.CFDZIP) AS autorated_destination_zip
            , TRIM(a.CFRATETYP) AS autorated_rate_type_code
            , a.CFPERMILE AS autorated_rate_per_mile
            , a.CFMINIMUM AS autorated_minimum_rate
            , a.CFFLATRATE AS autorated_flat_rate
            , TRIM(a.CFRATERTN) AS autorated_rate_match_note
            , CASE
                WHEN LEN(CONVERT(VARCHAR(8), a.CFADDDATE)) = 8
                    THEN DATEFROMPARTS(
                            LEFT(a.CFADDDATE,4),
                            SUBSTRING(CONVERT(VARCHAR(8),a.CFADDDATE),5,2),
                            RIGHT(a.CFADDDATE,2)
                         )
                ELSE NULL
              END AS autorated_create_date
            , CASE
                WHEN LEN(CONVERT(VARCHAR(6), a.CFADDTIME)) = 6
                    THEN TIMEFROMPARTS(
                            LEFT(a.CFADDTIME,2),
                            SUBSTRING(CONVERT(VARCHAR(6),a.CFADDTIME),3,2),
                            RIGHT(a.CFADDTIME,2),
                            0,0
                         )
                WHEN LEN(CONVERT(VARCHAR(6), a.CFADDTIME)) = 5
                    THEN TIMEFROMPARTS(
                            LEFT(a.CFADDTIME,1),
                            SUBSTRING(CONVERT(VARCHAR(6),a.CFADDTIME),2,2),
                            RIGHT(a.CFADDTIME,2),
                            0,0
                         )
                ELSE NULL
              END AS autorated_create_time
            , TRIM(a.CFADDUSER) AS autorated_create_user_code
            , a.loadDate
            , a.recordNumber
        FROM data_central_lh.dbo.ibmi_incr_autorated_loads_bronze a
    )
    SELECT *
    INTO #AUTORATED_Deduped
    FROM
    (
        SELECT
              p.*
            , ROW_NUMBER() OVER
              (
                  PARTITION BY p.autorated_load_number
                  ORDER BY p.loadDate DESC, p.recordNumber DESC
              ) AS rn
        FROM Prep p
    ) x
    WHERE x.rn = 1;

    /* ------------------------------------------------------------
       Step 1: UPDATE matches
       ------------------------------------------------------------ */
    UPDATE T
       SET T.autorated_rated_date              = S.autorated_rated_date
         , T.autorated_status_code             = S.autorated_status_code
         , T.autorated_contract_code           = S.autorated_contract_code
         , T.autorated_contract_date           = S.autorated_contract_date
         , T.autorated_rate_expiration_date    = S.autorated_rate_expiration_date
         , T.autorated_rate_effective_date     = S.autorated_rate_effective_date
         , T.autorated_billto_code             = S.autorated_billto_code
         , T.autorated_origin_state            = S.autorated_origin_state
         , T.autorated_origin_city_code        = S.autorated_origin_city_code
         , T.autorated_destination_state       = S.autorated_destination_state
         , T.autorated_destination_city_code   = S.autorated_destination_city_code
         , T.autorated_origin_zip              = S.autorated_origin_zip
         , T.autorated_destination_zip         = S.autorated_destination_zip
         , T.autorated_rate_type_code          = S.autorated_rate_type_code
         , T.autorated_rate_per_mile           = S.autorated_rate_per_mile
         , T.autorated_minimum_rate            = S.autorated_minimum_rate
         , T.autorated_flat_rate               = S.autorated_flat_rate
         , T.autorated_rate_match_note         = S.autorated_rate_match_note
         , T.autorated_create_date             = S.autorated_create_date
         , T.autorated_create_time             = S.autorated_create_time
         , T.autorated_create_user_code        = S.autorated_create_user_code
    FROM silver.ibmi_autorated_loads T
    INNER JOIN #AUTORATED_Deduped S
        ON T.autorated_load_number = S.autorated_load_number;

    /* ------------------------------------------------------------
       Step 2: INSERT non-matches
       ------------------------------------------------------------ */
    INSERT INTO silver.ibmi_autorated_loads
    (
          autorated_load_number
        , autorated_rated_date
        , autorated_status_code
        , autorated_contract_code
        , autorated_contract_date
        , autorated_rate_expiration_date
        , autorated_rate_effective_date
        , autorated_billto_code
        , autorated_origin_state
        , autorated_origin_city_code
        , autorated_destination_state
        , autorated_destination_city_code
        , autorated_origin_zip
        , autorated_destination_zip
        , autorated_rate_type_code
        , autorated_rate_per_mile
        , autorated_minimum_rate
        , autorated_flat_rate
        , autorated_rate_match_note
        , autorated_create_date
        , autorated_create_time
        , autorated_create_user_code
    )
    SELECT
          S.autorated_load_number
        , S.autorated_rated_date
        , S.autorated_status_code
        , S.autorated_contract_code
        , S.autorated_contract_date
        , S.autorated_rate_expiration_date
        , S.autorated_rate_effective_date
        , S.autorated_billto_code
        , S.autorated_origin_state
        , S.autorated_origin_city_code
        , S.autorated_destination_state
        , S.autorated_destination_city_code
        , S.autorated_origin_zip
        , S.autorated_destination_zip
        , S.autorated_rate_type_code
        , S.autorated_rate_per_mile
        , S.autorated_minimum_rate
        , S.autorated_flat_rate
        , S.autorated_rate_match_note
        , S.autorated_create_date
        , S.autorated_create_time
        , S.autorated_create_user_code
    FROM #AUTORATED_Deduped S
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM silver.ibmi_autorated_loads T
        WHERE T.autorated_load_number = S.autorated_load_number
    );

    DROP TABLE #AUTORATED_Deduped;
END;