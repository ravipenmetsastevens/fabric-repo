/***************************************************************************************************
Procedure:          dbo.usp_ibmi_area_silver
ALTER Date:        2024-07-01
Author:             Jeremy Shahan
Description:        Truncate and load of Region Silver
Called by:            Azure Data Factory
					Pipeline: ibmi_region_master
Affected table(s):  silver.ibmi_region_master
Usage:              EXEC dbo.usp_ibmi_region_silver

****************************************************************************************************
SUMMARY OF CHANGES
#             Date(yyyy-mm-dd)    Author              Comments
------------------- ------------------ ------------------------------------------------------------
1            
***************************************************************************************************/

CREATE PROCEDURE [dbo].[usp_ibmi_region_silver]
AS

DELETE FROM silver.ibmi_region_master

INSERT INTO silver.ibmi_region_master
SELECT 
	  TRIM([NMRCOD])								AS region_code
	, TRIM([NMRNAM])								AS region_name


FROM data_central_lh.dbo.ibmi_region_master_bronze