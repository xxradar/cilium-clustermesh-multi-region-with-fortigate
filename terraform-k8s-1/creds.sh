#!/bin/bash
echo $1
[ -z $(eval 'terraform  output -json  jumbox_public_ip') ] && exit 1

instancecount=$(eval "terraform  output -json instancecount")
instancecount=$(($instancecount-1))
# echo $instancecount 

workercount=$(eval "terraform  output -json worker_count")
workercount=$(($workercount-1))
# echo $workercount 

 for (( i=0; i<=$instancecount; i++ ))
do
  ### Gett the private keys
  rm -f ./key$i.pem
  terraform output -json  private_key | jq -r '.['$i']' >key$i.pem
  chmod 400 ./key$i.pem

  ### Get the jumpbox, k8smaster and k8snodes
  ip=$(eval "terraform  output -json  jumbox_public_ip | jq -r '.['$i']'")
  
  #terraform state show 'module.env[0].aws_instance.jumpbox' 
  master=$(eval "terraform output -json  k8smaster_private_ip | jq -r '.['$i']'")
  nodes=$(eval "terraform output -json  k8nodes_private_ip | jq -r '.['$i']'")

  ### Get the kubeadm join command
  join=$(eval "ssh -i ./key$i.pem  -o "StrictHostKeyChecking=accept-new" ubuntu@$ip ssh -i key.pem -o "StrictHostKeyChecking=accept-new" ubuntu@$master sudo kubeadm token create --print-join-command ")
 
  ### Apply ythe join command on all nodes
   echo $join  
  for (( x=0; x<=$workercount; x++ ))
    do
    mynode=$(echo $nodes | jq -r '.['$x']')
    echo $mynode
    command='ssh -i ./key'$i'.pem  -o "StrictHostKeyChecking=accept-new" ubuntu@'$ip' ssh -i key.pem -o "StrictHostKeyChecking=accept-new" ubuntu@'$mynode' sudo '$join'&'
    eval $command  > /dev/null 2>&1
    done 
  
  ### Install the CNI on k8smaster
  ssh -i ./key$i.pem  -o "StrictHostKeyChecking=accept-new" ubuntu@$ip ssh -i key.pem -o "StrictHostKeyChecking=accept-new" ubuntu@$master 'curl -O https://raw.githubusercontent.com/xxradar/cilium-lab/main/cilium_install.sh'  > /dev/null 2>&1
  ssh -i ./key$i.pem  -o "StrictHostKeyChecking=accept-new" ubuntu@$ip ssh -i key.pem -o "StrictHostKeyChecking=accept-new" ubuntu@$master 'chmod 770 /home/ubuntu/cilium_install.sh'  > /dev/null 2>&1
  ssh -i ./key$i.pem  -o "StrictHostKeyChecking=accept-new" ubuntu@$ip ssh -i key.pem -o "StrictHostKeyChecking=accept-new" ubuntu@$master '/home/ubuntu/cilium_install.sh'  > /dev/null 2>&1


### Echo login steps
echo "ssh -i key$i.pem ubuntu@$ip" 
echo "K8S Master: ssh -i key.pem ubuntu@$master"
done


