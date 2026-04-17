-- Auto Generated (Do not modify) 83CBE37665464FB7FDD49C2840F84AC93E5FC3459F364B01036517B50797AEBD
CREATE VIEW silver.vw_workday_ar_payments AS
SELECT
    -- Stable primary key for reporting
    COALESCE(payment_id, payment_reference_id, payment_wid) AS payment_key,

    -- Audit / lineage
    pulled_at_utc,
    tenant,
    rm_version,

    -- Identifiers
    payment_wid,
    payment_reference_id,
    payment_id,

    -- Customer join key (currently null in your sample, but keep it)
    customer_key,

    -- Core facts
    payment_date,
    payment_amount,
    currency,
    status,

    -- Useful reference-id packs (already flattened JSON arrays)
    payment_reference_ids_json,
    customer_reference_ids_json,
    currency_reference_ids_json,

    -- Keep payload for full fidelity (don’t parse in SQL)
    payment_json,

    -- Data quality flags
    CASE WHEN customer_key IS NULL THEN 1 ELSE 0 END AS missing_customer_key_flag,
    CASE WHEN payment_date IS NULL THEN 1 ELSE 0 END AS missing_payment_date_flag,
    CASE WHEN payment_amount IS NULL THEN 1 ELSE 0 END AS missing_payment_amount_flag,
    CASE WHEN currency IS NULL THEN 1 ELSE 0 END AS missing_currency_flag

FROM data_central_lh.dbo.workday_customer_payments_bronze_v2;