-- Auto Generated (Do not modify) 137C2DC08554A2F3BED7D577D5F268842FF7722686EE9B8DFD03E91D4120BA47

-- ===============================================================
-- Create View template for Azure Synapse SQL Analytics on-demand
-- ===============================================================

CREATE VIEW [silver].[vw_ibmi_gross_revenue_all] AS


SELECT 
a.cd_ordbill_load_number AS load_number
, SUM(a.cd_ordbill_load_bill_amount) AS billed_amount
, MAX(a.cd_ordbill_billed_date) AS last_date_billed
FROM silver.ibmi_cd_ordbill_v2 a INNER JOIN 
(SELECT DISTINCT cd_billing_load_number 
FROM silver.ibmi_cd_billing
) b 
ON a.cd_ordbill_load_number = b.cd_billing_load_number 
--WHERE a.is_billing_flagged = 'TRUE'
GROUP BY a.cd_ordbill_load_number

UNION

SELECT 
a.tlb_ordbill_load_number
, SUM(a.tlb_ordbill_load_bill_amount) AS billed_amount
, MAX(a.tlb_ordbill_billed_date) AS last_date_billed
FROM silver.ibmi_tlb_ordbill a INNER JOIN 
(SELECT DISTINCT tlb_billing_load_number 
FROM silver.ibmi_tlb_billing
) b 
ON a.tlb_ordbill_load_number = b.tlb_billing_load_number 
--WHERE a.is_billing_flagged = 'TRUE'
AND NOT EXISTS
(
SELECT DISTINCT
a.cd_ordbill_load_number
FROM silver.ibmi_cd_ordbill_v2 a INNER JOIN 
(SELECT DISTINCT cd_billing_load_number 
FROM silver.ibmi_cd_billing
) b 
ON a.cd_ordbill_load_number = b.cd_billing_load_number 
--WHERE a.is_billing_flagged = 'TRUE'
AND tlb_ordbill_load_number = cd_ordbill_load_number
)
GROUP BY a.tlb_ordbill_load_number

UNION

SELECT 
a.ordbill_load_number
, SUM(a.ordbill_load_bill_amount) AS billed_amount
, MAX(a.ordbill_billed_date) AS last_date_billed 
FROM silver.ibmi_ordbill a INNER JOIN 
(
SELECT DISTINCT billing_load_number 
FROM silver.ibmi_billing
) b 
ON a.ordbill_load_number = b.billing_load_number 
--WHERE a.is_billing_flagged = 'TRUE'
AND NOT EXISTS 
(
SELECT 
a.cd_ordbill_load_number 
FROM silver.ibmi_cd_ordbill_v2 a INNER JOIN 
(SELECT DISTINCT cd_billing_load_number 
FROM silver.ibmi_cd_billing
) b 
ON a.cd_ordbill_load_number = b.cd_billing_load_number 
--WHERE a.is_billing_flagged = 'TRUE'
AND  ordbill_load_number = cd_ordbill_load_number
)
AND NOT EXISTS 
(
SELECT 
a.tlb_ordbill_load_number
FROM silver.ibmi_tlb_ordbill a INNER JOIN 
(SELECT DISTINCT tlb_billing_load_number 
FROM silver.ibmi_tlb_billing
) b 
ON a.tlb_ordbill_load_number = b.tlb_billing_load_number 
--WHERE a.is_billing_flagged = 'TRUE'
AND ordbill_load_number = tlb_ordbill_load_number
)
GROUP BY a.ordbill_load_number