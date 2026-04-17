-- Auto Generated (Do not modify) 240EF3343F87785ED923973315A619B5E241F787FBD3B6C11B55CE0D3DC2B32C

CREATE VIEW [silver].[ibmi_vw_paid_loads_billing_by_category]
AS
SELECT        
	  b.load_number
	, a.billing_category
	, b.billed_amount
FROM  gold.dim_billing_categories a
INNER JOIN [silver].[vw_ibmi_paid_loads_billing_all] b ON a.type_code = b.commodity_code