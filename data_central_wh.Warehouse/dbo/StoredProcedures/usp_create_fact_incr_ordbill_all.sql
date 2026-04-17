CREATE PROCEDURE [dbo].[usp_create_fact_incr_ordbill_all]
AS

DELETE FROM gold.fact_incr_ordbill_all

INSERT INTO gold.fact_incr_ordbill_all

SELECT 
	  a.[cd_ordbill_load_number]					AS load_number
	, SUM(a.[cd_ordbill_load_bill_amount])			AS bill_amount

FROM   [silver].[ibmi_incr_cd_ordbill] a 
INNER JOIN [silver].[ibmi_incr_cd_billing] b ON b.[cd_billing_load_number] = a.[cd_ordbill_load_number] 
									   AND b.[cd_billing_record_number] = 1 
									   AND b.[cd_billing_sequence_number] = ''
--WHERE a.[cd_ordbill_void_invoice_number] = '' 
GROUP BY a.[cd_ordbill_load_number]
HAVING SUM(a.[cd_ordbill_load_bill_amount]) > 1

UNION

SELECT 
	  a.[tlb_ordbill_load_number]					AS load_number
	, SUM(a.[tlb_ordbill_load_bill_amount])			AS bill_amount
FROM   [silver].[ibmi_incr_tlb_ordbill] a 
INNER JOIN [silver].[ibmi_incr_tlb_billing] b ON b.[tlb_billing_load_number] = a.[tlb_ordbill_load_number] 
										AND b.[tlb_billing_record_number] = 1 
										AND b.[tlb_billing_sequence_number] = ''
--WHERE a.[tlb_ordbill_void_invoice_number] = '' 
GROUP BY a.[tlb_ordbill_load_number]
HAVING SUM(a.[tlb_ordbill_load_bill_amount]) > 1

UNION

SELECT 
	  [ordbill_load_number]							AS load_number
	, SUM([ordbill_load_bill_amount])				AS bill_amount
FROM   [silver].[ibmi_incr_ordbill] a 
INNER JOIN [silver].[ibmi_incr_billing] b ON b.[billing_load_number] = a.[ordbill_load_number] 
									AND b.[billing_record_number] = 1 
									AND b.[billing_sequence_number] = ''
--WHERE a.[ordbill_void_invoice_number] = '' 
GROUP BY a.[ordbill_load_number]
HAVING SUM(a.[ordbill_load_bill_amount]) > 1