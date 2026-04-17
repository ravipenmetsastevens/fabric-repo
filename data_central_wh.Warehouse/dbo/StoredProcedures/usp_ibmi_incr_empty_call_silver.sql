/***************************************************************************************************
Procedure:          dbo.usp_ibmi_incr_empty_call_silver
Create Date:        2026-02-23
Description:        Incremental (delta) load of Empty Call to Silver using INCR source.
Called by:          Fabric
Pipeline:           ibmi_empty_call
Affected table(s):  silver.ibmi_empty_call
Source table(s):    data_central_lh.dbo.ibmi_incr_empty_call_bronze
Dedupe / Upsert Keys:
                    CNUNIT, CNORD, CNDISP, CNCALL
Delete Driver Key:  CNORD (distinct load numbers present in this run)
Usage:              EXEC dbo.usp_ibmi_incr_empty_call_silver
***************************************************************************************************/
CREATE   PROCEDURE dbo.usp_ibmi_incr_empty_call_silver
AS
BEGIN
    SET NOCOUNT ON;

    /*========================================================
      1) Deduplicate INCR source rows by keys:
         CNUNIT, CNORD, CNDISP, CNCALL
         Latest wins: loadDate DESC, recordNumber DESC
    ========================================================*/
    IF OBJECT_ID('tempdb..#DedupedEmptyCall') IS NOT NULL DROP TABLE #DedupedEmptyCall;

    SELECT *
    INTO #DedupedEmptyCall
    FROM
    (
        SELECT
            a.*,
            ROW_NUMBER() OVER
            (
                PARTITION BY a.CNUNIT, a.CNORD, a.CNDISP, a.CNCALL
                ORDER BY a.loadDate DESC, a.recordNumber DESC
            ) AS rn
        FROM data_central_lh.dbo.ibmi_incr_empty_call_bronze a
    ) d
    WHERE d.rn = 1;

    /*========================================================
      1.5) Delete from target ONLY for DISTINCT CNORD in this run
           (prevents stale rows for the loads being re-sent)
    ========================================================*/
    IF OBJECT_ID('tempdb..#LoadsToDelete') IS NOT NULL DROP TABLE #LoadsToDelete;

    SELECT DISTINCT
        TRIM(CNORD) AS empty_call_load_number
    INTO #LoadsToDelete
    FROM #DedupedEmptyCall
    WHERE CNORD IS NOT NULL;

    DELETE TGT
    FROM silver.ibmi_empty_call TGT
    JOIN #LoadsToDelete D
      ON TGT.empty_call_load_number = D.empty_call_load_number;

    /*========================================================
      2) Transform source once (shared by UPDATE + INSERT)
    ========================================================*/
    IF OBJECT_ID('tempdb..#Xform') IS NOT NULL DROP TABLE #Xform;

    SELECT
          TRIM(a.CNUNIT)                                              AS empty_call_truck_number
        , TRIM(a.CNORD)                                               AS empty_call_load_number
        , TRIM(a.CNDISP)                                              AS empty_call_dispatch
        , TRIM(a.CNCALL)                                              AS empty_call_call_number
        , TRIM(a.CNTRLR)                                              AS empty_call_trailer_number
        , TRIM(a.CNDRV1)                                              AS empty_call_seat_1_driver_code
        , TRIM(a.CNDRV2)                                              AS empty_call_seat_2_driver_code
        , CNDATE.date_key_pk                                          AS empty_call_contact_date
        , CASE
            WHEN TRY_CONVERT(INT, a.CNTIME) < 2400 AND LEN(TRIM(a.CNTIME)) = 4
              THEN TRY_CONVERT(TIME(0), CONCAT(LEFT(a.CNTIME,2),':',RIGHT(a.CNTIME,2)))
            ELSE NULL
          END                                                         AS empty_call_contact_time
        , TRIM(a.CNCODE)                                              AS empty_call_type_code
        , TRIM(a.CNLOC)                                               AS empty_call_location_code
        , TRIM(a.CNSNM)                                               AS empty_call_city_short_name
        , TRIM(a.CNINIT)                                              AS empty_call_initials
        , TRIM(a.CNREST)                                              AS empty_call_message_details
        , a.CNHUB                                                     AS empty_call_hub_reading
        , a.CNTEMP                                                    AS empty_call_temp_reading
        , TRIM(a.CNHUBN)                                              AS empty_call_hub_flag

        -- match keys (post-trim)
        , TRIM(a.CNUNIT)                                              AS _k_truck
        , TRIM(a.CNORD)                                               AS _k_load
        , TRIM(a.CNDISP)                                              AS _k_disp
        , TRIM(a.CNCALL)                                              AS _k_call

    INTO #Xform
    FROM #DedupedEmptyCall a
    LEFT JOIN gold.dim_date CNDATE
      ON a.CNDATE = CNDATE.date_ordinal;

    /*========================================================
      3) UPDATE existing rows using FULL keys
    ========================================================*/
    UPDATE TGT
    SET
          empty_call_trailer_number      = SRC.empty_call_trailer_number
        , empty_call_seat_1_driver_code  = SRC.empty_call_seat_1_driver_code
        , empty_call_seat_2_driver_code  = SRC.empty_call_seat_2_driver_code
        , empty_call_contact_date        = SRC.empty_call_contact_date
        , empty_call_contact_time        = SRC.empty_call_contact_time
        , empty_call_type_code           = SRC.empty_call_type_code
        , empty_call_location_code       = SRC.empty_call_location_code
        , empty_call_city_short_name     = SRC.empty_call_city_short_name
        , empty_call_initials            = SRC.empty_call_initials
        , empty_call_message_details     = SRC.empty_call_message_details
        , empty_call_hub_reading         = SRC.empty_call_hub_reading
        , empty_call_temp_reading        = SRC.empty_call_temp_reading
        , empty_call_hub_flag            = SRC.empty_call_hub_flag
    FROM silver.ibmi_empty_call TGT
    JOIN #Xform SRC
      ON  TGT.empty_call_truck_number = SRC._k_truck
      AND TGT.empty_call_load_number  = SRC._k_load
      AND TGT.empty_call_dispatch     = SRC._k_disp
      AND TGT.empty_call_call_number  = SRC._k_call;

    /*========================================================
      4) INSERT new rows
    ========================================================*/
    INSERT INTO silver.ibmi_empty_call
    (
          empty_call_truck_number
        , empty_call_load_number
        , empty_call_dispatch
        , empty_call_call_number
        , empty_call_trailer_number
        , empty_call_seat_1_driver_code
        , empty_call_seat_2_driver_code
        , empty_call_contact_date
        , empty_call_contact_time
        , empty_call_type_code
        , empty_call_location_code
        , empty_call_city_short_name
        , empty_call_initials
        , empty_call_message_details
        , empty_call_hub_reading
        , empty_call_temp_reading
        , empty_call_hub_flag
    )
    SELECT
          empty_call_truck_number
        , empty_call_load_number
        , empty_call_dispatch
        , empty_call_call_number
        , empty_call_trailer_number
        , empty_call_seat_1_driver_code
        , empty_call_seat_2_driver_code
        , empty_call_contact_date
        , empty_call_contact_time
        , empty_call_type_code
        , empty_call_location_code
        , empty_call_city_short_name
        , empty_call_initials
        , empty_call_message_details
        , empty_call_hub_reading
        , empty_call_temp_reading
        , empty_call_hub_flag
    FROM #Xform SRC
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM silver.ibmi_empty_call TGT
        WHERE TGT.empty_call_truck_number = SRC._k_truck
          AND TGT.empty_call_load_number  = SRC._k_load
          AND TGT.empty_call_dispatch     = SRC._k_disp
          AND TGT.empty_call_call_number  = SRC._k_call
    );

    DROP TABLE #DedupedEmptyCall;
    DROP TABLE #LoadsToDelete;
    DROP TABLE #Xform;
END;