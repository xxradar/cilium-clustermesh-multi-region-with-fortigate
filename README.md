# Cilium Clustermesh multi-region using Fortinet Fortigate VPN in AWS
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
repeat the process for AWS region `eu-west-1` (fgtsingle2)<br>
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
<img src="./images/vpn-setup-1.png"  width="600" align="center" /><br>
<img src="./images/vpn-setup-2.png"  width="600" align="center" /><br>
<img src="./images/vpn-setup-3.png"  width="600" align="center" /><br>
<img src="./images/vpn-setup-4.png"  width="600" align="center" /><br>
</p> <br>
</details>

### Create a VPN IPSEC tunnel
<details>
<summary>IPSEC VPN setup using IPSEC wizard</summary>

<p align="center">
<img src="./images/allow-all.png"  width="600" align="center" /><br><br>
<img src="./images/allow-all-rule.png"  width="1000" align="center" />
</p> <br>
</details>
