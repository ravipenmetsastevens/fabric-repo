-- Auto Generated (Do not modify) DD046CBFAEE3BFF66CE59F159FFC57760F5FB886E1814E7F3E7829023C7CE0DF
CREATE   VIEW [gold].[vw_ibmi_order_combined] AS

WITH orders_combined AS
(
    SELECT *
    FROM [data_central_wh].[silver].[vw_ibmi_incr_order_all]

    UNION ALL

    SELECT *
    FROM [data_central_wh].[silver].[vw_ibmi_order_all] o
    WHERE NOT EXISTS
    (
        SELECT 1
        FROM [data_central_wh].[silver].[vw_ibmi_incr_order_all] i
        WHERE i.order_load_number = o.order_load_number
    )
),

edi_api_flags AS
(
    SELECT
        edi_ord_hist_bill_of_lading,

        1 AS edi_division_078_flag,

        MAX(
            CASE
                WHEN edi_ord_hist_edi_customer_code <> 'GM'
                THEN 1
                ELSE 0
            END
        ) AS edi_api_customer_flag

    FROM [gold].[vw_ibmi_edi_order_history]
    WHERE edi_ord_hist_division_code = '078'
    GROUP BY edi_ord_hist_bill_of_lading
)

SELECT
    o.*,

    CASE
        WHEN d.division_fleet_name = 'Brokerage'
            AND d.division_code <> '025'
            AND o.order_status_code <> 'C'
            AND e.edi_division_078_flag = 1
            AND
            (
                o.order_truck_type_requirement_code = 'SXVN'
                OR e.edi_api_customer_flag = 1
            )
        THEN 1
        ELSE 0
    END AS is_api

FROM orders_combined o
LEFT JOIN [gold].[vw_ibmi_division] d
    ON o.order_division_code = d.division_code
LEFT JOIN edi_api_flags e
    ON o.order_bill_of_lading = e.edi_ord_hist_bill_of_lading;