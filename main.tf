# Reusable variables
locals {
  #Shorthand these to make them easier to refer to
  azure_tenant_id = data.azurerm_subscription.this.tenant_id
  oidc_client_id = azuread_application.azure-oidc.application_id
  oidc_client_secret = azuread_application_password.azure-oidc.value

  # Each tenant in Vault will require its own redirect URL on the Azure app.
  reply_urls = concat([
    "http://localhost:8250/oidc/callback",
    "${var.vault_url}/ui/vault/auth/oidc/oidc/callback"
    ],[
      for v in var.namespaces : "${var.vault_url}/ui/vault/auth/oidc/oidc/callback?${v}"
    ])
}

# Vault Namespace Generation
resource vault_namespace "this" {
  for_each = toset(var.namespaces)
  path     = each.value
}

# Azure provider related requirements
provider "azurerm" {
  features {}
}

data azurerm_subscription "this" {}


#Azure App Configuration
resource azuread_application "azure-oidc" {
  name                       = "oidc-demo"
  reply_urls                 = local.reply_urls

  required_resource_access {
    # Add MS Graph Group.Read.All API permissions
    resource_app_id = "00000003-0000-0000-c000-000000000000"

    resource_access {
      id   = "5b567255-7703-4780-807c-7be8301ae99b"
      type = "Scope"
    }
  }

  available_to_other_tenants = false
  oauth2_allow_implicit_flow = true
  type                       = "webapp/api"
}

resource random_password "azure-oidc" {
  length = 32
  special = true
}

resource azuread_application_password "azure-oidc" {
  application_object_id = azuread_application.azure-oidc.id
  value                 = random_password.azure-oidc.result
  end_date              = timeadd(timestamp(), "8766h")
  lifecycle {
    ignore_changes = [end_date]
  }
}