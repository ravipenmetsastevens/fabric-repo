-- Auto Generated (Do not modify) 5B1BE520E1BF880E9F6BF7ACCAAA52D7FBFCACF9926DBB03F0AFF839F3865895
CREATE   VIEW [silver].[vw_employee_hierarchy_edge_numeric_active]
AS
WITH active AS
(
    SELECT *
    FROM [data_central_wh].[silver].[vw_employee_hierarchy_levels]
    WHERE Level2 IS NOT NULL
),
keys AS
(
    SELECT
        employee_id,
        ROW_NUMBER() OVER (
            ORDER BY
                Level1, Level2, Level3, Level4, Level5,
                Level6, Level7, Level8, Level9, Level10,
                employee_id
        ) AS Id
    FROM active
)
SELECT
    k.Id                    AS Id,
    km.Id                   AS Pid,
    e.employee_id,
    e.employee_name         AS Name,
    e.manager_employee_id,
    e.manager_name,
    e.supervisory_org_ref_id
FROM [data_central_wh].[silver].[vw_wd_worker_manager] e
JOIN keys k
  ON e.employee_id = k.employee_id
LEFT JOIN keys km
  ON e.manager_employee_id = km.employee_id;