CREATE   PROCEDURE [dbo].[usp_ibmi_incr_edi_reject_details_silver]
AS
BEGIN
    SET NOCOUNT ON;

    IF OBJECT_ID('tempdb..#DedupedEdiRejects') IS NOT NULL 
        DROP TABLE #DedupedEdiRejects;

    SELECT *
    INTO #DedupedEdiRejects
    FROM (
        SELECT *,
               ROW_NUMBER() OVER (
                    PARTITION BY 
                        TRIM(CAST(ELTNAM AS VARCHAR(100))),
                        TRIM(CAST(EOODR AS VARCHAR(50)))
                    ORDER BY loadDate DESC, recordNumber DESC
               ) AS rn
        FROM data_central_lh.dbo.ibmi_incr_edi_reject_details_bronze
    ) a
    WHERE rn = 1;

    -- 🔄 UPDATE existing
    UPDATE TGT
    SET 
        edi_rejects_origin = TRIM(CAST(SRC.ORICOD AS VARCHAR(10))),
        edi_rejects_destination = TRIM(CAST(SRC.DESCOD AS VARCHAR(10))),
        edi_rejects_comment = TRIM(CAST(SRC.TOMGMT AS VARCHAR(200))),
        edi_rejects_pickup_date = EOPDAT.date_key_pk,
        edi_rejects_delivery_date = EODDAT.date_key_pk,
        edi_rejects_reject_date = SRC.RJDATE,
        edi_rejects_tender_date = EOTNDT.date_key_pk,
        edi_rejects_tender_time =
            CASE 
                WHEN TRY_CONVERT(INT, SRC.EOTNTM) BETWEEN 0 AND 2359
                     AND LEN(LTRIM(RTRIM(CONVERT(VARCHAR(4), TRY_CONVERT(INT, SRC.EOTNTM))))) IN (3,4)
                THEN TIMEFROMPARTS(
                        LEFT(RIGHT('0000' + CONVERT(VARCHAR(4), TRY_CONVERT(INT, SRC.EOTNTM)), 4), 2),
                        RIGHT(RIGHT('0000' + CONVERT(VARCHAR(4), TRY_CONVERT(INT, SRC.EOTNTM)), 4), 2),
                        0,0,0)
                ELSE NULL END,
        edi_rejects_load_type = TRIM(CAST(SRC.EOBBOC AS VARCHAR(10))),
        edi_rejects_temp_low = SRC.EOTMPL,
        edi_rejects_temp_high = SRC.EOTMPH,
        edi_rejects_user_code = TRIM(CAST(SRC.USRNAM AS VARCHAR(20))),
        edi_rejects_miles_billable = SRC.EOMILE
    FROM silver.ibmi_edi_reject_details AS TGT
    JOIN #DedupedEdiRejects AS SRC
        ON TGT.edi_rejects_customer_name = TRIM(CAST(SRC.ELTNAM AS VARCHAR(100)))
       AND TGT.edi_rejects_bol = TRIM(CAST(SRC.EOODR AS VARCHAR(50)))
    LEFT JOIN gold.dim_date EOPDAT ON SRC.EOPDAT = EOPDAT.date_ordinal
    LEFT JOIN gold.dim_date EODDAT ON SRC.EODDAT = EODDAT.date_ordinal
    LEFT JOIN gold.dim_date EOTNDT ON SRC.EOTNDT = EOTNDT.date_ordinal;

    -- 🆕 INSERT new
    INSERT INTO silver.ibmi_edi_reject_details (
        edi_rejects_customer_name,
        edi_rejects_origin,
        edi_rejects_destination,
        edi_rejects_bol,
        edi_rejects_comment,
        edi_rejects_pickup_date,
        edi_rejects_delivery_date,
        edi_rejects_reject_date,
        edi_rejects_tender_date,
        edi_rejects_tender_time,
        edi_rejects_load_type,
        edi_rejects_temp_low,
        edi_rejects_temp_high,
        edi_rejects_user_code,
        edi_rejects_miles_billable
    )
    SELECT 
        TRIM(CAST(SRC.ELTNAM AS VARCHAR(100))),
        TRIM(CAST(SRC.ORICOD AS VARCHAR(10))),
        TRIM(CAST(SRC.DESCOD AS VARCHAR(10))),
        TRIM(CAST(SRC.EOODR AS VARCHAR(50))),
        TRIM(CAST(SRC.TOMGMT AS VARCHAR(200))),
        EOPDAT.date_key_pk,
        EODDAT.date_key_pk,
        SRC.RJDATE,
        EOTNDT.date_key_pk,
        CASE 
            WHEN TRY_CONVERT(INT, SRC.EOTNTM) BETWEEN 0 AND 2359
                 AND LEN(LTRIM(RTRIM(CONVERT(VARCHAR(4), TRY_CONVERT(INT, SRC.EOTNTM))))) IN (3,4)
            THEN TIMEFROMPARTS(
                    LEFT(RIGHT('0000' + CONVERT(VARCHAR(4), TRY_CONVERT(INT, SRC.EOTNTM)), 4), 2),
                    RIGHT(RIGHT('0000' + CONVERT(VARCHAR(4), TRY_CONVERT(INT, SRC.EOTNTM)), 4), 2),
                    0,0,0)
            ELSE NULL END,
        TRIM(CAST(SRC.EOBBOC AS VARCHAR(10))),
        SRC.EOTMPL,
        SRC.EOTMPH,
        TRIM(CAST(SRC.USRNAM AS VARCHAR(20))),
        SRC.EOMILE
    FROM #DedupedEdiRejects SRC
    LEFT JOIN gold.dim_date EOPDAT ON SRC.EOPDAT = EOPDAT.date_ordinal
    LEFT JOIN gold.dim_date EODDAT ON SRC.EODDAT = EODDAT.date_ordinal
    LEFT JOIN gold.dim_date EOTNDT ON SRC.EOTNDT = EOTNDT.date_ordinal
    WHERE NOT EXISTS (
        SELECT 1 
        FROM silver.ibmi_edi_reject_details AS TGT
        WHERE TGT.edi_rejects_customer_name = TRIM(CAST(SRC.ELTNAM AS VARCHAR(100)))
          AND TGT.edi_rejects_bol = TRIM(CAST(SRC.EOODR AS VARCHAR(50)))
    );

    DROP TABLE #DedupedEdiRejects;
END;