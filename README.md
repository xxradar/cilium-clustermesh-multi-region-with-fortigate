# A multi-region Cilium Clustermesh using Fortigate VPN in AWS
## Introduction
<p align="center">
<img src="./images/clustermesh.png"  width="800" />
</p> <br>

## Setting up the network and fortigate infrastructure
Next terraform plan will create a public and private network and deploy a PAYG fortigate instance.<br>
Rename `terraform.tfvars.example` to `terraform.tfvars` and populate the variables. <br>
Deployment will happen in AWS region `eu-west-3`.
```
cd fgtsingle1
terraform init
terraform apply 
```
Repeat the process for AWS region `eu-west-1` (fgtsingle2)<br>
Give it some minutes. The `terraform output` will provide login details and IP address of the Fortigates.

## Configuring the Fortigates
### Create an allow_all outbound rule
<details>
<summary>Create on both firewall an address resource representing the private networks.</summary>
- eu-west-3 (fgtsingle1) -> 10.1.1.0/24<br>
- eu-west-1 (fgtsingle2) -> 10.2.1.0/24<br>
<br>
<br>
<p align="center">
<img src="./images/private_network.png"  width="600" />
</p> <br>
</details>
<details>
  <summary>Create an outbound firewall rule.</summary>
<p align="center">
<img src="./images/allow-all.png"  width="600" align="center" /><br><br>
<img src="./images/allow-all-rule.png"  width="1000" align="center" />
</p> <br>
</details>

### Create a VPN IPSEC tunnel
<details>
<summary>IPSEC VPN setup using VPN wizard</summary>

<p align="center">
<img src="./images/vpn-setup-1.png"  width="1000" align="center" /><br>
<img src="./images/vpn-setup-2.png"  width="1000" align="center" /><br>
<img src="./images/vpn-setup-3.png"  width="1000" align="center" /><br>
<img src="./images/vpn-setup-4.png"  width="1000" align="center" /><br>
</p> <br>
</details>

## Deploying kubernetes and jumpbox
In the next step, a 3-node kubernetes cluster is deployed, together with a jumpbox and backend test server.<br>
Rename `terraform.tfvars.example` to `terraform.tfvars` and populate the variables.<br>
The information can be obtained from the `terraform output` for both fortigate deployments.
```
cd terraform-k8s-1
terraform init
terraform apply
```
Repeat process for terraform-k8s-2

## Deploying the clustermesh
### Install pre-requisite tooling
On both clusters:
<details>
<summary>Install required tooling </summary>

```
CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/main/stable.txt)
CLI_ARCH=amd64
if [ "$(uname -m)" = "aarch64" ]; then CLI_ARCH=arm64; fi
curl -L --fail --remote-name-all https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}
sha256sum --check cilium-linux-${CLI_ARCH}.tar.gz.sha256sum
sudo tar xzvfC cilium-linux-${CLI_ARCH}.tar.gz /usr/local/bin
rm cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}



export HUBBLE_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/hubble/master/stable.txt)
curl -L --remote-name-all https://github.com/cilium/hubble/releases/download/$HUBBLE_VERSION/hubble-linux-amd64.tar.gz{,.sha256sum}
sha256sum --check hubble-linux-amd64.tar.gz.sha256sum
sudo tar xzvfC hubble-linux-amd64.tar.gz /usr/local/bin
rm hubble-linux-amd64.tar.gz{,.sha256sum}

sudo snap install helm --classic
helm repo add cilium https://helm.cilium.io/
```
</details>

