-- Auto Generated (Do not modify) 5CE649C5164B0B94447AB76A56D109E8ACFADAAA390C6B07A332B9893B6CBF3A
CREATE VIEW [silver].[ibmi_vw_paid_loads_max_dispatch]
AS
SELECT 
	  a.load_load_number
	, MAX(a.load_dispatch)		AS max_dispatch
FROM   silver.ibmi_load a 
INNER JOIN silver.ibmi_order b ON a.load_load_number = b.order_load_number
WHERE (b.order_division_code NOT IN ('6', '7', '8'))
GROUP BY a.load_load_number