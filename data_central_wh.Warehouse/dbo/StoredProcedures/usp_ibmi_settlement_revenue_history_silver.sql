/***************************************************************************************************
Procedure:          dbo.usp_ibmi_settlement_revenue_history_silver
Create Date:        2024-05-07
Author:             Jeremy Shahan
Description:        Truncate and load of Settlement Revenue History Silver
Called by:            Azure Data Factory
					Pipeline: ibmi_settlement_revenue_history
Affected table(s):  silver.ibmi_settlement_revenue_history
Usage:              EXEC dbo.usp_ibmi_settlement_revenue_history_silver

****************************************************************************************************
SUMMARY OF CHANGES
#             Date(yyyy-mm-dd)    Author              Comments
------------------- ------------------ ------------------------------------------------------------
1             2024-05-09		  Jeremy Shahan		  Revised Load Date
***************************************************************************************************/

CREATE PROCEDURE [dbo].[usp_ibmi_settlement_revenue_history_silver]
AS

SET NOCOUNT ON

DELETE FROM silver.ibmi_settlement_revenue_history

INSERT INTO silver.ibmi_settlement_revenue_history
SELECT 
	--TRIM(SRRECS)																		Unused
	  TRIM(a.SROWN)																		AS set_rev_hist_owner_code
	, TRIM(a.SRUNIT)																	AS set_rev_hist_truck_number
	--, TRIM(a.SRREVC)																	Unused
	, TRIM(a.SRORD)																	AS set_rev_hist_load_number
	, TRIM(a.SRDISP)																	AS set_rev_hist_dispatch_number
	, a.SRSEQ																			AS set_rev_hist_sequence_number
	, a.SRLDTE																			AS set_rev_hist_load_date --[m]dd
	, TRIM(a.SRLYR)																		AS set_rev_hist_load_year --yy
	--, CONCAT(
	--  CASE 
	--	WHEN LEFT(TRIM(a.SRLYR),1) > 5 THEN CONCAT('19',TRIM(a.SRLYR))
	--	ELSE CONCAT('20',TRIM(a.SRLYR)) END
	--	,'-'
	--	, CASE
	--	WHEN LEN(a.SRLDTE) = 3 THEN CONCAT('0',LEFT(a.SRLDTE,1),'-',RIGHT(a.SRLDTE,2))
	--	ELSE CONCAT(LEFT(a.SRLDTE,2),'-',RIGHT(a.SRLDTE,2)) END)						AS set_rev_hist_load_date_revised    --could not cast as date 
	,CONCAT(
	  CASE 
		WHEN LEFT(TRIM(a.SRLYR),1) > 5 THEN CONCAT('19',TRIM(a.SRLYR))
		ELSE CONCAT('20',TRIM(a.SRLYR)) END
		,'-'
		, CASE WHEN CHARINDEX('.' , CONVERT(VARCHAR, a.SRLDTE)) - 1 = 3 
			THEN CONCAT('0',LEFT(a.SRLDTE,1),'-',RIGHT(LEFT(a.SRLDTE, 3),2))
			ELSE CONCAT(LEFT(a.SRLDTE,2),'-',RIGHT(LEFT(a.SRLDTE,4),2)) END)			AS set_rev_hist_load_date_revised
	, SRRDAT.date_key_pk																AS set_rev_hist_record_date
	, TRIM(a.SRORG)																		AS set_rev_hist_origin_city --Seems mixed use between city and description
	, TRIM(a.SRDEST)																	AS set_rev_hist_destination_city
	, a.SRREVA																			AS set_rev_hist_revenue_amount
	, TRIM(a.SRFC)																		AS set_rev_hist_fund_code --Need clarification
	--, TRIM(a.SROWNR)																	Unused
	, TRIM(a.SRSEG)																		AS set_rev_hist_segment_status_code --Need clarification
	, a.SRMILE																			AS set_rev_hist_miles_total
	, TRIM(a.SROCTY)																	AS set_rev_hist_origin_code
	, TRIM(a.SRDCTY)																	AS set_rev_hist_destination_code
	, a.SRADPY																			AS set_rev_hist_additional_pay_amount
	, TRIM(a.SRFCAD)																	AS set_rev_hist_additional_pay_fund_code
	--, TRIM(a.SRFSC)																	Unused
	, a.SRLM																			AS set_rev_hist_miles_loaded
	, a.SRLMR																			AS set_rev_hist_loaded_mileage_rate
	, a.SREM																			AS set_rev_hist_miles_dead_head
	, a.SREMR																			AS set_rev_hist_dead_head_mileage_rate
	, TRIM(a.SRFCRT)																	AS set_rev_hist_mileage_rate_fund_code --Need clarification
	, TRIM(a.SRDBGL)																	AS set_rev_hist_debit_account_number
	, TRIM(a.SRCRGL)																	AS set_rev_hist_credit_account_number
	--, TRIM(a.SRDBCC)																	Unused
	--, TRIM(a.SRCRCC)																	Unused
	, TRIM(a.SRBKMO)																	AS set_rev_hist_expense_month
	, TRIM(a.SRBKYR)																	AS set_rev_hist_expense_year
	--, TRIM(a.SRVBKM)																	Unused
	--, TRIM(a.SRVBKY)																	Unused
	, TRIM(a.SRPBKM)																	AS set_rev_hist_paid_month
	, TRIM(a.SRPBKY)																	AS set_rev_hist_paid_year
	, CASE WHEN TRIM(a.SREXPF) = 'Y'
			THEN 'TRUE'
			ELSE 'FALSE' END															AS is_expensed
	--, TRIM(a.SRWCFL)																	Unused
	, a.SRDOM																			AS set_rev_hist_domestic_amount
	, SREDAT.date_key_pk																AS set_rev_hist_domestic_expensed_date
	--, TRIM(a.SROREV)																	Unused
	, TRIM(a.SRREVT)																	AS set_rev_hist_revenue_type_code
	--, TRIM(a.SRGSTC)																	Unused
	--, TRIM(a.SRGSTA)																	Unused
	, TRIM(a.SRVCH)																	AS set_rev_hist_voucher_number
	--, TRIM(a.SRPGLB)																	Unused
	--, TRIM(a.SREGLB)																	Unused
	--, TRIM(a.SRVGLB)																	Unused
	--, TRIM(a.SROBAL)																	Unused
	, SRUPDD.date_key_pk																AS set_rev_hist_last_update_date
	, CASE WHEN CONVERT(INT, a.SRUPDT) < 2400 AND LEN(TRIM(a.SRUPDT)) = 4
		THEN CONVERT(TIME, (CONCAT(LEFT(TRIM(a.SRUPDT),2)
		     ,':',RIGHT(TRIM(a.SRUPDT),2))))
		ELSE NULL END																	AS set_rev_hist_last_update_time
	, TRIM(a.SRUPDI)																	AS set_rev_hist_last_update_initials
FROM data_central_lh.dbo.ibmi_settlement_revenue_history_bronze a
LEFT JOIN gold.dim_date SRRDAT ON a.SRRDAT = SRRDAT.date_ordinal
LEFT JOIN gold.dim_date SREDAT ON a.SREDAT = SREDAT.date_ordinal
LEFT JOIN gold.dim_date SRUPDD ON a.SRUPDD = SRUPDD.date_ordinal