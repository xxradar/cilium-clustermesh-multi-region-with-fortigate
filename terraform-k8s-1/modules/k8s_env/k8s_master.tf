resource "aws_instance" "k8s_master" {
  ami           = "${data.aws_ami.ubuntu_ami.image_id}"
  instance_type = "t2.xlarge"
  key_name      = "${aws_key_pair.jumpbox_key.key_name}"
  subnet_id     = "${var.privatesubnet}"
  vpc_security_group_ids      = ["${aws_security_group.allow_custom_k8s.id}"]
  associate_public_ip_address = true

  root_block_device {
    volume_size           = "50"
    volume_type           = "gp2"
    encrypted             = true
    delete_on_termination = true
  }

  user_data = <<EOF
#!/bin/bash
sudo apt-get update
sudo apt-get install -y  jq curl net-tools software-properties-common iputils-ping git vim nano
curl https://raw.githubusercontent.com/xxradar/install_k8s_ubuntu/main/setup_latest.sh | bash
sudo mkdir -p /home/ubuntu/.kube
sudo cp -i /etc/kubernetes/admin.conf /home/ubuntu/.kube/config
sudo chown ubuntu:ubuntu /home/ubuntu/.kube/config
EOF

  tags = {
    Name = "${var.prefix}-${var.environment}-ec2-k8smaster"
  }
}

