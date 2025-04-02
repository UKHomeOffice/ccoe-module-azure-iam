# *********************************************************
# VARIABLES
# *********************************************************

# ---------------------------------------------------------
# General
# ---------------------------------------------------------

variable "prefix" {
  type        = string
  description = "Prefix to be used when creating groups / resources."
  nullable    = false
}

variable "env" {
  type        = string
  description = "Environment name. Used when creating groups / resources."
  nullable    = false
}

variable "region" {
  type        = string
  description = "The name of the region being deployed to. e.g uksouth"
  nullable    = false
}

variable "region_friendly" {
  type        = string
  description = "The friendly name of the region being deployed to. e.g NorthEU"
  nullable    = false
}

# ---------------------------------------------------------
# Tags
# ---------------------------------------------------------

variable "tags" {
  type = object({
    CostCentre  = string
    Department  = string
    Owner       = string
    ProjectName = string
    Environment = string
    Repo        = string
  })
  description = "Azure tags to be applied to all resources inc RGs."
  nullable    = false
}

# ---------------------------------------------------------
# Breakglass
# ---------------------------------------------------------

variable "breakglass_users" {
  type        = list(string)
  description = "Breakglass users. The specified users will be created as global administrators and excluded from ALL conditional access policies."
  nullable    = false
}

variable "alert_on_breakglass_login" {
  type        = map(any)
  description = "Recipients of alerts that will be sent when a break glass account is logged into."
  nullable    = false
}

# ---------------------------------------------------------
# Top Level Admins
# ---------------------------------------------------------

variable "top_level_admins" {
  type = map(object({
    first_name                   = string
    last_name                    = string
    usage_location               = string
    global_administrator         = bool
    azure_root_administrator     = bool
    is_pim                       = optional(bool, true)
  }))
  description = "Tenant administrators including entitlement to Entra and / or Azure subscriptions."
  nullable    = false
}

# ---------------------------------------------------------
# Azure Root Admins
# ---------------------------------------------------------

# Azure root admins have full access to ALL Azure subscriptions and 
# the ability to run all parts of this Terraform including subscription vending.

variable "azure_root_admins" {
  type        = map(string)
  description = "Users who should have Azure top level root management capability. E.g any principal whom needs to run this code."

  validation {
    condition     = alltrue(flatten([for principal, type in var.azure_root_admins : contains(["user", "guest", "guest_tf", "group", "group_tf", "service_principal", "service_principal_tf", "id"], type)]))
    error_message = "Delegation object must equal either \"user\" OR \"guest\" OR \"guest_tf\" OR \"group\" OR \"group_tf\" OR \"service_principal\" OR \"service_principal_tf\" OR \"id\""
  }
}

# ---------------------------------------------------------
# Management Groups
# ---------------------------------------------------------

variable "root_management_group" {
  type = object({
    name = optional(string, "Tenant Root Group")
    delegations = optional(map(object({
      is_pim                     = optional(bool, false)
      allow_high_privilege_roles = optional(bool, false)
      objects                    = optional(map(string), {})
    })), {})
  })
  description = "Root management group."
  nullable    = false
}

variable "management_groups" {
  type = map(object({ # Level 1
    name = string
    delegations = optional(map(object({
      is_pim                     = optional(bool, false)
      allow_high_privilege_roles = optional(bool, false)
      objects                    = optional(map(string), {})
    })), {})
    children = optional(map(object({ # Level 2
      name = string
      delegations = optional(map(object({
        is_pim                     = optional(bool, false)
        allow_high_privilege_roles = optional(bool, false)
        objects                    = optional(map(string), {})
      })), {})
      children = optional(map(object({ # Level 3
        name = string
        delegations = optional(map(object({
          is_pim                     = optional(bool, false)
          allow_high_privilege_roles = optional(bool, false)
          objects                    = optional(map(string), {})
        })), {})
        children = optional(map(object({ # Level 4
          name = string
          delegations = optional(map(object({
            is_pim                     = optional(bool, false)
            allow_high_privilege_roles = optional(bool, false)
            objects                    = optional(map(string), {})
          })), {})
          children = optional(map(object({ # Level 5
            name = string
            delegations = optional(map(object({
              is_pim                     = optional(bool, false)
              allow_high_privilege_roles = optional(bool, false)
              objects                    = optional(map(string), {})
            })), {})
            children = optional(map(object({ # Level 6
              name = string
              delegations = optional(map(object({
                is_pim                     = optional(bool, false)
                allow_high_privilege_roles = optional(bool, false)
                objects                    = optional(map(string), {})
              })), {})
            })))
          })))
        })))
      })))
    })))
  }))
  description = "Management groups."
  nullable    = true
}

