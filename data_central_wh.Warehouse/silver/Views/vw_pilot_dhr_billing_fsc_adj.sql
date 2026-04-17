-- Auto Generated (Do not modify) 469EEBAF9DB7DF8AFFFFBC885A5FCF51695B4FDAA288304928F53BD1F8AB3489






CREATE VIEW [silver].[vw_pilot_dhr_billing_fsc_adj]
AS

SELECT 
	  a.order_load_number
	, CASE WHEN c.fuel_surcharge_rates_customer_code IS NOT NULL 
          THEN 
			CASE b.true_load_type
				WHEN 'I' THEN (b.order_miles_billable * fuel_surcharge_rates_intermodal_rate) 
				WHEN 'D' THEN (b.order_miles_billable * fuel_surcharge_rates_dry_rate) 
				WHEN 'R' THEN (b.order_miles_billable * fuel_surcharge_rates_reefer_rate) 
			ELSE 0 END 
		ELSE 0 END																						AS fsc_adjustment_amount
FROM  [silver].[vw_ibmi_incr_order_all] a
INNER JOIN [silver].[vw_ibmi_load_type_reclass] b ON a.order_load_number = b.order_load_number
LEFT OUTER JOIN silver.ibmi_fuel_surcharge_rates c ON a.order_billto_code = c.fuel_surcharge_rates_customer_code