### Install Cilium CNI on cluster1
```
helm install cilium cilium/cilium --version 1.14.2 \
    --namespace kube-system \
    --set authentication.mutual.spire.enabled=true \
    --set authentication.mutual.spire.install.enabled=true \
    --set hubble.relay.enabled=true \
    --set hubble.ui.enabled=true \
    --set encryption.enabled=true \
    --set encryption.type=wireguard \
    --set kube-proxy-replacement=strict \
    --set ingressController.enabled=partial \
    --set ingressController.loadbalancerMode=shared \
    --set ingressController.service.type="NodePort" \
    --set loadBalancer.l7.backend=envoy \
    --set auto-create-cilium-node-resource=true \
    --set ipam.operator.clusterPoolIPv4PodCIDRList="10.10.0.0/16" \
    --set ipam.operator.clusterPoolIPv4MaskSize="24" \
    --set ipam.mode=cluster-pool \
    --set cluster.id=1 \
    --set cluster.name="cluster1"
```
### Install Cilium CNI on cluster2
```
helm install cilium cilium/cilium --version 1.14.2 \
    --namespace kube-system \
    --set authentication.mutual.spire.enabled=true \
    --set authentication.mutual.spire.install.enabled=true \
    --set hubble.relay.enabled=true \
    --set hubble.ui.enabled=true \
    --set encryption.enabled=true \
    --set encryption.type=wireguard \
    --set kube-proxy-replacement=strict \
    --set ingressController.enabled=partial \
    --set ingressController.loadbalancerMode=shared \
    --set ingressController.service.type="NodePort" \
    --set loadBalancer.l7.backend=envoy \
    --set auto-create-cilium-node-resource=true \
    --set ipam.operator.clusterPoolIPv4PodCIDRList="10.12.0.0/16" \
    --set ipam.operator.clusterPoolIPv4MaskSize="24" \
    --set ipam.mode=cluster-pool \
    --set cluster.id=2 \
    --set cluster.name="cluster2"
```
### Enable the clustermesh service
On both clusters:
```
cilium clustermesh enable --service-type NodePort
```
### Create a kubeconfig with access to both clusters
Combine both `.kube/config` files
- make sure clusternames are different
- make sure usernames are differemt
- make sure context names are different
<br>

Follow these steps:
```
cp .kube/config cluster1.yaml
```
```
touch cluster2.yaml
```
copy/paste `.kube/config` content (cluster2) into `cluster2.yaml`<br>
We now have a copy of both kubeconfig files stored in respectively `cluster1.yaml` and `cluster2.yaml`<r>
<br>

