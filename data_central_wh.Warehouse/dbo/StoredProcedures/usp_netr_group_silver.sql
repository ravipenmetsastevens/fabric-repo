/***************************************************************************************************
Procedure:          dbo.usp_netr_group_silver
Create Date:        2024-07-22
Author:             Tom Wolfenden
Description:        Move/transform Netradyne group data from bronze to silver
Called by:          Fabric  
					Pipeline: Netradyne\Pipeline\pl_netr_group_v1
Affected table(s):  silver.netr_group
Usage:              EXEC dbo.usp_netr_group_silver

****************************************************************************************************
SUMMARY OF CHANGES
#             Date(yyyy-mm-dd)    Author              Comments
------------------- ------------------ ------------------------------------------------------------
1            
***************************************************************************************************/

CREATE PROCEDURE [dbo].[usp_netr_group_silver]
AS

DELETE FROM silver.netr_group

INSERT INTO silver.netr_group

SELECT
	  a.[data.groups.groupUniqueName]							AS group_id
	, a.[data.groups.groupName]									AS group_name
	, a.[data.groups.status]									AS group_status
FROM data_central_lh.[dbo].[netr_groups_v1_bronze] a