-- Auto Generated (Do not modify) B2B09881A4D5AE21A279E23BF3719E734C9D54CAA6D47D923D445423EBDB8188
CREATE     VIEW [silver].[vw_wd_employee]
AS
SELECT
    w.run_id,
    w.extract_ts_utc,
    w.worker_wid,
    w.employee_id,
    w.worker_id,
    w.user_id,
    w.email,
    w.worker_descriptor,
    w.first_name,
    w.middle_name,
    w.last_name,

    wo.org_ref_id   AS sup_org_ref_id,
        o.org_code      AS sup_org_code,
    o.org_name      AS sup_org_name,

    o.inactive      AS sup_org_inactive,

    CASE WHEN o.inactive = '1' THEN 0 ELSE 1 END AS is_active,

    CONCAT(
      'https://fabricstoragescus.blob.core.windows.net/employee-photos/',
      w.employee_id,
      '.jpg',
      '?sp=r&st=2026-02-06T14:16:30Z&se=2026-12-31T22:31:30Z&spr=https&sv=2024-11-04&sr=c&sig=MHJWT1i61%2FCkS3L%2FVQJOfTdK%2FqJC1e4o8vtS9i1EEio%3D'
    ) AS photo_url
FROM [data_central_lh].[dbo].[wd_worker_bronze] w
LEFT JOIN [data_central_lh].[dbo].[wd_worker_sup_org_bronze] wo
    ON w.employee_id = wo.employee_id
LEFT JOIN [data_central_lh].[dbo].[wd_sup_org_bronze] o
    ON wo.org_ref_id = o.org_ref_id
LEFT JOIN [data_central_lh].[dbo].[wd_employee_photo_meta_bronze] p
    ON p.employee_id = w.employee_id;