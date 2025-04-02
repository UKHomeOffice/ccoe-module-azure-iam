# *********************************************************
# ENTRA ROLES
# *********************************************************

# ---------------------------------------------------------
# High Privleged Roles
# ---------------------------------------------------------

resource "azuread_directory_role" "global-administrator" {
  display_name = "Global Administrator"
}

resource "azuread_directory_role" "privileged-role-administrator" {
  display_name = "Privileged Role Administrator"
}

resource "azuread_directory_role" "privileged-authentication-administrator" {
  display_name = "Privileged Authentication Administrator"
}

resource "azuread_directory_role" "global-reader" {
  display_name = "Global Reader"
}


# ---------------------------------------------------------
# Everything Else
# ---------------------------------------------------------

locals {
  # These roles are used elsewhere in the code so must ALWAYS be defined in addition to the user defined role assignments
  roles = ["Authentication Administrator"]
}

resource "azuread_directory_role" "roles" {
  for_each = toset(concat(local.roles, keys(var.role_assignments_permanent), keys(var.role_assignments_pim), local.all_cap_roles))

  display_name = each.key
}