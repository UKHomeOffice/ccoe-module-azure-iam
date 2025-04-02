# *********************************************************
# LOGS
# *********************************************************

# ---------------------------------------------------------
# Create Resource Group
# ---------------------------------------------------------

resource "azurerm_resource_group" "logs-rg" {
  count = length(var.breakglass_users) > 0 || length(var.enabled_logs) > 0 ? 1 : 0 # Only create if breakglass users are given OR enabled_logs are set

  name     = "${var.prefix}-${var.env}-${var.region_friendly}-EntraLogs-RG"
  location = var.region
  tags     = var.tags
}

# ---------------------------------------------------------
# Create Log Analytics Workspace
# ---------------------------------------------------------

resource "azurerm_log_analytics_workspace" "logs-loganal" {
  count = length(var.breakglass_users) > 0 || length(var.enabled_logs) > 0 ? 1 : 0 # Only create if breakglass users are given OR enabled_logs are set

  name                = "${var.prefix}-${var.env}-${var.region_friendly}-EntraLogs-Log"
  resource_group_name = azurerm_resource_group.logs-rg[0].name
  location            = azurerm_resource_group.logs-rg[0].location
  tags                = var.tags

  sku               = "PerGB2018" # Basically has to be this
  retention_in_days = var.retention_in_days
}

# ---------------------------------------------------------
# Send Entra Logs
# ---------------------------------------------------------

locals {
  # Always include "SignInLogs" as its needed for reporting on breakglass sign ins
  enabled_logs = concat(var.enabled_logs, ["SignInLogs"])
}

resource "azurerm_monitor_aad_diagnostic_setting" "logs-diagsetting" {
  count = length(var.breakglass_users) > 0 || length(var.enabled_logs) > 0 ? 1 : 0 # Only create if breakglass users are given OR enabled_logs are set

  name                       = "IAM-to-LogAnalytics"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.logs-loganal[0].id

  dynamic "enabled_log" {
    for_each = local.enabled_logs
    content {
      category = enabled_log.value
      retention_policy {
        enabled = false
      }
    }
  }
}