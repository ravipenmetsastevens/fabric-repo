-- Auto Generated (Do not modify) 3D54B196F270C50978BCF77503223C9C0DEC40F3CF30719882D902B6BD5A3A6F
CREATE   VIEW [gold].[vw_ibmi_utlfile_min_record_date]
AS
SELECT
    utlfile_driver_code,
    CAST(MIN(utlfile_record_date) AS date) AS min_record_date
FROM
    [data_central_wh].[gold].[vw_ibmi_utlfile]
WHERE
    (utlfile_training_level_code = '' OR utlfile_training_level_code IS NULL)
    AND (utlfile_driver_code IS NOT NULL AND LTRIM(RTRIM(utlfile_driver_code)) <> '')
    AND utlfile_record_date IS NOT NULL
GROUP BY
    utlfile_driver_code;