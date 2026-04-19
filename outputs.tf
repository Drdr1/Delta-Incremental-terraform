output "dataflow_application_id" {
  description = "OCID of the Data Flow application"
  value       = oci_dataflow_application.delta_copy.id
}

output "dataflow_arguments" {
  description = "Script arguments passed to the Data Flow application"
  value       = local.script_arguments
}

output "di_workspace_id" {
  description = "OCID of the Data Integration workspace"
  value       = oci_dataintegration_workspace.this.id
}

output "di_application_key" {
  description = "Key of the Data Integration application"
  value       = oci_dataintegration_workspace_application.this.key
}

output "di_schedule_key" {
  description = "Key of the daily schedule"
  value       = oci_dataintegration_workspace_application_schedule.daily.key
}
