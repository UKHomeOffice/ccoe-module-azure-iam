# *********************************************************
# SUBSCRIPTIONS
# *********************************************************

# ---------------------------------------------------------
# New Subscriptions
# ---------------------------------------------------------

resource "azurerm_subscription" "subscriptions" {
  for_each = { for k, v in var.subscriptions : k => v if v.subscription_id == "" } # If subscription_id is empty

  subscription_name = each.value.name
  alias             = each.key
  billing_scope_id  = each.value.billing_scope_id_override != "" ? each.value.billing_scope_id_override : var.default_billing_scope_id
  workload          = each.value.is_devtest ? "DevTest" : "Production"
  tags              = each.value.tags

  lifecycle {
    ignore_changes = [tags]
  }

  # provisioner "local-exec" {
  #   # This is really important as it ensures the subscription creation waits until the corresponding alias
  #   # is also created. This is needed for the subsequent role assignment on the alias.
  #   # Without this, errors will happen.
  #   command     = "az account alias wait --name \"${each.key}\" --created"
  #   interpreter = ["bash", "-c"]
  # }
}

# ---------------------------------------------------------
# Existing Subscriptions
# ---------------------------------------------------------

resource "azurerm_subscription" "existing-subscriptions" {
  for_each = { for k, v in var.subscriptions : k => v if v.subscription_id != "" } # If subscription_id is NOT empty

  subscription_name = each.value.name
  alias             = each.key
  subscription_id   = each.value.subscription_id
  workload          = each.value.is_devtest ? "DevTest" : "Production"
  tags              = each.value.tags

  lifecycle {
    ignore_changes = [tags]
  }

  # provisioner "local-exec" {
  #   # This is really important as it ensures the subscription creation waits until the corresponding alias
  #   # is also created. This is needed for the subsequent role assignment on the alias.
  #   # Without this, errors will happen.
  #   command     = "az account alias wait --name \"${each.key}\" --created"
  #   interpreter = ["bash", "-c"]
  # }
}

# ---------------------------------------------------------
# Link To Management Groups
# ---------------------------------------------------------

locals {
  all_subs = merge(azurerm_subscription.subscriptions, azurerm_subscription.existing-subscriptions)
}

resource "azurerm_management_group_subscription_association" "subscription-mgmt-group-assoc" {
  for_each = { for k, v in var.subscriptions : k => v if v.management_group_id != "" } # If management_group_id is NOT empty

  management_group_id = local.all_mgmt_groups[each.value.management_group_id].id
  subscription_id     = "/subscriptions/${local.all_subs[each.key].subscription_id}"

  depends_on = [azurerm_subscription.subscriptions, azurerm_subscription.existing-subscriptions]
}

# ---------------------------------------------------------
# Delegations
# ---------------------------------------------------------

locals {
  # Get a formatted map of all delegations for all subscriptions and all roles
  # e.g subdel-user1@example.com-subscription-owner => { principal = "user1@example.com", subscription = "subscription", is_existing_sub = false, role = "Reader", type = "user", is_pim = false, high_priv = false }
  all_sub_delegations = merge([for skey, svalue in var.subscriptions : merge([for dkey, dvalue in svalue.delegations : { for k, v in dvalue.objects : "subdel-${k}-${skey}-${dkey}" => { principal = k, subscription = skey, is_existing_sub = svalue.subscription_id == "" ? false : true, role = dkey, type = v, is_pim = dvalue.is_pim, high_priv = dvalue.allow_high_privilege_roles } }]...)]...)

  all_sub_users              = [for v in local.all_sub_delegations : v.principal if v.type == "user"]
  all_sub_guests             = [for v in local.all_sub_delegations : v.principal if v.type == "guest"]
  all_sub_groups             = [for v in local.all_sub_delegations : v.principal if v.type == "group"]
  all_sub_service_principals = [for v in local.all_sub_delegations : v.principal if v.type == "service_principal"]
}

resource "azurerm_role_assignment" "subscriptions-delegations" {
  for_each = { for k, v in local.all_sub_delegations : k => v if v.is_pim == false }

  scope                = each.value.is_existing_sub ? "/subscriptions/${azurerm_subscription.existing-subscriptions[each.value.subscription].subscription_id}" : "/subscriptions/${azurerm_subscription.subscriptions[each.value.subscription].subscription_id}"
  role_definition_name = contains(keys(local.azure_platform_roles), each.value.role) ? null : each.value.role
  role_definition_id   = contains(keys(local.azure_platform_roles), each.value.role) ? azurerm_role_definition.azure-platform-roles[each.value.role].role_definition_resource_id : null
  principal_id         = each.value.type == "id" ? each.value.principal : endswith(each.value.type, "_tf") ? local.all_tf_resources[each.value.type][each.value.principal] : local.all_users_guests_groups_sps[each.value.principal].id # Only perform data lookup if ID NOT provided
  condition_version    = contains(local.high_priv_roles, each.value.role) ? each.value.high_priv ? null : local.high_priv_role_condition_version : null
  condition            = contains(local.high_priv_roles, each.value.role) ? each.value.high_priv ? null : local.high_priv_role_condition : null
}