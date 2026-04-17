CREATE   PROCEDURE dbo.usp_ibmi_incr_settlement_revenue_history_silver
AS
BEGIN
    SET NOCOUNT ON;

    WITH Prep AS (
        SELECT
              TRIM(a.SROWN)  AS set_rev_hist_owner_code,
              TRIM(a.SRUNIT) AS set_rev_hist_truck_number,
              TRIM(a.SRORD)  AS set_rev_hist_load_number,
              TRIM(a.SRDISP) AS set_rev_hist_dispatch_number,
              a.SRSEQ        AS set_rev_hist_sequence_number,
              a.loadDate,
              a.recordNumber
        FROM data_central_lh.dbo.ibmi_incr_settlement_revenue_history_bronze a
    ),
    Deduped AS (
        SELECT
              p.set_rev_hist_owner_code,
              p.set_rev_hist_truck_number,
              p.set_rev_hist_load_number,
              p.set_rev_hist_dispatch_number,
              p.set_rev_hist_sequence_number,
              ROW_NUMBER() OVER (
                  PARTITION BY
                      p.set_rev_hist_owner_code,
                      p.set_rev_hist_truck_number,
                      p.set_rev_hist_load_number,
                      p.set_rev_hist_dispatch_number,
                      p.set_rev_hist_sequence_number
                  ORDER BY p.loadDate DESC, p.recordNumber DESC
              ) AS rn
        FROM Prep p
    )
    INSERT INTO silver.ibmi_settlement_revenue_history
    (
          set_rev_hist_owner_code,
          set_rev_hist_truck_number,
          set_rev_hist_load_number,
          set_rev_hist_dispatch_number,
          set_rev_hist_sequence_number
    )
    SELECT
          d.set_rev_hist_owner_code,
          d.set_rev_hist_truck_number,
          d.set_rev_hist_load_number,
          d.set_rev_hist_dispatch_number,
          d.set_rev_hist_sequence_number
    FROM Deduped d
    WHERE d.rn = 1
      AND NOT EXISTS (
            SELECT 1
            FROM silver.ibmi_settlement_revenue_history t
            WHERE t.set_rev_hist_owner_code      = d.set_rev_hist_owner_code
              AND t.set_rev_hist_truck_number    = d.set_rev_hist_truck_number
              AND t.set_rev_hist_load_number     = d.set_rev_hist_load_number
              AND t.set_rev_hist_dispatch_number = d.set_rev_hist_dispatch_number
              AND t.set_rev_hist_sequence_number = d.set_rev_hist_sequence_number
      );
END;