-- Auto Generated (Do not modify) D7BC409C7C9A47F04D12D0CD3975821434A47F0B58920F763103EBED70805CA2
-- data_central_wh
CREATE   VIEW gold.vw_truck_positions AS
WITH p AS (
  SELECT
    hb.plt_truck_id,
    hb.heartbeat_id,
    hb.msg_type,

    -- Parse timestamps (handles 'T' and trailing '.')
    TRY_CONVERT(datetime2(0), hb.recv_utc_raw) AS recv_dt,
    TRY_CONVERT(datetime2(0),
      REPLACE(CASE WHEN RIGHT(hb.log_utc_raw,1)='.'
                   THEN LEFT(hb.log_utc_raw, LEN(hb.log_utc_raw)-1)
                   ELSE hb.log_utc_raw END,'T',' ')
    ) AS log_dt,

    TRY_CAST(hb.speed_raw            AS decimal(9,3))  AS speed_mph,
    TRY_CAST(hb.heading_deg_raw      AS decimal(9,3))  AS heading_deg,
    TRY_CAST(hb.rpm_raw              AS decimal(18,3)) AS rpm,
    TRY_CAST(hb.eng_hrs_total        AS decimal(18,3)) AS eng_hrs_total,
    TRY_CAST(hb.eng_hrs_j1939        AS decimal(18,3)) AS eng_hrs_j1939,
    TRY_CAST(hb.fuel_total           AS decimal(18,3)) AS fuel_total,
    TRY_CAST(hb.latitude_raw         AS decimal(9,6))  AS latitude,
    TRY_CAST(hb.longitude_raw        AS decimal(9,6))  AS longitude,
    TRY_CAST(hb.hdop_raw             AS decimal(9,3))  AS hdop,
    TRY_CAST(hb.sat_count_raw        AS int)           AS sat_count,
    CASE WHEN LOWER(CONVERT(varchar(10),hb.gps_fix_raw)) IN ('true','1','t','y','yes') THEN 1 ELSE 0 END AS gps_fix,
    CASE WHEN LOWER(CONVERT(varchar(10),hb.ignition_raw)) IN ('true','1','t','y','yes') THEN 1 ELSE 0 END AS ignition,

    hb.location_desc, hb.heading_cardinal, hb.city, hb.state, hb.country
  FROM silver.plsc_vehicle_heartbeats hb
),
b AS (
  SELECT
    plt_truck_id, heartbeat_id, msg_type,
    COALESCE(recv_dt, log_dt) AS ts_utc,
    speed_mph, heading_deg, rpm, eng_hrs_total, eng_hrs_j1939, fuel_total,
    latitude, longitude, hdop, sat_count, gps_fix, ignition,
    location_desc, heading_cardinal, city, state, country
  FROM p
  WHERE COALESCE(recv_dt,log_dt) IS NOT NULL
)
SELECT
  *,
  CASE
    WHEN latitude BETWEEN -90 AND 90
     AND longitude BETWEEN -180 AND 180
     AND gps_fix = 1
     AND (hdop IS NULL OR hdop <= 6)
  THEN 1 ELSE 0 END AS is_valid_gps,
  CASE WHEN speed_mph >= 3 OR (rpm >= 500 AND ignition=1) THEN 'Moving' ELSE 'Stopped' END AS motion_status
FROM b;