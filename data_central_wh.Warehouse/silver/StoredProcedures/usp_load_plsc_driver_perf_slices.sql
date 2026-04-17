CREATE   PROCEDURE [silver].[usp_load_plsc_driver_perf_slices]
AS
BEGIN
    SET NOCOUNT ON;

    -- refresh the silver table
    DELETE FROM [data_central_wh].[silver].[plsc_driver_perf_slices];

    INSERT INTO [data_central_wh].[silver].[plsc_driver_perf_slices] (
        truck_id, load_id, primary_driver_id, co_driver_id, snapshot_type,
        server_received_at, slice_start_utc, slice_end_utc,
        miles_driven, minutes_driving, minutes_idle_internal,
        minutes_idle_shutdown, minutes_idle_stopped, minutes_moving,
        fuel_move_gal, fuel_idle_gal, fuel_pto_gal,
        overspeed_events, minutes_overspeed, minutes_high_rpm,
        avg_engine_load_pct, max_rpm, max_speed_mph,
        odometer_end_mi, trip_distance_mi, engine_hours_end, load_date
    )
    SELECT
        PLPTRUCK                                   AS truck_id,
        PLPORDER                                   AS load_id,
        PLPDRVR1                                   AS primary_driver_id,
        PLPDRVR2                                   AS co_driver_id,
        PLPTYPE                                    AS snapshot_type,
        PLPRECVT                                   AS server_received_at,
        CAST(PLPBEGINT AS datetime2(3))            AS slice_start_utc,
        CAST(PLPENDT  AS datetime2(3))             AS slice_end_utc,
        TRY_CONVERT(decimal(10,2), PLPDRIVED)      AS miles_driven,
        TRY_CONVERT(decimal(10,2), PLPDRIVET)      AS minutes_driving,
        TRY_CONVERT(decimal(10,2), PLPINTIDLT)     AS minutes_idle_internal,
        TRY_CONVERT(decimal(10,2), PLPSHTIDLT)     AS minutes_idle_shutdown,
        TRY_CONVERT(decimal(10,2), PLPSTPIDLT)     AS minutes_idle_stopped,
        TRY_CONVERT(decimal(10,2), PLPMOVINGT)     AS minutes_moving,
        TRY_CONVERT(decimal(12,4), PLPMOVFLU)      AS fuel_move_gal,
        TRY_CONVERT(decimal(12,4), PLPSTPIDFU)     AS fuel_idle_gal,
        TRY_CONVERT(decimal(12,4), PLPPTOFLU)      AS fuel_pto_gal,
        TRY_CONVERT(int,          PLPOVRSPDC)      AS overspeed_events,
        TRY_CONVERT(decimal(10,2), PLPOVRSPDT)     AS minutes_overspeed,
        TRY_CONVERT(decimal(10,2), PLPOVRRPMT)     AS minutes_high_rpm,
        TRY_CONVERT(decimal(7,3),  PLPAVENGLT)     AS avg_engine_load_pct,
        TRY_CONVERT(int,          PLPORPMMXT)      AS max_rpm,
        TRY_CONVERT(int,          PLPOSPDMXT)      AS max_speed_mph,
        TRY_CONVERT(decimal(12,3), PLPSTRODOM)     AS odometer_end_mi,
        TRY_CONVERT(decimal(12,3), PLPTLTRIPC)     AS trip_distance_mi,
        TRY_CONVERT(decimal(12,2), PLPENGINET)     AS engine_hours_end,
        CAST(PLPLOGDT AS date)                     AS load_date
    FROM   [data_central_lh].[dbo].[PLSC_PLTDRPMP];
END;