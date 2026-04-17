[StagingDefinition = [Kind = "FastCopy"]]
section Section1;
[DataDestinations = {[Definition = [Kind = "Reference", QueryName = "ARFile_DataDestination", IsNewTarget = true], Settings = [Kind = "Manual", AllowCreation = true, ColumnSettings = [Mappings = {[SourceColumnName = "record_code", DestinationColumnName = "record_code"], [SourceColumnName = "customer_code", DestinationColumnName = "customer_code"], [SourceColumnName = "invoice_number", DestinationColumnName = "invoice_number"], [SourceColumnName = "adj_batch_code", DestinationColumnName = "adj_batch_code"], [SourceColumnName = "record_type", DestinationColumnName = "record_type"], [SourceColumnName = "record_number", DestinationColumnName = "record_number"], [SourceColumnName = "customer_name", DestinationColumnName = "customer_name"], [SourceColumnName = "sequence_code", DestinationColumnName = "sequence_code"], [SourceColumnName = "statement_number", DestinationColumnName = "statement_number"], [SourceColumnName = "dispatch_date", DestinationColumnName = "dispatch_date"], [SourceColumnName = "amount", DestinationColumnName = "amount"], [SourceColumnName = "balance_forward", DestinationColumnName = "balance_forward"], [SourceColumnName = "is_daily_pro_register", DestinationColumnName = "is_daily_pro_register"], [SourceColumnName = "is_weekly_pro_register", DestinationColumnName = "is_weekly_pro_register"], [SourceColumnName = "is_monthly_pro_register", DestinationColumnName = "is_monthly_pro_register"], [SourceColumnName = "is_non_current", DestinationColumnName = "is_non_current"], [SourceColumnName = "invoice_date", DestinationColumnName = "invoice_date"], [SourceColumnName = "load_number", DestinationColumnName = "load_number"], [SourceColumnName = "deposit_date", DestinationColumnName = "deposit_date"], [SourceColumnName = "cust_order_number", DestinationColumnName = "cust_order_number"], [SourceColumnName = "book_month", DestinationColumnName = "book_month"], [SourceColumnName = "book_year", DestinationColumnName = "book_year"], [SourceColumnName = "SnapshotDate", DestinationColumnName = "SnapshotDate"], [SourceColumnName = "DaysOpen", DestinationColumnName = "DaysOpen"], [SourceColumnName = "Open_30", DestinationColumnName = "Open_30"], [SourceColumnName = "Open_45", DestinationColumnName = "Open_45"], [SourceColumnName = "Open_60", DestinationColumnName = "Open_60"], [SourceColumnName = "Open_90", DestinationColumnName = "Open_90"], [SourceColumnName = "Open_120", DestinationColumnName = "Open_120"]}], DynamicSchema = false, UpdateMethod = [Kind = "Append"], TypeSettings = [Kind = "Table"]]]}]
shared ARFile = let
    Source =
        Sql.Database(
            "lofzv5bdxbxepf3ufbs6kug4du-dpb5fjqdbnqezisyyjteyvx6hu.datawarehouse.fabric.microsoft.com",
            "data_central_wh",
            [
                Query = "
                SELECT *
                FROM [data_central_wh].[gold].[vw_ibmi_arfile_combined]
                WHERE [invoice_date] >= DATEFROMPARTS(2024, 1, 1);
                "
            ]
        ),

    #"Filtered Rows" = Table.SelectRows(Source, each [balance_forward] > 0),

    #"Converted InvoiceDate" = Table.TransformColumns(
        #"Filtered Rows",
        {{"invoice_date", Date.From, type date}}
    ),

    SnapshotDate = Date.AddDays(
        Date.From(DateTime.LocalNow()),
        -Date.DayOfWeek(DateTime.LocalNow(), Day.Sunday) - 1
    ),

    #"Added SnapshotDate" = Table.AddColumn(
        #"Converted InvoiceDate",
        "SnapshotDate",
        each SnapshotDate,
        type date
    ),

    #"Added DaysOpen" = Table.AddColumn(
        #"Added SnapshotDate",
        "DaysOpen",
        each Duration.Days([SnapshotDate] - [invoice_date]),
        Int64.Type
    ),

    #"Added 30Day" = Table.AddColumn(
        #"Added DaysOpen", "Open_30",
        each if [DaysOpen] >= 30 and [DaysOpen] < 45 then 1 else 0, Int64.Type
    ),
    #"Added 45Day" = Table.AddColumn(
        #"Added 30Day", "Open_45",
        each if [DaysOpen] >= 45 and [DaysOpen] < 60 then 1 else 0, Int64.Type
    ),
    #"Added 60Day" = Table.AddColumn(
        #"Added 45Day", "Open_60",
        each if [DaysOpen] >= 60 and [DaysOpen] < 90 then 1 else 0, Int64.Type
    ),
    #"Added 90Day" = Table.AddColumn(
        #"Added 60Day", "Open_90",
        each if [DaysOpen] >= 90 and [DaysOpen] < 120 then 1 else 0, Int64.Type
    ),
    #"Added 120Day" = Table.AddColumn(
        #"Added 90Day", "Open_120",
        each if [DaysOpen] >= 120 then 1 else 0, Int64.Type
    )

in
    #"Added 120Day";
shared ARFile_DataDestination = let
  Pattern = Fabric.Warehouse([HierarchicalNavigation = true, CreateNavigationProperties = false]),
  Navigation_1 = Pattern{[workspaceId = "a6d2c31b-0b03-4c60-a258-c2664c56fe3d"]}[Data],
  Navigation_2 = Navigation_1{[warehouseId = "f8578495-391e-4e7e-b791-4949397ba86f"]}[Data],
  Navigation_3 = Navigation_2{[Schema = "gold"]}[Data],
  TableNavigation = Navigation_3{[Name = "fact_ar_weekly_snapshot"]}?[Data]?
in
  TableNavigation;
