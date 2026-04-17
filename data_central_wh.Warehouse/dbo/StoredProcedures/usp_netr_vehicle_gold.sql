/***************************************************************************************************
Procedure:          dbo.usp_netr_vehicle_location_gold
Create Date:        2024-07-22
Author:             Tom Wolfenden
Description:        Move/transform Netradyne vehicle location data from silver to gold
Called by:          Fabric  
					Pipeline: Netradyne\Pipeline\pl_netr_vehicle_v1
Affected table(s):  gold.dim_netr_vehicle
Usage:              EXEC dbo.usp_netr_vehicle_gold

****************************************************************************************************
SUMMARY OF CHANGES
#             Date(yyyy-mm-dd)    Author              Comments
------------------- ------------------ ------------------------------------------------------------
1            
***************************************************************************************************/

CREATE PROCEDURE [dbo].[usp_netr_vehicle_gold]
AS

DELETE FROM gold.dim_netr_vehicle

INSERT INTO gold.dim_netr_vehicle
SELECT DISTINCT
	  a.[vehicle_vin]
	, a.[vehicle_number]
    , a.[vehicle_device_id]
    , a.[vehicle_licence_plate_number]
    , a.[vehicle_class]
    , a.[vehicle_gvm]
    , a.[vehicle_group]
    , a.[vehicle_battery_disconnect]
    , a.[vehicle_reg_date]
    , a.[vehicle_reg_time]
    , a.[vehicle_update_date]
    , a.[vehicle_update_time]
    , a.[vehicle_status]
	, b.location_date									AS vehicle_location_date
	, b.location_time									AS vehicle_location_time
	, b.location_latitude								AS vehicle_location_latitude
	, b.location_longitude								AS vehicle_location_longitude
FROM [silver].[netr_vehicle] a
LEFT JOIN [silver].[netr_vehicle_location] b ON a.vehicle_vin = b.location_vin
JOIN (SELECT c.[vehicle_vin]
		   , MAX(c.vehicle_update_date)	AS max_of_date
		   , MAX(c.vehicle_update_time) AS max_of_time
	  FROM silver.netr_vehicle c 
	  GROUP BY c.vehicle_vin) x				ON a.vehicle_vin = x.vehicle_vin
										   AND a.vehicle_update_date = x.max_of_date
										   AND a.vehicle_update_time = x.max_of_time