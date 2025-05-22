# *********************************************************
# AZURE ROLES
# *********************************************************

# ---------------------------------------------------------
# High Privleged Roles
# ---------------------------------------------------------

locals {
  high_priv_roles_builtin = ["Owner", "User Access Administrator", "Role Based Access Control Administrator"]
  high_priv_roles_custom  = keys({ for rkey, rval in local.azure_platform_roles : rkey => rval if rval.high_priv })
  high_priv_roles         = concat(local.high_priv_roles_builtin, local.high_priv_roles_custom)
}

data "azurerm_role_definition" "high-privilege" {
  for_each = toset(local.high_priv_roles_builtin)

  name = each.value
}

locals {
  high_priv_roles_ids              = join(",", concat([for v in data.azurerm_role_definition.high-privilege : basename(v.id)], [ for role in local.high_priv_roles_custom : azurerm_role_definition.azure-platform-roles[role].role_definition_id ]))
  high_priv_role_condition_version = "2.0"
  # The below condition allows assignment of ANY role EXCEPT the high privilege roles specified above
  high_priv_role_condition = "((!(ActionMatches{'Microsoft.Authorization/roleAssignments/write'})) OR( @Request[Microsoft.Authorization/roleAssignments:RoleDefinitionId] ForAnyOfAllValues:GuidNotEquals {${local.high_priv_roles_ids}})) AND ((!(ActionMatches{'Microsoft.Authorization/roleAssignments/delete'})) OR (@Resource[Microsoft.Authorization/roleAssignments:RoleDefinitionId] ForAnyOfAllValues:GuidNotEquals {${local.high_priv_roles_ids}}))"
}

# ---------------------------------------------------------
# User Defined Roles
# ---------------------------------------------------------

data "azurerm_role_definition" "user-defined" {
  for_each = toset(local.all_azure_role_mgmt_policies_roles)

  name = each.value
}