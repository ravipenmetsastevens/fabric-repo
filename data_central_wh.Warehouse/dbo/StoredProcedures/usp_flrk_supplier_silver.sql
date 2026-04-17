/***************************************************************************************************
Procedure:          dbo.usp_flrk_supplier_silver
Create Date:        2024-05-06
Author:             Tom Wolfenden
Description:        Add data for Fleetrock suppliers from bronze to silver
Called by:          Fabric  
					Pipeline: Fleetrock\Pipeline\pl_flrk_supplier
Affected table(s):  silver.flrk_supplier
Usage:              EXEC dbo.usp_flrk_supplier_silver

****************************************************************************************************
SUMMARY OF CHANGES
#             Date(yyyy-mm-dd)    Author              Comments
------------------- ------------------ ------------------------------------------------------------
1            
***************************************************************************************************/

CREATE PROCEDURE [dbo].[usp_flrk_supplier_silver]
AS

DELETE FROM silver.flrk_supplier

INSERT INTO silver.flrk_supplier
SELECT [name]
      ,[custom_id]
      ,[street_address_1]
      ,[street_address_2]
      ,[city]
      ,[state]
      ,[zip_code]
      ,[country]
      ,[phone]
      ,[email]
      ,[payment_term_days]
      ,[notes]
      ,[date_added]
      ,[supplier_type]
  FROM data_central_lh.dbo.flrk_supplier_bronze