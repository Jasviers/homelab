packer {
  required_version = ">= 1.10.0"

  required_plugins {
    proxmox = {
      source  = "github.com/hashicorp/proxmox"
      version = ">= 1.2.3"
    }
  }
}

locals {
  autoinstall_content = {
    "/meta-data" = file("./autoinstall/meta-data.tpl")
    "/user-data" = templatefile("./autoinstall/user-data.tpl", {
      vm_name                = var.vm_name
      ssh_username           = var.ssh_username
      identity_password_hash = var.identity_password_hash
      ssh_public_key         = file(var.ssh_public_key_file)
    })
  }
}

source "proxmox-iso" "ubuntu26" {
  proxmox_url              = var.proxmox_url
  insecure_skip_tls_verify = true
  username                 = var.proxmox_username
  token                    = var.proxmox_token
  node                     = var.proxmox_node

  efi_config {
    efi_storage_pool  = "local-lvm"
    efi_type          = "4m"
    pre_enrolled_keys = true
  }

  boot_iso {
    iso_url          = var.ubuntu_iso_url
    iso_checksum     = var.ubuntu_iso_checksum
    iso_storage_pool = var.boot_iso_storage_pool
    iso_download_pve = var.boot_iso_download_pve
    unmount          = true
  }


  additional_iso_files {
    cd_content       = local.autoinstall_content
    cd_label         = "cidata"
    iso_storage_pool = "local"
  }

  os                       = "l26"
  cores                    = var.cores
  sockets                  = var.sockets
  memory                   = var.memory

  network_adapters {
    bridge = var.network_bridge
    model  = "virtio"
  }

  disks {
    type         = "virtio"
    disk_size    = var.disk_size
    storage_pool = var.storage_pool
  }

  qemu_agent               = true

  cloud_init               = true
  cloud_init_storage_pool = var.storage_pool

  ssh_username             = var.ssh_username
  ssh_private_key_file     = var.ssh_private_key_file
  ssh_timeout              = var.ssh_timeout

  boot = "order=virtio0;ide2;net0"
  boot_wait                = "15s"
  boot_command = [
    "<wait3s>c<wait3s>",
    "linux /casper/vmlinuz --- autoinstall ds=nocloud",
    "<enter><wait>",
    "initrd /casper/initrd",
    "<enter><wait>",
    "boot",
    "<enter>"
  ]

  template_name            = var.template_name
  template_description     = var.template_description
  
  tags                    = var.template_tags
}

build {
  sources = ["source.proxmox-iso.ubuntu26"]
}
