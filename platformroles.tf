# *********************************************************
# AZURE PLATFORM ROLES
# *********************************************************

locals{
  azure_platform_roles = {
    "Admin" = {
      description = "Top level Azure platform administration."
      high_priv   = true
      actions     = [
        # User Access Admin Role
        "*/read",
        "Microsoft.Authorization/*",
        "Microsoft.Support/*",
        # Management Group Actions
        "Microsoft.Management/*",
        # Subscription Actions (including aliases)
        "Microsoft.Subscription/*"
      ]
      not_actions = []
    }
    "Support" = {
      description = "Top level Azure platform support."
      high_priv   = true
      actions     = [
        # User Access Admin Role
        "*/read",
        "Microsoft.Authorization/*",
        "Microsoft.Support/*",
      ]
      not_actions = []
    }
    "FinOps" = {
      description = "Top level Azure platform FinOps."
      high_priv   = false
      actions     = [
        # Advisor Recommendations Contributor (Assessments and Reviews)
        "Microsoft.Advisor/recommendations/read",
        "Microsoft.Advisor/recommendations/write",
        "Microsoft.Advisor/recommendations/available/action",
        # Billing Reader
        "Microsoft.Authorization/*/read",
        "Microsoft.Billing/*/read",
        "Microsoft.Commerce/*/read",
        "Microsoft.Consumption/*/read",
        "Microsoft.Management/managementGroups/read",
        "Microsoft.CostManagement/*/read",
        "Microsoft.Support/*"        
      ]
      not_actions = []
    }
    "Security" = {
      description = "Top level Azure platform security."
      high_priv   = false
      actions     = [
        # Security Admin (excluding policy)
        "Microsoft.Authorization/*/read",
        # "Microsoft.Authorization/policyAssignments/*",
        # "Microsoft.Authorization/policyDefinitions/*",
        # "Microsoft.Authorization/policyExemptions/*",
        # "Microsoft.Authorization/policySetDefinitions/*",
        "Microsoft.Insights/alertRules/*",
        "Microsoft.Management/managementGroups/read",
        "Microsoft.operationalInsights/workspaces/*/read",
        "Microsoft.Resources/deployments/*",
        "Microsoft.Resources/subscriptions/resourceGroups/read",
        "Microsoft.Security/*",
        "Microsoft.IoTSecurity/*",
        "Microsoft.IoTFirmwareDefense/*",
        "Microsoft.Support/*"
      ]
      not_actions = []
    }
  }
}

# ---------------------------------------------------------
# Create Custom Azure Roles
# ---------------------------------------------------------

resource "azurerm_role_definition" "azure-platform-roles" {
  for_each = local.azure_platform_roles

  name        = "${var.prefix} Platform ${each.key}"
  scope       = local.tenant_root_mgmt_group
  description = each.value.description

  permissions {
    actions     = each.value.actions
    not_actions = each.value.not_actions
  }

  assignable_scopes = [
    local.tenant_root_mgmt_group,
  ]
}