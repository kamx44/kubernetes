locals {
  # Single control-plane node. Bare IPs (no CIDR) so they can be reused directly
  # as provisioner SSH targets; the /24 is appended in the ip_config blocks.
  master = {
    vm_id       = 110
    ip_address  = "192.168.137.20"
    mac_address = "bc:24:11:2b:41:01"
  }

  workers = {
    "worker" = {
      vm_id       = 120
      ip_address  = "192.168.137.26"
      mac_address = "bc:24:11:2b:41:09"
    }
  }

  gateway            = "192.168.137.1"
  nameserver         = "192.168.137.1"
  join_command_local = "C:\\Users\\Kamil\\.ssh\\join_command.sh"
}

######## MASTER / CONTROL PLANE ##############

resource "proxmox_virtual_environment_vm" "master" {
  name      = "k8s-vm-master"
  node_name = var.node_name
  vm_id     = local.master.vm_id
  on_boot   = true
  started   = true

  clone {
    vm_id = var.template_vm_id
    full  = true
  }

  # Guest agent is installed post-boot by the install-agent-master provisioner,
  # so it must stay disabled here or the clone would block waiting for it.
  agent {
    enabled = false
  }

  cpu {
    cores = 2
    type  = "x86-64-v2-AES"
  }

  memory {
    dedicated = 2048
  }

  scsi_hardware = "virtio-scsi-pci"

  serial_device {
    device = "socket"
  }

  disk {
    datastore_id = "local-lvm"
    interface    = "scsi0"
    size         = 32
    discard      = "on"
    ssd          = true
  }

  network_device {
    bridge      = "vmbr0"
    model       = "virtio"
    mac_address = local.master.mac_address
    firewall    = false
  }

  operating_system {
    type = "l26"
  }

  initialization {
    datastore_id = "local-lvm"

    dns {
      servers = [local.nameserver]
    }

    ip_config {
      ipv4 {
        address = "${local.master.ip_address}/24"
        gateway = local.gateway
      }
    }

    user_account {
      username = var.vm_user
      password = var.vm_password
      keys     = [trimspace(var.public_key)]
    }
  }
}

output "host-master" {
  value = local.master.ip_address
}

resource "time_sleep" "wait_1_minute-master" {
  depends_on      = [proxmox_virtual_environment_vm.master]
  create_duration = "60s"
}

resource "null_resource" "install-agent-master" {
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
      host        = local.master.ip_address
      private_key = file(var.private_key_location)
      port        = 22
      timeout     = "2m"
    }
  }

  depends_on = [time_sleep.wait_1_minute-master]
}

resource "null_resource" "init-node-master" {
  provisioner "file" {
    source      = "scripts\\init_node.sh"
    destination = "/tmp/init_node.sh"

    connection {
      type        = "ssh"
      user        = var.vm_user
      host        = local.master.ip_address
      private_key = file(var.private_key_location)
      port        = 22
      timeout     = "2m"
    }
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/init_node.sh",
      "/tmp/init_node.sh args",
    ]

    connection {
      type        = "ssh"
      user        = var.vm_user
      host        = local.master.ip_address
      private_key = file(var.private_key_location)
      port        = 22
      timeout     = "2m"
    }
  }

  depends_on = [null_resource.install-agent-master]
}

resource "null_resource" "kubeadm-init" {
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
      host        = local.master.ip_address
      private_key = file(var.private_key_location)
      port        = 22
      timeout     = "2m"
    }
  }

  depends_on = [null_resource.init-node-master]
}

resource "null_resource" "generate-token" {
  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      user        = var.vm_user
      host        = local.master.ip_address
      private_key = file(var.private_key_location)
      port        = 22
      timeout     = "2m"
    }

    inline = [
      "sudo kubeadm token create --print-join-command > /tmp/join_command.sh"
    ]
  }

  depends_on = [null_resource.kubeadm-init]
}

resource "null_resource" "get_token" {
  provisioner "local-exec" {
    interpreter = ["PowerShell", "-Command"]
    command     = "ssh -i ${var.private_key_location} ${var.vm_user}@${local.master.ip_address} -o StrictHostKeyChecking=no 'cat /tmp/join_command.sh' > ${local.join_command_local}"
  }

  depends_on = [null_resource.generate-token]
}

