CREATE   PROCEDURE [dbo].[usp_netr_alert_silver]
AS
BEGIN
  SET NOCOUNT ON;

  INSERT INTO silver.netr_alert
  SELECT DISTINCT
      a.[data.alerts.id]                                            AS alert_id,

      /* from robust UTC parse */
      CAST(p.alert_dt_utc AS date)                                   AS alert_date,
      CONVERT(time(0), p.alert_dt_utc)                               AS alert_time,

      a.[data.alerts.duration]                                       AS alert_duration,
      a.[data.alerts.details.typeId]                                 AS alert_type_id,
      a.[data.alerts.details.typeDescription]                        AS alert_type_descr,
      a.[data.alerts.details.subTypeId]                              AS alert_type_sub_id,
      a.[data.alerts.details.subTypeDescription]                     AS alert_type_sub_descr,
      a.[data.alerts.details.severity]                               AS alert_severity,
      a.[data.alerts.details.severityDescription]                    AS alert_severity_descr,
      a.[data.alerts.details.category]                               AS alert_category,
      a.[data.alerts.details.categoryDescription]                    AS alert_category_descr,
      a.[data.alerts.details.cause]                                  AS alert_cause_id,
      cause.configDescription                                        AS alert_cause_descr,
      a.[data.alerts.details.weatherPrediction]                      AS alert_weather_prediction,

      /* GPS from robust parse */
      CAST(p.alert_gps_dt_utc AS date)                               AS alert_gps_date,
      CONVERT(time(0), p.alert_gps_dt_utc)                           AS alert_gps_time,
      a.[data.alerts.gpsData.latitude]                               AS alert_gps_latitude,
      a.[data.alerts.gpsData.longitude]                              AS alert_gps_longitude,

      a.[data.alerts.vehicle.vin]                                    AS alert_vehicle_vin,
      a.[data.alerts.vehicle.vehicleNumber]                          AS alert_vehcile_vehicleNumber,
      a.[data.alerts.vehicle.status]                                 AS alert_vehicle_status_id,
      vehicle.configDescription                                      AS alert_vehcile_status_descr,

      a.[data.alerts.driver.firstName]                               AS alert_driver_firstname,
      a.[data.alerts.driver.lastName]                                AS alert_driver_lastname,
      a.[data.alerts.driver.driverId]                                AS alert_driver_id,

      a.[data.alerts.videos.id]                                      AS alert_video_id,
      a.[data.alerts.videos.status]                                  AS alert_video_status_id,
      video.configDescription                                        AS alert_video_status_descr,
      a.[data.alerts.videos.position]                                AS alert_video_position_id,
      vPosn.configDescription                                        AS alert_video_position_decr,

      /* video time from robust parse */
      CAST(p.alert_video_dt_utc AS date)                             AS alert_video_date,
      CONVERT(time(0), p.alert_video_dt_utc)                         AS alert_video_time,

      a.[data.alerts.camera.id]                                      AS alert_camera_id,
      a.[data.alerts.alertStatus]                                    AS alert_status_id,
      stat.configDescription                                         AS alert_status_descr,

      a.[data.alerts.speedData.speed]                                AS alert_speed,
      a.[data.alerts.speedData.speedLimit]                           AS alert_speed_limit

  FROM [data_central_lh].[dbo].[netr_alerts_v1_bronze] AS a

  /* lookups */
  LEFT JOIN (
      SELECT CONVERT(BIGINT, configId) AS alertVideoStatusId, configDescription
      FROM   [data_central_lh].[dbo].[netr_config_v2_bronze]
      WHERE  configType = 'videoStatus'
  ) video   ON a.[data.alerts.videos.status] = video.alertVideoStatusId
  LEFT JOIN (
      SELECT CONVERT(BIGINT, configId) AS alertCauseId, configDescription
      FROM   [data_central_lh].[dbo].[netr_config_v2_bronze]
      WHERE  configType = 'alertCause'
  ) cause   ON a.[data.alerts.details.cause] = cause.alertCauseId
  LEFT JOIN (
      SELECT CONVERT(BIGINT, configId) AS alertvStatusId, configDescription
      FROM   [data_central_lh].[dbo].[netr_config_v2_bronze]
      WHERE  configType = 'vehicleStatus'
  ) vehicle ON a.[data.alerts.vehicle.status] = vehicle.alertvStatusId
  LEFT JOIN (
      SELECT CONVERT(BIGINT, configId) AS alertVideoPosnId, configDescription
      FROM   [data_central_lh].[dbo].[netr_config_v2_bronze]
      WHERE  configType = 'cameraConfigurations'
  ) vPosn   ON a.[data.alerts.videos.position] = vPosn.alertVideoPosnId
  LEFT JOIN (
      SELECT CONVERT(BIGINT, configId) AS alertStatusId, configDescription
      FROM   [data_central_lh].[dbo].[netr_config_v2_bronze]
      WHERE  configType = 'alertStatus'
  ) stat    ON a.[data.alerts.alertStatus] = stat.alertStatusId

  /* normalize all timestamp inputs to VARCHAR first (prevents BIGINT->datetime2 cast) */
  CROSS APPLY (SELECT
      TRY_CONVERT(varchar(64), a.[data.alerts.timestamp])        AS ts_alert_str,
      TRY_CONVERT(varchar(64), a.[data.alerts.gpsData.timestamp]) AS ts_gps_str,
      TRY_CONVERT(varchar(64), a.[data.alerts.videos.timestamp])  AS ts_video_str
  ) ts

  /* robust timestamp parsing — ms, sec, or ISO — returning datetime2(6) */
  CROSS APPLY (SELECT
      CASE
        WHEN TRY_CONVERT(bigint, ts.ts_alert_str) IS NOT NULL AND LEN(ts.ts_alert_str) >= 13
          THEN DATEADD(millisecond, CAST(TRY_CONVERT(bigint, ts.ts_alert_str) % 1000 AS int),
               DATEADD(second,     CAST(TRY_CONVERT(bigint, ts.ts_alert_str) / 1000 AS int),
                       CAST('1970-01-01T00:00:00' AS datetime2(6))))
        WHEN TRY_CONVERT(bigint, ts.ts_alert_str) IS NOT NULL
          THEN DATEADD(second, CAST(TRY_CONVERT(bigint, ts.ts_alert_str) AS int),
                       CAST('1970-01-01T00:00:00' AS datetime2(6)))
        ELSE TRY_CONVERT(datetime2(6), ts.ts_alert_str)
      END AS alert_dt_utc,

      CASE
        WHEN TRY_CONVERT(bigint, ts.ts_gps_str) IS NOT NULL AND LEN(ts.ts_gps_str) >= 13
          THEN DATEADD(millisecond, CAST(TRY_CONVERT(bigint, ts.ts_gps_str) % 1000 AS int),
               DATEADD(second,     CAST(TRY_CONVERT(bigint, ts.ts_gps_str) / 1000 AS int),
                       CAST('1970-01-01T00:00:00' AS datetime2(6))))
        WHEN TRY_CONVERT(bigint, ts.ts_gps_str) IS NOT NULL
          THEN DATEADD(second, CAST(TRY_CONVERT(bigint, ts.ts_gps_str) AS int),
                       CAST('1970-01-01T00:00:00' AS datetime2(6)))
        ELSE TRY_CONVERT(datetime2(6), ts.ts_gps_str)
      END AS alert_gps_dt_utc,

      CASE
        WHEN TRY_CONVERT(bigint, ts.ts_video_str) IS NOT NULL AND LEN(ts.ts_video_str) >= 13
          THEN DATEADD(millisecond, CAST(TRY_CONVERT(bigint, ts.ts_video_str) % 1000 AS int),
               DATEADD(second,     CAST(TRY_CONVERT(bigint, ts.ts_video_str) / 1000 AS int),
                       CAST('1970-01-01T00:00:00' AS datetime2(6))))
        WHEN TRY_CONVERT(bigint, ts.ts_video_str) IS NOT NULL
          THEN DATEADD(second, CAST(TRY_CONVERT(bigint, ts.ts_video_str) AS int),
                       CAST('1970-01-01T00:00:00' AS datetime2(6)))
        ELSE TRY_CONVERT(datetime2(6), ts.ts_video_str)
      END AS alert_video_dt_utc
  ) p

  /* de-dupe correctly (avoid NOT IN + NULL issues) */
  WHERE NOT EXISTS (
    SELECT 1 FROM silver.netr_alert s WHERE s.alert_id = a.[data.alerts.id]
  );
END;