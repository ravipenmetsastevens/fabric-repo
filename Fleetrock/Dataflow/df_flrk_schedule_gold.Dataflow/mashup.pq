section Section1;
[DataDestinations = {[Definition = [Kind = "Reference", QueryName = "silver flrk_scheduled_maint_DataDestination", IsNewTarget = true], Settings = [Kind = "Manual", AllowCreation = true, ColumnSettings = [Mappings = {[SourceColumnName = "sched_maint_id", DestinationColumnName = "sched_maint_id"], [SourceColumnName = "sm_repair_order_id", DestinationColumnName = "sm_repair_order_id"], [SourceColumnName = "has_repair_order", DestinationColumnName = "has_repair_order"], [SourceColumnName = "sm_group", DestinationColumnName = "sm_group"], [SourceColumnName = "sm_vin", DestinationColumnName = "sm_vin"], [SourceColumnName = "sm_unit_number", DestinationColumnName = "sm_unit_number"], [SourceColumnName = "sm_start_date", DestinationColumnName = "sm_start_date"], [SourceColumnName = "sm_start_miles", DestinationColumnName = "sm_start_miles"], [SourceColumnName = "sm_start_engine_hours", DestinationColumnName = "sm_start_engine_hours"], [SourceColumnName = "sm_is_recurring", DestinationColumnName = "sm_is_recurring"], [SourceColumnName = "scheduled_days", DestinationColumnName = "scheduled_days"], [SourceColumnName = "scheduled_miles", DestinationColumnName = "scheduled_miles"], [SourceColumnName = "scheduled_engine_hours", DestinationColumnName = "scheduled_engine_hours"], [SourceColumnName = "sm_system_component_code", DestinationColumnName = "sm_system_component_code"], [SourceColumnName = "sm_tag", DestinationColumnName = "sm_tag"], [SourceColumnName = "sm_notes", DestinationColumnName = "sm_notes"], [SourceColumnName = "sm_became_due_datetime", DestinationColumnName = "sm_became_due_datetime"], [SourceColumnName = "sm_became_due_date", DestinationColumnName = "sm_became_due_date"]}], DynamicSchema = false, UpdateMethod = [Kind = "Replace"], TypeSettings = [Kind = "Table"]]]}]
shared #"silver flrk_scheduled_maint" = let
  Source = Fabric.Warehouse(null){[workspaceId = "a6d2c31b-0b03-4c60-a258-c2664c56fe3d"]}[Data]{[warehouseId = "f8578495-391e-4e7e-b791-4949397ba86f"]}[Data],
  #"Navigation 1" = Source{[Schema = "silver", Item = "flrk_scheduled_maint"]}[Data],
  #"Reordered columns" = Table.ReorderColumns(#"Navigation 1", {"sched_maint_id", "sm_ro_number", "sm_group", "sm_vin", "sm_unit_number", "sm_start_date", "sm_start_miles", "sm_start_engine_hours", "sm_is_recurring", "scheduled_days", "scheduled_miles", "scheduled_engine_hours", "sm_system_component_code", "sm_tag", "sm_notes", "sm_became_due_datetime"}),
  #"Renamed columns" = Table.RenameColumns(#"Reordered columns", {{"sm_ro_number", "sm_repair_order_id"}}),
  #"Added custom" = Table.AddColumn(#"Renamed columns", "has_repair_order", each if [sm_repair_order_id] = 0 then 0 else 1),
  #"Changed column type 1" = Table.TransformColumnTypes(#"Added custom", {{"has_repair_order", type logical}}),
  #"Reordered columns 1" = Table.ReorderColumns(#"Changed column type 1", {"sched_maint_id", "sm_repair_order_id", "has_repair_order", "sm_group", "sm_vin", "sm_unit_number", "sm_start_date", "sm_start_miles", "sm_start_engine_hours", "sm_is_recurring", "scheduled_days", "scheduled_miles", "scheduled_engine_hours", "sm_system_component_code", "sm_tag", "sm_notes", "sm_became_due_datetime"}),
  #"Duplicated column" = Table.DuplicateColumn(#"Reordered columns 1", "sm_became_due_datetime", "sm_became_due_datetime - Copy"),
  #"Changed column type" = Table.TransformColumnTypes(#"Duplicated column", {{"sm_became_due_datetime - Copy", type date}}),
  #"Renamed columns 1" = Table.RenameColumns(#"Changed column type", {{"sm_became_due_datetime - Copy", "sm_became_due_date"}})
in
  #"Renamed columns 1";
shared #"silver flrk_scheduled_maint_DataDestination" = let
  Pattern = Fabric.Warehouse([CreateNavigationProperties = false]),
  Navigation_1 = Pattern{[workspaceId = "a6d2c31b-0b03-4c60-a258-c2664c56fe3d"]}[Data],
  Navigation_2 = Navigation_1{[warehouseId = "f8578495-391e-4e7e-b791-4949397ba86f"]}[Data],
  TableNavigation = Navigation_2{[Item = "dim_maint_schedule", Schema = "dbo"]}?[Data]?
in
  TableNavigation;
