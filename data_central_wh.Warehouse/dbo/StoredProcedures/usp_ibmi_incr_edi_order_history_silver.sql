CREATE   PROCEDURE [dbo].[usp_ibmi_incr_edi_order_history_silver]
AS
BEGIN
    SET NOCOUNT ON;

    IF OBJECT_ID('tempdb..#DedupedEdiOrderHist') IS NOT NULL 
        DROP TABLE #DedupedEdiOrderHist;

    SELECT *
    INTO #DedupedEdiOrderHist
    FROM (
        SELECT *,
               ROW_NUMBER() OVER (
                    PARTITION BY 
                        TRIM(CAST(EOODR AS VARCHAR(50))), 
                        TRIM(CAST(EOEDCD AS VARCHAR(50)))
                    ORDER BY loadDate DESC, recordNumber DESC
               ) AS rn
        FROM data_central_lh.dbo.ibmi_incr_edi_order_history_bronze
    ) a
    WHERE rn = 1;

    -- 🔄 UPDATE existing records
    UPDATE TGT
    SET 
        edi_ord_hist_status_code = TRIM(CAST(SRC.EOSTAT AS VARCHAR(10))),
        edi_ord_hist_order_date = EODATE.date_key_pk,
        edi_ord_hist_pickup_date = EOPDAT.date_key_pk,
        edi_ord_hist_delivery_date = EODDAT.date_key_pk,
        edi_ord_hist_ship_date = EOSHDT.date_key_pk,
        edi_ord_hist_tender_date = EOTNDT.date_key_pk,
        edi_ord_hist_order_time =
            CASE 
                WHEN TRY_CONVERT(INT, SRC.EOTIME) BETWEEN 0 AND 2359
                     AND LEN(LTRIM(RTRIM(CONVERT(VARCHAR(4), TRY_CONVERT(INT, SRC.EOTIME))))) IN (3,4)
                THEN TIMEFROMPARTS(
                        LEFT(RIGHT('0000' + CONVERT(VARCHAR(4), TRY_CONVERT(INT, SRC.EOTIME)), 4), 2),
                        RIGHT(RIGHT('0000' + CONVERT(VARCHAR(4), TRY_CONVERT(INT, SRC.EOTIME)), 4), 2),
                        0,0,0)
                ELSE NULL END,
        edi_ord_hist_tender_time =
            CASE 
                WHEN TRY_CONVERT(INT, SRC.EOTNTM) BETWEEN 0 AND 2359
                     AND LEN(LTRIM(RTRIM(CONVERT(VARCHAR(4), TRY_CONVERT(INT, SRC.EOTNTM))))) IN (3,4)
                THEN TIMEFROMPARTS(
                        LEFT(RIGHT('0000' + CONVERT(VARCHAR(4), TRY_CONVERT(INT, SRC.EOTNTM)), 4), 2),
                        RIGHT(RIGHT('0000' + CONVERT(VARCHAR(4), TRY_CONVERT(INT, SRC.EOTNTM)), 4), 2),
                        0,0,0)
                ELSE NULL END,
        edi_ord_hist_pickup_time =
            CASE 
                WHEN TRY_CONVERT(INT, SRC.EOPTIM) BETWEEN 0 AND 2359
                     AND LEN(LTRIM(RTRIM(CONVERT(VARCHAR(4), TRY_CONVERT(INT, SRC.EOPTIM))))) IN (3,4)
                THEN TIMEFROMPARTS(
                        LEFT(RIGHT('0000' + CONVERT(VARCHAR(4), TRY_CONVERT(INT, SRC.EOPTIM)), 4), 2),
                        RIGHT(RIGHT('0000' + CONVERT(VARCHAR(4), TRY_CONVERT(INT, SRC.EOPTIM)), 4), 2),
                        0,0,0)
                ELSE NULL END,
        edi_ord_hist_delivery_time =
            CASE 
                WHEN TRY_CONVERT(INT, SRC.EODTIM) BETWEEN 0 AND 2359
                     AND LEN(LTRIM(RTRIM(CONVERT(VARCHAR(4), TRY_CONVERT(INT, SRC.EODTIM))))) IN (3,4)
                THEN TIMEFROMPARTS(
                        LEFT(RIGHT('0000' + CONVERT(VARCHAR(4), TRY_CONVERT(INT, SRC.EODTIM)), 4), 2),
                        RIGHT(RIGHT('0000' + CONVERT(VARCHAR(4), TRY_CONVERT(INT, SRC.EODTIM)), 4), 2),
                        0,0,0)
                ELSE NULL END,
        edi_ord_hist_ship_time =
            CASE 
                WHEN TRY_CONVERT(INT, SRC.EOSHTM) BETWEEN 0 AND 2359
                     AND LEN(LTRIM(RTRIM(CONVERT(VARCHAR(4), TRY_CONVERT(INT, SRC.EOSHTM))))) IN (3,4)
                THEN TIMEFROMPARTS(
                        LEFT(RIGHT('0000' + CONVERT(VARCHAR(4), TRY_CONVERT(INT, SRC.EOSHTM)), 4), 2),
                        RIGHT(RIGHT('0000' + CONVERT(VARCHAR(4), TRY_CONVERT(INT, SRC.EOSHTM)), 4), 2),
                        0,0,0)
                ELSE NULL END,
        is_pickup_required = CASE TRIM(CAST(SRC.EORPIK AS VARCHAR(5)))
                                WHEN 'Y' THEN 'TRUE'
                                WHEN 'N' THEN 'FALSE'
                                ELSE 'unknown' END,
        is_delivery_required = CASE TRIM(CAST(SRC.EORDEL AS VARCHAR(5)))
                                WHEN 'Y' THEN 'TRUE'
                                WHEN 'N' THEN 'FALSE'
                                ELSE 'unknown' END,
        has_hazardous_material = CASE TRIM(CAST(SRC.EOHAZM AS VARCHAR(5)))
                                    WHEN 'Y' THEN 'TRUE'
                                    WHEN 'N' THEN 'FALSE'
                                    ELSE 'unknown' END,
        edi_ord_hist_bill_amount = SRC.EOBAMT,
        edi_ord_hist_total_amount = SRC.EOTAMT,
        edi_ord_hist_miles_billable = SRC.EOMILE
    FROM silver.ibmi_edi_order_history AS TGT
    JOIN #DedupedEdiOrderHist AS SRC
        ON TGT.edi_ord_hist_customer_order = TRIM(CAST(SRC.EOODR AS VARCHAR(50)))
       AND TGT.edi_ord_hist_edi_customer_code = TRIM(CAST(SRC.EOEDCD AS VARCHAR(50)))
    LEFT JOIN gold.dim_date EODATE ON SRC.EODATE = EODATE.date_ordinal
    LEFT JOIN gold.dim_date EOPDAT ON SRC.EOPDAT = EOPDAT.date_ordinal
    LEFT JOIN gold.dim_date EODDAT ON SRC.EODDAT = EODDAT.date_ordinal
    LEFT JOIN gold.dim_date EOSHDT ON SRC.EOSHDT = EOSHDT.date_ordinal
    LEFT JOIN gold.dim_date EOTNDT ON SRC.EOTNDT = EOTNDT.date_ordinal;

    -- 🆕 INSERT new records
    INSERT INTO silver.ibmi_edi_order_history (
        edi_ord_hist_origin_area_code,
        edi_ord_hist_customer_order,
        edi_ord_hist_status_code,
        edi_ord_hist_order_date,
        edi_ord_hist_order_time,
        edi_ord_hist_pickup_date,
        edi_ord_hist_pickup_time,
        edi_ord_hist_delivery_date,
        edi_ord_hist_delivery_time,
        edi_ord_hist_ship_date,
        edi_ord_hist_ship_time,
        edi_ord_hist_tender_date,
        edi_ord_hist_tender_time,
        is_pickup_required,
        is_delivery_required,
        has_hazardous_material,
        edi_ord_hist_bill_amount,
        edi_ord_hist_total_amount,
        edi_ord_hist_miles_billable,
        edi_ord_hist_edi_customer_code,
        edi_ord_hist_user_code
    )
    SELECT 
        TRIM(CAST(SRC.EOARA AS VARCHAR(10))),
        TRIM(CAST(SRC.EOODR AS VARCHAR(50))),
        TRIM(CAST(SRC.EOSTAT AS VARCHAR(10))),
        EODATE.date_key_pk,
        CASE 
            WHEN TRY_CONVERT(INT, SRC.EOTIME) BETWEEN 0 AND 2359
                 AND LEN(LTRIM(RTRIM(CONVERT(VARCHAR(4), TRY_CONVERT(INT, SRC.EOTIME))))) IN (3,4)
            THEN TIMEFROMPARTS(
                    LEFT(RIGHT('0000' + CONVERT(VARCHAR(4), TRY_CONVERT(INT, SRC.EOTIME)), 4), 2),
                    RIGHT(RIGHT('0000' + CONVERT(VARCHAR(4), TRY_CONVERT(INT, SRC.EOTIME)), 4), 2),
                    0,0,0)
            ELSE NULL END,
        EOPDAT.date_key_pk,
        CASE 
            WHEN TRY_CONVERT(INT, SRC.EOPTIM) BETWEEN 0 AND 2359
                 AND LEN(LTRIM(RTRIM(CONVERT(VARCHAR(4), TRY_CONVERT(INT, SRC.EOPTIM))))) IN (3,4)
            THEN TIMEFROMPARTS(
                    LEFT(RIGHT('0000' + CONVERT(VARCHAR(4), TRY_CONVERT(INT, SRC.EOPTIM)), 4), 2),
                    RIGHT(RIGHT('0000' + CONVERT(VARCHAR(4), TRY_CONVERT(INT, SRC.EOPTIM)), 4), 2),
                    0,0,0)
            ELSE NULL END,
        EODDAT.date_key_pk,
        CASE 
            WHEN TRY_CONVERT(INT, SRC.EODTIM) BETWEEN 0 AND 2359
                 AND LEN(LTRIM(RTRIM(CONVERT(VARCHAR(4), TRY_CONVERT(INT, SRC.EODTIM))))) IN (3,4)
            THEN TIMEFROMPARTS(
                    LEFT(RIGHT('0000' + CONVERT(VARCHAR(4), TRY_CONVERT(INT, SRC.EODTIM)), 4), 2),
                    RIGHT(RIGHT('0000' + CONVERT(VARCHAR(4), TRY_CONVERT(INT, SRC.EODTIM)), 4), 2),
                    0,0,0)
            ELSE NULL END,
        EOSHDT.date_key_pk,
        CASE 
            WHEN TRY_CONVERT(INT, SRC.EOSHTM) BETWEEN 0 AND 2359
                 AND LEN(LTRIM(RTRIM(CONVERT(VARCHAR(4), TRY_CONVERT(INT, SRC.EOSHTM))))) IN (3,4)
            THEN TIMEFROMPARTS(
                    LEFT(RIGHT('0000' + CONVERT(VARCHAR(4), TRY_CONVERT(INT, SRC.EOSHTM)), 4), 2),
                    RIGHT(RIGHT('0000' + CONVERT(VARCHAR(4), TRY_CONVERT(INT, SRC.EOSHTM)), 4), 2),
                    0,0,0)
            ELSE NULL END,
        EOTNDT.date_key_pk,
        CASE 
            WHEN TRY_CONVERT(INT, SRC.EOTNTM) BETWEEN 0 AND 2359
                 AND LEN(LTRIM(RTRIM(CONVERT(VARCHAR(4), TRY_CONVERT(INT, SRC.EOTNTM))))) IN (3,4)
            THEN TIMEFROMPARTS(
                    LEFT(RIGHT('0000' + CONVERT(VARCHAR(4), TRY_CONVERT(INT, SRC.EOTNTM)), 4), 2),
                    RIGHT(RIGHT('0000' + CONVERT(VARCHAR(4), TRY_CONVERT(INT, SRC.EOTNTM)), 4), 2),
                    0,0,0)
            ELSE NULL END,
        CASE TRIM(CAST(SRC.EORPIK AS VARCHAR(5)))
            WHEN 'Y' THEN 'TRUE'
            WHEN 'N' THEN 'FALSE'
            ELSE 'unknown' END,
        CASE TRIM(CAST(SRC.EORDEL AS VARCHAR(5)))
            WHEN 'Y' THEN 'TRUE'
            WHEN 'N' THEN 'FALSE'
            ELSE 'unknown' END,
        CASE TRIM(CAST(SRC.EOHAZM AS VARCHAR(5)))
            WHEN 'Y' THEN 'TRUE'
            WHEN 'N' THEN 'FALSE'
            ELSE 'unknown' END,
        SRC.EOBAMT,
        SRC.EOTAMT,
        SRC.EOMILE,
        TRIM(CAST(SRC.EOEDCD AS VARCHAR(50))),
        TRIM(CAST(SRC.EOUSER AS VARCHAR(20)))
    FROM #DedupedEdiOrderHist SRC
    LEFT JOIN gold.dim_date EODATE ON SRC.EODATE = EODATE.date_ordinal
    LEFT JOIN gold.dim_date EOPDAT ON SRC.EOPDAT = EOPDAT.date_ordinal
    LEFT JOIN gold.dim_date EODDAT ON SRC.EODDAT = EODDAT.date_ordinal
    LEFT JOIN gold.dim_date EOSHDT ON SRC.EOSHDT = EOSHDT.date_ordinal
    LEFT JOIN gold.dim_date EOTNDT ON SRC.EOTNDT = EOTNDT.date_ordinal
    WHERE NOT EXISTS (
        SELECT 1 
        FROM silver.ibmi_edi_order_history AS TGT
        WHERE TGT.edi_ord_hist_customer_order = TRIM(CAST(SRC.EOODR AS VARCHAR(50)))
          AND TGT.edi_ord_hist_edi_customer_code = TRIM(CAST(SRC.EOEDCD AS VARCHAR(50)))
    );

    DROP TABLE #DedupedEdiOrderHist;
END;