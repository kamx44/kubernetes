variable "vm_name" {
  type = string
}

variable "vm_id" {
  type = number
}

variable "clone_name" {
  type = string
}

variable "cores" {
  type = number
}

variable "memory" {
  type = number
}

variable "network" {
  type = object({
    ip_cidr = string
    mac_address = string
    nameserver = string
    gateway = string
  })
}

variable "authentications" {
  type = object({
    public_key = string
    vm_user = string
    vm_password = string
    private_key_location = string
  })
}