CREATE   PROCEDURE [dbo].[usp_ibmi_incr_loaded_call_silver]
AS
BEGIN
    SET NOCOUNT ON;

    IF OBJECT_ID('tempdb..#DedupedLoadedCall') IS NOT NULL 
        DROP TABLE #DedupedLoadedCall;

    SELECT *
    INTO #DedupedLoadedCall
    FROM (
        SELECT *,
               ROW_NUMBER() OVER (
                    PARTITION BY TRIM([CNORD#]), TRIM(CNDISP)
                    ORDER BY loadDate DESC, recordNumber DESC
               ) AS rn
        FROM data_central_lh.dbo.ibmi_incr_loaded_call_bronze_new
    ) a
    WHERE rn = 1;

    UPDATE TGT
    SET 
        loaded_call_truck_number = TRIM(SRC.CNUNIT),
        loaded_call_trailer_number = TRIM(SRC.CNTRLR),
        loaded_call_seat_1_driver_code = TRIM(SRC.CNDRV1),
        loaded_call_seat_2_driver_code = TRIM(SRC.CNDRV2),
        loaded_call_contact_date = CNDATE.date_key_pk,
        loaded_call_contact_time =
            CASE WHEN CONVERT(INT, SRC.CNTIME) < 2400 
                      AND LEN(TRIM(SRC.CNTIME)) = 4
                 THEN CONVERT(TIME, CONCAT(LEFT(TRIM(SRC.CNTIME),2), ':', RIGHT(TRIM(SRC.CNTIME),2)))
                 ELSE NULL END,
        loaded_call_type_code = TRIM(SRC.CNCODE),
        loaded_call_location_code = TRIM(SRC.CNLOC),
        loaded_call_city_short_name = TRIM(SRC.CNSNM),
        loaded_call_initials = TRIM(SRC.CNINIT),
        loaded_call_message_details = TRIM(SRC.CNREST),
        loaded_call_hub_reading = SRC.CNHUB,
        loaded_call_temp_reading = SRC.CNTEMP,
        loaded_call_hub_flag = TRIM(SRC.CNHUBN)
    FROM silver.ibmi_loaded_call AS TGT
    JOIN #DedupedLoadedCall AS SRC
        ON TGT.loaded_call_load_number = TRIM(SRC.[CNORD#])
       AND TGT.loaded_call_dispatch = TRIM(SRC.CNDISP)
    LEFT JOIN gold.dim_date AS CNDATE 
        ON SRC.CNDATE = CNDATE.date_ordinal;

    INSERT INTO silver.ibmi_loaded_call (
        loaded_call_truck_number,
        loaded_call_load_number,
        loaded_call_dispatch,
        loaded_call_call_number,
        loaded_call_trailer_number,
        loaded_call_seat_1_driver_code,
        loaded_call_seat_2_driver_code,
        loaded_call_contact_date,
        loaded_call_contact_time,
        loaded_call_type_code,
        loaded_call_location_code,
        loaded_call_city_short_name,
        loaded_call_initials,
        loaded_call_message_details,
        loaded_call_hub_reading,
        loaded_call_temp_reading,
        loaded_call_hub_flag
    )
    SELECT 
        TRIM(SRC.CNUNIT),
        TRIM(SRC.[CNORD#]),
        TRIM(SRC.CNDISP),
        TRIM(SRC.CNCALL),
        TRIM(SRC.CNTRLR),
        TRIM(SRC.CNDRV1),
        TRIM(SRC.CNDRV2),
        CNDATE.date_key_pk,
        CASE WHEN CONVERT(INT, SRC.CNTIME) < 2400 
                  AND LEN(TRIM(SRC.CNTIME)) = 4
             THEN CONVERT(TIME, CONCAT(LEFT(TRIM(SRC.CNTIME),2), ':', RIGHT(TRIM(SRC.CNTIME),2)))
             ELSE NULL END,
        TRIM(SRC.CNCODE),
        TRIM(SRC.CNLOC),
        TRIM(SRC.CNSNM),
        TRIM(SRC.CNINIT),
        TRIM(SRC.CNREST),
        SRC.CNHUB,
        SRC.CNTEMP,
        TRIM(SRC.CNHUBN)
    FROM #DedupedLoadedCall AS SRC
    LEFT JOIN gold.dim_date AS CNDATE 
        ON SRC.CNDATE = CNDATE.date_ordinal
    WHERE NOT EXISTS (
        SELECT 1 
        FROM silver.ibmi_loaded_call AS TGT
        WHERE TGT.loaded_call_load_number = TRIM(SRC.[CNORD#])
          AND TGT.loaded_call_dispatch = TRIM(SRC.CNDISP)
    );

    DROP TABLE #DedupedLoadedCall;
END;