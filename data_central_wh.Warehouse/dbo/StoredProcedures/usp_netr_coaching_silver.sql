/***************************************************************************************************
Procedure:          dbo.usp_netr_coaching_silver
Create Date:        2024-07-22
Author:             Tom Wolfenden
Description:        Move/transform Netradyne coaching data from bronze to silver
Called by:          Fabric  
					Pipeline: Netradyne\Pipeline\pl_netr_coaching_sessions_v1
Affected table(s):  silver.netr_coaching
Usage:              EXEC dbo.usp_netr_coaching_silver

****************************************************************************************************
SUMMARY OF CHANGES
#             Date(yyyy-mm-dd)    Author              Comments
------------------- ------------------ ------------------------------------------------------------
1            
***************************************************************************************************/

CREATE PROCEDURE [dbo].[usp_netr_coaching_silver]
AS

DELETE FROM silver.netr_coaching

INSERT INTO silver.netr_coaching
SELECT DISTINCT
	  a.[data.coachingSession.sessionId]							AS coaching_id
	, CONVERT(DATE,
		DATEADD(S, 
			CONVERT(INT, LEFT(a.[data.coachingSession.creationDate], 10)
				), '1970-01-01'))									AS coaching_create_date
	, CONVERT(TIME(0),
		DATEADD(S, 
			CONVERT(INT, LEFT(a.[data.coachingSession.creationDate], 10)
				), '1970-01-01'))									AS coaching_create_time
	, CONVERT(DATE,
		DATEADD(S, 
			CONVERT(INT, LEFT(a.[data.coachingSession.coachedDate], 10)
				), '1970-01-01'))									AS coaching_complete_date
	, CONVERT(TIME(0),
		DATEADD(S, 
			CONVERT(INT, LEFT(a.[data.coachingSession.coachedDate], 10)
				), '1970-01-01'))									AS coaching_complete_time
	, a.[data.coachingSession.status]								AS coaching_status_id
	, stat.configDescription
	, a.[data.coachingSession.driver.firstName]						AS coaching_driver_firstname
    , a.[data.coachingSession.driver.lastName]						AS coaching_driver_lastname
    , a.[data.coachingSession.driver.driverId]						AS coaching_driver_id
	, CONVERT(DATE,
		DATEADD(S, 
			CONVERT(INT, LEFT(a.[data.coachingSession.updatedOn], 10)
				), '1970-01-01'))									AS coaching_update_date
	, CONVERT(TIME(0),
		DATEADD(S, 
			CONVERT(INT, LEFT(a.[data.coachingSession.updatedOn], 10)
				), '1970-01-01'))									AS coaching_update_time
	, a.[data.coachingSession.coachingType]							AS coaching_type
FROM data_central_lh.[dbo].[netr_coaching_sessions_v1_bronze] a
LEFT JOIN (SELECT CONVERT(BIGINT, configId) AS coachingStatusId
				, configDescription
			FROM data_central_lh.[dbo].[netr_config_v2_bronze]
			WHERE configType = 'coachingSessionStatus') stat on a.[data.coachingSession.status] = stat.coachingStatusId