#/bin/bash
ACR_ID="sslovidiu.azurecr.io"
echo "Bitcoin Monitor Deployment Script v.0.1beta"
echo "Checking requirements..."
command -v terraform >/dev/null 2>&1 || { echo >&2 "Terraform not installed on system. Aborting"; exit 1; }
command -v az >/dev/null 2>&1 || { echo >&2 "Azure CLI not installed on system. Aborting"; exit 1; }
command -v git >/dev/null 2>&1 || { echo >&2 "Azure CLI not installed on system. Aborting"; exit 1; }
echo "Getting the Admin Object ID for configuring on AKS Cluster"
if [[ -z "${ADMIN_ID}" ]]; then
  echo "Admin Object ID not found"
else 
   PRINCIPAL_ID=$ADMIN_ID
fi

#ACR_TOKEN=$(az acr login --name $ACR_ID --expose-token --output tsv --query accessToken)
#docker login $ACR_ID -u 00000000-0000-0000-0000-000000000000 -p $ACR_TOKEN

#sudo docker build -t btcmon ./get.go
#sudo docker tag btcmon sslovidiu.azurecr.io/btcmon
#sudo docker push sslovidiu.azurecr.io/btcmon

cat << EOF > ./main.tf
# --- Define Variable used
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
  metwork_policy = "azure"
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
  principal_id         = "$PRINCIPAL_ID"
}
EOF

terraform init
terraform apply -auto-approve

echo "AKS Cluster Installed Successfully..."

echo "$(terraform output kube_config)" > ./azurek8s

export KUBECONFIG="/home/ovi/bitcoin/azurek8s"
az aks update -n aksbitcoin -g bitcoin --attach-acr sslovidiu

kubectl create deployment service-a --image=sslovidiu.azurecr.io/btcmon --port=8080 --replicas=1
kubectl expose deployment service-a --type=ClusterIP --port=8080 --target-port=8080

kubectl create deployment service-b --image=sslovidiu.azurecr.io/btcmon --replicas=1 --port=8080
kubectl expose deployment service-b --type=ClusterIP --port=8080 --target-port=8080 

helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm install ingress-nginx ingress-nginx/ingress-nginx --set controller.service.annotations."service\.beta\.kubernetes\.io/azure-load-bala
ncer-health-probe-request-path"=/healthz

cat << EOF > ./ingress-service-a.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: servicea
  namespace: servicea
spec:
  ingressClassName: nginx
  rules:
  - host: azbastion.cloud
    http:
      paths:
      - backend:
          service:
            name: service-a
            port:
              number: 8080
        path: /
        pathType: Prefix
      - backend:
          service:
            name: service-b
            port:
              number: 8080
        path: /health
        pathType: Prefix
EOF

cat << EOF > ./ingress-service-b.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: serviceb
  namespace: serviceb
spec:
  ingressClassName: nginx
  rules:
  - host: azbastion.cloud
    http:
      paths:
      - backend:
          service:
            name: service-b
            port:
              number: 8080
        path: /health
        pathType: Prefix
EOF

kubectl apply -f ./ingress-service-a.yaml
kubectl apply -f ./ingress-service-b.yaml

kubectl label ns app=default

#Default Deny Network Policy
cat << EOF > ./default-deny.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-egress
spec:
  podSelector: {}
  policyTypes:
  - Egress
  - Ingress
EOF

kubectl apply -f ./default-deny.yaml -n servicea
kubectl apply -f ./default-deny.yaml -n serviceb

#Allow Traffic from Default namespace where the  Ingress Nginx controller is installed
cat << EOF > ./allow-ingress.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: access-nginx
spec:
  podSelector: {}
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          app: "default"
EOF

kubectl apply -f ./allow-ingress.yaml -n servicea
kubectl apply -f ./allow-ingress.yaml -n serviceb
