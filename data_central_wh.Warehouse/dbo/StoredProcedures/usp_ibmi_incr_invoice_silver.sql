CREATE   PROCEDURE [dbo].[usp_ibmi_incr_invoice_silver]
AS
BEGIN
    SET NOCOUNT ON;

    IF OBJECT_ID('tempdb..#DedupedInvoice') IS NOT NULL DROP TABLE #DedupedInvoice;

    SELECT *
    INTO #DedupedInvoice
    FROM (
        SELECT *,
               ROW_NUMBER() OVER (
                   PARTITION BY TNORD#, TNDISP
                   ORDER BY loadDate DESC, recordNumber DESC
               ) AS rn
        FROM [data_central_lh].[dbo].[ibmi_incr_invoice_bronze]
    ) a
    WHERE rn = 1;

    UPDATE TGT
    SET
        loadNumber      = SRC.TNORD#,
        dispatchNumber  = SRC.TNDISP,
        divisionNumber  = SRC.TNDIV#,
        orderNumber     = SRC.TNORD#,
        invoiceNumber   = SRC.TNINV#,
        carrierCode     = TRIM(SRC.TNCARR),
        enteredUser     = TRIM(SRC.TNEUSE),
        enteredDate     = TRY_CONVERT(DATE, LEFT(CAST(SRC.TNEDAT AS VARCHAR(20)), 8)),
        enteredTime     = TIMEFROMPARTS(CAST(SRC.TNETIM AS INT) / 100, CAST(SRC.TNETIM AS INT) % 100, 0, 0, 0),
        modifiedUser    = TRIM(SRC.TNMUSE),
        modifiedDate    = TRY_CONVERT(DATE, LEFT(CAST(SRC.TNMDAT AS VARCHAR(20)), 8)),
        modifiedTime    = TIMEFROMPARTS(CAST(SRC.TNMTIM AS INT) / 100, CAST(SRC.TNMTIM AS INT) % 100, 0, 0, 0),
        bookMonth       = SRC.TNBKMO,
        bookYear        = SRC.TNBKYR,
        voidFlag        = SRC.TNVOID,
        refNumber       = SRC.TNREF#,
        checkNumber     = SRC.TNCHK#,
        checkDate       = TRY_CONVERT(DATE, LEFT(CAST(SRC.TNCDAT AS VARCHAR(20)), 8)),
        checkAmount     = SRC.TNCAMT,
        invoiceDate     = TRY_CONVERT(DATE, LEFT(CAST(SRC.TNIDAT AS VARCHAR(20)), 8)),
        updateDate      = TRY_CONVERT(DATE, LEFT(CAST(SRC.TNUDAT AS VARCHAR(20)), 8)),
        paymentDate     = TRY_CONVERT(DATE, LEFT(CAST(SRC.TNPDAT AS VARCHAR(20)), 8)),
        invoiceAmount   = SRC.TNIAMT,
        is_deleted      = CASE WHEN SRC.TNVOID = 'Y' THEN 1 ELSE 0 END,
        loadDate        = SYSDATETIME(),
        refreshDate     = CAST(SYSDATETIME() AS DATE),
        sourceSystem    = 'IBM'
    FROM [data_central_wh].[silver].[ibmi_incr_invoice] AS TGT
    JOIN #DedupedInvoice SRC
      ON TGT.loadNumber = SRC.TNORD#
     AND TGT.dispatchNumber = SRC.TNDISP;

    INSERT INTO [data_central_wh].[silver].[ibmi_incr_invoice]
    (
        loadNumber,
        dispatchNumber,
        divisionNumber,
        orderNumber,
        invoiceNumber,
        carrierCode,
        enteredUser,
        enteredDate,
        enteredTime,
        modifiedUser,
        modifiedDate,
        modifiedTime,
        bookMonth,
        bookYear,
        voidFlag,
        refNumber,
        checkNumber,
        checkDate,
        checkAmount,
        invoiceDate,
        updateDate,
        paymentDate,
        invoiceAmount,
        is_deleted,
        loadDate,
        refreshDate,
        sourceSystem
    )
    SELECT
        SRC.TNORD#,
        SRC.TNDISP,
        SRC.TNDIV#,
        SRC.TNORD#,
        SRC.TNINV#,
        TRIM(SRC.TNCARR),
        TRIM(SRC.TNEUSE),
        TRY_CONVERT(DATE, LEFT(CAST(SRC.TNEDAT AS VARCHAR(20)), 8)),
        TIMEFROMPARTS(CAST(SRC.TNETIM AS INT) / 100, CAST(SRC.TNETIM AS INT) % 100, 0, 0, 0),
        TRIM(SRC.TNMUSE),
        TRY_CONVERT(DATE, LEFT(CAST(SRC.TNMDAT AS VARCHAR(20)), 8)),
        TIMEFROMPARTS(CAST(SRC.TNMTIM AS INT) / 100, CAST(SRC.TNMTIM AS INT) % 100, 0, 0, 0),
        SRC.TNBKMO,
        SRC.TNBKYR,
        SRC.TNVOID,
        SRC.TNREF#,
        SRC.TNCHK#,
        TRY_CONVERT(DATE, LEFT(CAST(SRC.TNCDAT AS VARCHAR(20)), 8)),
        SRC.TNCAMT,
        TRY_CONVERT(DATE, LEFT(CAST(SRC.TNIDAT AS VARCHAR(20)), 8)),
        TRY_CONVERT(DATE, LEFT(CAST(SRC.TNUDAT AS VARCHAR(20)), 8)),
        TRY_CONVERT(DATE, LEFT(CAST(SRC.TNPDAT AS VARCHAR(20)), 8)),
        SRC.TNIAMT,
        CASE WHEN SRC.TNVOID = 'Y' THEN 1 ELSE 0 END,
        SYSDATETIME(),
        CAST(SYSDATETIME() AS DATE),
        'IBM'
    FROM #DedupedInvoice SRC
    WHERE NOT EXISTS (
        SELECT 1
        FROM [data_central_wh].[silver].[ibmi_incr_invoice] TGT
        WHERE TGT.loadNumber = SRC.TNORD#
          AND TGT.dispatchNumber = SRC.TNDISP
    );

    DROP TABLE #DedupedInvoice;
END;