### Create unique context, user and cluster references in both files
```
sed -i 's/kubernetes/kubernetes1/g' cluster1.yaml
sed -i 's/kubernetes/kubernetes2/g' cluster2.yaml
```
### Load the KUBECONFIG 
```
export KUBECONFIG=$PWD/cluster1.yaml:$PWD/cluster2.yaml
```
```
~$ kubectl config get-contexts
CURRENT   NAME                           CLUSTER       AUTHINFO            NAMESPACE
*         kubernetes1-admin@kubernetes1   kubernetes1   kubernetes-admin1
          kubernetes2-admin@kubernetes2   kubernetes2   kubernetes-admin2
```
### Connect both clusters
```
cilium clustermesh connect --context kubernetes1-admin@kubernetes1 --destination-context kubernetes2-admin@kubernetes2
```
## Deploy demo app
Deploy a demo app, based on [https://github.com/xxradar/app_routable_demo](https://github.com/xxradar/app_routable_demo) on **both K8S clusters**
```
git clone https://github.com/xxradar/app_routable_demo.git
cd ./app_routable_demo
./setup.sh
watch kubectl get po -n app-routable-demo -o wide
```

### Optionally: 
configure Cilium Ingress
```
kubectl apply -f ./app_routable_demo/ingress_cilium.yaml
```
Additionally, you need to create a firewall rule allowing access from the internet towards the ingress nodeports.
<p align="center">
<img src="./images/ingress-fw-rule.png"  width="1000" align="center" /><br>
</p> 

## Testing the clustermesh
### App architecture
The ultimate goal is to create following app deployment.<br>
<p align="center">
<img src="./images/microservice-mesh.png"  width="600" align="center" /><br>
</p> <br>
Currently the application is not **globably shared`** accross both clusters.

### Connectivity test w/o service sharing
On both clusters, run following test:
```
kubectl run -it -n app-routable-demo --rm --image xxradar/hackon mycurler -- bash
       curl -v -H "Cookie: loc=client" http://zone1/app3
```

<details>
<summary>Result cluster1 </summary><br>

```
root@mycurler:/# curl -v -H "Cookie: loc=client" http://zone1/app3
*   Trying 10.100.23.232:80...
* Connected to zone1 (10.100.23.232) port 80 (#0)
> GET /app3 HTTP/1.1
> Host: zone1
> User-Agent: curl/7.81.0
> Accept: */*
> Cookie: loc=client
>
* Mark bundle as not supporting multiuse
< HTTP/1.1 200 OK
< Server: nginx/1.25.2
< Date: Tue, 19 Sep 2023 10:44:51 GMT
< Content-Type: application/json; charset=utf-8
< Content-Length: 600
< Connection: keep-alive
< X-Powered-By: Express
< ETag: W/"258-zGzwAESu1cvKemzgO8W6mCBaWZQ"
<
{
  "path": "/app3",
  "headers": {
    "x-forwarded-for": "10.10.2.91, 10.10.2.183, 10.10.1.240",
    "cookie": "loc=client, loc=zone1, loc=zone3, loc=zone5",
    "host": "zone7",
    "connection": "close",
    "user-agent": "curl/7.81.0",
    "accept": "*/*"
  },
  "method": "GET",
  "body": "",
  "fresh": false,
  "hostname": "zone7",
  "ip": "10.10.2.91",
  "ips": [
    "10.10.2.91",
    "10.10.2.183",
    "10.10.1.240"
  ],
  "protocol": "http",
  "query": {},
  "subdomains": [],
  "xhr": false,
  "os": {
    "hostname": "echoserver-2-deployment-6f499cfbbb-7kztt"
  },
  "connection": {}
* Connection #0 to host zone1 left intact
}
```
  
</details>

<details>
<summary>Result cluster2 </summary><br>

```
root@mycurler:/# curl -v -H "Cookie: loc=client" http://zone1/app3
*   Trying 10.96.245.46:80...
* Connected to zone1 (10.96.245.46) port 80 (#0)
> GET /app3 HTTP/1.1
> Host: zone1
> User-Agent: curl/7.81.0
> Accept: */*
> Cookie: loc=client
>
* Mark bundle as not supporting multiuse
< HTTP/1.1 200 OK
< Server: nginx/1.25.2
< Date: Tue, 19 Sep 2023 10:44:49 GMT
< Content-Type: application/json; charset=utf-8
< Content-Length: 593
< Connection: keep-alive
< X-Powered-By: Express
< ETag: W/"251-IE7zC2Tif6dhLPEYr0JMi8HMYYM"
<
{
  "path": "/app3",
  "headers": {
    "x-forwarded-for": "10.12.2.8, 10.12.0.40, 10.12.2.16",
    "cookie": "loc=client, loc=zone1, loc=zone3, loc=zone5",
    "host": "zone7",
    "connection": "close",
    "user-agent": "curl/7.81.0",
    "accept": "*/*"
  },
  "method": "GET",
  "body": "",
  "fresh": false,
  "hostname": "zone7",
  "ip": "10.12.2.8",
  "ips": [
    "10.12.2.8",
    "10.12.0.40",
    "10.12.2.16"
  ],
  "protocol": "http",
  "query": {},
  "subdomains": [],
  "xhr": false,
  "os": {
    "hostname": "echoserver-2-deployment-6f499cfbbb-fqh25"
  },
  "connection": {}
* Connection #0 to host zone1 left intact
}root@mycurler:/# curl -v -H "Cookie: loc=client" http://zone1/app3
*   Trying 10.96.245.46:80...
* Connected to zone1 (10.96.245.46) port 80 (#0)
> GET /app3 HTTP/1.1
> Host: zone1
> User-Agent: curl/7.81.0
> Accept: */*
> Cookie: loc=client
>
* Mark bundle as not supporting multiuse
< HTTP/1.1 200 OK
< Server: nginx/1.25.2
< Date: Tue, 19 Sep 2023 10:44:49 GMT
< Content-Type: application/json; charset=utf-8
< Content-Length: 593
< Connection: keep-alive
< X-Powered-By: Express
< ETag: W/"251-IE7zC2Tif6dhLPEYr0JMi8HMYYM"
<
{
  "path": "/app3",
  "headers": {
    "x-forwarded-for": "10.12.2.8, 10.12.0.40, 10.12.2.16",
    "cookie": "loc=client, loc=zone1, loc=zone3, loc=zone5",
    "host": "zone7",
    "connection": "close",
    "user-agent": "curl/7.81.0",
    "accept": "*/*"
  },
  "method": "GET",
  "body": "",
  "fresh": false,
  "hostname": "zone7",
  "ip": "10.12.2.8",
  "ips": [
    "10.12.2.8",
    "10.12.0.40",
    "10.12.2.16"
  ],
  "protocol": "http",
  "query": {},
  "subdomains": [],
  "xhr": false,
  "os": {
    "hostname": "echoserver-2-deployment-6f499cfbbb-fqh25"
  },
  "connection": {}
