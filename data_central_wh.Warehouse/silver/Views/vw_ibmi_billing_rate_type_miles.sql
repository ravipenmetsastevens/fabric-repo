-- Auto Generated (Do not modify) 3FA41023DD7002B436488BC14E60A2A050F99F7328031EB95E674C50E8477159


-- ===============================================================
-- Create View template for Azure Synapse SQL Analytics on-demand
-- ===============================================================


CREATE VIEW [silver].[vw_ibmi_billing_rate_type_miles] AS

SELECT DISTINCT billing_load_number
, billing_commodity_code
, SUM(billing_actual_quantity_count) AS billed_miles
  FROM [gold].[fact_billing_all]
  INNER JOIN silver.vw_ibmi_unloading_order_list
  ON order_load_number = billing_load_number
  WHERE billing_commodity_code IN ('MR','FR')
  AND billing_billed_amount > 1
  GROUP BY billing_load_number, billing_commodity_code
  HAVING SUM(billing_actual_quantity_count) > 1