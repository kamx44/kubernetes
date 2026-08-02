variable "public_key" {
  type      = string
  sensitive = true
}

variable "private_key_location" {
  type = string
}

variable "vm_user" {
  type = string
}

variable "vm_password" {
  type      = string
  sensitive = true
}

# Proxmox node the VMs are created on (bpg's node_name).
variable "node_name" {
  type    = string
  default = "pve"
}

# Numeric VM ID of the cloud-init template to clone. bpg clones by ID, not by
# name (the old Telmate config used clone = "ubuntu-2404-cloudinit-template").
variable "template_vm_id" {
  type = number
}

# Proxmox API endpoint. May include the /api2/json suffix; provider.tf strips it.
variable "pm_api_url" {
  type = string
}

# API token id, e.g. "terraform@pam!terraform".
variable "pm_api_token_id" {
  type = string
}

# API token secret (the UUID).
variable "pm_api_token_secret" {
  type      = string
  sensitive = true
}
