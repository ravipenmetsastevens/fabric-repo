CREATE   PROCEDURE [dbo].[usp_ibmi_incr_order_silver_new]
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        BEGIN TRAN;

        /*========================================================
          Step 1: Prepare deduplicated source data (latest per ORODR)
        ========================================================*/
        IF OBJECT_ID('tempdb..#DedupedWithDates', 'U') IS NOT NULL DROP TABLE #DedupedWithDates;

        SELECT a.*,
               ORDATE.date_key_pk  AS ORDATE_key,
               ORPDAT.date_key_pk  AS ORPDAT_key,
               ORDDAT.date_key_pk  AS ORDDAT_key,
               ORAPDT.date_key_pk  AS ORAPDT_key,
               ORADDT.date_key_pk  AS ORADDT_key,
               ORUPDD.date_key_pk  AS ORUPDD_key,
               ORLCDT.date_key_pk  AS ORLCDT_key,
               ORECDT.date_key_pk  AS ORECDT_key,
               ORSHDT.date_key_pk  AS ORSHDT_key
        INTO #DedupedWithDates
        FROM (
            SELECT *,
                   ROW_NUMBER() OVER (
                       PARTITION BY ORODR
                       ORDER BY loadDate DESC, recordNumber DESC
                   ) AS rn
            FROM data_central_lh.dbo.ibmi_incr_order_bronze_new
        ) a
        LEFT JOIN gold.dim_date ORDATE ON a.ORDATE = ORDATE.date_ordinal
        LEFT JOIN gold.dim_date ORPDAT ON a.ORPDAT = ORPDAT.date_ordinal
        LEFT JOIN gold.dim_date ORDDAT ON a.ORDDAT = ORDDAT.date_ordinal
        LEFT JOIN gold.dim_date ORAPDT ON a.ORAPDT = ORAPDT.date_ordinal
        LEFT JOIN gold.dim_date ORADDT ON a.ORADDT = ORADDT.date_ordinal
        LEFT JOIN gold.dim_date ORUPDD ON a.ORUPDD = ORUPDD.date_ordinal
        LEFT JOIN gold.dim_date ORLCDT ON a.ORLCDT = ORLCDT.date_ordinal
        LEFT JOIN gold.dim_date ORECDT ON a.ORECDT = ORECDT.date_ordinal
        LEFT JOIN gold.dim_date ORSHDT ON a.ORSHDT = ORSHDT.date_ordinal
        WHERE a.rn = 1;

        /*========================================================
          Step 1.5 (NEW): Delete from target ONLY for DISTINCT order_load_number in this run
        ========================================================*/
        IF OBJECT_ID('tempdb..#OrdersToDelete', 'U') IS NOT NULL DROP TABLE #OrdersToDelete;

        SELECT DISTINCT TRIM(ORODR) AS order_load_number
        INTO #OrdersToDelete
        FROM #DedupedWithDates
        WHERE ORODR IS NOT NULL;

        DELETE TGT
        FROM silver.ibmi_incr_order_new TGT
        JOIN #OrdersToDelete D
          ON TGT.order_load_number = D.order_load_number;

        /*========================================================
          Step 2: UPDATE existing (will usually be 0 after delete; kept for consistency)
        ========================================================*/
        UPDATE TGT
        SET
            order_origin_area_code = TRIM(SRC.ORARA),
            order_status_code = TRIM(SRC.ORSTAT),
            order_date = SRC.ORDATE_key,
            order_time = TRIM(SRC.ORTIME),
            order_customer_code = TRIM(SRC.ORCUST),
            order_consignee_code = TRIM(SRC.ORCONS),
            order_billto_code = TRIM(SRC.ORBILL),
            order_loadat_code = TRIM(SRC.ORLDAT),
            order_early_pickup_date = SRC.ORPDAT_key,
            order_early_pickup_time = TRIM(SRC.ORPTIM),
            is_pickup_required = CASE TRIM(SRC.ORRPIK) WHEN 'Y' THEN 'TRUE' WHEN 'N' THEN 'FALSE' ELSE 'unknown' END,
            order_early_delivery_date = SRC.ORDDAT_key,
            order_early_delivery_time = TRIM(SRC.ORDTIM),
            is_delivery_required = CASE TRIM(SRC.ORRDEL) WHEN 'Y' THEN 'TRUE' WHEN 'N' THEN 'FALSE' ELSE 'unknown' END,
            order_commodity_code = TRIM(SRC.ORCOMC),
            order_commodity_description = TRIM(SRC.ORCOMD),
            order_creation_initials = TRIM(SRC.ORINIT),
            order_customer_phone_area_code = CONVERT(VARCHAR, SRC.ORCAC),
            order_customer_phone_number = CONVERT(VARCHAR, SRC.ORCPHN),
            order_consignee_phone_area_code = CONVERT(VARCHAR, SRC.ORRAC),
            order_consignee_phone_number = CONVERT(VARCHAR, SRC.ORRPHN),
            order_load_weight = SRC.ORWGT,
            order_pallet_count = TRIM(SRC.ORPLLT),
            order_origin_city_code = TRIM(SRC.OROCTY),
            order_origin_state = TRIM(SRC.OROST),
            order_origin_bea_code = SRC.OROBEA,
            order_origin_gu_code = TRIM(SRC.OROGU),
            order_origin_city_short_name = TRIM(SRC.OROSNM),
            order_destination_city_code = TRIM(SRC.ORDCTY),
            order_destination_state = TRIM(SRC.ORDST),
            order_destination_bea_code = SRC.ORDBEA,
            order_destination_gu_code = TRIM(SRC.ORDGU),
            order_destination_city_short_name = TRIM(SRC.ORDSNM),
            order_miles_billable = SRC.ORMILE,
            order_load_type = TRIM(SRC.ORRST),
            order_stop_count = TRIM(SRC.ORSTP),
            order_dispatch_count = TRIM(SRC.OR_DSP),
            order_preload_trailer = TRIM(SRC.ORTRLR),
            order_revenue_estimation = SRC.ORESTR,
            order_new_origin_area_code = TRIM(SRC.ORNWPK),
            order_destination_area_code = TRIM(SRC.ORINAR),
            order_bill_of_lading = TRIM(SRC.ORCSH),
            order_purchase_order = TRIM(SRC.ORCNS),
            order_pick_up_code = TRIM(SRC.ORORBY),
            order_piece_count = TRIM(SRC.ORPIEC),
            order_collection_method_code = TRIM(SRC.ORPORC),
            order_load_volume = TRIM(SRC.ORCUBE),
            order_message = TRIM(SRC.ORSPEC),
            order_late_pickup_date = SRC.ORAPDT_key,
            order_late_pickup_time = TRIM(SRC.ORAPTM),
            order_late_delivery_date = SRC.ORADDT_key,
            order_late_delivery_time = TRIM(SRC.ORADTM),
            order_required_pallet_count = SRC.ORPREQ,
            order_ship_date = SRC.ORSHDT_key,
            order_ship_time = TRIM(SRC.ORSHTM),
            order_temp_high = SRC.ORTMPH,
            order_temp_low = SRC.ORTMPL,
            order_last_update_date = SRC.ORUPDD_key,
            order_last_update_time = TRIM(SRC.ORUPDT),
            order_last_update_initials = TRIM(SRC.ORUPDI),
            order_company_code = TRIM(SRC.ORCO),
            order_division_code = TRIM(SRC.ORDV),
            order_lane_code = TRIM(SRC.ORTM),
            order_seal_code = TRIM(SRC.ORSEL1),
            order_service_failure_code = TRIM(SRC.ORSERV),
            order_driver_commit_flag = TRIM(SRC.ORCMTM),
            is_edi_load = TRIM(SRC.OREDI),
            is_edi_stats_complete = TRIM(SRC.OREDIC),
            is_driver_loaded = TRIM(SRC.ORDLD),
            is_driver_unloaded = TRIM(SRC.ORDULD),
            is_delivery_receipt_signed = TRIM(SRC.ORSDR),
            order_delivery_receipt_req = TRIM(SRC.ORSDRR),
            order_edi_message_billing_flag = TRIM(SRC.OREDMB),
            is_load_just_in_time = TRIM(SRC.ORJIT),
            order_edi_billing_code = TRIM(SRC.OREDFB),
            is_edi_inbound_or_outbound = CASE TRIM(SRC.OREDIO) WHEN 'I' THEN 'INBOUND' WHEN 'O' THEN 'OUTBOUND' ELSE 'unknown' END,
            order_current_city_code = TRIM(SRC.ORCCTY),
            order_current_state = TRIM(SRC.ORCST),
            order_loaded_call_date = SRC.ORLCDT_key,
            order_empty_call_date = SRC.ORECDT_key,
            order_trailer_length = SRC.ORLGT,
            order_trailer_height = SRC.ORHGT,
            has_permit = TRIM(SRC.ORPMTF),
            has_permit_complete = TRIM(SRC.ORPCOM),
            order_latitude = SRC.ORLAT,
            order_longitude = SRC.ORLONG,
            is_tentitive_load = TRIM(SRC.ORTEN),
            order_hours_under_dispatch = SRC.ORHRS,
            order_origin_zone_code = TRIM(SRC.OROZN),
            order_origin_region_code = TRIM(SRC.ORORG),
            order_destination_zone_code = TRIM(SRC.ORDZN),
            order_destination_region_code = TRIM(SRC.ORDRG),
            is_to_be_rated = TRIM(SRC.ORTBRT),
            has_new_gu_code = TRIM(SRC.ORNGU),
            is_exclude_from_model = TRIM(SRC.OREFM),
            order_carry_over_flag = TRIM(SRC.ORCARF),
            order_truck_type_requirement_code = TRIM(SRC.ORUTYP),
            order_delivery_code = TRIM(SRC.ORFIL)
        FROM silver.ibmi_incr_order_new TGT
        JOIN #DedupedWithDates SRC
          ON TGT.order_load_number = TRIM(SRC.ORODR);

        /*========================================================
          Step 3: INSERT new records not present in silver
        ========================================================*/
        INSERT INTO silver.ibmi_incr_order_new (
            order_origin_area_code,
            order_load_number,
            order_status_code,
            order_date,
            order_time,
            order_customer_code,
            order_consignee_code,
            order_billto_code,
            order_loadat_code,
            order_early_pickup_date,
            order_early_pickup_time,
            is_pickup_required,
            order_early_delivery_date,
            order_early_delivery_time,
            is_delivery_required,
            order_commodity_code,
            order_commodity_description,
            order_creation_initials,
            order_customer_phone_area_code,
            order_customer_phone_number,
            order_consignee_phone_area_code,
            order_consignee_phone_number,
            order_load_weight,
            order_pallet_count,
            order_origin_city_code,
            order_origin_state,
            order_origin_bea_code,
            order_origin_gu_code,
            order_origin_city_short_name,
            order_destination_city_code,
            order_destination_state,
            order_destination_bea_code,
            order_destination_gu_code,
            order_destination_city_short_name,
            order_miles_billable,
            order_load_type,
            order_stop_count,
            order_dispatch_count,
            order_preload_trailer,
            order_revenue_estimation,
            order_new_origin_area_code,
            order_destination_area_code,
            order_bill_of_lading,
            order_purchase_order,
            order_pick_up_code,
            order_piece_count,
            order_collection_method_code,
            order_load_volume,
            order_message,
            order_late_pickup_date,
            order_late_pickup_time,
            order_late_delivery_date,
            order_late_delivery_time,
            order_required_pallet_count,
            order_ship_date,
            order_ship_time,
            order_temp_high,
            order_temp_low,
            order_last_update_date,
            order_last_update_time,
            order_last_update_initials,
            order_company_code,
            order_division_code,
            order_lane_code,
            order_seal_code,
            order_service_failure_code,
            order_driver_commit_flag,
            is_edi_load,
            is_edi_stats_complete,
            is_driver_loaded,
            is_driver_unloaded,
            is_delivery_receipt_signed,
            order_delivery_receipt_req,
            order_edi_message_billing_flag,
            is_load_just_in_time,
            order_edi_billing_code,
            is_edi_inbound_or_outbound,
            order_current_city_code,
            order_current_state,
            order_loaded_call_date,
            order_empty_call_date,
            order_trailer_length,
            order_trailer_height,
            has_permit,
            has_permit_complete,
            order_latitude,
            order_longitude,
            is_tentitive_load,
            order_hours_under_dispatch,
            order_origin_zone_code,
            order_origin_region_code,
            order_destination_zone_code,
            order_destination_region_code,
            is_to_be_rated,
            has_new_gu_code,
            is_exclude_from_model,
            order_carry_over_flag,
            order_truck_type_requirement_code,
            order_delivery_code
        )
        SELECT
            TRIM(SRC.ORARA),
            TRIM(SRC.ORODR),
            TRIM(SRC.ORSTAT),
            SRC.ORDATE_key,
            TRIM(SRC.ORTIME),
            TRIM(SRC.ORCUST),
            TRIM(SRC.ORCONS),
            TRIM(SRC.ORBILL),
            TRIM(SRC.ORLDAT),
            SRC.ORPDAT_key,
            TRIM(SRC.ORPTIM),
            CASE TRIM(SRC.ORRPIK) WHEN 'Y' THEN 'TRUE' WHEN 'N' THEN 'FALSE' ELSE 'unknown' END,
            SRC.ORDDAT_key,
            TRIM(SRC.ORDTIM),
            CASE TRIM(SRC.ORRDEL) WHEN 'Y' THEN 'TRUE' WHEN 'N' THEN 'FALSE' ELSE 'unknown' END,
            TRIM(SRC.ORCOMC),
            TRIM(SRC.ORCOMD),
            TRIM(SRC.ORINIT),
            CONVERT(VARCHAR, SRC.ORCAC),
            CONVERT(VARCHAR, SRC.ORCPHN),
            CONVERT(VARCHAR, SRC.ORRAC),
            CONVERT(VARCHAR, SRC.ORRPHN),
            SRC.ORWGT,
            TRIM(SRC.ORPLLT),
            TRIM(SRC.OROCTY),
            TRIM(SRC.OROST),
            SRC.OROBEA,
            TRIM(SRC.OROGU),
            TRIM(SRC.OROSNM),
            TRIM(SRC.ORDCTY),
            TRIM(SRC.ORDST),
            SRC.ORDBEA,
            TRIM(SRC.ORDGU),
            TRIM(SRC.ORDSNM),
            SRC.ORMILE,
            TRIM(SRC.ORRST),
            TRIM(SRC.ORSTP),
            TRIM(SRC.OR_DSP),
            TRIM(SRC.ORTRLR),
            SRC.ORESTR,
            TRIM(SRC.ORNWPK),
            TRIM(SRC.ORINAR),
            TRIM(SRC.ORCSH),
            TRIM(SRC.ORCNS),
            TRIM(SRC.ORORBY),
            TRIM(SRC.ORPIEC),
            TRIM(SRC.ORPORC),
            TRIM(SRC.ORCUBE),
            TRIM(SRC.ORSPEC),
            SRC.ORAPDT_key,
            TRIM(SRC.ORAPTM),
            SRC.ORADDT_key,
            TRIM(SRC.ORADTM),
            SRC.ORPREQ,
            SRC.ORSHDT_key,
            TRIM(SRC.ORSHTM),
            SRC.ORTMPH,
            SRC.ORTMPL,
            SRC.ORUPDD_key,
            TRIM(SRC.ORUPDT),
            TRIM(SRC.ORUPDI),
            TRIM(SRC.ORCO),
            TRIM(SRC.ORDV),
            TRIM(SRC.ORTM),
            TRIM(SRC.ORSEL1),
            TRIM(SRC.ORSERV),
            TRIM(SRC.ORCMTM),
            TRIM(SRC.OREDI),
            TRIM(SRC.OREDIC),
            TRIM(SRC.ORDLD),
            TRIM(SRC.ORDULD),
            TRIM(SRC.ORSDR),
            TRIM(SRC.ORSDRR),
            TRIM(SRC.OREDMB),
            TRIM(SRC.ORJIT),
            TRIM(SRC.OREDFB),
            CASE TRIM(SRC.OREDIO) WHEN 'I' THEN 'INBOUND' WHEN 'O' THEN 'OUTBOUND' ELSE 'unknown' END,
            TRIM(SRC.ORCCTY),
            TRIM(SRC.ORCST),
            SRC.ORLCDT_key,
            SRC.ORECDT_key,
            SRC.ORLGT,
            SRC.ORHGT,
            TRIM(SRC.ORPMTF),
            TRIM(SRC.ORPCOM),
            SRC.ORLAT,
            SRC.ORLONG,
            TRIM(SRC.ORTEN),
            SRC.ORHRS,
            TRIM(SRC.OROZN),
            TRIM(SRC.ORORG),
            TRIM(SRC.ORDZN),
            TRIM(SRC.ORDRG),
            TRIM(SRC.ORTBRT),
            TRIM(SRC.ORNGU),
            TRIM(SRC.OREFM),
            TRIM(SRC.ORCARF),
            TRIM(SRC.ORUTYP),
            TRIM(SRC.ORFIL)
        FROM #DedupedWithDates SRC
        WHERE NOT EXISTS (
            SELECT 1
            FROM silver.ibmi_incr_order_new TGT
            WHERE TGT.order_load_number = TRIM(SRC.ORODR)
        );

        DROP TABLE #DedupedWithDates;
        DROP TABLE #OrdersToDelete;

        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;

        DECLARE @ErrMsg NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR('usp_ibmi_incr_order_silver_new failed. %s', 16, 1, @ErrMsg) WITH NOWAIT;
    END CATCH
END