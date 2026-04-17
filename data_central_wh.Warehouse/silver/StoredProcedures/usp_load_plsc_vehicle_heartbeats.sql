/*───────── PROCEDURE: simple “truncate‑and‑load” – column counts now match ─────────*/
CREATE   PROCEDURE [silver].[usp_load_plsc_vehicle_heartbeats]
AS
BEGIN
    TRUNCATE TABLE [data_central_wh].[silver].[plsc_vehicle_heartbeats];

    INSERT INTO [data_central_wh].[silver].[plsc_vehicle_heartbeats]
    (
        plt_truck_id, heartbeat_id, msg_type, recv_utc_raw, log_utc_raw,
        speed_raw, distance_unit, heading_cardinal, city, state, country,
        fuel_instant, fuel_total, latitude_raw, longitude_raw, location_desc,
        road_grade_raw, eng_hrs_j1939, windows_mask, acu_raw, sat_count_raw,
        gps_fix_raw, hdop_raw, odometer_raw, odo_j1939_raw, heading_deg_raw,
        ignition_raw, rpm_raw, eng_hrs_total
    )
    SELECT
        PLTHTRUCK , PLTHHBID , PLTHTYPE , PLTHRECV , PLTHLOGA ,
        PLTHSPEED , PLTHRUM , PLTHRDIR , PLTHRCITY , PLTHRSTATE , PLTHRCUNTR ,
        PLTHFUEL  , PLTHFUELU , PLTHLAT , PLTHLON  , PLTHLOCD ,
        PLTHRPD   , PLTHENGHJ , PLTHWINM , PLTHACU , PLTHSAT ,
        PLTHGPSV  , PLTHHDOP  , PLTHODO , PLTHODOJ , PLTHHEAD ,
        PLTHIGNS  , PLTHRPM   , PLTHENGH
    FROM [data_central_lh].[dbo].[PLSC_PLTMHBDP];
END;