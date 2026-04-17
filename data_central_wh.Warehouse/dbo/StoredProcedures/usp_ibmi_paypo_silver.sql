/***************************************************************************************************
Procedure:          dbo.usp_ibmi_paypo_silver
Create Date:        2025-10-07
Author:             Jeremy Shahan
Description:        Truncate and load of Paypo to Silver
Called by:          Fabric
					Pipeline: ibmi_paypo
Affected table(s):  silver.ibmi_paypo
Usage:              EXEC dbo.usp_ibmi_paypo_silver

****************************************************************************************************
SUMMARY OF CHANGES
#             Date(yyyy-mm-dd)    Author              Comments
------------------- ------------------ ------------------------------------------------------------
1            
***************************************************************************************************/

CREATE    PROCEDURE [dbo].[usp_ibmi_paypo_silver]
AS

SET NOCOUNT ON

DELETE FROM silver.ibmi_paypo

INSERT INTO silver.ibmi_paypo
SELECT 
		TRIM(a.PYPOTY)																	AS paypo_type_code
      , CASE TRIM(a.PYPOST)
			WHEN 'D' THEN 'TRUE'
			ELSE 'FALSE'	END															AS is_deleted
      , CASE TRIM(a.PYPOTP)
			WHEN 'X' THEN 'Revenue'
			WHEN 'P' THEN 'Purchase Order'
			ELSE 'unknown'	END															AS paypo_category
      , TRIM(a.PYPODE)																	AS paypo_description
      , CASE TRIM(a.PYPOTX)
			WHEN 'Y' THEN 'TRUE'
			WHEN 'N' THEN 'FALSE'
			ELSE 'unknown'	END															AS is_taxable
      , TRIM(a.PYPOGL)																	AS paypo_gl_account_number
      --, a.PYPOCC
      , a.PYPORT																		AS paypo_normal_rate
      , a.PYPOAM																		AS paypo_max_amount
      , a.PYPOMN																		AS paypo_min_amount
      , CASE TRIM(a.PYPOOV)
			WHEN 'Y' THEN 'TRUE'
			WHEN 'N' THEN 'FALSE'
			ELSE 'unknown'	END															AS can_override_limit
      , CASE TRIM(a.PYPOSP)
			WHEN 'S' THEN 'TRUE'
			WHEN 'Y' THEN 'TRUE'
			WHEN 'N' THEN 'FALSE'
			ELSE 'unknown'	END															AS is_split_for_teams
      , PYPOCD.date_key_pk															AS paypo_creation_date
	  , CASE 
			WHEN CONVERT(INT, a.PYPOCT) <= 2359 
				AND LEN(TRIM(a.PYPOCT)) = 4 
				AND CONVERT(INT,RIGHT(TRIM(a.PYPOCT),2)) < 60
			THEN CONVERT(TIME(0),CONCAT(LEFT(a.PYPOCT,2),':',RIGHT(a.PYPOCT,2)))
			ELSE NULL END																AS paypo_creation_time
      , TRIM(a.PYPOCI)																	AS paypo_creation_initials						
      , PYPOLD.date_key_pk															AS paypo_last_update_date
	  , CASE 
			WHEN CONVERT(INT, a.PYPOLT) <= 2359 
				AND LEN(TRIM(a.PYPOLT)) = 4 
				AND CONVERT(INT,RIGHT(TRIM(a.PYPOLT),2)) < 60
			THEN CONVERT(TIME(0),CONCAT(LEFT(a.PYPOLT,2),':',RIGHT(a.PYPOLT,2)))
			ELSE NULL END																AS paypo_last_update_time
      , TRIM(a.PYPOLI)																	AS paypo_last_update_initials
      --, a.PYPOCO
      , TRIM(a.PYPODV)																	AS paypo_divisions
      --, a.PYPOTM
      --, a.PYYPSE
      , a.PYYPA2																		AS paypo_max_limit_l2
      , a.PYYPA3																		AS paypo_max_limit_l3
      --, a.PYYPEN
      , TRIM(a.PYYPCL)																	AS paypo_pay_class_code
      , TRIM(a.PYYPRT)																	AS paypo_pay_rate
      , CASE TRIM(a.PYYDBP)
			WHEN 'B' THEN 'TRUE'
			ELSE 'FALSE'	END															AS has_benefits_package
      , TRIM(a.PYYDTY)																	AS paypo_deduction_type_code
      , CONVERT(INT,a.PYYDSQ)															AS paypo_deduction_subtype_code
      , CASE TRIM(a.PYYCIR)
			WHEN 'C' THEN 'Charge'
			WHEN 'I' THEN 'Income'
			WHEN 'R' THEN 'Reimbursement'
			ELSE 'unknown'	END															AS paypo_pay_type
      , TRIM(a.PYPOG2)																	AS paypo_credit_gl_account	
      , TRIM(a.PYCOMC)																	AS paypo_commodity_code
--INTO data_central_wh.silver.ibmi_paypo
FROM data_central_lh.dbo.ibmi_paypo_bronze a
LEFT JOIN data_central_wh.gold.dim_date PYPOCD ON a.PYPOCD = PYPOCD.date_ordinal
LEFT JOIN data_central_wh.gold.dim_date PYPOLD ON a.PYPOLD = PYPOLD.date_ordinal