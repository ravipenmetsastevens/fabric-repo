/***************************************************************************************************
Procedure:          dbo.usp_trkg_getdata_v1_gold
Create Date:        2024-09-13
Author:             Tom Wolfenden
Description:        Move/transform ThermoKing data from silver to gold
Called by:          Fabric  
					Pipeline: ThermoKing\Pipeline\pl_trkg_getdata_v1
Affected table(s):  silver.trkg_getdata_v1
Usage:              EXEC dbo.usp_trkg_getdata_v1_gold

****************************************************************************************************
SUMMARY OF CHANGES
#             Date(yyyy-mm-dd)    Author              Comments
------------------- ------------------ ------------------------------------------------------------
1            
***************************************************************************************************/

CREATE PROCEDURE [dbo].[usp_trkg_getdata_v1_gold]
AS

-- TRAILERS  UNIQUE
DELETE FROM gold.dim_thermoking_trailer

INSERT INTO gold.dim_thermoking_trailer
SELECT DISTINCT	
	  a.vehicleName
	, a.reeferSerialNumber
	, a.trailer_VIN
	, a.truck_VIN
	, a.wirelessGen
	, a.doorlockfitted										   AS isDoorLockFitted
	, a.fuelTankSize
FROM [silver].[trkg_getdata_v1] a

-- LOCATION
DELETE FROM gold.fact_thermoking_location

INSERT INTO gold.fact_thermoking_location
SELECT DISTINCT
	  a.vehicleName
	, a.dataDate
	, a.dataTime
	, a.thermoking_latitude
	, a.thermoking_longitude
	, a.locationDescription
	, a.speed													AS speed_kmph
	, CAST(ROUND(a.speed * 0.62137119, 0) AS INT)				AS speed_mph
	, a.geoFenceName
	, a.geoAccessTypeDescription
FROM [silver].[trkg_getdata_v1] a

-- ALARMS
DELETE FROM gold.fact_thermoking_alarm

INSERT INTO gold.fact_thermoking_alarm
SELECT DISTINCT
	  a.vehicleName
	, a.dataDate
	, a.dataTime
	, a.alarmCode
	, a.alarmDescription
	, a.alarmSeverity
	, a.alarmRecommendation
	, a.alarmZone
FROM [silver].[trkg_getdata_v1] a
WHERE a.alarmCode IS NOT NULL

-- REEFER
DELETE FROM gold.fact_thermoking_reefer_status

INSERT INTO gold.fact_thermoking_reefer_status
SELECT DISTINCT
	  a.vehicleName
	, a.dataDate
	, a.dataTime
	, a.powerOn											AS isPowerOn
	, a.voltage
	, a.fuelLevel
	, a.dischargeAir1									AS dischargeAirTemp_C
	, ROUND((a.dischargeAir1 * 1.8) + 32, 2)			AS dischargeAirTemp_F
	, a.returnAir1										AS returnAirTemp_C
	, ROUND((a.returnAir1 * 1.8) + 32, 2)				AS returnAirTemp_F
	, a.setPoint1										AS setPointTemp_C
	, ROUND((a.setPoint1 * 1.8) + 32, 2)				AS setPointTemp_F
	, a.ambientTemperature								AS ambientTemp_C
	, ROUND((a.ambientTemperature * 1.8) + 32, 2)		AS ambientTemp_F
	, a.doorStatus
	, a.doorlocked
	, a.operatingMode1									AS operatingMode
	, a.engineHours	
	, a.engineRpm		
	, a.electricalHours
	, a.totalHours
	, a.unitMode
	, a.unitModeDetail
	, a.powerSource
	, a.devicePortA
	, a.devicePortB
	, a.devicePortC
	, a.multiTemp
	, a.maintenanceHours
	, a.odometer
	, a.controllerStatus
FROM [silver].[trkg_getdata_v1] a

--ZONES
DELETE FROM gold.fact_thermoking_reefer_zones

INSERT INTO gold.fact_thermoking_reefer_zones
SELECT DISTINCT
	  a.vehicleName
	, a.dataDate
	, a.dataTime
	, a.zone1Active										AS isZone1Active
	, a.zone1Configured									AS isZone1Configured
	, a.zone1DoorOpen									AS isZone1DoorOpen
	, a.zone2Active										AS isZone2Active
	, a.zone2Configured									AS isZone2Configured
	, a.zone2DoorOpen									AS isZone2DoorOpen
	, a.zone3Active										AS isZone3Active
	, a.zone3Configured									AS isZone3Configured
	, a.zone3DoorOpen									AS isZone3DoorOpen
FROM [silver].[trkg_getdata_v1] a
WHERE
	  a.zone1Active IS NOT NULL
OR	  a.zone1Configured IS NOT NULL
OR	  a.zone1DoorOpen IS NOT NULL
OR	  a.zone2Active IS NOT NULL
OR	  a.zone2Configured IS NOT NULL
OR	  a.zone2DoorOpen IS NOT NULL
OR	  a.zone3Active IS NOT NULL
OR	  a.zone3Configured IS NOT NULL
OR	  a.zone3DoorOpen IS NOT NULL