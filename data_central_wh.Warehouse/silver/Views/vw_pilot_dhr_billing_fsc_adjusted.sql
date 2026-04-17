-- Auto Generated (Do not modify) 5D7E347A4857AE9617BFB8A8F6DB24AF1EF707EFCBC3B203AC9938B60CBFA39E



CREATE VIEW [silver].[vw_pilot_dhr_billing_fsc_adjusted]
AS
SELECT 
	  a.order_load_number
	, CASE 
--		WHEN b.billing_load_number IS NULL 
--			THEN NULL
		WHEN a.fsc_adjustment_amount IS NOT NULL 
			THEN (a.fsc_adjustment_amount + isnull(b.fsc_amount,0)) 
        ELSE b.fsc_amount END											AS adjusted_fsc_amount
FROM   [silver].[vw_pilot_dhr_billing_fsc_adj] a 
LEFT OUTER JOIN [silver].[vw_pilot_dhr_billing_fsc] b ON a.order_load_number = b.billing_load_number