# ---------------------------------------------------------
# Subscriptions
# ---------------------------------------------------------

variable "default_billing_scope_id" {
  type        = string
  description = "Default billing scope ID."
  nullable    = false
}

variable "subscriptions" {
  type = map(object({
    name                = string
    management_group_id = string
    delegations = optional(map(object({
      is_pim                     = optional(bool, false)
      allow_high_privilege_roles = optional(bool, false)
      objects                    = optional(map(string), {})
    })), {})
    is_devtest                = optional(bool, false)
    billing_scope_id_override = optional(string, "")
    subscription_id           = optional(string, "")
    tags                      = optional(map(any), {})
  }))
  description = "Subscriptions."
  nullable    = true

  validation {
    condition     = alltrue(flatten([for skey, svalue in var.subscriptions : flatten([for dkey, dvalue in svalue.delegations : [for v in dvalue.objects : contains(["user", "guest", "guest_tf", "group", "group_tf", "service_principal", "service_principal_tf", "id"], v)]])]))
    error_message = "Delegation object must equal either \"user\" OR \"guest\" OR \"guest_tf\" OR \"group\" OR \"group_tf\" OR \"service_principal\" OR \"service_principal_tf\" OR \"id\""
  }
}

# ---------------------------------------------------------
# Administrative Units
# ---------------------------------------------------------

variable "administrative_units" {
  type = map(object({
    name           = string
    description    = string
    administrators = optional(map(string), {})
    members        = optional(map(string), {})
  }))
  description = "Administrative units."
  nullable    = true

  validation {
    condition     = alltrue(flatten([for aukey, auvalue in var.administrative_units : flatten([for v in auvalue.administrators : contains(["user", "guest", "guest_tf", "group", "group_tf", "service_principal", "service_principal_tf", "id"], v)])]))
    error_message = "Administrator object must equal either \"user\" OR \"guest\" OR \"guest_tf\" OR \"group\" OR \"group_tf\" OR \"service_principal\" OR \"service_principal_tf\" OR \"id\""
  }

  validation {
    condition     = alltrue(flatten([for aukey, auvalue in var.administrative_units : flatten([for v in auvalue.members : contains(["user", "guest", "guest_tf", "group", "group_tf", "service_principal", "service_principal_tf", "id"], v)])]))
    error_message = "Member object must equal either \"user\" OR \"guest\" OR \"guest_tf\" OR \"group\" OR \"group_tf\" OR \"service_principal\" OR \"service_principal_tf\" OR \"id\""
  }
}

# ---------------------------------------------------------
# Groups
# ---------------------------------------------------------

variable "groups" {
  type = map(object({
    name          = string
    type          = string
    managed_by_au = optional(string, "")
    owners        = optional(map(string), {})
    members       = optional(map(string), {})
    dynamic_rule  = optional(string, "")
  }))
  description = "Groups."
  nullable    = true

  validation {
    # REMEMBER: If adding a new group type you should update the _outputs.tf file group_types local to include it as an output
    condition     = alltrue([for group in var.groups : contains(["TEAM", "DYN", "PERM", "APP", "AWS"], group.type)])
    error_message = "Group type must be either [TEAM, DYN, PERM, APP, AWS]"
  }

  validation {
    condition     = alltrue(flatten([for gkey, gvalue in var.groups : flatten([for v in gvalue.owners : contains(["user", "guest", "group", "service_principal", "id"], v)])]))
    error_message = "Owner object must equal either \"user\" OR \"guest\" OR \"group\" OR \"service_principal\" OR \"id\""
  }

  validation {
    condition     = alltrue(flatten([for gkey, gvalue in var.groups : flatten([for v in gvalue.members : contains(["user", "guest", "guest_tf", "group", "group_tf", "service_principal", "service_principal_tf", "id"], v)])]))
    error_message = "Member object must equal either \"user\" OR \"guest\" OR \"guest_tf\" OR \"group\" OR \"group_tf\" OR \"service_principal\" OR \"service_principal_tf\" OR \"id\""
  }

  # Force ALL groups but DYN to have owners
  validation {
    condition     = alltrue(flatten([for gkey, gvalue in var.groups : length(gvalue.owners) > 0 ? true : false if gvalue.type != "DYN"]))
    error_message = "ALL groups but DYN must have owners defined"
  }
}

