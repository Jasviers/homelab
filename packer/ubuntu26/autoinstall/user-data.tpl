#cloud-config
autoinstall:
  version: 1
  refresh-installer:
  locale: es_ES.UTF-8
  keyboard:
    layout: es
  identity:
    hostname: ${vm_name}
    username: ${ssh_username}
    password: ${identity_password_hash}
  ssh:
    allow-pw: false
    install-server: true
    authorized-keys:
      - ${ssh_public_key}

  package_update: true
  package_upgrade: true
  packages:
    - qemu-guest-agent
    - cloud-init