resource "time_sleep" "wait_for_master" {
  depends_on      = [null_resource.get_token]
  create_duration = "60s"
}

# ######## WORKER(S) ##############

# resource "proxmox_virtual_environment_vm" "worker" {
#   for_each = local.workers

#   name      = "k8s-vm-${each.key}"
#   node_name = var.node_name
#   vm_id     = each.value.vm_id
#   on_boot   = true
#   started   = true

#   clone {
#     vm_id = var.template_vm_id
#     full  = true
#   }

#   agent {
#     enabled = false
#   }

#   cpu {
#     cores = 2
#     type  = "x86-64-v2-AES"
#   }

#   memory {
#     dedicated = 2048
#   }

#   scsi_hardware = "virtio-scsi-pci"

#   serial_device {
#     device = "socket"
#   }

#   disk {
#     datastore_id = "local-lvm"
#     interface    = "scsi0"
#     size         = 32
#     discard      = "on"
#     ssd          = true
#   }

#   network_device {
#     bridge      = "vmbr0"
#     model       = "virtio"
#     mac_address = each.value.mac_address
#     firewall    = false
#   }

#   operating_system {
#     type = "l26"
#   }

#   initialization {
#     datastore_id = "local-lvm"

#     dns {
#       servers = [local.nameserver]
#     }

#     ip_config {
#       ipv4 {
#         address = "${each.value.ip_address}/24"
#         gateway = local.gateway
#       }
#     }

#     user_account {
#       username = var.vm_user
#       password = var.vm_password
#       keys     = [trimspace(var.public_key)]
#     }
#   }

#   depends_on = [time_sleep.wait_for_master]
# }

# output "host-worker" {
#   value = { for k, v in local.workers : k => v.ip_address }
# }

# resource "time_sleep" "wait_1_minute" {
#   depends_on      = [proxmox_virtual_environment_vm.worker]
#   create_duration = "60s"
# }

# resource "null_resource" "install-agent" {
#   for_each = local.workers

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
#       host        = each.value.ip_address
#       private_key = file(var.private_key_location)
#       port        = 22
#       timeout     = "2m"
#     }
#   }

#   depends_on = [time_sleep.wait_1_minute]
# }

# resource "null_resource" "init-node" {
#   for_each = local.workers

#   provisioner "file" {
#     source      = "scripts\\init_node.sh"
#     destination = "/tmp/init_node.sh"

#     connection {
#       type        = "ssh"
#       user        = var.vm_user
#       host        = each.value.ip_address
#       private_key = file(var.private_key_location)
#       port        = 22
#       timeout     = "2m"
#     }
#   }

#   provisioner "remote-exec" {
#     inline = [
#       "chmod +x /tmp/init_node.sh",
#       "dos2unix /tmp/init_node.sh",
#       "/tmp/init_node.sh args",
#     ]

#     connection {
#       type        = "ssh"
#       user        = var.vm_user
#       host        = each.value.ip_address
#       private_key = file(var.private_key_location)
#       port        = 22
#       timeout     = "2m"
#     }
#   }

#   depends_on = [null_resource.install-agent]
# }

# resource "null_resource" "join_worker" {
#   for_each = local.workers

#   provisioner "file" {
#     source      = local.join_command_local
#     destination = "/tmp/join_command.sh"

#     connection {
#       type        = "ssh"
#       user        = var.vm_user
#       host        = each.value.ip_address
#       private_key = file(var.private_key_location)
#       port        = 22
#       timeout     = "2m"
#     }
#   }

#   provisioner "remote-exec" {
#     inline = [
#       "chmod +x /tmp/join_command.sh",
#       "dos2unix /tmp/join_command.sh",
#       "sudo /tmp/join_command.sh",
#     ]

#     connection {
#       type        = "ssh"
#       user        = var.vm_user
#       host        = each.value.ip_address
#       private_key = file(var.private_key_location)
#       port        = 22
#       timeout     = "2m"
#     }
#   }

#   depends_on = [null_resource.init-node]
# }
