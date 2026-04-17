CREATE   PROCEDURE [dbo].[usp_ibmi_incr_service_exceptions_silver]
AS
BEGIN
    SET NOCOUNT ON;

    /*==============================================================
      STEP 1: Deduplicate the bronze source
      Keys: TRIM(a.[SEORD#]) AS serv_exc_load_number, a.[SESEQ#] AS serv_exc_sequence_number
    ==============================================================*/
    IF OBJECT_ID('tempdb..#DedupedServiceExceptions') IS NOT NULL 
        DROP TABLE #DedupedServiceExceptions;

    SELECT *
    INTO #DedupedServiceExceptions
    FROM (
        SELECT *,
               ROW_NUMBER() OVER (
                    PARTITION BY TRIM([SEORD#]), [SESEQ#]
                    ORDER BY loadDate DESC, recordNumber DESC
               ) AS rn
        FROM data_central_lh.dbo.ibmi_incr_service_exceptions_bronze
    ) a
    WHERE rn = 1;

    /*==============================================================
      STEP 2: Update existing rows in silver.ibmi_service_exceptions
    ==============================================================*/
    UPDATE TGT
    SET 
        serv_exc_type = CASE TRIM(SRC.SETYPE)
                            WHEN 'AC' THEN 'Appointment Change'
                            WHEN 'LA' THEN 'Late Arrival'
                            WHEN 'ME' THEN 'Manual Entry'
                            WHEN 'LU' THEN 'Low Utilization'
                            WHEN 'RP' THEN 'Repower'
                            WHEN 'DL' THEN 'Driver Late'
                            WHEN 'LP' THEN 'Late Preplan'
                            ELSE 'unknown' END,
        serv_exc_dispatch = TRIM(SRC.SEDISP),
        serv_exc_order_status_code = TRIM(SRC.SESTAT),
        serv_exc_truck_number = TRIM(SRC.SEUNIT),
        serv_exc_trailer_number = TRIM(SRC.SETRLR),
        serv_exc_seat_1_driver_code = TRIM(SRC.SEDRV1),
        serv_exc_dm_code = TRIM(SRC.SEDM),
        serv_exc_dmol_code = TRIM(SRC.SEFM),
        serv_exc_csr_code = TRIM(SRC.SECSR),
        serv_exc_stop_number = SRC.[SESTP#],
        is_customer_reportable = CASE TRIM(SRC.SERPT)
                                     WHEN 'Y' THEN 'TRUE'
                                     WHEN 'N' THEN 'FALSE'
                                     ELSE 'unknown' END,
        has_csr_signoff = CASE TRIM(SRC.SESOCSR)
                              WHEN 'Y' THEN 'TRUE'
                              WHEN 'N' THEN 'FALSE'
                              ELSE 'unknown' END,
        has_dm_signoff = CASE TRIM(SRC.SESODM)
                             WHEN 'Y' THEN 'TRUE'
                             WHEN 'N' THEN 'FALSE'
                             ELSE 'unknown' END,
        is_customer_responsible = CASE TRIM(SRC.SERPCU) WHEN 'X' THEN 'TRUE' ELSE 'FALSE' END,
        is_shipper_responsible = CASE TRIM(SRC.SERPSH) WHEN 'X' THEN 'TRUE' ELSE 'FALSE' END,
        is_loadat_responsible = CASE TRIM(SRC.SERPLD) WHEN 'X' THEN 'TRUE' ELSE 'FALSE' END,
        is_consignee_responsible = CASE TRIM(SRC.SERPCN) WHEN 'X' THEN 'TRUE' ELSE 'FALSE' END,
        is_driver_responsible = CASE TRIM(SRC.SERPDR) WHEN 'X' THEN 'TRUE' ELSE 'FALSE' END,
        is_equipment_responsible = CASE TRIM(SRC.SERPEQ) WHEN 'X' THEN 'TRUE' ELSE 'FALSE' END,
        is_weather_responsible = CASE TRIM(SRC.SERPWE) WHEN 'X' THEN 'TRUE' ELSE 'FALSE' END,
        is_sales_responsible = CASE TRIM(SRC.SERPSL) WHEN 'X' THEN 'TRUE' ELSE 'FALSE' END,
        is_csr_responsible = CASE TRIM(SRC.SERPCS) WHEN 'X' THEN 'TRUE' ELSE 'FALSE' END,
        is_planner_responsible = CASE TRIM(SRC.SERPPL) WHEN 'X' THEN 'TRUE' ELSE 'FALSE' END,
        is_dm_responsible = CASE TRIM(SRC.SERPDM) WHEN 'X' THEN 'TRUE' ELSE 'FALSE' END,
        is_brokerage_responsible = CASE TRIM(SRC.SERPBR) WHEN 'X' THEN 'TRUE' ELSE 'FALSE' END,
        serv_exc_last_update_user_code = TRIM(SRC.SEUPDI),
        is_no_charge = CASE TRIM(SRC.SERPNC) WHEN 'X' THEN 'TRUE' ELSE 'FALSE' END,
        is_rail_responsible = CASE TRIM(SRC.SERPRL) WHEN 'X' THEN 'TRUE' ELSE 'FALSE' END,
        has_planner_signoff = CASE TRIM(SRC.SESOUSR)
                                   WHEN 'Y' THEN 'TRUE'
                                   WHEN 'N' THEN 'FALSE'
                                   ELSE 'unknown' END,
        serv_exc_planner_code = TRIM(SRC.SEPLAN),
        serv_exc_severity = CASE TRIM(SRC.SESEV)
                                WHEN 'E' THEN 'Exception'
                                WHEN 'F' THEN 'Failure'
                                ELSE 'unknown' END,
        serv_exc_appt_change_reason_code = TRIM(SRC.SEACRSN),
        is_driver_reportable = CASE TRIM(SRC.SERPTDR)
                                   WHEN 'Y' THEN 'TRUE'
                                   WHEN 'N' THEN 'FALSE'
                                   ELSE 'unknown' END,
        serv_exc_exception_status_code = TRIM(SRC.SESESTAT),
        serv_exc_regional_manager_code = TRIM(SRC.SERM),
        is_road_condition_responsible = CASE TRIM(SRC.SERPRC) WHEN 'X' THEN 'TRUE' ELSE 'FALSE' END,
        serv_exc_region_code = TRIM(SRC.SEREGN)
    FROM silver.ibmi_service_exceptions TGT
    JOIN #DedupedServiceExceptions SRC
        ON TGT.serv_exc_load_number = TRIM(SRC.[SEORD#])
       AND TGT.serv_exc_sequence_number = SRC.[SESEQ#];

    /*==============================================================
      STEP 3: Insert new rows
    ==============================================================*/
    INSERT INTO silver.ibmi_service_exceptions (
        serv_exc_load_number,
        serv_exc_sequence_number,
        serv_exc_type,
        serv_exc_dispatch,
        serv_exc_order_status_code,
        serv_exc_truck_number,
        serv_exc_trailer_number,
        serv_exc_seat_1_driver_code,
        serv_exc_dm_code,
        serv_exc_dmol_code,
        serv_exc_csr_code,
        serv_exc_stop_number,
        is_customer_reportable,
        has_csr_signoff,
        has_dm_signoff,
        is_customer_responsible,
        is_shipper_responsible,
        is_loadat_responsible,
        is_consignee_responsible,
        is_driver_responsible,
        is_equipment_responsible,
        is_weather_responsible,
        is_sales_responsible,
        is_csr_responsible,
        is_planner_responsible,
        is_dm_responsible,
        is_brokerage_responsible,
        serv_exc_last_update_user_code,
        is_no_charge,
        is_rail_responsible,
        has_planner_signoff,
        serv_exc_planner_code,
        serv_exc_severity,
        serv_exc_appt_change_reason_code,
        is_driver_reportable,
        serv_exc_exception_status_code,
        serv_exc_regional_manager_code,
        is_road_condition_responsible,
        serv_exc_region_code
    )
    SELECT
        TRIM(SRC.[SEORD#]),
        SRC.[SESEQ#],
        CASE TRIM(SRC.SETYPE)
            WHEN 'AC' THEN 'Appointment Change'
            WHEN 'LA' THEN 'Late Arrival'
            WHEN 'ME' THEN 'Manual Entry'
            WHEN 'LU' THEN 'Low Utilization'
            WHEN 'RP' THEN 'Repower'
            WHEN 'DL' THEN 'Driver Late'
            WHEN 'LP' THEN 'Late Preplan'
            ELSE 'unknown' END,
        TRIM(SRC.SEDISP),
        TRIM(SRC.SESTAT),
        TRIM(SRC.SEUNIT),
        TRIM(SRC.SETRLR),
        TRIM(SRC.SEDRV1),
        TRIM(SRC.SEDM),
        TRIM(SRC.SEFM),
        TRIM(SRC.SECSR),
        SRC.[SESTP#],
        CASE TRIM(SRC.SERPT)
            WHEN 'Y' THEN 'TRUE' WHEN 'N' THEN 'FALSE' ELSE 'unknown' END,
        CASE TRIM(SRC.SESOCSR)
            WHEN 'Y' THEN 'TRUE' WHEN 'N' THEN 'FALSE' ELSE 'unknown' END,
        CASE TRIM(SRC.SESODM)
            WHEN 'Y' THEN 'TRUE' WHEN 'N' THEN 'FALSE' ELSE 'unknown' END,
        CASE TRIM(SRC.SERPCU) WHEN 'X' THEN 'TRUE' ELSE 'FALSE' END,
        CASE TRIM(SRC.SERPSH) WHEN 'X' THEN 'TRUE' ELSE 'FALSE' END,
        CASE TRIM(SRC.SERPLD) WHEN 'X' THEN 'TRUE' ELSE 'FALSE' END,
        CASE TRIM(SRC.SERPCN) WHEN 'X' THEN 'TRUE' ELSE 'FALSE' END,
        CASE TRIM(SRC.SERPDR) WHEN 'X' THEN 'TRUE' ELSE 'FALSE' END,
        CASE TRIM(SRC.SERPEQ) WHEN 'X' THEN 'TRUE' ELSE 'FALSE' END,
        CASE TRIM(SRC.SERPWE) WHEN 'X' THEN 'TRUE' ELSE 'FALSE' END,
        CASE TRIM(SRC.SERPSL) WHEN 'X' THEN 'TRUE' ELSE 'FALSE' END,
        CASE TRIM(SRC.SERPCS) WHEN 'X' THEN 'TRUE' ELSE 'FALSE' END,
        CASE TRIM(SRC.SERPPL) WHEN 'X' THEN 'TRUE' ELSE 'FALSE' END,
        CASE TRIM(SRC.SERPDM) WHEN 'X' THEN 'TRUE' ELSE 'FALSE' END,
        CASE TRIM(SRC.SERPBR) WHEN 'X' THEN 'TRUE' ELSE 'FALSE' END,
        TRIM(SRC.SEUPDI),
        CASE TRIM(SRC.SERPNC) WHEN 'X' THEN 'TRUE' ELSE 'FALSE' END,
        CASE TRIM(SRC.SERPRL) WHEN 'X' THEN 'TRUE' ELSE 'FALSE' END,
        CASE TRIM(SRC.SESOUSR)
            WHEN 'Y' THEN 'TRUE' WHEN 'N' THEN 'FALSE' ELSE 'unknown' END,
        TRIM(SRC.SEPLAN),
        CASE TRIM(SRC.SESEV)
            WHEN 'E' THEN 'Exception' WHEN 'F' THEN 'Failure' ELSE 'unknown' END,
        TRIM(SRC.SEACRSN),
        CASE TRIM(SRC.SERPTDR)
            WHEN 'Y' THEN 'TRUE' WHEN 'N' THEN 'FALSE' ELSE 'unknown' END,
        TRIM(SRC.SESESTAT),
        TRIM(SRC.SERM),
        CASE TRIM(SRC.SERPRC) WHEN 'X' THEN 'TRUE' ELSE 'FALSE' END,
        TRIM(SRC.SEREGN)
    FROM #DedupedServiceExceptions SRC
    WHERE NOT EXISTS (
        SELECT 1 FROM silver.ibmi_service_exceptions TGT
        WHERE TGT.serv_exc_load_number = TRIM(SRC.[SEORD#])
          AND TGT.serv_exc_sequence_number = SRC.[SESEQ#]
    );

    DROP TABLE #DedupedServiceExceptions;
END;