# *********************************************************
# CONDITIONAL ACCESS
# *********************************************************

# ---------------------------------------------------------
# Baseline
# ---------------------------------------------------------

# Enforce MFA
resource "azuread_conditional_access_policy" "enforce-mfa" {
  count = var.enable_baseline_caps ? 1 : 0 # Only create if enable_baseline_caps is true

  display_name = "BASE-ALLOW-Enforce MFA"
  state        = var.baseline_report_only ? "enabledForReportingButNotEnforced" : "enabled"

  conditions {
    client_app_types = ["all"]

    applications {
      included_applications = ["All"]
      excluded_applications = []
    }

    users {
      included_users = ["All"]
      excluded_users = local.breakglass_users_ids # Always exclude breakglass users
    }
  }

  grant_controls {
    operator          = "OR"
    built_in_controls = ["mfa"]
  }
}

# Block Legacy Auth
resource "azuread_conditional_access_policy" "block-legacy-auth" {
  count = var.enable_baseline_caps ? 1 : 0 # Only create if enable_baseline_caps is true

  display_name = "BASE-BLOCK-Legacy Auth"
  state        = var.baseline_report_only ? "enabledForReportingButNotEnforced" : "enabled"

  conditions {
    client_app_types = ["exchangeActiveSync", "other"]

    applications {
      included_applications = ["All"]
      excluded_applications = []
    }

    users {
      included_users = ["All"]
      excluded_users = local.breakglass_users_ids # Always exclude breakglass users
    }
  }

  grant_controls {
    operator          = "OR"
    built_in_controls = ["block"]
  }
}

locals {
  all_restricted_locations = [for k, v in var.restricted_locations : k if v == "location"]
}

# Location Restrictions
resource "azuread_conditional_access_policy" "location-restriction" {
  count = var.enable_baseline_caps && length(var.restricted_countries) > 0 || var.include_unknown_countries ? 1 : 0 # Only create if enable_baseline_caps is true AND countries are specified OR include_unknown_countries is true

  display_name = "BASE-BLOCK-Location Restriction"
  state        = var.baseline_report_only ? "enabledForReportingButNotEnforced" : var.location_restriction_report_only ? "enabledForReportingButNotEnforced" : "enabled"

  conditions {
    client_app_types = ["all"]

    applications {
      included_applications = ["All"]
      excluded_applications = []
    }

    locations {
      excluded_locations = var.location_restriction_whitelist ? concat([azuread_named_location.restricted-countries[0].id], [for k, v in var.restricted_locations : v == "location_id" ? k : endswith(v, "_tf") ? azuread_named_location.custom-locations[k].id : data.azuread_named_location.locations[k].id]) : ["AllTrusted"]
      included_locations = var.location_restriction_whitelist ? ["All"] : concat([azuread_named_location.restricted-countries[0].id], [for k, v in var.restricted_locations : v == "location_id" ? k : endswith(v, "_tf") ? azuread_named_location.custom-locations[k].id : data.azuread_named_location.locations[k].id])
    }

    users {
      included_users = ["All"]
      excluded_users = local.breakglass_users_ids # Always exclude breakglass users
    }
  }

  grant_controls {
    operator          = "OR"
    built_in_controls = ["block"]
  }
}

# Sign In Frequency
resource "azuread_conditional_access_policy" "sign-in-frequency" {
  count = var.enable_baseline_caps ? 1 : 0 # Only create if enable_baseline_caps is true

  display_name = "BASE-ALLOW-Sign In Frequency"
  state        = var.baseline_report_only ? "enabledForReportingButNotEnforced" : var.sign_in_frequency_report_only ? "enabledForReportingButNotEnforced" : "enabled"

  conditions {
    client_app_types = ["all"]

    applications {
      included_applications = ["All"]
      excluded_applications = []
    }

    users {
      included_users = ["All"]
      excluded_users = local.breakglass_users_ids # Always exclude breakglass users
    }
  }

  session_controls {
    sign_in_frequency        = var.sign_in_frequency_value
    sign_in_frequency_period = var.sign_in_frequency_units
    persistent_browser_mode  = var.persistent_browser_session ? "always" : "never"
  }
}

# ---------------------------------------------------------
# Custom
# ---------------------------------------------------------

