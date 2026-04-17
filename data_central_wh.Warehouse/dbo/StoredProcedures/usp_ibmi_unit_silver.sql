/***************************************************************************************************
Procedure:          dbo.usp_ibmi_unit_silver
Create Date:        2024-03-21
Author:             Tom Wolfenden
Description:        Truncate and load of unit Silver
Called by:            Azure Data Factory
					Pipeline: ibmi_unit_master
Affected table(s):  silver.ibmi_unit_master
Usage:              EXEC dbo.usp_ibmi_unit_silver

****************************************************************************************************
SUMMARY OF CHANGES
#             Date(yyyy-mm-dd)    Author              Comments
------------------- ------------------ ------------------------------------------------------------
1            
***************************************************************************************************/

CREATE PROCEDURE [dbo].[usp_ibmi_unit_silver]
AS

SET NOCOUNT ON

TRUNCATE TABLE  silver.ibmi_unit

INSERT INTO silver.ibmi_unit
SELECT 
      TRIM(a.UNUNIT)																					AS unit_truck_number
    , TRIM(a.UNOWN)																						AS unit_owner_code
    --, TRIM(a.UNCO)																					Unused
    , TRIM(a.UNDV)																						AS unit_truck_division_code				
    --, TRIM(a.UNTM)																					Unused
    , TRIM(a.UNYEAR)																					AS unit_year    
    , TRIM(a.UNMAKE)																					AS unit_make
    , TRIM(a.UNSER)																						AS unit_vin
    , TRIM(a.UNPLAT)																					AS unit_base_license_plate
    , TRIM(a.UNPLST)																					AS unit_base_state
    , TRIM(a.UNTNT)																						AS unit_new_york_license
    , TRIM(a.UNHUT)																						AS unit_other --Need clarification
    , unterm.date_key_pk																				AS unit_term_date
    --, a.UNCOST																						Hasn't been used for years
    --, a.UNINS																							Hasn't been used for years
    , TRIM(a.UNPAYT)																					AS unit_pay_type --Need clarification. M or Blank
    --, a.UNPERC																						Unused
    --, a.UNLRAT																						Unused
    --, a.UNERAT																						Unused
    , unhirw.date_key_pk																				AS unit_hire_date
    , TRIM(a.UNDR1)																						AS unit_seat_1_driver_code
    , TRIM(a.UNDR2)																						AS unit_seat_2_driver_code
    , TRIM(a.UNTRL1)																					AS unit_trailer_1_code
    , TRIM(a.UNPDR1)																					AS unit_previous_seat_1_driver_code
    , TRIM(a.UNPDR2)																					AS unit_previous_seat_2_driver_code
    , TRIM(a.UNPTR1)																					AS unit_previous_trailer_1_code
    , TRIM(a.UNSTAT)																					AS unit_status_code --Need clarification
    , TRIM(a.UNORD)																						AS unit_current_load
    , TRIM(a.UNDISP)																					AS unit_current_dispatch
    , TRIM(a.UNPRVO)																					AS unit_previous_load
    , TRIM(a.UNPDSP)																					AS unit_previous_dispatch
    , TRIM(a.UNDCTY)																					AS unit_destination_city_code
    , TRIM(a.UNDST)																						AS unit_destination_state
    --, TRIM(a.UNDZN)																					Unused
    , TRIM(a.UNDRG)																						AS unit_destination_region_code
    , a.UNDBEA																							AS unit_destination_bea_code
    , TRIM(a.UNDGU)																						AS unit_destination_gu_code
    , TRIM(a.UNDSNM)																					AS unit_destination_city_short_description
    , a.UNEWGT																							AS unit_empty_weight
    , a.UNGRWT																							AS unit_gross_weight
    , unetad.date_key_pk																				AS unit_eta_date
	, CASE WHEN CONVERT(INT, a.UNETAT) < 2400 
			AND LEN(TRIM(a.UNETAT)) = 4 
			AND CONVERT(INT, RIGHT(TRIM(a.UNETAT),2)) <60
		THEN CONVERT(TIME(0),CONCAT(LEFT(a.UNETAT,2),':',RIGHT(a.UNETAT,2)))
		ELSE NULL END																					AS unit_eta_time
    , unectd.date_key_pk																				AS unit_eta_change_date
    , uncntd.date_key_pk																				AS unit_contact_date
	, CASE WHEN CONVERT(INT, a.UNCNTT) < 2400 
			AND LEN(TRIM(a.UNCNTT)) = 4 
			AND CONVERT(INT, RIGHT(TRIM(a.UNCNTT),2)) <60
		THEN CONVERT(TIME(0),CONCAT(LEFT(a.UNCNTT,2),':',RIGHT(a.UNCNTT,2)))
		ELSE NULL END																					AS unit_contact_time
    , TRIM(a.UNCNTI)																					AS unit_contact_initials
    , TRIM(a.UNCCTY)																					AS unit_contact_city_code
    , TRIM(a.UNCST)																						AS unit_contact_state
    , TRIM(a.UNCSNM)																					AS unit_contact_city_short_description
    , CASE TRIM(a.UNMESS)
		  WHEN 'Y'	THEN 'TRUE'
		  ELSE 'FALSE' END																				AS has_message_flag
    , CASE TRIM(a.UNDEL) 
			WHEN 'D' THEN 'TRUE'
			WHEN 'A' THEN 'TRUE'
			ELSE 'FALSE' END																			AS is_truck_deleted																						
    , TRIM(a.UNTYPE)																					AS unit_truck_type
    , TRIM(a.UNAXLE)																					AS unit_axle_count																				
    , TRIM(a.UNFLET)																					AS unit_fleet_code
    --, TRIM(a.UNDHOR)																					Unused
    , TRIM(a.UNPREO)																					AS unit_preplan_load
    , CASE TRIM(a.UNCMTM)
		WHEN 'Y' THEN 'TRUE'
		WHEN 'N' THEN 'FALSE'
		ELSE 'unknown'	END																				AS is_preplan_committed
    , TRIM(a.UNFUEL)																					AS unit_fuel_type_code -- U/Blank. D was used in 2023.
    , CASE TRIM(a.UNAVAS)
		  WHEN 'Y'	THEN 'TRUE'
		  ELSE 'FALSE' END																				AS has_avas_code    
	, TRIM(a.UNDARA)																					AS unit_destination_area_code
    , a.UNLHUB																							AS unit_lastest_hub_miles
    , unlprd.date_key_pk																				AS unit_lastest_purchase_date
    , CASE WHEN CONVERT(INT, a.UNLPRT) < 2400 AND LEN(TRIM(a.UNLPRT)) = 4
		THEN CONVERT(TIME(0), (CONCAT(LEFT(TRIM(a.UNLPRT),2)
		     ,':',RIGHT(TRIM(a.UNLPRT),2))))
		ELSE NULL END																					AS unit_lastest_purchase_time																					
    --, a.UNLGAL																						Unused
    --, a.UNLMPG																						Unused
    --, a.UN1GAL																						Unused
    --, a.UN1MPG																						Unused --99 and 0 for 2024. Not logical
    --, a.UN1HUB																						Unused
    , un1prd.date_key_pk																				AS unit_first_purchase_date
	, CASE WHEN CONVERT(INT, a.UN1PRT) < 2400 
			AND LEN(TRIM(a.UN1PRT)) = 4 
			AND CONVERT(INT, RIGHT(TRIM(a.UN1PRT),2)) <60
		THEN CONVERT(TIME(0),CONCAT(LEFT(a.UN1PRT,2),':',RIGHT(a.UN1PRT,2)))
		ELSE NULL END																					AS unit_first_purchase_time
    , a.UNPGAL									
    , a.UNPMPG
    , a.UNPHUB																							AS unit_previous_hub_miles
    , unpprd.date_ordinal																				AS unit_previous_purchase_date
	, CASE WHEN CONVERT(INT, a.UNPPRT) < 2400 
			AND LEN(TRIM(a.UNPPRT)) = 4 
			AND CONVERT(INT, RIGHT(TRIM(a.UNPPRT),2)) <60
		THEN CONVERT(TIME(0),CONCAT(LEFT(a.UNPPRT,2),':',RIGHT(a.UNPPRT,2)))
		ELSE NULL END																					AS unit_previous_purchase_time
    --, TRIM(a.UNCOSC)																					Unused
    , a.UNEDIS																							AS unit_latitude
    , a.UNNDIS																							AS unit_longitude
    --, TRIM(a.UNMULT)																					Unused
    --, a.UNLEN																							Unused
    --, a.UNAXS																							Unused
    , CASE TRIM(a.UNFLIC)
		  WHEN 'Y'	THEN 'TRUE'
		  ELSE 'FALSE' END																				AS has_fleet_license																					
    --, TRIM(a.UNENG)																					Unused for the last few decades
    --, TRIM(a.UNMISC)																					Unused in 2024
    --, a.UNFCAP																						Unused for the last few decades
    --, unpurd.date_key_pk																				Unused
    , TRIM(a.UNLCOD)																					AS unit_2_character_code --Need clarification
    --, TRIM(a.UNWRKC)																					Unused
    , TRIM(a.UNLSTS)																					AS unit_last_satalite_location --City Code+ST 
    , TRIM(a.UNSSNM)																					AS unit_last_satalite_location_short_name
    --, TRIM(a.UNNXTL)																					Unused
    , TRIM(a.UNNSNM)																					AS unit_next_stop_short_name
	, CASE WHEN CONVERT(INT, a.UNPTA) < 2400 
			AND LEN(TRIM(a.UNPTA)) = 4 
			AND CONVERT(INT, RIGHT(TRIM(a.UNPTA),2)) <60
		THEN CONVERT(TIME(0),CONCAT(LEFT(a.UNPTA,2),':',RIGHT(a.UNPTA,2)))
		ELSE NULL END																					AS unit_proj_avail_time --Might need to take the raw HHMM value since we use it for other things
    , unpda.date_key_pk																					AS unit_proj_avail_date
    , unpcdt.date_key_pk																				AS unit_pta_change_date
    , TRIM(a.UNSUPR)																					AS unit_dm_code
    , TRIM(a.UNFMGR)																					AS unit_dmol_code
    --, TRIM(a.UNSERV)																					Unused since 2022
    , CASE TRIM(a.UNCSTF)
		WHEN 'Y' THEN 'TRUE'
		WHEN 'N' THEN 'FALSE'
		ELSE 'unknown'	END																				AS is_customer_site_flagged
    --, uncred.date_key_pk																				Unused
	--, CASE WHEN CONVERT(INT, a.UNCRET) < 2400 
	--		AND LEN(TRIM(a.UNCRET)) = 4 
	--		AND CONVERT(INT, RIGHT(TRIM(a.UNCRET),2)) <60
	--	THEN CONVERT(TIME,CONCAT(LEFT(a.UNCRET,2),':',RIGHT(a.UNCRET,2)))
	--	ELSE NULL END																					Unused
    --, TRIM(a.UNCREI)																					Unused
    , unupdd.date_key_pk																				AS unit_last_update_date
	, CASE WHEN CONVERT(INT, a.UNUPDT) < 2400 
			AND LEN(TRIM(a.UNUPDT)) = 4 
			AND CONVERT(INT, RIGHT(TRIM(a.UNUPDT),2)) <60
		THEN CONVERT(TIME(0),CONCAT(LEFT(a.UNUPDT,2),':',RIGHT(a.UNUPDT,2)))
		ELSE NULL END																					AS unit_last_update_time
    , TRIM(a.UNUPDI)																					AS unit_last_update_initials
    --, TRIM(a.UNOWNT)																					Unused since 8/2023
    --, a.UNUBAL																						Unused
    --, a.UNCBAL																						Unused
    , CASE TRIM(a.UNCTYT)
		WHEN 'Y' THEN 'TRUE'
		WHEN 'N' THEN 'FALSE'
		ELSE 'unknown'	END																				AS is_city_truck
    , TRIM(a.UNMODL)																					AS unit_model_code --Repurposed Need clarification
    , TRIM(a.UNGATE)																					AS unit_gate_check_location
    , TRIM(a.UNDCST)																					AS unit_dedicated_customer_code
    --, TRIM(a.UNEDFL)																					Unused
    , TRIM(a.UNTYP2)																					AS unit_subtype --Repurposed Need clarification
    --, TRIM(a.UNEFM)																					Redundancy. Only used for modeling
    , CASE TRIM(a.UNAVLD)
		WHEN 'Y' THEN 'TRUE'
		WHEN 'N' THEN 'FALSE'
		ELSE 'unknown'	END																				AS is_available_for_limited_dispatch --Need clarification if "dispatch"																					
    , unhdte.date_key_pk																				AS unit_temp_hold_date
    , SUBSTRING(a.UNFIL,8,1)																			AS unit_truck_sold_flag
	--, LEFT(a.UNFIL,1)																					AS unit_owner_code
	, CASE SUBSTRING(a.UNFIL,2,1)
		WHEN 'Y' THEN 'TRUE'
		WHEN 'N' THEN 'FALSE'
		ELSE 'unknown'		END																			AS has_jake
	, CASE SUBSTRING(a.UNFIL,3,1)
		WHEN 'Y' THEN 'TRUE'
		WHEN 'N' THEN 'FALSE'
		ELSE 'unknown'			END																		AS has_cruise
	, SUBSTRING(a.UNFIL,4,2)																			AS unit_speed_control
	, CASE SUBSTRING(a.UNFIL,12,1)
		WHEN 'Y' THEN 'TRUE'
		WHEN 'N' THEN 'FALSE'
		ELSE 'unknown'			END																		AS has_esp
	, CASE SUBSTRING(a.UNFIL,6,1)
		WHEN 'Y' THEN 'TRUE'
		WHEN 'N' THEN 'FALSE'
		ELSE 'unknown'			END																		AS has_apu
	, CASE SUBSTRING(a.UNFIL,9,1)
		WHEN 'Y' THEN 'TRUE'
		WHEN 'N' THEN 'FALSE'
		ELSE 'unknown'			END																		AS is_carbon_compliant 
	, CASE SUBSTRING(a.UNFIL,10,1)
		WHEN 'X' THEN 'TRUE'
		ELSE 'FALSE'			END																		AS has_team_gone_solo --11 is unknown. 7 is a message not sent flag 
