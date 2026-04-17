/***************************************************************************************************
Procedure:          dbo.usp_ibmi_edi_order_history_silver
Create Date:        2026-01-07
Author:             Jeremy Shahan
Description:        Truncate and load of EDI Order History Silver
Called by:            Azure Data Factory
					Pipeline: ibmi_edi_order_history
Affected table(s):  silver.ibmi_edi_order_history
Usage:              EXEC dbo.usp_ibmi_edi_order_history_silver

****************************************************************************************************
SUMMARY OF CHANGES
#             Date(yyyy-mm-dd)    Author              Comments
------------------- ------------------ ------------------------------------------------------------
1            
***************************************************************************************************/

CREATE   PROCEDURE [dbo].[usp_ibmi_edi_order_history_silver]
AS

SET NOCOUNT ON

DELETE FROM silver.ibmi_edi_order_history

INSERT INTO silver.ibmi_edi_order_history
SELECT 

        TRIM(a.EOARA)                                                                                                                               AS edi_ord_hist_origin_area_code
      , TRIM(a.EOODR)                                                                                                                               AS edi_ord_hist_customer_order
      , TRIM(a.EOSTAT)                                                                                                                              AS edi_ord_hist_status_code
      , EODATE.date_key_pk														                                                                	AS edi_ord_hist_order_date
	  , CASE 
            WHEN TRY_CAST(a.EOTIME AS INT) IS NULL THEN NULL
			WHEN CONVERT(INT,a.EOTIME) < 2400 
                AND RIGHT(CONVERT(INT,a.EOTIME),2) < 60
				AND LEN(CONVERT(VARCHAR(4),CONVERT(INT,a.EOTIME))) = 4 
			THEN TIMEFROMPARTS(LEFT(CONVERT(INT,a.EOTIME),2),RIGHT(CONVERT(INT,a.EOTIME),2),0,0,0)
			WHEN CONVERT(INT,a.EOTIME) < 2400 
                AND RIGHT(CONVERT(INT,a.EOTIME),2) < 60
				AND LEN(CONVERT(VARCHAR(4),CONVERT(INT,a.EOTIME))) = 3 
			THEN TIMEFROMPARTS(LEFT(CONVERT(INT,a.EOTIME),1),RIGHT(CONVERT(INT,a.EOTIME),2),0,0,0)
			WHEN CONVERT(INT,a.EOTIME) < 2400  
                AND RIGHT(CONVERT(INT,a.EOTIME),2) < 60
				AND LEN(CONVERT(VARCHAR(4),CONVERT(INT,a.EOTIME))) IN (1,2)
			THEN TIMEFROMPARTS(0,CONVERT(INT,a.EOTIME),0,0,0)
			ELSE NULL END												                                                                            AS edi_ord_hist_order_time     
      , TRIM(a.EOCUST)                                                                                                                              AS edi_ord_hist_customer_code
      , TRIM(a.EOCONS)                                                                                                                              AS edi_ord_hist_consignee_code
      , TRIM(a.EOBILL)                                                                                                                              AS edi_ord_hist_billto_code
      , TRIM(a.EOLDAT)                                                                                                                              AS edi_ord_hist_loadat_code
      , EOPDAT.date_key_pk														                                                                	AS edi_ord_hist_pickup_date
	  , CASE 
            WHEN TRY_CAST(a.EOPTIM AS INT) IS NULL THEN NULL
			WHEN CONVERT(INT,a.EOPTIM) < 2400 
                AND RIGHT(CONVERT(INT,a.EOPTIM),2) < 60
				AND LEN(CONVERT(VARCHAR(4),CONVERT(INT,a.EOPTIM))) = 4 
			THEN TIMEFROMPARTS(LEFT(CONVERT(INT,a.EOPTIM),2),RIGHT(CONVERT(INT,a.EOPTIM),2),0,0,0)
			WHEN CONVERT(INT,a.EOPTIM) < 2400 
                AND RIGHT(CONVERT(INT,a.EOPTIM),2) < 60
				AND LEN(CONVERT(VARCHAR(4),CONVERT(INT,a.EOPTIM))) = 3 
			THEN TIMEFROMPARTS(LEFT(CONVERT(INT,a.EOPTIM),1),RIGHT(CONVERT(INT,a.EOPTIM),2),0,0,0)
			WHEN CONVERT(INT,a.EOPTIM) < 2400  
                AND RIGHT(CONVERT(INT,a.EOPTIM),2) < 60
				AND LEN(CONVERT(VARCHAR(4),CONVERT(INT,a.EOPTIM))) IN (1,2)
			THEN TIMEFROMPARTS(0,CONVERT(INT,a.EOPTIM),0,0,0)
			ELSE NULL END												                                                                            AS edi_ord_hist_pickup_time     
      , CASE TRIM(a.EORPIK)
            WHEN 'Y' THEN 'TRUE'
            WHEN 'N' THEN 'FALSE'
            ELSE 'unknown' END                                                                                                                      AS is_pickup_required
      , EODDAT.date_key_pk														                                                                	AS edi_ord_hist_delivery_date
	  , CASE 
            WHEN TRY_CAST(a.EODTIM AS INT) IS NULL THEN NULL
			WHEN CONVERT(INT,a.EODTIM) < 2400 
                AND RIGHT(CONVERT(INT,a.EODTIM),2) < 60
				AND LEN(CONVERT(VARCHAR(4),CONVERT(INT,a.EODTIM))) = 4 
			THEN TIMEFROMPARTS(LEFT(CONVERT(INT,a.EODTIM),2),RIGHT(CONVERT(INT,a.EODTIM),2),0,0,0)
			WHEN CONVERT(INT,a.EODTIM) < 2400 
                AND RIGHT(CONVERT(INT,a.EODTIM),2) < 60
				AND LEN(CONVERT(VARCHAR(4),CONVERT(INT,a.EODTIM))) = 3 
			THEN TIMEFROMPARTS(LEFT(CONVERT(INT,a.EODTIM),1),RIGHT(CONVERT(INT,a.EODTIM),2),0,0,0)
			WHEN CONVERT(INT,a.EODTIM) < 2400  
                AND RIGHT(CONVERT(INT,a.EODTIM),2) < 60
				AND LEN(CONVERT(VARCHAR(4),CONVERT(INT,a.EODTIM))) IN (1,2)
			THEN TIMEFROMPARTS(0,CONVERT(INT,a.EODTIM),0,0,0)
			ELSE NULL END												                                                                            AS edi_ord_hist_delivery_time    
      , CASE TRIM(a.EORDEL)
            WHEN 'Y' THEN 'TRUE'
            WHEN 'N' THEN 'FALSE'
            ELSE 'unknown' END                                                                                                                      AS is_delivery_required
      , TRIM(a.EOCOMC)																                                                                AS edi_ord_hist_commodity_code
      , TRIM(a.EOCOMD)																                                                                AS edi_ord_hist_commodity_description
      , TRIM(a.EOINIT)																                                                                AS edi_ord_hist_creation_initials
      , CONVERT(VARCHAR, a.EOCAC)													                                                                AS edi_ord_hist_customer_phone_area_code
      , CONVERT(VARCHAR, a.EOCPHN)													                                                                AS edi_ord_hist_customer_phone_number
      , CONVERT(VARCHAR, a.EORAC)													                                                                AS edi_ord_hist_consignee_phone_area_code
      , CONVERT(VARCHAR, a.EORPHN)													                                                                AS edi_ord_hist_consignee_phone_number
      --, a.EOCTIM
      , a.EOWGT																		                                                                AS edi_ord_hist_load_weight
      --, a.EOTWGT
      --, a.EOHOOK
      , TRIM(a.EOPLLT)																                                                                AS edi_ord_hist_pallet_count
      , a.EOBAMT                                                                                                                                    AS edi_ord_hist_bill_amount                                                   
      , a.EOTAMT                                                                                                                                    AS edi_ord_hist_total_amount
      , TRIM(a.EOOCTY)																                                                                AS edi_ord_hist_origin_city_code
      , TRIM(a.EOOST)																	                                                            AS edi_ord_hist_origin_state
      --, a.EOOZN
      --, a.EOORG
      --, a.EOOBEA
      --, a.EOOGU
      , TRIM(a.EOOSNM)																                                                                AS edi_ord_hist_origin_city_short_name
      , TRIM(a.EODCTY)																                                                                AS edi_ord_hist_destination_city_code
      , TRIM(a.EODST)																	                                                            AS edi_ord_hist_destination_state
      --, a.EODZN
      --, a.EODRG
      --, a.EODBEA
      --, a.EODGU
      , TRIM(a.EODSNM)																                                                                AS edi_ord_hist_destination_city_short_name
      , a.EOMILE                                                                                                                                    AS edi_ord_hist_miles_billable
      , TRIM(a.EOSTP#)                                                                                                                              AS edi_ord_hist_stop_count
      --, a.EOLD#
      --, a.EOPDRV
      , TRIM(a.EOTRLR)                                                                                                                              AS edi_ord_hist_trailer_number                                                                                                                            
      , a.EOESTR                                                                                                                                    AS edi_ord_hist_revenue_estimation
      --, a.EONWPK
      , TRIM(a.EOINAR)                                                                                                                              AS edi_ord_hist_destination_area_code
      --, a.EOTARF
      --, a.EOITEM
      --, a.EOLINE
      , TRIM(a.EOCSH)                                                                                                                               AS edi_ord_hist_bill_of_lading
      , TRIM(a.EOCNS)                                                                                                                               AS edi_ord_hist_purchase_order
      , TRIM(a.EOORBY)                                                                                                                              AS edi_ord_hist_pickup_code
      , TRIM(a.EOPIEC)                                                                                                                              AS edi_ord_hist_piece_count
      , TRIM(a.EOPORC)                                                                                                                              AS edi_ord_hist_collection_method_code
      , TRIM(a.EOMAN)                                                                                                                               AS edi_ord_hist_manifest_number
      , TRIM(a.EOCUBE)                                                                                                                              AS edi_ord_hist_load_volume
      --, a.EOSPEC
      , EOAPDT.date_key_pk														                                                                	AS edi_ord_hist_pickup_appt_date
	  , CASE 
            WHEN TRY_CAST(a.EOAPTM AS INT) IS NULL THEN NULL
			WHEN CONVERT(INT,a.EOAPTM) < 2400 
                AND RIGHT(CONVERT(INT,a.EOAPTM),2) < 60
				AND LEN(CONVERT(VARCHAR(4),CONVERT(INT,a.EOAPTM))) = 4 
			THEN TIMEFROMPARTS(LEFT(CONVERT(INT,a.EOAPTM),2),RIGHT(CONVERT(INT,a.EOAPTM),2),0,0,0)
			WHEN CONVERT(INT,a.EOAPTM) < 2400 
                AND RIGHT(CONVERT(INT,a.EOAPTM),2) < 60
				AND LEN(CONVERT(VARCHAR(4),CONVERT(INT,a.EOAPTM))) = 3 
			THEN TIMEFROMPARTS(LEFT(CONVERT(INT,a.EOAPTM),1),RIGHT(CONVERT(INT,a.EOAPTM),2),0,0,0)
			WHEN CONVERT(INT,a.EOAPTM) < 2400  
                AND RIGHT(CONVERT(INT,a.EOAPTM),2) < 60
				AND LEN(CONVERT(VARCHAR(4),CONVERT(INT,a.EOAPTM))) IN (1,2)
			THEN TIMEFROMPARTS(0,CONVERT(INT,a.EOAPTM),0,0,0)
			ELSE NULL END												                                                                            AS edi_ord_hist_pickup_appt_time    
      --, a.EOAPNM
      --, a.EOAPIN
      , EOADDT.date_key_pk														                                                                	AS edi_ord_hist_delivery_appt_date
	  , CASE 
            WHEN TRY_CAST(a.EOADTM AS INT) IS NULL THEN NULL
			WHEN CONVERT(INT,a.EOADTM) < 2400 
                AND RIGHT(CONVERT(INT,a.EOADTM),2) < 60
				AND LEN(CONVERT(VARCHAR(4),CONVERT(INT,a.EOADTM))) = 4 
			THEN TIMEFROMPARTS(LEFT(CONVERT(INT,a.EOADTM),2),RIGHT(CONVERT(INT,a.EOADTM),2),0,0,0)
			WHEN CONVERT(INT,a.EOADTM) < 2400 
                AND RIGHT(CONVERT(INT,a.EOADTM),2) < 60
				AND LEN(CONVERT(VARCHAR(4),CONVERT(INT,a.EOADTM))) = 3 
			THEN TIMEFROMPARTS(LEFT(CONVERT(INT,a.EOADTM),1),RIGHT(CONVERT(INT,a.EOADTM),2),0,0,0)
			WHEN CONVERT(INT,a.EOADTM) < 2400  
                AND RIGHT(CONVERT(INT,a.EOADTM),2) < 60
				AND LEN(CONVERT(VARCHAR(4),CONVERT(INT,a.EOADTM))) IN (1,2)
			THEN TIMEFROMPARTS(0,CONVERT(INT,a.EOADTM),0,0,0)
			ELSE NULL END												                                                                            AS edi_ord_hist_delivery_appt_time    
      --, a.EOADNM
      --, a.EOADIN
      , a.EOPREQ                                                                                                                                    AS edi_ord_hist_required_pallet_count
      , TRIM(a.EOCNSH)                                                                                                                              AS edi_ord_hist_consignee_ship_number
      , TRIM(a.EOPUSH)                                                                                                                              AS edi_ord_hist_pickup_ship_number
      --, a.EOARR
      --, a.EOCPIC
      --, a.EOCWGT
      , EOSHDT.date_key_pk														                                                                	AS edi_ord_hist_ship_date
	  , CASE 
            WHEN TRY_CAST(a.EOSHTM AS INT) IS NULL THEN NULL
			WHEN CONVERT(INT,a.EOSHTM) < 2400 
                AND RIGHT(CONVERT(INT,a.EOSHTM),2) < 60
				AND LEN(CONVERT(VARCHAR(4),CONVERT(INT,a.EOSHTM))) = 4 
			THEN TIMEFROMPARTS(LEFT(CONVERT(INT,a.EOSHTM),2),RIGHT(CONVERT(INT,a.EOSHTM),2),0,0,0)
			WHEN CONVERT(INT,a.EOSHTM) < 2400 
                AND RIGHT(CONVERT(INT,a.EOSHTM),2) < 60
				AND LEN(CONVERT(VARCHAR(4),CONVERT(INT,a.EOSHTM))) = 3 
			THEN TIMEFROMPARTS(LEFT(CONVERT(INT,a.EOSHTM),1),RIGHT(CONVERT(INT,a.EOSHTM),2),0,0,0)
			WHEN CONVERT(INT,a.EOSHTM) < 2400  
                AND RIGHT(CONVERT(INT,a.EOSHTM),2) < 60
				AND LEN(CONVERT(VARCHAR(4),CONVERT(INT,a.EOSHTM))) IN (1,2)
			THEN TIMEFROMPARTS(0,CONVERT(INT,a.EOSHTM),0,0,0)
			ELSE NULL END												                                                                            AS edi_ord_hist_ship_time    
      , a.EOTMPH                                                                                                                                    AS edi_ord_hist_order_temp_high
      , a.EOTMPL                                                                                                                                    AS edi_ord_hist_order_temp_low
      --, a.EOEQTY
      , TRIM(a.EOCO)                                                                                                                                AS edi_ord_hist_company_code
      , TRIM(a.EODV)                                                                                                                                AS edi_ord_hist_division_code
      --, a.EOTM
      , TRIM(a.EOSEL1)                                                                                                                              AS edi_ord_hist_seal_code
      --, a.EOSEL2
      , CASE TRIM(a.EOHAZM)
            WHEN 'Y' THEN 'TRUE'
            WHEN 'N' THEN 'FALSE'
            ELSE 'unknown' END                                                                                                                      AS has_hazardous_material
      , TRIM(a.EODLD)                                                                                                                               AS edi_ord_hist_driver_load_code
      , TRIM(a.EODULD)                                                                                                                              AS edi_ord_hist_driver_unload_code
      , TRIM(a.EOBBOC)                                                                                                                              AS edi_ord_hist_load_type
      , TRIM(a.EOJIT)                                                                                                                               AS edi_ord_hist_just_in_time_code
      , TRIM(a.EOAGNT)                                                                                                                              AS edi_ord_hist_agent_code
      , EOTNDT.date_key_pk														                                                                	AS edi_ord_hist_tender_date
	  , CASE 
            WHEN TRY_CAST(a.EOTNTM AS INT) IS NULL THEN NULL
			WHEN CONVERT(INT,a.EOTNTM) < 2400 
                AND RIGHT(CONVERT(INT,a.EOTNTM),2) < 60
				AND LEN(CONVERT(VARCHAR(4),CONVERT(INT,a.EOTNTM))) = 4 
			THEN TIMEFROMPARTS(LEFT(CONVERT(INT,a.EOTNTM),2),RIGHT(CONVERT(INT,a.EOTNTM),2),0,0,0)
			WHEN CONVERT(INT,a.EOTNTM) < 2400 
                AND RIGHT(CONVERT(INT,a.EOTNTM),2) < 60
				AND LEN(CONVERT(VARCHAR(4),CONVERT(INT,a.EOTNTM))) = 3 
			THEN TIMEFROMPARTS(LEFT(CONVERT(INT,a.EOTNTM),1),RIGHT(CONVERT(INT,a.EOTNTM),2),0,0,0)
			WHEN CONVERT(INT,a.EOTNTM) < 2400  
                AND RIGHT(CONVERT(INT,a.EOTNTM),2) < 60
				AND LEN(CONVERT(VARCHAR(4),CONVERT(INT,a.EOTNTM))) IN (1,2)
			THEN TIMEFROMPARTS(0,CONVERT(INT,a.EOTNTM),0,0,0)
			ELSE NULL END												                                                                            AS edi_ord_hist_tender_time    
	  , CASE 
            WHEN TRY_CAST(a.EORSTM AS INT) IS NULL THEN NULL
			WHEN CONVERT(INT,a.EORSTM) < 2400 
                AND RIGHT(CONVERT(INT,a.EORSTM),2) < 60
				AND LEN(CONVERT(VARCHAR(4),CONVERT(INT,a.EORSTM))) = 4 
			THEN TIMEFROMPARTS(LEFT(CONVERT(INT,a.EORSTM),2),RIGHT(CONVERT(INT,a.EORSTM),2),0,0,0)
			WHEN CONVERT(INT,a.EORSTM) < 2400 
                AND RIGHT(CONVERT(INT,a.EORSTM),2) < 60
				AND LEN(CONVERT(VARCHAR(4),CONVERT(INT,a.EORSTM))) = 3 
			THEN TIMEFROMPARTS(LEFT(CONVERT(INT,a.EORSTM),1),RIGHT(CONVERT(INT,a.EORSTM),2),0,0,0)
			WHEN CONVERT(INT,a.EORSTM) < 2400  
                AND RIGHT(CONVERT(INT,a.EORSTM),2) < 60
				AND LEN(CONVERT(VARCHAR(4),CONVERT(INT,a.EORSTM))) IN (1,2)
			THEN TIMEFROMPARTS(0,CONVERT(INT,a.EORSTM),0,0,0)
			ELSE NULL END												                                                                            AS edi_ord_hist_response_time    
      , TRIM(a.EOEDCD)                                                                                                                              AS edi_ord_hist_edi_customer_code
      , TRIM(a.EOUSER)                                                                                                                              AS edi_ord_hist_user_code
--INTO data_central_wh.silver.ibmi_edi_order_history
FROM data_central_lh.dbo.ibmi_edi_order_history_bronze a
LEFT JOIN gold.dim_date EODATE ON a.EODATE = EODATE.date_ordinal
LEFT JOIN gold.dim_date EOPDAT ON a.EOPDAT = EOPDAT.date_ordinal
LEFT JOIN gold.dim_date EODDAT ON a.EODDAT = EODDAT.date_ordinal
LEFT JOIN gold.dim_date EOAPDT ON a.EOAPDT = EOAPDT.date_ordinal
LEFT JOIN gold.dim_date EOADDT ON a.EOADDT = EOADDT.date_ordinal
LEFT JOIN gold.dim_date EOSHDT ON a.EOSHDT = EOSHDT.date_ordinal
LEFT JOIN gold.dim_date EOTNDT ON a.EOTNDT = EOTNDT.date_ordinal