/***************************************************************************************************
Procedure:          dbo.usp_ibmi_cd_ar_extension_silver
Create Date:        2026-02-20
Author:             Jeremy Shahan
Description:        Truncate and load of CD AR Extension File to Silver
Called by:          Fabric
					Pipeline: ibmi_cd_ar_extension
Affected table(s):  silver.ibmi_cd_ar_extension
Usage:              EXEC dbo.usp_ibmi_cd_ar_extension_silver

****************************************************************************************************
SUMMARY OF CHANGES
#             Date(yyyy-mm-dd)    Author              Comments
------------------- ------------------ ------------------------------------------------------------
1            
***************************************************************************************************/

CREATE       PROCEDURE [dbo].[usp_ibmi_cd_ar_extension_silver]
AS

SET NOCOUNT ON

DELETE FROM silver.ibmi_cd_ar_extension

INSERT INTO silver.ibmi_cd_ar_extension

SELECT 
        CASE
            WHEN LEN(CONVERT(VARCHAR(8),a.ARENDT)) = 8
                THEN DATEFROMPARTS(LEFT(a.ARENDT,4),SUBSTRING(CONVERT(VARCHAR(8),a.ARENDT),5,2),RIGHT(a.ARENDT,2))
                ELSE NULL END                                                                                   AS cd_ar_ext_create_date
	  , CASE 
			WHEN LEN(CONVERT(VARCHAR(6),a.ARENTI)) = 6 
			    THEN TIMEFROMPARTS(LEFT(a.ARENTI,2),SUBSTRING(CONVERT(VARCHAR(6),a.ARENTI),3,2),RIGHT(a.ARENTI,2),0,0)
            WHEN LEN(CONVERT(VARCHAR(6),a.ARENTI)) = 5 
			    THEN TIMEFROMPARTS(LEFT(a.ARENTI,1),SUBSTRING(CONVERT(VARCHAR(6),a.ARENTI),2,2),RIGHT(a.ARENTI,2),0,0)
            ELSE NULL END												                                        AS cd_ar_ext_create_time     
      , TRIM(a.ARCUST)                                                                                          AS cd_ar_ext_customer_code
      , TRIM(a.ARINVN)                                                                                          AS cd_ar_ext_invoice_number
      , TRIM(a.ARORD)                                                                                           AS cd_ar_ext_load_number
      , TRIM(a.ARSEQ)                                                                                           AS cd_ar_ext_sequence_code
      , TRIM(a.ARCUS)                                                                                           AS cd_ar_ext_ar_code
      , TRIM(a.ARTYPE)                                                                                          AS cd_ar_ext_record_type_code
      , a.ARREC                                                                                                 AS cd_ar_ext_record_number
      , a.ARAMT                                                                                                 AS cd_ar_ext_invoice_amount
      , TRIM(a.ARRECC)                                                                                          AS cd_ar_ext_record_code
      , CASE
            WHEN LEN(a.ARINVD) = 6
                THEN DATEFROMPARTS('20' + RIGHT(a.ARINVD,2),LEFT(a.ARINVD,2),SUBSTRING(a.ARINVD,3,2))
            ELSE NULL END                                                                                       AS cd_ar_ext_invoice_date
      , CASE
            WHEN LEN(a.ARDPDT) = 6 AND a.ARDPDT <> '000000'
                THEN DATEFROMPARTS('20' + RIGHT(a.ARDPDT,2),LEFT(a.ARDPDT,2),SUBSTRING(a.ARDPDT,3,2))
            ELSE NULL END                                                                                       AS cd_ar_ext_deposit_or_adjustment_date
      , TRIM(a.ARCORD)                                                                                          AS cd_ar_ext_bol
      , TRIM(a.ARBOMO)                                                                                          AS cd_ar_ext_book_month
      , TRIM(a.ARBOYR)                                                                                          AS cd_ar_ext_book_year
      , a.ARBFWD                                                                                                AS cd_ar_ext_balance_forward_amount
      --, a.ARFC
      , TRIM(a.ARNAME)                                                                                          AS cd_ar_ext_customer_name
      , TRIM(a.ARSTM)                                                                                          AS cd_ar_ext_statement_number
      , CASE
            WHEN LEN(a.ARDSPD) = 6 AND a.ARDSPD <> '000000'
                THEN DATEFROMPARTS('20' + RIGHT(a.ARDSPD,2),LEFT(a.ARDSPD,2),SUBSTRING(a.ARDSPD,3,2))
            ELSE NULL END                                                                                       AS cd_ar_ext_dispatch_date
      --, a.ARSTMF
      --, a.ARGSTA
      --, a.ARGLNO
      , TRIM(a.ARENUS)                                                                                          AS cd_ar_ext_create_user_code
      , TRIM(a.ARENPG)                                                                                          AS cd_ar_ext_create_program_code
      , CASE
            WHEN LEN(CONVERT(VARCHAR(8),a.ARCHDT)) = 8
                THEN DATEFROMPARTS(LEFT(a.ARCHDT,4),SUBSTRING(CONVERT(VARCHAR(8),a.ARCHDT),5,2),RIGHT(a.ARCHDT,2))
                ELSE NULL END                                                                                   AS cd_ar_ext_last_change_date
	  , CASE 
			WHEN LEN(CONVERT(VARCHAR(6),a.ARCHTI)) = 6 
			    THEN TIMEFROMPARTS(LEFT(a.ARCHTI,2),SUBSTRING(CONVERT(VARCHAR(6),a.ARCHTI),3,2),RIGHT(a.ARCHTI,2),0,0)
            WHEN LEN(CONVERT(VARCHAR(6),a.ARCHTI)) = 5 
			    THEN TIMEFROMPARTS(LEFT(a.ARCHTI,1),SUBSTRING(CONVERT(VARCHAR(6),a.ARCHTI),2,2),RIGHT(a.ARCHTI,2),0,0)
            ELSE NULL END												                                        AS cd_ar_ext_last_change_time     
      , TRIM(a.ARCHUS)                                                                                          AS cd_ar_ext_last_change_user_code
      , TRIM(a.ARCHPG)                                                                                          AS cd_ar_ext_last_change_program_code
      , CASE
            WHEN LEN(CONVERT(VARCHAR(8),a.ARDEDT)) = 8
                THEN DATEFROMPARTS(LEFT(a.ARDEDT,4),SUBSTRING(CONVERT(VARCHAR(8),a.ARDEDT),5,2),RIGHT(a.ARDEDT,2))
                ELSE NULL END                                                                                   AS cd_ar_ext_delete_date
	  , CASE 
			WHEN LEN(CONVERT(VARCHAR(6),a.ARDETI)) = 6 
			    THEN TIMEFROMPARTS(LEFT(a.ARDETI,2),SUBSTRING(CONVERT(VARCHAR(6),a.ARDETI),3,2),RIGHT(a.ARDETI,2),0,0)
            WHEN LEN(CONVERT(VARCHAR(6),a.ARDETI)) = 5 
			    THEN TIMEFROMPARTS(LEFT(a.ARDETI,1),SUBSTRING(CONVERT(VARCHAR(6),a.ARDETI),2,2),RIGHT(a.ARDETI,2),0,0)
            ELSE NULL END												                                        AS cd_ar_ext_delete_time     
      , TRIM(a.ARDEUS)                                                                                          AS cd_ar_ext_delete_user_code
      , TRIM(a.ARDEPG)                                                                                          AS cd_ar_ext_delete_program_code
--INTO data_central_wh.silver.ibmi_cd_ar_extension
FROM data_central_lh.dbo.ibmi_cd_ar_extension_bronze a