locals {
  # The below maps only purpose is for data lookups

  # Get a formatted map of all included and excluded principals in all CAPs
  # e.g capincludedprincipal-TEST-user1@example.com => { principal = "user1@example.com", cap = "TEST", type = "user" }
  all_cap_principals_included = merge([for cakey, cavalue in var.conditional_access : { for ikey, ivalue in cavalue.principals.included : "capincludedprincipal-${cakey}-${ikey}" => { principal = ikey, cap = cakey, type = ivalue } } if can(cavalue.principals.included)]...)
  all_cap_principals_excluded = merge([for cakey, cavalue in var.conditional_access : { for ekey, evalue in cavalue.principals.excluded : "capexcludedprincipal-${cakey}-${ekey}" => { principal = ekey, cap = cakey, type = evalue } } if can(cavalue.principals.excluded)]...)

  all_cap_principals = merge(local.all_cap_principals_included, local.all_cap_principals_excluded)

  all_cap_users              = [for v in local.all_cap_principals : v.principal if v.type == "user"]
  all_cap_guests             = [for v in local.all_cap_principals : v.principal if v.type == "guest"]
  all_cap_groups             = [for v in local.all_cap_principals : v.principal if v.type == "group"]
  all_cap_service_principals = [for v in local.all_cap_principals : v.principal if v.type == "service_principal"]
  all_cap_roles              = [for v in local.all_cap_principals : v.principal if v.type == "role"]

  # Get a formatted map of all included and excluded resources in all CAPs
  # e.g capincludedresouce-TEST-AzureDataBricks => { resource = "AzureDataBricks", cap = "TEST", type = "microsoft" }
  all_cap_resources_included = merge([for cakey, cavalue in var.conditional_access : { for ikey, ivalue in cavalue.resources.included : "capincludedresouce-${cakey}-${ikey}" => { resource = ikey, cap = cakey, type = ivalue } } if can(cavalue.resources.included)]...)
  all_cap_resources_excluded = merge([for cakey, cavalue in var.conditional_access : { for ekey, evalue in cavalue.resources.excluded : "capexcludedresouce-${cakey}-${ekey}" => { resource = ekey, cap = cakey, type = evalue } } if can(cavalue.resources.excluded)]...)

  all_cap_resources = merge(local.all_cap_resources_included, local.all_cap_resources_excluded)

  all_cap_custom_apps = [for v in local.all_cap_resources : v.resource if v.type == "app_custom"]

  # Get a formatted map of all included and excluded network in all CAPs
  # e.g capincludedresouce-TEST-AzureDataBricks => { resource = "AzureDataBricks", cap = "TEST", type = "microsoft" }
  all_cap_network_included = merge([for cakey, cavalue in var.conditional_access : { for ikey, ivalue in cavalue.network.included : "capincludednetwork-${cakey}-${ikey}" => { network = ikey, cap = cakey, type = ivalue } } if can(cavalue.network.included)]...)
  all_cap_network_excluded = merge([for cakey, cavalue in var.conditional_access : { for ekey, evalue in cavalue.network.excluded : "capexcludednetwork-${cakey}-${ekey}" => { network = ekey, cap = cakey, type = evalue } } if can(cavalue.network.excluded)]...)

  all_cap_network = merge(local.all_cap_network_included, local.all_cap_network_excluded)

  all_cap_locations = [for v in local.all_cap_network : v.network if v.type == "location"]
}

