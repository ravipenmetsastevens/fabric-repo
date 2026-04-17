[StagingDefinition = [Kind = "FastCopy"]]
section Section1;
[DataDestinations = {[Definition = [Kind = "Reference", QueryName = "VW_PLSC_PLPMILES_DataDestination", IsNewTarget = false], Settings = [Kind = "Manual", AllowCreation = false, ColumnSettings = [Mappings = {[SourceColumnName = "PPMMN", DestinationColumnName = "PPMMN"], [SourceColumnName = "PPEIDNP", DestinationColumnName = "PPEIDNP"], [SourceColumnName = "PPMAC_P", DestinationColumnName = "PPMAC_P"], [SourceColumnName = "PPVER_P", DestinationColumnName = "PPVER_P"], [SourceColumnName = "PPLOAD", DestinationColumnName = "PPLOAD"], [SourceColumnName = "PPLOADMILE", DestinationColumnName = "PPLOADMILE"], [SourceColumnName = "PPEMTMILE", DestinationColumnName = "PPEMTMILE"]}], DynamicSchema = false, UpdateMethod = [Kind = "Replace"], TypeSettings = [Kind = "Table"]]]}]
shared VW_PLSC_PLPMILES = let
  Source = DB2.Database("S10A3543.STEVENSTRANSPORT.COM:447", "S10A3543", [HierarchicalNavigation = true, Implementation = "Microsoft"]),
  #"Navigation 1" = Source{[Schema = "FABRIC"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[Name = "VW_PLSC_PLPMILES"]}[Data],
  #"Trimmed text" = Table.TransformColumns(#"Navigation 2", {{"PPEIDNP", each Text.Trim(_), type text}, {"PPMAC#P", each Text.Trim(_), type text}, {"PPVER#P", each Text.Trim(_), type text}, {"PPLOAD", each Text.Trim(_), type text}, {"PPLOADMILE", each Text.Trim(_), type text}, {"PPEMTMILE", each Text.Trim(_), type text}}),
  #"Renamed columns" = Table.RenameColumns(#"Trimmed text", {{"PPMAC#P", "PPMAC_P"}, {"PPVER#P", "PPVER_P"}, {"PPMMN#", "PPMMN"}})
in
  #"Renamed columns";
shared VW_PLSC_PLPMILES_DataDestination = let
  Pattern = Lakehouse.Contents([HierarchicalNavigation = null, CreateNavigationProperties = false, EnableFolding = false]),
  Navigation_1 = Pattern{[workspaceId = "a6d2c31b-0b03-4c60-a258-c2664c56fe3d"]}[Data],
  Navigation_2 = Navigation_1{[lakehouseId = "f9a73da1-08e4-4f3d-a67f-74623bfde721"]}[Data],
  TableNavigation = Navigation_2{[Id = "PLSC_PLPMILES", ItemKind = "Table"]}[Data]
in
  TableNavigation;
