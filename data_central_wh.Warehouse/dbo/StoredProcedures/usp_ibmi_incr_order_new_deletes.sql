CREATE       PROCEDURE dbo.usp_ibmi_incr_order_new_deletes
AS
BEGIN
    -- ibmi_incr_order_new
    UPDATE TGT
    SET    TGT.is_deleted = CASE WHEN L.[ORDER] IS NULL THEN 0 ELSE 1 END
    FROM   silver.ibmi_incr_order_new AS TGT
    LEFT   JOIN (
        SELECT DISTINCT [ORDER]
        FROM data_central_lh.dbo.ibmi_ord_bill_change_log
        WHERE [JOOBJ] = 'ORDER' AND [JOLIB] = 'I93FILE'
    ) AS L
      ON L.[ORDER] = TGT.order_load_number
    WHERE  (L.[ORDER] IS NULL  AND (TGT.is_deleted IS NULL OR TGT.is_deleted <> 0))
       OR  (L.[ORDER] IS NOT NULL AND (TGT.is_deleted IS NULL OR TGT.is_deleted <> 1));

    -- ibmi_incr_cd_order_new
    UPDATE TGT
    SET    TGT.is_deleted = CASE WHEN L.[ORDER] IS NULL THEN 0 ELSE 1 END
    FROM   silver.ibmi_incr_cd_order_new AS TGT
    LEFT   JOIN (
        SELECT DISTINCT [ORDER]
        FROM data_central_lh.dbo.ibmi_ord_bill_change_log
        WHERE [JOOBJ] = 'ORDER' AND [JOLIB] = 'CDFILE'
    ) AS L
      ON L.[ORDER] = TGT.cd_order_load_number
    WHERE  (L.[ORDER] IS NULL  AND (TGT.is_deleted IS NULL OR TGT.is_deleted <> 0))
       OR  (L.[ORDER] IS NOT NULL AND (TGT.is_deleted IS NULL OR TGT.is_deleted <> 1));

    -- ibmi_incr_tlb_order_new
    UPDATE TGT
    SET    TGT.is_deleted = CASE WHEN L.[ORDER] IS NULL THEN 0 ELSE 1 END
    FROM   silver.ibmi_incr_tlb_order_new AS TGT
    LEFT   JOIN (
        SELECT DISTINCT [ORDER]
        FROM data_central_lh.dbo.ibmi_ord_bill_change_log
        WHERE [JOOBJ] = 'ORDER' AND [JOLIB] = 'TLBFILE'
    ) AS L
      ON L.[ORDER] = TGT.tlb_order_load_number
    WHERE  (L.[ORDER] IS NULL  AND (TGT.is_deleted IS NULL OR TGT.is_deleted <> 0))
       OR  (L.[ORDER] IS NOT NULL AND (TGT.is_deleted IS NULL OR TGT.is_deleted <> 1));
END;