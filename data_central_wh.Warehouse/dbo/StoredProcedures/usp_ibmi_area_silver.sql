/***************************************************************************************************
Procedure:          dbo.usp_ibmi_area_silver
Create Date:        2024-03-21
Author:             Tom Wolfenden
Description:        Truncate and load of area Silver
Called by:            Azure Data Factory
					Pipeline: ibmi_area_master
Affected table(s):  silver.ibmi_area_master
Usage:              EXEC dbo.usp_ibmi_area_silver

****************************************************************************************************
SUMMARY OF CHANGES
#             Date(yyyy-mm-dd)    Author              Comments
------------------- ------------------ ------------------------------------------------------------
1            
***************************************************************************************************/

CREATE PROCEDURE [dbo].[usp_ibmi_area_silver]
AS

DELETE FROM silver.ibmi_area_master

INSERT INTO silver.ibmi_area_master
SELECT 
	  TRIM([NMACOD])								AS area_code
	, TRIM([NMANAM])								AS area_name
    , TRIM([NMASHN])								AS area_short_name
    , TRIM([NMAZON])								AS area_zone_code
    , TRIM([NMAREG])								AS area_region_code
FROM data_central_lh.dbo.ibmi_area_master_bronze