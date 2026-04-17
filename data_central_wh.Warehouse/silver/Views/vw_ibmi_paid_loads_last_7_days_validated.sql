-- Auto Generated (Do not modify) 37D2404771A8F084E50041C868C171270D0F26C381584DD4205ECCFABC94D26C
CREATE VIEW [silver].[vw_ibmi_paid_loads_last_7_days_validated]
AS
SELECT 
	  a.earnings_history_load_number
	, MAX(a.max_date)								AS check_date
	, MAX(a.max_dispatch)							AS last_dispatch
FROM  [silver].[vw_ibmi_paid_loads_last_7_days] a
GROUP BY a.earnings_history_load_number