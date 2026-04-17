CREATE   PROCEDURE [dbo].[usp_ibmi_incr_load_silver_new]
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRAN;

        /*========================================================
          Step 1: Deduplicate bronze (latest per DIODR, DIDISP, DICONT)
        ========================================================*/
        IF OBJECT_ID('tempdb..#DedupedWithDates', 'U') IS NOT NULL DROP TABLE #DedupedWithDates;

        SELECT  a.*,
                DIDATE.date_key_pk  AS DIDATE_key,
                DIETAD.date_key_pk  AS DIETAD_key,
                DITJD.date_key_pk   AS DITJD_key
        INTO #DedupedWithDates
        FROM (
            SELECT *,
                   ROW_NUMBER() OVER (
                        PARTITION BY DIODR, DIDISP, DICONT
                        ORDER BY loadDate DESC, recordNumber DESC
                   ) AS rn
            FROM data_central_lh.dbo.ibmi_incr_load_bronze_new
        ) a
        LEFT JOIN gold.dim_date DIDATE ON a.DIDATE = DIDATE.date_ordinal
        LEFT JOIN gold.dim_date DIETAD ON a.DIETAD = DIETAD.date_ordinal
        LEFT JOIN gold.dim_date DITJD  ON a.DITJD  = DITJD.date_ordinal
        WHERE a.rn = 1;

        /*========================================================
          Step 1.5 (NEW): Delete from target ONLY for DISTINCT load numbers in this run
        ========================================================*/
        IF OBJECT_ID('tempdb..#LoadsToDelete', 'U') IS NOT NULL DROP TABLE #LoadsToDelete;

        SELECT DISTINCT TRIM(DIODR) AS load_load_number
        INTO #LoadsToDelete
        FROM #DedupedWithDates
        WHERE DIODR IS NOT NULL;

        DELETE TGT
        FROM silver.ibmi_incr_load_new TGT
        JOIN #LoadsToDelete D
          ON TGT.load_load_number = D.load_load_number;

        /*========================================================
          Step 2: UPDATE existing records in silver where keys match
          (NOTE: after the delete above, this will typically affect 0 rows,
                 but kept as-is per your original pattern)
        ========================================================*/
        UPDATE TGT
        SET
            load_origin_area_code               = TRIM(SRC.DIARA),
            load_status                         = TRIM(SRC.DILDST),
            load_dispatch_date                  = SRC.DIDATE_key,
            load_dispatch_time                  = TRIM(SRC.DITIME),
            load_truck_number                   = TRIM(SRC.DIUNIT),
            load_trailer_number                 = TRIM(SRC.DITRLR),
            load_seat_1_driver_code             = TRIM(SRC.DIDR1),
            load_seat_2_driver_code             = TRIM(SRC.DIDR2),
            load_route_line_codes               = TRIM(SRC.DIROUT),
            load_route_status                   = TRIM(SRC.DIRTST),
            load_miles_dead_head                = SRC.DIEMIL,
            load_miles_total                    = SRC.DITMIL,
            load_miles_loaded                   = SRC.DISMNF,
            load_mile_flag                      = TRIM(SRC.DIMIFL),
            load_initials                       = TRIM(SRC.DIINIT),
            load_destination_area_code          = TRIM(SRC.DIAREA),
            load_dispatch_end_date              = SRC.DIETAD_key,
            load_dispatch_end_time              = TRIM(SRC.DIETAT),
            load_multiple_trailers_on_dispatch  = TRIM(SRC.DIMTRL),
            load_settlement_flag                = TRIM(SRC.DISTST),
            load_payroll_approval_flag          = TRIM(SRC.DIAPRV),
            load_truck_dmol_code                = TRIM(SRC.DIUFMG),
            load_truck_dm_code                  = TRIM(SRC.DIUDMG),
            load_driver_dmol_code               = TRIM(SRC.DIDFMG),
            load_driver_dm_code                 = TRIM(SRC.DIDDMG),
            load_trip_jacket_received_flag      = TRIM(SRC.DITJR),
            load_trip_jacket_received_date      = SRC.DITJD_key,
            load_miles_hub_start                = SRC.DIBHUB,
            load_miles_hub_end                  = SRC.DIEHUB,
            load_unit_division_code             = TRIM(LEFT(SRC.DIOWNR,3)),
            load_team_status_code               = TRIM(RIGHT(SRC.DIOWNR,2)),
            load_trainer_team_code              = TRIM(SRC.DITRN2),
            is_deleted                          = 0
        FROM silver.ibmi_incr_load_new TGT
        JOIN #DedupedWithDates SRC
          ON TGT.load_load_number           = TRIM(SRC.DIODR)
         AND TGT.load_dispatch              = TRIM(SRC.DIDISP)
         AND TGT.load_route_line_extension  = TRIM(SRC.DICONT);

        /*========================================================
          Step 3: INSERT new records not present in silver
          (after delete, these will mostly all insert)
        ========================================================*/
        INSERT INTO silver.ibmi_incr_load_new (
            load_origin_area_code,
            load_load_number,
            load_dispatch,
            load_status,
            load_dispatch_date,
            load_dispatch_time,
            load_truck_number,
            load_trailer_number,
            load_seat_1_driver_code,
            load_seat_2_driver_code,
            load_route_line_codes,
            load_route_status,
            load_miles_dead_head,
            load_miles_total,
            load_miles_loaded,
            load_mile_flag,
            load_initials,
            load_destination_area_code,
            load_route_line_extension,
            load_dispatch_end_date,
            load_dispatch_end_time,
            load_multiple_trailers_on_dispatch,
            load_settlement_flag,
            load_payroll_approval_flag,
            load_truck_dmol_code,
            load_truck_dm_code,
            load_driver_dmol_code,
            load_driver_dm_code,
            load_trip_jacket_received_flag,
            load_trip_jacket_received_date,
            load_miles_hub_start,
            load_miles_hub_end,
            load_unit_division_code,
            load_team_status_code,
            load_trainer_team_code,
            is_deleted
        )
        SELECT
            TRIM(SRC.DIARA),
            TRIM(SRC.DIODR),
            TRIM(SRC.DIDISP),
            TRIM(SRC.DILDST),
            SRC.DIDATE_key,
            TRIM(SRC.DITIME),
            TRIM(SRC.DIUNIT),
            TRIM(SRC.DITRLR),
            TRIM(SRC.DIDR1),
            TRIM(SRC.DIDR2),
            TRIM(SRC.DIROUT),
            TRIM(SRC.DIRTST),
            SRC.DIEMIL,
            SRC.DITMIL,
            SRC.DISMNF,
            TRIM(SRC.DIMIFL),
            TRIM(SRC.DIINIT),
            TRIM(SRC.DIAREA),
            TRIM(SRC.DICONT),
            SRC.DIETAD_key,
            TRIM(SRC.DIETAT),
            TRIM(SRC.DIMTRL),
            TRIM(SRC.DISTST),
            TRIM(SRC.DIAPRV),
            TRIM(SRC.DIUFMG),
            TRIM(SRC.DIUDMG),
            TRIM(SRC.DIDFMG),
            TRIM(SRC.DIDDMG),
            TRIM(SRC.DITJR),
            SRC.DITJD_key,
            SRC.DIBHUB,
            SRC.DIEHUB,
            TRIM(LEFT(SRC.DIOWNR,3)),
            TRIM(RIGHT(SRC.DIOWNR,2)),
            TRIM(SRC.DITRN2),
            0
        FROM #DedupedWithDates SRC
        WHERE NOT EXISTS (
            SELECT 1
            FROM silver.ibmi_incr_load_new TGT
            WHERE TGT.load_load_number          = TRIM(SRC.DIODR)
              AND TGT.load_dispatch             = TRIM(SRC.DIDISP)
              AND TGT.load_route_line_extension = TRIM(SRC.DICONT)
        );

        DROP TABLE #DedupedWithDates;
        DROP TABLE #LoadsToDelete;

        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;

        DECLARE @ErrMsg NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrNum INT = ERROR_NUMBER();
        DECLARE @ErrState INT = ERROR_STATE();
        RAISERROR('usp_ibmi_incr_load_silver_new failed. %s', 16, 1, @ErrMsg) WITH NOWAIT;
    END CATCH
END;