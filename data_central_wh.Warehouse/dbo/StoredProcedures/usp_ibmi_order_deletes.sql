CREATE       PROCEDURE dbo.usp_ibmi_order_deletes
AS
BEGIN
    -- ibmi_order
    UPDATE TGT
    SET    TGT.is_deleted = CASE WHEN L.[ORDER] IS NULL THEN 0 ELSE 1 END
    FROM   silver.ibmi_order AS TGT
    LEFT   JOIN (
        SELECT DISTINCT [ORDER]
        FROM data_central_lh.dbo.ibmi_ord_bill_change_log
        WHERE [JOOBJ] = 'ORDER' AND [JOLIB] = 'I93FILE'
    ) AS L
      ON L.[ORDER] = TGT.order_load_number
    WHERE  (L.[ORDER] IS NULL  AND (TGT.is_deleted IS NULL OR TGT.is_deleted <> 0))
       OR  (L.[ORDER] IS NOT NULL AND (TGT.is_deleted IS NULL OR TGT.is_deleted <> 1));

    -- ibmi_cd_order
    UPDATE TGT
    SET    TGT.is_deleted = CASE WHEN L.[ORDER] IS NULL THEN 0 ELSE 1 END
    FROM   silver.ibmi_cd_order AS TGT
    LEFT   JOIN (
        SELECT DISTINCT [ORDER]
        FROM data_central_lh.dbo.ibmi_ord_bill_change_log
        WHERE [JOOBJ] = 'ORDER' AND [JOLIB] = 'CDFILE'
    ) AS L
      ON L.[ORDER] = TGT.cd_order_load_number
    WHERE  (L.[ORDER] IS NULL  AND (TGT.is_deleted IS NULL OR TGT.is_deleted <> 0))
       OR  (L.[ORDER] IS NOT NULL AND (TGT.is_deleted IS NULL OR TGT.is_deleted <> 1));

    -- ibmi_tlb_order
    UPDATE TGT
    SET    TGT.is_deleted = CASE WHEN L.[ORDER] IS NULL THEN 0 ELSE 1 END
    FROM   silver.ibmi_tlb_order AS TGT
    LEFT   JOIN (
        SELECT DISTINCT [ORDER]
        FROM data_central_lh.dbo.ibmi_ord_bill_change_log
        WHERE [JOOBJ] = 'ORDER' AND [JOLIB] = 'TLBFILE'
    ) AS L
      ON L.[ORDER] = TGT.tlb_order_load_number
    WHERE  (L.[ORDER] IS NULL  AND (TGT.is_deleted IS NULL OR TGT.is_deleted <> 0))
       OR  (L.[ORDER] IS NOT NULL AND (TGT.is_deleted IS NULL OR TGT.is_deleted <> 1));
END;