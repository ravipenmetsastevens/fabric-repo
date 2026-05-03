-- Auto Generated (Do not modify) E3EBD43508CF364891D0EF53B58D01B2CA844B3099C183DC26968C83BD882D53


CREATE         VIEW [gold].[vw_ibmi_edi_order_history] AS

WITH 

latestactivity AS 
(SELECT 
    MAX(DATETIME2FROMPARTS(
        YEAR(a.edi_ord_hist_tender_date), 
        MONTH(a.edi_ord_hist_tender_date), 
        DAY(a.edi_ord_hist_tender_date), 
        DATEPART(HOUR, a.edi_ord_hist_tender_time), 
        DATEPART(MINUTE, a.edi_ord_hist_tender_time), 
        0, 
        0,
        0
      ))                                                    AS latest_tender_datetime
      , a.edi_ord_hist_customer_order
FROM silver.ibmi_edi_order_history a
WHERE edi_ord_hist_creation_initials <> 'can'
GROUP BY a.edi_ord_hist_customer_order),

base AS
(SELECT
    DATETIME2FROMPARTS(
        YEAR(b.edi_ord_hist_tender_date), 
        MONTH(b.edi_ord_hist_tender_date), 
        DAY(b.edi_ord_hist_tender_date), 
        DATEPART(HOUR, b.edi_ord_hist_tender_time), 
        DATEPART(MINUTE, b.edi_ord_hist_tender_time), 
        0, 
        0,
        0
      )                                                    AS tender_datetime
    , b. *
FROM silver.ibmi_edi_order_history b
WHERE edi_ord_hist_creation_initials <> 'can')


SELECT b.* 
FROM base b
    INNER JOIN latestactivity a
        ON b.edi_ord_hist_customer_order = a.edi_ord_hist_customer_order
            AND b.tender_datetime = a.latest_tender_datetime
;