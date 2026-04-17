/***************************************************************************************************
Procedure:          dbo.usp_netr_driver_gold
Create Date:        2024-07-22
Author:             Tom Wolfenden
Description:        Move/transform Netradyne driver data from silver to gold
Called by:          Fabric  
					Pipeline: Netradyne\Pipeline\pl_netr_driver_v1
Affected table(s):  gold.dim_netr_driver
Usage:              EXEC dbo.usp_netr_driver_gold

****************************************************************************************************
SUMMARY OF CHANGES
#             Date(yyyy-mm-dd)    Author              Comments
------------------- ------------------ ------------------------------------------------------------
1            
***************************************************************************************************/

CREATE PROCEDURE [dbo].[usp_netr_driver_gold]
AS

DELETE FROM gold.dim_netr_driver

INSERT INTO gold.dim_netr_driver
SELECT [driver_id]
      ,[driver_firstname]
      ,[driver_lastname]
      ,[driver_status_descr]
      ,[driver_username]
      ,[driver_email]
      ,[driver_licence_number]
      ,[driver_licence_state]
      ,[driver_licence_country]
      ,[driver_group_name]
      ,[driver_group_unique_name]
      ,[driver_create_date]
      ,[driver_create_time]
      ,[driver_update_date]
      ,[driver_update_time]
FROM [silver].[netr_driver]