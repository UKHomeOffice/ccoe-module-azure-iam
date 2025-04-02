# *********************************************************
# BREAKGLASS
# *********************************************************

# ---------------------------------------------------------
# Create Breakglass Users
# ---------------------------------------------------------

resource "azuread_user" "breakglass-users" {
  for_each = toset(var.breakglass_users)

  user_principal_name         = "${each.value}@${local.default_domain}"
  display_name                = each.value
  password                    = random_password.temp-pwd.result
  disable_password_expiration = true
  force_password_change       = false
  show_in_address_list        = false

  lifecycle {
    ignore_changes = [password] # Ignore pwd changes - used for imported users
  }
}

locals {
  breakglass_users_ids = [for user in azuread_user.breakglass-users : user.object_id] # Used in conditional access exceptions
}

# ---------------------------------------------------------
# Delegate Global Administrator Role
# ---------------------------------------------------------

resource "azuread_directory_role_assignment" "breakglass-globaladministrator" {
  for_each = toset(var.breakglass_users)

  role_id             = azuread_directory_role.global-administrator.template_id
  principal_object_id = azuread_user.breakglass-users[each.value].object_id
}

# ---------------------------------------------------------
# Setup Alert On Login Action Group
# ---------------------------------------------------------

resource "azurerm_monitor_action_group" "breakglass-action-group" {
  count = length(var.breakglass_users) > 0 ? 1 : 0 # Only create if breakglass users are given

  name                = "${var.prefix}-Breakglass-Login-Alert"
  resource_group_name = azurerm_resource_group.logs-rg[0].name
  short_name          = "${var.prefix}-BG-Login"
  tags                = var.tags

  dynamic "azure_app_push_receiver" {
    for_each = [for k, v in var.alert_on_breakglass_login : k if v == "push"]
    content {
      name          = azure_app_push_receiver.value
      email_address = azure_app_push_receiver.value
    }
  }

  dynamic "email_receiver" {
    for_each = [for k, v in var.alert_on_breakglass_login : k if v == "email"]
    content {
      name                    = email_receiver.value
      email_address           = email_receiver.value
      use_common_alert_schema = true
    }
  }

  dynamic "sms_receiver" {
    for_each = [for k, v in var.alert_on_breakglass_login : k if v == "sms"]
    content {
      name         = sms_receiver.value
      country_code = split("_", sms_receiver.value)[0] # Parse out the country code before underscore e.g 44_123456789
      phone_number = split("_", sms_receiver.value)[1] # Parse out the main number after the underscore e.g 44_123456789
    }
  }

  dynamic "voice_receiver" {
    for_each = [for k, v in var.alert_on_breakglass_login : k if v == "voice"]
    content {
      name         = voice_receiver.value
      country_code = split("_", voice_receiver.value)[0] # Parse out the country code before underscore e.g 44_123456789
      phone_number = split("_", voice_receiver.value)[1] # Parse out the main number after the underscore e.g 44_123456789
    }
  }

  dynamic "webhook_receiver" {
    for_each = [for k, v in var.alert_on_breakglass_login : k if v == "webhook"]
    content {
      name                    = webhook_receiver.value
      service_uri             = webhook_receiver.value
      use_common_alert_schema = true
    }
  }
}

# ---------------------------------------------------------
# Setup Alert On Login Rule
# ---------------------------------------------------------

locals {
  query_where = join(" or ", [for bg_user in azuread_user.breakglass-users : "UserId == \"${bg_user.id}\""])
}

resource "azurerm_monitor_scheduled_query_rules_alert_v2" "breakglass-alert" {
  count = length(var.breakglass_users) > 0 ? 1 : 0 # Only create if breakglass users are given

  name                = "Breakglass-Login-Alert"
  resource_group_name = azurerm_resource_group.logs-rg[0].name
  location            = azurerm_resource_group.logs-rg[0].location
  tags                = var.tags

  evaluation_frequency = "PT5M" # 5 mins
  window_duration      = "PT5M" # 5 mins
  scopes               = [azurerm_log_analytics_workspace.logs-loganal[0].id]
  severity             = 0 # Critical

  criteria {
    query                   = <<-QUERY
      SigninLogs
        | project UserId 
        | where ${local.query_where}
      QUERY
    time_aggregation_method = "Count"
    threshold               = 0
    operator                = "GreaterThan"

    failing_periods {
      minimum_failing_periods_to_trigger_alert = 1
      number_of_evaluation_periods             = 1
    }
  }

  description           = "Alert when break glass account is logged into."
  enabled               = true
  skip_query_validation = true

  action {
    action_groups = [azurerm_monitor_action_group.breakglass-action-group[0].id]
  }
}