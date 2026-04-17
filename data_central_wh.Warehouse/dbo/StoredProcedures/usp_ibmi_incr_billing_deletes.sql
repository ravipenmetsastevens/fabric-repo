CREATE   PROCEDURE dbo.usp_ibmi_incr_billing_deletes
AS
BEGIN
    -- ibmi_incr_billing
    UPDATE TGT
    SET  TGT.is_deleted = CASE WHEN L.[ORDER] IS NULL THEN 0 ELSE 1 END
    FROM silver.ibmi_incr_billing AS TGT
    LEFT JOIN (
        SELECT DISTINCT [ORDER], [SEQ], [RCDCNT]
        FROM data_central_lh.dbo.ibmi_ord_bill_change_log
        WHERE [JOOBJ] = 'BILLING'
    ) AS L
      ON  L.[ORDER]  = TGT.billing_load_number
      AND L.[SEQ]    = TGT.billing_sequence_number
      AND L.[RCDCNT] = TGT.billing_record_number
    WHERE (L.[ORDER] IS NULL  AND (TGT.is_deleted IS NULL OR TGT.is_deleted <> 0))
       OR (L.[ORDER] IS NOT NULL AND (TGT.is_deleted IS NULL OR TGT.is_deleted <> 1));

    -- ibmi_incr_cd_billing
    UPDATE TGT
    SET  TGT.is_deleted = CASE WHEN L.[ORDER] IS NULL THEN 0 ELSE 1 END
    FROM silver.ibmi_incr_cd_billing AS TGT
    LEFT JOIN (
        SELECT DISTINCT [ORDER], [SEQ], [RCDCNT]
        FROM data_central_lh.dbo.ibmi_ord_bill_change_log
        WHERE [JOOBJ] = 'BILLING'
    ) AS L
      ON  L.[ORDER]  = TGT.cd_billing_load_number
      AND L.[SEQ]    = TGT.cd_billing_sequence_number
      AND L.[RCDCNT] = TGT.cd_billing_record_number
    WHERE (L.[ORDER] IS NULL  AND (TGT.is_deleted IS NULL OR TGT.is_deleted <> 0))
       OR (L.[ORDER] IS NOT NULL AND (TGT.is_deleted IS NULL OR TGT.is_deleted <> 1));

    -- ibmi_incr_tlb_billing
    UPDATE TGT
    SET  TGT.is_deleted = CASE WHEN L.[ORDER] IS NULL THEN 0 ELSE 1 END
    FROM silver.ibmi_incr_tlb_billing AS TGT
    LEFT JOIN (
        SELECT DISTINCT [ORDER], [SEQ], [RCDCNT]
        FROM data_central_lh.dbo.ibmi_ord_bill_change_log
        WHERE [JOOBJ] = 'BILLING'
    ) AS L
      ON  L.[ORDER]  = TGT.tlb_billing_load_number
      AND L.[SEQ]    = TGT.tlb_billing_sequence_number
      AND L.[RCDCNT] = TGT.tlb_billing_record_number
    WHERE (L.[ORDER] IS NULL  AND (TGT.is_deleted IS NULL OR TGT.is_deleted <> 0))
       OR (L.[ORDER] IS NOT NULL AND (TGT.is_deleted IS NULL OR TGT.is_deleted <> 1));
END;