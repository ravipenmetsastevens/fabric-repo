/***************************************************************************************************
Procedure:          dbo.usp_ibmi_driver_master
Create Date:        2024-03-21
Author:             Tom Wolfenden
Description:        Truncate and load of Driver Master Silver
Called by:            Azure Data Factory
					Pipeline: ibmi_driver_master
Affected table(s):  silver.ibmi_driver_master
Usage:              EXEC dbo.usp_ibmi_driver_silver

****************************************************************************************************
SUMMARY OF CHANGES
#             Date(yyyy-mm-dd)    Author              Comments
------------------- ------------------ ------------------------------------------------------------
1				2025-09-11			Jeremy Shahan		Modified various fields to correspond 
														to repurposed system fields 
***************************************************************************************************/

CREATE   PROCEDURE [dbo].[usp_ibmi_driver_silver_new]
AS

SET NOCOUNT ON

DELETE FROM silver.ibmi_driver

INSERT INTO silver.ibmi_driver

SELECT
	    TRIM(a.DRCODE)																	AS drv_code
      , TRIM(a.DRNAME)																	AS drv_full_name
	  , CASE WHEN CHARINDEX(',', TRIM(a.DRNAME)) > 1 THEN
			LEFT(TRIM(a.DRNAME), CHARINDEX(',', TRIM(a.DRNAME))-1)  
			ELSE TRIM(a.DRNAME) END														AS drv_last_name
	  , CASE WHEN CHARINDEX(',', TRIM(a.DRNAME)) > 1 THEN
		RIGHT(TRIM(a.DRNAME), (LEN(TRIM(a.DRNAME)) - CHARINDEX(',', a.DRNAME))-1)  
		ELSE TRIM(a.DRNAME) END															AS drv_first_name
      , TRIM(a.DRSHNM)																	AS drv_short_name
      , TRIM(a.DRADD)																	AS drv_address_line_1
      , TRIM(a.DRCITY)																	AS drv_address_city
      , TRIM(a.DRST)																	AS drv_address_state
      , TRIM(a.DRZIP)																	AS drv_address_zip
      , TRIM(a.DRZP2)																	AS drv_address_zip_extn
      , CONVERT(VARCHAR, a.DRAC)														AS drv_area_code
      , CONVERT(VARCHAR, a.DRPHON)														AS drv_phone_number
      , TRIM(a.DRSS)																	AS drv_social_security  --MASK?
      , TRIM(a.DRSUPR)																	AS drv_dm_code   -- Change to ID later
      , TRIM(a.DRFMGR)																	AS drv_dmol_code    -- Change to ID later
      , DRCRED.date_key_pk																AS drv_create_date
      ,CASE WHEN LEN(TRIM(DRCRET)) > 0 THEN
		CONVERT(TIME(0), CONCAT(LEFT(DRCRET,2),':',RIGHT(DRCRET,2)))
		ELSE NULL END																	AS drv_create_time
      , TRIM(a.DRCREI)																	AS drv_create_initial
      , DRUPDD.date_key_pk																AS drv_update_date
      ,CASE WHEN LEN(TRIM(DRUPDT)) > 0 THEN
		CONVERT(TIME(0), CONCAT(LEFT(DRUPDT,2),':',RIGHT(DRUPDT,2)))
		ELSE NULL END																	AS drv_update_time
      , TRIM(a.DRUPDI)																	AS drv_update_initial
      --**, TRIM(a.DRCO)																	AS drv_company   --NO DATA	
      --**, TRIM(a.DRDV)																	AS drv_division  --NO DATA
      , TRIM(a.DRTM)																	AS drv_school_code   --**
      , DRBDAT.date_key_pk																AS drv_birth_date
      , DRHDAT.date_key_pk																AS drv_hire_date
      , DRRDAT.date_key_pk																AS drv_review_date
      , DRTDAT.date_key_pk																AS drv_termination_date
      , DRLEXP.date_key_pk																AS drv_license_expiry_date
      , DRPEXP.date_key_pk																AS drv_physical_expiry_date
	  , TRIM(LEFT(a.DRLICE, 23))														AS drv_license_number
	  , CASE WHEN LEN(a.DRLICE) > 23 THEN
			TRIM(RIGHT(a.DRLICE, LEN(a.DRLICE) -23))
			ELSE 'unknown' END															AS drv_license_state
      --, TRIM(a.DRLICE)																	
      ,CASE DRTYPE
		WHEN 0 THEN 'COMPANY'
		WHEN 1 THEN 'OWNER'
		ELSE 'unknown'			END														AS drv_type
	  , CASE WHEN LEN(TRIM(a.DRSTAT)) = 0 OR a.DRSTAT IS NULL
			THEN 'unknown'
			ELSE a.DRSTAT END															AS drv_availability_code --**
      , CASE WHEN LEN(TRIM(a.DRPRVO)) = 0 OR a.DRPRVO IS NULL
			THEN 'unknown'
			ELSE a.DRPRVO END															AS drv_previous_load_number --** update to ID later   ORDERS
      , CASE WHEN LEN(TRIM(a.DRPDSP)) = 0 OR a.DRPDSP IS NULL
			THEN 'unknown'
			ELSE a.DRPDSP END															AS drv_previous_dispatch    --update to ID later  LOADS
      , CASE WHEN LEN(TRIM(a.DRORD)) = 0 OR a.DRORD IS NULL
			THEN 'unknown'
			ELSE a.DRORD END															AS drv_current_load_number     --** update to ID later	   ORDER
      , CASE WHEN LEN(TRIM(a.DRDISP)) = 0 OR a.DRDISP IS NULL
			THEN 'unknown'
			ELSE a.DRDISP END															AS drv_current_dispatch  --update to ID later     LOAD
      , CASE WHEN LEN(TRIM(a.DRUNIT)) = 0 OR a.DRUNIT IS NULL
			THEN 'unknown'
			ELSE a.DRUNIT END															AS drv_assigned_truck --update to ID later	   UNIT
      , CASE WHEN LEN(TRIM(a.DRDCTY)) = 0 OR a.DRDCTY IS NULL
			THEN 'unknown'
			ELSE a.DRDCTY END															AS drv_dispatch_city_code --** 
      , CASE WHEN LEN(TRIM(a.DRDST)) = 0 OR a.DRDST IS NULL
			THEN 'unknown'
			ELSE a.DRDST END															AS drv_dispatch_state 
	  , CONCAT(a.DRDST,a.DRDCTY)														AS drv_dispatch_st_city   --update to ID later CITY
      , CASE WHEN TRIM(a.DRMSG) = 'Y'
			THEN 'TRUE'
			ELSE 'FALSE' END															AS has_drv_messages
      , CASE WHEN TRIM(a.DRDLT) = 'D'
			THEN 'TRUE'
			ELSE 'FALSE' END															AS is_drv_deleted
      , TRIM(a.DRENAM)																	AS drv_emerg_contact_name
      , TRIM(a.DRENUM)																	AS drv_emerg_contact_phone
      , TRIM(a.DRPHAZ) 																	AS drv_trainee_level_code --**
      , TRIM(a.DRNUNT)																	AS drv_trainee_counselor_code   --** This is NOT a UNIT number!
      --**, TRIM(a.DRSPS)																	AS drv_spouse --NO DATA
      , CASE 
			WHEN TRY_CONVERT(DATE,SUBSTRING(a.DRMISC,7,2)+SUBSTRING(a.DRMISC,3,4),101) 
			IS NULL THEN NULL
			ELSE CONVERT(DATE,SUBSTRING(a.DRMISC,7,2)+SUBSTRING(a.DRMISC,3,4),101) END	AS drv_last_safety_talk_date
      , TRIM(SUBSTRING(a.DRMISC,10,3))													AS drv_safety_talk_code
	  --**, TRIM(a.DRFC)																	AS drv_fund_code --NO DATA
      , CONCAT(RIGHT(TRIM(a.DRHOME),2),LEFT(TRIM(a.DRHOME),4))							AS drv_home_city_code
	  , CASE WHEN LEN(TRIM(a.DRVOIC)) = 0 OR a.DRVOIC IS NULL
			THEN 'unknown'
			ELSE a.DRVOIC END															AS drv_voice_box
	  , CASE TRIM(a.DRJIT)
			WHEN 'N' THEN 'False'
			WHEN 'Y' THEN 'True'
			ELSE 'unknown' END															AS is_jit_drv
      , TRIM(a.DRTRAN)																	AS is_trainee_drv --TRAINEE Y/N/S
      --, a.DR1DTE																		-- NOT CONVERTING THESE UNLESS NEEDED
      --, a.DR1MIL
      --, a.DR2DTE
      --, a.DR2MIL
      --, a.DR3DTE
      --, a.DR3MIL
      --, a.DR4DTE
      --, a.DR4MIL
      --, a.DR5DTE
      --, a.DR5MIL
      --, a.DR6DTE
      --, a.DR6MIL
      --, a.DR7DTE
      --, a.DR7MIL
      , a.DRDBAL																		AS drv_adv_balance
      --**, a.DRCBAL																		AS drv_company_adv_balance
      , a.DRMBPW																		AS drv_mailbox_pwd
      --**, a.DRLPAY																		AS drv_last_pay_amount
      , TRIM(a.DRCARD)																	AS drv_fuel_card
      , DRSOLO.date_key_pk																AS drv_grad_date    --Driver Solo Day
      --, a.DRLTDT    --Date Last Drug Test
      --, a.DRNTDT    --Date Next Drug Test
	  , CASE TRIM(a.DRSMKR)
			WHEN 'N' THEN 'False'
			WHEN 'Y' THEN 'True'
			ELSE 'unknown' END															AS is_drv_smoker
	  , CASE WHEN LEN(TRIM(a.DRRACE)) = 0 OR a.DRRACE IS NULL
			THEN 'unknown'
			ELSE a.DRRACE END															AS drv_race
      , CASE TRIM(a.DRSEX) 
			WHEN 'M' THEN 'MALE'
			WHEN 'F' THEN 'FEMALE'
			ELSE 'unknown' END															AS drv_gender
	  , CASE TRIM(a.DRLONG)
			WHEN 'N' THEN 'FALSE'
			WHEN 'Y' THEN 'TRUE'
			ELSE 'unknown' END															AS has_hazmat_cert --**
      , DRLGDT.date_key_pk																AS drv_hazmat_exp_date --**
      , TRIM(a.DRTYCD)																	AS drv_cell_area_code       --DRIVER TYPE/CODE
      , TRIM(a.DRTERM)																	AS drv_cell_number    --DRIVER HOME TERMINAL
     -- , a.DRPTAD				--DRIVER PTA DATE
      --, TRIM(a.DRPTAT)		--PTA TIME
      --, a.DRHFM
      --, TRIM(a.DRSPCT)
      , TRIM(a.DRSPST)																	AS drv_grad_level_code --**
      , DRSDTE.date_key_pk																AS drv_sr_cert_date    
      --, TRIM(a.DRSTME)   --special request time
      , TRIM(a.DRPRIO)																	AS drv_status_code 
      --, a.DRDTED
      --, TRIM(a.DRTMED)
      , TRIM(a.DRUNTA)																	AS drv_counselor_status_code --**
   --   , CASE TRIM(SUBSTRING(a.DRFIL,2,5))
			--WHEN '' THEN NULL 
			--WHEN '00000' THEN NULL
			--ELSE DATEADD(dd, (SUBSTRING(a.DRFIL,2,5) % 1000) - 1
			--, DATEADD(yy, SUBSTRING(a.DRFIL,2,5) / 1000 + 100, 0))	END					AS drv_physical_recheck_date --**
	  , CASE TRIM(SUBSTRING(a.DRFIL,1,1))
			WHEN 'Y' THEN 'TRUE'
			WHEN 'N' THEN 'FALSE'
			ELSE 'unknown'	END															AS is_canada_cert --**
	  , CASE TRIM(SUBSTRING(a.DRFIL,12,1))
			WHEN 'Y' THEN 'TRUE'
			WHEN 'N' THEN 'FALSE'
			ELSE 'unknown'	END															AS is_nyc_cert --**
  --INTO data_central_wh.silver.ibmi_driver
  FROM data_central_lh.dbo.ibmi_driver_bronze a
  LEFT JOIN gold.dim_date DRCRED ON a.DRCRED = DRCRED.date_ordinal
  LEFT JOIN gold.dim_date DRUPDD ON a.DRUPDD = DRUPDD.date_ordinal
  LEFT JOIN gold.dim_date DRBDAT ON a.DRBDAT = DRBDAT.date_ordinal
  LEFT JOIN gold.dim_date DRHDAT ON a.DRHDAT = DRHDAT.date_ordinal
  LEFT JOIN gold.dim_date DRRDAT ON a.DRRDAT = DRRDAT.date_ordinal
  LEFT JOIN gold.dim_date DRTDAT ON a.DRTDAT = DRTDAT.date_ordinal
  LEFT JOIN gold.dim_date DRLEXP ON a.DRLEXP = DRLEXP.date_ordinal
  LEFT JOIN gold.dim_date DRPEXP ON a.DRPEXP = DRPEXP.date_ordinal
  LEFT JOIN gold.dim_date DRLGDT ON a.DRLGDT = DRLGDT.date_ordinal
  LEFT JOIN gold.dim_date DRSOLO ON a.DRSOLO = DRSOLO.date_ordinal
  LEFT JOIN gold.dim_date DRSDTE ON a.DRSDTE = DRSDTE.date_ordinal