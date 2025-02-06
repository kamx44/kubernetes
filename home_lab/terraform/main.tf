locals {
    vms = {
    "worker" = {
      vmid = 120
      ip = "192.168.137.26/24"
      mac_address = "bc:24:11:2b:41:09"
    }
    }
  k8s_vms = {
    "master" = {
      vmid = 110
      ip = "192.168.137.20/24"
      mac_address = "bc:24:11:2b:41:01"
    }
  }
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
    ip_cidr = "192.168.137.20/24"
    mac_address = "bc:24:11:2b:41:01"
    nameserver =  "192.168.137.1"
    gateway =  "192.168.137.1"
  }
  authentications = {
    public_key = var.public_key
    vm_user = var.vm_user
    vm_password = var.vm_password
    private_key_location = var.private_key_location
  }
}

# resource "proxmox_vm_qemu" "test-vm-master"{
#     for_each = local.k8s_vms
#     name        = "k8s-vm-${each.key}"
#     target_node = "pve"
    
#     vmid = each.value.vmid
#     ### or for a Clone VM operation
#     clone = "ubuntu-24-template"
#     full_clone = true
#     cores = 2
#     memory = 2048
#     agent = 1
#     onboot = true


#     serial {
#         type = "socket"
#         id = 0
#     }

#     scsihw = "virtio-scsi-pci"
#     disks {
#       ide {
#         ide0{
#           cloudinit{
#             storage="local-lvm"
#           }
#         }

#         ide2 {
#           cdrom {
#               passthrough = false
#           }
#         }
#       }
      

#       scsi{
#         scsi0{
#           disk{
#             storage="local-lvm"
#             size="32G"
#             discard=true
#             emulatessd = true
#             replicate = true
#           }
#         }
#       }
#     }

#     network {
#         model = "virtio"
#         bridge = "vmbr0"
#         firewall = false
#         link_down = false
#         id = 0
#         macaddr = each.value.mac_address
#     }

#     sshkeys = var.public_key
#     ciuser = var.vm_user
#     cipassword = var.vm_password
#     ciupgrade = true

#     nameserver = "192.168.137.1"
#     ipconfig0= "ip=${each.value.ip},gw=192.168.137.1"
#     define_connection_info = true

# }


# output "host-master" {
#   value =  proxmox_vm_qemu.test-vm-master["master"].ssh_host
# }

# resource "time_sleep" "wait_1_minute-master" {
#   depends_on = [proxmox_vm_qemu.test-vm-master]

#   create_duration = "60s"
# }

# resource "null_resource" "install-agent-master"{

#   provisioner "remote-exec" {
#     inline = [
#       "sudo apt update",
#       "sudo apt-get install qemu-guest-agent -y",
#       "sudo systemctl start qemu-guest-agent",
#       "sudo systemctl enable qemu-guest-agent",
#       "sudo systemctl status qemu-guest-agent"
#     ]

#     connection {
#       type        = "ssh"
#       user        = var.vm_user
#       host        = proxmox_vm_qemu.test-vm-master["master"].ssh_host
#       private_key = file(var.private_key_location)
#       port        = 22
#       timeout     = "2m"
#     }
#   }

#   depends_on = [ 
#     time_sleep.wait_1_minute-master
#    ]
# }


# resource "null_resource" "init-node-master"{

#   provisioner "file" {
#     source      = "scripts\\init_node.sh"
#     destination = "/tmp/init_node.sh"

#      connection {
#       type        = "ssh"
#       user        = var.vm_user
#       host        = proxmox_vm_qemu.test-vm-master["master"].ssh_host
#       private_key = file(var.private_key_location)
#       port        = 22
#       timeout     = "2m"
#     }
#   }

#   provisioner "remote-exec" {
    
#     inline = [
#       "chmod +x /tmp/init_node.sh",
#       "/tmp/init_node.sh args",
#     ]
  
#     connection {
#       type        = "ssh"
#       user        = var.vm_user
#       host        = proxmox_vm_qemu.test-vm-master["master"].ssh_host
#       private_key = file(var.private_key_location)
#       port        = 22
#       timeout     = "2m"
#     }
#   }

#   depends_on = [ 
#     null_resource.install-agent-master
#    ]
# }

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


