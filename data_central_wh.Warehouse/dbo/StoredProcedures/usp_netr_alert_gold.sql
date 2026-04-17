CREATE   PROCEDURE dbo.usp_netr_alert_gold
AS
BEGIN

    DELETE FROM gold.fact_netr_alert;

    ;WITH src AS (
        SELECT
            a.alert_id,
            a.alert_driver_id,
            a.alert_vehicle_vin,
            a.alert_camera_id,
            a.alert_date,
            a.alert_time,
            a.alert_duration,
            a.alert_type_descr,
            a.alert_type_sub_descr,
            a.alert_severity_descr,
            a.alert_category_descr,
            a.alert_cause_descr,
            ISNULL(a.alert_weather_prediction, 'UNKNOWN') AS alert_weather_prediction,
            a.alert_vehicle_status_descr,
            a.alert_gps_date,
            a.alert_gps_time,
            a.alert_gps_latitude,
            a.alert_gps_longitude,
            a.alert_speed,
            a.alert_speed_limit,
            a.alert_status_descr,


            TRY_CONVERT(date, a.alert_gps_date) AS gps_dt,
            TRY_CONVERT(time, a.alert_gps_time) AS gps_tm,
            TRY_CONVERT(date, a.alert_date)     AS evt_dt,
            TRY_CONVERT(time, a.alert_time)     AS evt_tm
        FROM silver.netr_alert a
    ),
    latest AS (
        SELECT
            s.*,
            ROW_NUMBER() OVER (
                PARTITION BY s.alert_id
                ORDER BY 
                    -- prefer GPS timestamp if available, else fall back to event timestamp
                    COALESCE(s.gps_dt, s.evt_dt) DESC,
                    COALESCE(s.gps_tm, s.evt_tm) DESC
            ) AS rn
        FROM src s
    )
    INSERT INTO gold.fact_netr_alert (
          alert_id
        , alert_driver_id
        , alert_vehicle_vin
        , alert_device_id
        , alert_date
        , alert_time
        , alert_duration
        , alert_type
        , alert_sub_type
        , alert_severity
        , alert_category
        , alert_cause
        , alert_weather
        , alert_vehicle_status
        , alert_gps_date
        , alert_gps_time
        , alert_gps_latitude
        , alert_gps_longitude
        , alert_speed
        , alert_speed_limit
        , alert_status
    )
    SELECT
          l.alert_id
        , l.alert_driver_id
        , l.alert_vehicle_vin
        , l.alert_camera_id                                AS alert_device_id
        , l.alert_date
        , l.alert_time
        , l.alert_duration
        , l.alert_type_descr                               AS alert_type
        , l.alert_type_sub_descr                           AS alert_sub_type
        , l.alert_severity_descr                           AS alert_severity
        , l.alert_category_descr                           AS alert_category
        , l.alert_cause_descr                              AS alert_cause
        , l.alert_weather_prediction                        AS alert_weather
        , l.alert_vehicle_status_descr                      AS alert_vehicle_status
        , l.alert_gps_date
        , l.alert_gps_time
        , l.alert_gps_latitude
        , l.alert_gps_longitude
        , l.alert_speed
        , l.alert_speed_limit
        , l.alert_status_descr                             AS alert_status
    FROM latest l
    WHERE l.rn = 1;
END