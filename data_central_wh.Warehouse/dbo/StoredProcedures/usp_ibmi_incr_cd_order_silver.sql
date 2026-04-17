CREATE    PROCEDURE [dbo].[usp_ibmi_incr_cd_order_silver]
AS

SET NOCOUNT ON

DELETE FROM silver.ibmi_incr_cd_order

INSERT INTO silver.ibmi_incr_cd_order
SELECT
	  TRIM(a.ORARA)																	AS cd_order_origin_area_code
	, TRIM(a.ORODR)																	AS cd_order_load_number
	, TRIM(a.ORSTAT)																AS cd_order_status_code
	, ORDATE.date_key_pk															AS cd_order_date
	--, CASE WHEN CONVERT(INT, a.ORTIME) < 2400 AND LEN(TRIM(a.ORTIME)) = 4
	--	THEN CONVERT(TIME,CONCAT(LEFT(a.ORTIME,2),':',RIGHT(a.ORTIME,2)))
	--	ELSE NULL END																AS order_time
	, TRIM(a.ORTIME)																AS cd_order_time
	, TRIM(a.ORCUST)																AS cd_order_customer_code
	, TRIM(a.ORCONS)																AS cd_order_consignee_code
	, TRIM(a.ORBILL)																AS cd_order_billto_code
	, TRIM(a.ORLDAT)																AS cd_order_loadat_code
	, ORPDAT.date_key_pk															AS cd_order_early_pickup_date
	--, CASE WHEN CONVERT(INT, a.ORPTIM) < 2400 AND LEN(TRIM(a.ORPTIM)) = 4
	--	THEN CONVERT(TIME,CONCAT(LEFT(a.ORPTIM,2),':',RIGHT(a.ORPTIM,2)))
	--	ELSE NULL END																AS order_early_pickup_time
	, TRIM(a.ORPTIM)																AS cd_order_early_pickup_time
	, CASE TRIM(a.ORRPIK)
		WHEN 'Y' THEN 'TRUE'
		WHEN 'N' THEN 'FALSE'
		ELSE 'unknown'	END															AS is_pickup_required
	, ORDDAT.date_key_pk															AS cd_order_early_delivery_date
	--, CASE WHEN CONVERT(INT, a.ORDTIM) < 2400 AND LEN(TRIM(a.ORDTIM)) = 4
	--	THEN CONVERT(TIME,CONCAT(LEFT(a.ORDTIM,2),':',RIGHT(a.ORDTIM,2)))
	--	ELSE NULL END																AS order_early_delivery_time
	, TRIM(a.ORDTIM)																AS cd_order_early_delivery_time
    , CASE TRIM(a.ORRDEL)
		WHEN 'Y' THEN 'TRUE'
		WHEN 'N' THEN 'FALSE'
		ELSE 'unknown'	END															AS is_delivery_required
    , TRIM(a.ORCOMC)																AS cd_order_commodity_code
    , TRIM(a.ORCOMD)																AS cd_order_commodity_description
    , TRIM(a.ORINIT)																AS cd_order_creation_initials
    , CONVERT(VARCHAR, a.ORCAC)													AS cd_order_customer_phone_area_code
    , CONVERT(VARCHAR, a.ORCPHN)													AS cd_order_customer_phone_number
    , CONVERT(VARCHAR, a.ORRAC)													AS cd_order_consignee_phone_area_code
    , CONVERT(VARCHAR, a.ORRPHN)													AS cd_order_consignee_phone_number
    --, TRIM(a.ORCTIM)																Unused
    , a.ORWGT																		AS cd_order_load_weight
    --, a.ORTWGT																	Unused
    --, TRIM(a.ORHOOK)																Unused
    --, TRIM(a.ORRACK)																Unused
    , TRIM(a.ORPLLT)																AS cd_order_pallet_count
    , TRIM(a.OROCTY)																AS cd_order_origin_city_code
    , TRIM(a.OROST)																	AS cd_order_origin_state
    , a.OROBEA																		AS cd_order_origin_bea_code -- Need clarification
    , TRIM(a.OROGU)																	AS cd_order_origin_gu_code --Need clarification
    , TRIM(a.OROSNM)																AS cd_order_origin_city_short_name
    , TRIM(a.ORDCTY)																AS cd_order_destination_city_code
    , TRIM(a.ORDST)																	AS cd_order_destination_state
    , a.ORDBEA																		AS cd_order_destination_bea_code -- Need clarification
    , TRIM(a.ORDGU)																	AS cd_order_destination_gu_code
    , TRIM(a.ORDSNM)																AS cd_order_destination_city_short_name
    , a.ORMILE																		AS cd_order_miles_billable
    --, a.ORLDMI																	Unused over the last few decades
    --, a.OREMIL																	Unused over the last few decades
    , TRIM(a.ORRST)																	AS cd_order_load_type -- R = Reefer, D = Dry, I = Intermodal
    , TRIM(a.ORSTP)																	AS cd_order_stop_count --Need to convert to number
    --, TRIM(a.ORLD)																AS order_load_count --Redundancy for the last several years. 
    --, TRIM(a.ORPDRV)																Redundancy. Only used during proccessing to represent preplanned truck/T-Call location for swaps
    , TRIM(a.OR_DSP)																AS cd_order_dispatch_count
    --, TRIM(a.ORDSP)																Redundancy
    , TRIM(a.ORTRLR)																AS cd_order_preload_trailer														
    , a.ORESTR																		AS cd_order_revenue_estimation
    , TRIM(a.ORNWPK)																AS cd_order_new_origin_area_code --Area from possible T-Call location
    , TRIM(a.ORINAR)																AS cd_order_destination_area_code
    , TRIM(a.ORCSH)																	AS cd_order_bill_of_lading
    , TRIM(a.ORCNS)																	AS cd_order_purchase_order
    , TRIM(a.ORORBY)																AS cd_order_pick_up_code  --Used by customers for tracking purposes
    --, TRIM(a.ORLS)																Unused over the last few decades
    , TRIM(a.ORPIEC)																AS cd_order_piece_count
    , TRIM(a.ORPORC)																AS cd_order_collection_method_code -- P = Prepaid and C = Collection T = Third Party or Blank
    --, TRIM(a.ORMAN)																Unused over the last few decades
    , TRIM(a.ORCUBE)																AS cd_order_load_volume --In cubic feet
    , TRIM(a.ORSPEC)																AS cd_order_message --Need clarification from Ops
    , ORAPDT.date_key_pk															AS cd_order_late_pickup_date
	--, CASE WHEN CONVERT(INT, a.ORAPTM) < 2400 AND LEN(TRIM(a.ORAPTM)) = 4
	--	THEN CONVERT(TIME,CONCAT(LEFT(a.ORAPTM,2),':',RIGHT(a.ORAPTM,2)))
	--	ELSE NULL END																AS order_late_pickup_time
	, TRIM(a.ORAPTM)																AS cd_order_late_pickup_time
    --, TRIM(a.ORAPNM)																Unused
    --, TRIM(a.ORAPIN)																Unused over the last few decades
    , ORADDT.date_key_pk															AS cd_order_late_delivery_date
	--, CASE WHEN CONVERT(INT, a.ORADTM) < 2400 AND LEN(TRIM(a.ORADTM)) = 4
	--	THEN CONVERT(TIME,CONCAT(LEFT(a.ORADTM,2),':',RIGHT(a.ORADTM,2)))
	--	ELSE NULL END																AS order_late_delivery_time
	, TRIM(a.ORADTM)																AS cd_order_late_delivery_time
    --, TRIM(a.ORADNM)																Unused
    --, TRIM(a.ORADIN)																Unused over the last few decades
    , a.ORPREQ																		AS cd_order_required_pallet_count
    --, orarr.date_key_pk															Unused
    --, a.ORCPIC																	Unused
    --, a.ORCWGT																	Unused
    , ORSHDT.date_key_pk															AS cd_order_ship_date
	--, CASE WHEN CONVERT(INT, TRIM(a.ORSHTM)) < 2400 AND LEN(TRIM(a.ORSHTM)) = 4
	--	THEN CONVERT(TIME,CONCAT(LEFT(TRIM(a.ORSHTM),2),':',RIGHT(TRIM(a.ORSHTM),2)))
	--	ELSE NULL END																AS order_ship_time
	, TRIM(a.ORSHTM)																		AS order_ship_time
	--, TRIM(a.ORSHTM)																AS order_ship_time
    , a.ORTMPH																		AS cd_order_temp_high
    , a.ORTMPL																		AS cd_order_temp_low
    --, TRIM(a.OREQTY)																Unused over the last few years
    , ORUPDD.date_key_pk															AS cd_order_last_update_date
	--, CASE WHEN CONVERT(INT, a.ORUPDT) < 2400 AND LEN(TRIM(a.ORUPDT)) = 4
	--	THEN CONVERT(TIME,CONCAT(LEFT(a.ORUPDT,2),':',RIGHT(a.ORUPDT,2)))
	--	ELSE NULL END																AS order_last_update_time
	, TRIM(a.ORUPDT)																AS cd_order_last_update_time
    , TRIM(a.ORUPDI)																AS cd_order_last_update_initials
    , TRIM(a.ORCO)																	AS cd_order_company_code
    , TRIM(a.ORDV)																	AS cd_order_division_code
    , TRIM(a.ORTM)																	AS cd_order_lane_code
    , TRIM(a.ORSEL1)																AS cd_order_seal_code
    --, TRIM(a.ORSEL2)																Unused
    , TRIM(a.ORSERV)																AS cd_order_service_failure_code
    , TRIM(a.ORCMTM)																AS cd_order_driver_commit_flag
    --, TRIM(a.ORHAZM)																Unused over the last few decades
    , TRIM(a.OREDI)																	AS is_edi_load
    , TRIM(a.OREDIC)																AS is_edi_stats_complete
    , TRIM(a.ORDLD)																	AS is_driver_loaded
    , TRIM(a.ORDULD)																AS is_driver_unloaded
    , TRIM(a.ORSDR)																	AS is_delivery_receipt_signed
    , TRIM(a.ORSDRR)																AS cd_order_delivery_receipt_req 
    , TRIM(a.OREDMB)																AS cd_order_edi_message_billing_flag
    --, TRIM(a.ORBBOC)																Unused over the last few decades
    , TRIM(a.ORJIT)																	AS is_load_just_in_time
    --, TRIM(a.ORCDED)																Unused
    --, TRIM(a.ORAGNT)																Unused over the last few decades
    , TRIM(a.OREDFB)																AS cd_order_edi_billing_code
    , CASE TRIM(a.OREDIO)
		WHEN 'I' THEN 'INBOUND'
		WHEN 'O' THEN 'OUTBOUND'
		ELSE 'unknown'	END															AS is_edi_inbound_or_outbound
    --, a.ORQUT																		Unused
    --, a.OROPLM																	Unused
    --, a.ORDPLM																	Unused
    , TRIM(a.ORCCTY)																AS cd_order_current_city_code
    , TRIM(a.ORCST)																	AS cd_order_current_state
    , ORLCDT.date_key_pk															AS cd_order_loaded_call_date
    , ORECDT.date_key_pk															AS cd_order_empty_call_date
    --, TRIM(a.ORRATO)																Unused
    --, a.ORLDWG																	Unused
    , a.ORLGT																		AS cd_order_trailer_length --Need clarification
    , a.ORHGT																		AS cd_order_trailer_height --Need clarification
    --, a.ORWDT																		Unused
    , TRIM(a.ORPMTF)																AS has_permit --Blank or "M"
    , TRIM(a.ORPCOM)																AS has_permit_complete
    , a.ORLAT																		AS cd_order_latitude
    , a.ORLONG																		AS cd_order_longitude
    , TRIM(a.ORTEN)																	AS is_tentitive_load --Blank or "C"
    , a.ORHRS																		AS cd_order_hours_under_dispatch --Hasn't been used in 2024
    --, a.ORMIN																		Unused
    , TRIM(a.OROZN)																	AS cd_order_origin_zone_code
    , TRIM(a.ORORG)																	AS cd_order_origin_region_code
    , TRIM(a.ORDZN)																	AS cd_order_destination_zone_code
    , TRIM(a.ORDRG)																	AS cd_order_destination_region_code
    , TRIM(a.ORTBRT)																AS is_to_be_rated
    --, TRIM(a.ORNZN)																Unused
    --, TRIM(a.ORNRG)																Unused
    --, a.ORNBEA																	Unused
    , TRIM(a.ORNGU)																	AS has_new_gu_code --Blank or "U"
    , TRIM(a.OREFM)																	AS is_exclude_from_model --Blank or "R"
    , TRIM(a.ORCARF)																AS cd_order_carry_over_flag --Blank or "U" or "V"
    , TRIM(a.ORUTYP)																AS cd_order_truck_type_requirement_code
    --, TRIM(a.ORTTYP)																Unused over the last few decades															
    --, TRIM(a.ORDTYP)																Unused
    --, TRIM(a.ORHAZC)																Unused
    , TRIM(a.ORFIL)																	AS cd_order_delivery_code 
--INTO data_central_wh.silver.ibmi_incr_cd_order
FROM data_central_lh.dbo.ibmi_incr_cd_order_bronze a
LEFT JOIN gold.dim_date ORDATE ON a.ORDATE = ORDATE.date_ordinal
LEFT JOIN gold.dim_date ORPDAT ON a.ORPDAT = ORPDAT.date_ordinal
LEFT JOIN gold.dim_date ORDDAT ON a.ORDDAT = ORDDAT.date_ordinal
LEFT JOIN gold.dim_date ORAPDT ON a.ORAPDT = ORAPDT.date_ordinal
LEFT JOIN gold.dim_date ORADDT ON a.ORADDT = ORADDT.date_ordinal
LEFT JOIN gold.dim_date ORARR  ON a.ORARR  = ORARR.date_ordinal
LEFT JOIN gold.dim_date ORUPDD ON a.ORUPDD = ORUPDD.date_ordinal
LEFT JOIN gold.dim_date ORLCDT ON a.ORLCDT = ORLCDT.date_ordinal
LEFT JOIN gold.dim_date ORECDT ON a.ORECDT = ORECDT.date_ordinal
LEFT JOIN gold.dim_date ORSHDT ON a.ORSHDT = ORSHDT.date_ordinal