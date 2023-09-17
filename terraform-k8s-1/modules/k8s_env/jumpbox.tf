resource "tls_private_key" "key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "jumpbox_key" {
  key_name   = "${var.prefix}-${var.environment}-jumpbox_key_${var.region}"
  public_key = tls_private_key.key.public_key_openssh
}  
  
  data "aws_ami" "ubuntu_ami" {
    most_recent = true
    owners      = ["679593333241"]
    filter {
      name   = "name"
      values = ["*ubuntu-jammy-22.04-amd64-minimal-20220717*"]
    }
  }

  resource "aws_instance" "jumpbox" {
  ami           = "${data.aws_ami.ubuntu_ami.image_id}"
  instance_type = "t2.micro"
  key_name      = "${aws_key_pair.jumpbox_key.key_name}"
  subnet_id     = "${var.publicsubnet}"
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
sudo apt-get install -y docker.io jq net-tools iputils-ping git
sudo echo "${tls_private_key.key.private_key_pem}" >/home/ubuntu/key.pem
sudo chmod 400 /home/ubuntu/key.pem
sudo chown ubuntu:ubuntu /home/ubuntu/key.pem
sudo docker run -d -p 8080:80 nginx
EOF

  tags = {
    Name = "${var.prefix}-${var.environment}-ec2-jumpbox"
  }
}

resource "aws_instance" "backend" {
  ami           = "${data.aws_ami.ubuntu_ami.image_id}"
  instance_type = "t2.micro"
  key_name      = "${aws_key_pair.jumpbox_key.key_name}"
  subnet_id     = "${var.privatesubnet}"
  vpc_security_group_ids      = ["${aws_security_group.allow_custom_k8s.id}"]
  associate_public_ip_address = true

  root_block_device {
    volume_size           = "20"
    volume_type           = "gp2"
    encrypted             = true
    delete_on_termination = true
  }

  user_data = <<EOF
#!/bin/bash
apt-get update
apt-get install -y docker.io jq net-tools
sudo docker run -d -p 8080:80 nginx
EOF

  tags = {
    Name = "${var.prefix}-${var.environment}-ec2-backend"
  }
}