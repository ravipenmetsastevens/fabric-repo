[StagingDefinition = [Kind = "FastCopy"]]
section Section1;
[DataDestinations = {[Definition = [Kind = "Reference", QueryName = "VW_PLSC_PLPFWDMAC_DataDestination", IsNewTarget = false], Settings = [Kind = "Manual", AllowCreation = false, ColumnSettings = [Mappings = {[SourceColumnName = "OMMAC", DestinationColumnName = "OMMAC"], [SourceColumnName = "OMFWD", DestinationColumnName = "OMFWD"], [SourceColumnName = "PSTITLE", DestinationColumnName = "PSTITLE"]}], DynamicSchema = false, UpdateMethod = [Kind = "Replace"], TypeSettings = [Kind = "Table"]]]}]
shared VW_PLSC_PLPFWDMAC = let
  Source = DB2.Database("S10A3543.STEVENSTRANSPORT.COM:447", "S10A3543", [HierarchicalNavigation = true, Implementation = "Microsoft"]),
  #"Navigation 1" = Source{[Schema = "FABRIC"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[Name = "VW_PLSC_PLPFWDMAC"]}[Data],
  #"Renamed columns" = Table.RenameColumns(#"Navigation 2", {{"OMMAC#", "OMMAC"}, {"OMFWD#", "OMFWD"}}),
  #"Trimmed text" = Table.TransformColumns(#"Renamed columns", {{"PSTITLE", each Text.Trim(_), type text}})
in
  #"Trimmed text";
shared VW_PLSC_PLPFWDMAC_DataDestination = let
  Pattern = Lakehouse.Contents([HierarchicalNavigation = null, CreateNavigationProperties = false, EnableFolding = false]),
  Navigation_1 = Pattern{[workspaceId = "a6d2c31b-0b03-4c60-a258-c2664c56fe3d"]}[Data],
  Navigation_2 = Navigation_1{[lakehouseId = "f9a73da1-08e4-4f3d-a67f-74623bfde721"]}[Data],
  TableNavigation = Navigation_2{[Id = "PLSC_PLPFWDMAC", ItemKind = "Table"]}[Data]
in
  TableNavigation;
