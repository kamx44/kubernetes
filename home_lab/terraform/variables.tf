variable "public_key" {
  type = string
  sensitive = true
}

variable "private_key_location" {
    type = string
}

variable "vm_user" {
    type = string
}

variable "vm_password" {
    type = string
    sensitive = true
}

# variable "kubernetes_vms" {
#     type = object({
#         master = object({
#           vmid = number
#           ip = string
#           mac_address = string
#         })
#         workers = map(object({
#           vmid = number
#           ip = string
#           mac_address = string
#         }))
#     })
# }