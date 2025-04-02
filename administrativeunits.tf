# *********************************************************
# ADMINISTRATIVE UNITS
# *********************************************************

# ---------------------------------------------------------
# Create AUs
# ---------------------------------------------------------

resource "azuread_administrative_unit" "administrative-units" {
  for_each = var.administrative_units

  display_name              = each.value.name
  description               = each.value.description
  hidden_membership_enabled = false
}

# ---------------------------------------------------------
# Get AU Administrators / Members
# ---------------------------------------------------------

locals {
  # Get a formatted map of all owners of all administrative units
  # e.g auadmin-TEST-user1@example.com => { principal = "user1@example.com", au = "TEST", type = "user" }
  all_au_administrators = merge([for aukey, auvalue in var.administrative_units : { for akey, avalue in auvalue.administrators : "auadmin-${aukey}-${akey}" => { principal = akey, au = aukey, type = avalue } } if can(auvalue.administrators)]...)

  all_au_members = merge([for aukey, auvalue in var.administrative_units : { for mkey, mvalue in auvalue.members : "aumember-${aukey}-${mkey}" => { principal = mkey, au = aukey, type = mvalue } } if can(auvalue.members)]...)

  all_au_principals = merge(local.all_au_administrators, local.all_au_members)

  all_au_users              = [for v in local.all_au_principals : v.principal if v.type == "user"]
  all_au_guests             = [for v in local.all_au_principals : v.principal if v.type == "guest"]
  all_au_groups             = [for v in local.all_au_principals : v.principal if v.type == "group"]
  all_au_service_principals = [for v in local.all_au_principals : v.principal if v.type == "service_principal"]
}

# ---------------------------------------------------------
# Delegate AU Administrators
# ---------------------------------------------------------

# Authentication Administrator
resource "azuread_administrative_unit_role_member" "administrative-units-administrators-authadmin" {
  for_each = local.all_au_administrators

  role_object_id                = azuread_directory_role.roles["Authentication Administrator"].id
  administrative_unit_object_id = azuread_administrative_unit.administrative-units[each.value.au].id
  member_object_id              = each.value.type == "id" ? each.value.principal : endswith(each.value.type, "_tf") ? local.all_tf_resources[each.value.type][each.value.principal] : local.all_users_guests_groups_sps[each.value.principal].id
}

# ---------------------------------------------------------
# Delegate AU Members
# ---------------------------------------------------------

resource "azuread_administrative_unit_member" "administrative-units-members" {
  for_each = local.all_au_members

  administrative_unit_object_id = azuread_administrative_unit.administrative-units[each.value.au].id
  member_object_id              = each.value.type == "id" ? each.value.principal : endswith(each.value.type, "_tf") ? local.all_tf_resources[each.value.type][each.value.principal] : local.all_users_guests_groups_sps[each.value.principal].id
}

# ---------------------------------------------------------
# Delegate AU Groups
# ---------------------------------------------------------

resource "azuread_administrative_unit_member" "administrative-units-groups" {
  for_each = { for k, v in var.groups : k => v if v.managed_by_au != "" }

  administrative_unit_object_id = azuread_administrative_unit.administrative-units[each.value.managed_by_au].id
  member_object_id              = each.value.type == "DYNA" ? azuread_group.groups-dynamic[each.key].object_id : azuread_group.groups-static[each.key].object_id
}