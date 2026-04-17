section Section1;
[DataDestinations = {[Definition = [Kind = "Reference", QueryName = "VW_TLB_ARFILE_DataDestination", IsNewTarget = false], Settings = [Kind = "Manual", AllowCreation = false, ColumnSettings = [Mappings = {[SourceColumnName = "ARRECC", DestinationColumnName = "ARRECC"], [SourceColumnName = "ARCUST", DestinationColumnName = "ARCUST"], [SourceColumnName = "ARINVN", DestinationColumnName = "ARINVN"], [SourceColumnName = "ARCUS#", DestinationColumnName = "ARCUS#"], [SourceColumnName = "ARTYPE", DestinationColumnName = "ARTYPE"], [SourceColumnName = "ARREC#", DestinationColumnName = "ARREC#"], [SourceColumnName = "ARINVD", DestinationColumnName = "ARINVD"], [SourceColumnName = "ARORD", DestinationColumnName = "ARORD"], [SourceColumnName = "ARDPDT", DestinationColumnName = "ARDPDT"], [SourceColumnName = "ARCORD", DestinationColumnName = "ARCORD"], [SourceColumnName = "ARBOMO", DestinationColumnName = "ARBOMO"], [SourceColumnName = "ARBOYR", DestinationColumnName = "ARBOYR"], [SourceColumnName = "ARAMT", DestinationColumnName = "ARAMT"], [SourceColumnName = "ARBFWD", DestinationColumnName = "ARBFWD"], [SourceColumnName = "ARFC", DestinationColumnName = "ARFC"], [SourceColumnName = "ARDPRO", DestinationColumnName = "ARDPRO"], [SourceColumnName = "ARWPRO", DestinationColumnName = "ARWPRO"], [SourceColumnName = "ARMPRO", DestinationColumnName = "ARMPRO"], [SourceColumnName = "ARNCUR", DestinationColumnName = "ARNCUR"], [SourceColumnName = "ARNAME", DestinationColumnName = "ARNAME"], [SourceColumnName = "ARSEQ", DestinationColumnName = "ARSEQ"], [SourceColumnName = "ARSTM#", DestinationColumnName = "ARSTM#"], [SourceColumnName = "ARDSPD", DestinationColumnName = "ARDSPD"], [SourceColumnName = "ARSTMF", DestinationColumnName = "ARSTMF"], [SourceColumnName = "ARGSTA", DestinationColumnName = "ARGSTA"], [SourceColumnName = "ARGLNO", DestinationColumnName = "ARGLNO"]}], DynamicSchema = false, UpdateMethod = [Kind = "Replace"], TypeSettings = [Kind = "Table"]]]}]
shared VW_TLB_ARFILE = let
  Source = DB2.Database("S10A3543.STEVENSTRANSPORT.COM:447", "S10A3543", [HierarchicalNavigation = true, Implementation = "Microsoft"]),
  #"Navigation 1" = Source{[Schema = "FABRIC"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[Name = "VW_TLB_ARFILE"]}[Data]
in
  #"Navigation 2";
shared VW_TLB_ARFILE_DataDestination = let
  Pattern = Lakehouse.Contents([CreateNavigationProperties = false, EnableFolding = false]),
  Navigation_1 = Pattern{[workspaceId = "a6d2c31b-0b03-4c60-a258-c2664c56fe3d"]}[Data],
  Navigation_2 = Navigation_1{[lakehouseId = "f9a73da1-08e4-4f3d-a67f-74623bfde721"]}[Data],
  TableNavigation = Navigation_2{[Id = "ibmi_tlb_arfile_bronze", ItemKind = "Table"]}[Data]
in
  TableNavigation;
