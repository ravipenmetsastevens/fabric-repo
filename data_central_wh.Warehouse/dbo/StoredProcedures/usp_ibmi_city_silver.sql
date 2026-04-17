/***************************************************************************************************
Procedure:          dbo.usp_ibmi_city_silver
Create Date:        2024-03-21
Author:             Tom Wolfenden
Description:        Truncate and load of City Silver
Called by:            Azure Data Factory
					Pipeline: ibmi_city_master
Affected table(s):  silver.ibmi_city_master
Usage:              EXEC dbo.usp_ibmi_city_silver

****************************************************************************************************
SUMMARY OF CHANGES
#             Date(yyyy-mm-dd)    Author              Comments
------------------- ------------------ ------------------------------------------------------------
1            
***************************************************************************************************/

CREATE PROCEDURE [dbo].[usp_ibmi_city_silver]
AS

SET NOCOUNT ON

DELETE FROM silver.ibmi_city_master

INSERT INTO [silver].[ibmi_city_master]
SELECT
	    TRIM([CIST])+TRIM([CICTY])
	  , TRIM([CIST])
      , TRIM([CICTY])
      , [CIRCD]
      , TRIM([CICOUN])
      , TRIM([CILATD])
      , TRIM([CILNGD])
      , TRIM([CICOMZ])
      , [CICNTY]
      , [CIBEA]
      , TRIM([CIRGU])
      , [CISMSA]
      , TRIM([CIZIP1])
      , TRIM([CIZIP2])
      , [CISPLC]
      , TRIM([CIAREA])
      , TRIM([CITERR])
      , TRIM([CITIME])
      , CASE [CISAME]
			WHEN 'Y' THEN 'True'
			WHEN 'N' THEN 'False'
			ELSE 'unknown' END
	  , CASE [CIHZON]
			WHEN 'Y' THEN 'True'
			WHEN 'N' THEN 'False'
			ELSE 'unknown' END
	  , CASE [CIDAY]
			WHEN 'Y' THEN 'True'
			WHEN 'N' THEN 'False'
			ELSE 'unknown' END
      , CASE [CIHHMG]
			WHEN 'Y' THEN 'True'
			WHEN 'N' THEN 'False'
			ELSE 'unknown' END
      , CASE [CIBIGC]
			WHEN 'Y' THEN 'True'
			WHEN 'N' THEN 'False'
			ELSE 'unknown' END
      , CASE [CIDUPL]
			WHEN 'Y' THEN 'True'
			WHEN 'N' THEN 'False'
			ELSE 'unknown' END
      , TRIM([CINEAR])
      , TRIM([CIDIRN])
      , [CIDISN]
      , TRIM([CISTIN])
      , [CICOIN]
      , TRIM([CISIZE])
      , TRIM([CILEVL])
	  , CASE [CIPOPE]
			WHEN 'Y' THEN 'True'
			WHEN 'N' THEN 'False'
			ELSE 'unknown' END
      , [CIPOPA]
      , TRIM([CINAME])
      , TRIM([CISHNM])
      , CASE 
			WHEN [CILATD] = 'S' THEN [CILAT] * -1
			ELSE [CILAT] END
      , CASE
		WHEN [CILNGD] = 'W' THEN [CILONG] * -1
		ELSE [CILONG] END
	  , CASE [CICQUL]
			WHEN 'Y' THEN 'True'
			WHEN 'N' THEN 'False'
			ELSE 'unknown' END
      , TRIM([CICABR])
  FROM data_central_lh.dbo.ibmi_city_master_bronze