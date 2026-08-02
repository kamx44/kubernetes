terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = ">= 0.66.0"
    }
  }
}

provider "proxmox" {
  # bpg expects the base URL WITHOUT the /api2/json suffix. replace() keeps the
  # existing tfvars (which may still carry the old suffix) working either way.
  endpoint = replace(var.pm_api_url, "/api2/json", "")

  # bpg takes the API token as a single "user@realm!tokenid=secret" string.
  api_token = "${var.pm_api_token_id}=${var.pm_api_token_secret}"

  insecure = true

  # An SSH block is only required for operations that touch the node's
  # filesystem directly (snippet uploads, disk imports, idmap). This config
  # only clones + cloud-inits via the API, so it is left commented out.
  # Uncomment and point at a PAM user on the Proxmox node if you add those.
  #
  # ssh {
  #   agent       = false
  #   username    = "root"
  #   private_key = file(var.private_key_location)
  # }
}
