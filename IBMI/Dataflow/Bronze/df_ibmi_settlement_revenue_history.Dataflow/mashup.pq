section Section1;
[DataDestinations = {[Definition = [Kind = "Reference", QueryName = "VW_SETTLEMENT_REVENUE_HISTORY_DataDestination", IsNewTarget = false], Settings = [Kind = "Manual", AllowCreation = false, ColumnSettings = [Mappings = {[SourceColumnName = "SRRECS", DestinationColumnName = "SRRECS"], [SourceColumnName = "SROWN", DestinationColumnName = "SROWN"], [SourceColumnName = "SRUNIT", DestinationColumnName = "SRUNIT"], [SourceColumnName = "SRREVC", DestinationColumnName = "SRREVC"], [SourceColumnName = "SRORD", DestinationColumnName = "SRORD"], [SourceColumnName = "SRDISP", DestinationColumnName = "SRDISP"], [SourceColumnName = "SRSEQ", DestinationColumnName = "SRSEQ"], [SourceColumnName = "SRLDTE", DestinationColumnName = "SRLDTE"], [SourceColumnName = "SRLYR", DestinationColumnName = "SRLYR"], [SourceColumnName = "SRRDAT", DestinationColumnName = "SRRDAT"], [SourceColumnName = "SRORG", DestinationColumnName = "SRORG"], [SourceColumnName = "SRDEST", DestinationColumnName = "SRDEST"], [SourceColumnName = "SRREVA", DestinationColumnName = "SRREVA"], [SourceColumnName = "SRFC", DestinationColumnName = "SRFC"], [SourceColumnName = "SROWNR", DestinationColumnName = "SROWNR"], [SourceColumnName = "SRSEG", DestinationColumnName = "SRSEG"], [SourceColumnName = "SRMILE", DestinationColumnName = "SRMILE"], [SourceColumnName = "SROCTY", DestinationColumnName = "SROCTY"], [SourceColumnName = "SRDCTY", DestinationColumnName = "SRDCTY"], [SourceColumnName = "SRADPY", DestinationColumnName = "SRADPY"], [SourceColumnName = "SRFCAD", DestinationColumnName = "SRFCAD"], [SourceColumnName = "SRFSC", DestinationColumnName = "SRFSC"], [SourceColumnName = "SRLM", DestinationColumnName = "SRLM"], [SourceColumnName = "SRLMR", DestinationColumnName = "SRLMR"], [SourceColumnName = "SREM", DestinationColumnName = "SREM"], [SourceColumnName = "SREMR", DestinationColumnName = "SREMR"], [SourceColumnName = "SRFCRT", DestinationColumnName = "SRFCRT"], [SourceColumnName = "SRDBGL", DestinationColumnName = "SRDBGL"], [SourceColumnName = "SRCRGL", DestinationColumnName = "SRCRGL"], [SourceColumnName = "SRDBCC", DestinationColumnName = "SRDBCC"], [SourceColumnName = "SRCRCC", DestinationColumnName = "SRCRCC"], [SourceColumnName = "SRBKMO", DestinationColumnName = "SRBKMO"], [SourceColumnName = "SRBKYR", DestinationColumnName = "SRBKYR"], [SourceColumnName = "SRVBKM", DestinationColumnName = "SRVBKM"], [SourceColumnName = "SRVBKY", DestinationColumnName = "SRVBKY"], [SourceColumnName = "SRPBKM", DestinationColumnName = "SRPBKM"], [SourceColumnName = "SRPBKY", DestinationColumnName = "SRPBKY"], [SourceColumnName = "SREXPF", DestinationColumnName = "SREXPF"], [SourceColumnName = "SRWCFL", DestinationColumnName = "SRWCFL"], [SourceColumnName = "SRDOM", DestinationColumnName = "SRDOM"], [SourceColumnName = "SREDAT", DestinationColumnName = "SREDAT"], [SourceColumnName = "SROREV", DestinationColumnName = "SROREV"], [SourceColumnName = "SRREVT", DestinationColumnName = "SRREVT"], [SourceColumnName = "SRGSTC", DestinationColumnName = "SRGSTC"], [SourceColumnName = "SRGSTA", DestinationColumnName = "SRGSTA"], [SourceColumnName = "SRVCH", DestinationColumnName = "SRVCH"], [SourceColumnName = "SRPGLB", DestinationColumnName = "SRPGLB"], [SourceColumnName = "SREGLB", DestinationColumnName = "SREGLB"], [SourceColumnName = "SRVGLB", DestinationColumnName = "SRVGLB"], [SourceColumnName = "SROBAL", DestinationColumnName = "SROBAL"], [SourceColumnName = "SRUPDD", DestinationColumnName = "SRUPDD"], [SourceColumnName = "SRUPDT", DestinationColumnName = "SRUPDT"], [SourceColumnName = "SRUPDI", DestinationColumnName = "SRUPDI"]}], DynamicSchema = false, UpdateMethod = [Kind = "Replace"], TypeSettings = [Kind = "Table"]]]}]
shared VW_SETTLEMENT_REVENUE_HISTORY = let
    // Step 1: Calculate today's and 14-days-ago Julian dates (YYDDD format)
    Today = DateTime.Date(DateTime.LocalNow()),
    FourteenDaysAgo = Today - #duration(14, 0, 0, 0),
    JulianToday = Number.Mod(Date.Year(Today), 100) * 1000 + Date.DayOfYear(Today),
    Julian14DaysAgo = Number.Mod(Date.Year(FourteenDaysAgo), 100) * 1000 + Date.DayOfYear(FourteenDaysAgo),

    // Step 2: Create SQL query string
    SqlQuery = Text.Format(
        "SELECT *
         FROM FABRIC.VW_SETTLEMENT_REVENUE_HISTORY",
        {Text.From(Julian14DaysAgo), Text.From(JulianToday)}
    ),

    // Step 3: Load filtered data using native SQL
    Source = DB2.Database(
        "S10A3543.STEVENSTRANSPORT.COM:447", 
        "S10A3543", 
        [Query = SqlQuery, Implementation = "Microsoft"]
    ),
  #"Renamed columns" = Table.RenameColumns(#"Source", {{"SRORD#", "SRORD"}, {"SRSEQ#", "SRSEQ"}, {"SRVCH#", "SRVCH"}})
in
  #"Renamed columns";
shared VW_SETTLEMENT_REVENUE_HISTORY_DataDestination = let
  Pattern = Lakehouse.Contents([CreateNavigationProperties = false, EnableFolding = false]),
  Navigation_1 = Pattern{[workspaceId = "a6d2c31b-0b03-4c60-a258-c2664c56fe3d"]}[Data],
  Navigation_2 = Navigation_1{[lakehouseId = "f9a73da1-08e4-4f3d-a67f-74623bfde721"]}[Data],
  TableNavigation = Navigation_2{[Id = "ibmi_settlement_revenue_history_bronze", ItemKind = "Table"]}[Data]
in
  TableNavigation;
