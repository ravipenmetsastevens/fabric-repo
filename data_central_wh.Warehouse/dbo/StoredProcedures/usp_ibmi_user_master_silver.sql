/***************************************************************************************************
Procedure:          dbo.usp_ibmi_user_master_silver
Create Date:        2026-02-20
Author:             Jeremy Shahan
Description:        Truncate and load of User Master to Silver
Called by:          Fabric
					Pipeline: ibmi_user_master
Affected table(s):  silver.ibmi_user_master
Usage:              EXEC dbo.usp_ibmi_user_master_silver

****************************************************************************************************
SUMMARY OF CHANGES
#             Date(yyyy-mm-dd)    Author              Comments
------------------- ------------------ ------------------------------------------------------------
1            
***************************************************************************************************/

CREATE     PROCEDURE [dbo].[usp_ibmi_user_master_silver]
AS

SET NOCOUNT ON

DELETE FROM silver.ibmi_user_master

INSERT INTO silver.ibmi_user_master

SELECT 
        TRIM(a.USRID)																					AS user_code
      --, a.USRC1
      --, a.USRC2
      --, a.USRC3
      --, a.USRC4
      --, a.USRC5
      --, a.USRC6
      --, a.USRC7
      --, a.USRC8
      --, a.USRC9
      --, a.USRC10
      --, a.USRC11
      --, a.USRC12
      --, a.USRC13
      --, a.USRC14
      --, a.USRC15
      --, a.USRC16
      --, a.USRC17
      --, a.USRC18
      --, a.USRC19
      --, a.USRC20
      , TRIM(a.USRINT)																					AS user_initials
      --, a.USRDB
      --, a.USRQUE
      --, a.USRPRT
      --, a.USRTRM
      --, a.USRTRA
      --, a.USMENU
      , TRIM(a.USRNME)																					AS user_full_name
      --, a.USRTXT
      --, a.USRDMG
      , USRUPD.date_key_pk																				AS user_last_update_date
	  , CASE 
			WHEN a.USRUP <= 2359 
				AND LEN(CONVERT(VARCHAR(4),CONVERT(INT,a.USRUP))) = 4 
			THEN TIMEFROMPARTS(LEFT(CONVERT(INT,a.USRUP),2),RIGHT(CONVERT(INT,a.USRUP),2),0,0,0)
			WHEN a.USRUP <= 2359 
				AND LEN(CONVERT(VARCHAR(4),CONVERT(INT,a.USRUP))) = 3 
			THEN TIMEFROMPARTS(LEFT(CONVERT(INT,a.USRUP),1),RIGHT(CONVERT(INT,a.USRUP),2),0,0,0)
			WHEN a.USRUP <= 2359 
				AND LEN(CONVERT(VARCHAR(4),CONVERT(INT,a.USRUP))) IN (1,2)
			THEN TIMEFROMPARTS(0,CONVERT(INT,a.USRUP),0,0,0)
			ELSE NULL END																				AS user_last_update_time     
      , TRIM(a.USRUPI)																					AS user_last_update_user_initials
  --INTO data_central_wh.silver.ibmi_user_master
  FROM data_central_lh.[dbo].[ibmi_user_master_bronze] a
  LEFT JOIN data_central_wh.gold.dim_date USRUPD ON a.USRUPD = USRUPD.date_ordinal