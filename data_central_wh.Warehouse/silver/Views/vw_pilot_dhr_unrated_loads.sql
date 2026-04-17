-- Auto Generated (Do not modify) 8639C427863DFB7B8501559C0CAFAE0C0F81E59103073B7065D5A9CF59B6EA49

-- ===============================================================
-- Create View template for Azure Synapse SQL Analytics on-demand
-- ===============================================================

CREATE VIEW [silver].[vw_pilot_dhr_unrated_loads] AS

SELECT
	* 
FROM 
	silver.vw_pilot_dhr_export2
WHERE NOT EXISTS
	(
	SELECT
		billing_load_number
	FROM 
		gold.vw_fact_incr_billing_all
	WHERE
		billing_load_number = order_load_number
	)