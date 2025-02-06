resource "proxmox_vm_qemu" "clone_vm"{
    
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
        macaddr = each.value.mac_address
    }

    sshkeys = var.public_key
    ciuser = var.vm_user
    cipassword = var.vm_password
    ciupgrade = true

    nameserver = "192.168.137.1"
    ipconfig0= "ip=${each.value.ip},gw=192.168.137.1"
    define_connection_info = true

}


output "host-master" {
  value =  proxmox_vm_qemu.test-vm-master["master"].ssh_host
}

resource "time_sleep" "wait_1_minute-master" {
  depends_on = [proxmox_vm_qemu.test-vm-master]

  create_duration = "60s"
}

resource "null_resource" "install-agent-master"{

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
      host        = proxmox_vm_qemu.test-vm-master["master"].ssh_host
      private_key = file(var.private_key_location)
      port        = 22
      timeout     = "2m"
    }
  }

  depends_on = [ 
    time_sleep.wait_1_minute-master
   ]
}


resource "null_resource" "init-node-master"{

  provisioner "file" {
    source      = "scripts\\init_node.sh"
    destination = "/tmp/init_node.sh"

     connection {
      type        = "ssh"
      user        = var.vm_user
      host        = proxmox_vm_qemu.test-vm-master["master"].ssh_host
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
      host        = proxmox_vm_qemu.test-vm-master["master"].ssh_host
      private_key = file(var.private_key_location)
      port        = 22
      timeout     = "2m"
    }
  }

  depends_on = [ 
    null_resource.install-agent-master
   ]
}