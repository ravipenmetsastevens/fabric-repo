/***************************************************************************************************
Procedure:          dbo.usp_trkg_getdata_v1_silver
Create Date:        2024-09-12
Author:             Tom Wolfenden
Description:        Move/transform ThermoKing data from bronze to silver
Called by:          Fabric  
					Pipeline: ThermoKing\Pipeline\pl_trkg_getdata_v1
Affected table(s):  silver.trkg_getdata_v1
Usage:              EXEC dbo.usp_trkg_getdata_v1_silver

****************************************************************************************************
SUMMARY OF CHANGES
#             Date(yyyy-mm-dd)    Author              Comments
------------------- ------------------ ------------------------------------------------------------
1            
***************************************************************************************************/

CREATE PROCEDURE dbo.usp_trkg_getdata_v1_silver
AS

DELETE FROM silver.trkg_getdata_v1

INSERT INTO silver.trkg_getdata_v1
SELECT DISTINCT
	  a.vehicleName
	, CASE a.[externalId] 
		WHEN '' THEN NULL
		ELSE a.externalId END									AS externalId
	, TRIM(a.reeferSerialNumber)								AS reeferSerialNumber
	, a.truck_VIN
	, a.trailer_VIN
	, CONVERT(DATE, LEFT(a.dataDate, 10))						AS dataDate
	, CONVERT(TIME(0), SUBSTRING(a.dataDate, 12, 8))				AS dataTime
	, CONVERT(DATE, LEFT(a.databaseInsertionDate, 10))			AS databaseInsertionDate
	, CONVERT(TIME(0), SUBSTRING(a.databaseInsertionDate, 12, 8))  AS databaseInsertionTime
	, a.latitude												AS thermoking_latitude
	, a.longitude												AS thermoking_longitude
	, a.locationDescription
	, a.speed												
	, a.powerOn
	, a.lastIgnitionStatus
	, a.voltage
	, a.fuelLevel
	, a.wirelessGen
	, a.avgFuelRateControllerOn
	, a.avgFuelRateTrip
	, a.dischargeAir1
	, a.dischargeAir2
	, a.dischargeAir3
	, a.returnAir1
	, a.returnAir2
	, a.returnAir3
	, a.setPoint1
	, a.setPoint2
	, a.setPoint3
	, a.doorStatus
	, a.doorlockfitted
	, a.doorlocked
	, CASE a.operatingMode1
		WHEN 'null' THEN NULL
		ELSE a.operatingMode1 END								AS operatingMode1
	, a.operatingMode2
	, a.operatingMode3
	, a.engineHours
	, a.engineRpm
	, a.electricalHours
	, a.totalHours
	, a.ambientTemperature
	, a.zone1Active
	, a.zone1Configured
	, a.zone1DoorOpen
	, a.zone2Active
	, a.zone2Configured
	, a.zone2DoorOpen
	, a.zone3Active
	, a.zone3Configured
	, a.zone3DoorOpen
	, a.unitMode
	, a.unitModeDetail
	, a.powerSource
	, a.ignitionStatus
	, a.bufferSize
	, a.devicePortA
	, a.devicePortB
	, a.devicePortC
	, a.commStatus
	, CONVERT(DATE, LEFT(a.alarmDataDate, 10))						AS alarmDataDate
	, CONVERT(TIME(0), SUBSTRING(a.alarmDataDate, 12, 8))				AS alarmDataTime
	, a.alarmCode
	, a.alarmDescription
	, a.alarmSeverity
	, a.alarmZone
	, a.alarmRecommendation
	, a.fuelTankSize
	, a.multiTemp
	, a.batteryHours
	, a.batteryHealth
	, a.batteryCharge
	, a.batteryEstimatedAutonomyHours
	, a.maintenanceHours
	, a.humidity
	, a.axle_load_sum
	, a.wheel_tyre_pressure
	, a.wheel_brake_lining
	, a.wheelBrakeLiningState
	, a.is_coupled
	, a.dtc_number
	, a.dtc_severity
	, a.odometer
	, a.tyrePressureDetection
	, a.geoFenceName
	, a.geoAccessTypeDescription
	, a.controllerStatus
FROM [data_central_lh].[dbo].[trkg_getData_v1_bronze] a