CREATE   PROCEDURE [dbo].[usp_ibmi_incr_edi_processing_history_silver]
AS
BEGIN
    SET NOCOUNT ON;

    IF OBJECT_ID('tempdb..#DedupedEdiProcHist') IS NOT NULL 
        DROP TABLE #DedupedEdiProcHist;

    SELECT *
    INTO #DedupedEdiProcHist
    FROM (
        SELECT *,
               ROW_NUMBER() OVER (
                    PARTITION BY 
                        TRIM(CAST(ATEDCD AS VARCHAR(50))),
                        TRIM(CAST(ATSHIP AS VARCHAR(50))),
                        TRIM(CAST(ATSEQ AS VARCHAR(50)))
                    ORDER BY loadDate DESC, recordNumber DESC
               ) AS rn
        FROM data_central_lh.dbo.ibmi_incr_edi_processing_history_bronze
    ) a
    WHERE rn = 1;

    -- 🔄 UPDATE existing records
    UPDATE TGT
    SET 
        edi_proc_hist_stv_load_number = TRIM(CAST(SRC.ATORDN AS VARCHAR(50))),
        edi_proc_hist_action = CASE TRIM(CAST(SRC.ATACTN AS VARCHAR(5)))
                                 WHEN 'A' THEN 'ACCEPTED'
                                 WHEN 'R' THEN 'REJECTED'
                                 WHEN 'D' THEN 'REJECTED'
                                 ELSE 'unknown' END,
        edi_proc_hist_action_date = ATDATE.date_key_pk,
        edi_proc_hist_action_time =
            CASE 
                WHEN TRY_CONVERT(INT, SRC.ATTIME) BETWEEN 0 AND 2359
                     AND LEN(LTRIM(RTRIM(CONVERT(VARCHAR(4), TRY_CONVERT(INT, SRC.ATTIME))))) IN (3,4)
                THEN TIMEFROMPARTS(
                        LEFT(RIGHT('0000' + CONVERT(VARCHAR(4), TRY_CONVERT(INT, SRC.ATTIME)), 4), 2),
                        RIGHT(RIGHT('0000' + CONVERT(VARCHAR(4), TRY_CONVERT(INT, SRC.ATTIME)), 4), 2),
                        0,0,0)
                ELSE NULL END,
        edi_proc_hist_event_code = TRIM(CAST(SRC.ATEVCD AS VARCHAR(10))),
        edi_proc_hist_event_date = ATEVDT.date_key_pk,
        edi_proc_hist_event_time =
            CASE 
                WHEN TRY_CONVERT(INT, SRC.ATEVTM) BETWEEN 0 AND 2359
                     AND LEN(LTRIM(RTRIM(CONVERT(VARCHAR(4), TRY_CONVERT(INT, SRC.ATEVTM))))) IN (3,4)
                THEN TIMEFROMPARTS(
                        LEFT(RIGHT('0000' + CONVERT(VARCHAR(4), TRY_CONVERT(INT, SRC.ATEVTM)), 4), 2),
                        RIGHT(RIGHT('0000' + CONVERT(VARCHAR(4), TRY_CONVERT(INT, SRC.ATEVTM)), 4), 2),
                        0,0,0)
                ELSE NULL END,
        edi_proc_hist_event_description = TRIM(CAST(SRC.ATEDES AS VARCHAR(200))),
        edi_proc_hist_trasmit_date = ATTRDT.date_key_pk,
        edi_proc_hist_transmit_time =
            CASE 
                WHEN TRY_CONVERT(INT, SRC.ATTRTM) BETWEEN 0 AND 2359
                     AND LEN(LTRIM(RTRIM(CONVERT(VARCHAR(4), TRY_CONVERT(INT, SRC.ATTRTM))))) IN (3,4)
                THEN TIMEFROMPARTS(
                        LEFT(RIGHT('0000' + CONVERT(VARCHAR(4), TRY_CONVERT(INT, SRC.ATTRTM)), 4), 2),
                        RIGHT(RIGHT('0000' + CONVERT(VARCHAR(4), TRY_CONVERT(INT, SRC.ATTRTM)), 4), 2),
                        0,0,0)
                ELSE NULL END,
        edi_proc_hist_pillsbury_load_number = TRIM(CAST(SRC.ATOCON AS VARCHAR(50)))
    FROM silver.ibmi_edi_processing_history AS TGT
    JOIN #DedupedEdiProcHist AS SRC
        ON TGT.edi_proc_hist_customer_code = TRIM(CAST(SRC.ATEDCD AS VARCHAR(50)))
       AND TGT.edi_proc_hist_customer_ship_number = TRIM(CAST(SRC.ATSHIP AS VARCHAR(50)))
       AND TGT.edi_proc_hist_sequence_number = TRIM(CAST(SRC.ATSEQ AS VARCHAR(50)))
    LEFT JOIN gold.dim_date ATDATE ON SRC.ATDATE = ATDATE.date_ordinal
    LEFT JOIN gold.dim_date ATEVDT ON SRC.ATEVDT = ATEVDT.date_ordinal
    LEFT JOIN gold.dim_date ATTRDT ON SRC.ATTRDT = ATTRDT.date_ordinal;

    -- 🆕 INSERT new records
    INSERT INTO silver.ibmi_edi_processing_history (
        edi_proc_hist_customer_code,
        edi_proc_hist_customer_ship_number,
        edi_proc_hist_sequence_number,
        edi_proc_hist_stv_load_number,
        edi_proc_hist_action,
        edi_proc_hist_action_date,
        edi_proc_hist_action_time,
        edi_proc_hist_event_code,
        edi_proc_hist_event_date,
        edi_proc_hist_event_time,
        edi_proc_hist_event_description,
        edi_proc_hist_trasmit_date,
        edi_proc_hist_transmit_time,
        edi_proc_hist_pillsbury_load_number
    )
    SELECT 
        TRIM(CAST(SRC.ATEDCD AS VARCHAR(50))),
        TRIM(CAST(SRC.ATSHIP AS VARCHAR(50))),
        SRC.ATSEQ,
        TRIM(CAST(SRC.ATORDN AS VARCHAR(50))),
        CASE TRIM(CAST(SRC.ATACTN AS VARCHAR(5)))
            WHEN 'A' THEN 'ACCEPTED'
            WHEN 'R' THEN 'REJECTED'
            WHEN 'D' THEN 'REJECTED'
            ELSE 'unknown' END,
        ATDATE.date_key_pk,
        CASE 
            WHEN TRY_CONVERT(INT, SRC.ATTIME) BETWEEN 0 AND 2359
                 AND LEN(LTRIM(RTRIM(CONVERT(VARCHAR(4), TRY_CONVERT(INT, SRC.ATTIME))))) IN (3,4)
            THEN TIMEFROMPARTS(
                    LEFT(RIGHT('0000' + CONVERT(VARCHAR(4), TRY_CONVERT(INT, SRC.ATTIME)), 4), 2),
                    RIGHT(RIGHT('0000' + CONVERT(VARCHAR(4), TRY_CONVERT(INT, SRC.ATTIME)), 4), 2),
                    0,0,0)
            ELSE NULL END,
        TRIM(CAST(SRC.ATEVCD AS VARCHAR(10))),
        ATEVDT.date_key_pk,
        CASE 
            WHEN TRY_CONVERT(INT, SRC.ATEVTM) BETWEEN 0 AND 2359
                 AND LEN(LTRIM(RTRIM(CONVERT(VARCHAR(4), TRY_CONVERT(INT, SRC.ATEVTM))))) IN (3,4)
            THEN TIMEFROMPARTS(
                    LEFT(RIGHT('0000' + CONVERT(VARCHAR(4), TRY_CONVERT(INT, SRC.ATEVTM)), 4), 2),
                    RIGHT(RIGHT('0000' + CONVERT(VARCHAR(4), TRY_CONVERT(INT, SRC.ATEVTM)), 4), 2),
                    0,0,0)
            ELSE NULL END,
        TRIM(CAST(SRC.ATEDES AS VARCHAR(200))),
        ATTRDT.date_key_pk,
        CASE 
            WHEN TRY_CONVERT(INT, SRC.ATTRTM) BETWEEN 0 AND 2359
                 AND LEN(LTRIM(RTRIM(CONVERT(VARCHAR(4), TRY_CONVERT(INT, SRC.ATTRTM))))) IN (3,4)
            THEN TIMEFROMPARTS(
                    LEFT(RIGHT('0000' + CONVERT(VARCHAR(4), TRY_CONVERT(INT, SRC.ATTRTM)), 4), 2),
                    RIGHT(RIGHT('0000' + CONVERT(VARCHAR(4), TRY_CONVERT(INT, SRC.ATTRTM)), 4), 2),
                    0,0,0)
            ELSE NULL END,
        TRIM(CAST(SRC.ATOCON AS VARCHAR(50)))
    FROM #DedupedEdiProcHist SRC
    LEFT JOIN gold.dim_date ATDATE ON SRC.ATDATE = ATDATE.date_ordinal
    LEFT JOIN gold.dim_date ATEVDT ON SRC.ATEVDT = ATEVDT.date_ordinal
    LEFT JOIN gold.dim_date ATTRDT ON SRC.ATTRDT = ATTRDT.date_ordinal
    WHERE NOT EXISTS (
        SELECT 1 
        FROM silver.ibmi_edi_processing_history AS TGT
        WHERE TGT.edi_proc_hist_customer_code = TRIM(CAST(SRC.ATEDCD AS VARCHAR(50)))
          AND TGT.edi_proc_hist_customer_ship_number = TRIM(CAST(SRC.ATSHIP AS VARCHAR(50)))
          AND TGT.edi_proc_hist_sequence_number = TRIM(CAST(SRC.ATSEQ AS VARCHAR(50)))
    );

    DROP TABLE #DedupedEdiProcHist;
END;