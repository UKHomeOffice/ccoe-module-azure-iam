# *********************************************************
# GUEST USERS
# *********************************************************

resource "azuread_invitation" "guest-users" {
  for_each = var.guest_users

  user_display_name  = each.value.name
  user_email_address = each.key
  redirect_url       = "https://portal.azure.com/${local.default_domain}" # Note the use of the tenant domain - so once users redeem the invite they are put into the correct tenant

  message {
    additional_recipients = each.value.additional_emails
    body                  = var.guest_invite_message
  }
}