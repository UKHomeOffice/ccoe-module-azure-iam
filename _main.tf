# *********************************************************
# TERRAFORM CONFIG
# *********************************************************

# ---------------------------------------------------------
# Providers
# ---------------------------------------------------------

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.2.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "2.53.1"
    }
    random = {
      source  = "hashicorp/random"
      version = "3.6.3"
    }
  }
  required_version = ">= 1.5.0" # Because of strcontains()
}

# ---------------------------------------------------------
# Resource Map
# ---------------------------------------------------------

# This is used to pull relevant IDs of resources created in
# this terraform and present them in a structured way for
# use elsewhere in the code.

locals {
  all_tf_resources = {
    "guest_tf"             = { for k, v in azuread_invitation.guest-users : k => v.user_id }
    "group_tf"             = { for k, v in local.all_groups : k => v.object_id },
    "service_principal_tf" = { for k, v in azuread_service_principal.service-principals : k => v.object_id }
  }
}