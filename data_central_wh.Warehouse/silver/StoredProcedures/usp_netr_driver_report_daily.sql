CREATE   PROCEDURE [silver].[usp_netr_driver_report_daily]
    @snapshot_date date
AS
BEGIN
    SET NOCOUNT ON;

    -- 1) Remove existing slice (idempotent)
    DELETE FROM [silver].[netr_driver_report_daily]
    WHERE snapshot_date = @snapshot_date;

    -- 2) Insert fresh slice from Bronze shortcut
    INSERT INTO [silver].[netr_driver_report_daily] (
        driver_id, first_name, last_name, driver_score, minutes_analyzed,
        green_minutes_pct, overspeeding_pct, snapshot_date, loaded_at_utc
    )
    SELECT
        b.driver_id,
        b.first_name,
        b.last_name,
        b.driver_score,
        b.minutes_analyzed,
        b.green_minutes_pct,
        b.overspeeding_pct,
        b.snapshot_date,
        SYSUTCDATETIME() AS loaded_at_utc
    FROM data_central_lh.dbo.netr_driver_report_daily_bronze AS b
    WHERE b.snapshot_date = @snapshot_date and b.driver_id is not null;
END;