# ---------------------------------------------------------
# Role Management Policies
# ---------------------------------------------------------

variable "azure_role_mgmt_policies" {
  type = map(object({
    role_name             = string
    scope                 = string
    scope_type            = string
    max_duration          = optional(string, "PT8H") # 8 hours
    require_mfa           = optional(bool, true)
    require_justification = optional(bool, true)
    require_approval      = optional(bool, false)
    approvers             = optional(map(string), {})
    admin_notifications   = optional(map(list(string)), {})
  }))
  description = "Role management policies for Azure roles."
  nullable    = true

  validation {
    condition     = alltrue(flatten([for rmpkey, rmpvalue in var.azure_role_mgmt_policies : contains(["subscription_id", "management_group"], rmpvalue.scope_type)]))
    error_message = "scope_type must equal either \"subscription_id\" OR \"management_group\""
  }
}

variable "group_role_mgmt_policies" {
  type = map(object({
    group                 = string
    group_type            = string
    role                  = string
    max_duration          = optional(string, "PT8H") # 8 hours
    require_mfa           = optional(bool, true)
    require_justification = optional(bool, true)
    require_approval      = optional(bool, false)
    approvers             = optional(map(string), {})
    admin_notifications   = optional(map(list(string)), {})
  }))
  description = "Role management policies for groups."
  nullable    = true

  validation {
    condition     = alltrue(flatten([for rmpkey, rmpvalue in var.group_role_mgmt_policies : contains(["name", "tf", "id"], rmpvalue.group_type)]))
    error_message = "group_type must equal either \"name\" OR \"tf\" OR \"id\""
  }
}

# ---------------------------------------------------------
# Role Assignments
# ---------------------------------------------------------

variable "role_assignments_permanent" {
  type        = map(map(string))
  description = "Permanent role assignments."
  nullable    = true

  # This is temporarily disabled as PIM is not properly supported in the Terraform AzureAD provider
  # validation {
  #   condition     = alltrue([for role, assignments in var.role_assignments_permanent : strcontains(role, "Reader")])
  #   error_message = "Permant role assignments MUST contain Reader only"
  # }

  validation {
    condition     = alltrue(flatten([for rakey, ravalue in var.role_assignments_permanent : flatten([for v in ravalue : contains(["user", "guest", "guest_tf", "group", "group_tf", "service_principal", "service_principal_tf", "id"], v)])]))
    error_message = "Principal object must equal either \"user\" OR \"guest\" OR \"guest_tf\" OR \"group\" OR \"group_tf\" OR \"service_principal\" OR \"service_principal_tf\" OR \"id\""
  }
}

variable "role_assignments_pim" {
  type        = map(map(string))
  description = "PIM role assignments."
  nullable    = true

  validation {
    condition     = alltrue([for role, assignments in var.role_assignments_pim : !contains(["Global Administrator", "Privileged Role Administrator", "Privileged Authentication Administrator"], role)])
    error_message = "Role CANNOT be [Global Administrator, Privileged Role Administrator, Privileged Authentication Administrator]"
  }

  validation {
    condition     = alltrue(flatten([for rakey, ravalue in var.role_assignments_pim : flatten([for v in ravalue : contains(["user", "guest", "guest_tf", "group", "group_tf", "service_principal", "service_principal_tf", "id"], v)])]))
    error_message = "Principal object must equal either \"user\" OR \"guest\" OR \"guest_tf\" OR \"group\" OR \"group_tf\" OR \"service_principal\" OR \"service_principal_tf\" OR \"id\""
  }
}

# ---------------------------------------------------------
# Custom Locations
# ---------------------------------------------------------

variable "custom_locations" {
  type = map(object({
    name       = string
    ip_ranges  = list(string)
    is_trusted = bool
  }))
  description = "Custom locations."
  nullable    = true
}

# ---------------------------------------------------------
# Baseline Conditional Access
# ---------------------------------------------------------

variable "enable_baseline_caps" {
  type        = bool
  description = "Should baseline conditional access policies be enabled? [true / false]"
  nullable    = false
}

