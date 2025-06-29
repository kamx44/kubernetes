resource "proxmox_vm_qemu" "cloned_vm"{
    
    name        = var.vm_name
    target_node = "pve"
    
    vmid = var.vm_id
    ### or for a Clone VM operation
    clone = var.clone_name
    full_clone = true
    cores = var.cores
    memory = var.memory
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
        macaddr = var.network.mac_address
    }

    sshkeys = var.authentications.public_key
    ciuser = var.authentications.vm_user
    cipassword = var.authentications.vm_password
    ciupgrade = true

    nameserver = var.network.nameserver
    ipconfig0= "ip=${var.network.ip_cidr},gw=${var.network.gateway}"
    define_connection_info = true

}




resource "time_sleep" "wait_1_minute-master" {
  depends_on = [proxmox_vm_qemu.cloned_vm]

  create_duration = "60s"
}

resource "null_resource" "install-agent-master"{

  provisioner "remote-exec" {
    inline = [
      "sudo apt update",
      "sleep 30",
      "sudo apt-get install qemu-guest-agent -y",
      "sudo systemctl start qemu-guest-agent",
      "sudo systemctl enable qemu-guest-agent",
      "sudo systemctl status qemu-guest-agent"
    ]

    connection {
      type        = "ssh"
      user        = var.authentications.vm_user
      host        = proxmox_vm_qemu.cloned_vm.ssh_host
      private_key = file(var.authentications.private_key_location)
      port        = 22
      timeout     = "2m"
    }
  }

  depends_on = [ 
    time_sleep.wait_1_minute-master
   ]
}


resource "null_resource" "init-node-master"{
  count = var.init_kuberentes ? 1 : 0

  provisioner "file" {
    source      = "${path.module}\\scripts\\init_node.sh"
    destination = "/tmp/init_node.sh"

     connection {
      type        = "ssh"
      user        = var.authentications.vm_user
      host        = proxmox_vm_qemu.cloned_vm.ssh_host
      private_key = file(var.authentications.private_key_location)
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
      user        = var.authentications.vm_user
      host        = proxmox_vm_qemu.cloned_vm.ssh_host
      private_key = file(var.authentications.private_key_location)
      port        = 22
      timeout     = "2m"
    }
  }

  depends_on = [ 
    null_resource.install-agent-master
   ]
}