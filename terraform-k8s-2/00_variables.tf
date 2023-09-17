variable "access_key" {
description = "The AWS access key."
}

variable "secret_key" {
description = "The AWS access secret."
}

variable "region" {
description = "The AWS region."
default = "eu-west-1"
}


variable "instancecount" {
  type    = number
  default = 1
}
variable "workercount" {
  type    = number
  default = 2
}

variable "prefix" {}

variable "environment" {}

variable "privatesubnet" {}

variable "publicsubnet" {}

variable "vpcid" {}
