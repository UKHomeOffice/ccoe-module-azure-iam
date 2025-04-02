# *********************************************************
# DATA
# *********************************************************

# ---------------------------------------------------------
# Tenant Details
# ---------------------------------------------------------

data "azurerm_client_config" "current" {}

data "azuread_domains" "default_domain" {
  only_default = true
}

locals {
  default_domain = data.azuread_domains.default_domain.domains[0].domain_name
}

# ---------------------------------------------------------
# Users
# ---------------------------------------------------------

locals {
  users = toset(distinct(concat(local.all_au_users, local.all_group_users, local.all_cap_users, local.all_sub_users, local.all_mg_users, local.all_app_reg_sp_owner_users, local.all_role_assignments_users)))
}

data "azuread_user" "users" {
  for_each = local.users

  user_principal_name = each.key
}

# ---------------------------------------------------------
# Guests
# ---------------------------------------------------------

locals {
  guests = toset(distinct(concat(local.all_au_guests, local.all_group_guests, local.all_cap_guests, local.all_sub_guests, local.all_mg_guests, local.all_app_reg_sp_owner_guests, local.all_role_assignments_guests)))
}

data "azuread_user" "guests" {
  for_each = local.guests

  user_principal_name = "${replace(each.key, "@", "_")}#EXT#@${local.default_domain}"
}

# ---------------------------------------------------------
# Groups
# ---------------------------------------------------------

locals {
  groups = toset(distinct(concat(local.all_au_groups, local.all_cap_groups, local.all_sub_groups, local.all_mg_groups, local.all_app_reg_sp_owner_groups, local.all_role_assignments_groups, local.all_group_groups)))
}

data "azuread_group" "groups" {
  for_each = local.groups

  display_name = each.key
}

# ---------------------------------------------------------
# Service Principals
# ---------------------------------------------------------

locals {
  service_principals = toset(distinct(concat(local.all_au_service_principals, local.all_cap_service_principals, local.all_sub_service_principals, local.all_mg_service_principals, local.all_app_reg_sp_owner_service_principals, local.all_role_assignments_service_principals, local.all_group_service_principals)))
}

data "azuread_service_principal" "service-principals" {
  for_each = local.service_principals

  display_name = each.key
}

# ---------------------------------------------------------
# Merge Users / Groups / Service Principals
# ---------------------------------------------------------

locals {
  all_users_guests            = merge(data.azuread_user.users, data.azuread_user.guests)
  all_users_guests_groups_sps = merge(data.azuread_user.users, data.azuread_user.guests, data.azuread_group.groups, data.azuread_service_principal.service-principals)
}

# ---------------------------------------------------------
# Applications
# ---------------------------------------------------------

locals {
  apps = toset(distinct(concat(local.all_cap_custom_apps)))
}

# Custom
data "azuread_application" "apps" {
  for_each = local.apps

  display_name = each.key
}

# Microsoft
data "azuread_application_published_app_ids" "microsoft" {}

# ---------------------------------------------------------
# Locations
# ---------------------------------------------------------

locals {
  locations = toset(distinct(concat(local.all_cap_locations, local.all_restricted_locations)))
}

data "azuread_named_location" "locations" {
  for_each = local.locations

  display_name = each.key
}