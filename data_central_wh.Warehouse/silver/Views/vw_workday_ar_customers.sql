-- Auto Generated (Do not modify) FA50C0924912EC9E5E3A5E4C6B00310B5CE65DE644BBF051312715D1494249C5
CREATE VIEW silver.vw_workday_ar_customers AS
SELECT
    customer_id,
    customer_reference_id,
    customer_wid,
    COALESCE(customer_id, customer_reference_id, customer_wid) AS customer_key,
    customer_name,
    customer_json
FROM data_central_lh.dbo.workday_customers_bronze;