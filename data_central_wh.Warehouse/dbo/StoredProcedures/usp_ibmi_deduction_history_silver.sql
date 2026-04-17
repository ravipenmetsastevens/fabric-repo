/***************************************************************************************************
Procedure:          dbo.usp_ibmi_deduction_history_silver
Create Date:        2024-05-15
Author:             Jeremy Shahan
Description:        Truncate and load of Deduction History Silver
Called by:            Azure Data Factory
					Pipeline: ibmi_deduction_history
Affected table(s):  silver.ibmi_deduction_history
Usage:              EXEC dbo.usp_ibmi_deduction_history

****************************************************************************************************
SUMMARY OF CHANGES
             Date(yyyy-mm-dd)    Author              Comments
------------------- ------------------ ------------------------------------------------------------
1            
***************************************************************************************************/

CREATE PROCEDURE [dbo].[usp_ibmi_deduction_history_silver]
AS

SET NOCOUNT ON

DELETE FROM silver.ibmi_deduction_history

INSERT INTO silver.ibmi_deduction_history
SELECT
	  TRIM(a.DHEMP)																		AS deduction_history_employee_code
	, TRIM(a.DHRUN)																			AS deduction_history_run_code
	, TRIM(a.DHBPKG)																		AS deduction_history_benefit_package_code
	, TRIM(a.DHTYPE)																		AS deduction_history_deduction_type
	, a.DHCODE																				AS deduction_history_deduction_code
	, TRIM(a.DHWDCD)																		AS deduction_history_wage_dump_code
	, dhpayd.date_key_pk																	AS deduction_history_deduct_date
	--, TRIM(a.DHWEEK)																		Unused
	, a.DHSEQ																				AS deduction_history_sequence_number
	, TRIM(a.DHDEPT)																		AS deduction_history_department_code
	, TRIM(a.DHJOB)																			AS deduction_history_job_description
	, CASE TRIM(a.DHADRP) 
			WHEN  'A'	THEN 'ADD'
			WHEN  'R'	THEN 'REPLACE'
			ELSE 'unknown' END																AS is_add_or_replace
	, CASE TRIM(a.DHCHGC) 
			WHEN  'C'	THEN 'CHARGE'
			WHEN  'R'	THEN 'REIMB'
			ELSE 'unknown' END																AS is_charge_or_reimbursement
	, CASE WHEN TRIM(a.DHHOLD) = 'H'
			THEN 'TRUE'
			ELSE 'FALSE' END																AS is_on_hold
	, TRIM(a.DHDVSN)																		AS deduction_history_division_code
	, TRIM(a.DHORD)																		AS deduction_history_load_number
	, TRIM(a.DHDSP)																		AS deduction_history_dispatch_number
	, TRIM(a.DHUNIT)																		AS deduction_history_truck_number
	, TRIM(a.DHOWNR)																		AS deduction_history_owner_code
	, TRIM(a.DHTEXC)																		AS deduction_history_truck_expense_account_number	
	--, TRIM(a.DHTCC)																		Unused
	, CASE WHEN TRIM(a.DHWDMP) = 'Y'
			THEN 'TRUE'
			ELSE 'FALSE' END																AS is_wage_dump
	, TRIM(a.DHPYAC)																		AS deduction_history_expense_account_number
	--, a.DHLACT																			Unused
	--, a.DHCACT																			Unused
	--, DHCC1																				Unused  
	--, DHPC1																				Unused
	--, DHCC2																				Unused
	--, DHPC2																				Unused
	--, DHCC3																				Unused
	--, DHPC3																				Unused
	, dhernd.date_key_pk																	AS deduction_history_earnings_date
	, a.DHEBKM																				AS deduction_history_expensed_book_month
	, a.DHEBKY																				AS deduction_history_expensed_book_year
	, dhckdt.date_key_pk																	AS deduction_history_check_date
	--, a.DHCKCD																			Unused
	, TRIM(a.DHCKNO)																		AS deduction_history_check_number
	--, a.DHPBKM																			Unused
	--, a.DHPBKY																			Unused
	, CASE WHEN TRIM(a.DHSTAT) = 'V'
			THEN 'TRUE'
			ELSE 'FALSE' END																AS is_voided
	--, a.DHVDDT																			Unused
	--, a.DHVBKM																			Unused
	--, a.DHVBKY																			Unused
	, a.DHAMT																				AS deduction_history_deduction_amount
	, a.DHAMTA																				AS deduction_history_employee_share_deducted
	, a.DHAMTB																				AS deduction_history_company_share
	, a.DHGROS																				AS deduction_history_earnings_gross_amount
	, a.DHQTY																				AS deduction_history_quantity
	--, a.DHCOVG																			Unused
	, TRIM(a.DHPO)																			AS deduction_history_purchase_order_number
	, TRIM(a.DHREF)																		AS deduction_history_advance_reference_code
	, TRIM(a.DHVNDR)																		AS deduction_history_advance_vendor_code
	, TRIM(a.DHCITY)																		AS deduction_history_location_city_code	
	, TRIM(a.DHST)																			AS deduction_history_location_state  
	, TRIM(a.DHAUSR)																		AS deduction_history_audit_user_code
	, dhadat.date_key_pk																	AS deduction_history_audit_date
    , CASE LEN(CONVERT(VARCHAR, a.DHATIM))
		WHEN 5 THEN CONVERT(TIME, CONCAT(LEFT(CONCAT('0',CONVERT(VARCHAR, a.DHATIM)),2),':',SUBSTRING(CONCAT('0',CONVERT(VARCHAR, a.DHATIM)),3,2)))
		WHEN 6 THEN CONVERT(TIME, CONCAT(LEFT(CONVERT(VARCHAR, a.DHATIM),2),':',SUBSTRING(CONVERT(VARCHAR, a.DHATIM),3,2)))
		ELSE NULL END																		AS deduction_history_audit_time
	--, a.DHCALC																			Unused
	--, a.DHPCTC																			Unused
	--, a.DHTAXA																			Unused
	--, a.DHPCTB																			Unused
--INTO silver.ibmi_deduction_history
FROM data_central_lh.dbo.ibmi_deduction_history_bronze a
LEFT JOIN gold.dim_date dhpayd ON a.DHPAYD = dhpayd.date_ordinal
LEFT JOIN gold.dim_date dhernd ON a.DHERND = dhernd.date_ordinal
LEFT JOIN gold.dim_date dhckdt ON a.DHCKDT = dhckdt.date_ordinal
LEFT JOIN gold.dim_date dhadat ON a.DHADAT = dhadat.date_ordinal