* Connection #0 to host zone1 left intact
}
```
  
</details>

### Connectivity test global service sharing
Annotate a service (zone1)
```
  annotations:
    service.cilium.io/global: "true"
    service.cilium.io/shared: "true"
```
You can test this:
```
kubectl run -it -n app-routable-demo --rm --image xxradar/hackon mycurler -- bash
       curl -v -H "Cookie: loc=client" http://zone1/app3
```

<details>
<summary>Result cluster1 </summary><br>

```
root@mycurler:/# curl -v -H "Cookie: loc=client" http://zone1/app3
*   Trying 10.100.210.61:80...
* Connected to zone1 (10.100.210.61) port 80 (#0)
> GET /app3 HTTP/1.1
> Host: zone1
> User-Agent: curl/7.81.0
> Accept: */*
> Cookie: loc=client
>
* Mark bundle as not supporting multiuse
< HTTP/1.1 200 OK
< Server: nginx/1.25.2
< Date: Tue, 19 Sep 2023 10:36:10 GMT
< Content-Type: application/json; charset=utf-8
< Content-Length: 599
< Connection: keep-alive
< X-Powered-By: Express
< ETag: W/"257-8F7QuYIPBkqxghJh0J7OdGFUAJY"
<
{
  "path": "/app3",
  "headers": {
    "x-forwarded-for": "10.10.2.159, 10.12.0.40, 10.12.2.16",
    "cookie": "loc=client, loc=zone1, loc=zone3, loc=zone5",
    "host": "zone7",
    "connection": "close",
    "user-agent": "curl/7.81.0",
    "accept": "*/*"
  },
  "method": "GET",
  "body": "",
  "fresh": false,
  "hostname": "zone7",
  "ip": "10.10.2.159",
  "ips": [
    "10.10.2.159",
    "10.12.0.40",
    "10.12.2.16"
  ],
  "protocol": "http",
  "query": {},
  "subdomains": [],
  "xhr": false,
  "os": {
    "hostname": "echoserver-2-deployment-6f499cfbbb-f754s"
  },
  "connection": {}
* Connection #0 to host zone1 left intact
}
```
  
</details>

<details>
<summary>Result cluster2 </summary><br>

```
root@mycurler:/# curl -v -H "Cookie: loc=client" http://zone1/app3
*   Trying 10.98.218.19:80...
* Connected to zone1 (10.98.218.19) port 80 (#0)
> GET /app3 HTTP/1.1
> Host: zone1
> User-Agent: curl/7.81.0
> Accept: */*
> Cookie: loc=client
>
* Mark bundle as not supporting multiuse
< HTTP/1.1 200 OK
< Server: nginx/1.25.2
< Date: Tue, 19 Sep 2023 10:38:01 GMT
< Content-Type: application/json; charset=utf-8
< Content-Length: 603
< Connection: keep-alive
< X-Powered-By: Express
< ETag: W/"25b-Sh6Qc2jjVtVZLUmH1G3UFezpX0E"
<
{
  "path": "/app3",
  "headers": {
    "x-forwarded-for": "10.12.2.122, 10.10.2.183, 10.10.1.240",
    "cookie": "loc=client, loc=zone1, loc=zone3, loc=zone5",
    "host": "zone7",
    "connection": "close",
    "user-agent": "curl/7.81.0",
    "accept": "*/*"
  },
  "method": "GET",
  "body": "",
  "fresh": false,
  "hostname": "zone7",
  "ip": "10.12.2.122",
  "ips": [
    "10.12.2.122",
    "10.10.2.183",
    "10.10.1.240"
  ],
  "protocol": "http",
  "query": {},
  "subdomains": [],
  "xhr": false,
  "os": {
    "hostname": "echoserver-2-deployment-6f499cfbbb-7kztt"
  },
  "connection": {}
* Connection #0 to host zone1 left intact
}
```
  
</details>

### Disable sharing on cluster2
Annotate a service (zone1)
```
  annotations:
    service.cilium.io/global: "true"
    service.cilium.io/shared: "false"
