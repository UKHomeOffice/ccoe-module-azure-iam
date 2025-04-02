# *********************************************************
# ROLE ASSIGNMENTS
# *********************************************************

locals {
  # Get a formatted map of all permanent role assignments for each user
  # e.g roleassignment-Global Reader-user1@example.com => { principal = "user1@example.com", role = "Global Reader", type = "user" }
  all_permanent_role_assignments = merge([for rakey, ravalue in var.role_assignments_permanent : { for pkey, pvalue in ravalue : "roleassignmentperm-${rakey}-${pkey}" => { principal = pkey, role = rakey, type = pvalue } } if can(ravalue)]...)

  all_permanent_role_assignments_users              = [for v in local.all_permanent_role_assignments : v.principal if v.type == "user"]
  all_permanent_role_assignments_guests             = [for v in local.all_permanent_role_assignments : v.principal if v.type == "guest"]
  all_permanent_role_assignments_groups             = [for v in local.all_permanent_role_assignments : v.principal if v.type == "group"]
  all_permanent_role_assignments_service_principals = [for v in local.all_permanent_role_assignments : v.principal if v.type == "service_principal"]

  all_pim_role_assignments = merge([for rakey, ravalue in var.role_assignments_pim : { for pkey, pvalue in ravalue : "roleassignmentpim-${rakey}-${pkey}" => { principal = pkey, role = rakey, type = pvalue } } if can(ravalue)]...)

  all_pim_role_assignments_users              = [for v in local.all_pim_role_assignments : v.principal if v.type == "user"]
  all_pim_role_assignments_guests             = [for v in local.all_pim_role_assignments : v.principal if v.type == "guest"]
  all_pim_role_assignments_groups             = [for v in local.all_pim_role_assignments : v.principal if v.type == "group"]
  all_pim_role_assignments_service_principals = [for v in local.all_pim_role_assignments : v.principal if v.type == "service_principal"]

  all_role_assignments_users              = concat(local.all_permanent_role_assignments_users, local.all_pim_role_assignments_users)
  all_role_assignments_guests             = concat(local.all_permanent_role_assignments_guests, local.all_pim_role_assignments_guests)
  all_role_assignments_groups             = concat(local.all_permanent_role_assignments_groups, local.all_pim_role_assignments_groups)
  all_role_assignments_service_principals = concat(local.all_permanent_role_assignments_service_principals, local.all_pim_role_assignments_service_principals)
}

# ---------------------------------------------------------
# Permanent
# ---------------------------------------------------------

resource "azuread_directory_role_assignment" "permanent-role-assignment" {
  for_each = local.all_permanent_role_assignments

  role_id             = azuread_directory_role.roles[each.value.role].template_id
  principal_object_id = each.value.type == "id" ? each.value.principal : endswith(each.value.type, "_tf") ? local.all_tf_resources[each.value.type][each.value.principal] : local.all_users_guests_groups_sps[each.value.principal].id
}

# ---------------------------------------------------------
# PIM
# ---------------------------------------------------------

# The below does not work properly, see - 

# https://github.com/hashicorp/terraform-provider-azuread/issues/1234
# and!
# https://github.com/hashicorp/terraform-provider-azuread/issues/1306
# and!
# https://github.com/hashicorp/terraform-provider-azuread/issues/1386

# resource "azuread_directory_role_eligibility_schedule_request" "pim-role-assignment" {
#   for_each = local.all_pim_role_assignments

#   role_definition_id = azuread_directory_role.roles[each.value.role].template_id
#   principal_id       = each.value.type == "id" ? each.value.principal : endswith(each.value.type, "_tf") ? local.all_tf_resources[each.value.type][each.value.principal] : local.all_users_guests_groups_sps[each.value.principal].id
#   directory_scope_id = "/"
#   justification      = "Assigned via IAM Azure Terraform - see code for details."
# }