/***************************************************************************************************
Procedure:          dbo.usp_ibmi_cd_ordbill_silver
Create Date:        2024-06-12
Author:             Jeremy Shahan
Description:        Truncate and load of CD ORDBILL Silver
Called by:            Azure Data Factory
					Pipeline: ibmi_cd_ordbill
Affected table(s):  silver.ibmi_cd_ordbill
Usage:              EXEC dbo.usp_ibmi_cd_ordbill_silver

****************************************************************************************************
SUMMARY OF CHANGES
#             Date(yyyy-mm-dd)    Author              Comments
------------------- ------------------ ------------------------------------------------------------
1            
***************************************************************************************************/

CREATE PROCEDURE [dbo].[usp_ibmi_cd_ordbill_silver]
AS

SET NOCOUNT ON

DELETE FROM silver.ibmi_cd_ordbill

INSERT INTO silver.ibmi_cd_ordbill
SELECT

	  TRIM(a.ORODR#)																		AS cd_ordbill_load_number
	, TRIM(a.ORSEQ)																			AS cd_ordbill_sequence_number 
	, TRIM(a.ORBINT)																		AS cd_ordbill_rate_clerk_initials
	, TRIM(a.ORINV)																			AS cd_ordbill_invoice_number 
	, TRIM(a.ORVINV)																		AS cd_ordbill_void_invoice_number
	, orbdat.date_key_pk																	AS cd_ordbill_billed_date
	, a.ORBAMT																				AS cd_ordbill_load_bill_amount
	, a.ORTAMT																				AS cd_ordbill_load_total_amount
	, TRIM(a.ORBOMO)																		AS cd_ordbill_load_book_month
	, TRIM(a.ORBOYR)																		AS cd_ordbill_load_book_year
	, CASE TRIM(a.ORBLST)
		WHEN 'Y' THEN 'TRUE'
		WHEN 'N' THEN 'FALSE'
		ELSE 'unknown'	END																	AS is_billing_flagged
	, TRIM(a.ORARST)																		AS cd_ordbill_ar_status_flag
	--, TRIM(a.ORSTCD)																		Unused
	--, TRIM(a.ORSERI)																		Unused
	, TRIM(a.ORTARF)																		AS cd_ordbill_tariff_code
	, TRIM(a.ORITEM)																		AS cd_ordbill_item_code
	, TRIM(a.ORLINE)																		AS cd_ordbill_line_code
	--, TRIM(a.ORSUMC)																		Unused
	, TRIM(a.ORRATC)																		AS cd_ordbill_rate_code
	--, TRIM(a.ORHLDB)																		Unused
	, a.ORBAML																				AS cd_ordbill_billed_amount_linehaul
	, a.ORBAMA																				AS cd_ordbill_billed_amount_accessorial
	, a.ORTAML																				AS cd_ordbill_total_amount_linehaul
	, a.ORTAMA																				AS cd_ordbill_total_amount_accessorial
	--, a.ORACAM																			Unused since 2021
	--, TRIM(a.ORACFL)																		Unused since 2021
	, a.ORFSC																				AS cd_ordbill_load_fuel_surcharge_amount 
	, a.ORTFSC																				AS cd_ordbill_total_fuel_surcharge_amount
	--, TRIM(a.ORGSTR)																		Unused
	--, TRIM(a.ORGSTB)																		Unused
	, oraudt.date_key_pk																	AS cd_ordbill_audit_date
	, TRIM(a.ORAUIN)																		AS cd_ordbill_audit_initials
	, orprdt.date_key_pk																	AS cd_ordbill_print_date
	, TRIM(a.ORCFLG)																		AS cd_ordbill_cost_record_flag
	--, TRIM(a.ORGSTC)																		Unused since 2014
	--, TRIM(a.ORFREV)																		Unused
FROM data_central_lh.dbo.ibmi_cd_ordbill_bronze a
LEFT JOIN data_central_wh.gold.dim_date orbdat ON a.ORBDAT = orbdat.date_ordinal
LEFT JOIN data_central_wh.gold.dim_date oraudt ON a.ORAUDT = oraudt.date_ordinal
LEFT JOIN data_central_wh.gold.dim_date orprdt ON a.ORPRDT = orprdt.date_ordinal