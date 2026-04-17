CREATE   PROCEDURE [dbo].[usp_netr_alert_silver_range]
  @from_date date,   -- inclusive UTC date
  @to_date   date    -- inclusive UTC date
AS
BEGIN
  SET NOCOUNT ON;

  DECLARE @epoch datetime2(6) = '1970-01-01T00:00:00';

  IF OBJECT_ID('tempdb..#base')  IS NOT NULL DROP TABLE #base;
  IF OBJECT_ID('tempdb..#stage') IS NOT NULL DROP TABLE #stage;

  /* 1) Build #base: parse vid_dt, gps_dt, alt_dt (NO filtering here) */
  SELECT DISTINCT
      a.[data.alerts.id]                      AS alert_id,
      a.[data.alerts.duration]                AS alert_duration,
      a.[data.alerts.details.typeId]          AS alert_type_id,
      a.[data.alerts.details.typeDescription] AS alert_type_descr,
      a.[data.alerts.details.subTypeId]       AS alert_type_sub_id,
      a.[data.alerts.details.subTypeDescription] AS alert_type_sub_descr,
      a.[data.alerts.details.severity]        AS alert_severity,
      a.[data.alerts.details.severityDescription] AS alert_severity_descr,
      a.[data.alerts.details.category]        AS alert_category,
      a.[data.alerts.details.categoryDescription] AS alert_category_descr,
      a.[data.alerts.details.cause]           AS alert_cause_id,
      a.[data.alerts.details.weatherPrediction] AS alert_weather_prediction,
      a.[data.alerts.gpsData.latitude]        AS alert_gps_latitude,
      a.[data.alerts.gpsData.longitude]       AS alert_gps_longitude,
      a.[data.alerts.vehicle.vin]             AS alert_vehicle_vin,
      a.[data.alerts.vehicle.vehicleNumber]   AS alert_vehicle_vehicleNumber,
      a.[data.alerts.vehicle.status]          AS alert_vehicle_status_id,
      a.[data.alerts.driver.firstName]        AS alert_driver_firstname,
      a.[data.alerts.driver.lastName]         AS alert_driver_lastname,
      a.[data.alerts.driver.driverId]         AS alert_driver_id,
      a.[data.alerts.videos.id]               AS alert_video_id,
      a.[data.alerts.videos.status]           AS alert_video_status_id,
      a.[data.alerts.videos.position]         AS alert_video_position_id,
      a.[data.alerts.camera.id]               AS alert_camera_id,
      a.[data.alerts.alertStatus]             AS alert_status_id,
      a.[data.alerts.speedData.speed]         AS alert_speed,
      a.[data.alerts.speedData.speedLimit]    AS alert_speed_limit,

      /* videos.timestamp -> vid_dt (ms/sec/ISO) */
      CASE
        WHEN TRY_CONVERT(bigint, TRY_CONVERT(varchar(64), a.[data.alerts.videos.timestamp])) IS NOT NULL
             AND LEN(TRY_CONVERT(varchar(64), a.[data.alerts.videos.timestamp])) >= 13
          THEN DATEADD(millisecond,
                 CAST(TRY_CONVERT(bigint, TRY_CONVERT(varchar(64), a.[data.alerts.videos.timestamp])) % 1000 AS int),
                 DATEADD(second,
                   CAST(TRY_CONVERT(bigint, TRY_CONVERT(varchar(64), a.[data.alerts.videos.timestamp])) / 1000 AS int),
                   @epoch))
        WHEN TRY_CONVERT(bigint, TRY_CONVERT(varchar(64), a.[data.alerts.videos.timestamp])) IS NOT NULL
          THEN DATEADD(second,
                 CAST(TRY_CONVERT(bigint, TRY_CONVERT(varchar(64), a.[data.alerts.videos.timestamp])) AS int),
                 @epoch)
        ELSE TRY_CONVERT(datetime2(6), TRY_CONVERT(varchar(64), a.[data.alerts.videos.timestamp]))
      END AS vid_dt,

      /* gpsData.timestamp -> gps_dt */
      CASE
        WHEN TRY_CONVERT(bigint, TRY_CONVERT(varchar(64), a.[data.alerts.gpsData.timestamp])) IS NOT NULL
             AND LEN(TRY_CONVERT(varchar(64), a.[data.alerts.gpsData.timestamp])) >= 13
          THEN DATEADD(millisecond,
                 CAST(TRY_CONVERT(bigint, TRY_CONVERT(varchar(64), a.[data.alerts.gpsData.timestamp])) % 1000 AS int),
                 DATEADD(second,
                   CAST(TRY_CONVERT(bigint, TRY_CONVERT(varchar(64), a.[data.alerts.gpsData.timestamp])) / 1000 AS int),
                   @epoch))
        WHEN TRY_CONVERT(bigint, TRY_CONVERT(varchar(64), a.[data.alerts.gpsData.timestamp])) IS NOT NULL
          THEN DATEADD(second,
                 CAST(TRY_CONVERT(bigint, TRY_CONVERT(varchar(64), a.[data.alerts.gpsData.timestamp])) AS int),
                 @epoch)
        ELSE TRY_CONVERT(datetime2(6), TRY_CONVERT(varchar(64), a.[data.alerts.gpsData.timestamp]))
      END AS gps_dt,

      /* data.alerts.timestamp -> alt_dt */
      CASE
        WHEN TRY_CONVERT(bigint, TRY_CONVERT(varchar(64), a.[data.alerts.timestamp])) IS NOT NULL
             AND LEN(TRY_CONVERT(varchar(64), a.[data.alerts.timestamp])) >= 13
          THEN DATEADD(millisecond,
                 CAST(TRY_CONVERT(bigint, TRY_CONVERT(varchar(64), a.[data.alerts.timestamp])) % 1000 AS int),
                 DATEADD(second,
                   CAST(TRY_CONVERT(bigint, TRY_CONVERT(varchar(64), a.[data.alerts.timestamp])) / 1000 AS int),
                   @epoch))
        WHEN TRY_CONVERT(bigint, TRY_CONVERT(varchar(64), a.[data.alerts.timestamp])) IS NOT NULL
          THEN DATEADD(second,
                 CAST(TRY_CONVERT(bigint, TRY_CONVERT(varchar(64), a.[data.alerts.timestamp])) AS int),
                 @epoch)
        ELSE TRY_CONVERT(datetime2(6), TRY_CONVERT(varchar(64), a.[data.alerts.timestamp]))
      END AS alt_dt
  INTO #base
  FROM [data_central_lh].[dbo].[netr_alerts_v1_bronze] AS a;

  /* 2) Build #stage: add unified event clock (video → gps → alert.ts) */
  SELECT
      b.*,
      COALESCE(b.vid_dt, b.gps_dt, b.alt_dt) AS event_dt_utc
  INTO #stage
  FROM #base b;

  /* 3) Slice-replace in Silver using ONLY event_dt_utc */
  DELETE FROM [silver].[netr_alert]
  WHERE alert_date BETWEEN @from_date AND @to_date;

  INSERT INTO [silver].[netr_alert] (
    alert_id, alert_date, alert_time, alert_duration,
    alert_type_id, alert_type_descr, alert_type_sub_id, alert_type_sub_descr,
    alert_severity, alert_severity_descr, alert_category, alert_category_descr,
    alert_cause_id, alert_cause_descr, alert_weather_prediction,
    alert_gps_date, alert_gps_time, alert_gps_latitude, alert_gps_longitude,
    alert_vehicle_vin, alert_vehicle_vehicleNumber,
    alert_vehicle_status_id, alert_vehicle_status_descr,
    alert_driver_firstname, alert_driver_lastname, alert_driver_id,
    alert_video_id, alert_video_status_id, alert_video_status_descr,
    alert_video_position_id, alert_video_position_decr,
    alert_video_date, alert_video_time,
    alert_camera_id, alert_status_id, alert_status_descr,
    alert_speed, alert_speed_limit
  )
  SELECT DISTINCT
      s.alert_id,
      CAST(s.event_dt_utc AS date)                                 AS alert_date,
      CONVERT(time(0), s.event_dt_utc)                              AS alert_time,
      TRY_CONVERT(float, s.alert_duration),
      s.alert_type_id, s.alert_type_descr, s.alert_type_sub_id, s.alert_type_sub_descr,
      s.alert_severity, s.alert_severity_descr, s.alert_category, s.alert_category_descr,
      s.alert_cause_id, cause.configDescription                     AS alert_cause_descr,
      s.alert_weather_prediction,
      CAST(s.gps_dt AS date)                                        AS alert_gps_date,
      CONVERT(time(0), s.gps_dt)                                    AS alert_gps_time,
      TRY_CONVERT(float, s.alert_gps_latitude),
      TRY_CONVERT(float, s.alert_gps_longitude),
      s.alert_vehicle_vin, s.alert_vehicle_vehicleNumber,
      s.alert_vehicle_status_id, vehicle.configDescription          AS alert_vehicle_status_descr,
      s.alert_driver_firstname, s.alert_driver_lastname, s.alert_driver_id,
      s.alert_video_id, s.alert_video_status_id, video.configDescription AS alert_video_status_descr,
      s.alert_video_position_id, vPosn.configDescription            AS alert_video_position_decr,
      CAST(s.vid_dt AS date)                                        AS alert_video_date,
      CONVERT(time(0), s.vid_dt)                                    AS alert_video_time,
      s.alert_camera_id, s.alert_status_id, stat.configDescription  AS alert_status_descr,
      TRY_CONVERT(float, s.alert_speed), TRY_CONVERT(float, s.alert_speed_limit)
  FROM #stage s
  LEFT JOIN (SELECT CONVERT(BIGINT, configId) AS alertVideoStatusId, configDescription
             FROM [data_central_lh].[dbo].[netr_config_v2_bronze]
             WHERE configType='videoStatus') video
    ON TRY_CONVERT(BIGINT, s.alert_video_status_id) = video.alertVideoStatusId
  LEFT JOIN (SELECT CONVERT(BIGINT, configId) AS alertCauseId, configDescription
             FROM [data_central_lh].[dbo].[netr_config_v2_bronze]
             WHERE configType='alertCause') cause
    ON TRY_CONVERT(BIGINT, s.alert_cause_id) = cause.alertCauseId
  LEFT JOIN (SELECT CONVERT(BIGINT, configId) AS alertvStatusId, configDescription
             FROM [data_central_lh].[dbo].[netr_config_v2_bronze]
             WHERE configType='vehicleStatus') vehicle
    ON TRY_CONVERT(BIGINT, s.alert_vehicle_status_id) = vehicle.alertvStatusId
  LEFT JOIN (SELECT CONVERT(BIGINT, configId) AS alertVideoPosnId, configDescription
             FROM [data_central_lh].[dbo].[netr_config_v2_bronze]
             WHERE configType='cameraConfigurations') vPosn
    ON TRY_CONVERT(BIGINT, s.alert_video_position_id) = vPosn.alertVideoPosnId
  LEFT JOIN (SELECT CONVERT(BIGINT, configId) AS alertStatusId, configDescription
             FROM [data_central_lh].[dbo].[netr_config_v2_bronze]
             WHERE configType='alertStatus') stat
    ON TRY_CONVERT(BIGINT, s.alert_status_id) = stat.alertStatusId
  WHERE s.event_dt_utc IS NOT NULL
    AND CAST(s.event_dt_utc AS date) BETWEEN @from_date AND @to_date;
END;