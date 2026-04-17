/***************************************************************************************************
Procedure:          dbo.usp_netr_vehicle_location_silver
Create Date:        2024-07-22
Author:             Tom Wolfenden
Description:        Move/transform Netradyne vehicle location data from bronze to silver
Called by:          Fabric  
					Pipeline: Netradyne\Pipeline\pl_netr_vehicle_location_v1
Affected table(s):  silver.netr_vehicle_location
Usage:              EXEC dbo.usp_netr_vehicle_location_silver

****************************************************************************************************
SUMMARY OF CHANGES
#             Date(yyyy-mm-dd)    Author              Comments
------------------- ------------------ ------------------------------------------------------------
1            
***************************************************************************************************/

CREATE PROCEDURE [dbo].[usp_netr_vehicle_location_silver]
AS

DELETE FROM silver.netr_vehicle_location

INSERT INTO silver.netr_vehicle_location
SELECT DISTINCT
	  a.[data.locations.vehicle.vin]								AS location_vin
	, a.[data.locations.vehicle.vehicleNumber]						AS location_vehicle_number
	, CONVERT(DATE,
		DATEADD(S, 
			CONVERT(INT, LEFT(a.[data.locations.location.timestamp], 10)
				), '1970-01-01'))									AS location_date
	, CONVERT(TIME(0),
		DATEADD(S, 
			CONVERT(INT, LEFT(a.[data.locations.location.timestamp], 10)
				), '1970-01-01'))									AS location_time
	, a.[data.locations.location.latitude]							AS location_latitude
	, a.[data.locations.location.longitude]							AS location_longitude
FROM data_central_lh.[dbo].[netr_vehicle_location_v1_bronze] a