-- Auto Generated (Do not modify) FEDF111E68E8DFD90CC2878C872B2CA1A56E627B35B6B3AFB814FCB5573BAF84


-- ===============================================================
-- Create View template for Azure Synapse SQL Analytics on-demand
-- ===============================================================


CREATE VIEW [silver].[vw_ibmi_unload_to_driver] AS

SELECT load_number									
, SUM(amount_to_driver)								AS driver_amount
, MIN(earliest_check_date)							AS early_check_date
, MAX(latest_check_date)							AS late_check_date
FROM 
(
SELECT set_rev_hist_load_number						AS load_number
, SUM(set_rev_hist_additional_pay_amount)			AS amount_to_driver
, MIN(set_rev_hist_record_date)						AS earliest_check_date
, MAX(set_rev_hist_record_date)						AS latest_check_date
FROM silver.ibmi_settlement_revenue_history
INNER JOIN silver.vw_ibmi_unloading_order_list
ON order_load_number = set_rev_hist_load_number
WHERE set_rev_hist_origin_city like '%UNLOAD%'
GROUP BY set_rev_hist_load_number

UNION

SELECT deduction_history_load_number				AS load_number
, SUM(deduction_history_deduction_amount)*-1		AS amount_to_driver
, MIN(deduction_history_check_date)					AS earliest_check_date
, MAX(deduction_history_check_date)					AS latest_check_date
FROM silver.ibmi_deduction_history
INNER JOIN silver.vw_ibmi_unloading_order_list
ON order_load_number = deduction_history_load_number
WHERE deduction_history_deduction_type = 'LMPR'
GROUP BY deduction_history_load_number
) a
GROUP BY load_number