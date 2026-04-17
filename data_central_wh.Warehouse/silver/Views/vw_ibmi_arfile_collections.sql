-- Auto Generated (Do not modify) 00C7CA8E2FC15AD7B8710EBDD4EA0C78A69F220A6CE1552C0B9858B2813FAFBF



-- ===============================================================
-- Create View template for Azure Synapse SQL Analytics on-demand
-- ===============================================================


CREATE VIEW [silver].[vw_ibmi_arfile_collections] AS

SELECT load_number
, SUM(collected_amount)			AS amount_collected
, MIN(earliest_collected_date)	AS early_collected_date
, MAX(latest_collected_date)	AS late_collected_date
FROM
(
SELECT cd_arfile_load_number	AS load_number
, SUM(cd_arfile_amount)			AS collected_amount
, MIN(cd_arfile_invoice_date)	AS earliest_collected_date
, MAX(cd_arfile_invoice_date)	AS latest_collected_date
FROM silver.ibmi_cd_arfile
INNER JOIN silver.vw_ibmi_unloading_order_list
ON order_load_number = cd_arfile_load_number
WHERE cd_arfile_record_type IN ('10','14')
GROUP BY cd_arfile_load_number
HAVING SUM(cd_arfile_amount) > 1

UNION

SELECT tlb_arfile_load_number	AS load_number
, SUM(tlb_arfile_amount)		AS collected_amount
, MIN(tlb_arfile_invoice_date)	AS earliest_collected_date
, MAX(tlb_arfile_invoice_date)	AS latest_collected_date
FROM silver.ibmi_tlb_arfile
INNER JOIN silver.vw_ibmi_unloading_order_list
ON order_load_number = tlb_arfile_load_number
WHERE tlb_arfile_record_type IN ('10','14')
GROUP BY tlb_arfile_load_number
HAVING SUM(tlb_arfile_amount) > 1

UNION

SELECT arfile_load_number		AS load_number
, SUM(arfile_amount)			AS collected_amount
, MIN(arfile_invoice_date)		AS earliest_collected_date
, MAX(arfile_invoice_date)		AS latest_collected_date
FROM silver.ibmi_arfile
INNER JOIN silver.vw_ibmi_unloading_order_list
ON order_load_number = arfile_load_number
WHERE arfile_record_type IN ('10','14') 
GROUP BY arfile_load_number
HAVING SUM(arfile_amount) > 1
) a
GROUP BY load_number