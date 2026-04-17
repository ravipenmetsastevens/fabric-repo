-- Auto Generated (Do not modify) 4706088B0B76235A50A9EC73FB400A9AAE6D4BAE10F23A9193B29E83FDA43464
CREATE   VIEW gold.vw_ibmi_stopoff
AS
WITH s AS (
    SELECT *
    FROM silver.ibmi_stopoff
),
og AS (
    SELECT
        stopoff_og_load_number,
        stopoff_og_stop_number,
        stopoff_og_appt_late_date,
        stopoff_og_appt_late_time
    FROM silver.ibmi_stopoff_og_appt
),
dt AS (
    SELECT
        s.*,

        -- Actual arrival datetime
        CASE 
            WHEN s.stopoff_arrival_date IS NOT NULL
            THEN DATEADD(
                    SECOND,
                    DATEDIFF(
                        SECOND,
                        CAST('00:00:00' AS time(0)),
                        COALESCE(s.stopoff_arrival_time, CAST('00:00:00' AS time(0)))
                    ),
                    CAST(s.stopoff_arrival_date AS datetime2)
                 )
            ELSE NULL
        END AS actual_arrival_dt,

        -- Current appointment late datetime
        CASE 
            WHEN s.stopoff_appt_late_date IS NOT NULL
            THEN DATEADD(
                    SECOND,
                    DATEDIFF(
                        SECOND,
                        CAST('00:00:00' AS time(0)),
                        COALESCE(s.stopoff_appt_late_time, CAST('00:00:00' AS time(0)))
                    ),
                    CAST(s.stopoff_appt_late_date AS datetime2)
                 )
            ELSE NULL
        END AS appt_late_date
    FROM s
),
dt2 AS (
    SELECT
        dt.*,

        -- OG appointment late datetime (for debugging + metrics)
        CASE 
            WHEN og.stopoff_og_appt_late_date IS NOT NULL
            THEN DATEADD(
                    SECOND,
                    DATEDIFF(
                        SECOND,
                        CAST('00:00:00' AS time(0)),
                        COALESCE(og.stopoff_og_appt_late_time, CAST('00:00:00' AS time(0)))
                    ),
                    CAST(og.stopoff_og_appt_late_date AS datetime2)
                 )
            ELSE NULL
        END AS og_appt_late_dt
    FROM dt
    LEFT JOIN og
        ON  og.stopoff_og_load_number = dt.stopoff_load_number
        AND og.stopoff_og_stop_number = TRY_CONVERT(int, dt.stopoff_stop_number)
),
se AS (
    SELECT
        se_load_number,
        se_stop_number,
        MAX(se_reason_code) AS se_reason_code
    FROM silver.ibmi_service_exceptions_edi
    WHERE se_reason_code LIKE 'B%'
    GROUP BY
        se_load_number,
        se_stop_number
)
SELECT
    dt2.*,
    o.order_division_code AS division_code,

    CASE WHEN se.se_load_number IS NOT NULL THEN 1 ELSE 0 END AS HasLateServiceException,
    se.se_reason_code AS LateServiceExceptionReasonCode,

    CASE 
        WHEN UPPER(dt2.stopoff_stop_type) = 'PICKUP'
         AND (
                (dt2.appt_late_date IS NOT NULL AND dt2.actual_arrival_dt IS NOT NULL AND dt2.actual_arrival_dt > dt2.appt_late_date)
                OR se.se_load_number IS NOT NULL
             )
        THEN 1 ELSE 0
    END AS OnTimePickupLateCount,

    CASE 
        WHEN UPPER(dt2.stopoff_stop_type) = 'DELIVERY'
         AND (
                (dt2.appt_late_date IS NOT NULL AND dt2.actual_arrival_dt IS NOT NULL AND dt2.actual_arrival_dt > dt2.appt_late_date)
                OR se.se_load_number IS NOT NULL
             )
        THEN 1 ELSE 0
    END AS OnTimeDeliveryLateCount,

    CASE 
        WHEN UPPER(dt2.stopoff_stop_type) = 'PICKUP'
         AND (
                (dt2.og_appt_late_dt IS NOT NULL AND dt2.actual_arrival_dt IS NOT NULL AND dt2.actual_arrival_dt > dt2.og_appt_late_dt)
                OR se.se_load_number IS NOT NULL
             )
        THEN 1 ELSE 0
    END AS OnTimePickupLateCount_OG,

    CASE 
        WHEN UPPER(dt2.stopoff_stop_type) = 'DELIVERY'
         AND (
                (dt2.og_appt_late_dt IS NOT NULL AND dt2.actual_arrival_dt IS NOT NULL AND dt2.actual_arrival_dt > dt2.og_appt_late_dt)
                OR se.se_load_number IS NOT NULL
             )
        THEN 1 ELSE 0
    END AS OnTimeDeliveryLateCount_OG,

    RIGHT(
        '00' + CAST(
            COALESCE(
                NULLIF(TRY_CONVERT(INT, dt2.stopoff_dispatch), 0),
                CASE WHEN TRY_CONVERT(INT, dt2.stopoff_stop_number) = 1 THEN 1 END,
                CASE WHEN TRY_CONVERT(INT, dt2.stopoff_stop_number) IN (90, 99)
                     THEN (
                         SELECT MAX(TRY_CONVERT(INT, l1.load_dispatch))
                         FROM gold.vw_ibmi_load_combined l1
                         WHERE l1.load_load_number = dt2.stopoff_load_number
                     )
                END,
                (
                    SELECT TOP (1) TRY_CONVERT(INT, l2.load_dispatch)
                    FROM gold.vw_ibmi_load_combined l2
                    WHERE l2.load_load_number = dt2.stopoff_load_number
                      AND l2.load_truck_number = dt2.stopoff_truck_number
                    ORDER BY
                        COALESCE(l2.load_dispatch_date, '1900-01-01') ASC,
                        COALESCE(l2.load_dispatch_time, '00:00:00') ASC
                )
            ) AS varchar(2)
        ),
        2
    ) AS stopoff_dispatch_new
FROM dt2
LEFT JOIN gold.vw_ibmi_order_combined AS o
    ON dt2.stopoff_load_number = o.order_load_number
LEFT JOIN se
    ON  se.se_load_number = dt2.stopoff_load_number
    AND se.se_stop_number = TRY_CONVERT(int, dt2.stopoff_stop_number);