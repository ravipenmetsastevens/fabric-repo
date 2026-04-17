[StagingDefinition = [Kind = "FastCopy"]]
section Section1;
[DataDestinations = {[Definition = [Kind = "Reference", QueryName = "VW_PLSC_PLACTORDP_DataDestination", IsNewTarget = false], Settings = [Kind = "Manual", AllowCreation = false, ColumnSettings = [Mappings = {[SourceColumnName = "PLACTORD", DestinationColumnName = "PLACTORD"], [SourceColumnName = "PLACTDISP", DestinationColumnName = "PLACTDISP"], [SourceColumnName = "PLDRVCODE", DestinationColumnName = "PLDRVCODE"], [SourceColumnName = "PLMHDATE", DestinationColumnName = "PLMHDATE"], [SourceColumnName = "PLMHDATE_CONV", DestinationColumnName = "PLMHDATE_CONV"], [SourceColumnName = "PLMHTIME", DestinationColumnName = "PLMHTIME"]}], DynamicSchema = false, UpdateMethod = [Kind = "Replace"], TypeSettings = [Kind = "Table"]]]}]
shared VW_PLSC_PLACTORDP = let
  Source = DB2.Database("S10A3543.STEVENSTRANSPORT.COM:447", "S10A3543", [HierarchicalNavigation = true, Implementation = "Microsoft"]),
  #"Navigation 1" = Source{[Schema = "FABRIC"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[Name = "VW_PLSC_PLACTORDP"]}[Data],
  #"Trimmed text" = Table.TransformColumns(#"Navigation 2", {{"PLACTORD", each Text.Trim(_), type text}, {"PLACTDISP", each Text.Trim(_), type text}, {"PLDRVCODE", each Text.Trim(_), type text}, {"PLMHTIME", each Text.Trim(_), type text}})
in
  #"Trimmed text";
shared VW_PLSC_PLACTORDP_DataDestination = let
  Pattern = Lakehouse.Contents([HierarchicalNavigation = null, CreateNavigationProperties = false, EnableFolding = false]),
  Navigation_1 = Pattern{[workspaceId = "a6d2c31b-0b03-4c60-a258-c2664c56fe3d"]}[Data],
  Navigation_2 = Navigation_1{[lakehouseId = "f9a73da1-08e4-4f3d-a67f-74623bfde721"]}[Data],
  TableNavigation = Navigation_2{[Id = "PLSC_PLACTORDP2", ItemKind = "Table"]}[Data]
in
  TableNavigation;
