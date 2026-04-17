CREATE   PROCEDURE [dbo].[usp_ibmi_incr_stopoff_silver]
AS
BEGIN
    SET NOCOUNT ON;

    /* -------------------------------
       Step 0: Prep & dedupe bronze
       ------------------------------- */
    IF OBJECT_ID('tempdb..#STOP_Deduped','U') IS NOT NULL DROP TABLE #STOP_Deduped;

    WITH Prep AS (
        SELECT
            TRIM(a.SOORD)                                         AS stopoff_load_number,
            a.SOSTP                                               AS stopoff_stop_number,
            CASE a.SOTYPE WHEN 'D' THEN 'DELIVERY'
                          WHEN 'P' THEN 'PICKUP'
                          ELSE 'unknown' END                      AS stopoff_stop_type,
            TRIM(a.SOREC)                                         AS stopoff_stop_code,
            TRIM(a.SOCUST)                                        AS stopoff_customer_code,
            TRIM(a.SOCTYC)                                        AS stopoff_city_code,
            TRIM(a.SOST)                                          AS stopoff_state,
            a.SOAC                                                AS stopoff_customer_area_code,
            a.SOPHNM                                              AS stopoff_customer_phone_number,
            TRIM(a.SOCONT)                                        AS stopoff_contact_info,
            TRIM(a.SOECD1)                                        AS stopoff_shipper_edi_code,
            TRIM(a.SOECD2)                                        AS stopoff_consignee_edi_code,
            CASE TRIM(a.SOTYPE) WHEN 'E' THEN 'APPT MADE'
                                WHEN 'A' THEN 'ARRIVED'
                                WHEN 'D' THEN 'DEPARTED'
                                ELSE 'unknown' END                AS stopoff_last_status,
            SOEDA.date_key_pk                                     AS stopoff_est_arrival_date,
            CASE WHEN TRY_CONVERT(int, a.SOETA) <= 2359
                      AND LEN(TRIM(a.SOETA)) = 4
                      AND TRY_CONVERT(int, RIGHT(TRIM(a.SOETA),2)) < 60
                 THEN CONVERT(time(0), CONCAT(LEFT(a.SOETA,2),':',RIGHT(a.SOETA,2)))
                 ELSE NULL END                                    AS stopoff_est_arrival_time,
            SOADT1.date_key_pk                                    AS stopoff_appt_early_date,
            SOADT2.date_key_pk                                    AS stopoff_appt_late_date,
            CASE WHEN TRY_CONVERT(int, a.SOATM1) <= 2359
                      AND LEN(TRIM(a.SOATM1)) = 4
                      AND TRY_CONVERT(int, RIGHT(TRIM(a.SOATM1),2)) < 60
                 THEN CONVERT(time(0), CONCAT(LEFT(a.SOATM1,2),':',RIGHT(a.SOATM1,2)))
                 ELSE NULL END                                    AS stopoff_appt_early_time,
            CASE WHEN TRY_CONVERT(int, a.SOATM2) <= 2359
                      AND LEN(TRIM(a.SOATM2)) = 4
                      AND TRY_CONVERT(int, RIGHT(TRIM(a.SOATM2),2)) < 60
                 THEN CONVERT(time(0), CONCAT(LEFT(a.SOATM2,2),':',RIGHT(a.SOATM2,2)))
                 ELSE NULL END                                    AS stopoff_appt_late_time,
            SOARDT.date_key_pk                                    AS stopoff_arrival_date,
            CASE WHEN TRY_CONVERT(int, a.SOARTM) <= 2359
                      AND LEN(TRIM(a.SOARTM)) = 4
                      AND TRY_CONVERT(int, RIGHT(TRIM(a.SOARTM),2)) < 60
                 THEN CONVERT(time(0), CONCAT(LEFT(a.SOARTM,2),':',RIGHT(a.SOARTM,2)))
                 ELSE NULL END                                    AS stopoff_arrival_time,
            SOLUDT.date_key_pk                                    AS stopoff_load_unload_date,
            CASE WHEN TRY_CONVERT(int, a.SOLUTM) <= 2359
                      AND LEN(TRIM(a.SOLUTM)) = 4
                      AND TRY_CONVERT(int, RIGHT(TRIM(a.SOLUTM),2)) < 60
                 THEN CONVERT(time(0), CONCAT(LEFT(a.SOLUTM,2),':',RIGHT(a.SOLUTM,2)))
                 ELSE NULL END                                    AS stopoff_load_unload_time,
            CASE TRIM(a.SOAPPR) WHEN 'Y' THEN 'TRUE'
                                 WHEN 'N' THEN 'FALSE'
                                 ELSE 'unknown' END               AS is_appt_required,
            TRIM(a.SOCSID)                                        AS stopoff_shipper_specific_code,
            TRIM(a.SOSEL1)                                        AS stopoff_seal_1_code,
            TRIM(a.SOSEL2)                                        AS stopoff_seal_2_code,
            a.SOWGT                                               AS stopoff_weight,
            TRIM(a.SOPIEC)                                        AS stopoff_pieces,
            TRIM(a.SOUM)                                          AS stopoff_unit_of_measure,
            a.SOPLON                                              AS stopoff_pallets_on,
            a.SOPLOF                                              AS stopoff_pallets_off,
            CASE TRIM(a.SODLU)
                WHEN 'D' THEN 'DROP TRAILER'
                WHEN 'W' THEN 'WINDOWED DROP'
                WHEN 'N' THEN 'LIVE LOAD LUMPER'
                WHEN 'Y' THEN 'LIVE LOAD DRIVER'
                ELSE 'unknown' END                                AS stopoff_load_unload_type,
            TRIM(a.SOUNIT)                                        AS stopoff_truck_number,
            TRIM(a.SOTRL1)                                        AS stopoff_trailer_number,
            TRIM(a.SODISP)                                        AS stopoff_dispatch,
            TRIM(a.SOAPMI)                                        AS stopoff_appt_created_initials,
            SOAPMD.date_key_pk                                    AS stopoff_appt_created_date,
            CASE WHEN TRY_CONVERT(int, a.SOAPMT) <= 2359
                      AND LEN(TRIM(a.SOAPMT)) = 4
                      AND TRY_CONVERT(int, RIGHT(TRIM(a.SOAPMT),2)) < 60
                 THEN CONVERT(time(0), CONCAT(LEFT(a.SOAPMT,2),':',RIGHT(a.SOAPMT,2)))
                 ELSE NULL END                                    AS stopoff_appt_created_time,
            TRIM(a.SOSPEC)                                        AS stopoff_message,
            CASE TRIM(a.SOAPTM) WHEN 'Y' THEN 'TRUE'
                                 WHEN 'N' THEN 'FALSE'
                                 ELSE 'unknown' END               AS is_appt_created,
            SOA_DD.date_key_pk                                    AS stopoff_appt_date_at_dispatch,
            CASE WHEN TRY_CONVERT(int, a.[SOA@DT]) <= 2359
                      AND LEN(TRIM(a.[SOA@DT])) = 4
                      AND TRY_CONVERT(int, RIGHT(TRIM(a.[SOA@DT]),2)) < 60
                 THEN CONVERT(time(0), CONCAT(LEFT(a.[SOA@DT],2),':',RIGHT(a.[SOA@DT],2)))
                 ELSE NULL END                                    AS stopoff_appt_time_at_dispatch,
            -- recency for dedupe
            a.loadDate,
            a.recordNumber
        FROM data_central_lh.dbo.ibmi_incr_stopoff_bronze a
        LEFT JOIN data_central_wh.gold.dim_date SOEDA   ON a.SOEDA    = SOEDA.date_ordinal
        LEFT JOIN data_central_wh.gold.dim_date SOADT1  ON a.SOADT1   = SOADT1.date_ordinal
        LEFT JOIN data_central_wh.gold.dim_date SOADT2  ON a.SOADT2   = SOADT2.date_ordinal
        LEFT JOIN data_central_wh.gold.dim_date SOARDT  ON a.SOARDT   = SOARDT.date_ordinal
        LEFT JOIN data_central_wh.gold.dim_date SOLUDT  ON a.SOLUDT   = SOLUDT.date_ordinal
        LEFT JOIN data_central_wh.gold.dim_date SOAPMD  ON a.SOAPMD   = SOAPMD.date_ordinal
        LEFT JOIN data_central_wh.gold.dim_date SOA_DD  ON a.[SOA@DD] = SOA_DD.date_ordinal  -- bracketed col with '@'
    )
    SELECT *
    INTO #STOP_Deduped
    FROM (
        SELECT p.*,
               ROW_NUMBER() OVER (
                   PARTITION BY p.stopoff_load_number, p.stopoff_stop_number
                   ORDER BY p.loadDate DESC, p.recordNumber DESC
               ) AS rn
        FROM Prep p
    ) x
    WHERE x.rn = 1;

    /* -------------------------------
       Step 1: UPDATE matches
       ------------------------------- */
    UPDATE T
       SET T.stopoff_stop_type                 = S.stopoff_stop_type,
           T.stopoff_stop_code                 = S.stopoff_stop_code,
           T.stopoff_customer_code             = S.stopoff_customer_code,
           T.stopoff_city_code                 = S.stopoff_city_code,
           T.stopoff_state                     = S.stopoff_state,
           T.stopoff_customer_area_code        = S.stopoff_customer_area_code,
           T.stopoff_customer_phone_number     = S.stopoff_customer_phone_number,
           T.stopoff_contact_info              = S.stopoff_contact_info,
           T.stopoff_shipper_edi_code          = S.stopoff_shipper_edi_code,
           T.stopoff_consignee_edi_code        = S.stopoff_consignee_edi_code,
           T.stopoff_last_status               = S.stopoff_last_status,
           T.stopoff_est_arrival_date          = S.stopoff_est_arrival_date,
           T.stopoff_est_arrival_time          = S.stopoff_est_arrival_time,
           T.stopoff_appt_early_date           = S.stopoff_appt_early_date,
           T.stopoff_appt_late_date            = S.stopoff_appt_late_date,
           T.stopoff_appt_early_time           = S.stopoff_appt_early_time,
           T.stopoff_appt_late_time            = S.stopoff_appt_late_time,
           T.stopoff_arrival_date              = S.stopoff_arrival_date,
           T.stopoff_arrival_time              = S.stopoff_arrival_time,
           T.stopoff_load_unload_date          = S.stopoff_load_unload_date,
           T.stopoff_load_unload_time          = S.stopoff_load_unload_time,
           T.is_appt_required                  = S.is_appt_required,
           T.stopoff_shipper_specific_code     = S.stopoff_shipper_specific_code,
           T.stopoff_seal_1_code               = S.stopoff_seal_1_code,
           T.stopoff_seal_2_code               = S.stopoff_seal_2_code,
           T.stopoff_weight                    = S.stopoff_weight,
           T.stopoff_pieces                    = S.stopoff_pieces,
           T.stopoff_unit_of_measure           = S.stopoff_unit_of_measure,
           T.stopoff_pallets_on                = S.stopoff_pallets_on,
           T.stopoff_pallets_off               = S.stopoff_pallets_off,
           T.stopoff_load_unload_type          = S.stopoff_load_unload_type,
           T.stopoff_truck_number              = S.stopoff_truck_number,
           T.stopoff_trailer_number            = S.stopoff_trailer_number,
           T.stopoff_dispatch                  = S.stopoff_dispatch,
           T.stopoff_appt_created_initials     = S.stopoff_appt_created_initials,
           T.stopoff_appt_created_date         = S.stopoff_appt_created_date,
           T.stopoff_appt_created_time         = S.stopoff_appt_created_time,
           T.stopoff_message                   = S.stopoff_message,
           T.is_appt_created                   = S.is_appt_created,
           T.stopoff_appt_date_at_dispatch     = S.stopoff_appt_date_at_dispatch,
           T.stopoff_appt_time_at_dispatch     = S.stopoff_appt_time_at_dispatch
    FROM silver.ibmi_stopoff T
    JOIN #STOP_Deduped S
      ON T.stopoff_load_number = S.stopoff_load_number
     AND T.stopoff_stop_number = S.stopoff_stop_number;

    /* -------------------------------
       Step 2: INSERT non-matches
       ------------------------------- */
    INSERT INTO silver.ibmi_stopoff
    (
        stopoff_load_number,
        stopoff_stop_number,
        stopoff_stop_type,
        stopoff_stop_code,
        stopoff_customer_code,
        stopoff_city_code,
        stopoff_state,
        stopoff_customer_area_code,
        stopoff_customer_phone_number,
        stopoff_contact_info,
        stopoff_shipper_edi_code,
        stopoff_consignee_edi_code,
        stopoff_last_status,
        stopoff_est_arrival_date,
        stopoff_est_arrival_time,
        stopoff_appt_early_date,
        stopoff_appt_late_date,
        stopoff_appt_early_time,
        stopoff_appt_late_time,
        stopoff_arrival_date,
        stopoff_arrival_time,
        stopoff_load_unload_date,
        stopoff_load_unload_time,
        is_appt_required,
        stopoff_shipper_specific_code,
        stopoff_seal_1_code,
        stopoff_seal_2_code,
        stopoff_weight,
        stopoff_pieces,
        stopoff_unit_of_measure,
        stopoff_pallets_on,
        stopoff_pallets_off,
        stopoff_load_unload_type,
        stopoff_truck_number,
        stopoff_trailer_number,
        stopoff_dispatch,
        stopoff_appt_created_initials,
        stopoff_appt_created_date,
        stopoff_appt_created_time,
        stopoff_message,
        is_appt_created,
        stopoff_appt_date_at_dispatch,
        stopoff_appt_time_at_dispatch
    )
    SELECT
        S.stopoff_load_number,
        S.stopoff_stop_number,
        S.stopoff_stop_type,
        S.stopoff_stop_code,
        S.stopoff_customer_code,
        S.stopoff_city_code,
        S.stopoff_state,
        S.stopoff_customer_area_code,
        S.stopoff_customer_phone_number,
        S.stopoff_contact_info,
        S.stopoff_shipper_edi_code,
        S.stopoff_consignee_edi_code,
        S.stopoff_last_status,
        S.stopoff_est_arrival_date,
        S.stopoff_est_arrival_time,
        S.stopoff_appt_early_date,
        S.stopoff_appt_late_date,
        S.stopoff_appt_early_time,
        S.stopoff_appt_late_time,
        S.stopoff_arrival_date,
        S.stopoff_arrival_time,
        S.stopoff_load_unload_date,
        S.stopoff_load_unload_time,
        S.is_appt_required,
        S.stopoff_shipper_specific_code,
        S.stopoff_seal_1_code,
        S.stopoff_seal_2_code,
        S.stopoff_weight,
        S.stopoff_pieces,
        S.stopoff_unit_of_measure,
        S.stopoff_pallets_on,
        S.stopoff_pallets_off,
        S.stopoff_load_unload_type,
        S.stopoff_truck_number,
        S.stopoff_trailer_number,
        S.stopoff_dispatch,
        S.stopoff_appt_created_initials,
        S.stopoff_appt_created_date,
        S.stopoff_appt_created_time,
        S.stopoff_message,
        S.is_appt_created,
        S.stopoff_appt_date_at_dispatch,
        S.stopoff_appt_time_at_dispatch
    FROM #STOP_Deduped S
    WHERE NOT EXISTS (
        SELECT 1
        FROM silver.ibmi_stopoff T
        WHERE T.stopoff_load_number = S.stopoff_load_number
          AND T.stopoff_stop_number = S.stopoff_stop_number
    );

    DROP TABLE #STOP_Deduped;
END;