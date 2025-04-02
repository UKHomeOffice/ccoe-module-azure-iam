# *********************************************************
# OUTPUTS
# *********************************************************

# ---------------------------------------------------------
# Variables
# ---------------------------------------------------------

# ---------------------------------------------------------
# General
# ---------------------------------------------------------

output "var_prefix" {
  value = var.prefix
}

output "var_env" {
  value = var.env
}

output "var_region" {
  value = var.region
}

output "var_region_friendly" {
  value = var.region_friendly
}

# ---------------------------------------------------------
# Tags
# ---------------------------------------------------------

output "var_tags" {
  value = var.tags
}

# ---------------------------------------------------------
# Breakglass
# ---------------------------------------------------------

output "var_breakglass_users" {
  value = var.breakglass_users
}

output "var_alert_on_breakglass_login" {
  value = var.alert_on_breakglass_login
}

# ---------------------------------------------------------
# Top Level Admins
# ---------------------------------------------------------

output "var_top_level_admins" {
  value = var.top_level_admins
}

# ---------------------------------------------------------
# Azure Root Admins
# ---------------------------------------------------------

output "var_azure_root_admins" {
  value = var.azure_root_admins
}

# ---------------------------------------------------------
# Management Groups
# ---------------------------------------------------------

output "var_root_management_group" {
  value = var.root_management_group
}

output "var_management_groups" {
  value = var.management_groups
}

# ---------------------------------------------------------
# Subscriptions
# ---------------------------------------------------------

output "var_default_billing_scope_id" {
  value = var.default_billing_scope_id
}

output "var_subscriptions" {
  value = var.subscriptions
}

# ---------------------------------------------------------
# Administrative Units
# ---------------------------------------------------------

output "var_administrative_units" {
  value = var.administrative_units
}

# ---------------------------------------------------------
# Groups
# ---------------------------------------------------------

output "var_groups" {
  value = var.groups
}

# ---------------------------------------------------------
# Role Management Policies
# ---------------------------------------------------------

output "var_azure_role_mgmt_policies" {
  value = var.azure_role_mgmt_policies
}

output "var_group_role_mgmt_policies" {
  value = var.group_role_mgmt_policies
}

# ---------------------------------------------------------
# Role Assignments
# ---------------------------------------------------------

output "var_role_assignments_permanent" {
  value = var.role_assignments_permanent
}

output "var_role_assignments_pim" {
  value = var.role_assignments_pim
}

# ---------------------------------------------------------
# Custom Locations
# ---------------------------------------------------------

output "var_custom_locations" {
  value = var.custom_locations
}

# ---------------------------------------------------------
# Baseline Conditional Access
# ---------------------------------------------------------

output "var_enable_baseline_caps" {
  value = var.enable_baseline_caps
}

output "var_baseline_report_only" {
  value = var.baseline_report_only
}

output "var_location_restriction_report_only" {
  value = var.location_restriction_report_only
}

output "var_restricted_countries" {
  value = var.restricted_countries
}

output "var_include_unknown_countries" {
  value = var.include_unknown_countries
}

output "var_location_restriction_whitelist" {
  value = var.location_restriction_whitelist
}

output "var_restricted_locations" {
  value = var.restricted_locations
}

output "var_sign_in_frequency_report_only" {
  value = var.sign_in_frequency_report_only
}

output "var_sign_in_frequency_value" {
  value = var.sign_in_frequency_value
}

output "var_sign_in_frequency_units" {
  value = var.sign_in_frequency_units
}

output "var_persistent_browser_session" {
  value = var.persistent_browser_session
}

# ---------------------------------------------------------
# Conditional Access
# ---------------------------------------------------------

output "var_conditional_access" {
  value = var.conditional_access
}

# ---------------------------------------------------------
# Guest Users
# ---------------------------------------------------------

output "var_guest_invite_message" {
  value = var.guest_invite_message
}

output "var_guest_users" {
  value = var.guest_users
}

# ---------------------------------------------------------
# App Registrations / Service Principals
# ---------------------------------------------------------

output "var_app_registrations_service_principals" {
  value = var.app_registrations_service_principals
}

# ---------------------------------------------------------
# Logs
# ---------------------------------------------------------

output "var_enabled_logs" {
  value = var.enabled_logs
}

output "var_retention_in_days" {
  value = var.retention_in_days
}

# ---------------------------------------------------------
# Resources
# ---------------------------------------------------------

# ---------------------------------------------------------
# Breakglass Users
# ---------------------------------------------------------

output "breakglass_users" {
  value = azuread_user.breakglass-users
}

# ---------------------------------------------------------
# Top Level Admins
# ---------------------------------------------------------

output "top_level_admins" {
  value = azuread_user.topleveladmin-users
}

# ---------------------------------------------------------
# Management Groups
# ---------------------------------------------------------

output "management_groups" {
  value = local.all_mgmt_groups
}

# ---------------------------------------------------------
# Subscriptions
# ---------------------------------------------------------

output "subscriptions" {
  value = local.all_subs
}

# ---------------------------------------------------------
# Administrative Units
# ---------------------------------------------------------

output "administrative_units" {
  value = azuread_administrative_unit.administrative-units
}

# ---------------------------------------------------------
# Groups
# ---------------------------------------------------------

locals {
  group_types = ["TEAM", "DYN", "PERM", "APP", "AWS"]
}

output "all_groups" {
  value = local.all_groups
}

output "groups" {
  value = { for gt in local.group_types : gt => [ for gkey, gvalue in var.groups : gvalue.type == "DYN" ? azuread_group.groups-dynamic[gkey] : azuread_group.groups-static[gkey] if gvalue.type == gt ] }
}

# ---------------------------------------------------------
# Custom Locations
# ---------------------------------------------------------

output "custom_locations" {
  value = azuread_named_location.custom-locations
}

# ---------------------------------------------------------
# Guest Users
# ---------------------------------------------------------

output "guest_users" {
  value = azuread_invitation.guest-users
}

# ---------------------------------------------------------
# App Registrations / Service Principals
# ---------------------------------------------------------

output "app_registrations" {
  value = azuread_application_registration.app-registrations
}

output "service_principals" {
  value = azuread_service_principal.service-principals
}