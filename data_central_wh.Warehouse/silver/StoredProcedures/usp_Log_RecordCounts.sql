CREATE   PROCEDURE silver.usp_Log_RecordCounts
    @OnlyEnabled BIT = 1,                         -- 1 = only enabled objects, 0 = all rows in config
    @RunId UNIQUEIDENTIFIER = NULL                -- optional: pass a run_id from pipeline; else generated
AS
BEGIN
    SET NOCOUNT ON;

    IF @RunId IS NULL
        SET @RunId = NEWID();

    DECLARE @NowUtc DATETIME2(3) = SYSUTCDATETIME();

    -------------------------------------------------------------------
    -- Stage targets
    -------------------------------------------------------------------
    IF OBJECT_ID('tempdb..#targets') IS NOT NULL
        DROP TABLE #targets;

    SELECT
        ISNULL(database_name, 'data_central_wh') AS database_name,
        object_schema,
        object_name,
        object_type
    INTO #targets
    FROM silver.RecordCount_config
    WHERE (@OnlyEnabled = 0 OR is_enabled = 1);

    -------------------------------------------------------------------
    -- Loop over targets
    -------------------------------------------------------------------
    DECLARE @db     SYSNAME;
    DECLARE @schema SYSNAME;
    DECLARE @obj    SYSNAME;
    DECLARE @type   VARCHAR(10);

    DECLARE @sql NVARCHAR(MAX);
    DECLARE @start DATETIME2(3);
    DECLARE @duration_ms BIGINT;
    DECLARE @cnt BIGINT;

    WHILE EXISTS (SELECT 1 FROM #targets)
    BEGIN
        SELECT TOP (1)
            @db     = database_name,
            @schema = object_schema,
            @obj    = object_name,
            @type   = object_type
        FROM #targets
        ORDER BY database_name, object_schema, object_name;

        DELETE FROM #targets
        WHERE database_name = @db
          AND object_schema = @schema
          AND object_name   = @obj;

        BEGIN TRY
            SET @start = SYSUTCDATETIME();
            SET @cnt = NULL;

            -- 3-part naming: [db].[schema].[object]
            -- COUNT_BIG so you don't overflow on huge tables
            SET @sql =
                N'SELECT @cnt_out = COUNT_BIG(*) FROM '
                + QUOTENAME(@db) + N'.' + QUOTENAME(@schema) + N'.' + QUOTENAME(@obj) + N';';

            EXEC sp_executesql
                @sql,
                N'@cnt_out BIGINT OUTPUT',
                @cnt_out = @cnt OUTPUT;

            SET @duration_ms = DATEDIFF(MILLISECOND, @start, SYSUTCDATETIME());

            INSERT INTO silver.RecordCount_log
            (
                run_id,
                database_name,
                object_schema,
                object_name,
                run_datetime_utc,
                record_count,
                is_zero_count,
                duration_ms,
                status,
                error_message
            )
            VALUES
            (
                @RunId,
                @db,
                @schema,
                @obj,
                @NowUtc,
                @cnt,
                CASE WHEN @cnt = 0 THEN 1 ELSE 0 END,
                @duration_ms,
                'OK',
                NULL
            );
        END TRY
        BEGIN CATCH
            SET @duration_ms = CASE
                                WHEN @start IS NULL THEN NULL
                                ELSE DATEDIFF(MILLISECOND, @start, SYSUTCDATETIME())
                               END;

            INSERT INTO silver.RecordCount_log
            (
                run_id,
                database_name,
                object_schema,
                object_name,
                run_datetime_utc,
                record_count,
                is_zero_count,
                duration_ms,
                status,
                error_message
            )
            VALUES
            (
                @RunId,
                @db,
                @schema,
                @obj,
                @NowUtc,
                NULL,
                0,
                ISNULL(@duration_ms, 0),
                'ERROR',
                ERROR_MESSAGE()
            );
        END CATCH
    END

    -------------------------------------------------------------------
    -- Return run id to pipeline
    -------------------------------------------------------------------
    SELECT @RunId AS run_id;
END;