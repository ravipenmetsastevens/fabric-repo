/***************************************************************************************************
Procedure:          dbo.usp_ibmi_owner_silver
Create Date:        2024-03-21
Author:             Tom Wolfenden
Description:        Truncate and load of order Silver
Called by:            Azure Data Factory
					Pipeline: ibmi_owner_master
Affected table(s):  silver.ibmi_owner_master
Usage:              EXEC dbo.usp_ibmi_owner_silver

****************************************************************************************************
SUMMARY OF CHANGES
#             Date(yyyy-mm-dd)    Author              Comments
------------------- ------------------ ------------------------------------------------------------
1            
***************************************************************************************************/

CREATE PROCEDURE [dbo].[usp_ibmi_owner_silver]
AS

SET NOCOUNT ON

DELETE FROM  silver.ibmi_owner

INSERT INTO silver.ibmi_owner
SELECT 
	TRIM(a.OWUNIT)
  , TRIM(a.OWNAME)
  , TRIM(a.OWADD1)
  , TRIM(a.OWCITY)
  , TRIM(a.OWST)
  , TRIM(a.OWZIP)
  , TRIM(a.OWEXT)
  , TRIM(a.OWADD2)
  , TRIM(a.OWCIT2)	
  , TRIM(a.OWST2)
  , TRIM(a.OWZIP2)
  , TRIM(a.OWEXT2)
  , CONVERT(NVARCHAR, a.OWAC)
  , CONVERT(NVARCHAR, a.OWTEL)
  , CONVERT(NVARCHAR, a.OWSS)
  , a.OWWCMP
  , a.OWPCRV
  , a.OWYTDG
  , a.OWVACB
  , a.OWUNSB
  , TRIM(a.OWCMPR)
  , TRIM(a.OWDEL)
  , TRIM(a.OWCHK)
  , TRIM(a.OWFC)
  , TRIM(a.OWSF)
  , TRIM(a.OWCNTY)
  , TRIM(a.OWGST)
  , a.OWGSTP
  , a.OWGSTR
  , TRIM(a.OWGSTC)
  , TRIM(a.OWCKTN)
  , TRIM(a.OWCARD)
  , TRIM(a.OW1099)
  , TRIM(a.OWFLET)
FROM data_central_lh.dbo.ibmi_owner_bronze a