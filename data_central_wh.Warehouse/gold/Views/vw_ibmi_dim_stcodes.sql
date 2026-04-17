-- Auto Generated (Do not modify) 41FF1F2FC8C85520483DD8889CABC7F5A803DDF1E5F6D90DDBE45B5E771F4E98


CREATE   VIEW gold.vw_ibmi_dim_stcodes AS
SELECT
    stcodes_settlement_code,
    LEFT(stcodes_description, 15) AS stcodes_description_trimmed,
    stcodes_description,
    stcodes_credit_account_number,
    stcodes_debit_account_number,
    stcodes_settlement_type,
    stcodes_deduction_code,
    is_active
FROM silver.ibmi_stcodes;