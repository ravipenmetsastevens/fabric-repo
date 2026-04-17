/***************************************************************************************************
Procedure:          dbo.usp_ibmi_payclass_silver
Create Date:        2025-10-07
Author:             Jeremy Shahan
Description:        Truncate and load of Payclass to Silver
Called by:          Fabric
					Pipeline: ibmi_payclass
Affected table(s):  silver.ibmi_payclass
Usage:              EXEC dbo.usp_ibmi_payclass_silver

****************************************************************************************************
SUMMARY OF CHANGES
#             Date(yyyy-mm-dd)    Author              Comments
------------------- ------------------ ------------------------------------------------------------
1            
***************************************************************************************************/

CREATE    PROCEDURE [dbo].[usp_ibmi_payclass_silver]
AS

SET NOCOUNT ON

DELETE FROM silver.ibmi_payclass

INSERT INTO silver.ibmi_payclass
SELECT 
		TRIM(a.CLCLAS)													AS payclass_class_code
      , TRIM(a.CLRTYP)													AS payclass_unit_type_code
      , a.CLFAC															AS payclass_pay_rate_factor
      , TRIM(a.CLDESC)													AS payclass_description
      , TRIM(a.CLUNBK)													AS payclass_unbank_overtime_code
      , a.CLPOST														AS payclass_bucket_code
      , CASE TRIM(a.CLTTAX)
			WHEN 'Y' THEN 'TRUE'
			WHEN 'N' THEN 'FALSE'
			ELSE 'unknown'	END											AS is_income_taxable
      , CASE TRIM(a.CLTINS)
			WHEN 'Y' THEN 'TRUE'
			WHEN 'N' THEN 'FALSE'
			ELSE 'unknown'	END											AS has_unemployment_insurance
      , CASE TRIM(a.CLTPEN)
			WHEN 'Y' THEN 'TRUE'
			WHEN 'N' THEN 'FALSE'
			ELSE 'unknown'	END											AS has_cpp_pension_pay
      , CASE TRIM(a.CLTUN)
			WHEN 'Y' THEN 'TRUE'
			WHEN 'N' THEN 'FALSE'
			ELSE 'unknown'	END											AS has_union_dues
      , CASE TRIM(a.CLT401)
			WHEN 'Y' THEN 'TRUE'
			WHEN 'N' THEN 'FALSE'
			ELSE 'unknown'	END											AS has_401k_pay
      , CASE TRIM(a.CLTCAF)
			WHEN 'Y' THEN 'TRUE'
			WHEN 'N' THEN 'FALSE'
			ELSE 'unknown'	END											AS has_cafeteria_pay
      , CASE TRIM(a.CLEWCB)
			WHEN 'Y' THEN 'TRUE'
			WHEN 'N' THEN 'FALSE'
			ELSE 'unknown'	END											AS has_employee_workers_comp
      , CASE TRIM(a.CLRWCB)
			WHEN 'Y' THEN 'TRUE'
			WHEN 'N' THEN 'FALSE'
			ELSE 'unknown'	END											AS has_employer_workers_comp
      --, a.CLPAID
      , TRIM(a.CLTEXC)													AS payclass_truck_expense_account_number
      , TRIM(a.CLEACT)													AS payclass_expense_account_number
--INTO data_central_wh.silver.ibmi_payclass
FROM data_central_lh.dbo.ibmi_payclass_bronze a