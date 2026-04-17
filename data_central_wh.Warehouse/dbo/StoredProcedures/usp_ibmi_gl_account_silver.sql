/***************************************************************************************************
Procedure:          dbo.usp_ibmi_gl_account_silver
Create Date:        2024-03-21
Author:             Tom Wolfenden
Description:        Truncate and load of gl_account Silver
Called by:            Azure Data Factory
					Pipeline: ibmi_gl_account_master
Affected table(s):  silver.ibmi_gl_account_master
Usage:              EXEC dbo.usp_ibmi_gl_account_silver

****************************************************************************************************
SUMMARY OF CHANGES
#             Date(yyyy-mm-dd)    Author              Comments
------------------- ------------------ ------------------------------------------------------------
1            
***************************************************************************************************/

CREATE PROCEDURE [dbo].[usp_ibmi_gl_account_silver]
AS

SET NOCOUNT ON

DELETE FROM silver.ibmi_gl_account

INSERT INTO silver.ibmi_gl_account
SELECT  
	    CONCAT(TRIM(GCACCT),'-',TRIM(GCLEV))							AS	gl_acct_key
      , TRIM(GCACCT)													AS	gl_account_number
      , TRIM(GCLEV)														AS	gl_account_level
      , TRIM(GCDESC)													AS  gl_account_description
      , TRIM(GCCONS)													AS  gl_consolidation_account
	  , CASE WHEN LEN(TRIM(GCPRT)) = 0 OR GCPRT IS NULL 	
			THEN 'unknown'
			ELSE GCPRT END												AS gl_account_answer	
	  --,GCDELC   Record Status 
      --,GCTYPE   Code
      --,GCAVCD    Avas Component Code
      --,GCAVAL    Avas Allocation Component
      --,GCAVPE	   Avas Allocation Percentage
  FROM data_central_lh.dbo.ibmi_gl_account_bronze