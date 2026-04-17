-- Auto Generated (Do not modify) 122A6D1B95E8B45769AB94A28994A6A3662883FC71683CB8ECCA9063E9A63903
CREATE     VIEW [gold].[vw_ibmi_load_prorated_revenue]
AS
WITH base AS (
    SELECT *
    FROM [data_central_wh].[gold].[vw_ibmi_load_combined]
    WHERE load_dispatch_date >= DATEFROMPARTS(2023, 11, 1)
),
miles_filtered AS (
    SELECT
        load_load_number,
        SUM(load_miles_total) AS TotalMilesPerLoad,
        COUNT(*) AS DispatchCount
    FROM base
    WHERE miles_indicator = 1
    GROUP BY load_load_number
),
billing AS (
    SELECT
        bf.billing_load_number,
        SUM(bf.billing_billed_amount) AS BillingAmount,
        SUM(CASE WHEN TRIM(bc.billing_category) = 'Fuel Surcharge' THEN bf.billing_billed_amount END) AS BillingAmountFSC,
        SUM(CASE WHEN TRIM(bc.billing_category) = 'Linehaul' THEN bf.billing_billed_amount END) AS BillingAmountLH
    FROM [data_central_wh].[gold].[vw_ibmi_billing_combined] AS bf
    LEFT JOIN [data_central_wh].[gold].[dim_billing_categories] AS bc
        ON bf.billing_commodity_code = bc.type_code
    WHERE bf.order_loaded_call_date >= DATEFROMPARTS(YEAR(GETDATE()) - 1, 1, 1)
      AND bf.order_loaded_call_date <  DATEFROMPARTS(YEAR(GETDATE()) + 1, 1, 1)
    GROUP BY bf.billing_load_number
),
orders AS (
    SELECT
        order_load_number,
        MAX(order_revenue_estimation) AS OrderRevenueEstimation,
        CAST(MAX(order_loaded_call_date) AS date) AS OrderLoadedCallDate
    FROM [data_central_wh].[gold].[vw_ibmi_order_combined]
    WHERE order_early_pickup_date >= DATEFROMPARTS(2024, 1, 1)
    GROUP BY order_load_number
),
calc AS (
    SELECT
        b.*,
        mf.TotalMilesPerLoad,
        mf.DispatchCount,
        CASE
            WHEN b.miles_indicator <> 1 THEN NULL
            WHEN mf.DispatchCount = 1 THEN 100.0
            WHEN mf.TotalMilesPerLoad IS NULL OR mf.TotalMilesPerLoad = 0 THEN NULL
            ELSE ROUND((b.load_miles_total / NULLIF(mf.TotalMilesPerLoad, 0)) * 100.0, 2)
        END AS PercentMiles,
        CASE
            WHEN b.miles_indicator <> 1 THEN NULL
            WHEN mf.DispatchCount = 1 THEN 1.0
            WHEN mf.TotalMilesPerLoad IS NULL OR mf.TotalMilesPerLoad = 0 THEN NULL
            ELSE (b.load_miles_total / NULLIF(mf.TotalMilesPerLoad, 0))
        END AS PercentMilesDecimal,
        bil.BillingAmount,
        bil.BillingAmountFSC,
        bil.BillingAmountLH,
        ord.OrderRevenueEstimation,
        ord.OrderLoadedCallDate
    FROM base b
    LEFT JOIN miles_filtered mf
        ON b.load_load_number = mf.load_load_number
    LEFT JOIN billing bil
        ON b.load_load_number = bil.billing_load_number
    LEFT JOIN orders ord
        ON b.load_load_number = ord.order_load_number
    WHERE b.miles_indicator = 1
)
SELECT
    *,
    CASE
        WHEN PercentMilesDecimal IS NULL THEN NULL
        ELSE ROUND(COALESCE(BillingAmount, OrderRevenueEstimation) * PercentMilesDecimal, 2)
    END AS ProratedRevenue,
    CASE
        WHEN PercentMilesDecimal IS NULL OR BillingAmountFSC IS NULL THEN NULL
        ELSE ROUND(BillingAmountFSC * PercentMilesDecimal, 2)
    END AS ProRevFSC,
    CASE
        WHEN PercentMilesDecimal IS NULL OR BillingAmountLH IS NULL THEN NULL
        ELSE ROUND(BillingAmountLH * PercentMilesDecimal, 2)
    END AS ProRevLH
FROM calc;