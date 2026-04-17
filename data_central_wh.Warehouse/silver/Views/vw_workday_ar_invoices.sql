-- Auto Generated (Do not modify) B6C2A1A712BDEBEC4A81C7C9D17D4E592FB4A9E8C24F6541CE3C16D685FCC2F9
CREATE VIEW silver.vw_workday_ar_invoices AS
SELECT
    -- invoice header
    h.invoice_id,
    h.invoice_number,
    h.invoice_date,
    h.due_date_override,
    h.amount_due,
    h.payment_status,
    h.document_status,
    h.customer_po_number,
    h.memo,

    -- join keys
    h.customer_id,
    h.customer_reference_id,
    h.customer_wid,
    h.sold_to_customer_id,
    h.company_id,
    h.currency_id,

    -- bill-to
    h.bill_to_address_id,
    h.bill_to_formatted_address,
    h.bill_to_address_line1,
    h.bill_to_city,
    h.bill_to_state,
    h.bill_to_postal_code,
    h.bill_to_country_alpha2,

    -- invoice line
    l.line_index,
    l.invoice_line_reference_id,
    l.revenue_category_id,
    l.quantity,
    l.unit_cost,
    l.extended_amount,
    l.line_memo

FROM data_central_lh.dbo.workday_customer_invoices_hdr_shred h
LEFT JOIN data_central_lh.dbo.workday_customer_invoices_line_shred l
    ON h.invoice_id = l.invoice_id;