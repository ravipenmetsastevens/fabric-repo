/***************************************************************************************************
Procedure:          dbo.usp_risk_claim_master_silver
Create Date:        2025-08-26
Author:             Jeremy Shahan
Description:        Truncate and load of Claim Master Silver
Called by:            Azure Data Factory
					Pipeline: risk_claim_master
Affected table(s):  silver.risk_claim_master
Usage:              EXEC dbo.usp_risk_claim_master_silver

****************************************************************************************************
SUMMARY OF CHANGES
#             Date(yyyy-mm-dd)    Author              Comments
------------------- ------------------ ------------------------------------------------------------
1            
***************************************************************************************************/

CREATE   PROCEDURE [dbo].[usp_risk_claim_master_silver]
AS

SET NOCOUNT ON

TRUNCATE TABLE silver.risk_claim_master

INSERT INTO silver.risk_claim_master
SELECT
	    a.COMPANYRECORDID								AS claim_mast_company_code
      , a.CLAIMMASTERRECORDID							AS claim_mast_record_code
      , a.PRECLAIMRECORDID								AS claim_mast_pre_claim_code
      , CASE a.CLAIMMASTERTYPECODE 
			WHEN 1 THEN 'OS&D Cargo Claim'
			WHEN 2 THEN 'Accidents & Incidents'
			WHEN 3 THEN 'Personal Injury'
			WHEN 4 THEN 'Hazmat Incident'
			WHEN 5 THEN 'Self Funded Workers Comp'
			WHEN 6 THEN 'Personal Injury'
			ELSE 'unknown' END							AS claim_mast_type							
      --, a.BRANCHRECORDID								AS claim_mast_branch_code
      , TRIM(a.CLAIMNUMBER)								AS claim_mast_claim_number									
      , CONVERT(DATE,a.OCCURANCEDATE)					AS claim_mast_occurance_date
	  , CONVERT(TIME(0),a.OCCURANCEDATE)				AS claim_mast_occurance_time
	  , a.OCCURANCEDATE									AS claim_mast_occurance_datetime
      --, a.COMMONCATRECORDID							AS claim_mast_common_record_code
      , CASE WHEN TRIM(a.INCLUDECARGOCLAIMYN) = 'Y'
			THEN 'TRUE'
			ELSE 'FALSE' END							AS is_cargo_included							
      , a.REPORTEDBYCODE								AS claim_mast_reported_by_code
      , a.CLAIMANTCOMPANYNUM							AS claim_mast_claimant_company_code
      , a.CLAIMANTINDIVIDUALNUM							AS claim_mast_claimant_individual_code
      --, a.INSUREDCOMPANYNUM							
      , a.INVOLVEDDRIVERNUM								AS claim_mast_involved_driver_code
      , a.CLAIMANTCUSTOMERNUM							AS claim_mast_claimant_customer_code
      , a.WCCLAIMANTNUM									AS claim_mast_wc_claimant_code
      , a.WITNESSNUM									AS claim_mast_witness_code
      , CONVERT(DATE,a.CREATEDATE)						AS claim_mast_create_date
	  , CONVERT(TIME(0),a.CREATEDATE)					AS claim_mast_create_time
	  , a.CREATEDATE									AS claim_mast_create_datetime
      , TRIM(a.CREATEUSER)								AS claim_mast_create_user_code
      , CONVERT(DATE,a.CHANGEDATE)						AS claim_mast_last_update_date
	  , CONVERT(TIME(0),a.CHANGEDATE)					AS claim_mast_last_update_time
	  , a.CHANGEDATE									AS claim_mast_last_update_datetime
      , TRIM(a.CHANGEUSER)								AS claim_mast_last_update_user_code
      --, a.INSUREDINDIVIDUALNUM
      , a.MISCELLANEOUSNUM								AS claim_mast_misc_code
      , a.COEQUIPMENTNUM								AS claim_mast_coequipment_code
      , TRIM(a.UDFA1)									AS claim_mast_truck_number
      , TRIM(a.UDFA2)									AS claim_mast_trailer_number
      , TRIM(a.UDFA3)									AS claim_mast_driver_home_code
      --, TRIM(a.UDFA4)									AS claim_mast_
      --, a.UDFD1
      --, a.UDFD2
      --, a.UDFD3
      --, a.UDFD4
      --, a.UDFN1
      --, a.UDFN2
      --, a.UDFN3
      --, a.UDFN4
      --, a.UDFL1
      --, a.UDFL2
      --, a.UDFL3
      --, a.UDFL4
      --, a.UDFL5
      --, a.UDFL6
      --, a.UDFL7
      --, a.UDFL8
      --, a.INCLWCC
      , a.FTADJRID										AS claim_mast_primary_adjuster_code	
      , a.CURRENTSTATUS									AS claim_mast_current_status_code
      , CONVERT(DATE,a.CLOSINGDATE)						AS claim_mast_closing_date
	  , CONVERT(TIME(0),a.CLOSINGDATE)					AS claim_mast_closing_time
	  , a.CLOSINGDATE									AS claim_mast_closing_datetime
      --, a.SEQFROM400
--INTO data_central_wh.silver.risk_claim_master
FROM data_central_lh.dbo.risk_claim_master_bronze a