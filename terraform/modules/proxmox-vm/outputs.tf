output "vm_id" {
  value       = proxmox_virtual_environment_vm.vm.vm_id
  description = "VMID asignado en Proxmox."
}

output "vm_name" {
  value       = proxmox_virtual_environment_vm.vm.name
  description = "Nombre de la VM."
}

output "ipv4_addresses" {
  value       = proxmox_virtual_environment_vm.vm.ipv4_addresses
  description = "Configuración IPv4 administrada."
}
