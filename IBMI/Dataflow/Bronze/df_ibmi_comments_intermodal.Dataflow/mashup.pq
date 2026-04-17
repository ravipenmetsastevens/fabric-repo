section Section1;
[DataDestinations = {[Definition = [Kind = "Reference", QueryName = "VW_COMMENTS_INTERMODAL_DataDestination", IsNewTarget = false], Settings = [Kind = "Manual", AllowCreation = false, ColumnSettings = [Mappings = {[SourceColumnName = "CDATE", DestinationColumnName = "CDATE"], [SourceColumnName = "OCORD", DestinationColumnName = "OCORD"], [SourceColumnName = "OCREC", DestinationColumnName = "OCREC"], [SourceColumnName = "OCTYP", DestinationColumnName = "OCTYP"], [SourceColumnName = "OCLOC", DestinationColumnName = "OCLOC"], [SourceColumnName = "OCDESC", DestinationColumnName = "OCDESC"], [SourceColumnName = "OCDLT", DestinationColumnName = "OCDLT"], [SourceColumnName = "OCFIL", DestinationColumnName = "OCFIL"], [SourceColumnName = "OCDATE", DestinationColumnName = "OCDATE"], [SourceColumnName = "OCINIT", DestinationColumnName = "OCINIT"]}], DynamicSchema = false, UpdateMethod = [Kind = "Replace"], TypeSettings = [Kind = "Table"]]]}]
shared VW_COMMENTS_INTERMODAL = let
  Source = DB2.Database("S10A3543.STEVENSTRANSPORT.COM:447", "S10A3543", [HierarchicalNavigation = true, Implementation = "Microsoft"]),
  #"Navigation 1" = Source{[Schema = "FABRIC"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[Name = "VW_COMMENTS_INTERMODAL"]}[Data],
  #"Renamed columns" = Table.RenameColumns(#"Navigation 2", {{"OCORD#", "OCORD"}, {"OCREC#", "OCREC"}})
in
  #"Renamed columns";
shared VW_COMMENTS_INTERMODAL_DataDestination = let
  Pattern = Lakehouse.Contents([CreateNavigationProperties = false, EnableFolding = false]),
  Navigation_1 = Pattern{[workspaceId = "a6d2c31b-0b03-4c60-a258-c2664c56fe3d"]}[Data],
  Navigation_2 = Navigation_1{[lakehouseId = "f9a73da1-08e4-4f3d-a67f-74623bfde721"]}[Data],
  TableNavigation = Navigation_2{[Id = "ibmi_comments_intermodal_bronze", ItemKind = "Table"]}[Data]
in
  TableNavigation;
