-- Auto Generated (Do not modify) F75CD52CA9D116408A70497AFE72D907FE3C494D71320787933709DD4BD9A6FA
CREATE   View [silver].[vw_wd_org_manager] AS
SELECT
    o.org_ref_id,
    o.org_code,
    o.org_name,
    o.org_type_id,
    o.org_subtype_id,
    o.inactive,
    o.last_updated_datetime,

    o.manager_employee_id,
    o.manager_wid,

    w.worker_descriptor AS manager_name,
    w.user_id           AS manager_user_id,
    w.email             AS manager_email
FROM [data_central_lh].[dbo].[wd_sup_org_bronze] o
LEFT JOIN [data_central_lh].[dbo].[wd_worker_bronze] w
  ON o.manager_employee_id = w.employee_id;