```
You can test this:
```
kubectl run -it -n app-routable-demo --rm --image xxradar/hackon mycurler -- bash
       curl -v -H "Cookie: loc=client" http://zone1/app3
```

<details>
<summary>Result cluster1 </summary><br>

```
root@mycurler:/# curl -v -H "Cookie: loc=client" http://zone1/app3
*   Trying 10.100.210.61:80...
* Connected to zone1 (10.100.210.61) port 80 (#0)
> GET /app3 HTTP/1.1
> Host: zone1
> User-Agent: curl/7.81.0
> Accept: */*
> Cookie: loc=client
>
* Mark bundle as not supporting multiuse
< HTTP/1.1 200 OK
< Server: nginx/1.25.2
< Date: Tue, 19 Sep 2023 10:29:07 GMT
< Content-Type: application/json; charset=utf-8
< Content-Length: 603
< Connection: keep-alive
< X-Powered-By: Express
< ETag: W/"25b-f0L/f1mAbIn+H04wKxbGvqLshvs"
<
{
  "path": "/app3",
  "headers": {
    "x-forwarded-for": "10.10.2.159, 10.10.2.183, 10.10.1.240",
    "cookie": "loc=client, loc=zone1, loc=zone3, loc=zone5",
    "host": "zone7",
    "connection": "close",
    "user-agent": "curl/7.81.0",
    "accept": "*/*"
  },
  "method": "GET",
  "body": "",
  "fresh": false,
  "hostname": "zone7",
  "ip": "10.10.2.159",
  "ips": [
    "10.10.2.159",
    "10.10.2.183",
    "10.10.1.240"
  ],
  "protocol": "http",
  "query": {},
  "subdomains": [],
  "xhr": false,
  "os": {
    "hostname": "echoserver-2-deployment-6f499cfbbb-l6z8f"
  },
  "connection": {}
* Connection #0 to host zone1 left intact
}
```
  
</details>

<details>
<summary>Result cluster2 </summary><br>

```
root@mycurler:/# curl -v -H "Cookie: loc=client" http://zone1/app3
*   Trying 10.98.218.19:80...
* Connected to zone1 (10.98.218.19) port 80 (#0)
> GET /app3 HTTP/1.1
> Host: zone1
> User-Agent: curl/7.81.0
> Accept: */*
> Cookie: loc=client
>
* Mark bundle as not supporting multiuse
< HTTP/1.1 200 OK
< Server: nginx/1.25.2
< Date: Tue, 19 Sep 2023 10:30:47 GMT
< Content-Type: application/json; charset=utf-8
< Content-Length: 603
< Connection: keep-alive
< X-Powered-By: Express
< ETag: W/"25b-NpEDfnU4V3ztZSYebd9GcZlJZOU"
<
{
  "path": "/app3",
  "headers": {
    "x-forwarded-for": "10.12.2.137, 10.10.2.183, 10.10.1.240",
    "cookie": "loc=client, loc=zone1, loc=zone3, loc=zone5",
    "host": "zone7",
    "connection": "close",
    "user-agent": "curl/7.81.0",
    "accept": "*/*"
  },
  "method": "GET",
  "body": "",
  "fresh": false,
  "hostname": "zone7",
  "ip": "10.12.2.137",
  "ips": [
    "10.12.2.137",
    "10.10.2.183",
    "10.10.1.240"
  ],
  "protocol": "http",
  "query": {},
  "subdomains": [],
  "xhr": false,
  "os": {
    "hostname": "echoserver-2-deployment-6f499cfbbb-7kztt"
  },
  "connection": {}
