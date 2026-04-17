/***************************************************************************************************
Procedure:          dbo.usp_risk_company_master_silver
Create Date:        2025-09-05
Author:             Jeremy Shahan
Description:        Truncate and load of Company Master Silver
Called by:            Azure Data Factory
					Pipeline: risk_company_master
Affected table(s):  silver.risk_company_master
Usage:              EXEC dbo.usp_risk_company_master_silver

****************************************************************************************************
SUMMARY OF CHANGES
#             Date(yyyy-mm-dd)    Author              Comments
------------------- ------------------ ------------------------------------------------------------
1            
***************************************************************************************************/

CREATE       PROCEDURE [dbo].[usp_risk_company_master_silver]
AS

SET NOCOUNT ON

TRUNCATE TABLE silver.risk_company_master

INSERT INTO silver.risk_company_master
SELECT
		a.COMPANYRECORDID											AS company_mast_record_code
      , TRIM(a.COMPANYNAME)											AS company_mast_name
      , TRIM(a.COMPANYCODE)											AS company_mast_company_code
      , TRIM(a.TAXIDNUMBER)											AS company_mast_tax_id
       , CASE TRIM(a.NEWCLAIMSTOREGISTER)
			WHEN 'Y' THEN 'TRUE'
			WHEN 'N' THEN 'FALSE'
			ELSE 'unknown'	END										AS is_new_claims_to_register
      , CASE TRIM(a.FORCEDATEREPORTED)
			WHEN 'Y' THEN 'TRUE'
			WHEN 'N' THEN 'FALSE'
			ELSE 'unknown'	END										AS is_forced_date_reported
      , CASE TRIM(a.FORCETIMEREPORTED)
			WHEN 'Y' THEN 'TRUE'
			WHEN 'N' THEN 'FALSE'
			ELSE 'unknown'	END										AS is_forced_time_reported
      , CASE TRIM(a.USERESVTYPEFORPMNTS)
			WHEN 'Y' THEN 'TRUE'
			WHEN 'N' THEN 'FALSE'
			ELSE 'unknown'	END										AS is_use_reserve_type_for_payments
      , CASE TRIM(a.ALLOWBONUSDEDUCTION)
			WHEN 'Y' THEN 'TRUE'
			WHEN 'N' THEN 'FALSE'
			ELSE 'unknown'	END										AS is_bonus_deduction_allowed
      , a.BONUSDEDUCTIONLIMIT										AS company_mast_bonus_deduction_limit
      , CASE TRIM(a.ALLOWSALARYDEDUCTION)
			WHEN 'Y' THEN 'TRUE'
			WHEN 'N' THEN 'FALSE'
			ELSE 'unknown'	END										AS is_salary_deduction_allowed
      , a.SALARYDEDUCTIONLIMIT										AS company_mast_salary_deduction_limit
      , TRIM(a.ALLOWDEDUCTIONAT)									AS company_mast_allowed_deduction_at
      , CASE TRIM(a.FORCESALVSUBROTORESV)
			WHEN 'Y' THEN 'TRUE'
			WHEN 'N' THEN 'FALSE'
			ELSE 'unknown'	END										AS is_forced_salvage_to_reserve
      , CASE TRIM(a.FORCESALVSUBROTOEQUIP)
			WHEN 'Y' THEN 'TRUE'
			WHEN 'N' THEN 'FALSE'
			ELSE 'unknown'	END										AS is_forced_salvage_to_equipment
      , CASE TRIM(a.POSTEXPECTEDRECOVTOGL)
			WHEN 'Y' THEN 'TRUE'
			WHEN 'N' THEN 'FALSE'
			ELSE 'unknown'	END										AS is_posted_recovery_to_gl
      , TRIM(a.CLAIMMASK)											AS company_mast_claim_mask
      , CASE TRIM(a.CLAIMNUMBERRESET)
			WHEN 'Y' THEN 'TRUE'
			WHEN 'N' THEN 'FALSE'
			ELSE 'unknown'	END										AS is_claim_record_reset
      , CASE TRIM(a.ALLOWBRANCHSPECIFIC)
			WHEN 'Y' THEN 'TRUE'
			WHEN 'N' THEN 'FALSE'
			ELSE 'unknown'	END										AS is_branch_specific_allowed
      , CASE TRIM(a.EXTENDEDCLOSINGSTATUS)
			WHEN 'Y' THEN 'TRUE'
			WHEN 'N' THEN 'FALSE'
			ELSE 'unknown'	END										AS is_closing_status_extended
      , CASE TRIM(a.ALLOWPAYMENTSONCLOSED)
			WHEN 'Y' THEN 'TRUE'
			WHEN 'N' THEN 'FALSE'
			ELSE 'unknown'	END										AS is_payment_on_closed_allowed
      , a.NEXTAVAILABLECLAIMNUMBER									AS company_mast_next_avail_claim_record
      , a.NEXTAVAILABLEPRECLAIMNUMBER								AS company_mast_next_avail_pre_claim_record
      , CASE TRIM(a.ATTACHADJTOCLMT)
			WHEN 'Y' THEN 'TRUE'
			WHEN 'N' THEN 'FALSE'
			ELSE 'unknown'	END										AS is_attached_adjustment_to_claimant
      --, a.CURRENTYEAR
      --, a.CURRENTMONTH
      , a.CREATEDATE												AS company_mast_create_datetime
      , TRIM(a.CREATEUSER)											AS company_mast_create_user_code 
      , a.CHANGEDATE												AS company_mast_last_changed_datetime
      , TRIM(a.CHANGEUSER)											AS company_mast_last_changed_user_code
      , a.FUNDCODE													AS company_mast_fund_code
      , TRIM(a.CLAIMDATETOUSE)										AS company_mast_claim_date_usage_code	
      , CASE TRIM(a.MANUALCLAIMNUMBERYN)
			WHEN 'Y' THEN 'TRUE'
			WHEN 'N' THEN 'FALSE'
			ELSE 'unknown'	END										AS is_manual_claim_number
      --, a.DOCUMENTPATH
      --, a.UPLOADPATH
      --, a.CLMNUMLN
      --, a.NUMDAYKP
      --, a.REQTOPMNT
      --, a.DOTNUM
      --, a.ICCNUM
      --, a.OSHANUM
      --, a.MAXDIARIES
      , CASE TRIM(a.COSPECIFICMASTERTABLES)
			WHEN 'Y' THEN 'TRUE'
			WHEN 'N' THEN 'FALSE'
			ELSE 'unknown'	END										AS has_company_specific_master_tables
      --, a.DISABLEPAYMENTS
      , CASE TRIM(a.DISABLECHECKREQUESTS)
			WHEN 'Y' THEN 'TRUE'
			WHEN 'N' THEN 'FALSE'
			ELSE 'unknown'	END										AS is_check_request_disabled
      , a.FISCALYEARSTART											AS company_mast_fiscal_year_start_date
      --, a.MERGEMAILARCHIVEATTACHMENTTYPE
      , CASE TRIM(a.CLOSEDCLAIMSREADONLY)
			WHEN 'Y' THEN 'TRUE'
			WHEN 'N' THEN 'FALSE'
			ELSE 'unknown'	END										AS is_closed_claim_read_only
      , CASE TRIM(a.ALLOWEXCESSRECOVERIES)
			WHEN 'Y' THEN 'TRUE'
			WHEN 'N' THEN 'FALSE'
			ELSE 'unknown'	END										AS is_excess_recovery_allowed
      --, a.NAMEFORMAT
      --, a.NAMECASE
--INTO data_central_wh.silver.risk_company_master
FROM data_central_lh.dbo.risk_company_master_bronze a