-- Auto Generated (Do not modify) 8B0E75018A6A859350F7259494EDFCB8C91C9B482409F7A7DCA3A39DB03CF46D
-- In data_central_wh
CREATE   VIEW [gold].[vw_plsc_vehicle_heartbeats_enriched]
AS
WITH src AS (
    SELECT
        hb.plt_truck_id,
        hb.heartbeat_id,
        hb.msg_type,
        hb.recv_utc_raw,
        hb.log_utc_raw,

        -- Parse timestamps (handles 'T' and trailing '.')
        TRY_CONVERT(datetime2(0), hb.recv_utc_raw) AS recv_utc_dt,
        TRY_CONVERT(
            datetime2(0),
            REPLACE(
                CASE WHEN RIGHT(hb.log_utc_raw,1)='.'
                     THEN LEFT(hb.log_utc_raw, LEN(hb.log_utc_raw)-1)
                     ELSE hb.log_utc_raw END,
                'T',' ')
        ) AS log_utc_dt,

        -- Coalesce preferred numeric sources
        COALESCE(TRY_CAST(hb.odometer_raw AS decimal(18,3)),
                 TRY_CAST(hb.odo_j1939_raw AS decimal(18,3)))   AS odometer_val,
        COALESCE(TRY_CAST(hb.eng_hrs_total AS decimal(18,3)),
                 TRY_CAST(hb.eng_hrs_j1939 AS decimal(18,3)))  AS eng_hrs_val,
        TRY_CAST(hb.fuel_total AS decimal(18,3))               AS fuel_total,

        -- Useful passthroughs
        TRY_CAST(hb.latitude_raw  AS decimal(9,6))  AS latitude,
        TRY_CAST(hb.longitude_raw AS decimal(9,6))  AS longitude,
        hb.location_desc,
        hb.heading_deg_raw, hb.ignition_raw, hb.rpm_raw, hb.windows_mask, hb.acu_raw,
        hb.sat_count_raw, hb.gps_fix_raw, hb.hdop_raw, hb.distance_unit, hb.heading_cardinal,
        hb.city, hb.state, hb.country, hb.fuel_instant
    FROM [silver].[plsc_vehicle_heartbeats] AS hb
),
t AS (
    SELECT *,
           COALESCE(recv_utc_dt, log_utc_dt) AS dt_base
    FROM src
),
w AS (
    SELECT
        *,
        LAG(odometer_val) OVER (PARTITION BY plt_truck_id ORDER BY dt_base, heartbeat_id) AS odometer_prev,
        LAG(eng_hrs_val)  OVER (PARTITION BY plt_truck_id ORDER BY dt_base, heartbeat_id) AS eng_hrs_prev,
        LAG(fuel_total)   OVER (PARTITION BY plt_truck_id ORDER BY dt_base, heartbeat_id) AS fuel_prev
    FROM t
)
SELECT
    plt_truck_id,
    heartbeat_id,
    msg_type,

    recv_utc_raw, log_utc_raw,
    recv_utc_dt,  log_utc_dt,
    dt_base,

    CAST(dt_base AS date)                                     AS [date],
    DATEPART(hour, dt_base)                                   AS hour_of_day,
    DATETIMEFROMPARTS(YEAR(dt_base),MONTH(dt_base),DAY(dt_base),
                      DATEPART(hour, dt_base),0,0,0)          AS hour_start,
    -- Week start (Monday)
    CAST(DATEADD(day, -((DATEDIFF(day, 0, CAST(dt_base AS date)) + 6) % 7),
                 CAST(dt_base AS date)) AS date)              AS week_start_monday,

    odometer_val                                              AS odometer_coalesced_mi,
    eng_hrs_val                                               AS engine_hours_coalesced,
    fuel_total,

    CASE WHEN odometer_val IS NULL OR odometer_prev IS NULL THEN NULL
         WHEN odometer_val - odometer_prev < 0 THEN 0
         ELSE odometer_val - odometer_prev END                AS odo_delta_mi,

    CASE WHEN eng_hrs_val IS NULL OR eng_hrs_prev IS NULL THEN NULL
         WHEN eng_hrs_val - eng_hrs_prev < 0 THEN 0
         ELSE eng_hrs_val - eng_hrs_prev END                  AS engine_hours_delta,

    CASE WHEN fuel_total IS NULL OR fuel_prev IS NULL THEN NULL
         WHEN fuel_total - fuel_prev < 0 THEN 0
         ELSE fuel_total - fuel_prev END                      AS fuel_delta_gal,

    latitude, longitude, location_desc,
    heading_deg_raw, ignition_raw, rpm_raw, windows_mask, acu_raw,
    sat_count_raw, gps_fix_raw, hdop_raw, distance_unit, heading_cardinal,
    city, state, country, fuel_instant
FROM w
WHERE dt_base IS NOT NULL;