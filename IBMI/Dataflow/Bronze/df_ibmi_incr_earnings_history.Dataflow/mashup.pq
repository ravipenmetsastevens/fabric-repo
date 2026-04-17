[StagingDefinition = [Kind = "FastCopy"]]
section Section1;
[DataDestinations = {[Definition = [Kind = "Reference", QueryName = "VW_EARNINGS_HISTORY_DataDestination", IsNewTarget = true], Settings = [Kind = "Automatic", TypeSettings = [Kind = "Table"]]]}]
shared VW_EARNINGS_HISTORY = let
    // Step 1: Calculate today's and 14 days ago
    Today = DateTime.Date(DateTime.LocalNow()),
    FourteenDaysAgo = Today - #duration(14, 0, 0, 0),

    // Step 2: Convert to YYDDD format (2-digit year + day of year)
    JulianToday = Number.Mod(Date.Year(Today), 100) * 1000 + Date.DayOfYear(Today),
    Julian14DaysAgo = Number.Mod(Date.Year(FourteenDaysAgo), 100) * 1000 + Date.DayOfYear(FourteenDaysAgo),

    // Step 3: Format SQL string
    SqlQuery = Text.Format(
        "SELECT *
         FROM FABRIC.VW_INCR_EARNINGS_HISTORY
         WHERE EHCKDT BETWEEN #{0} AND #{1}",
        {Text.From(Julian14DaysAgo), Text.From(JulianToday)}
    ),

    // Step 4: Run native SQL query
    Source = DB2.Database(
        "S10A3543.STEVENSTRANSPORT.COM:447", 
        "S10A3543", 
        [Query = SqlQuery, Implementation = "Microsoft"]
    ),
  #"Renamedcolumns" = Table.RenameColumns(#"Source", {{"EHEMP#", "EHEMP"}, {"EHORD#", "EHORD"}, {"EHDSP#", "EHDSP"}}),
    AddRecordNumber = Table.AddIndexColumn(Renamedcolumns, "recordNumber", 1, 1, Int64.Type),
    AddLoadDate = Table.AddColumn(AddRecordNumber, "loadDate", each DateTime.LocalNow(), type datetime),
    AddRefreshDate = Table.AddColumn(AddLoadDate, "refreshDate", each Date.From(DateTime.LocalNow()), type date),
    AddSourceSystem = Table.AddColumn(AddRefreshDate, "sourceSystem", each "IBM", type text)

in
    AddSourceSystem;
shared VW_EARNINGS_HISTORY_DataDestination = let
  Pattern = Lakehouse.Contents([CreateNavigationProperties = false, EnableFolding = false]),
  Navigation_1 = Pattern{[workspaceId = "a6d2c31b-0b03-4c60-a258-c2664c56fe3d"]}[Data],
  Navigation_2 = Navigation_1{[lakehouseId = "f9a73da1-08e4-4f3d-a67f-74623bfde721"]}[Data],
  TableNavigation = Navigation_2{[Id = "ibmi_incr_earnings_history_bronze", ItemKind = "Table"]}?[Data]?
in
  TableNavigation;
