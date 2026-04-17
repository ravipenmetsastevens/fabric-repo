/***************************************************************************************************
Procedure:          dbo.usp_ibmi_driver_bio
Create Date:        2025-08-19
Author:             Tom Wolfenden
Description:        Truncate and load of Driver Bio Silver
Called by:            Azure Data Factory
					Pipeline: ibmi_driver_bio
Affected table(s):  silver.ibmi_driver_bio
Usage:              EXEC dbo.usp_ibmi_driver_bio_silver

****************************************************************************************************
SUMMARY OF CHANGES
#             Date(yyyy-mm-dd)    Author              Comments
------------------- ------------------ ------------------------------------------------------------
1            
***************************************************************************************************/

CREATE   PROCEDURE [dbo].[usp_ibmi_driver_bio_silver]
AS

SET NOCOUNT ON

DELETE FROM silver.ibmi_driver_bio

INSERT INTO silver.ibmi_driver_bio

SELECT
	    TRIM(a.DBDRVR)												AS drv_bio_driver_code
      , TRIM(a.DBJOIN)												AS drv_bio_why_join
      , TRIM(a.DBEXPR)												AS drv_bio_satisfaction_level
      , TRIM(a.DBEXPT)												AS drv_bio_expectations_met
      , TRIM(a.DBSHTG)												AS drv_bio_short_term_goals								
      , TRIM(a.DBLNTG)												AS drv_bio_long_term_goals	
      , TRIM(a.DBSUCC)												AS drv_bio_success
      , TRIM(a.DBFMLY)												AS drv_bio_family_life
      , TRIM(a.DBHTMC)												AS drv_bio_preferred_home_city
      , TRIM(a.DBHTMS)												AS drv_bio_preferred_home_state
      , TRIM(a.DBSAFE)												AS drv_bio_safe_haven
      , TRIM(a.DBHOBY)												AS drv_bio_hobbies
      , TRIM(a.DBSTVG)												AS drv_bio_stevens_goals
      , DBDATE.date_key_pk											AS drv_bio_last_update_date
      , TRIM(a.DBUSER)												AS drv_bio_last_update_user_code
  FROM data_central_lh.dbo.ibmi_driver_bio_bronze a
  LEFT JOIN gold.dim_date DBDATE ON a.DBDATE = DBDATE.date_key_pk