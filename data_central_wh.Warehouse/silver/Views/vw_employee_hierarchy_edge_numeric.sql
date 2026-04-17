-- Auto Generated (Do not modify) AFEF5DCB03BA0BEA924D742671FF7A98A720463D2AB4AD17E680BDB19495F603
CREATE   VIEW [silver].[vw_employee_hierarchy_edge_numeric]
AS
WITH ceo AS
(
    SELECT TOP (1)
        employee_id   AS ceo_employee_id,
        employee_name AS ceo_name
    FROM [data_central_wh].[silver].[vw_wd_worker_manager]
    WHERE employee_id = '1AARS'   -- CEO employee_id
),
src AS
(
    SELECT
        employee_id,
        employee_name,
        Level1, Level2, Level3, Level4, Level5,
        Level6, Level7, Level8, Level9, Level10
    FROM [data_central_wh].[silver].[vw_employee_hierarchy_levels]
    WHERE Level2 IS NOT NULL   -- inactive rule
),
src_plus_ceo AS
(
    -- Add CEO row if missing from src
    SELECT * FROM src

    UNION ALL
    SELECT
        c.ceo_employee_id AS employee_id,
        c.ceo_name        AS employee_name,
        c.ceo_name        AS Level1,
        NULL AS Level2, NULL AS Level3, NULL AS Level4, NULL AS Level5,
        NULL AS Level6, NULL AS Level7, NULL AS Level8, NULL AS Level9, NULL AS Level10
    FROM ceo c
    WHERE NOT EXISTS (SELECT 1 FROM src s WHERE s.employee_id = c.ceo_employee_id)
),
base AS
(
    SELECT
        s.*,
        c.ceo_name,
        CASE
            WHEN s.employee_id = c.ceo_employee_id THEN NULL

            WHEN s.Level10 IS NOT NULL THEN s.Level9
            WHEN s.Level9  IS NOT NULL THEN s.Level8
            WHEN s.Level8  IS NOT NULL THEN s.Level7
            WHEN s.Level7  IS NOT NULL THEN s.Level6
            WHEN s.Level6  IS NOT NULL THEN s.Level5
            WHEN s.Level5  IS NOT NULL THEN s.Level4
            WHEN s.Level4  IS NOT NULL THEN s.Level3
            WHEN s.Level3  IS NOT NULL THEN s.Level2
            WHEN s.Level2  IS NOT NULL THEN s.Level1
            ELSE c.ceo_name
        END AS ParentName
    FROM src_plus_ceo s
    CROSS JOIN ceo c
),
numbered AS
(
    -- Force CEO to be Id=1, then everyone else in hierarchy order
    SELECT
        b.*,
        ROW_NUMBER() OVER (
            ORDER BY
                CASE WHEN b.employee_id = (SELECT ceo_employee_id FROM ceo) THEN 0 ELSE 1 END,
                Level1, Level2, Level3, Level4, Level5,
                Level6, Level7, Level8, Level9, Level10,
                employee_id
        ) AS Id
    FROM base b
),
name_to_id AS
(
    SELECT employee_name AS Name, Id
    FROM numbered
)
SELECT
    n.Id,
    CASE
        WHEN n.employee_id = (SELECT ceo_employee_id FROM ceo) THEN NULL
        ELSE p.Id
    END AS Pid,
    n.employee_id,
    n.employee_name AS Name,
    n.ParentName    AS ManagerName,
    n.Level1, n.Level2, n.Level3, n.Level4, n.Level5,
    n.Level6, n.Level7, n.Level8, n.Level9, n.Level10
FROM numbered n
LEFT JOIN name_to_id p
    ON p.Name = n.ParentName;