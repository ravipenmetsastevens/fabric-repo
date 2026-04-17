/***************************************************************************************************
Procedure:          dbo.usp_ibmi_driver_master
Create Date:        2025-09-09
Author:             Jeremy Shahan
Description:        Truncate and load of Business Unit Master Silver
Called by:            Azure Data Factory
					Pipeline: ibmi_business_unit_master
Affected table(s):  silver.ibmi_business_unit_master
Usage:              EXEC dbo.usp_ibmi_business_unit_silver

****************************************************************************************************
SUMMARY OF CHANGES
#             Date(yyyy-mm-dd)    Author              Comments
------------------- ------------------ ------------------------------------------------------------
1            
***************************************************************************************************/

CREATE PROCEDURE [dbo].[usp_ibmi_business_unit_master_silver]
AS

SET NOCOUNT ON

DELETE FROM silver.ibmi_business_unit_master

INSERT INTO silver.ibmi_business_unit_master

SELECT
		TRIM(a.BUCLS)					AS business_unit_class
      , TRIM(a.BUDESC)					AS business_unit_description
      , TRIM(a.BUCODE)					AS business_unit_code  
--INTO data_central_wh.silver.ibmi_business_unit_master
FROM data_central_lh.dbo.ibmi_business_unit_master_bronze a