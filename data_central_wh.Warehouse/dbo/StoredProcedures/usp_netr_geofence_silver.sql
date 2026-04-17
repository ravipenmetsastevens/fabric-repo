/***************************************************************************************************
Procedure:          dbo.usp_netr_geofence_silver
Create Date:        2024-07-22
Author:             Tom Wolfenden
Description:        Move/transform Netradyne geofence data from bronze to silver
Called by:          Fabric  
					Pipeline: Netradyne\Pipeline\pl_netr_geofence_v1
Affected table(s):  silver.netr_geofence
Usage:              EXEC dbo.usp_netr_geofence_silver

****************************************************************************************************
SUMMARY OF CHANGES
#             Date(yyyy-mm-dd)    Author              Comments
------------------- ------------------ ------------------------------------------------------------
1            
***************************************************************************************************/

CREATE PROCEDURE [dbo].[usp_netr_geofence_silver]
AS

DELETE FROM silver.netr_geofence

INSERT INTO silver.netr_geofence
SELECT
	  a.[data.id]														AS geofence_id
	, a.[data.name]														AS geofence_name
	, a.[data.typeName]													AS geofence_type
	, a.[data.subTypeName]												AS geofence_sub_type
	, a.[data.shape]													AS geofence_shape
	, a.[data.address.country]											AS geofence_country
    , a.[data.address.stateProvince]									AS geofence_state
    , a.[data.address.city]												AS geofence_city
    , a.[data.address.streetNumberName]									AS geofence_street
    , a.[data.address.zipCode]											AS geofence_zipcode
    , a.[data.radius]													AS geofence_radius
    , a.[data.duration]													AS geofence_duration
    , a.[data.center]													
	, CAST(
		LEFT(a.[data.center], CHARINDEX('-', a.[data.center]) - 1)
			AS FLOAT)													AS geofence_center_latitude
	, CAST(
		RIGHT(a.[data.center],
			LEN(a.[data.center]) - CHARINDEX('-', a.[data.center]) + 1)
				AS FLOAT)												AS geofence_center_longitude    
    , a.[data.polygon]
	, CAST(
		LEFT(a.[data.polygon], CHARINDEX('-', a.[data.polygon]) - 1)
			AS FLOAT)													AS geofence_polygon_latitude
	, CAST(
		RIGHT(a.[data.polygon],
			LEN(a.[data.polygon]) - CHARINDEX('-', a.[data.polygon]) + 1)
				AS FLOAT)												AS geofence_polygon_longitude
	, a.[data.status]
FROM data_central_lh.[dbo].[netr_geofences_v1_bronze] a