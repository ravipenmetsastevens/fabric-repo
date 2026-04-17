CREATE   PROCEDURE dbo.usp_ibmi_incr_cd_ar_extension_silver
AS
BEGIN
    SET NOCOUNT ON;

    /*========================================================
      1) Deduplicate by full key set
         Keys:
         ARENDT, ARENTI, ARCUST, ARINVN, ARCUS, ARREC
    ========================================================*/
    IF OBJECT_ID('tempdb..#DedupedCDARX') IS NOT NULL DROP TABLE #DedupedCDARX;

    SELECT *
    INTO #DedupedCDARX
    FROM
    (
        SELECT
            a.*,
            ROW_NUMBER() OVER (
                PARTITION BY
                    a.ARENDT,
                    a.ARENTI,
                    a.ARCUST,
                    a.ARINVN,
                    a.[ARCUS],
                    a.ARREC
                ORDER BY a.loadDate DESC, a.recordNumber DESC
            ) AS rn
        FROM data_central_lh.dbo.ibmi_incr_cd_ar_extension_bronze a
    ) d
    WHERE d.rn = 1;

    /*========================================================
      1.5) Run-scoped delete (customer + invoice)
    ========================================================*/
    IF OBJECT_ID('tempdb.#InvoicesToDelete') IS NOT NULL DROP TABLE #InvoicesToDelete;

    SELECT DISTINCT
          TRIM(ARCUST) AS cd_ar_ext_customer_code
        , TRIM(ARINVN) AS cd_ar_ext_invoice_number
    INTO #InvoicesToDelete
    FROM #DedupedCDARX
    WHERE ARCUST IS NOT NULL
      AND ARINVN IS NOT NULL;

    DELETE TGT
    FROM silver.ibmi_cd_ar_extension TGT
    JOIN #InvoicesToDelete D
      ON TGT.cd_ar_ext_customer_code  = D.cd_ar_ext_customer_code
     AND TGT.cd_ar_ext_invoice_number = D.cd_ar_ext_invoice_number;

    /*========================================================
      2) Transform once
    ========================================================*/
    IF OBJECT_ID('tempdb.#Xform') IS NOT NULL DROP TABLE #Xform;

    SELECT
        CASE
            WHEN LEN(CONVERT(VARCHAR(8),a.ARENDT)) = 8
                THEN DATEFROMPARTS(
                        LEFT(a.ARENDT,4),
                        SUBSTRING(CONVERT(VARCHAR(8),a.ARENDT),5,2),
                        RIGHT(a.ARENDT,2)
                     )
            ELSE NULL
        END AS cd_ar_ext_create_date,

        CASE
            WHEN LEN(CONVERT(VARCHAR(6),a.ARENTI)) = 6
                THEN TIMEFROMPARTS(
                        LEFT(a.ARENTI,2),
                        SUBSTRING(CONVERT(VARCHAR(6),a.ARENTI),3,2),
                        RIGHT(a.ARENTI,2),
                        0,0
                     )
            WHEN LEN(CONVERT(VARCHAR(6),a.ARENTI)) = 5
                THEN TIMEFROMPARTS(
                        LEFT(a.ARENTI,1),
                        SUBSTRING(CONVERT(VARCHAR(6),a.ARENTI),2,2),
                        RIGHT(a.ARENTI,2),
                        0,0
                     )
            ELSE NULL
        END AS cd_ar_ext_create_time,

        TRIM(a.ARCUST)   AS cd_ar_ext_customer_code,
        TRIM(a.ARINVN)   AS cd_ar_ext_invoice_number,
        TRIM(a.ARORD)    AS cd_ar_ext_load_number,
        TRIM(a.ARSEQ)    AS cd_ar_ext_sequence_code,
        TRIM(a.[ARCUS])  AS cd_ar_ext_ar_code,
        TRIM(a.ARTYPE)   AS cd_ar_ext_record_type_code,
        a.ARREC          AS cd_ar_ext_record_number,
        a.ARAMT          AS cd_ar_ext_invoice_amount,
        TRIM(a.ARRECC)   AS cd_ar_ext_record_code,

        CASE
            WHEN LEN(a.ARINVD) = 6
                THEN DATEFROMPARTS(
                        '20' + RIGHT(a.ARINVD,2),
                        LEFT(a.ARINVD,2),
                        SUBSTRING(a.ARINVD,3,2)
                     )
            ELSE NULL
        END AS cd_ar_ext_invoice_date,

        CASE
            WHEN LEN(a.ARDPDT) = 6
             AND a.ARDPDT <> '000000'
                THEN DATEFROMPARTS(
                        '20' + RIGHT(a.ARDPDT,2),
                        LEFT(a.ARDPDT,2),
                        SUBSTRING(a.ARDPDT,3,2)
                     )
            ELSE NULL
        END AS cd_ar_ext_deposit_or_adjustment_date,

        TRIM(a.ARCORD) AS cd_ar_ext_bol,
        TRIM(a.ARBOMO) AS cd_ar_ext_book_month,
        TRIM(a.ARBOYR) AS cd_ar_ext_book_year,
        a.ARBFWD       AS cd_ar_ext_balance_forward_amount,
        TRIM(a.ARNAME) AS cd_ar_ext_customer_name,
        TRIM(a.ARSTM)  AS cd_ar_ext_statement_number,

        CASE
            WHEN LEN(a.ARDSPD) = 6
             AND a.ARDSPD <> '000000'
                THEN DATEFROMPARTS(
                        '20' + RIGHT(a.ARDSPD,2),
                        LEFT(a.ARDSPD,2),
                        SUBSTRING(a.ARDSPD,3,2)
                     )
            ELSE NULL
        END AS cd_ar_ext_dispatch_date,

        TRIM(a.ARENUS) AS cd_ar_ext_create_user_code,
        TRIM(a.ARENPG) AS cd_ar_ext_create_program_code,

        CASE
            WHEN LEN(CONVERT(VARCHAR(8),a.ARCHDT)) = 8
                THEN DATEFROMPARTS(
                        LEFT(a.ARCHDT,4),
                        SUBSTRING(CONVERT(VARCHAR(8),a.ARCHDT),5,2),
                        RIGHT(a.ARCHDT,2)
                     )
            ELSE NULL
        END AS cd_ar_ext_last_change_date,

        CASE
            WHEN LEN(CONVERT(VARCHAR(6),a.ARCHTI)) = 6
                THEN TIMEFROMPARTS(
                        LEFT(a.ARCHTI,2),
                        SUBSTRING(CONVERT(VARCHAR(6),a.ARCHTI),3,2),
                        RIGHT(a.ARCHTI,2),
                        0,0
                     )
            WHEN LEN(CONVERT(VARCHAR(6),a.ARCHTI)) = 5
                THEN TIMEFROMPARTS(
                        LEFT(a.ARCHTI,1),
                        SUBSTRING(CONVERT(VARCHAR(6),a.ARCHTI),2,2),
                        RIGHT(a.ARCHTI,2),
                        0,0
                     )
            ELSE NULL
        END AS cd_ar_ext_last_change_time,

        TRIM(a.ARCHUS) AS cd_ar_ext_last_change_user_code,
        TRIM(a.ARCHPG) AS cd_ar_ext_last_change_program_code,

        CASE
            WHEN LEN(CONVERT(VARCHAR(8),a.ARDEDT)) = 8
                THEN DATEFROMPARTS(
                        LEFT(a.ARDEDT,4),
                        SUBSTRING(CONVERT(VARCHAR(8),a.ARDEDT),5,2),
                        RIGHT(a.ARDEDT,2)
                     )
            ELSE NULL
        END AS cd_ar_ext_delete_date,

        CASE
            WHEN LEN(CONVERT(VARCHAR(6),a.ARDETI)) = 6
                THEN TIMEFROMPARTS(
                        LEFT(a.ARDETI,2),
                        SUBSTRING(CONVERT(VARCHAR(6),a.ARDETI),3,2),
                        RIGHT(a.ARDETI,2),
                        0,0
                     )
            WHEN LEN(CONVERT(VARCHAR(6),a.ARDETI)) = 5
                THEN TIMEFROMPARTS(
                        LEFT(a.ARDETI,1),
                        SUBSTRING(CONVERT(VARCHAR(6),a.ARDETI),2,2),
                        RIGHT(a.ARDETI,2),
                        0,0
                     )
            ELSE NULL
        END AS cd_ar_ext_delete_time,

        TRIM(a.ARDEUS) AS cd_ar_ext_delete_user_code,
        TRIM(a.ARDEPG) AS cd_ar_ext_delete_program_code,

        -- materialized keys
        CASE
            WHEN LEN(CONVERT(VARCHAR(8),a.ARENDT)) = 8
                THEN DATEFROMPARTS(
                        LEFT(a.ARENDT,4),
                        SUBSTRING(CONVERT(VARCHAR(8),a.ARENDT),5,2),
                        RIGHT(a.ARENDT,2)
                     )
            ELSE NULL
        END AS _k_create_date,

        CASE
            WHEN LEN(CONVERT(VARCHAR(6),a.ARENTI)) IN (5,6)
                THEN TIMEFROMPARTS(
                        CASE
                            WHEN LEN(CONVERT(VARCHAR(6),a.ARENTI)) = 6 THEN LEFT(a.ARENTI,2)
                            ELSE LEFT(a.ARENTI,1)
                        END,
                        SUBSTRING(
                            CONVERT(VARCHAR(6),a.ARENTI),
                            CASE
                                WHEN LEN(CONVERT(VARCHAR(6),a.ARENTI)) = 6 THEN 3
                                ELSE 2
                            END,
                            2
                        ),
                        RIGHT(a.ARENTI,2),
                        0,0
                     )
            ELSE NULL
        END AS _k_create_time,

        TRIM(a.ARCUST)  AS _k_customer,
        TRIM(a.ARINVN)  AS _k_invoice,
        TRIM(a.[ARCUS]) AS _k_arcus,
        a.ARREC         AS _k_record_number

    INTO #Xform
    FROM #DedupedCDARX a;

    /*========================================================
      3) UPDATE existing rows
    ========================================================*/
    UPDATE TGT
    SET
          cd_ar_ext_load_number                  = SRC.cd_ar_ext_load_number
        , cd_ar_ext_sequence_code                = SRC.cd_ar_ext_sequence_code
        , cd_ar_ext_ar_code                      = SRC.cd_ar_ext_ar_code
        , cd_ar_ext_record_type_code             = SRC.cd_ar_ext_record_type_code
        , cd_ar_ext_invoice_amount               = SRC.cd_ar_ext_invoice_amount
        , cd_ar_ext_record_code                  = SRC.cd_ar_ext_record_code
        , cd_ar_ext_invoice_date                 = SRC.cd_ar_ext_invoice_date
        , cd_ar_ext_deposit_or_adjustment_date   = SRC.cd_ar_ext_deposit_or_adjustment_date
        , cd_ar_ext_bol                          = SRC.cd_ar_ext_bol
        , cd_ar_ext_book_month                   = SRC.cd_ar_ext_book_month
        , cd_ar_ext_book_year                    = SRC.cd_ar_ext_book_year
        , cd_ar_ext_balance_forward_amount       = SRC.cd_ar_ext_balance_forward_amount
        , cd_ar_ext_customer_name                = SRC.cd_ar_ext_customer_name
        , cd_ar_ext_statement_number             = SRC.cd_ar_ext_statement_number
        , cd_ar_ext_dispatch_date                = SRC.cd_ar_ext_dispatch_date
        , cd_ar_ext_create_user_code             = SRC.cd_ar_ext_create_user_code
        , cd_ar_ext_create_program_code          = SRC.cd_ar_ext_create_program_code
        , cd_ar_ext_last_change_date             = SRC.cd_ar_ext_last_change_date
        , cd_ar_ext_last_change_time             = SRC.cd_ar_ext_last_change_time
        , cd_ar_ext_last_change_user_code        = SRC.cd_ar_ext_last_change_user_code
        , cd_ar_ext_last_change_program_code     = SRC.cd_ar_ext_last_change_program_code
        , cd_ar_ext_delete_date                  = SRC.cd_ar_ext_delete_date
        , cd_ar_ext_delete_time                  = SRC.cd_ar_ext_delete_time
        , cd_ar_ext_delete_user_code             = SRC.cd_ar_ext_delete_user_code
        , cd_ar_ext_delete_program_code          = SRC.cd_ar_ext_delete_program_code
    FROM silver.ibmi_cd_ar_extension TGT
    JOIN #Xform SRC
      ON  TGT.cd_ar_ext_create_date      = SRC._k_create_date
      AND (
            TGT.cd_ar_ext_create_time = SRC._k_create_time
            OR (TGT.cd_ar_ext_create_time IS NULL AND SRC._k_create_time IS NULL)
          )
      AND TGT.cd_ar_ext_customer_code    = SRC._k_customer
      AND TGT.cd_ar_ext_invoice_number   = SRC._k_invoice
      AND TGT.cd_ar_ext_ar_code          = SRC._k_arcus
      AND TGT.cd_ar_ext_record_number    = SRC._k_record_number;

    /*========================================================
      4) INSERT new rows
    ========================================================*/
    INSERT INTO silver.ibmi_cd_ar_extension
    (
          cd_ar_ext_create_date
        , cd_ar_ext_create_time
        , cd_ar_ext_customer_code
        , cd_ar_ext_invoice_number
        , cd_ar_ext_load_number
        , cd_ar_ext_sequence_code
        , cd_ar_ext_ar_code
        , cd_ar_ext_record_type_code
        , cd_ar_ext_record_number
        , cd_ar_ext_invoice_amount
        , cd_ar_ext_record_code
        , cd_ar_ext_invoice_date
        , cd_ar_ext_deposit_or_adjustment_date
        , cd_ar_ext_bol
        , cd_ar_ext_book_month
        , cd_ar_ext_book_year
        , cd_ar_ext_balance_forward_amount
        , cd_ar_ext_customer_name
        , cd_ar_ext_statement_number
        , cd_ar_ext_dispatch_date
        , cd_ar_ext_create_user_code
        , cd_ar_ext_create_program_code
        , cd_ar_ext_last_change_date
        , cd_ar_ext_last_change_time
        , cd_ar_ext_last_change_user_code
        , cd_ar_ext_last_change_program_code
        , cd_ar_ext_delete_date
        , cd_ar_ext_delete_time
        , cd_ar_ext_delete_user_code
        , cd_ar_ext_delete_program_code
    )
    SELECT
          cd_ar_ext_create_date
        , cd_ar_ext_create_time
        , cd_ar_ext_customer_code
        , cd_ar_ext_invoice_number
        , cd_ar_ext_load_number
        , cd_ar_ext_sequence_code
        , cd_ar_ext_ar_code
        , cd_ar_ext_record_type_code
        , cd_ar_ext_record_number
        , cd_ar_ext_invoice_amount
        , cd_ar_ext_record_code
        , cd_ar_ext_invoice_date
        , cd_ar_ext_deposit_or_adjustment_date
        , cd_ar_ext_bol
        , cd_ar_ext_book_month
        , cd_ar_ext_book_year
        , cd_ar_ext_balance_forward_amount
        , cd_ar_ext_customer_name
        , cd_ar_ext_statement_number
        , cd_ar_ext_dispatch_date
        , cd_ar_ext_create_user_code
        , cd_ar_ext_create_program_code
        , cd_ar_ext_last_change_date
        , cd_ar_ext_last_change_time
        , cd_ar_ext_last_change_user_code
        , cd_ar_ext_last_change_program_code
        , cd_ar_ext_delete_date
        , cd_ar_ext_delete_time
        , cd_ar_ext_delete_user_code
        , cd_ar_ext_delete_program_code
    FROM #Xform SRC
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM silver.ibmi_cd_ar_extension TGT
        WHERE TGT.cd_ar_ext_create_date    = SRC._k_create_date
          AND (
                TGT.cd_ar_ext_create_time = SRC._k_create_time
                OR (TGT.cd_ar_ext_create_time IS NULL AND SRC._k_create_time IS NULL)
              )
          AND TGT.cd_ar_ext_customer_code  = SRC._k_customer
          AND TGT.cd_ar_ext_invoice_number = SRC._k_invoice
          AND TGT.cd_ar_ext_ar_code        = SRC._k_arcus
          AND TGT.cd_ar_ext_record_number  = SRC._k_record_number
    );

    DROP TABLE #DedupedCDARX;
    DROP TABLE #InvoicesToDelete;
    DROP TABLE #Xform;
END;