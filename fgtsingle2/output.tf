
output "FGTPublicIP" {
  value = aws_eip.FGTPublicIP.public_ip
}

output "Username" {
  value = "admin"
}

output "Password" {
  value = aws_instance.fgtvm.id
}

output "vpcid" {
  value = aws_vpc.fgtvm-vpc.id
}

output "publicsubnet" {
  value = aws_subnet.publicsubnetaz1.id
}

output "privatesubnet" {
  value = aws_subnet.privatesubnetaz1.id
}
