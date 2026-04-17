/***************************************************************************************************
Procedure:          dbo.usp_flrk_dim_maint_unit
Create Date:        2024-05-19
Author:             Tom Wolfenden
Description:        Add data for Fleetrock units from silver to gold
Called by:          Fabric  
					Pipeline: Fleetrock\Pipeline\pl_flrk_unit
Affected table(s):  gold.dim_maint_unit
Usage:              EXEC dbo.usp_flrk_dim_maint_unit

****************************************************************************************************
SUMMARY OF CHANGES
#             Date(yyyy-mm-dd)    Author              Comments
------------------- ------------------ ------------------------------------------------------------
1            
***************************************************************************************************/

CREATE PROCEDURE [dbo].[usp_flrk_dim_maint_unit]
AS

-- update existing units
UPDATE [gold].[dim_maint_unit] SET
		[unit_vin]						= s.unit_vin
      , [unit_group]					= s.unit_group
      , [unit_number]					= s.unit_number
      , [unit_custom_id]				= s.unit_custom_id
      , [unit_type]						= s.unit_type
      , [unit_year]						= s.unit_year
      , [unit_make]						= s.unit_make
      , [unit_model]					= s.unit_model
      , [unit_manufacturer]				= s.unit_manufacturer
      , [unit_odometer_miles]			= s.unit_odometer_miles
      , [unit_engine_hours]				= s.unit_engine_hours
      , [unit_in_service_date]			= CONVERT(DATE, s.unit_in_service_date)
      , [unit_tag]						= s.unit_tag
      , [unit_status]					= s.unit_status
FROM [gold].[dim_maint_unit] t
JOIN [silver].[flrk_unit] s ON t.unit_vin = s.unit_vin

--insert new units
INSERT INTO [gold].[dim_maint_unit]
SELECT       
	   s.[unit_vin]
	 , s.[unit_group]
     , s.[unit_number]
     , s.[unit_custom_id]
     , s.[unit_type]
     , s.[unit_year]
     , s.[unit_make]
     , s.[unit_model]
     , s.[unit_manufacturer]
     , s.[unit_odometer_miles]
     , s.[unit_engine_hours]
     , CONVERT(DATE, s.[unit_in_service_date])
     , s.[unit_tag]
     , s.[unit_status]
FROM [silver].[flrk_unit] s
LEFT JOIN [gold].[dim_maint_unit] t on s.unit_vin = t.unit_vin
WHERE t.unit_vin IS NULL