-- Auto Generated (Do not modify) 340545875A30C76ECFDDA74C74CDD6BBBED09E6F6BA3684F6132AD447E550752

CREATE     VIEW [gold].[vw_ibmi_dim_pay] AS
SELECT
    pc.payclass_class_code              AS pay_class_code,
    pc.payclass_description             AS pay_class_description,
    pc.payclass_bucket_code,
    pc.is_income_taxable,
    pc.payclass_expense_account_number,
    pp.paypo_type_code,
    pp.paypo_category,
    pp.paypo_description,
    pp.paypo_pay_type,
    pp.paypo_credit_gl_account,
    pp.paypo_divisions,
    pp.paypo_max_limit_l2,
    pp.paypo_max_limit_l3,
    pp.paypo_pay_rate,
    pp.paypo_gl_account_number,
    pp.paypo_normal_rate,
    pp.paypo_max_amount,
    pp.paypo_min_amount,
    pp.can_override_limit,
    pp.is_split_for_teams,
    pp.is_taxable
FROM silver.ibmi_payclass AS pc
LEFT JOIN 
(SELECT * FROM silver.ibmi_paypo 
WHERE is_deleted = 'FALSE') AS pp
    ON pc.payclass_class_code = pp.paypo_pay_class_code
;