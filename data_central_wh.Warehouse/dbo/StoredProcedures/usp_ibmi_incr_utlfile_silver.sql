CREATE     PROCEDURE [dbo].[usp_ibmi_incr_utlfile_silver]
AS
BEGIN
    SET NOCOUNT ON;

    IF OBJECT_ID('tempdb..#Deduped', 'U') IS NOT NULL 
        DROP TABLE #Deduped;

    SELECT
        a.*,
        UWPDA.date_key_pk  AS UWPDA_key,   -- projected date available
        UWDAT2.date_key_pk AS UWDAT2_key   -- record date
    INTO #Deduped
    FROM (
        SELECT *,
               ROW_NUMBER() OVER (
                   PARTITION BY TRIM(UWCODE), UWDAT2
                   ORDER BY loadDate DESC, recordNumber DESC
               ) AS rn
        FROM data_central_lh.dbo.ibmi_incr_utlfile_bronze
    ) a
    LEFT JOIN gold.dim_date UWPDA  ON a.UWPDA  = UWPDA.date_key_pk
    LEFT JOIN gold.dim_date UWDAT2 ON a.UWDAT2 = UWDAT2.date_key_pk
    WHERE a.rn = 1;

    /* ------------------------------------------------------------
       Step 1: UPDATE existing rows in silver on key
               (utlfile_driver_code, utlfile_record_date)
       ------------------------------------------------------------ */
    UPDATE TGT
    SET
        utlfile_truck_number              = TRIM(SRC.UWUNIT),
        utlfile_driver_code               = TRIM(SRC.UWCODE),
        utlfile_driver_type               = CASE SRC.UWTYPE 
                                                WHEN 0 THEN 'COMPANY'
                                                WHEN 1 THEN 'OWNER'
                                                ELSE 'unknown' 
                                            END,
        utlfile_truck_dm_code             = TRIM(SRC.UWSUPR),
        utlfile_driver_dm_code            = TRIM(SRC.UWDMGR),
        utlfile_dmol_code                 = TRIM(SRC.UWFMGR),
        utlfile_safety_manager_code       = TRIM(SRC.UWSFMG),
        utlfile_counselor_code            = TRIM(SRC.UWCOUN),
        utlfile_seat                      = TRIM(SRC.UWSEAT),
        utlfile_first_seat_code           = TRIM(SRC.UWDRS1),
        utlfile_second_seat_code          = TRIM(SRC.UWDRS2),
        utlfile_training_level_code       = TRIM(SRC.UWTLVL),
        is_team_truck                     = CASE WHEN TRIM(SRC.UWTMYN) = 'Y' THEN 'TRUE' ELSE 'FALSE' END,
        is_training_team                  = CASE WHEN TRIM(SRC.UWTRTM) = 'Y' THEN 'TRUE' ELSE 'FALSE' END,
        utlfile_miles_hub                 = SRC.UWMILS,
        utlfile_miles_adj_hub             = SRC.UWAMLS,
        utlfile_miles_goal                = SRC.UWGOAL,
        utlfile_utilization_ratio         = SRC.UWPERF,
        utlfile_projected_date_available  = SRC.UWPDA_key,
        utlfile_projected_time_available  = TRIM(SRC.UWPTA),
        is_home_time                      = CASE SRC.UWHOME 
                                                WHEN 'Y' THEN 'TRUE'
                                                WHEN 'N' THEN 'FALSE'
                                                ELSE 'unknown' 
                                            END,
        utlfile_hold_codes                = TRIM(SRC.UWHOLD),
        utlfile_equipment_breakdown       = TRIM(SRC.UWBRKD),
        is_resweep                        = CASE WHEN TRIM(SRC.UWFLAG) = 'Y' THEN 'TRUE' ELSE 'FALSE' END,
        utlfile_load_number               = TRIM(SRC.UWLOAD),
        is_grad_hold                      = CASE SRC.UWGRHD 
                                                WHEN 'Y' THEN 'TRUE'
                                                WHEN 'N' THEN 'FALSE'
                                                ELSE 'unknown' 
                                            END,
        is_omitted                        = CASE SRC.UWOMIT 
                                                WHEN 'Y' THEN 'TRUE'
                                                WHEN 'N' THEN 'FALSE'
                                                ELSE 'unknown' 
                                            END,
        utlfile_division                  = TRIM(SRC.UWDIV),
        utlfile_requested_days_out        = SRC.UWRDO,
        is_trainer                        = CASE SRC.UWTRNR 
                                                WHEN 'Y' THEN 'TRUE'
                                                WHEN 'N' THEN 'FALSE'
                                                ELSE 'unknown' 
                                            END,
        utlfile_trainer_availability_code = TRIM(SRC.UWTRAV),
        utlfile_trainer_status_code       = TRIM(SRC.UWTRCD),
        is_allowed_to_drive               = CASE SRC.UWCNDV 
                                                WHEN 'Y' THEN 'TRUE'
                                                WHEN 'N' THEN 'FALSE'
                                                ELSE 'unknown' 
                                            END,
        -- key column also set from SRC to keep normalized values consistent
        utlfile_record_date               = SRC.UWDAT2_key,
        utlfile_comfort_zone_code         = TRIM(SRC.UWCMZN),
        is_on_yard                        = CASE SRC.UWYARD 
                                                WHEN 'Y' THEN 'TRUE'
                                                WHEN 'N' THEN 'FALSE'
                                                ELSE 'unknown' 
                                            END,
        utlfile_business_unit_code        = TRIM(SRC.UWBUNT),
        utlfile_business_class            = CASE 
                                                WHEN TRIM(SRC.UWBUNT) = ''
                                                     THEN NULL
                                                ELSE TRIM(LEFT(SRC.UWXFLD,13)) END,
        utlfile_business_description      = CASE 
                                                WHEN TRIM(SRC.UWBUNT) = ''
                                                     THEN NULL
                                                ELSE TRIM(RIGHT(SRC.UWXFLD,17)) END
    FROM silver.ibmi_utlfile AS TGT
    JOIN #Deduped          AS SRC
      ON TGT.utlfile_driver_code = TRIM(SRC.UWCODE)
     AND TGT.utlfile_record_date = SRC.UWDAT2_key;

    /* ------------------------------------------------------------
       Step 2: INSERT rows that don’t exist in silver
       ------------------------------------------------------------ */
    INSERT INTO silver.ibmi_utlfile
    (   utlfile_truck_number,
        utlfile_driver_code,
        utlfile_driver_type,
        utlfile_truck_dm_code,
        utlfile_driver_dm_code,
        utlfile_dmol_code,
        utlfile_safety_manager_code,
        utlfile_counselor_code,
        utlfile_seat,
        utlfile_first_seat_code,
        utlfile_second_seat_code,
        utlfile_training_level_code,
        is_team_truck,
        is_training_team,
        utlfile_miles_hub,
        utlfile_miles_adj_hub,
        utlfile_miles_goal,
        utlfile_utilization_ratio,
        utlfile_projected_date_available,
        utlfile_projected_time_available,
        is_home_time,
        utlfile_hold_codes,
        utlfile_equipment_breakdown,
        is_resweep,
        utlfile_load_number,
        is_grad_hold,
        is_omitted,
        utlfile_division,
        utlfile_requested_days_out,
        is_trainer,
        utlfile_trainer_availability_code,
        utlfile_trainer_status_code,
        is_allowed_to_drive,
        utlfile_record_date,
        utlfile_comfort_zone_code,
        is_on_yard,
        utlfile_business_unit_code,
        utlfile_business_class,
        utlfile_business_description
    )
    SELECT
        TRIM(SRC.UWUNIT),
        TRIM(SRC.UWCODE),
        CASE SRC.UWTYPE 
            WHEN 0 THEN 'COMPANY'
            WHEN 1 THEN 'OWNER'
            ELSE 'unknown' 
        END,
        TRIM(SRC.UWSUPR),
        TRIM(SRC.UWDMGR),
        TRIM(SRC.UWFMGR),
        TRIM(SRC.UWSFMG),
        TRIM(SRC.UWCOUN),
        TRIM(SRC.UWSEAT),
        TRIM(SRC.UWDRS1),
        TRIM(SRC.UWDRS2),
        TRIM(SRC.UWTLVL),
        CASE WHEN TRIM(SRC.UWTMYN) = 'Y' THEN 'TRUE' ELSE 'FALSE' END,
        CASE WHEN TRIM(SRC.UWTRTM) = 'Y' THEN 'TRUE' ELSE 'FALSE' END,
        SRC.UWMILS,
        SRC.UWAMLS,
        SRC.UWGOAL,
        SRC.UWPERF,
        SRC.UWPDA_key,
        TRIM(SRC.UWPTA),
        CASE SRC.UWHOME 
            WHEN 'Y' THEN 'TRUE'
            WHEN 'N' THEN 'FALSE'
            ELSE 'unknown' 
        END,
        TRIM(SRC.UWHOLD),
        TRIM(SRC.UWBRKD),
        CASE WHEN TRIM(SRC.UWFLAG) = 'Y' THEN 'TRUE' ELSE 'FALSE' END,
        TRIM(SRC.UWLOAD),
        CASE SRC.UWGRHD 
            WHEN 'Y' THEN 'TRUE'
            WHEN 'N' THEN 'FALSE'
            ELSE 'unknown' 
        END,
        CASE SRC.UWOMIT 
            WHEN 'Y' THEN 'TRUE'
            WHEN 'N' THEN 'FALSE'
            ELSE 'unknown' 
        END,
        TRIM(SRC.UWDIV),
        SRC.UWRDO,
        CASE SRC.UWTRNR 
            WHEN 'Y' THEN 'TRUE'
            WHEN 'N' THEN 'FALSE'
            ELSE 'unknown' 
        END,
        TRIM(SRC.UWTRAV),
        TRIM(SRC.UWTRCD),
        CASE SRC.UWCNDV 
            WHEN 'Y' THEN 'TRUE'
            WHEN 'N' THEN 'FALSE'
            ELSE 'unknown' 
        END,
        SRC.UWDAT2_key,
        TRIM(SRC.UWCMZN),
        CASE SRC.UWYARD 
            WHEN 'Y' THEN 'TRUE'
            WHEN 'N' THEN 'FALSE'
            ELSE 'unknown' 
        END,
        TRIM(SRC.UWBUNT),
        CASE 
            WHEN TRIM(SRC.UWBUNT) = ''
                THEN NULL
            ELSE TRIM(LEFT(SRC.UWXFLD,13)) END,
        CASE 
            WHEN TRIM(SRC.UWBUNT) = ''
                THEN NULL
            ELSE TRIM(RIGHT(SRC.UWXFLD,17)) END
    FROM #Deduped SRC
    WHERE NOT EXISTS (
        SELECT 1
        FROM silver.ibmi_utlfile T
        WHERE T.utlfile_driver_code = TRIM(SRC.UWCODE)
          AND T.utlfile_record_date = SRC.UWDAT2_key
    );

    DROP TABLE #Deduped;
END;