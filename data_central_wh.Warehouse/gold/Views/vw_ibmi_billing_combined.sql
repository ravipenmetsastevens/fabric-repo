-- Auto Generated (Do not modify) 4A634FE93256E7830F9664CC7675255FEA6F2475BA71BC40526D25EE0EA77F0F


CREATE       VIEW gold.vw_ibmi_billing_combined AS

-- Incremental Billing
SELECT 
    i.*,
    ord.order_loaded_call_date AS order_loaded_call_date
FROM silver.vw_ibmi_incr_billing_all AS i
INNER JOIN gold.vw_ibmi_order_combined AS ord
    ON  i.billing_load_number     = ord.order_load_number
WHERE ord.order_status_code <> 'C'

UNION ALL

-- Historical Billing (Exclude Incremental)
SELECT 
    b.*,
    ord.order_loaded_call_date AS order_loaded_call_date
FROM silver.vw_ibmi_billing_all AS b
INNER JOIN gold.vw_ibmi_order_combined AS ord
    ON  b.billing_load_number     = ord.order_load_number
WHERE ord.order_status_code <> 'C'
  AND NOT EXISTS (
        SELECT 1
        FROM silver.vw_ibmi_incr_billing_all AS i
        WHERE i.billing_load_number      = b.billing_load_number
          AND i.billing_sequence_number  = b.billing_sequence_number
          AND i.billing_record_number    = b.billing_record_number
  );