variable "resource_group_name" {
  type    = string
  default = "bitcoin"
}

variable "location" {
  type    = string
  default = "West Europe"
}

# --- Terraform Main Block
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~>3.0"
    }
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }

  }
}

# --- Azure Resource Group
resource "azurerm_resource_group" "resource_group" {
  name     = var.resource_group_name
  location = "West Europe"
}

# --- Azure Kubernetes Service Cluster

resource "azurerm_kubernetes_cluster" "aks" {
  name                = "aksbitcoin"
  location            = azurerm_resource_group.resource_group.location
  resource_group_name = azurerm_resource_group.resource_group.name
  dns_prefix          = "aksudertest-5dd"
  oidc_issuer_enabled       = true
  workload_identity_enabled = true
  default_node_pool {
    name           = "system"
    node_count     = 1
    vm_size        = "Standard_DS2_v2"
  }
  network_profile {
  network_plugin = "azure"
  network_policy = "azure"
  }
  identity {
    type = "SystemAssigned"
  }
  azure_active_directory_role_based_access_control {
  managed = true
  azure_rbac_enabled = true
  }
}


output "kube_admin_config" {
  value = azurerm_kubernetes_cluster.aks.kube_admin_config
  sensitive = true
}


output "kube_config" {
  value = azurerm_kubernetes_cluster.aks.kube_config_raw
  sensitive = true
}

resource "azurerm_role_assignment" "example" {
  scope                = azurerm_kubernetes_cluster.aks.id
  role_definition_name = "Azure Kubernetes Service RBAC Cluster Admin"
  principal_id         = "xxxxxxxxxxxxxxxx"
}