resource "azuread_conditional_access_policy" "custom" {
  for_each = var.conditional_access

  display_name = "CUST-${each.value.type}-${each.value.name}"
  state        = each.value.state ? each.value.report_only ? "enabledForReportingButNotEnforced" : "enabled" : "disabled"

  conditions {
    client_app_types = each.value.conditions.client_app_types

    sign_in_risk_levels           = each.value.conditions.sign_in_risk_levels           # P2 Feature
    user_risk_levels              = each.value.conditions.user_risk_levels              # P2 Feature
    service_principal_risk_levels = each.value.conditions.service_principal_risk_levels # P2 Feature

    dynamic "applications" {
      for_each = length([for k, v in each.value.resources.included : k if v == "user_action"]) == 0 ? [] : [0]

      content {
        included_user_actions = [for k, v in each.value.resources.included : k if v == "user_action"]
      }
    }

    dynamic "applications" {
      for_each = length([for k, v in each.value.resources.included : k if v == "user_action"]) == 0 ? [0] : []

      content {
        # First check if all_apps true - then set "All"
        # Next check if each.value.resources.included has NOT been provided OR office365_included is FALSE - Then set "None"
        # Finally, if all of the above is FALSE then we can get the set included apps (both microsoft and custom) & IDs and concat() them together along with converting the microsoft / custom names to IDs
        included_applications = each.value.resources.all_apps ? ["All"] : length(each.value.resources.included) == 0 && each.value.resources.office365_included == false ? ["None"] : concat(each.value.resources.office365_included ? ["Office365"] : [], [for k, v in each.value.resources.included : k if v == "app_id"], [for k, v in each.value.resources.included : data.azuread_application_published_app_ids.microsoft.result[k] if v == "app_microsoft"], [for k, v in each.value.resources.included : data.azuread_application.apps[k].client_id if v == "app_custom"])

        excluded_applications = concat(each.value.resources.office365_excluded ? ["Office365"] : [], [for k, v in each.value.resources.excluded : k if v == "app_id"], [for k, v in each.value.resources.excluded : data.azuread_application_published_app_ids.microsoft.result[k] if v == "app_microsoft"], [for k, v in each.value.resources.excluded : data.azuread_application.apps[k].client_id if v == "app_custom"])
      }
    }

    dynamic "client_applications" {
      for_each = length([for k, v in each.value.principals.included : k if v == "service_principal" || v == "service_principal_tf" || v == "service_principal_id"]) == 0 ? [] : [0]

      content {
        included_service_principals = concat([for k, v in each.value.principals.included : k if v == "service_principal_id"], [for k, v in each.value.principals.included : local.all_tf_resources[v][k] if v == "service_principal_tf"], [for k, v in each.value.principals.included : data.azuread_service_principal.service-principals[k].id if v == "service_principal"])
        excluded_service_principals = concat([for k, v in each.value.principals.excluded : k if v == "service_principal_id"], [for k, v in each.value.principals.excluded : local.all_tf_resources[v][k] if v == "service_principal_tf"], [for k, v in each.value.principals.excluded : data.azuread_service_principal.service-principals[k].id if v == "service_principal"])
      }
    }

    dynamic "devices" {
      for_each = each.value.conditions.device_filter_rule != "" ? [0] : []

      content {
        filter {
          mode = each.value.conditions.device_filter_mode
          rule = each.value.conditions.device_filter_rule
        }
      }
    }

    dynamic "locations" {
      for_each = length(each.value.network.included) > 0 || each.value.network.all_locations_included || each.value.network.all_trusted_included ? [0] : [] # Included network locations must be given

      content {
        included_locations = each.value.network.all_locations_included ? ["All"] : length(each.value.network.included) == 0 && each.value.network.all_trusted_included == false ? [] : concat(each.value.network.all_trusted_included ? ["AllTrusted"] : [], [for k, v in each.value.network.included : k if v == "location_id"], [for k, v in each.value.network.included : azuread_named_location.custom-locations[k].id if v == "location_tf"], [for k, v in each.value.network.included : data.azuread_named_location.locations[k].id if v == "location"])
        excluded_locations = concat(each.value.network.all_trusted_excluded ? ["AllTrusted"] : [], [for k, v in each.value.network.excluded : k if v == "location_id"], [for k, v in each.value.network.excluded : azuread_named_location.custom-locations[k].id if v == "location_tf"], [for k, v in each.value.network.excluded : data.azuread_named_location.locations[k].id if v == "location"])
      }
    }

    dynamic "platforms" {
      for_each = length(each.value.conditions.included_platforms) == 0 ? [] : [0]

      content {
        included_platforms = each.value.conditions.included_platforms
        excluded_platforms = each.value.conditions.excluded_platforms
      }
    }

    users {
      # First check if all_users true - then set "All"
      # Next check if each.value.principals.included has NOT been provided OR all_guest_or_external_users_included is FALSE - Then set "None"
      # Finally, if all of the above is FALSE then we can get the set included users & IDs and concat() them together along with converting the user friendly names to IDs
      included_users = each.value.principals.all_users ? ["All"] : length(each.value.principals.included) == 0 && each.value.principals.all_guest_or_external_users_included == false ? ["None"] : concat(each.value.principals.all_guest_or_external_users_included ? ["GuestsOrExternalUsers"] : [], [for k, v in each.value.principals.included : k if v == "user_id" || v == "guest_id"], [for k, v in each.value.principals.included : local.all_tf_resources[v][k] if v == "guest_tf"], [for k, v in each.value.principals.included : local.all_users_guests[k].id if v == "user" || v == "guest"])

      # Check if service principals have been used
      # If they have - we cant add excluded users as they are incompatible with SPs, so set to null
      # If not - convert the user names to IDs and add to a list along with breakglass users that should ALWAYS be exluded
      excluded_users = length([for k, v in each.value.principals.included : k if v == "service_principal" || v == "service_principal_tf" || v == "service_principal_id"]) == 0 ? concat(each.value.principals.all_guest_or_external_users_excluded ? ["GuestsOrExternalUsers"] : [], [for k, v in each.value.principals.excluded : k if v == "user_id" || v == "guest_id"], [for k, v in each.value.principals.excluded : local.all_tf_resources[v][k] if v == "guest_tf"], [for k, v in each.value.principals.excluded : local.all_users_guests[k].id if v == "user" || v == "guest"], local.breakglass_users_ids) : null

      # Everything below here is a lot simpler - basically just convert the given friendly name to an ID that this TF resource can use alongside any given IDs

      included_groups = concat([for k, v in each.value.principals.included : k if v == "group_id"], [for k, v in each.value.principals.included : local.all_tf_resources[v][k] if v == "group_tf"], [for k, v in each.value.principals.included : data.azuread_group.groups[k].id if v == "group"])
      excluded_groups = concat([for k, v in each.value.principals.excluded : k if v == "group_id"], [for k, v in each.value.principals.excluded : local.all_tf_resources[v][k] if v == "group_tf"], [for k, v in each.value.principals.excluded : data.azuread_group.groups[k].id if v == "group"])

      included_roles = concat([for k, v in each.value.principals.included : k if v == "role_id"], [for k, v in each.value.principals.included : azuread_directory_role.roles[k].template_id if v == "role"])
      excluded_roles = concat([for k, v in each.value.principals.excluded : k if v == "role_id"], [for k, v in each.value.principals.excluded : azuread_directory_role.roles[k].template_id if v == "role"])

      dynamic "included_guests_or_external_users" {
        for_each = each.value.principals.all_guest_or_external_users_included == false && length([for k, v in each.value.principals.included : k if v == "guest_external_user_type"]) > 0 ? [0] : [] # Only do this if all_guest_or_external_users_included is false AND guest_external_user_type included objects have been set
        content {
          external_tenants {
            members         = [for k, v in each.value.principals.included : k if v == "external_tenant_id"]
            membership_kind = length([for k, v in each.value.principals.included : k if v == "external_tenant_id"]) > 0 ? "enumerated" : "all"
          }
          guest_or_external_user_types = [for k, v in each.value.principals.included : k if v == "guest_external_user_type"]
        }
      }

      dynamic "excluded_guests_or_external_users" {
        for_each = length([for k, v in each.value.principals.excluded : k if v == "guest_external_user_type"]) > 0 ? [0] : [] # Only do this if guest_external_user_type excluded objects have been set
        content {
          external_tenants {
            members         = [for k, v in each.value.principals.excluded : k if v == "external_tenant_id"]
            membership_kind = length([for k, v in each.value.principals.excluded : k if v == "external_tenant_id"]) > 0 ? "enumerated" : "all"
          }
          guest_or_external_user_types = [for k, v in each.value.principals.excluded : k if v == "guest_external_user_type"]
        }
      }
    }
  }

  dynamic "grant_controls" {
    for_each = each.value.grant.authentication_strength_policy_id != "" ? [] : [0]

    content {
      operator                      = each.value.grant.is_and ? "AND" : "OR"
      built_in_controls             = each.value.type == "BLOCK" ? ["block"] : each.value.grant.built_in_controls
      custom_authentication_factors = each.value.grant.custom_authentication_factors
      terms_of_use                  = each.value.grant.terms_of_use
    }
  }

  dynamic "grant_controls" {
    for_each = each.value.grant.authentication_strength_policy_id != "" ? [0] : []

    content {
      operator                          = each.value.grant.is_and ? "AND" : "OR"
      built_in_controls                 = each.value.type == "BLOCK" ? ["block"] : each.value.grant.built_in_controls
      authentication_strength_policy_id = each.value.grant.authentication_strength_policy_id
      custom_authentication_factors     = each.value.grant.custom_authentication_factors
      terms_of_use                      = each.value.grant.terms_of_use
    }
  }

  session_controls {
    application_enforced_restrictions_enabled = each.value.session.application_enforced_restrictions_enabled
    cloud_app_security_policy                 = each.value.session.cloud_app_security_policy
    disable_resilience_defaults               = each.value.session.disable_resilience_defaults
    persistent_browser_mode                   = each.value.session.persistent_browser_mode
    sign_in_frequency                         = each.value.session.sign_in_frequency
    sign_in_frequency_period                  = each.value.session.sign_in_frequency_period
    sign_in_frequency_authentication_type     = each.value.session.sign_in_frequency_authentication_type
    # sign_in_frequency_interval                = each.value.session.sign_in_frequency_interval # Preview feature so wont work
  }
}