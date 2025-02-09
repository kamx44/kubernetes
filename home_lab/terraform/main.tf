locals {
  workers = {
    "worker1" = {
      vmid = 120
      ip_cidr = "192.168.137.26/24"
      mac_address = "bc:24:11:2b:41:09"
    },
    "worker2" = {
      vmid = 130
      ip_cidr = "192.168.137.27/24"
      mac_address = "bc:24:11:2b:41:08"
    },
    "worker3" = {
      vmid = 140
      ip_cidr = "192.168.137.28/24"
      mac_address = "bc:24:11:2b:41:07"
    }
  }
  k8s_vms = {
    "master" = {
      vmid = 110
      ip_cidr = "192.168.137.20/24"
      mac_address = "bc:24:11:2b:41:01"
    }
  }
  nameserver = "192.168.137.1"
  gateway = "192.168.137.1"
}

module "kube_node" {
  for_each = local.k8s_vms
  source = "./modules/kube_node"

  vm_name = "k8s-vm-master"
  vm_id = 110
  clone_name = "ubuntu-24-template"
  cores = 2
  memory = 2048
  network = {
    ip_cidr = each.value.ip_cidr
    mac_address = each.value.mac_address
    nameserver =  local.nameserver
    gateway =  local.gateway
  }
  authentications = {
    public_key = var.public_key
    vm_user = var.vm_user
    vm_password = var.vm_password
    private_key_location = var.private_key_location
  }
}


resource "null_resource" "kubeadm-init"{

  provisioner "remote-exec" {
    
    inline = [
      "sudo kubeadm init",
      "mkdir -p $HOME/.kube",
      "sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config",
      "sudo chown $(id -u):$(id -g) $HOME/.kube/config",
      "kubectl apply -f https://reweave.azurewebsites.net/k8s/v1.32/net.yaml"
    ]
  
    connection {
      type        = "ssh"
      user        = var.vm_user
      host        = module.kube_node["master"].host
      private_key = file(var.private_key_location)
      port        = 22
      timeout     = "2m"
    }
  }

  depends_on = [ 
    module.kube_node
   ]
}

resource "null_resource" "generate-token"{
  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = var.vm_user
      host        = module.kube_node["master"].host
      private_key = file(var.private_key_location)
      port        = 22
      timeout     = "2m"
    }

    inline = [
      "sudo kubeadm token create --print-join-command > /tmp/join_command.sh"
    ]
  }

  depends_on = [ 
    null_resource.kubeadm-init
   ]
}

resource "null_resource" "get_token"{
  provisioner "local-exec" {
    interpreter = ["PowerShell", "-Command"]
    command = "ssh -i ${var.private_key_location} ${var.vm_user}@192.168.137.20 -o StrictHostKeyChecking=no 'cat /tmp/join_command.sh' > C:\\Users\\Kamil\\.ssh\\join_command.sh"
  }

  depends_on = [ 
    null_resource.generate-token
   ]
}


resource "time_sleep" "wait_for_master" {
  depends_on = [null_resource.get_token]

  create_duration = "60s"
}


# ######## WORKER ##############


module "kube_worker" {
  for_each = local.workers
  source = "./modules/kube_node"

  vm_name = "k8s-vm-${each.key}"
  vm_id = each.value.vmid
  clone_name = "ubuntu-24-template"
  cores = 4
  memory = 4096
  network = {
    ip_cidr = each.value.ip_cidr
    mac_address = each.value.mac_address
    nameserver =  local.nameserver
    gateway =  local.gateway
  }
  authentications = {
    public_key = var.public_key
    vm_user = var.vm_user
    vm_password = var.vm_password
    private_key_location = var.private_key_location
  }

  depends_on = [ time_sleep.wait_for_master ]
}


resource "null_resource" "join_worker"{
  for_each = local.workers
  provisioner "file" {
    source      = "C:\\Users\\Kamil\\.ssh\\join_command.sh"
    destination = "/tmp/join_command.sh"

     connection {
      type        = "ssh"
      user        = var.vm_user
      host        = module.kube_worker["${each.key}"].host
      private_key = file(var.private_key_location)
      port        = 22
      timeout     = "2m"
    }
  }

  provisioner "remote-exec" {
    
    inline = [
      "chmod +x /tmp/join_command.sh",
      "dos2unix /tmp/join_command.sh",
      "sudo /tmp/join_command.sh",
    ]
  
    connection {
      type        = "ssh"
      user        = var.vm_user
      host        = module.kube_worker["${each.key}"].host
      private_key = file(var.private_key_location)
      port        = 22
      timeout     = "2m"
    }
  }

}