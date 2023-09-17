resource "null_resource" "runstuff" {
  depends_on = [ module.env ]  
  
  provisioner "local-exec" {
   command = "./creds.sh"
  }
}