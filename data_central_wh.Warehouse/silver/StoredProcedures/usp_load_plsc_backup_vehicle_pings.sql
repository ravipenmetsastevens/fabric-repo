/*───────── LOAD PROCEDURE ─────────*/
CREATE   PROCEDURE [silver].[usp_load_plsc_backup_vehicle_pings]
AS
BEGIN
    TRUNCATE TABLE [data_central_wh].[silver].[plsc_backup_vehicle_pings];

    INSERT INTO [data_central_wh].[silver].[plsc_backup_vehicle_pings]
    (
        vehicle_id, gps_epoch_raw, gps_timestamp_utc, arrv_epoch_raw, arrv_timestamp_utc,
        msg_type_code, latitude_raw, longitude_raw, trip_distance_raw, heading_deg_raw,
        speed_mph_raw, odometer_miles_raw, gm_hours_raw, bt_input_raw,
        next_stop_lat_raw, next_stop_lon_raw, last_stop_lat_raw, last_stop_lon_raw,
        position_source, sio_type, ignition_status_raw, mobile_activity_raw,
        mobile_machine_code_raw, protocol_version_raw
    )
    SELECT
        PHVEH, PHTIME, PHTIME_DT, PHARRV, PHARRV_DT,
        PHTYPE, PHLAT, PHLON, PHLTDD, PHDIRC,
        PHSPED, PHODOM, PHGMH, PHBTIN,
        PHNXST, PHNXSA, PHLSST, PHLSSA,
        PHPSRC, PHSIOT, PHIGST, PHMACT,
        PHMAC, PHVER
    FROM [data_central_lh].[dbo].[PLSC_BACKUPVEH1];
END;