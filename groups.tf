# *********************************************************
# GROUPS
# *********************************************************

locals {
  # Get a formatted map of all owners of all groups
  # e.g groupowner-TEST-user1@example.com => { principal = "user1@example.com", group = "TEST", type = "user" }
  all_group_owners = merge([for gkey, gvalue in var.groups : { for okey, ovalue in gvalue.owners : "groupowner-${gkey}-${okey}" => { principal = okey, group = gkey, type = ovalue } } if can(gvalue.owners)]...)

  all_group_members = merge([for gkey, gvalue in var.groups : { for mkey, mvalue in gvalue.members : "groupmember-${gkey}-${mkey}" => { principal = mkey, group = gkey, type = mvalue } } if can(gvalue.members)]...)

  all_group_principals = merge(local.all_group_owners, local.all_group_members)

  all_group_users              = [for v in local.all_group_principals : v.principal if v.type == "user"]
  all_group_guests             = [for v in local.all_group_principals : v.principal if v.type == "guest"]
  all_group_groups             = [for v in local.all_group_principals : v.principal if v.type == "group"]
  all_group_service_principals = [for v in local.all_group_principals : v.principal if v.type == "service_principal"]

  all_groups = merge(azuread_group.groups-static, azuread_group.groups-dynamic)
}

# ---------------------------------------------------------
# Create Groups
# ---------------------------------------------------------

# Static
resource "azuread_group" "groups-static" {
  for_each = { for k, v in var.groups : k => v if v.type != "DYN" } # Only if group type NOT dynamic

  display_name = "${var.prefix}-${each.value.type}-${each.value.name}"
  # owners             = length(each.value.owners) > 0 ? [ for okey, ovalue in each.value.owners : ovalue == "id" ? okey : endswith(ovalue, "_tf") ? local.all_tf_resources[ovalue][okey] : local.all_users_guests_groups_sps[okey].id ] : null
  owners           = length(each.value.owners) > 0 ? [for okey, ovalue in each.value.owners : ovalue == "id" ? okey : local.all_users_guests_groups_sps[okey].id] : null
  security_enabled = true

  lifecycle {
    ignore_changes = [description, 
      administrative_unit_ids] # Do this as azuread_administrative_unit_member resource is being used
  }
}

# Dynamic
resource "azuread_group" "groups-dynamic" {
  for_each = { for k, v in var.groups : k => v if v.type == "DYN" } # Only if group type dynamic

  display_name     = "${var.prefix}-${each.value.type}-${each.value.name}"
  security_enabled = true
  types            = ["DynamicMembership"]

  dynamic_membership {
    enabled = true
    rule    = each.value.dynamic_rule
  }

  lifecycle {
    ignore_changes = [description]
  }
}

# ---------------------------------------------------------
# Assign Members
# ---------------------------------------------------------

resource "azuread_group_member" "group-members" {
  for_each = local.all_group_members

  group_object_id  = azuread_group.groups-static[each.value.group].id
  member_object_id = each.value.type == "id" ? each.value.principal : endswith(each.value.type, "_tf") ? local.all_tf_resources[each.value.type][each.value.principal] : local.all_users_guests_groups_sps[each.value.principal].id
}