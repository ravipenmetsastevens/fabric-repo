/***************************************************************************************************
Procedure:          dbo.usp_ibmi_stcodes_silver
Create Date:        2025-10-08
Author:             Jeremy Shahan
Description:        Truncate and load of Settlement Codes to Silver
Called by:          Fabric
					Pipeline: ibmi_stcodes
Affected table(s):  silver.ibmi_stcodes
Usage:              EXEC dbo.usp_ibmi_stcodes_silver

****************************************************************************************************
SUMMARY OF CHANGES
#             Date(yyyy-mm-dd)    Author              Comments
------------------- ------------------ ------------------------------------------------------------
1            
***************************************************************************************************/

CREATE    PROCEDURE [dbo].[usp_ibmi_stcodes_silver]
AS

SET NOCOUNT ON

DELETE FROM silver.ibmi_stcodes

INSERT INTO silver.ibmi_stcodes
SELECT 
		TRIM(a.STCODE)													AS stcodes_settlement_code
      , TRIM(a.STDESC)													AS stcodes_description
      , TRIM(a.STCRED)													AS stcodes_credit_account_number
      , TRIM(a.STDEBT)													AS stcodes_debit_account_number
      , CASE TRIM(a.STTYPE)
			WHEN 'R' THEN 'Revenue'
			ELSE 'unknown'	END											AS stcodes_settlement_type
      , TRIM(a.STDEDC)													AS stcodes_deduction_code
      , CASE TRIM(a.STSTAT)	
			WHEN 'A' THEN 'TRUE'
			WHEN 'D' THEN 'FALSE'
			ELSE 'unknown'	END											AS is_active
      , TRY_CONVERT(DATE,CONVERT(VARCHAR(8),a.STCRDT))					AS stcodes_creation_date
      , TRIM(a.STCRBY)													AS stcodes_creation_user_code
      , TRY_CONVERT(DATE,CONVERT(VARCHAR(8),a.STCHDT))					AS stcodes_last_update_date
      , TRIM(a.STCHBY)													AS stcodes_last_update_user_code
--INTO data_central_wh.silver.ibmi_stcodes
FROM data_central_lh.dbo.ibmi_stcodes_bronze a