--INTO data_central_wh.silver.ibmi_unit
FROM data_central_lh.dbo.ibmi_unit_bronze a
LEFT JOIN gold.dim_date unterm ON a.UNTERM = unterm.date_ordinal
LEFT JOIN gold.dim_date unhirw ON a.UNHIRW = unhirw.date_ordinal
LEFT JOIN gold.dim_date unetad ON a.UNETAD = unetad.date_ordinal
LEFT JOIN gold.dim_date unectd ON a.UNECDT = unectd.date_ordinal
LEFT JOIN gold.dim_date uncntd ON a.UNCNTD = uncntd.date_ordinal
LEFT JOIN gold.dim_date unlprd ON a.UNLPRD = unlprd.date_ordinal
LEFT JOIN gold.dim_date un1prd ON a.UN1PRD = un1prd.date_ordinal
LEFT JOIN gold.dim_date unpprd ON a.UNPPRD = unpprd.date_ordinal
LEFT JOIN gold.dim_date unpurd ON a.UNPURD = unpurd.date_ordinal
LEFT JOIN gold.dim_date unpda ON a.UNPDA = unpda.date_ordinal
LEFT JOIN gold.dim_date unpcdt ON a.UNPCDT = unpcdt.date_ordinal
LEFT JOIN gold.dim_date uncred ON a.UNCRED = uncred.date_ordinal
LEFT JOIN gold.dim_date unupdd ON a.UNUPDD = unupdd.date_ordinal
LEFT JOIN gold.dim_date unhdte ON a.UNHDTE = unhdte.date_ordinal