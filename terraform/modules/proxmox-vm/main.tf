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
  }

  cpu {
    cores = var.cores
    type  = "x86-64-v2-AES"
  }

  memory {
    dedicated = var.memory
  }

  disk {
    datastore_id = var.storage
    file_format  = "raw"
    interface    = "scsi0"
    size         = var.disk_gb
  }

  network_device {
    bridge = var.network_bridge
    model  = "virtio"
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
