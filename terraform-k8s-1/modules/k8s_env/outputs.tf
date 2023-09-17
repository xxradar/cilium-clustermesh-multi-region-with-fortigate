output "jumbox_public_ip" {
   value = "${aws_instance.jumpbox.public_ip}"
}

output "backend_private_ip" {
   value = "${aws_instance.backend.private_ip}"
}

output "k8smaster_private_ip" {
   value = "${aws_instance.k8s_master.private_ip}"
}

output "k8snodes_private_ip" {
  value = [for e in aws_instance.k8s_nodes[*] : e.private_ip]
  sensitive = false
#  value = "${aws_instance.k8s_nodes[0].private_ip},${aws_instance.k8s_nodes[1].private_ip},${aws_instance.k8s_nodes[2].private_ip}"
}

output "private_key" {
  value     = tls_private_key.key.private_key_pem
  sensitive = true
}