variable "baseline_report_only" {
  type        = bool
  description = "Should baseline conditional access policies be set to report only? [true / false]"
  nullable    = false
}

# Location Restriction

variable "location_restriction_report_only" {
  type        = bool
  description = "Should location restriction be set to report only? [true / false]"
  nullable    = false
}

variable "restricted_countries" {
  type        = list(string)
  description = "Countries to block. e.g [\"GB\", \"US\"]"
  nullable    = false
}

variable "include_unknown_countries" {
  type        = bool
  description = "Block unknown countries/regions? [true / false]"
  nullable    = false
}

variable "location_restriction_whitelist" {
  type        = bool
  description = "Is the country restriction a whitelist? [true / false]"
  nullable    = false
}

variable "restricted_locations" {
  type        = map(string)
  description = "List of locations that should always be allowed."
  nullable    = false

  validation {
    condition     = alltrue(flatten([for k, v in var.restricted_locations : contains(["location", "location_tf", "location_id"], v)]))
    error_message = "Always allowed locations object must equal either \"location\" OR \"location_tf\" OR \"location_id\""
  }
}

# Session Lifetime

variable "sign_in_frequency_report_only" {
  type        = bool
  description = "If the sign in frequency policy should be enabled."
  nullable    = false
}

variable "sign_in_frequency_value" {
  type        = number
  description = "The number value before a user should require sign in. Units are set separately."
  nullable    = false
}

variable "sign_in_frequency_units" {
  type        = string
  description = "Units to correspond to the value set. [hours / days]"
  nullable    = false
}

variable "persistent_browser_session" {
  type        = bool
  description = "If the browser session should be persisted. e.g persist cookies"
  nullable    = false
}

# ---------------------------------------------------------
# Conditional Access
# ---------------------------------------------------------

