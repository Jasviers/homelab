module "vm" {
  for_each = var.vms

  source = "git::git@github.com:Jasviers/homelab.git//terraform/modules/proxmox-vm?ref=v1.11.0"

  vm_name     = each.value.vm_name
  target_node = each.value.target_node
  template    = var.template
  vm_id       = each.value.vm_id

  cores   = var.cores
  memory  = var.memory
  disk_gb = var.disk_gb
  storage = var.storage

  network_bridge = var.network_bridge
  ipv4_cidr      = each.value.ipv4_cidr
  ipv4_gateway   = var.ipv4_gateway

  ciuser     = var.ciuser
  cipassword = var.cipassword
  ssh_keys   = var.ssh_keys

  tags        = var.tags
  description = coalesce(each.value.description, var.description)
}
