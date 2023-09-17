module "env" {
  source = "./modules/k8s_env"
  prefix = var.prefix
  region = var.region
  environment = "${var.environment}"
  workercount = var.workercount
  instancecount = var.instancecount
  privatesubnet = var.privatesubnet
  publicsubnet = var.publicsubnet
  vpcid = var.vpcid
}