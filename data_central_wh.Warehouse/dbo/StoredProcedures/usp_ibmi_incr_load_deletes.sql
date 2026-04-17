CREATE    PROCEDURE dbo.usp_ibmi_incr_load_deletes
AS
BEGIN

    UPDATE TGT
    SET is_deleted = 1
    FROM silver.ibmi_incr_load_new AS TGT
    INNER JOIN data_central_lh.dbo.ibmi_load_change_log AS LOG
        ON TGT.load_load_number = LOG.DIODR#
        AND TGT.load_dispatch = LOG.DIDISP
        AND TGT.load_route_line_extension = LOG.DICONT;


    UPDATE TGT
    SET is_deleted = 0
    FROM silver.ibmi_incr_load_new AS TGT
    LEFT JOIN data_central_lh.dbo.ibmi_load_change_log AS LOG
        ON TGT.load_load_number = LOG.DIODR#
        AND TGT.load_dispatch = LOG.DIDISP
        AND TGT.load_route_line_extension = LOG.DICONT
    WHERE LOG.DIODR# IS NULL;
END;