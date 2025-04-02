# *********************************************************
# NAMED LOCATIONS
# *********************************************************

# ---------------------------------------------------------
# Restricted Countries
# ---------------------------------------------------------

resource "azuread_named_location" "restricted-countries" {
  count = var.enable_baseline_caps && length(var.restricted_countries) > 0 || var.include_unknown_countries ? 1 : 0 # Only create if enable_baseline_caps is true AND restricted_countries are specified OR include_unknown_countries is true

  display_name = "Restricted Countries"
  country {
    countries_and_regions                 = var.restricted_countries
    include_unknown_countries_and_regions = var.include_unknown_countries
  }
}

# ---------------------------------------------------------
# Custom Locations
# ---------------------------------------------------------

resource "azuread_named_location" "custom-locations" {
  for_each = var.custom_locations

  display_name = each.value.name
  ip {
    ip_ranges = each.value.ip_ranges
    trusted   = each.value.is_trusted
  }
}