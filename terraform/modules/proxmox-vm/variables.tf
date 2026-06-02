variable "vm_name" {
  type        = string
  description = "Nombre de la VM en Proxmox."
  validation {
    condition     = length(trimspace(var.vm_name)) > 0
    error_message = "vm_name no puede estar vacío."
  }
}

variable "target_node" {
  type        = string
  description = "Nodo Proxmox donde se desplegará la VM."
  validation {
    condition     = length(trimspace(var.target_node)) > 0
    error_message = "target_node no puede estar vacío."
  }
}

variable "template" {
  type        = string
  description = "Nombre del template de Proxmox para clonar."
  validation {
    condition     = length(trimspace(var.template)) > 0
    error_message = "template no puede estar vacío."
  }
}

variable "vm_id" {
  type        = number
  description = "VMID opcional. Si es null, Proxmox asigna automáticamente."
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
  description = "Tamaño del disco en GB."
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

variable "ipv4_cidr" {
  type        = string
  description = "IPv4 con CIDR (ej: 192.168.1.10/23)."
  validation {
    condition     = can(regex("^\\d{1,3}(\\.\\d{1,3}){3}\\/\\d{1,2}$", var.ipv4_cidr))
    error_message = "ipv4_cidr debe tener formato CIDR, por ejemplo 192.168.1.10/23."
  }
}

variable "ipv4_gateway" {
  type        = string
  description = "Gateway IPv4 (ej: 192.168.0.1)."
  validation {
    condition     = can(regex("^\\d{1,3}(\\.\\d{1,3}){3}$", var.ipv4_gateway))
    error_message = "ipv4_gateway debe ser una IP válida (ej: 192.168.0.1)."
  }
}

variable "ciuser" {
  type        = string
  description = "Usuario cloud-init."
  default     = "ubuntu"
}

variable "cipassword" {
  type        = string
  description = "Password cloud-init (puede ser null si usas solo sshkeys)."
  default     = null
  sensitive   = true
}

variable "ssh_keys" {
  type        = list(string)
  description = "Lista de claves SSH públicas."
  default     = []
  validation {
    condition     = length(var.ssh_keys) == 0 || alltrue([for key in var.ssh_keys : length(trimspace(key)) > 0])
    error_message = "ssh_keys no puede contener entradas vacías."
  }
}

variable "tags" {
  type        = string
  description = "Tags de Proxmox (separados por coma si aplica)."
  default     = ""
}

variable "description" {
  type        = string
  description = "Descripción de la VM."
  default     = ""
}
