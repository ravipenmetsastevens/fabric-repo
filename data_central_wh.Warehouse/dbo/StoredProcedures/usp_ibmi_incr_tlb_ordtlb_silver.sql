CREATE   PROCEDURE [dbo].[usp_ibmi_incr_tlb_ordtlb_silver]
AS
BEGIN
    SET NOCOUNT ON;

    IF OBJECT_ID('tempdb..#DedupedOrdTlb') IS NOT NULL 
        DROP TABLE #DedupedOrdTlb;

    SELECT *
    INTO #DedupedOrdTlb
    FROM (
        SELECT *,
               ROW_NUMBER() OVER (
                    PARTITION BY TRIM(ORLM)
                    ORDER BY loadDate DESC, recordNumber DESC
               ) AS rn
        FROM data_central_lh.dbo.ibmi_incr_tlb_ordtlb_bronze
    ) a
    WHERE rn = 1;

    UPDATE TGT
    SET
        tlb_ordtlb_carrier_code = TRIM(SRC.ORCARR),
        tlb_ordtlb_broker_code = TRIM(SRC.ORBROK),
        tlb_ordtlb_driver_full_name = TRIM(SRC.ORDRVN),
        tlb_ordtlb_truck_number = TRIM(SRC.ORLTRK),
        tlb_ordtlb_trailer_number = TRIM(SRC.ORLTRL),
        tlb_ordtlb_truck_pay_amount = SRC.ORTRKP,
        is_trip_settled = CASE TRIM(SRC.ORSETT) WHEN 'Y' THEN 'TRUE' ELSE 'FALSE' END,
        is_expense_accrued = CASE TRIM(SRC.ORACCF) WHEN 'Y' THEN 'TRUE' ELSE 'FALSE' END,
        tlb_ordtlb_expense_accrual_amount = SRC.ORACCA,
        tlb_ordtlb_check_date = TRY_CONVERT(DATE, CAST(CONVERT(INT,SRC.ORCKDT) AS VARCHAR(8)), 112)
    FROM silver.ibmi_tlb_ordtlb AS TGT
    JOIN #DedupedOrdTlb AS SRC
        ON TGT.tlb_ordtlb_load_number = TRIM(SRC.ORLM);

    INSERT INTO silver.ibmi_tlb_ordtlb (
        tlb_ordtlb_load_number,
        tlb_ordtlb_carrier_code,
        tlb_ordtlb_broker_code,
        tlb_ordtlb_driver_full_name,
        tlb_ordtlb_truck_number,
        tlb_ordtlb_trailer_number,
        tlb_ordtlb_truck_pay_amount,
        is_trip_settled,
        is_expense_accrued,
        tlb_ordtlb_expense_accrual_amount,
        tlb_ordtlb_check_date
    )
    SELECT
        TRIM(SRC.ORLM),
        TRIM(SRC.ORCARR),
        TRIM(SRC.ORBROK),
        TRIM(SRC.ORDRVN),
        TRIM(SRC.ORLTRK),
        TRIM(SRC.ORLTRL),
        SRC.ORTRKP,
        CASE TRIM(SRC.ORSETT) WHEN 'Y' THEN 'TRUE' ELSE 'FALSE' END,
        CASE TRIM(SRC.ORACCF) WHEN 'Y' THEN 'TRUE' ELSE 'FALSE' END,
        SRC.ORACCA,
        TRY_CONVERT(DATE, CAST(CONVERT(INT,SRC.ORCKDT) AS VARCHAR(8)), 112)
    FROM #DedupedOrdTlb AS SRC
    WHERE NOT EXISTS (
        SELECT 1 
        FROM silver.ibmi_tlb_ordtlb AS TGT
        WHERE TGT.tlb_ordtlb_load_number = TRIM(SRC.ORLM)
    );

    DROP TABLE #DedupedOrdTlb;
END;