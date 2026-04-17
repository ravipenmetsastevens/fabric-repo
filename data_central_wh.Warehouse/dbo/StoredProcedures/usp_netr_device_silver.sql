/***************************************************************************************************
Procedure:          dbo.usp_netr_device_silver
Create Date:        2024-07-22
Author:             Tom Wolfenden
Description:        Move/transform Netradyne device data from bronze to silver
Called by:          Fabric  
					Pipeline: Netradyne\Pipeline\pl_netr_devices_v1
Affected table(s):  silver.netr_device
Usage:              EXEC dbo.usp_netr_device_silver

****************************************************************************************************
SUMMARY OF CHANGES
#             Date(yyyy-mm-dd)    Author              Comments
------------------- ------------------ ------------------------------------------------------------
1            
***************************************************************************************************/

CREATE PROCEDURE [dbo].[usp_netr_device_silver]
AS

DELETE FROM silver.netr_device

INSERT INTO silver.netr_device
SELECT
	  CONVERT(BIGINT, [data.cameraMapping.camera.id])				AS device_id
	, [data.cameraMapping.camera.productType]						AS device_product_type
	, [data.cameraMapping.vehicle.vin]								AS device_vehicle_vin
	, [data.cameraMapping.vehicle.vehicleNumber]					AS device_vehicle_number
	, [data.cameraMapping.vehicle.status]							AS device_vehicle_status
	, [data.cameraMapping.vehicle.licensePlateNumber]				AS device_vehicle_license_plate_number
	--, [data.cameraMapping.vehicle.associationTime]					AS device_vehicle_association_time
	, [data.cameraMapping.driver.firstName]							AS device_driver_firstname
	, [data.cameraMapping.driver.lastName]							AS device_driver_lastname
	, [data.cameraMapping.driver.driverId]							AS device_driver_id						
	, CONVERT(DATE,
		DATEADD(S, 
			CONVERT(INT, LEFT([data.cameraMapping.updatedOn], 10)
				), '1970-01-01'))									AS device_updated_date
	, CONVERT(TIME(0),
		DATEADD(S, 
			CONVERT(INT, LEFT([data.cameraMapping.updatedOn], 10)
				), '1970-01-01'))									AS device_updated_time
	, [data.cameraMapping.group.groupName]							AS device_groupname
	, [data.cameraMapping.group.groupUniqueName]					AS device_unique_groupname
FROM data_central_lh.[dbo].[netr_devices_v1_bronze]