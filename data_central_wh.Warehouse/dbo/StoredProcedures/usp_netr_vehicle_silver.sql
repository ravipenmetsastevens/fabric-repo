/***************************************************************************************************
Procedure:          dbo.usp_netr_vehicle_silver
Create Date:        2024-07-22
Author:             Tom Wolfenden
Description:        Move/transform Netradyne vehicle data from bronze to silver
Called by:          Fabric  
					Pipeline: Netradyne\Pipeline\pl_netr_vehicle_v1
Affected table(s):  silver.netr_vehicle
Usage:              EXEC dbo.usp_netr_vehicle_silver

****************************************************************************************************
SUMMARY OF CHANGES
#             Date(yyyy-mm-dd)    Author              Comments
------------------- ------------------ ------------------------------------------------------------
1            
***************************************************************************************************/

CREATE PROCEDURE [dbo].[usp_netr_vehicle_silver]
AS

DELETE FROM silver.netr_vehicle

INSERT INTO silver.netr_vehicle
SELECT DISTINCT
	  a.[data.vehicles.vin]											AS vehicle_vin
	, a.[data.vehicles.vehicleNumber]								AS vehicle_number
	, ISNULL(a.[data.vehicles.deviceId], 'unknown')					AS vehicle_device_id
	--, a.[data.vehicles.camera.id]									AS vehicle_camera_id
	, a.[data.vehicles.licensePlateNumber]							AS vehicle_licence_plate_number
	, a.[data.vehicles.vehicleDetails.class]						AS vehicle_class
	, ISNULL(a.[data.vehicles.vehicleDetails.gVM],'unknown')		AS vehicle_gvm
	, ISNULL(a.[data.vehicles.group.groupName], 'unknown')			AS vehicle_group
	, CASE a.[data.vehicles.batteryToMasterSwitchDisconnected]
		WHEN 0 THEN 'not sure'
		WHEN 1 THEN 'yes'
		WHEN 2 THEN 'no'	END										AS vehicle_battery_disconnect				
	, CONVERT(DATE,
		DATEADD(S, 
			CONVERT(INT, LEFT(a.[data.vehicles.regdDate], 10)
				), '1970-01-01'))									AS vehicle_reg_date
	, CONVERT(TIME(0),
		DATEADD(S, 
			CONVERT(INT, LEFT(a.[data.vehicles.regdDate], 10)
				), '1970-01-01'))									AS vehicle_reg_time
	, CONVERT(DATE,
		DATEADD(S, 
			CONVERT(INT, LEFT(a.[data.vehicles.updatedOn], 10)
				), '1970-01-01'))									AS vehicle_update_date
	, CONVERT(TIME(0),
		DATEADD(S, 
			CONVERT(INT, LEFT(a.[data.vehicles.updatedOn], 10)
				), '1970-01-01'))									AS vehicle_update_time
	, CASE [data.vehicles.status]
		WHEN 0 THEN 'disabled'
		WHEN 1 THEN 'enabled'	END									AS vehicle_status
FROM data_central_lh.[dbo].[netr_vehicles_v1_bronze] a