* Connection #0 to host zone1 left intact
}
```
  
</details>


# Ingress testing
<details>
<summary>Igress results </summary>
  
#### fgtsingle1_eip
```
% curl 35.180.16.215/app2
{
  "path": "/app2",
  "headers": {
    "x-forwarded-for": "84.192.8.14, 10.10.2.138, 10.10.2.183, 10.10.1.22",
    "cookie": ", loc=zone1, loc=zone2, loc=zone5",
    "host": "zone7",
    "connection": "close",
    "user-agent": "curl/8.1.2",
    "accept": "*/*",
    "x-forwarded-proto": "http",
    "x-envoy-external-address": "84.192.8.14",
    "x-request-id": "7cb335aa-a6b5-43ac-aa33-265220a46259"
  },
  "method": "GET",
  "body": "",
  "fresh": false,
  "hostname": "zone7",
  "ip": "84.192.8.14",
  "ips": [
    "84.192.8.14",
    "10.10.2.138",
    "10.10.2.183",
    "10.10.1.22"
  ],
  "protocol": "http",
  "query": {},
  "subdomains": [],
  "xhr": false,
  "os": {
    "hostname": "echoserver-2-deployment-6f499cfbbb-x5pkw"
  },
  "connection": {}
}
```
#### fgtsingle2_eip
```
% curl 34.242.99.90/app1
{
  "path": "/app1",
  "headers": {
    "x-forwarded-for": "84.192.8.14, 10.12.2.54, 10.12.0.40, 10.12.0.239",
    "cookie": ", loc=zone1, loc=zone2, loc=zone4",
    "host": "zone6",
    "connection": "close",
    "user-agent": "curl/8.1.2",
    "accept": "*/*",
    "x-forwarded-proto": "http",
    "x-envoy-external-address": "84.192.8.14",
    "x-request-id": "b45d921d-a2e4-4a98-963e-04cf2e345ee5"
  },
  "method": "GET",
  "body": "",
  "fresh": false,
  "hostname": "zone6",
  "ip": "84.192.8.14",
  "ips": [
    "84.192.8.14",
    "10.12.2.54",
    "10.12.0.40",
    "10.12.0.239"
  ],
  "protocol": "http",
  "query": {},
  "subdomains": [],
  "xhr": false,
  "os": {
    "hostname": "echoserver-1-deployment-695c7db8d-ljnw6"
  },
  "connection": {}
}
```
#### Annotations
Annotate a service (zone1) (cluster1)
```
  annotations:
    service.cilium.io/global: "true"
    service.cilium.io/shared: "true"
```
Annotate a service (zone1) (cluster2)
```
  annotations:
    service.cilium.io/global: "true"
    service.cilium.io/shared: "false"
```

#### fgtsingle1_eip
```
% curl 35.180.16.215/app2
{
  "path": "/app2",
  "headers": {
    "x-forwarded-for": "84.192.8.14, 10.10.2.138, 10.12.0.40, 10.12.0.239",
    "cookie": ", loc=zone1, loc=zone2, loc=zone5",
    "host": "zone7",
    "connection": "close",
    "user-agent": "curl/8.1.2",
    "accept": "*/*",
    "x-forwarded-proto": "http",
    "x-envoy-external-address": "84.192.8.14",
    "x-request-id": "65deeed9-0c1b-406a-b078-69de93451ef2"
  },
  "method": "GET",
  "body": "",
  "fresh": false,
  "hostname": "zone7",
  "ip": "84.192.8.14",
  "ips": [
    "84.192.8.14",
    "10.10.2.138",
    "10.12.0.40",
    "10.12.0.239"
  ],
  "protocol": "http",
  "query": {},
  "subdomains": [],
  "xhr": false,
  "os": {
    "hostname": "echoserver-2-deployment-6f499cfbbb-fqh25"
  },
  "connection": {}
}
```
#### fgtsingle2_eip
```
 curl 34.242.99.90/app1
{
  "path": "/app1",
  "headers": {
    "x-forwarded-for": "84.192.8.14, 10.12.2.54, 10.12.0.40, 10.12.0.239",
    "cookie": ", loc=zone1, loc=zone2, loc=zone4",
    "host": "zone6",
    "connection": "close",
    "user-agent": "curl/8.1.2",
    "accept": "*/*",
    "x-forwarded-proto": "http",
    "x-envoy-external-address": "84.192.8.14",
    "x-request-id": "c7425a21-cc19-4d45-b64e-05e8ffe7323d"
  },
  "method": "GET",
  "body": "",
  "fresh": false,
  "hostname": "zone6",
  "ip": "84.192.8.14",
  "ips": [
    "84.192.8.14",
    "10.12.2.54",
    "10.12.0.40",
    "10.12.0.239"
  ],
  "protocol": "http",
  "query": {},
  "subdomains": [],
  "xhr": false,
  "os": {
    "hostname": "echoserver-1-deployment-695c7db8d-ljnw6"
  },
  "connection": {}
}
```

</details>
