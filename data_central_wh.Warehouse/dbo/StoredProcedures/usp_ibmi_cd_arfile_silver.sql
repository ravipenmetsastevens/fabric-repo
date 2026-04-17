/***************************************************************************************************
Procedure:          dbo.usp_ibmi_cd_arfile_silver
Create Date:        2024-08-19
Author:             Jeremy Shahan
Description:        Truncate and load of CD ARFILE to Silver
Called by:          Fabric
					Pipeline: ibmi_cd_arfile
Affected table(s):  silver.ibmi_cd_arfile
Usage:              EXEC dbo.usp_ibmi_cd_arfile_silver

****************************************************************************************************
SUMMARY OF CHANGES
#             Date(yyyy-mm-dd)    Author              Comments
------------------- ------------------ ------------------------------------------------------------
1            
***************************************************************************************************/

CREATE   PROCEDURE [dbo].[usp_ibmi_cd_arfile_silver]
AS

SET NOCOUNT ON

DELETE FROM silver.ibmi_cd_arfile

INSERT INTO silver.ibmi_cd_arfile
SELECT
	   a.[ARRECC]																			AS cd_arfile_record_code
      ,TRIM(a.[ARCUST])																		AS cd_arfile_customer_code
      ,TRIM(a.[ARINVN])																		AS cd_arfile_invoice_number
      ,TRIM(a.[ARCUS#])																		AS cd_arfile_adj_batch_code
      ,TRIM(a.[ARTYPE])																		AS cd_arfile_record_type
      ,a.[ARREC#]																			AS cd_arfile_record_number
      , CASE 
			WHEN TRIM(a.[ARINVD]) = ''
			THEN NULL
			WHEN TRIM(a.[ARINVD]) = '000000'
			THEN NULL
			ELSE
	  CONVERT(DATE,RIGHT(a.[ARINVD],2)+LEFT(a.[ARINVD],2)+SUBSTRING(a.[ARINVD],3,2))
			END																				AS cd_arfile_invoice_date
      ,TRIM(a.[ARORD])																		AS cd_arfile_load_number
      , CASE 
			WHEN TRIM(a.[ARDPDT]) = ''
			THEN NULL
			WHEN TRIM(a.[ARDPDT]) = '000000'
			THEN NULL
			ELSE
	  CONVERT(DATE,RIGHT(a.[ARDPDT],2)+LEFT(a.[ARDPDT],2)+SUBSTRING(a.[ARDPDT],3,2))
			END																				AS cd_arfile_deposit_date
	  ,TRIM(a.[ARCORD])																		AS cd_arfile_cust_order_number
      ,TRIM(a.[ARBOMO])																		AS cd_arfile_book_month
      ,TRIM(a.[ARBOYR])																		AS cd_arfile_book_year
      ,a.[ARAMT]																			AS cd_arfile_amount
      ,a.[ARBFWD]																			AS cd_arfile_balance_forward
      --,TRIM(a.[ARFC])																		Unused
	  , CASE WHEN TRIM(a.[ARDPRO]) = 'Y'
			THEN 'TRUE'
			ELSE 'FALSE' END																AS is_daily_pro_register
	  , CASE WHEN TRIM(a.[ARWPRO]) = 'Y'
			THEN 'TRUE'
			ELSE 'FALSE' END																AS is_weekly_pro_register
	  , CASE WHEN TRIM(a.[ARMPRO]) = 'Y'
			THEN 'TRUE'
			ELSE 'FALSE' END																AS is_monthly_pro_register
	  , CASE WHEN TRIM(a.[ARNCUR]) = 'Y'
			THEN 'TRUE'
			ELSE 'FALSE' END																AS is_non_current
      ,TRIM(a.[ARNAME])																		AS cd_arfile_customer_name
      ,TRIM(a.[ARSEQ])																		AS cd_arfile_sequence_code
      ,TRIM(a.[ARSTM#])																		AS cd_arfile_statement_number
      , CASE 
			WHEN TRIM(a.[ARDSPD]) = ''
			THEN NULL
			WHEN TRIM(a.[ARDSPD]) = '000000'
			THEN NULL
			ELSE
	  CONVERT(DATE,RIGHT(a.[ARDSPD],2)+LEFT(a.[ARDSPD],2)+SUBSTRING(a.[ARDSPD],3,2))
			END																				AS cd_arfile_dispatch_date
      --,TRIM(a.[ARSTMF])																	Unused
      --,a.[ARGSTA]																			Unused
      --,a.[ARGLNO]																			Unused
FROM data_central_lh.dbo.ibmi_cd_arfile_bronze a