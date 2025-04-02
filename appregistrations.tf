# *********************************************************
# APP REGISTRATIONS
# *********************************************************

# An Application Object: The Application Object is what you see under App Registrations in Azure active directory blade. 
# Along with Client Secret, this is used for authentication. 
# E.g. Connect-AzAccount -Credential <Credential PS Object With AppID> -Tenant XXX -ServicePrincipal

resource "azuread_application_registration" "app-registrations" {
  for_each = var.app_registrations_service_principals

  display_name = "${var.prefix}-${each.value.display_name}"

  lifecycle {
    # Ignore all available params apart from display_name - this is to allow the created app registrations to be managed outside of this code.
    ignore_changes = [description, group_membership_claims, implicit_access_token_issuance_enabled, implicit_id_token_issuance_enabled, notes, requested_access_token_version, service_management_reference, sign_in_audience, homepage_url, logout_url, marketing_url, privacy_statement_url, support_url, terms_of_service_url]
  }
}

locals {
  # Get a formatted map of all owners of all app registrations
  # e.g appregowner-PREFIX-TEST-user1@example.com => { principal = "user1@example.com", app_reg_sp = "TEST", type = "user" }
  all_app_reg_sp_owners = merge([for arkey, arvalue in var.app_registrations_service_principals : { for okey, ovalue in arvalue.owners : "appregowner-${arkey}-${okey}" => { principal = okey, app_reg_sp = arkey, type = ovalue, has_sp = arvalue.requires_service_principal } } if can(arvalue.owners)]...)

  all_app_reg_sp_owner_users              = [for v in local.all_app_reg_sp_owners : v.principal if v.type == "user"]
  all_app_reg_sp_owner_guests             = [for v in local.all_app_reg_sp_owners : v.principal if v.type == "guest"]
  all_app_reg_sp_owner_groups             = [for v in local.all_app_reg_sp_owners : v.principal if v.type == "group"]
  all_app_reg_sp_owner_service_principals = [for v in local.all_app_reg_sp_owners : v.principal if v.type == "service_principal"]
}

resource "azuread_application_owner" "app-registrations-owners" {
  for_each = local.all_app_reg_sp_owners

  application_id  = azuread_application_registration.app-registrations[each.value.app_reg_sp].id
  owner_object_id = each.value.type == "id" ? each.value.principal : each.value.type == "guest_tf" ? azuread_invitation.guest-users[each.value.principal].user_id : local.all_users_guests_groups_sps[each.value.principal].id
}