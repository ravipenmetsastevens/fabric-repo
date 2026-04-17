/***************************************************************************************************
Procedure:          dbo.usp_flrk_driver_silver
Create Date:        2024-04-28
Author:             Tom Wolfenden
Description:        Add data for Fleetrock driver from bronze to silver
Called by:          Fabric  
					Pipeline: Fleetrock\Pipeline\pl_flrk_driver
Affected table(s):  silver.flrk_driver
Usage:              EXEC dbo.usp_flrk_driver_silver

****************************************************************************************************
SUMMARY OF CHANGES
#             Date(yyyy-mm-dd)    Author              Comments
------------------- ------------------ ------------------------------------------------------------
1            
***************************************************************************************************/

CREATE PROCEDURE dbo.usp_flrk_driver_silver
AS

DELETE FROM silver.flrk_driver

INSERT INTO silver.flrk_driver
SELECT 
		a.username
      , a.last_name
      , a.first_name
      , a.street_address
      , a.zip_code
      , a.city
      , a.[state]
      , a.vin
      , a.odometer_miles
      , a.escrow_balance
      , a.[start_date]
      , a.end_date
      , a.[status]
FROM data_central_lh.dbo.flrk_driver_bronze a