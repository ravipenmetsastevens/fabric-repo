-- Auto Generated (Do not modify) 6CEB43A792518505B8C3380A790BEC1B07A2B3AD59F1C124C5A5CF19ED8E3F54



CREATE    VIEW [gold].[vw_fact_risk_preventable_accident_details] AS
SELECT
	  a.*
FROM
	data_central_wh.gold.vw_fact_risk_accident_details a
WHERE 
	a.is_preventable = 'TRUE'
	AND a.claim_mast_occurance_date BETWEEN DATEADD(year, -1, GETDATE()) AND GETDATE()