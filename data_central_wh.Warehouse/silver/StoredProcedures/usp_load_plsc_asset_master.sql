/* =====================================================================
   Silver asset master – simple reload
   Source  : data_central_lh.dbo.plsc_asset_bronze
   Target  : data_central_wh.silver.plsc_asset_master
   =====================================================================*/
CREATE   PROCEDURE [silver].[usp_load_plsc_asset_master]
AS
BEGIN
    SET NOCOUNT ON;

    -- 1.  Clear the silver table
    TRUNCATE TABLE [data_central_wh].[silver].[plsc_asset_master];

    -- 2.  Reload from bronze
    INSERT INTO [data_central_wh].[silver].[plsc_asset_master] (
          asset_id
        , unit_number
        , vin
        , license_plate
        , plate_state
        , terminal
        , make
        , model
        , telematics_guid
    )
    SELECT
          src.[data.id]                            AS asset_id
        , src.[data.external_id]                   AS unit_number
        , src.[data.hardware_id]                   AS vin
        , NULLIF(src.[data.license_plate_number]         , '') AS license_plate
        , NULLIF(src.[data.license_plate_jurisdiction]   , '') AS plate_state
        , NULLIF(src.[data.terminal]                     , '') AS terminal
        , UPPER(LTRIM(RTRIM(src.[data.make])))      AS make
        , UPPER(LTRIM(RTRIM(src.[data.model])))     AS model
        , src.[data.hardware_id]                   AS telematics_guid   -- same as VIN in the API feed
    FROM [data_central_lh].[dbo].[plsc_asset_bronze] src;
END;