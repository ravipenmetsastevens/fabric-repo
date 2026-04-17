-- Auto Generated (Do not modify) FBC826832D4FDC5493EFC77CB9CF5ACC26C12F5AB2DF525A064DD2CD611BEBBB
create view gold.OrdBill as
SELECT
	[ordbill_load_number]
    ,[ordbill_rate_clerk_initials] -- kep in case they want to track
    ,[ordbill_invoice_number]
    ,[ordbill_billed_date]
	,[order_customer_code] -- added for dimensional join
    ,[ordbill_load_bill_amount] -- all amount fields in for testing (totals/breakdown corrolations)
    ,[ordbill_load_total_amount]
    ,[ordbill_load_book_month] -- book month/year potentially used for tax reporting
    ,[ordbill_load_book_year]     
    ,[ordbill_billed_amount_linehaul]
    ,[ordbill_billed_amount_accessorial]
    ,[ordbill_total_amount_linehaul]
    ,[ordbill_total_amount_accessorial]
    ,[ordbill_load_fuel_surcharge_amount]
    ,[ordbill_total_fuel_surcharge_amount]     
FROM 
	[silver].[ibmi_incr_ordbill] a left join
	[silver].[ibmi_order] b on a.ordbill_load_number = b.order_load_number