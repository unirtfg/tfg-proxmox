variable "pve_endpoint" {
  description = "Endpoint de la API de Proxmox"
  type        = string
  default     = "https://192.168.2.111:8006/"
}

variable "pve_api_token" {
  description = "API token de Proxmox (usuario@realm!tokenid=secret)"
  type        = string
  sensitive   = true
}

variable "pve_insecure" {
  description = "Aceptar certificado autofirmado"
  type        = bool
  default     = true
}

variable "template_node" {
  description = "Nodo donde se descarga la imagen cloud"
  type        = string
  default     = "proxmox1"
}

variable "gateway" {
  description = "Puerta de enlace de la red de VMs (vmbr0)"
  type        = string
  default     = "192.168.2.1"
}

variable "dns_server" {
  description = "DNS para las VMs (AdGuard en la VM de seguridad)"
  type        = string
  default     = "192.168.2.100"
}

variable "ci_user" {
  description = "Usuario cloud-init"
  type        = string
  default     = "sysadmin"
}

variable "ci_password" {
  description = "Contraseña cloud-init"
  type        = string
  sensitive   = true
}

variable "ssh_public_key" {
  description = "Clave pública SSH para acceso a las VMs"
  type        = string
}

variable "vms" {
  description = "Definición de las 4 VMs Debian del clúster"
  type = map(object({
    name   = string
    node   = string
    ip     = string
    cores  = number
    memory = number
    disk   = number
  }))
  default = {
    101 = { name = "vm-seguridad", node = "proxmox1", ip = "192.168.2.100", cores = 2, memory = 4096, disk = 32 }
    102 = { name = "vm-monitorizacion", node = "proxmox2", ip = "192.168.2.102", cores = 4, memory = 8192, disk = 48 }
    103 = { name = "vm-productividad", node = "proxmox2", ip = "192.168.2.103", cores = 4, memory = 6144, disk = 64 }
    104 = { name = "vm-aplicaciones", node = "proxmox3", ip = "192.168.2.104", cores = 4, memory = 8192, disk = 32 }
  }
}
