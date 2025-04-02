# *********************************************************
# MANAGEMENT GROUPS
# *********************************************************

# Cant be explained any better than -
# https://mikehosker.net/efficiently-creating-azure-management-groups-in-terraform/

locals {
  tenant_root_mgmt_group = "/providers/Microsoft.Management/managementGroups/${data.azurerm_client_config.current.tenant_id}"
  all_mgmt_groups        = { for key, value in merge(azurerm_management_group.level_1, azurerm_management_group.level_2, azurerm_management_group.level_3, azurerm_management_group.level_4, azurerm_management_group.level_5, azurerm_management_group.level_6) : basename(key) => value }

  all_mg_delegations = merge(local.all_mg_root_delegations, local.all_mg_level_1_delegations, local.all_mg_level_2_delegations, local.all_mg_level_3_delegations, local.all_mg_level_4_delegations, local.all_mg_level_5_delegations, local.all_mg_level_6_delegations)

  all_mg_users              = [for v in local.all_mg_delegations : v.principal if v.type == "user"]
  all_mg_guests             = [for v in local.all_mg_delegations : v.principal if v.type == "guest"]
  all_mg_groups             = [for v in local.all_mg_delegations : v.principal if v.type == "group"]
  all_mg_service_principals = [for v in local.all_mg_delegations : v.principal if v.type == "service_principal"]
}

# ---------------------------------------------------------
# Root
# ---------------------------------------------------------

resource "azurerm_management_group" "root" {
  display_name = var.root_management_group.name
}

locals {
  # Get a formatted map of all delegations for level 1 management groups and all roles
  # e.g mgdelroot-user1@example.com-owner => { principal = "user1@example.com", role = "Reader", type = "user", is_pim = false, high_priv = false }
  all_mg_root_delegations = merge([for dkey, dvalue in var.root_management_group.delegations : { for k, v in dvalue.objects : "mgdelroot-${k}-${dkey}" => { principal = k, role = dkey, type = v, is_pim = dvalue.is_pim, high_priv = dvalue.allow_high_privilege_roles } }]...)
}

resource "azurerm_role_assignment" "root-mg-delegations" {
  for_each = { for k, v in local.all_mg_root_delegations : k => v if v.is_pim == false }

  scope                = local.tenant_root_mgmt_group
  role_definition_name = contains(keys(local.azure_platform_roles), each.value.role) ? null : each.value.role
  role_definition_id   = contains(keys(local.azure_platform_roles), each.value.role) ? azurerm_role_definition.azure-platform-roles[each.value.role].role_definition_resource_id : null
  principal_id         = each.value.type == "id" ? each.value.principal : endswith(each.value.type, "_tf") ? local.all_tf_resources[each.value.type][each.value.principal] : local.all_users_guests_groups_sps[each.value.principal].id # Only perform data lookup if ID NOT provided
  condition_version    = contains(local.high_priv_roles, each.value.role) ? each.value.high_priv ? null : local.high_priv_role_condition_version : null
  condition            = contains(local.high_priv_roles, each.value.role) ? each.value.high_priv ? null : local.high_priv_role_condition : null
}

# ---------------------------------------------------------
# Level 1
# ---------------------------------------------------------

resource "azurerm_management_group" "level_1" {
  for_each = var.management_groups

  name                       = each.key
  display_name               = each.value.name
  parent_management_group_id = local.tenant_root_mgmt_group
}

locals {
  # Get a formatted map of all delegations for level 1 management groups and all roles
  # e.g mgdel-user1@example.com-TESTMG-owner => { principal = "user1@example.com", management_group = "TESTMG", role = "Reader", type = "user", is_pim = false }
  all_mg_level_1_delegations = merge([for mgkey, mgvalue in var.management_groups : merge([for dkey, dvalue in mgvalue.delegations : { for k, v in dvalue.objects : "mgdel-${k}-${mgkey}-${dkey}" => { principal = k, management_group = mgkey, role = dkey, type = v, is_pim = dvalue.is_pim, high_priv = dvalue.allow_high_privilege_roles } }]...)]...)
}

