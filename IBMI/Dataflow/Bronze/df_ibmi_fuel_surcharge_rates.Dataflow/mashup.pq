section Section1;
[DataDestinations = {[Definition = [Kind = "Reference", QueryName = "VW_FUEL_SURCHARGE_RATES_DataDestination", IsNewTarget = false], Settings = [Kind = "Manual", AllowCreation = false, ColumnSettings = [Mappings = {[SourceColumnName = "FSCODE", DestinationColumnName = "FSCODE"], [SourceColumnName = "FSTYPE", DestinationColumnName = "FSTYPE"], [SourceColumnName = "FSRATE", DestinationColumnName = "FSRATE"], [SourceColumnName = "FSEFDT", DestinationColumnName = "FSEFDT"], [SourceColumnName = "FSRATER", DestinationColumnName = "FSRATER"], [SourceColumnName = "FSRATEI", DestinationColumnName = "FSRATEI"], [SourceColumnName = "FSMNMLS", DestinationColumnName = "FSMNMLS"]}], DynamicSchema = false, UpdateMethod = [Kind = "Replace"], TypeSettings = [Kind = "Table"]]]}]
shared VW_FUEL_SURCHARGE_RATES = let
  Source = DB2.Database("S10A3543.STEVENSTRANSPORT.COM:447", "S10A3543", [HierarchicalNavigation = true, Implementation = "Microsoft"]),
  #"Navigation 1" = Source{[Schema = "FABRIC"]}[Data],
  #"Navigation 2" = #"Navigation 1"{[Name = "VW_FUEL_SURCHARGE_RATES"]}[Data]
in
  #"Navigation 2";
shared VW_FUEL_SURCHARGE_RATES_DataDestination = let
  Pattern = Lakehouse.Contents([CreateNavigationProperties = false, EnableFolding = false]),
  Navigation_1 = Pattern{[workspaceId = "a6d2c31b-0b03-4c60-a258-c2664c56fe3d"]}[Data],
  Navigation_2 = Navigation_1{[lakehouseId = "f9a73da1-08e4-4f3d-a67f-74623bfde721"]}[Data],
  TableNavigation = Navigation_2{[Id = "ibmi_fuel_surcharge_rates_bronze", ItemKind = "Table"]}[Data]
in
  TableNavigation;
