-- Auto Generated (Do not modify) BE932460D4AD95A4F7F8B9271F6D5F55E66276DEF839ECA0D54555692D5270E5
CREATE     VIEW silver.vw_driver_perf_daily AS
WITH base AS (
    SELECT
        primary_driver_id                           AS driver_id,
        truck_id,
        CAST(slice_end_utc AS DATE)                 AS perf_date_utc,

        SUM(miles_driven)               AS miles_driven,
        SUM(minutes_driving)            AS minutes_driving,
        SUM(minutes_moving)             AS minutes_moving,
        SUM(minutes_idle_internal +
            minutes_idle_shutdown +
            minutes_idle_stopped)      AS minutes_idle,
        SUM(fuel_move_gal +
            fuel_idle_gal +
            fuel_pto_gal)              AS fuel_used_gal,
        SUM(fuel_idle_gal)             AS fuel_idle_gal,
        SUM(overspeed_events)          AS overspeed_events,
        SUM(minutes_overspeed)         AS minutes_overspeed,
        MAX(max_speed_mph)             AS max_speed_mph,
        MAX(max_rpm)                   AS max_rpm,
        SUM(minutes_high_rpm)          AS minutes_high_rpm,
        MAX(engine_hours_end) -
        MIN(engine_hours_end)          AS engine_hours,
        MAX(odometer_end_mi) -
        MIN(odometer_end_mi)           AS odo_delta_mi
    FROM  silver.plsc_driver_perf_slices
    GROUP BY
        primary_driver_id,
        truck_id,
        CAST(slice_end_utc AS DATE)
)
SELECT *
FROM   base;