/***************************************************************************************************
Procedure:          dbo.usp_netr_driver_silver
Create Date:        2024-07-22
Author:             Tom Wolfenden
Description:        Move/transform Netradyne driver data from bronze to silver
Called by:          Fabric  
					Pipeline: Netradyne\Pipeline\pl_netr_driver_v1
Affected table(s):  silver.netr_driver
Usage:              EXEC dbo.usp_netr_driver_silver

****************************************************************************************************
SUMMARY OF CHANGES
#             Date(yyyy-mm-dd)    Author              Comments
------------------- ------------------ ------------------------------------------------------------
1            
***************************************************************************************************/

CREATE PROCEDURE [dbo].[usp_netr_driver_silver]
AS

DELETE FROM silver.netr_driver

INSERT INTO silver.netr_driver
SELECT DISTINCT
	  a.[data.drivers.driverId]										AS driver_id
	, a.[data.drivers.firstName]									AS driver_firstname
	, a.[data.drivers.lastName]										AS driver_lastname
	, a.[data.drivers.status]										AS driver_status_id
	, stat.configDescription										AS driver_status_descr
	, a.[data.drivers.userName]										AS driver_username
	, a.[data.drivers.email]										AS driver_email
	, a.[data.drivers.licenceNumber]								AS driver_licence_number
	, a.[data.drivers.licenseState]									AS driver_licence_state
	, a.[data.drivers.licenseCountry]								AS driver_licence_country
	, a.[data.drivers.group.groupName]								AS driver_group_name
	, a.[data.drivers.group.groupUniqueName]						AS driver_group_unique_name
	, CONVERT(DATE,
		DATEADD(S, 
			CONVERT(INT, LEFT(a.[data.drivers.createdDate], 10)
				), '1970-01-01'))									AS driver_create_date
	, CONVERT(TIME(0),
		DATEADD(S, 
			CONVERT(INT, LEFT(a.[data.drivers.createdDate], 10)
				), '1970-01-01'))									AS driver_create_time
	, CONVERT(DATE,
		DATEADD(S, 
			CONVERT(INT, LEFT(a.[data.drivers.updatedDate], 10)
				), '1970-01-01'))									AS driver_update_date
	, CONVERT(TIME(0),
		DATEADD(S, 
			CONVERT(INT, LEFT(a.[data.drivers.updatedDate], 10)
				), '1970-01-01'))									AS driver_update_time
FROM data_central_lh.dbo.[netr_drivers_v1_bronze] a
LEFT JOIN (SELECT CONVERT(BIGINT, configId) AS driverStatusId
				, configDescription
			FROM data_central_lh.[dbo].[netr_config_v2_bronze]
			WHERE configType = 'driverStatus') stat on a.[data.drivers.status] = stat.driverStatusId