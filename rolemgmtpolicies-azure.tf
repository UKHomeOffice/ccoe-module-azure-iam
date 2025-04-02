# *********************************************************
# ROLE MANAGEMENT POLICIES - AZURE
# *********************************************************

locals {
  all_azure_role_mgmt_policies_roles = distinct([for v in var.azure_role_mgmt_policies : v.role_name])
}

resource "azurerm_role_management_policy" "azure-role-mgmt-policies" {
  for_each = var.azure_role_mgmt_policies

  scope              = each.value.scope_type == "subscription_id" ? "/subscriptions/${each.value.scope}" : each.value.scope == "/" ? local.tenant_root_mgmt_group : "/providers/Microsoft.Management/managementGroups/${each.value.scope}"
  role_definition_id = data.azurerm_role_definition.user-defined[each.value.role_name].id

  active_assignment_rules {
    expiration_required = false
  }

  eligible_assignment_rules {
    expiration_required = false
  }

  activation_rules {
    maximum_duration                   = each.value.max_duration
    require_approval                   = each.value.require_approval
    require_justification              = each.value.require_justification
    require_multifactor_authentication = each.value.require_mfa

    approval_stage {
      dynamic "primary_approver" {
        for_each = each.value.approvers
        content {
          object_id = endswith(primary_approver.value, "_id") || primary_approver.value == "id" ? primary_approver.key : endswith(primary_approver.value, "_tf") ? local.all_tf_resources[primary_approver.value][primary_approver.key] : local.all_users_guests_groups_sps[primary_approver.key].id
          type      = startswith(primary_approver.value, "group") ? "Group" : "User" # Assume "User" unless starts with "group"
        }
      }
    }
  }

  notification_rules {
    active_assignments {
      admin_notifications {
        notification_level    = "All"
        default_recipients    = true
        additional_recipients = [for k, v in each.value.admin_notifications : k if contains(v, "active_assignment")]
      }
    }
    eligible_assignments {
      admin_notifications {
        notification_level    = "All"
        default_recipients    = true
        additional_recipients = [for k, v in each.value.admin_notifications : k if contains(v, "eligible_assignment")]
      }
    }
    eligible_activations {
      admin_notifications {
        notification_level    = "All"
        default_recipients    = true
        additional_recipients = [for k, v in each.value.admin_notifications : k if contains(v, "eligible_activation")]
      }
    }
  }
}