resource "azurerm_role_assignment" "level_1-mg-delegations" {
  for_each = { for k, v in local.all_mg_level_1_delegations : k => v if v.is_pim == false }

  scope                = azurerm_management_group.level_1[each.value.management_group].id
  role_definition_name = contains(keys(local.azure_platform_roles), each.value.role) ? null : each.value.role
  role_definition_id   = contains(keys(local.azure_platform_roles), each.value.role) ? azurerm_role_definition.azure-platform-roles[each.value.role].role_definition_resource_id : null
  principal_id         = each.value.type == "id" ? each.value.principal : endswith(each.value.type, "_tf") ? local.all_tf_resources[each.value.type][each.value.principal] : local.all_users_guests_groups_sps[each.value.principal].id # Only perform data lookup if ID NOT provided
  condition_version    = contains(local.high_priv_roles, each.value.role) ? each.value.high_priv ? null : local.high_priv_role_condition_version : null
  condition            = contains(local.high_priv_roles, each.value.role) ? each.value.high_priv ? null : local.high_priv_role_condition : null
}

# ---------------------------------------------------------
# Level 2
# ---------------------------------------------------------

locals {
  level_2 = zipmap(
    flatten([for key, value in var.management_groups : formatlist("${key}/%s", keys(value.children)) if value.children != null]),
    flatten([for value in var.management_groups : values(value.children) if value.children != null])
  )
}

resource "azurerm_management_group" "level_2" {
  for_each = local.level_2

  name                       = basename(each.key)
  display_name               = each.value.name
  parent_management_group_id = azurerm_management_group.level_1[trimsuffix(each.key, "/${basename(each.key)}")].id

  depends_on = [azurerm_management_group.level_1]
}

locals {
  # Get a formatted map of all delegations for level 1 management groups and all roles
  # e.g mgdel-user1@example.com-TESTMG-owner => { principal = "user1@example.com", management_group = "TESTMG", role = "Reader", type = "user", is_pim = false }
  all_mg_level_2_delegations = merge([for mgkey, mgvalue in local.level_2 : merge([for dkey, dvalue in mgvalue.delegations : { for k, v in dvalue.objects : "mgdel-${k}-${mgkey}-${dkey}" => { principal = k, management_group = mgkey, role = dkey, type = v, is_pim = dvalue.is_pim, high_priv = dvalue.allow_high_privilege_roles } }]...)]...)
}

resource "azurerm_role_assignment" "level_2-mg-delegations" {
  for_each = { for k, v in local.all_mg_level_2_delegations : k => v if v.is_pim == false }

  scope                = azurerm_management_group.level_2[each.value.management_group].id
  role_definition_name = contains(keys(local.azure_platform_roles), each.value.role) ? null : each.value.role
  role_definition_id   = contains(keys(local.azure_platform_roles), each.value.role) ? azurerm_role_definition.azure-platform-roles[each.value.role].role_definition_resource_id : null
  principal_id         = each.value.type == "id" ? each.value.principal : endswith(each.value.type, "_tf") ? local.all_tf_resources[each.value.type][each.value.principal] : local.all_users_guests_groups_sps[each.value.principal].id # Only perform data lookup if ID NOT provided
  condition_version    = contains(local.high_priv_roles, each.value.role) ? each.value.high_priv ? null : local.high_priv_role_condition_version : null
  condition            = contains(local.high_priv_roles, each.value.role) ? each.value.high_priv ? null : local.high_priv_role_condition : null
}

# ---------------------------------------------------------
# Level 3
# ---------------------------------------------------------

locals {
  level_3 = zipmap(
    flatten([for key, value in local.level_2 : formatlist("${key}/%s", keys(value.children)) if value.children != null]),
    flatten([for value in local.level_2 : values(value.children) if value.children != null])
  )
}

resource "azurerm_management_group" "level_3" {
  for_each = local.level_3

  name                       = basename(each.key)
  display_name               = each.value.name
  parent_management_group_id = azurerm_management_group.level_2[trimsuffix(each.key, "/${basename(each.key)}")].id

  depends_on = [azurerm_management_group.level_2]
}

locals {
  # Get a formatted map of all delegations for level 1 management groups and all roles
  # e.g mgdel-user1@example.com-TESTMG-owner => { principal = "user1@example.com", management_group = "TESTMG", role = "Reader", type = "user", is_pim = false }
  all_mg_level_3_delegations = merge([for mgkey, mgvalue in local.level_3 : merge([for dkey, dvalue in mgvalue.delegations : { for k, v in dvalue.objects : "mgdel-${k}-${mgkey}-${dkey}" => { principal = k, management_group = mgkey, role = dkey, type = v, is_pim = dvalue.is_pim, high_priv = dvalue.allow_high_privilege_roles } }]...)]...)
}

