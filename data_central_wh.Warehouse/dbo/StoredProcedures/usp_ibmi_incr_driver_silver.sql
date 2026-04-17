CREATE   PROCEDURE [dbo].[usp_ibmi_incr_driver_silver]
AS
BEGIN
    SET NOCOUNT ON;

    IF OBJECT_ID('tempdb..#DRV_Deduped','U') IS NOT NULL DROP TABLE #DRV_Deduped;

    WITH Prep AS (
        SELECT
            TRIM(a.DRCODE) AS drv_code,
            TRIM(a.DRNAME) AS drv_full_name,
            CASE WHEN CHARINDEX(',', TRIM(a.DRNAME)) > 1
                 THEN LEFT(TRIM(a.DRNAME), CHARINDEX(',', TRIM(a.DRNAME)) - 1)
                 ELSE TRIM(a.DRNAME) END                                           AS drv_last_name,
            CASE WHEN CHARINDEX(',', TRIM(a.DRNAME)) > 1
                 THEN RIGHT(TRIM(a.DRNAME), LEN(TRIM(a.DRNAME)) - CHARINDEX(',', TRIM(a.DRNAME)))
                 ELSE TRIM(a.DRNAME) END                                           AS drv_first_name,
            TRIM(a.DRSHNM)                                                         AS drv_short_name,
            TRIM(a.DRADD)                                                          AS drv_address_line_1,
            TRIM(a.DRCITY)                                                         AS drv_address_city,
            TRIM(a.DRST)                                                           AS drv_address_state,
            TRIM(a.DRZIP)                                                          AS drv_address_zip,
            TRIM(a.DRZP2)                                                          AS drv_address_zip_extn,
            CONVERT(VARCHAR(10), a.DRAC)                                           AS drv_area_code,
            CONVERT(VARCHAR(20), a.DRPHON)                                         AS drv_phone_number,
            TRIM(a.DRSS)                                                           AS drv_social_security,
            TRIM(a.DRSUPR)                                                         AS drv_dm_code,
            TRIM(a.DRFMGR)                                                         AS drv_dmol_code,
            DRCRED.date_key_pk                                                     AS drv_create_date,
            CASE WHEN LEN(TRIM(a.DRCRET)) > 0
                 THEN CONVERT(TIME(0), CONCAT(LEFT(a.DRCRET,2),':',RIGHT(a.DRCRET,2)))
                 ELSE NULL END                                                     AS drv_create_time,
            TRIM(a.DRCREI)                                                         AS drv_create_initial,
            DRUPDD.date_key_pk                                                     AS drv_update_date,
            CASE WHEN LEN(TRIM(a.DRUPDT)) > 0
                 THEN CONVERT(TIME(0), CONCAT(LEFT(a.DRUPDT,2),':',RIGHT(a.DRUPDT,2)))
                 ELSE NULL END                                                     AS drv_update_time,
            TRIM(a.DRUPDI)                                                         AS drv_update_initial,

            CAST(NULL AS VARCHAR(50))                                              AS drv_company,
            CAST(NULL AS VARCHAR(50))                                              AS drv_division,
            CAST(NULL AS VARCHAR(50))                                              AS drv_terminal_number,

            DRBDAT.date_key_pk                                                     AS drv_birth_date,
            DRHDAT.date_key_pk                                                     AS drv_hire_date,
            DRRDAT.date_key_pk                                                     AS drv_review_date,
            DRTDAT.date_key_pk                                                     AS drv_termination_date,
            DRLEXP.date_key_pk                                                     AS drv_license_expiry_date,
            DRPEXP.date_key_pk                                                     AS drv_physical_expiry_date,
            TRIM(LEFT(a.DRLICE, 23))                                               AS drv_license_number,
            CASE WHEN LEN(a.DRLICE) > 23
                 THEN TRIM(RIGHT(a.DRLICE, LEN(a.DRLICE) - 23))
                 ELSE 'unknown' END                                                AS drv_license_state,
            CASE a.DRTYPE WHEN 0 THEN 'COMPANY' WHEN 1 THEN 'OWNER' ELSE 'unknown' END AS drv_type,
            CASE WHEN LEN(TRIM(a.DRSTAT)) = 0 OR a.DRSTAT IS NULL THEN 'unknown' ELSE a.DRSTAT END AS drv_status,
            CASE WHEN LEN(TRIM(a.DRPRVO)) = 0 OR a.DRPRVO IS NULL THEN 'unknown' ELSE a.DRPRVO END AS drv_previous_order,
            CASE WHEN LEN(TRIM(a.DRPDSP)) = 0 OR a.DRPDSP IS NULL THEN 'unknown' ELSE a.DRPDSP END AS drv_previous_dispatch,

            'unknown'                                                              AS drv_current_order,

            CASE WHEN LEN(TRIM(a.DRDISP)) = 0 OR a.DRDISP IS NULL THEN 'unknown' ELSE a.DRDISP END AS drv_current_dispatch,
            CASE WHEN LEN(TRIM(a.DRUNIT)) = 0 OR a.DRUNIT IS NULL THEN 'unknown' ELSE a.DRUNIT END AS drv_assigned_truck,
            CASE WHEN LEN(TRIM(a.DRDCTY)) = 0 OR a.DRDCTY IS NULL THEN 'unknown' ELSE a.DRDCTY END AS drv_dispatch_city,
            CASE WHEN LEN(TRIM(a.DRDST)) = 0 OR a.DRDST IS NULL THEN 'unknown' ELSE a.DRDST END    AS drv_dispatch_state,
            CONCAT(a.DRDST, a.DRDCTY)                                                AS drv_dispatch_city_code,
            CASE WHEN TRIM(a.DRMSG) = 'Y' THEN 'TRUE' ELSE 'FALSE' END              AS has_drv_messages,
            CASE WHEN TRIM(a.DRDLT) = 'D' THEN 'TRUE' ELSE 'FALSE' END              AS is_drv_deleted,
            TRIM(a.DRENAM)                                                          AS drv_emerg_contact_name,
            TRIM(a.DRENUM)                                                          AS drv_emerg_contact_phone,
            CASE WHEN TRIM(a.DRPHAZ) = '' THEN 'none' ELSE TRIM(a.DRPHAZ) END       AS drv_hazard_permit,
            TRIM(a.DRNUNT)                                                          AS drv_normal_unit,
            TRIM(a.DRSPS)                                                           AS drv_spouse,
            TRIM(a.DRMISC)                                                          AS drv_misc_info,
            TRIM(a.DRFC)                                                            AS drv_fund_code,
            CONCAT(RIGHT(TRIM(a.DRHOME),2), LEFT(TRIM(a.DRHOME),4))                 AS drv_home_city_code,
            CASE WHEN LEN(TRIM(a.DRVOIC)) = 0 OR a.DRVOIC IS NULL THEN 'unknown' ELSE a.DRVOIC END AS drv_voice_box,
            CASE TRIM(a.DRJIT) WHEN 'N' THEN 'False' WHEN 'Y' THEN 'True' ELSE 'unknown' END       AS is_jit_drv,
            TRIM(a.DRTRAN)                                                          AS is_trainee_drv,
            a.DRDBAL                                                                AS drv_adv_balance,
            a.DRCBAL                                                                AS drv_company_adv_balance,
            a.DRMBPW                                                                AS drv_mailbox_pwd,
            a.DRLPAY                                                                AS drv_last_pay_amount,
            TRIM(a.DRCARD)                                                          AS drv_fuel_card,
            DRSOLO.date_key_pk                                                      AS drv_grad_date,
            CASE TRIM(a.DRSMKR) WHEN 'N' THEN 'False' WHEN 'Y' THEN 'True' ELSE 'unknown' END      AS is_drv_smoker,
            CASE WHEN LEN(TRIM(a.DRRACE)) = 0 OR a.DRRACE IS NULL THEN 'unknown' ELSE a.DRRACE END AS drv_race,
            CASE TRIM(a.DRSEX) WHEN 'M' THEN 'MALE' WHEN 'F' THEN 'FEMALE' ELSE 'unknown' END      AS drv_gender,
            CASE TRIM(a.DRLONG) WHEN 'N' THEN 'False' WHEN 'Y' THEN 'True' ELSE 'unknown' END      AS has_longevity,
            DRLGDT.date_key_pk                                                      AS drv_longevity_date,
            TRIM(a.DRTYCD)                                                          AS drv_cell_area_code,
            TRIM(a.DRTERM)                                                          AS drv_cell_number,
            a.loadDate,
            a.recordNumber
        FROM data_central_lh.dbo.ibmi_incr_drivers a
        LEFT JOIN gold.dim_date DRCRED ON a.DRCRED = DRCRED.date_ordinal
        LEFT JOIN gold.dim_date DRUPDD ON a.DRUPDD = DRUPDD.date_ordinal
        LEFT JOIN gold.dim_date DRBDAT ON a.DRBDAT = DRBDAT.date_ordinal
        LEFT JOIN gold.dim_date DRHDAT ON a.DRHDAT = DRHDAT.date_ordinal
        LEFT JOIN gold.dim_date DRRDAT ON a.DRRDAT = DRRDAT.date_ordinal
        LEFT JOIN gold.dim_date DRTDAT ON a.DRTDAT = DRTDAT.date_ordinal
        LEFT JOIN gold.dim_date DRLEXP ON a.DRLEXP = DRLEXP.date_ordinal
        LEFT JOIN gold.dim_date DRPEXP ON a.DRPEXP = DRPEXP.date_ordinal
        LEFT JOIN gold.dim_date DRLGDT ON a.DRLGDT = DRLGDT.date_ordinal
        LEFT JOIN gold.dim_date DRSOLO ON a.DRSOLO = DRSOLO.date_ordinal
    )
    SELECT *
    INTO #DRV_Deduped
    FROM (
        SELECT p.*,
               ROW_NUMBER() OVER (
                   PARTITION BY p.drv_code, p.drv_social_security
                   ORDER BY p.loadDate DESC, p.recordNumber DESC
               ) AS rn
        FROM Prep p
    ) x
    WHERE x.rn = 1;

    /* UPDATE existing records */
    UPDATE T
       SET T.drv_full_name           = S.drv_full_name,
           T.drv_last_name           = S.drv_last_name,
           T.drv_first_name          = S.drv_first_name,
           T.drv_short_name          = S.drv_short_name,
           T.drv_address_line_1      = S.drv_address_line_1,
           T.drv_address_city        = S.drv_address_city,
           T.drv_address_state       = S.drv_address_state,
           T.drv_address_zip         = S.drv_address_zip,
           T.drv_address_zip_extn    = S.drv_address_zip_extn,
           T.drv_area_code           = S.drv_area_code,
           T.drv_phone_number        = S.drv_phone_number,
           T.drv_dm_code             = S.drv_dm_code,
           T.drv_dmol_code           = S.drv_dmol_code,
           T.drv_create_date         = S.drv_create_date,
           T.drv_create_time         = S.drv_create_time,
           T.drv_create_initial      = S.drv_create_initial,
           T.drv_update_date         = S.drv_update_date,
           T.drv_update_time         = S.drv_update_time,
           T.drv_update_initial      = S.drv_update_initial,
           T.drv_company             = S.drv_company,
           T.drv_division            = S.drv_division,
           T.drv_terminal_number     = S.drv_terminal_number,
           T.drv_birth_date          = S.drv_birth_date,
           T.drv_hire_date           = S.drv_hire_date,
           T.drv_review_date         = S.drv_review_date,
           T.drv_termination_date    = S.drv_termination_date,
           T.drv_license_expiry_date = S.drv_license_expiry_date,
           T.drv_physical_expiry_date= S.drv_physical_expiry_date,
           T.drv_license_number      = S.drv_license_number,
           T.drv_license_state       = S.drv_license_state,
           T.drv_type                = S.drv_type,
           T.drv_status              = S.drv_status,
           T.drv_previous_order      = S.drv_previous_order,
           T.drv_previous_dispatch   = S.drv_previous_dispatch,
           T.drv_current_order       = S.drv_current_order,
           T.drv_current_dispatch    = S.drv_current_dispatch,
           T.drv_assigned_truck      = S.drv_assigned_truck,
           T.drv_dispatch_city       = S.drv_dispatch_city,
           T.drv_dispatch_state      = S.drv_dispatch_state,
           T.drv_dispatch_city_code  = S.drv_dispatch_city_code,
           T.has_drv_messages        = S.has_drv_messages,
           T.is_drv_deleted          = S.is_drv_deleted,
           T.drv_emerg_contact_name  = S.drv_emerg_contact_name,
           T.drv_emerg_contact_phone = S.drv_emerg_contact_phone,
           T.drv_hazard_permit       = S.drv_hazard_permit,
           T.drv_normal_unit         = S.drv_normal_unit,
           T.drv_spouse              = S.drv_spouse,
           T.drv_misc_info           = S.drv_misc_info,
           T.drv_fund_code           = S.drv_fund_code,
           T.drv_home_city_code      = S.drv_home_city_code,
           T.drv_voice_box           = S.drv_voice_box,
           T.is_jit_drv              = S.is_jit_drv,
           T.is_trainee_drv          = S.is_trainee_drv,
           T.drv_adv_balance         = S.drv_adv_balance,
           T.drv_company_adv_balance = S.drv_company_adv_balance,
           T.drv_mailbox_pwd         = S.drv_mailbox_pwd,
           T.drv_last_pay_amount     = S.drv_last_pay_amount,
           T.drv_fuel_card           = S.drv_fuel_card,
           T.drv_grad_date           = S.drv_grad_date,
           T.is_drv_smoker           = S.is_drv_smoker,
           T.drv_race                = S.drv_race,
           T.drv_gender              = S.drv_gender,
           T.has_longevity           = S.has_longevity,
           T.drv_longevity_date      = S.drv_longevity_date,
           T.drv_cell_area_code      = S.drv_cell_area_code,
           T.drv_cell_number         = S.drv_cell_number
    FROM silver.ibmi_driver T
    JOIN #DRV_Deduped S
      ON T.drv_code            = S.drv_code
     AND T.drv_social_security = S.drv_social_security;

    /* INSERT new records */
    INSERT INTO silver.ibmi_driver
    (
        drv_code, drv_full_name, drv_last_name, drv_first_name, drv_short_name,
        drv_address_line_1, drv_address_city, drv_address_state, drv_address_zip, drv_address_zip_extn,
        drv_area_code, drv_phone_number, drv_social_security, drv_dm_code, drv_dmol_code,
        drv_create_date, drv_create_time, drv_create_initial, drv_update_date, drv_update_time, drv_update_initial,
        drv_company, drv_division, drv_terminal_number, drv_birth_date, drv_hire_date, drv_review_date,
        drv_termination_date, drv_license_expiry_date, drv_physical_expiry_date, drv_license_number, drv_license_state,
        drv_type, drv_status, drv_previous_order, drv_previous_dispatch, drv_current_order, drv_current_dispatch,
        drv_assigned_truck, drv_dispatch_city, drv_dispatch_state, drv_dispatch_city_code,
        has_drv_messages, is_drv_deleted, drv_emerg_contact_name, drv_emerg_contact_phone, drv_hazard_permit,
        drv_normal_unit, drv_spouse, drv_misc_info, drv_fund_code, drv_home_city_code, drv_voice_box,
        is_jit_drv, is_trainee_drv, drv_adv_balance, drv_company_adv_balance, drv_mailbox_pwd, drv_last_pay_amount,
        drv_fuel_card, drv_grad_date, is_drv_smoker, drv_race, drv_gender, has_longevity, drv_longevity_date,
        drv_cell_area_code, drv_cell_number
    )
    SELECT
        S.drv_code, S.drv_full_name, S.drv_last_name, S.drv_first_name, S.drv_short_name,
        S.drv_address_line_1, S.drv_address_city, S.drv_address_state, S.drv_address_zip, S.drv_address_zip_extn,
        S.drv_area_code, S.drv_phone_number, S.drv_social_security, S.drv_dm_code, S.drv_dmol_code,
        S.drv_create_date, S.drv_create_time, S.drv_create_initial, S.drv_update_date, S.drv_update_time, S.drv_update_initial,
        S.drv_company, S.drv_division, S.drv_terminal_number, S.drv_birth_date, S.drv_hire_date, S.drv_review_date,
        S.drv_termination_date, S.drv_license_expiry_date, S.drv_physical_expiry_date, S.drv_license_number, S.drv_license_state,
        S.drv_type, S.drv_status, S.drv_previous_order, S.drv_previous_dispatch, S.drv_current_order, S.drv_current_dispatch,
        S.drv_assigned_truck, S.drv_dispatch_city, S.drv_dispatch_state, S.drv_dispatch_city_code,
        S.has_drv_messages, S.is_drv_deleted, S.drv_emerg_contact_name, S.drv_emerg_contact_phone, S.drv_hazard_permit,
        S.drv_normal_unit, S.drv_spouse, S.drv_misc_info, S.drv_fund_code, S.drv_home_city_code, S.drv_voice_box,
        S.is_jit_drv, S.is_trainee_drv, S.drv_adv_balance, S.drv_company_adv_balance, S.drv_mailbox_pwd, S.drv_last_pay_amount,
        S.drv_fuel_card, S.drv_grad_date, S.is_drv_smoker, S.drv_race, S.drv_gender, S.has_longevity, S.drv_longevity_date,
        S.drv_cell_area_code, S.drv_cell_number
    FROM #DRV_Deduped S
    WHERE NOT EXISTS (
        SELECT 1
        FROM silver.ibmi_driver T
        WHERE T.drv_code            = S.drv_code
          AND T.drv_social_security = S.drv_social_security
    );

    DROP TABLE #DRV_Deduped;
END;