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
   pm_api_url = "https://<PROXMOX_IP>:8006/api2/json"
   pm_api_token_id = ""
   pm_api_token_secret = ""
   pm_tls_insecure = true
   pm_parallel = 20
}