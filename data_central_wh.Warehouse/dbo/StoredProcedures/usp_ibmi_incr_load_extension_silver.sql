CREATE   PROCEDURE [dbo].[usp_ibmi_incr_load_extension_silver]
AS
BEGIN
    SET NOCOUNT ON;

    IF OBJECT_ID('tempdb..#DedupedLoadExtension', 'U') IS NOT NULL 
        DROP TABLE #DedupedLoadExtension;

    SELECT *
    INTO #DedupedLoadExtension
    FROM (
        SELECT *,
               ROW_NUMBER() OVER (
                    PARTITION BY TRIM([LEORD#]), TRIM([LEDISP])
                    ORDER BY loadDate DESC, recordNumber DESC
               ) AS rn
        FROM data_central_lh.dbo.ibmi_incr_load_extension_bronze
    ) a
    WHERE rn = 1;

    /* ------------------------------------------------------------
       Step 1: UPDATE existing rows in silver
               (load_ext_load_number, load_ext_dispatch)
       ------------------------------------------------------------ */
    UPDATE TGT
    SET 
          load_ext_business_unit_code   = TRIM(SRC.LEBUNT)
        , load_ext_business_class       = TRIM(SRC.LERES1)
        , load_ext_business_description = TRIM(SRC.LERES2)
    FROM silver.ibmi_load_extension AS TGT
    JOIN #DedupedLoadExtension AS SRC
        ON TGT.load_ext_load_number = TRIM(SRC.[LEORD#])
       AND TGT.load_ext_dispatch    = TRIM(SRC.[LEDISP]);

    /* ------------------------------------------------------------
       Step 2: INSERT rows that don’t exist in silver
       ------------------------------------------------------------ */
    INSERT INTO silver.ibmi_load_extension (
          load_ext_load_number
        , load_ext_dispatch
        , load_ext_business_unit_code
        , load_ext_business_class
        , load_ext_business_description
    )
    SELECT
          TRIM(SRC.[LEORD#])
        , TRIM(SRC.[LEDISP])
        , TRIM(SRC.LEBUNT)
        , TRIM(SRC.LERES1)
        , TRIM(SRC.LERES2)
    FROM #DedupedLoadExtension AS SRC
    WHERE NOT EXISTS (
        SELECT 1 
        FROM silver.ibmi_load_extension AS TGT
        WHERE TGT.load_ext_load_number = TRIM(SRC.[LEORD#])
          AND TGT.load_ext_dispatch    = TRIM(SRC.[LEDISP])
    );

    DROP TABLE #DedupedLoadExtension;
END;