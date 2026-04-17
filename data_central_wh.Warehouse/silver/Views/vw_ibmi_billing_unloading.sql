-- Auto Generated (Do not modify) 604124573E5CC2894F686DCA04C7ED87225BA770AF553C65267A87A8333BAC88

-- ===============================================================
-- Create View template for Azure Synapse SQL Analytics on-demand
-- ===============================================================


CREATE VIEW [silver].[vw_ibmi_billing_unloading] AS

SELECT billing_load_number
, SUM(billing_billed_amount)	AS total_unloading_billed
FROM [gold].fact_billing_all
INNER JOIN silver.vw_ibmi_unloading_order_list
ON order_load_number = billing_load_number
WHERE billing_commodity_code IN ('ULC','LAB','UND','UNL','L5')
GROUP BY billing_load_number