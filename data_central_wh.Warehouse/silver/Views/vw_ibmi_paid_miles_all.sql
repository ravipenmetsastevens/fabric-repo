-- Auto Generated (Do not modify) 5180E7E684B0C786C09D8AC36AEE051F2CCD60DDC68D65322B36B20B1DF004FF


-- ===============================================================
-- Create View template for Azure Synapse SQL Analytics on-demand
-- ===============================================================


CREATE VIEW [silver].[vw_ibmi_paid_miles_all] AS


SELECT load_number
, SUM(paid_miles) AS miles_paid
FROM
(
SELECT earnings_history_load_number			AS load_number
, SUM(earnings_history_miles_loaded)		AS paid_miles		
FROM silver.ibmi_earnings_history
INNER JOIN silver.vw_ibmi_unloading_order_list
ON order_load_number = earnings_history_load_number
WHERE earnings_history_pay_class_code = 'MILES'
GROUP BY earnings_history_load_number

UNION

SELECT set_rev_hist_load_number				AS load_number
, SUM(set_rev_hist_miles_loaded)			AS paid_miles
FROM silver.ibmi_settlement_revenue_history
INNER JOIN silver.vw_ibmi_unloading_order_list
ON order_load_number = set_rev_hist_load_number
GROUP BY set_rev_hist_load_number
) a
GROUP BY load_number