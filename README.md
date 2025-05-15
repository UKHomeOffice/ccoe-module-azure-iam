# CCoE Module - Azure IAM
This Terraform module allows you to manage your Azure IAM tenant configuration in code.

It is designed to be used as the central "hub" module to manage top level tenant configurations and to be administered by a central platform team.

It supports the creation of:
- Administrative Units
- App Registrations / Service Principals
- Breakglass Users
- Conditional Access Policies
- Groups
- Guest Users
- Custom Locations
- Management Groups
- Custom Roles
- Role Assignments
- Subscription Vending
- Tenant baseline config (logging, top level admin users, etc.)
- PIM (Work in progress)

> **NOTE:** This module explicitly and very deliberately does not manage user creation as it is expected this will generally be handled via separate processes with JML functions e.g Azure connect sync from an on premises domain and links to a HR system

By using this module you ensure that:
- Majority of "changeable" IAM and central tenant configurations are in code
- Baseline configuration is applied e.g MFA enforcement via conditional access
- Breakglass users are always excluded from conditional access policies
- Groups, service principals & app registrations must always have owners set to prevent orphaned resources

> **NOTE:** The module is *not* designed to be an "all or nothing" and instead only the functions you choose to populate will be enacted upon. For example, if you choose to not deploy conditional access policies via this module then they wont be touched at all. You can also disable the default configuration entirely. In fact you could choose to use the module solely for say its subscription vending functionality and disregard all other capabilities. Its completely flexible. This is a deliberate design decision for more complex shared tenant scenarios where different teams / departments may manage different components / parts of the tenant using different methodologies / repos. The recommendation however would always be to centralise config using a robust pull request process and a `CODEOWNERS` file as required for collaborative working with approvals.

## Initial Setup
As part of the initial setup you will need to import some resources that will already exist.

This is an example of the initial required setup import commands:

```shell
# Import root management group
terraform1.8.5 import module.iam-azure.azurerm_management_group.root /providers/Microsoft.Management/managementGroups/<your tenant ID>

# Create builtin roles
terraform1.8.5 apply --target="module.iam-azure.azuread_directory_role.global-administrator" --auto-approve
terraform1.8.5 apply --target="module.iam-azure.azuread_directory_role.privileged-role-administrator" --auto-approve
terraform1.8.5 apply --target="module.iam-azure.azuread_directory_role.privileged-authentication-administrator" --auto-approve
terraform1.8.5 apply --target="module.iam-azure.azuread_directory_role.global-reader" --auto-approve
```

It is also recommended for the purpose of subscription vending to run the following command and delegate the principals that will run this Terraform to the `User Access Administrator` role on the `/providers/Microsoft.Subscription/` scope.

This will allow the principals to both create new aliases but also read and interact with all other aliases.

This prevents an issue that happens when multiple users run the Terraform to vend subscriptions and an error occurs when the user attempts to read aliases for subscriptions they have not created.

Delegating only at the `/providers/Microsoft.Subscription/` scope however acts as a least privilege option rather than providing `User Access Administrator` at the tenant root `/` scope as can be achieved in the portal.

The Powershell command is:

```powershell
New-AzRoleAssignment -Scope "/providers/Microsoft.Subscription/" -RoleDefinitionName "User Access Administrator" -ObjectId <principal object ID>
```

## Splitting Up Files
As your environment grows it will become desirable to split up the variables into multiple files rather than declaring everything in a single file.

For example you may wish to structure your variables like this:

```bash
.
├── _tenantname.tf
├── subscriptions-dept1.tf
├── subscriptions-dept2.tf
├── groups-dept1.tf
├── groups-dept2.tf
```

Where `_tenantname.tf` is your main Terraform file calling the module and the other files contain only variables.

This can be achieved through the use of Terraform `locals`.

For example, within the `groups-dept1.tf` file if you specify the following:

```hcl
locals{
    groups-dept1 = {
        "Dept1" = {
            name        = "Dept1"
            type        = "PERM"
            owners      = {
              "user1@internal.example.com" = "user"
              "user2@external.example.com" = "guest"
              "user3@internal.example.com" = "user"
            }
        }
    }
}
```

And repeat this structure in the `groups-dept2.tf` file.

Then within the main `_tenantname.tf` file which calls the module you can specify the groups parameter as:

```hcl
groups = merge(local.groups-dept1, local.groups-dept2)
```

This will take both of the `locals` defined within each file and merge them together to create one map of groups which is passed to the module.

## Importing Existing Subscriptions
If you have existing subscriptions you wish to import this cannot be achieved by traditional means, e.g running a `terraform import` command, this is due to the way Terraform handles Azure aliases.

Instead, you should specify the existing subscription ID within a the subscription map. For example:

```hcl
subscriptions = {
    "Subscription1" = {
        name                = "Subscription1"
        management_group_id = "Tier2"
        delegations = {
            "Owner" = {
                allow_high_privilege_roles = true
                objects = {
                    "user1@internal.example.com" = "user"
                    "user2@external.example.com" = "guest"
                    "user3@internal.example.com" = "user"
                }
            }
        }
    subscription_id = "aaaa0a0a-bb1b-cc2c-dd3d-eeeeee4e4e4e" # This is an existing subscription
    }
}
```