######## WORKER ##############

resource "proxmox_vm_qemu" "test-vm"{
    for_each = local.vms
    name        = "k8s-vm-${each.key}"
    target_node = "pve"
    
    vmid = each.value.vmid
    ### or for a Clone VM operation
    clone = "ubuntu-24-template"
    full_clone = true
    cores = 2
    memory = 2048
    agent = 1
    onboot = true

    serial {
        type = "socket"
        id = 0
    }

    scsihw = "virtio-scsi-pci"
    disks {
      ide {
        ide0{
          cloudinit{
            storage="local-lvm"
          }
        }

        ide2 {
          cdrom {
              passthrough = false
          }
        }
      }
      

      scsi{
        scsi0{
          disk{
            storage="local-lvm"
            size="32G"
            discard=true
            emulatessd = true
            replicate = true
            #afetr change
            # iothread = false
            # readonly = false
          }
        }
      }
    }

    network {
        model = "virtio"
        bridge = "vmbr0"
        firewall = false
        link_down = false
        id = 0
        macaddr = "bc:24:11:2b:41:09"
        #added after change
        # mtu = 0 
        # queues = 0
        # rate = 0
        # tag = 0
    }

    sshkeys = var.public_key
    ciuser = var.vm_user
    cipassword = var.vm_password
    ciupgrade = true
    #ipconfig0 = "ip=dhcp"
    #searchdomain = "."
    nameserver = "192.168.137.1"
    ipconfig0= "ip=${each.value.ip},gw=192.168.137.1"
    define_connection_info = true
    
    # os_type = "cloud-init"
    # preprovision   = true

  depends_on = [ 
    time_sleep.wait_for_master
   ]
    
}

output "host-worker" {
  value =  proxmox_vm_qemu.test-vm["worker"].ssh_host
}

resource "time_sleep" "wait_1_minute" {
  depends_on = [proxmox_vm_qemu.test-vm]

  create_duration = "60s"
}

resource "null_resource" "install-agent"{

  provisioner "remote-exec" {
    inline = [
      "sudo apt update",
      "sudo apt-get install qemu-guest-agent -y",
      "sudo systemctl start qemu-guest-agent",
      "sudo systemctl enable qemu-guest-agent",
      "sudo systemctl status qemu-guest-agent"
    ]

    connection {
      type        = "ssh"
      user        = var.vm_user
      host        = proxmox_vm_qemu.test-vm["worker"].ssh_host
      private_key = file(var.private_key_location)
      port        = 22
      timeout     = "2m"
    }
  }

  depends_on = [ 
    time_sleep.wait_1_minute
   ]
}


resource "null_resource" "init-node"{

  provisioner "file" {
    source      = "scripts\\init_node.sh"
    destination = "/tmp/init_node.sh"

     connection {
      type        = "ssh"
      user        = var.vm_user
      host        = proxmox_vm_qemu.test-vm["worker"].ssh_host
      private_key = file(var.private_key_location)
      port        = 22
      timeout     = "2m"
    }
  }

  provisioner "remote-exec" {
    
    inline = [
      "chmod +x /tmp/init_node.sh",
      "dos2unix /tmp/init_node.sh",
      "/tmp/init_node.sh args",
    ]
  
    connection {
      type        = "ssh"
      user        = var.vm_user
      host        = proxmox_vm_qemu.test-vm["worker"].ssh_host
      private_key = file(var.private_key_location)
      port        = 22
      timeout     = "2m"
    }
  }

  depends_on = [ 
    time_sleep.wait_1_minute,
    null_resource.install-agent
   ]
}


resource "null_resource" "join_worker"{

  provisioner "file" {
    source      = "C:\\Users\\Kamil\\.ssh\\join_command.sh"
    destination = "/tmp/join_command.sh"

     connection {
      type        = "ssh"
      user        = var.vm_user
      host        = proxmox_vm_qemu.test-vm["worker"].ssh_host
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
      host        = proxmox_vm_qemu.test-vm["worker"].ssh_host
      private_key = file(var.private_key_location)
      port        = 22
      timeout     = "2m"
    }
  }

  depends_on = [ 
    null_resource.init-node
   ]
}