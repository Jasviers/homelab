data "proxmox_virtual_environment_vms" "template" {
  node_name = var.target_node

  filter {
    name   = "name"
    values = [var.template]
  }
}

resource "proxmox_virtual_environment_vm" "vm" {
  name        = var.vm_name
  node_name   = var.target_node
  vm_id       = var.vm_id
  description = var.description
  tags        = var.tags != "" ? split(",", var.tags) : []

  clone {
    vm_id = data.proxmox_virtual_environment_vms.template.vms[0].vm_id
    full  = true
  }

  agent {
    enabled = true
    trim    = true
  }

  on_boot = var.on_boot

  cpu {
    cores = var.cores
    type  = var.cpu_type
    numa  = true
  }

  memory {
    dedicated = var.memory
    floating  = coalesce(var.memory_floating, var.memory)
  }

  disk {
    datastore_id = var.storage
    file_format  = "raw"
    interface    = "virtio0"
    size         = var.disk_gb
    discard      = "on"
    iothread     = true
  }

  network_device {
    bridge = var.network_bridge
    model  = "virtio"
  }

  dynamic "startup" {
    for_each = var.startup_order != null ? [1] : []
    content {
      order    = var.startup_order
      up_delay = var.startup_up_delay
    }
  }

  initialization {
    ip_config {
      ipv4 {
        address = var.ipv4_cidr
        gateway = var.ipv4_gateway
      }
    }
    user_account {
      username = var.ciuser
      password = var.cipassword
      keys     = var.ssh_keys
    }
  }
}
