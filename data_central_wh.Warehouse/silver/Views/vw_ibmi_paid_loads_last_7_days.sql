-- Auto Generated (Do not modify) 4CC498736464C23A676B0375DE1785DEC9781D7A74D1AC39164265D9354C5824
CREATE VIEW [silver].[vw_ibmi_paid_loads_last_7_days]
AS
SELECT 
	  a.earnings_history_load_number
	, max(a.earnings_history_check_date)				AS max_date
	, max(a.earnings_history_dispatch_number)			AS max_dispatch
FROM   silver.ibmi_earnings_history a
WHERE a.earnings_history_load_number <> ''
AND   a.earnings_history_check_date >= CAST(DATEADD(day, - 7, GETDATE()) AS DATE)
GROUP BY a.earnings_history_load_number
--HAVING max(a.earnings_history_check_date) >= DATEADD(day, - 7, GETDATE())

UNION

SELECT 
	  a.set_rev_hist_load_number
	, max(a.set_rev_hist_load_date_revised)					AS min_date
	, max(a.set_rev_hist_dispatch_number)					AS max_dispatch
FROM   silver.ibmi_settlement_revenue_history a
WHERE a.set_rev_hist_load_number <> ''
AND   a.set_rev_hist_load_date_revised >= CAST(DATEADD(day, - 7, GETDATE()) AS DATE)
GROUP BY set_rev_hist_load_number
--HAVING max(set_rev_hist_load_date_revised) >= DATEADD(day, - 7, GETDATE())