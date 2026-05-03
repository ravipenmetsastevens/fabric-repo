-- Auto Generated (Do not modify) 1CEAD2D0272F24ABDEB1C2707CD9F9C69D496DB96B440A9D96D57A7C8DCFF020


CREATE         VIEW [gold].[vw_ibmi_edi_processing_history] AS

WITH 

latestactivity AS 
(SELECT 
    MAX(DATETIME2FROMPARTS(
        YEAR(a.edi_proc_hist_event_date), 
        MONTH(a.edi_proc_hist_event_date), 
        DAY(a.edi_proc_hist_event_date), 
        DATEPART(HOUR, a.edi_proc_hist_event_time), 
        DATEPART(MINUTE, a.edi_proc_hist_event_time), 
        0, 
        0,
        0
      ))                                                    AS latest_event_datetime
      , a.edi_proc_hist_customer_ship_number
FROM silver.ibmi_edi_processing_history a
GROUP BY a.edi_proc_hist_customer_ship_number),

base AS
(SELECT
    DATETIME2FROMPARTS(
        YEAR(b.edi_proc_hist_event_date), 
        MONTH(b.edi_proc_hist_event_date), 
        DAY(b.edi_proc_hist_event_date), 
        DATEPART(HOUR, b.edi_proc_hist_event_time), 
        DATEPART(MINUTE, b.edi_proc_hist_event_time), 
        0, 
        0,
        0
      )                                                    AS event_datetime
    , b. *
FROM silver.ibmi_edi_processing_history b)

SELECT b.* 
FROM base b
    INNER JOIN latestactivity a
        ON b.edi_proc_hist_customer_ship_number = a.edi_proc_hist_customer_ship_number
            AND b.event_datetime = a.latest_event_datetime
;