-- Auto Generated (Do not modify) A8E588A46457DE6C2EFC3BCD8C1D282B18DE65ADFF181C61B7CC13F531A55D24
CREATE   VIEW [silver].[vw_employee_hierarchy_levels]
AS
WITH J AS
(
    SELECT
        e.employee_id,
        e.employee_name,
        m1.employee_name AS L1,
        m2.employee_name AS L2,
        m3.employee_name AS L3,
        m4.employee_name AS L4,
        m5.employee_name AS L5,
        m6.employee_name AS L6,
        m7.employee_name AS L7,
        m8.employee_name AS L8,
        m9.employee_name AS L9,
        m10.employee_name AS L10
    FROM [data_central_wh].[silver].[vw_wd_worker_manager] e
    LEFT JOIN [data_central_wh].[silver].[vw_wd_worker_manager] m1 ON e.manager_employee_id = m1.employee_id
    LEFT JOIN [data_central_wh].[silver].[vw_wd_worker_manager] m2 ON m1.manager_employee_id = m2.employee_id
    LEFT JOIN [data_central_wh].[silver].[vw_wd_worker_manager] m3 ON m2.manager_employee_id = m3.employee_id
    LEFT JOIN [data_central_wh].[silver].[vw_wd_worker_manager] m4 ON m3.manager_employee_id = m4.employee_id
    LEFT JOIN [data_central_wh].[silver].[vw_wd_worker_manager] m5 ON m4.manager_employee_id = m5.employee_id
    LEFT JOIN [data_central_wh].[silver].[vw_wd_worker_manager] m6 ON m5.manager_employee_id = m6.employee_id
    LEFT JOIN [data_central_wh].[silver].[vw_wd_worker_manager] m7 ON m6.manager_employee_id = m7.employee_id
    LEFT JOIN [data_central_wh].[silver].[vw_wd_worker_manager] m8 ON m7.manager_employee_id = m8.employee_id
    LEFT JOIN [data_central_wh].[silver].[vw_wd_worker_manager] m9 ON m8.manager_employee_id = m9.employee_id
    LEFT JOIN [data_central_wh].[silver].[vw_wd_worker_manager] m10 ON m9.manager_employee_id = m10.employee_id
),
U AS
(
    -- managers
    SELECT employee_id, employee_name, lvl, name
    FROM J
    UNPIVOT (name FOR lvl IN (L1,L2,L3,L4,L5,L6,L7,L8,L9,L10)) u
    WHERE name IS NOT NULL

    UNION ALL

    -- append employee as last node
    SELECT employee_id, employee_name, 'E' AS lvl, employee_name AS name
    FROM J
),
R AS
(
    -- Order: CEO first (highest manager) ... then employee last
    SELECT
        employee_id,
        employee_name,
        name,
        ROW_NUMBER() OVER (PARTITION BY employee_id ORDER BY lvl DESC) AS rn
    FROM U
)
SELECT
    employee_id,
    employee_name,
    MAX(CASE WHEN rn = 1 THEN name END)  AS Level1,
    MAX(CASE WHEN rn = 2 THEN name END)  AS Level2,
    MAX(CASE WHEN rn = 3 THEN name END)  AS Level3,
    MAX(CASE WHEN rn = 4 THEN name END)  AS Level4,
    MAX(CASE WHEN rn = 5 THEN name END)  AS Level5,
    MAX(CASE WHEN rn = 6 THEN name END)  AS Level6,
    MAX(CASE WHEN rn = 7 THEN name END)  AS Level7,
    MAX(CASE WHEN rn = 8 THEN name END)  AS Level8,
    MAX(CASE WHEN rn = 9 THEN name END)  AS Level9,
    MAX(CASE WHEN rn = 10 THEN name END) AS Level10
FROM R
GROUP BY employee_id, employee_name;