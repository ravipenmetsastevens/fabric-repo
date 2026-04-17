-- Auto Generated (Do not modify) 1CEDF078B409C122A3EDB4BAF2678FC1160E2102A90B325624323387D886FA00
CREATE      VIEW [gold].[vw_ibmi_order_combined] AS
SELECT *
FROM [data_central_wh].[silver].[vw_ibmi_incr_order_all]
UNION ALL
SELECT *
FROM [data_central_wh].[silver].[vw_ibmi_order_all] o
WHERE NOT EXISTS (
    SELECT 1
    FROM [data_central_wh].[silver].[vw_ibmi_incr_order_all] i
    WHERE i.order_load_number = o.order_load_number
)