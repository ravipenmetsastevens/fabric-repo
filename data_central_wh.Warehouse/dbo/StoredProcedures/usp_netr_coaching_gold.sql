/***************************************************************************************************
Procedure:          dbo.usp_netr_coaching_gold
Create Date:        2024-07-22
Author:             Tom Wolfenden
Description:        Move/transform Netradyne coaching data from silver to gold
Called by:          Fabric  
					Pipeline: Netradyne\Pipeline\pl_netr_alerts_v1
Affected table(s):  gold.fact_netr_coaching
Usage:              EXEC dbo.usp_netr_coaching_gold

****************************************************************************************************
SUMMARY OF CHANGES
#             Date(yyyy-mm-dd)    Author              Comments
------------------- ------------------ ------------------------------------------------------------
1            
***************************************************************************************************/

CREATE PROCEDURE [dbo].[usp_netr_coaching_gold]
AS

DELETE FROM gold.fact_netr_coaching

INSERT INTO gold.fact_netr_coaching
SELECT DISTINCT
	   [coaching_id]
	  ,[coaching_driver_id]
      ,[coaching_create_date]
      ,[coaching_create_time]
      ,[coaching_complete_date]
      ,[coaching_complete_time]
      ,[configDescription]							AS coaching_status
      ,[coaching_update_date]
      ,[coaching_update_time]
      ,[coaching_type]
FROM [silver].[netr_coaching]