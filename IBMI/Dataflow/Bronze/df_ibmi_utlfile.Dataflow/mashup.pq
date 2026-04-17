[StagingDefinition = [Kind = "FastCopy"]]
section Section1;
[DataDestinations = {[Definition = [Kind = "Reference", QueryName = "VW_UTLFILE_DataDestination", IsNewTarget = true], Settings = [Kind = "Automatic", TypeSettings = [Kind = "Table"]]]}]
shared VW_UTLFILE = let
  Source = DB2.Database("S10A3543.STEVENSTRANSPORT.COM:447", "S10A3543", [HierarchicalNavigation = true, Implementation = "Microsoft"]),
  #"Navigation 1" = Source{[Schema = "FABRIC"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[Name = "VW_UTLFILE"]}[Data],
  #"Renamed columns" = Table.RenameColumns(#"Navigation 2", {{"UWPRD#", "UWPRD"}, {"UWTRK#", "UWTRK"}, {"UWDIV#", "UWDIV"}, {"UWRDO#", "UWRDO"}})
in
  #"Renamed columns";
shared VW_UTLFILE_DataDestination = let
  Pattern = Lakehouse.Contents([CreateNavigationProperties = false, EnableFolding = false]),
  Navigation_1 = Pattern{[workspaceId = "a6d2c31b-0b03-4c60-a258-c2664c56fe3d"]}[Data],
  Navigation_2 = Navigation_1{[lakehouseId = "f9a73da1-08e4-4f3d-a67f-74623bfde721"]}[Data],
  TableNavigation = Navigation_2{[Id = "ibmi_utlfile_bronze", ItemKind = "Table"]}?[Data]?
in
  TableNavigation;
