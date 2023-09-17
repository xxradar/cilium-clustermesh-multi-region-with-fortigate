# Cilium Clustermesh multi-region using Fortinet Fortigate VPN in AWS
## Intruduction
This tutorial ...

## Setting up the network and fortigate infrastructure
Next terraform plan will create a public and private network and deploy a PAYG fortigate instance.<br>
Rename `terraform.tfvars.example` to `terraform.tfvars` and populate the variables. <br>
Deployment will happen in AWS region `eu-west-3`.
```
cd fgtsingle1
terraform init
terraform apply 
```
repeat the process for AWS region `eu-west-1`
```
cd fgtsingle2
terraform init
terraform apply 
```
Give it some minutes. The `terraform output` will provide login details and IP address of the Fortigates.

## Configuring the Fortigates
### Create an allow_all outbound rule
Create on both firewall an `address` representing the private networks.<br>
<p align="center">
<img src="./images/private_network.png"  width="400" />
</p> <br>
Create an outbound firewall rule.<br>
<p align="center">
<img src="./images/allow-all.png"  width="600" align="center" />
</p> <br>

### Create a VPN IPSEC tunnel

