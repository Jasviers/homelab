output "vm_ids" {
  value       = { for name, vm in module.vm : name => vm.vm_id }
  description = "VMIDs asignados por nodo."
}

output "vm_names" {
  value       = { for name, vm in module.vm : name => vm.vm_name }
  description = "Nombres de las VMs por nodo."
}

output "ipv4_addresses" {
  value       = { for name, vm in module.vm : name => vm.ipv4_addresses }
  description = "IP config aplicada por nodo."
}