## Local User Sets
Often it is desirable to have multiple groups and service principals owned by the same set of users.

Currently this is not possible natively in Entra, as in, service principals cannot be owned by groups and groups cannot be owned by other groups.

This module has developed a workaround for this through the use of "Local User Sets".

Effectively this allows you to create Terraform `locals` containing users which can then be referenced in multiple places throughout the module, e.g group ownership & service principal ownership.

For example, you could create a file called `locals.tf` with the following content:

```hcl
locals {
    teams = {
        "CloudPlatformTeam" = {
          "user1@internal.example.com" = "user"
          "user2@external.example.com" = "guest"
          "user3@internal.example.com" = "user"
        }
    }
}
```

The `locals` can then be referenced like so when creating a group:

```hcl
groups = {
  "Group1" = {
    name        = "Group1"
    type        = "TEAM"
    owners      = local.teams.CloudPlatformTeam
  }
}
```

And additionally like this when creating an app registration / service principal:

```hcl
app_registrations_service_principals = {
  "Example" = {
    display_name = "Example"
    requires_service_principal = true
    owners = local.teams.CloudPlatformTeam
  }    
}
```

This will then ensure that both the group and app registration / service principal are owned by the same set of users which can be managed centrally through the `locals`.

It is also possible to add service principals alongside user principals within the `locals`.

## PIM
PIM support in this module is currently limited, this is due to the currently poor support within the `azuread` Terraform provider for PIM.

Further PIM integration work is however on the roadmap for the module and variables have been designed with this in mind.

## Example Usage

The module can be called from your Terraform as shown in this example below:

