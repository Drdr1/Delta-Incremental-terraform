# ------------------------------------------------------------------------------
# Data Integration — Workspace
# ------------------------------------------------------------------------------
resource "oci_dataintegration_workspace" "this" {
  compartment_id = var.compartment_id
  display_name   = var.di_workspace_name
  is_private_network_enabled = false
}

# ------------------------------------------------------------------------------
# Data Integration — Application
# ------------------------------------------------------------------------------
resource "oci_dataintegration_workspace_application" "this" {
  workspace_id = oci_dataintegration_workspace.this.id
  name         = var.di_application_name
  identifier   = var.di_application_identifier
  model_type   = "INTEGRATION_APPLICATION"
}

# ------------------------------------------------------------------------------
# Data Integration — Project
# ------------------------------------------------------------------------------
resource "oci_dataintegration_workspace_project" "delta_copy" {
  workspace_id = oci_dataintegration_workspace.this.id
  name         = var.di_project_name
  identifier   = var.di_project_identifier
  description  = "Project for the Delta incremental copy task"
}

# ------------------------------------------------------------------------------
# Data Integration — OCI Data Flow Task (via CLI)
# ------------------------------------------------------------------------------
locals {
  delta_copy_di_task_payload = jsonencode({
    identifier  = var.di_task_identifier
    name        = var.di_task_name
    description = "Runs the Delta incremental copy OCI Data Flow application"
    workspaceId = oci_dataintegration_workspace.this.id

    registryMetadata = {
      aggregatorKey = oci_dataintegration_workspace_project.delta_copy.key
    }

    parentRef = {
      parent = oci_dataintegration_workspace_project.delta_copy.key
    }

    dataflowApplication = {
      applicationId = oci_dataflow_application.delta_copy.id
      compartmentId = var.compartment_id
    }

    isConcurrentAllowed = false
  })
}

resource "terraform_data" "delta_copy_oci_dataflow_task" {
  triggers_replace = {
    payload_sha    = sha256(local.delta_copy_di_task_payload)
    workspace_id   = oci_dataintegration_workspace.this.id
    project_key    = oci_dataintegration_workspace_project.delta_copy.key
    app_id         = oci_dataflow_application.delta_copy.id
    compartment_id = var.compartment_id
  }

  provisioner "local-exec" {
    command = "bash ${path.module}/create_dataflow_task.sh"

    environment = {
      WORKSPACE_ID    = oci_dataintegration_workspace.this.id
      TASK_IDENTIFIER = var.di_task_identifier
      TASK_PAYLOAD    = local.delta_copy_di_task_payload
    }
  }
}

# ------------------------------------------------------------------------------
# Look up the task key after CLI creation
# ------------------------------------------------------------------------------
data "external" "delta_copy_task_key" {
  depends_on = [terraform_data.delta_copy_oci_dataflow_task]

  program = [
    "bash", "-c",
    "KEY=$(oci data-integration task list --workspace-id '${oci_dataintegration_workspace.this.id}' --identifier '${var.di_task_identifier}' --type OCI_DATAFLOW_TASK --all --query 'data.items[0].key' --raw-output 2>/dev/null) && echo \"{\\\"key\\\": \\\"$KEY\\\"}\""
  ]
}

# ------------------------------------------------------------------------------
# Data Integration — Publish task to application
# ------------------------------------------------------------------------------
resource "oci_dataintegration_workspace_application_patch" "delta_copy_publish" {
  workspace_id    = oci_dataintegration_workspace.this.id
  application_key = oci_dataintegration_workspace_application.this.key

  name       = "Publish-${var.di_task_name}"
  identifier = "PUBLISH_${var.di_task_identifier}"
  patch_type = "PUBLISH"

  object_keys = [
    data.external.delta_copy_task_key.result.key
  ]
}

# ------------------------------------------------------------------------------
# Published task metadata
# ------------------------------------------------------------------------------
locals {
  di_published_task_candidates = [
    for o in oci_dataintegration_workspace_application_patch.delta_copy_publish.patch_object_metadata :
    o if o.identifier == var.di_task_identifier
  ]
  di_published_task = one(local.di_published_task_candidates)
}

# ------------------------------------------------------------------------------
# Data Integration — Daily Schedule
# ------------------------------------------------------------------------------
resource "oci_dataintegration_workspace_application_schedule" "daily" {
  workspace_id    = oci_dataintegration_workspace.this.id
  application_key = oci_dataintegration_workspace_application.this.key
  name            = var.di_schedule_name
  identifier      = var.di_schedule_identifier
  timezone        = var.schedule_timezone

  frequency_details {
    model_type = "DAILY"
    frequency  = "DAILY"

    time {
      hour   = var.schedule_hour
      minute = var.schedule_minute
    }
  }
}

# ------------------------------------------------------------------------------
# Data Integration — Task Schedule
# ------------------------------------------------------------------------------
resource "oci_dataintegration_workspace_application_task_schedule" "delta_copy" {
  workspace_id    = oci_dataintegration_workspace.this.id
  application_key = oci_dataintegration_workspace_application.this.key

  name       = var.di_task_schedule_name
  identifier = var.di_task_schedule_identifier

  is_enabled            = true
  is_concurrent_allowed = false
  number_of_retries     = 0

  parent_ref {
    parent = local.di_published_task.key
  }

  registry_metadata {
    aggregator_key = local.di_published_task.key
  }

  schedule_ref {
    key = oci_dataintegration_workspace_application_schedule.daily.key
  }

  depends_on = [
    oci_dataintegration_workspace_application_patch.delta_copy_publish,
    oci_dataintegration_workspace_application_schedule.daily
  ]
}
