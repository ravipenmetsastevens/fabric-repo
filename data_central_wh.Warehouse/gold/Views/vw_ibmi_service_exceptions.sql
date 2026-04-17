-- Auto Generated (Do not modify) 84E263DCD652371F0746C88FAD68152A3E630747DE67A94DC1F2651398CBA131
CREATE     VIEW gold.vw_ibmi_service_exceptions AS
SELECT
    se.*,
    so.stopoff_stop_type AS stop_type,
    ld.order_division_code AS division_code
FROM silver.ibmi_service_exceptions AS se
LEFT JOIN gold.vw_ibmi_stopoff AS so
    ON se.serv_exc_load_number = so.stopoff_load_number
    AND se.serv_exc_dispatch = so.stopoff_dispatch
    AND se.serv_exc_stop_number = so.stopoff_stop_number
LEFT JOIN gold.vw_ibmi_order_combined AS ld
    ON se.serv_exc_load_number = ld.order_load_number
WHERE se.serv_exc_sequence_number = (
    SELECT MIN(inner_se.serv_exc_sequence_number)
    FROM silver.ibmi_service_exceptions AS inner_se
    WHERE inner_se.serv_exc_load_number = se.serv_exc_load_number
      AND inner_se.serv_exc_dispatch = se.serv_exc_dispatch
      AND inner_se.serv_exc_stop_number = se.serv_exc_stop_number
);