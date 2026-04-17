/***************************************************************************************************
Procedure:          dbo.usp_ibmi_division_silver
Create Date:        2024-03-21
Author:             Tom Wolfenden
Description:        Truncate and load of division Silver
Called by:            Azure Data Factory
					Pipeline: ibmi_division_master
Affected table(s):  silver.ibmi_division_master
Usage:              EXEC dbo.usp_ibmi_division_silver

****************************************************************************************************
SUMMARY OF CHANGES
#             Date(yyyy-mm-dd)    Author              Comments
------------------- ------------------ ------------------------------------------------------------
1            
***************************************************************************************************/

CREATE   PROCEDURE [dbo].[usp_ibmi_division_silver]
AS

SET NOCOUNT ON

DELETE FROM silver.ibmi_division

INSERT INTO silver.ibmi_division

	SELECT 
		TRIM([DIVCDE])									AS division_code
      , CASE WHEN [DIVSTT] = 'D'
		THEN 'DELETED'
		ELSE 'ACTIVE' END								AS division_status
      ,TRIM([DIVNME])									AS division_name
      , CASE TRIM([DIVFC])
			WHEN 'A' THEN 'Rail'
			WHEN 'B' THEN 'Brokerage'
			WHEN 'C' THEN 'Company'
			WHEN 'D' THEN 'Dedicated'
			WHEN 'E' THEN 'Regional'
			WHEN 'L' THEN 'Local'
			ELSE 'unknown'	END							AS division_fleet_name
      --,[DIVFLE]
      --,[DIVWRK]
      --,[DIVSAV]
      --,[DIVCO]
      --,[DIVCOU]
      --,[DIVMET]
      --,[DIVAMT]
--  INTO data_central_wh.silver.ibmi_division
  FROM data_central_lh.dbo.ibmi_division_bronze