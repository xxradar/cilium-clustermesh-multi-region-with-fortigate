output "private_key" {
  value = [for e in module.env[*] : e.private_key]
  sensitive = true
}

output "jumbox_public_ip" {
  value = [for e in module.env[*] : e.jumbox_public_ip]
  sensitive = false
}

output "backend_private_ip" {
  value = [for e in module.env[*] : e.backend_private_ip]
  sensitive = false
}


output "k8smaster_private_ip" {
  value = [for e in module.env[*] : e.k8smaster_private_ip]
  sensitive = false
}

output "k8nodes_private_ip" {
  value = [for e in module.env[*] : e.k8snodes_private_ip]
  sensitive = false
}

output "worker_count" {
value = "${var.workercount}"
}


output "instancecount" {
value = "${var.instancecount}"
}