variable "conditional_access" {
  type = map(object({
    name        = string
    type        = string
    state       = bool
    report_only = optional(bool, true)
    principals = object({
      all_users                            = optional(bool, false)
      all_guest_or_external_users_included = optional(bool, false)
      all_guest_or_external_users_excluded = optional(bool, false)
      included                             = optional(map(string), {})
      excluded                             = optional(map(string), {})
    })
    resources = object({
      all_apps           = optional(bool, false)
      office365_included = optional(bool, false)
      office365_excluded = optional(bool, false)
      included           = optional(map(string), {})
      excluded           = optional(map(string), {})
    })
    network = object({
      all_locations_included = optional(bool, false)
      all_trusted_included   = optional(bool, false)
      all_trusted_excluded   = optional(bool, true) # Make this default true to help prevent accidental lockouts
      included               = optional(map(string), {})
      excluded               = optional(map(string), {})
    })
    conditions = object({
      sign_in_risk_levels           = optional(list(string), null) # P2 Feature
      user_risk_levels              = optional(list(string), null) # P2 Feature
      service_principal_risk_levels = optional(list(string), null) # P2 Feature
      client_app_types              = optional(list(string), [])
      included_platforms            = optional(list(string), [])
      excluded_platforms            = optional(list(string), [])
      device_filter_mode            = optional(string, "include")
      device_filter_rule            = optional(string, "")
    })
    grant = object({
      is_and                            = optional(bool, false)
      built_in_controls                 = optional(list(string), [])
      authentication_strength_policy_id = optional(string, null)
      custom_authentication_factors     = optional(list(string), null)
      terms_of_use                      = optional(list(string), null)
    })
    session = object({
      application_enforced_restrictions_enabled = optional(bool, null)
      cloud_app_security_policy                 = optional(string, null)
      disable_resilience_defaults               = optional(bool, null)
      persistent_browser_mode                   = optional(string, null)
      sign_in_frequency                         = optional(number, null)
      sign_in_frequency_period                  = optional(string, null)
      sign_in_frequency_authentication_type     = optional(string, null)
      # sign_in_frequency_interval                = optional(string, null) # Preview feature so wont work
    })
  }))
  description = "Conditional access policies."
  nullable    = true

  validation {
    condition     = alltrue([for ca in var.conditional_access : contains(["ALLOW", "BLOCK"], ca.type)])
    error_message = "Conditional access type must be either [ALLOW, BLOCK]"
  }

  # Principals

  validation {
    condition     = alltrue(flatten([for cakey, cavalue in var.conditional_access : flatten([for v in cavalue.principals.included : contains(["user", "user_id", "group", "group_tf", "group_id", "guest", "guest_tf", "guest_id", "service_principal", "service_principal_tf", "service_principal_id", "role", "role_id", "guest_external_user_type", "external_tenant_id"], v)])]))
    error_message = "Included principal object must equal either \"user\" OR \"user_id\" OR \"group\" OR \"group_tf\" OR \"group_id\" OR \"guest\" OR \"guest_tf\" OR \"guest_id\" OR \"service_principal\" OR \"service_principal_tf\" OR \"service_principal_id\" OR \"role\" OR \"role_id\" OR \"guest_external_user_type\" OR \"external_tenant_id\""
  }

  validation {
    condition     = alltrue(flatten([for cakey, cavalue in var.conditional_access : flatten([for v in cavalue.principals.excluded : contains(["user", "user_id", "group", "group_tf", "group_id", "guest", "guest_tf", "guest_id", "service_principal", "service_principal_tf", "service_principal_id", "role", "role_id", "guest_external_user_type", "external_tenant_id"], v)])]))
    error_message = "Excluded principal object must equal either \"user\" OR \"user_id\" OR \"group\" OR \"group_tf\" OR \"group_id\" OR \"guest\" OR \"guest_tf\" OR \"guest_id\" OR \"service_principal\" OR \"service_principal_tf\" OR \"service_principal_id\" OR \"role\" OR \"role_id\" OR \"guest_external_user_type\" OR \"external_tenant_id\""
  }

  # Resources

  validation {
    condition     = alltrue(flatten([for cakey, cavalue in var.conditional_access : flatten([for v in cavalue.resources.included : contains(["app_microsoft", "app_custom", "app_id", "user_action"], v)])]))
    error_message = "Included resource object must equal either \"app_microsoft\" OR \"app_custom\" OR \"app_id\" OR \"user_action\""
  }

  validation {
    condition     = alltrue(flatten([for cakey, cavalue in var.conditional_access : flatten([for v in cavalue.resources.excluded : contains(["app_microsoft", "app_custom", "app_id"], v)])]))
    error_message = "Excluded resource object must equal either \"app_microsoft\" OR \"app_custom\" OR \"app_id\""
  }

  # Network

  validation {
    condition     = alltrue(flatten([for cakey, cavalue in var.conditional_access : flatten([for v in cavalue.network.included : contains(["location", "location_tf", "location_id"], v)])]))
    error_message = "Included network object must equal either \"location\" OR \"location_tf\" OR \"location_id\""
  }

  validation {
    condition     = alltrue(flatten([for cakey, cavalue in var.conditional_access : flatten([for v in cavalue.network.excluded : contains(["location", "location_tf", "location_id"], v)])]))
    error_message = "Excluded network object must equal either \"location\" OR \"location_tf\" OR \"location_id\""
  }
}

# ---------------------------------------------------------
# Guest Users
# ---------------------------------------------------------

variable "guest_invite_message" {
  type        = string
  description = "Message to send to users when inviting."
  nullable    = true
}

variable "guest_users" {
  type = map(object({
    name              = string
    additional_emails = optional(list(string), [])
  }))
  description = "Guest users."
  nullable    = true
}

# ---------------------------------------------------------
# App Registrations / Service Principals
# ---------------------------------------------------------

variable "app_registrations_service_principals" {
  type = map(object({
    display_name               = string
    requires_service_principal = optional(bool, false)
    owners                     = map(string) # Require owners so app regs have accountability and dont become orphaned
  }))
  description = "App registrations and service principals."
  nullable    = true

  validation {
    condition     = alltrue(flatten([for arkey, arvalue in var.app_registrations_service_principals : flatten([for v in arvalue.owners : contains(["user", "guest", "guest_tf", "service_principal", "id"], v)])]))
    error_message = "Owner object must equal either \"user\" OR \"guest\" OR \"guest_tf\" \"service_principal\" OR \"id\""
  }
}

# ---------------------------------------------------------
# Logs
# ---------------------------------------------------------

variable "enabled_logs" {
  type        = list(string)
  description = "Log categories to collect for Entra. NOTE: \"SignInLogs\" are ALWAYS collected to allow for breakglass account usage alerting."
  nullable    = true
}

variable "retention_in_days" {
  type        = number
  description = "Number of days to retain logs for."
  nullable    = false
}