-- Auto Generated (Do not modify) 6CEB43A792518505B8C3380A790BEC1B07A2B3AD59F1C124C5A5CF19ED8E3F54

CREATE VIEW gold.vw_fact_risk_accident_details AS
SELECT
	  c1.claim_mast_record_code
	, c1.claim_mast_claim_number
	, c1.claim_mast_occurance_date
	, c1.claim_mast_occurance_datetime
	, c1.claim_mast_truck_number
	, d1.involved_drv_driver_code
	, d1.involved_drv_dm_code
	, p1.order_policy_load_number
	, p1.order_policy_dispatch
	, a1.accident_desc_description
	, t1.is_accident_or_incident
	, t1.is_dot_reportable
	, t1.is_preventable
	, t1.trans_mast_dm_code
	, t1.trans_mast_dmol_code
	, a2.accident_type_description
	, a2.accident_type_category
	, c2.reserve_ttl_reserve_total_amount
	, c2.reserve_ttl_paid_loss_total_amount
	, c2.reserve_ttl_paid_expense_total_amount
	, c2.reserve_ttl_recovered_total_amount
FROM
	silver.risk_claim_master c1
		INNER JOIN silver.risk_claim_reserve_total c2 
			ON c1.claim_mast_record_code = c2.reserve_ttl_claim_record_code
		INNER JOIN silver.risk_order_policy p1
			ON c1.claim_mast_record_code = p1.order_policy_claim_record_code
		INNER JOIN silver.risk_accident_description a1
			ON c1.claim_mast_record_code = a1.accident_desc_claim_record_code
		INNER JOIN silver.risk_transportation_master t1
			ON c1.claim_mast_record_code = t1.trans_mast_claim_record_code
		INNER JOIN silver.risk_involved_driver d1
			ON c1.claim_mast_record_code = d1.involved_drv_claim_record_code
		INNER JOIN silver.risk_accident_type_master a2
			ON t1.trans_mast_accident_type_code = a2.accident_type_code