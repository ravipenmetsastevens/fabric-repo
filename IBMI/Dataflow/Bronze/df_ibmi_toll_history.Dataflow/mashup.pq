section Section1;
[DataDestinations = {[Definition = [Kind = "Reference", QueryName = "VW_TOLL_HISTORY_DataDestination", IsNewTarget = false], Settings = [Kind = "Manual", AllowCreation = false, ColumnSettings = [Mappings = {[SourceColumnName = "TAG", DestinationColumnName = "TAG"], [SourceColumnName = "UNIT", DestinationColumnName = "UNIT"], [SourceColumnName = "TOLLDT", DestinationColumnName = "TOLLDT"], [SourceColumnName = "TLG", DestinationColumnName = "TLG"], [SourceColumnName = "TLI", DestinationColumnName = "TLI"], [SourceColumnName = "UNOWN", DestinationColumnName = "UNOWN"], [SourceColumnName = "UNDV", DestinationColumnName = "UNDV"], [SourceColumnName = "TLODR", DestinationColumnName = "TLODR"], [SourceColumnName = "TLDISP", DestinationColumnName = "TLDISP"], [SourceColumnName = "TLBILL", DestinationColumnName = "TLBILL"], [SourceColumnName = "UPLDDT", DestinationColumnName = "UPLDDT"]}], DynamicSchema = false, UpdateMethod = [Kind = "Replace"], TypeSettings = [Kind = "Table"]]]}]
shared VW_TOLL_HISTORY = let
  Source = DB2.Database("S10A3543.STEVENSTRANSPORT.COM:447", "S10A3543", [HierarchicalNavigation = true, Implementation = "Microsoft"]),
  #"Navigation 1" = Source{[Schema = "FABRIC"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[Name = "VW_TOLL_HISTORY"]}[Data],
  #"Renamed columns" = Table.RenameColumns(#"Navigation 2", {{"TAG#", "TAG"}, {"UNDV#", "UNDV"}, {"TLODR#", "TLODR"}})
in
  #"Renamed columns";
shared VW_TOLL_HISTORY_DataDestination = let
  Pattern = Lakehouse.Contents([CreateNavigationProperties = false, EnableFolding = false]),
  Navigation_1 = Pattern{[workspaceId = "a6d2c31b-0b03-4c60-a258-c2664c56fe3d"]}[Data],
  Navigation_2 = Navigation_1{[lakehouseId = "f9a73da1-08e4-4f3d-a67f-74623bfde721"]}[Data],
  TableNavigation = Navigation_2{[Id = "ibmi_toll_history_bronze", ItemKind = "Table"]}[Data]
in
  TableNavigation;
