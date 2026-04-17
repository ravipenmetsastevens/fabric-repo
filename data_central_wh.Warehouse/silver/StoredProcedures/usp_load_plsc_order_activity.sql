/*═════════════════════════════════════════════════════════════
  Load / refresh stored procedure
═════════════════════════════════════════════════════════════*/
CREATE   PROCEDURE [silver].[usp_load_plsc_order_activity]
AS
BEGIN
    TRUNCATE TABLE [data_central_wh].[silver].[plsc_order_activity];

    INSERT INTO [data_central_wh].[silver].[plsc_order_activity]
    (
        ao_date_raw, ao_time_raw, ao_pr_date_raw, ao_proc_code_raw,
        ao_return_type_raw, ao_order_id_raw, ao_movement_type_raw, ao_unit_raw
    )
    SELECT
        PLAODATE, PLAOTIME, PLAOPRDATE, PLAOPROC,
        PLAORETY, PLAOORD, PLAOMTYPE, PLAOUNIT
    FROM [data_central_lh].[dbo].[PLSC_PLTAOORDP];
END;