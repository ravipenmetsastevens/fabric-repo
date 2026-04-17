-- Auto Generated (Do not modify) 1FDF2B8CDE383C283C3459FC541CA3543764E6B4867B6EE94BA438195B19B2EE

CREATE VIEW [silver].[ibmi_vw_paid_loads_unload_to_driver]
AS
SELECT
	  a.deduction_history_load_number
	, a.deduction_history_check_date
	, SUM(a.deduction_history_deduction_amount)		AS Amount
	, 'ST' AS Entity
FROM silver.ibmi_deduction_history a
WHERE a.deduction_history_check_date >= DATEADD(day,-7,GETDATE())
	AND a.deduction_history_deduction_type = 'LMPR'
	AND a.deduction_history_load_number <> ''
GROUP BY 
	  a.deduction_history_load_number
	, a.deduction_history_check_date

UNION ALL

SELECT
	  b.set_rev_hist_load_number
	, b.set_rev_hist_load_date_revised
	, SUM(b.set_rev_hist_additional_pay_amount)	AS Amount
	, 'CD' as Entity
FROM silver.ibmi_settlement_revenue_history b
WHERE b.set_rev_hist_load_date_revised >= DATEADD(day,-7,GETDATE())
	AND b.set_rev_hist_origin_city like '%UNLOAD%'
	AND b.set_rev_hist_load_number <> ''
GROUP BY 
	  b.set_rev_hist_load_number
	, b.set_rev_hist_load_date_revised