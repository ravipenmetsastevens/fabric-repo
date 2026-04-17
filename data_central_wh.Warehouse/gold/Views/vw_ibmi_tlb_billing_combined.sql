-- Auto Generated (Do not modify) D7352E084BF6E140C7A4BA65E16FAE8ED6514973578FA7BE0C6F6DE1DD8CE937
CREATE       VIEW gold.vw_ibmi_tlb_billing_combined AS

-- Incremental Billing
SELECT 
    i.*,
    ord.order_loaded_call_date AS billing_billed_date
FROM silver.ibmi_incr_tlb_billing_new AS i
INNER JOIN gold.vw_ibmi_order_combined AS ord
    ON  i.tlb_billing_load_number     = ord.order_load_number
WHERE ord.order_status_code <> 'C'

UNION ALL

-- Historical Billing (Exclude Incremental)
SELECT 
    b.*,
    ord.order_loaded_call_date AS billing_billed_date
FROM silver.ibmi_tlb_billing AS b
INNER JOIN gold.vw_ibmi_order_combined AS ord
    ON  b.tlb_billing_load_number     = ord.order_load_number
WHERE ord.order_status_code <> 'C'
  AND NOT EXISTS (
        SELECT 1
        FROM silver.ibmi_incr_tlb_billing_new AS i
        WHERE i.tlb_billing_load_number      = b.tlb_billing_load_number
          AND i.tlb_billing_sequence_number  = b.tlb_billing_sequence_number
          AND i.tlb_billing_record_number    = b.tlb_billing_record_number
  );