# *********************************************************
# SERVICE PRINCIPALS
# *********************************************************

# A Service Principal Object: The Service Principal Object is what you see under the Enterprise Registration in Azure active directory blade. 
# This is used for authorization. 
# E.g. New-AzRoleAssignment -ObjectId <Object ID from Enterprise App> -RoleDefinitionName XX -Scope XX

resource "azuread_service_principal" "service-principals" {
  for_each = { for k, v in var.app_registrations_service_principals : k => v if v.requires_service_principal }

  client_id = azuread_application_registration.app-registrations[each.key].client_id
  owners    = [for k, v in azuread_application_owner.app-registrations-owners : v.owner_object_id if startswith(trimprefix(k, "appregowner-"), each.key)]

  feature_tags {
    # Set both as true as this is Azure default when creating in the portal
    enterprise = true # Means SP appears under "Enterprise Applications" blade
    hide       = true # Makes app invisible to users in My Apps and Office 365 Launcher
  }

  lifecycle {
    # This is to allow the created service principals to be managed outside of this code.
    ignore_changes = [account_enabled, alternative_names, app_role_assignment_required, description, feature_tags, login_url, notes, notification_email_addresses, preferred_single_sign_on_mode, saml_single_sign_on]
  }
}