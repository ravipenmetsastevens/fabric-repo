section Section1;
[DataDestinations = {[Definition = [Kind = "Reference", QueryName = "VW_EARNINGS_HISTORY_DataDestination", IsNewTarget = false], Settings = [Kind = "Manual", AllowCreation = false, ColumnSettings = [Mappings = {[SourceColumnName = "EHEMP", DestinationColumnName = "EHEMP"], [SourceColumnName = "EHCOMP", DestinationColumnName = "EHCOMP"], [SourceColumnName = "EHRUN", DestinationColumnName = "EHRUN"], [SourceColumnName = "EHBPKG", DestinationColumnName = "EHBPKG"], [SourceColumnName = "EHDEPT", DestinationColumnName = "EHDEPT"], [SourceColumnName = "EHDVSN", DestinationColumnName = "EHDVSN"], [SourceColumnName = "EHJOB", DestinationColumnName = "EHJOB"], [SourceColumnName = "EHPAYD", DestinationColumnName = "EHPAYD"], [SourceColumnName = "EHWEEK", DestinationColumnName = "EHWEEK"], [SourceColumnName = "EHSEQ", DestinationColumnName = "EHSEQ"], [SourceColumnName = "EHQTY", DestinationColumnName = "EHQTY"], [SourceColumnName = "EHUNTY", DestinationColumnName = "EHUNTY"], [SourceColumnName = "EHTYPE", DestinationColumnName = "EHTYPE"], [SourceColumnName = "EHPAID", DestinationColumnName = "EHPAID"], [SourceColumnName = "EHCLAS", DestinationColumnName = "EHCLAS"], [SourceColumnName = "EHRATC", DestinationColumnName = "EHRATC"], [SourceColumnName = "EHWDCD", DestinationColumnName = "EHWDCD"], [SourceColumnName = "EHRATE", DestinationColumnName = "EHRATE"], [SourceColumnName = "EHGROS", DestinationColumnName = "EHGROS"], [SourceColumnName = "EHQTYW", DestinationColumnName = "EHQTYW"], [SourceColumnName = "EHORD", DestinationColumnName = "EHORD"], [SourceColumnName = "EHDSP", DestinationColumnName = "EHDSP"], [SourceColumnName = "EHLMIL", DestinationColumnName = "EHLMIL"], [SourceColumnName = "EHEMIL", DestinationColumnName = "EHEMIL"], [SourceColumnName = "EHUNIT", DestinationColumnName = "EHUNIT"], [SourceColumnName = "EHOWNR", DestinationColumnName = "EHOWNR"], [SourceColumnName = "EHORGC", DestinationColumnName = "EHORGC"], [SourceColumnName = "EHORGS", DestinationColumnName = "EHORGS"], [SourceColumnName = "EHDSTC", DestinationColumnName = "EHDSTC"], [SourceColumnName = "EHDSTS", DestinationColumnName = "EHDSTS"], [SourceColumnName = "EHDESC", DestinationColumnName = "EHDESC"], [SourceColumnName = "EHSTCD", DestinationColumnName = "EHSTCD"], [SourceColumnName = "EHADDP", DestinationColumnName = "EHADDP"], [SourceColumnName = "EHWDMP", DestinationColumnName = "EHWDMP"], [SourceColumnName = "EHTEXC", DestinationColumnName = "EHTEXC"], [SourceColumnName = "EHTCC", DestinationColumnName = "EHTCC"], [SourceColumnName = "EHBGDT", DestinationColumnName = "EHBGDT"], [SourceColumnName = "EHERND", DestinationColumnName = "EHERND"], [SourceColumnName = "EHLACT", DestinationColumnName = "EHLACT"], [SourceColumnName = "EHEXAC", DestinationColumnName = "EHEXAC"], [SourceColumnName = "EHCC", DestinationColumnName = "EHCC"], [SourceColumnName = "EHPC1", DestinationColumnName = "EHPC1"], [SourceColumnName = "EHEXA2", DestinationColumnName = "EHEXA2"], [SourceColumnName = "EHCC2", DestinationColumnName = "EHCC2"], [SourceColumnName = "EHPC2", DestinationColumnName = "EHPC2"], [SourceColumnName = "EHEXA3", DestinationColumnName = "EHEXA3"], [SourceColumnName = "EHCC3", DestinationColumnName = "EHCC3"], [SourceColumnName = "EHPC3", DestinationColumnName = "EHPC3"], [SourceColumnName = "EHEXPF", DestinationColumnName = "EHEXPF"], [SourceColumnName = "EHPYPD", DestinationColumnName = "EHPYPD"], [SourceColumnName = "EHPYYR", DestinationColumnName = "EHPYYR"], [SourceColumnName = "EHCKDT", DestinationColumnName = "EHCKDT"], [SourceColumnName = "EHCKCD", DestinationColumnName = "EHCKCD"], [SourceColumnName = "EHCKNO", DestinationColumnName = "EHCKNO"], [SourceColumnName = "EHPBKM", DestinationColumnName = "EHPBKM"], [SourceColumnName = "EHPBKY", DestinationColumnName = "EHPBKY"], [SourceColumnName = "EHSTAT", DestinationColumnName = "EHSTAT"], [SourceColumnName = "EHVDDT", DestinationColumnName = "EHVDDT"], [SourceColumnName = "EHVBKM", DestinationColumnName = "EHVBKM"], [SourceColumnName = "EHVBKY", DestinationColumnName = "EHVBKY"], [SourceColumnName = "EHTXDY", DestinationColumnName = "EHTXDY"], [SourceColumnName = "EHHOLD", DestinationColumnName = "EHHOLD"], [SourceColumnName = "EHAUSR", DestinationColumnName = "EHAUSR"], [SourceColumnName = "EHADAT", DestinationColumnName = "EHADAT"], [SourceColumnName = "EHATIM", DestinationColumnName = "EHATIM"]}], DynamicSchema = false, UpdateMethod = [Kind = "Replace"], TypeSettings = [Kind = "Table"]]]}]
shared VW_EARNINGS_HISTORY = let
    // Dates
    Today          = DateTime.Date(DateTime.LocalNow()),
    FourMonthsAgo  = Date.AddMonths(Today, -4),

    // Convert to YYDDD (2-digit year * 1000 + day-of-year)
    ToJulian = (d as date) as number => Number.Mod(Date.Year(d), 100) * 1000 + Date.DayOfYear(d),
    JulianToday        = ToJulian(Today),
    JulianFourMonthsAgo = ToJulian(FourMonthsAgo),

    // Build SQL
    SqlQuery = Text.Format(
        "SELECT *
         FROM FABRIC.VW_EARNINGS_HISTORY",
        { Text.From(JulianFourMonthsAgo), Text.From(JulianToday) }
    ),

    // Execute
    Source = DB2.Database(
        "S10A3543.STEVENSTRANSPORT.COM:447",
        "S10A3543",
        [Query = SqlQuery, Implementation = "Microsoft"]
    ),

    // Optional: tidy column names
    #"Renamed Columns" =
        Table.RenameColumns(
            Source,
            {{"EHEMP#", "EHEMP"}, {"EHORD#", "EHORD"}, {"EHDSP#", "EHDSP"}}
        )
in
    #"Renamed Columns";
shared VW_EARNINGS_HISTORY_DataDestination = let
  Pattern = Lakehouse.Contents([CreateNavigationProperties = false, EnableFolding = false]),
  Navigation_1 = Pattern{[workspaceId = "a6d2c31b-0b03-4c60-a258-c2664c56fe3d"]}[Data],
  Navigation_2 = Navigation_1{[lakehouseId = "f9a73da1-08e4-4f3d-a67f-74623bfde721"]}[Data],
  TableNavigation = Navigation_2{[Id = "ibmi_earnings_history_bronze", ItemKind = "Table"]}[Data]
in
  TableNavigation;
