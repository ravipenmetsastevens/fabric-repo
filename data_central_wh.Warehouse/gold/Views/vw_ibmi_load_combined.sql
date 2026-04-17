-- Auto Generated (Do not modify) FF2E62E386B6A26E05DDD4A96675E5B80BCC4ED13FEEB747FC8AFA575D8C6D76
/****** Object:  View [gold].[vw_ibmi_load_combined]    Script Date: 11/17/2025 10:25:30 PM ******/
CREATE     VIEW [gold].[vw_ibmi_load_combined] AS
WITH combined_loads AS (
    SELECT *
    FROM [data_central_wh].[silver].[vw_ibmi_incr_load_all]

    UNION ALL

    SELECT *
    FROM [data_central_wh].[silver].[vw_ibmi_load_all] l
    WHERE NOT EXISTS (
        SELECT 1
        FROM [data_central_wh].[silver].[vw_ibmi_incr_load_all] il
        WHERE 
            il.load_load_number = l.load_load_number
            AND il.load_dispatch = l.load_dispatch
            AND il.load_route_line_extension = l.load_route_line_extension
    )
),


status_summary AS (
    SELECT
        load_load_number,
        load_dispatch,
        COUNT(*) AS record_count,
        COUNT(DISTINCT load_status) AS distinct_status_count,
        SUM(CASE WHEN load_status = 'E' THEN 1 ELSE 0 END) AS has_E
    FROM combined_loads
    GROUP BY load_load_number, load_dispatch
),


ranked AS (
    SELECT
        l.*,
        ROW_NUMBER() OVER (
            PARTITION BY l.load_load_number, l.load_dispatch
            ORDER BY
                CASE 
                    WHEN ss.record_count = 1 THEN 1          -- single record
                    WHEN ss.distinct_status_count = 1 THEN 2  -- multiple same status
                    WHEN ss.has_E > 0 AND l.load_status = 'E' THEN 3  -- both D & E -> E
                    ELSE 4
                END,
                l.load_route_line_extension ASC
        ) AS rn
    FROM combined_loads l
    INNER JOIN status_summary ss
        ON l.load_load_number = ss.load_load_number
        AND l.load_dispatch = ss.load_dispatch
),

with_miles AS (
    SELECT
        r.*,
        CASE WHEN r.rn = 1 THEN 1 ELSE 0 END AS miles_indicator
    FROM ranked r
)

SELECT 
    c.*,
    le.load_ext_business_unit_code AS load_business_unit_code,
	le.load_ext_business_class AS load_business_class,
	le.load_ext_business_description AS load_business_description,
    c2.miles_indicator
FROM with_miles c2
INNER JOIN combined_loads c
    ON c.load_load_number = c2.load_load_number
    AND c.load_dispatch = c2.load_dispatch
    AND c.load_route_line_extension = c2.load_route_line_extension
LEFT JOIN [data_central_wh].[silver].[ibmi_load_extension] le
    ON c.load_load_number = le.load_ext_load_number
    AND c.load_dispatch = le.load_ext_dispatch;