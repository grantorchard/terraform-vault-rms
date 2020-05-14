locals {
  # Providers can't use "depends_on", so we declare them here as local variables to force the dependency.
  app_a = vault_namespace.this["app_a"].path
  app_a_kv_read_users = {
    "grant":"go@hashicorp.com",
    "burkey":"burkey@hashicorp.com"
  }
  app_a_kv_write_users = {
    "burkey":"burkey@hashicorp.com"
  }
}

provider vault {
  alias     = "app_a"
  namespace = local.app_a
  # Using the local.namespace_app_a to sort out dependencies
}

# Auth methods
module "app_a_oidc" {
  providers = {
    vault = vault.app_a
  }
  source = "github.com/grantorchard/terraform-vault-module-oidc"

  azure_tenant_id    = local.azure_tenant_id
  oidc_client_id     = local.oidc_client_id
  oidc_client_secret = local.oidc_client_secret
  web_redirect_uri   = "${var.vault_url}/ui/vault/auth/oidc/oidc/callback?${local.app_a}"
}

# Secrets Engines
# k/v
resource vault_mount "app_a_kv" {
  provider = vault.app_a

  path        = "${local.app_a}/secret"
  type        = "kv-v2"
}

## Database


# User Onboarding
module "tenant_a_user_onboarding" {
  providers = {
    vault = vault.app_a
  }
  source = "github.com/grantorchard/terraform-vault-module-entities"

  mount_accessor = module.app_a_oidc.mount_accessor
  users = merge(local.app_a_kv_read_users,
                local.app_a_kv_write_users
          )
}


module "tenant_a_group_kv_reader" {
  providers = {
    vault = vault.app_a
  }
  source = "github.com/grantorchard/terraform-vault-module-policies"

  members = [
    for k,v in local.app_a_kv_read_users: lookup(module.tenant_a_user_onboarding.entities, k)
  ]
  policy_name = "kv_reader"
  policy_contents = templatefile("${path.module}/policies/kv_read.hcl",
    {
      path = vault_mount.app_a_kv.path
    }
  )
}
/*
module "tenant_a_group_kv_writer" {
  providers = {
    vault = vault.app_a
  }
  source = "../terraform-vault-module-policies"
  dependencies = module.tenant_a_user_onboarding.entities

  members = [
    "burkey"
  ]
  policy_name = "kv_writer"
  policy_contents = templatefile("${path.module}/policies/kv_write.hcl",
    {
      path = vault_mount.app_a_kv.path
    }
  )
}


/*


kv read
kv write
db read



add users
user entities

add groups with users and policies
*/