resource "azurerm_role_assignment" "level_3-mg-delegations" {
  for_each = { for k, v in local.all_mg_level_3_delegations : k => v if v.is_pim == false }

  scope                = azurerm_management_group.level_3[each.value.management_group].id
  role_definition_name = contains(keys(local.azure_platform_roles), each.value.role) ? null : each.value.role
  role_definition_id   = contains(keys(local.azure_platform_roles), each.value.role) ? azurerm_role_definition.azure-platform-roles[each.value.role].role_definition_resource_id : null
  principal_id         = each.value.type == "id" ? each.value.principal : endswith(each.value.type, "_tf") ? local.all_tf_resources[each.value.type][each.value.principal] : local.all_users_guests_groups_sps[each.value.principal].id # Only perform data lookup if ID NOT provided
  condition_version    = contains(local.high_priv_roles, each.value.role) ? each.value.high_priv ? null : local.high_priv_role_condition_version : null
  condition            = contains(local.high_priv_roles, each.value.role) ? each.value.high_priv ? null : local.high_priv_role_condition : null
}

# ---------------------------------------------------------
# Level 4
# ---------------------------------------------------------

locals {
  level_4 = zipmap(
    flatten([for key, value in local.level_3 : formatlist("${key}/%s", keys(value.children)) if value.children != null]),
    flatten([for value in local.level_3 : values(value.children) if value.children != null])
  )
}

resource "azurerm_management_group" "level_4" {
  for_each = local.level_4

  name                       = basename(each.key)
  display_name               = each.value.name
  parent_management_group_id = azurerm_management_group.level_3[trimsuffix(each.key, "/${basename(each.key)}")].id

  depends_on = [azurerm_management_group.level_3]
}

locals {
  # Get a formatted map of all delegations for level 1 management groups and all roles
  # e.g mgdel-user1@example.com-TESTMG-owner => { principal = "user1@example.com", management_group = "TESTMG", role = "Reader", type = "user", is_pim = false }
  all_mg_level_4_delegations = merge([for mgkey, mgvalue in local.level_4 : merge([for dkey, dvalue in mgvalue.delegations : { for k, v in dvalue.objects : "mgdel-${k}-${mgkey}-${dkey}" => { principal = k, management_group = mgkey, role = dkey, type = v, is_pim = dvalue.is_pim, high_priv = dvalue.allow_high_privilege_roles } }]...)]...)
}

resource "azurerm_role_assignment" "level_4-mg-delegations" {
  for_each = { for k, v in local.all_mg_level_4_delegations : k => v if v.is_pim == false }

  scope                = azurerm_management_group.level_4[each.value.management_group].id
  role_definition_name = contains(keys(local.azure_platform_roles), each.value.role) ? null : each.value.role
  role_definition_id   = contains(keys(local.azure_platform_roles), each.value.role) ? azurerm_role_definition.azure-platform-roles[each.value.role].role_definition_resource_id : null
  principal_id         = each.value.type == "id" ? each.value.principal : endswith(each.value.type, "_tf") ? local.all_tf_resources[each.value.type][each.value.principal] : local.all_users_guests_groups_sps[each.value.principal].id # Only perform data lookup if ID NOT provided
  condition_version    = contains(local.high_priv_roles, each.value.role) ? each.value.high_priv ? null : local.high_priv_role_condition_version : null
  condition            = contains(local.high_priv_roles, each.value.role) ? each.value.high_priv ? null : local.high_priv_role_condition : null
}

# ---------------------------------------------------------
# Level 5
# ---------------------------------------------------------

locals {
  level_5 = zipmap(
    flatten([for key, value in local.level_4 : formatlist("${key}/%s", keys(value.children)) if value.children != null]),
    flatten([for value in local.level_4 : values(value.children) if value.children != null])
  )
}

resource "azurerm_management_group" "level_5" {
  for_each = local.level_5

  name                       = basename(each.key)
  display_name               = each.value.name
  parent_management_group_id = azurerm_management_group.level_4[trimsuffix(each.key, "/${basename(each.key)}")].id

  depends_on = [azurerm_management_group.level_4]
}

