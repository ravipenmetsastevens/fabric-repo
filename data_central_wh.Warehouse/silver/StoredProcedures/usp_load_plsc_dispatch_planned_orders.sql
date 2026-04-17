/*═════════════════════════════════════════════════════════════
  Load / refresh stored procedure
═════════════════════════════════════════════════════════════*/
CREATE   PROCEDURE [silver].[usp_load_plsc_dispatch_planned_orders]
AS
BEGIN
    -- simple truncate‑and‑reload pattern
    TRUNCATE TABLE [data_central_wh].[silver].[plsc_dispatch_planned_orders];

    INSERT INTO [data_central_wh].[silver].[plsc_dispatch_planned_orders]
    (
        planned_order_id_raw, dispatch_status_raw, driver_code_raw,
        mh_date_raw, mh_date_iso_raw, mh_time_raw
    )
    SELECT
        PLACTORD, PLACTDISP, PLDRVCODE,
        PLMHDATE, PLMHDATE_CONV, PLMHTIME
    FROM [data_central_lh].[dbo].[PLSC_PLACTORDP2];
END;