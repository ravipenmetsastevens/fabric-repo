-- Auto Generated (Do not modify) 32AFC93A051B416A392F68D015202BF545E1FBABC7655816D77B77BD594A8F74

CREATE VIEW gold.vw_loaded_call_contact_by_load
AS
WITH lc AS (
    SELECT
        loaded_call_load_number,
        MIN(loaded_call_contact_date) AS loaded_call_contact_date
    FROM gold.vw_ibmi_loaded_call
    GROUP BY loaded_call_load_number
),
ord AS (
    SELECT
        order_load_number AS loaded_call_load_number,
        MIN(order_loaded_call_date) AS loaded_call_contact_date
    FROM gold.vw_ibmi_order_combined
    WHERE order_early_pickup_date >= DATEFROMPARTS(2024, 1, 1)
    GROUP BY order_load_number
),
unioned AS (
    SELECT loaded_call_load_number, loaded_call_contact_date, 1 AS source_priority FROM lc
    UNION ALL
    SELECT loaded_call_load_number, loaded_call_contact_date, 2 AS source_priority FROM ord
),
ranked AS (
    SELECT
        u.loaded_call_load_number,
        u.loaded_call_contact_date,
        ROW_NUMBER() OVER (
            PARTITION BY u.loaded_call_load_number
            ORDER BY u.source_priority, u.loaded_call_contact_date
        ) AS rn
    FROM unioned AS u
)
SELECT
    loaded_call_load_number,
    loaded_call_contact_date
FROM ranked
WHERE rn = 1;