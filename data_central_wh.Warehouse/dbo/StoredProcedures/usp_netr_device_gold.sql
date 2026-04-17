/***************************************************************************************************
Procedure:          dbo.usp_netr_device_gold
Create Date:        2024-07-22
Author:             Tom Wolfenden
Description:        Move/transform Netradyne device data from silver to gold
Called by:          Fabric  
					Pipeline: Netradyne\Pipeline\pl_netr_alerts_v1
Affected table(s):  gold.fact_netr_coaching
Usage:              EXEC dbo.usp_netr_device_gold

****************************************************************************************************
SUMMARY OF CHANGES
#             Date(yyyy-mm-dd)    Author              Comments
------------------- ------------------ ------------------------------------------------------------
1            
***************************************************************************************************/

CREATE PROCEDURE [dbo].[usp_netr_device_gold]
AS

DELETE FROM gold.dim_netr_device

INSERT INTO gold.dim_netr_device
SELECT DISTINCT
	   [device_id]
	  ,[device_driver_id]
	  ,[device_vehicle_vin]
      ,[device_vehicle_number]
      ,[device_product_type]
      ,[device_updated_date]
      ,[device_updated_time]
      ,[device_groupname]
      ,[device_unique_groupname]
FROM [silver].[netr_device]