terraform {
  required_providers {
    proxmox = {
      source = "Telmate/proxmox"
      version = "3.0.1-rc6"
    }
    external = {}
  }
}

provider "proxmox" {

   pm_tls_insecure = true
   pm_parallel = 20

}