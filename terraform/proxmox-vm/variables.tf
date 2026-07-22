variable "proxmox_endpoint" {
  type        = string
  description = "URL de la API de Proxmox (ej: https://192.168.1.3:8006/)."
  validation {
    condition     = can(regex("^https?://", var.proxmox_endpoint))
    error_message = "proxmox_endpoint debe empezar por http:// o https://."
  }
}

variable "proxmox_api_token" {
  type        = string
  description = "Token de la API de Proxmox (formato USER@REALM!TOKENID=UUID)."
  sensitive   = true
  validation {
    condition     = length(trimspace(var.proxmox_api_token)) > 0
    error_message = "proxmox_api_token no puede estar vacío."
  }
}

variable "proxmox_insecure" {
  type        = bool
  description = "Permitir TLS inseguro."
  default     = true
}

variable "vms" {
  type = map(object({
    vm_name     = string
    target_node = string
    vm_id       = optional(number)
    ipv4_cidr   = string
    description = optional(string)
    cores       = optional(number)
    memory      = optional(number)
    disk_gb     = optional(number)
    storage     = optional(string)
  }))
  description = "Definiciones de las VMs que se desplegarán por defecto. cores/memory/disk_gb/storage son overrides opcionales por VM; si se omiten, se usan los globales del mismo nombre."
}

variable "template" {
  type        = string
  description = "Nombre de template de Ubuntu 26 para clonar."
  validation {
    condition     = length(trimspace(var.template)) > 0
    error_message = "template no puede estar vacío."
  }
}

variable "vm_id" {
  type        = number
  description = "VMID opcional (null para auto)."
  default     = null
}

variable "cores" {
  type        = number
  description = "Número de cores."
  default     = 2
  validation {
    condition     = var.cores >= 1
    error_message = "cores debe ser >= 1."
  }
}

variable "memory" {
  type        = number
  description = "Memoria en MB."
  default     = 2048
  validation {
    condition     = var.memory >= 512
    error_message = "memory debe ser >= 512 MB."
  }
}

variable "disk_gb" {
  type        = number
  description = "Disco en GB."
  default     = 20
  validation {
    condition     = var.disk_gb >= 10
    error_message = "disk_gb debe ser >= 10."
  }
}

variable "storage" {
  type        = string
  description = "Storage de Proxmox para el disco."
  validation {
    condition     = length(trimspace(var.storage)) > 0
    error_message = "storage no puede estar vacío."
  }
}

variable "network_bridge" {
  type        = string
  description = "Bridge de red (ej: vmbr0)."
  default     = "vmbr0"
}

variable "ipv4_gateway" {
  type        = string
  description = "IP del Gateway."
}

variable "ssh_keys" {
  type        = list(string)
  description = "Lista de claves públicas SSH."
  default     = []
}

variable "ciuser" {
  type        = string
  description = "Usuario de Cloud Init."
  default     = "ubuntu"
}

variable "cipassword" {
  type        = string
  description = "Password de Cloud Init (opcional)."
  default     = null
  sensitive   = true
}

variable "tags" {
  type        = string
  description = "Tags de la VM."
  default     = ""
}

variable "description" {
  type        = string
  description = "Descripción."
  default     = ""
}
