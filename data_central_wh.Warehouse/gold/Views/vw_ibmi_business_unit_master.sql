-- Auto Generated (Do not modify) 37EF2B803D3F411C8E4BD8D1FBCC45E94E33C54AAFEF860C4A48979E9E46D756
CREATE   VIEW gold.vw_ibmi_business_unit_master AS
SELECT
    business_unit_class,
    business_unit_description,
    business_unit_code
FROM silver.ibmi_business_unit_master;