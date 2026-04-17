-- Auto Generated (Do not modify) 06E772C46E70355CC199585C152119AC840727165F13592CEF7BD014791C8CEA
CREATE    VIEW [silver].[vw_wd_worker_manager] AS
SELECT
    w.employee_id,
    w.worker_wid,
    w.worker_descriptor            AS employee_name,
    w.user_id                      AS employee_user_id,
    w.email                        AS employee_email,

    e.manager_employee_id,
    e.manager_wid,

    mw.worker_descriptor           AS manager_name,
    mw.user_id                     AS manager_user_id,
    mw.email                       AS manager_email,

    e.org_ref_id                   AS supervisory_org_ref_id
FROM [data_central_lh].[dbo].[wd_worker_bronze] w
LEFT JOIN [data_central_lh].[dbo].[wd_worker_manager_edge_bronze] e
  ON w.employee_id = e.employee_id
LEFT JOIN [data_central_lh].[dbo].[wd_worker_bronze] mw
  ON e.manager_employee_id = mw.employee_id;