```hcl
# Get enrollment account for subscriptions
data "azurerm_billing_enrollment_account_scope" "enrollment-account" {
  billing_account_name    = "12345678"
  enrollment_account_name = "123456"
}

module "example" {
  source = "github.com/UKHomeOffice/ccoe-module-iam-azure?ref=v1.2.1"

  # ---------------------------------------------------------
  # General
  # ---------------------------------------------------------

  prefix          = "HO"
  env             = "Prd"
  region_friendly = "UKSouth"
  region          = "uksouth"

  # ---------------------------------------------------------
  # Tags
  # ---------------------------------------------------------

  tags = {
    CostCentre  = "1234567"
    Department  = "Example Department"
    Owner       = "Example Team"
    ProjectName = "IAM Azure"
    Environment = "Prd"
    Repo        = "https://github.com/UKHomeOffice/ccoe-module-iam-azure"
  }

  # ---------------------------------------------------------
  # Breakglass
  # ---------------------------------------------------------

  breakglass_users = ["K6WxubEg7AkJqByf"]

  alert_on_breakglass_login = {
    "alert@example.com" = "email"
  }

  # ---------------------------------------------------------
  # Top Level Admins
  # ---------------------------------------------------------

  # These users have special non federated @*.onmicrosoft.com
  # accounts. Standard conditional access still applies.

  # global_administrator will grant the Global Administrator
  # Entra ID role directly.

  # azure_root_administrator will delegate the platform admin
  # custom role to the tenant root group and the owner role
  # to all subscription aliases

  top_level_admins = {
    "admin_example_username" = {
      first_name               = "Example"
      last_name                = "Admin"
      usage_location           = "GB"
      global_administrator     = true
      azure_root_administrator = false
      is_pim                   = false
    }
  }

  # ---------------------------------------------------------
  # Azure Root Admins
  # ---------------------------------------------------------

  azure_root_admins = {
    "Cloud-Platform-Admins" = "group_tf"
  }

  # ---------------------------------------------------------
  # Management Groups
  # ---------------------------------------------------------

  root_management_group = {
    name = "Tenant Root Group"
    delegations = {
      "Support" = {
        objects = {
          "Cloud-Platform-Support" = "group_tf"
        }
      }
      "FinOps" = {
        objects = {
          "Cloud-Platform-FinOps" = "group_tf"
        }
      }
    }
  }

  management_groups = {
      "Tier1" = {
          name = "Tier1"
              children = {
              "Tier2" = {
                  name = "Tier2"
                    children = {
                      "Tier3" = {
                          name = "Tier 3"
                      }
                  }
              }
          }
      }
      "Platform" = {
          name = "Platform"
      }
      "Landing" = {
          name = "Landing"
      }
  }

  # ---------------------------------------------------------
  # Subscriptions
  # ---------------------------------------------------------

  default_billing_scope_id = data.azurerm_billing_enrollment_account_scope.enrollment-account.id

  subscriptions = {
      "Subscription1" = {
          name                = "Subscription1"
          management_group_id = "Tier2"
          delegations = {
              "Owner" = {
                  allow_high_privilege_roles = true
                  objects = {
                      "user1@internal.example.com" = "user"
                      "user2@external.example.com" = "guest"
                      "user3@internal.example.com" = "user"
                  }
              }
          }
      subscription_id = "aaaa0a0a-bb1b-cc2c-dd3d-eeeeee4e4e4e" # This is an existing subscription
      },
      "Subscription2" = {
          name                = "Subscription2"
          management_group_id = "Tier3"
          delegations = {
              "Owner" = {
                  objects = {
                      "user1@internal.example.com" = "user"
                      "user2@external.example.com" = "guest"
                      "user3@internal.example.com" = "user"
                  }
              }
          }
      }
  }

  # ---------------------------------------------------------
  # Administrative Units
  # ---------------------------------------------------------

  administrative_units = {
    "Example" = {
      name           = "Example"
      description    = "Example AU"
      administrators = {
        "user1@internal.example.com" = "user"
        "user2@external.example.com" = "guest"
        "user3@internal.example.com" = "user"
      }
      members        = {
        "user1@internal.example.com" = "user"
        "user2@external.example.com" = "guest"
        "user3@internal.example.com" = "user"
      }      
    }
  }

  # ---------------------------------------------------------
  # Groups
  # ---------------------------------------------------------

  groups = {
    "Group1" = {
      name        = "Group1"
      type        = "TEAM"
      owners      = {
        "user1@internal.example.com" = "user"
        "user2@external.example.com" = "guest"
        "user3@internal.example.com" = "user"
      }
      members     = {
        "user1@internal.example.com" = "user"
        "user2@external.example.com" = "guest"
        "user3@internal.example.com" = "user"
      }
    }
  }

  # ---------------------------------------------------------
  # Role Management Policies
  # ---------------------------------------------------------

  azure_role_mgmt_policies = {
    "root-DeID Data Owner" = {
      role_name           = "DeID Data Owner"
      scope               = "/"
      scope_type          = "management_group"
      max_duration        = "PT8H"
      require_approval    = true
      approvers           = {
        "user1@internal.example.com" = "user"
        "user2@external.example.com" = "guest"
        "user3@internal.example.com" = "user"
      }
      admin_notifications = {
        "admin.alerts@example.com" = ["eligible_assignment", "eligible_activation", "active_assignment"]
      }
    }
  }

  group_role_mgmt_policies = {
    "Group1" = {
      group               = "Group1"
      group_type          = "tf"
      role                = "member"
      max_duration        = "PT8H"
      require_approval    = true
      approvers           = {
        "user1@internal.example.com" = "user"
        "user2@external.example.com" = "guest"
        "user3@internal.example.com" = "user"
      }
      admin_notifications = {
        "admin.alerts@example.com" = ["eligible_assignment", "eligible_activation", "active_assignment"]
      }
    }
  }

  # ---------------------------------------------------------
  # Role Assignments
  # ---------------------------------------------------------

  role_assignments_permanent = {
    "Directory Readers" = {
      "user1@internal.example.com" = "user"
      "user2@external.example.com" = "guest"
      "user3@internal.example.com" = "user"
    }
  }

  role_assignments_pim = {
    "User Administrator" = {
      "user1@internal.example.com" = "user"
      "user2@external.example.com" = "guest"
      "user3@internal.example.com" = "user"
    }    
  }

  # ---------------------------------------------------------
  # Custom Locations
  # ---------------------------------------------------------

  custom_locations = {
    "Example" = {
      name       = "Example"
      ip_ranges  = ["1.1.1.1/32"]
      is_trusted = true
    }
  }

  # ---------------------------------------------------------
  # Baseline Conditional Access
  # ---------------------------------------------------------

  enable_baseline_caps = true
  baseline_report_only = false

  # Location Restriction
  location_restriction_report_only = false
  location_restriction_whitelist   = true
  restricted_countries             = ["GB"]
  include_unknown_countries        = false
  restricted_locations             = {
    "Example" = "location"
  }
  
  # Session Lifetime
  sign_in_frequency_report_only = false
  sign_in_frequency_value       = "7"
  sign_in_frequency_units       = "days"
  persistent_browser_session    = false

  # ---------------------------------------------------------
  # Custom Conditional Access
  # ---------------------------------------------------------

  # WARNING: Be careful when applying conditional access policies! 
  # Dont get locked out!

  conditional_access = {

  }

  # ---------------------------------------------------------
  # Guest Users
  # ---------------------------------------------------------

  guest_invite_message = "Example invite message."

  guest_users = {
    "user2@external.example.com" = {
      name              = "User 2"
      additional_emails = []
    }
  }

  # ---------------------------------------------------------
  # App Registrations / Service Principals
  # ---------------------------------------------------------

  app_registrations_service_principals = {
    "Example" = {
      display_name = "Example"
      requires_service_principal = true
      owners = {
        "user1@internal.example.com" = "user"
        "user2@external.example.com" = "guest"
        "user3@internal.example.com" = "user"
      }
    }    
  }

  # ---------------------------------------------------------
  # Logs
  # ---------------------------------------------------------

  # NOTE: "SignInLogs" are always collected if breakglass users 
  # are defined to allow for their usage alerting.

  enabled_logs = []
  retention_in_days = 30
}
```