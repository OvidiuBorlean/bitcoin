# BITCOIN - Web Monitor
## Golang based Bitcoin monitor


**Table of content:**

- [About Project](#item-one)
- [Prerequisites](#item-two)
- [Implementation](#item-three)
- [What can be done better](#item-four)
- [Final words](#item-five)

<!-- headings -->
<a id="item-one"></a>
### About Bitcoin Monitor

Project Bitcoin Monitor is a microservices implementation of an application that can provide a realtime monitor for the Bitcoin values. It is implemented in Golang using the net/http library for implementing the web server connectivity.
By using a go routine that is running in parallel with the main function, the Bitcoin value is automatically update at specific time interval, default of 10 seconds, and based on the iteration value (default is 3 times), it calculate the average value. 
The application is deployed as a container, during the build process the code is compiled and the tagged image is pushed in a private ACR Registry. Also, the image will automatically expose the port 8080.

<a id="item-two"></a>
### Prerequisites
- Azure CLI
- Docker Engine
- kubelet
  

<a id="item-three"></a>
### Implementation
We deploy the Azure Infrastructure with Terraform. Using the latest version of AKS cluster with a single Node of type System and a VM SKU of Standard DS2_V2. On the networking layer we choose the Azure CNI, a System Assigned Identity and integration with Azure Entra for access to resources.

An Output block will provide access to the kubeconfig configuration in order to interact with with the managed AKS cluster through kubectl binary.
With Azure CLI we’ll attach the Azure Container Registry to our AKS Cluster. This command will actually provide the acr_pull Role to the Identity of the cluster over the Container Registry, hence the authentication of the containerd process over the ACR will be done directly over the Managed Identity.
For public exposing the services, we will use a Ingress Controller, in current setup we’ll deploy an Nginx Ingress Controller. This will assure the routing of the external requests to internal resources (Pods) inside the cluster. Installation of Nginx Ingress Controller is made with Helm, a cloud native package manager. 

As we use the community version of Nginx, we need to add the repository that host the components as follows:

```
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
```

Installation of the Nginx IC is created in minimal way, we only add the annotation for changing the Health Endopoint of the Load Balancer to /healthz. This is because of an architectural change that modified the health probe from TCP to HTTP.
Once we installed the Nginx Ingress Controller, it will automatically create a Load Balancer rules for inbound traffic, also it will automatically use the Frontend IP address of the underlay Load Balancer service. 

We deployed controllers in different namespaces as follows:
-	Ingress, Deployment and ClusterIP ServiceA in servicea namespace.
-	Ingress, Deployment and ClusterIP ServiceB in serviceb namespace.

Our Service A deployment consist of a single replica of our application (btcmon) and exposed with a Cluster IP service. This Service name will be used in the Ingress configuration. 

```
kubectl create deployment service-a --image=sslovidiu.azurecr.io/btcmon --port=8080 --replicas=1 -n servicea
kubectl expose deployment service-a --type=ClusterIP --port=8080 --target-port=8080 -n servicea
```
We used a custom domain configured in Ingress Host section and also created as a zone in Azure DNS. 
We will deploy the Service B in a different namespace (serviceb)

```
kubectl create deployment service-b --image=sslovidiu.azurecr.io/btcmon --replicas=1 --port=8080 -n serviceb
kubectl expose deployment service-b --type=ClusterIP --port=8080 --target-port=8080 -n serviceb
```
Will add the new endpoint in the Ingress configuration file with a different path (/health). It will use as an endpoint the new Service-B deployment. 

## Securing the traffic between services:

First, we’ll test the functionality of the Pod’s endpoint by opening a shell session on Service A Pod:

```
kubectl exec -it service-a-7fbf6bb868-l4chd – bash
```

A curl on the Service B Pod’s IP address will show that the application is reachable. Also the other way around, from Service B towards Service A.

To isolate the traffic between two namespaces (servicea and serviceb), we apply the following Network Policy in default namespace

To allow the traffic from Ingress controller in the default namespace towards the backend in servicea and serviceb namespaces we will apply network policy allow-default.yaml

<a id="item-four"></a>
### What can be done better
- Adding TLS support to Nginx Ingress controller by appending the TLS section in Ingress manifest
- Implementing the net/http Listener in goroutines to adapt to a higher number of requests
- Possible bug/race condition avoiding at the changing of the index.html file. If there is a http request in same time with an update operation it can trigger an error.
- Frontend workout
- Using Go template implementation for improving the Web Frontend
- Save data localy to have an historical pattern

<a id="item-five"></a>
### Final words
Thank you
