/***************************************************************************************************
Procedure:          dbo.usp_netr_user_silver
Create Date:        2024-07-22
Author:             Tom Wolfenden
Description:        Move/transform Netradyne user data from bronze to silver
Called by:          Fabric  
					Pipeline: Netradyne\Pipeline\pl_netr_user_v1
Affected table(s):  silver.netr_user
Usage:              EXEC dbo.usp_netr_user_silver

****************************************************************************************************
SUMMARY OF CHANGES
#             Date(yyyy-mm-dd)    Author              Comments
------------------- ------------------ ------------------------------------------------------------
1            
***************************************************************************************************/

CREATE PROCEDURE [dbo].[usp_netr_user_silver]
AS

DELETE FROM silver.netr_user

INSERT INTO silver.netr_user
SELECT DISTINCT
	  a.[data.userName]												AS user_username
	, a.[data.firstName]											AS user_firstname
    , a.[data.lastName]												AS user_lastname
    , a.[data.email]												AS user_email
	, stat.configDescription										AS user_status
	, a.[data.roleId]
	, roles.configDescription										AS user_role
	, CASE  a.[data.twofaStatus]
		WHEN 0 THEN 'Disabled'
		WHEN 1 THEN 'Enabled' END									AS user_twofastatus
	--, a.[data.groups.groupName]										AS user_group
	--, a.[data.hierarchies.nodeName]									AS user_node
	, CONVERT(DATE,
		DATEADD(S, 
			CONVERT(INT, LEFT(a.[data.createdOn], 10)
				), '1970-01-01'))									AS user_create_date
	, CONVERT(TIME(0),
		DATEADD(S, 
			CONVERT(INT, LEFT(a.[data.createdOn], 10)
				), '1970-01-01'))									AS user_create_time
	, CONVERT(DATE,
		DATEADD(S, 
			CONVERT(INT, LEFT(a.[data.updatedOn], 10)
				), '1970-01-01'))									AS user_update_date
	, CONVERT(TIME(0),
		DATEADD(S, 
			CONVERT(INT, LEFT(a.[data.updatedOn], 10)
				), '1970-01-01'))									AS user_update_time
FROM data_central_lh.[dbo].[netr_users_v1_bronze] a
LEFT JOIN (SELECT CONVERT(BIGINT, configId) AS userStatusId
				, configDescription
			FROM data_central_lh.[dbo].[netr_config_v2_bronze]
			WHERE configType = 'userStatus') stat on a.[data.status] = stat.userStatusId
LEFT JOIN (SELECT configId AS roleId
				, configDescription
			FROM data_central_lh.[dbo].[netr_config_v2_bronze]
			WHERE configType = 'rolesDetail') roles on a.[data.roleId] = roles.roleId

DELETE FROM silver.user_group_bridge

INSERT INTO silver.user_group_bridge
SELECT DISTINCT
	  a.[data.userName]												AS user_username
	, a.[data.groups.groupUniqueName]								AS user_group_uniquename
	, a.[data.groups.groupName]										AS user_groupname
FROM data_central_lh.[dbo].[netr_users_v1_bronze] a