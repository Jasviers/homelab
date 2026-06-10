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
    ssh_quiet_keygen: true
    allow_public_ssh_keys: true
    authorized-keys:
      - ${ssh_public_key}
  package_update: true
  package_upgrade: true
  packages:
    - qemu-guest-agent
    - cloud-init
  late-commands:
    - curtin in-target -- sh -c "printf '%s ALL=(ALL) NOPASSWD:ALL\n' '${ssh_username}' > /etc/sudoers.d/${ssh_username}"
    - curtin in-target -- chmod 440 /etc/sudoers.d/${ssh_username}
    - curtin in-target -- systemctl enable qemu-guest-agent