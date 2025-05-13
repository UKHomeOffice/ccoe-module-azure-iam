# *********************************************************
# TOP LEVEL ADMINISTRATORS
# *********************************************************

# ---------------------------------------------------------
# Temp Pwd
# ---------------------------------------------------------

resource "random_password" "temp-pwd" {
  length           = 256
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

# ---------------------------------------------------------
# Create Users
# ---------------------------------------------------------

resource "azuread_user" "topleveladmin-users" {
  for_each = var.top_level_admins

  user_principal_name         = "${each.key}@${local.default_domain}"
  display_name                = "${each.value.first_name} ${each.value.last_name} (Admin)"
  given_name                  = each.value.first_name
  surname                     = each.value.last_name
  usage_location              = each.value.usage_location
  password                    = random_password.temp-pwd.result
  disable_password_expiration = false
  force_password_change       = false
  show_in_address_list        = false

  lifecycle {
    ignore_changes = [password] # Ignore pwd changes - used for imported users
  }
}

# ---------------------------------------------------------
# Create Admin Administrative Unit
# ---------------------------------------------------------

resource "azuread_administrative_unit" "admin-administrative-unit" {
  count = length(var.top_level_admins) > 0 ? 1 : 0 # Only create if top_level_admins are given

  display_name              = "Admin"
  description               = "Top level admins"
  hidden_membership_enabled = true
}

# ---------------------------------------------------------
# Add Admins to Administrative Unit
# ---------------------------------------------------------

resource "azuread_administrative_unit_member" "admin-administrative-unit-members" {
  for_each = var.top_level_admins

  administrative_unit_object_id = azuread_administrative_unit.admin-administrative-unit[0].id
  member_object_id              = azuread_user.topleveladmin-users[each.key].id
}

# ---------------------------------------------------------
# Delegate Global Reader Role
# ---------------------------------------------------------

# This role is always delegated permanently regardless of PIM
# for top level admins.

resource "azuread_directory_role_assignment" "topleveladmin-globalreader" {
  for_each = var.top_level_admins

  role_id             = azuread_directory_role.global-reader.template_id
  principal_object_id = azuread_user.topleveladmin-users[each.key].object_id
}

# ---------------------------------------------------------
# Delegate Permanent Roles
# ---------------------------------------------------------

# Global Administrator
resource "azuread_directory_role_assignment" "topleveladmin-globaladministrator" {
  for_each = { for k, v in var.top_level_admins : k => v if v.global_administrator && v.is_pim == false } # Only delegate if global_administrator = true

  role_id             = azuread_directory_role.global-administrator.template_id
  principal_object_id = azuread_user.topleveladmin-users[each.key].object_id
}

# Privileged Authentication Administrator
resource "azuread_directory_role_assignment" "topleveladmin-privauthadministrator" {
  for_each = { for k, v in var.top_level_admins : k => v if v.priv_auth_administrator && v.is_pim == false } # Only delegate if priv_auth_administrator = true

  role_id             = azuread_directory_role.privileged-authentication-administrator.template_id
  principal_object_id = azuread_user.topleveladmin-users[each.key].object_id
}

# Privileged Role Administrator
resource "azuread_directory_role_assignment" "topleveladmin-privroleadministrator" {
  for_each = { for k, v in var.top_level_admins : k => v if v.priv_role_administrator && v.is_pim == false } # Only delegate if priv_role_administrator = true

  role_id             = azuread_directory_role.privileged-role-administrator.template_id
  principal_object_id = azuread_user.topleveladmin-users[each.key].object_id
}

# ---------------------------------------------------------
# Delegate PIM Roles
# ---------------------------------------------------------

# Global Administrator
resource "azuread_directory_role_eligibility_schedule_request" "topleveladmin-globaladministrator" {
  for_each = { for k, v in var.top_level_admins : k => v if v.global_administrator && v.is_pim == true } # Only delegate if global_administrator = true

  role_definition_id = azuread_directory_role.global-administrator.template_id
  principal_id       = azuread_user.topleveladmin-users[each.key].object_id
  directory_scope_id = "/"
  justification      = "Assigned via IAM Azure Terraform - see code for details."
}

# Privileged Authentication Administrator
resource "azuread_directory_role_eligibility_schedule_request" "topleveladmin-privauthadministrator" {
  for_each = { for k, v in var.top_level_admins : k => v if v.priv_auth_administrator && v.is_pim == true } # Only delegate if priv_auth_administrator = true

  role_definition_id = azuread_directory_role.privileged-authentication-administrator.template_id
  principal_id       = azuread_user.topleveladmin-users[each.key].object_id
  directory_scope_id = "/"
  justification      = "Assigned via IAM Azure Terraform - see code for details."
}

# Privileged Role Administrator
resource "azuread_directory_role_eligibility_schedule_request" "topleveladmin-privroleadministrator" {
  for_each = { for k, v in var.top_level_admins : k => v if v.priv_role_administrator && v.is_pim == true } # Only delegate if priv_role_administrator = true

  role_definition_id = azuread_directory_role.privileged-role-administrator.template_id
  principal_id       = azuread_user.topleveladmin-users[each.key].object_id
  directory_scope_id = "/"
  justification      = "Assigned via IAM Azure Terraform - see code for details."
}

# ---------------------------------------------------------
# Delegate Azure Root Admin Role
# ---------------------------------------------------------

locals {
  root_admins = merge({ for principal, type in merge(var.azure_root_admins, { for k, v in var.top_level_admins : azuread_user.topleveladmin-users[k].object_id => "id" if v.azure_root_administrator && v.is_pim == false }) : "rootadmin-${principal}" => { principal = principal, type = type } })
}

resource "azurerm_role_assignment" "rootadmin-subalias" {
  for_each = local.root_admins

  scope                = "/providers/Microsoft.Subscription/" # This allows access to all subscription aliases
  role_definition_name = "Owner" # Owner on subscription aliases for the purpose of deletions etc.
  principal_id         = each.value.type == "id" ? each.value.principal : endswith(each.value.type, "_tf") ? local.all_tf_resources[each.value.type][each.value.principal] : local.all_users_guests_groups_sps[each.value.principal].id # Only perform data lookup if ID NOT provided

  lifecycle {
    ignore_changes = [ scope ] # This appears to be a bug :(
  }
}

resource "azurerm_role_assignment" "rootadmin-tenantroot" {
  for_each = local.root_admins

  scope              = local.tenant_root_mgmt_group # This allows access to the tenant root management group
  role_definition_id = azurerm_role_definition.azure-platform-roles["Admin"].role_definition_resource_id
  principal_id       = each.value.type == "id" ? each.value.principal : endswith(each.value.type, "_tf") ? local.all_tf_resources[each.value.type][each.value.principal] : local.all_users_guests_groups_sps[each.value.principal].id # Only perform data lookup if ID NOT provided
}