locals {
  # Get a formatted map of all delegations for level 1 management groups and all roles
  # e.g mgdel-user1@example.com-TESTMG-owner => { principal = "user1@example.com", management_group = "TESTMG", role = "Reader", type = "user", is_pim = false }
  all_mg_level_5_delegations = merge([for mgkey, mgvalue in local.level_5 : merge([for dkey, dvalue in mgvalue.delegations : { for k, v in dvalue.objects : "mgdel-${k}-${mgkey}-${dkey}" => { principal = k, management_group = mgkey, role = dkey, type = v, is_pim = dvalue.is_pim, high_priv = dvalue.allow_high_privilege_roles } }]...)]...)
}

resource "azurerm_role_assignment" "level_5-mg-delegations" {
  for_each = { for k, v in local.all_mg_level_5_delegations : k => v if v.is_pim == false }

  scope                = azurerm_management_group.level_5[each.value.management_group].id
  role_definition_name = contains(keys(local.azure_platform_roles), each.value.role) ? null : each.value.role
  role_definition_id   = contains(keys(local.azure_platform_roles), each.value.role) ? azurerm_role_definition.azure-platform-roles[each.value.role].role_definition_resource_id : null
  principal_id         = each.value.type == "id" ? each.value.principal : endswith(each.value.type, "_tf") ? local.all_tf_resources[each.value.type][each.value.principal] : local.all_users_guests_groups_sps[each.value.principal].id # Only perform data lookup if ID NOT provided
  condition_version    = contains(local.high_priv_roles, each.value.role) ? each.value.high_priv ? null : local.high_priv_role_condition_version : null
  condition            = contains(local.high_priv_roles, each.value.role) ? each.value.high_priv ? null : local.high_priv_role_condition : null
}

# ---------------------------------------------------------
# Level 6
# ---------------------------------------------------------

locals {
  level_6 = zipmap(
    flatten([for key, value in local.level_5 : formatlist("${key}/%s", keys(value.children)) if value.children != null]),
    flatten([for value in local.level_5 : values(value.children) if value.children != null])
  )
}

resource "azurerm_management_group" "level_6" {
  for_each = local.level_6

  name                       = basename(each.key)
  display_name               = each.value.name
  parent_management_group_id = azurerm_management_group.level_5[trimsuffix(each.key, "/${basename(each.key)}")].id

  depends_on = [azurerm_management_group.level_5]
}

locals {
  # Get a formatted map of all delegations for level 1 management groups and all roles
  # e.g mgdel-user1@example.com-TESTMG-owner => { principal = "user1@example.com", management_group = "TESTMG", role = "Reader", type = "user", is_pim = false }
  all_mg_level_6_delegations = merge([for mgkey, mgvalue in local.level_6 : merge([for dkey, dvalue in mgvalue.delegations : { for k, v in dvalue.objects : "mgdel-${k}-${mgkey}-${dkey}" => { principal = k, management_group = mgkey, role = dkey, type = v, is_pim = dvalue.is_pim, high_priv = dvalue.allow_high_privilege_roles } }]...)]...)
}

resource "azurerm_role_assignment" "level_6-mg-delegations" {
  for_each = { for k, v in local.all_mg_level_6_delegations : k => v if v.is_pim == false }

  scope                = azurerm_management_group.level_6[each.value.management_group].id
  role_definition_name = contains(keys(local.azure_platform_roles), each.value.role) ? null : each.value.role
  role_definition_id   = contains(keys(local.azure_platform_roles), each.value.role) ? azurerm_role_definition.azure-platform-roles[each.value.role].role_definition_resource_id : null
  principal_id         = each.value.type == "id" ? each.value.principal : endswith(each.value.type, "_tf") ? local.all_tf_resources[each.value.type][each.value.principal] : local.all_users_guests_groups_sps[each.value.principal].id # Only perform data lookup if ID NOT provided
  condition_version    = contains(local.high_priv_roles, each.value.role) ? each.value.high_priv ? null : local.high_priv_role_condition_version : null
  condition            = contains(local.high_priv_roles, each.value.role) ? each.value.high_priv ? null : local.high_priv_role_condition : null
}