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
cd fgtsingle1
terraform init
terraform apply 
```
Give it some minutes. The `terraform output` will provide login details and IP address of the Fortigates
