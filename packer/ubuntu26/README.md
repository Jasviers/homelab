# Ubuntu 26 Packer template

Plantilla Packer para generar un template de Proxmox con Ubuntu 26 (live-server).

Uso y variables: ver `variables.pkr.hcl` dentro de esta carpeta.

Build rápido:

```bash
cd packer/ubuntu26

# Descargar y verificar checksum de la ISO
wget -qO- https://releases.ubuntu.com/26.04/SHA256SUMS | grep ubuntu-26.04-live-server-amd64.iso
# Copia el hash de la línea anterior y úsalo en ubuntu_iso_checksum

openssl passwd -6 <PASSWORD>
packer build -var 'proxmox_url=https://192.168.x.x:8006/api2/json' \
  -var 'proxmox_username=root@pam!template-token' \
  -var 'proxmox_token=<TOKEN>' \
  -var 'proxmox_node=<NODE_NAME>' \
  -var 'ubuntu_iso_checksum=sha256:<HASH_DESDE_SHA256SUMS>' \
  -var 'ssh_private_key_file=/home/jasviers/.ssh/id_ed25519' \
  -var 'boot_iso_storage_pool=local' \
  -var 'boot_iso_download_pve=true' \
  -var 'ssh_public_key_file=/home/jasviers/.ssh/id_ed25519.pub' \
  -var 'identity_password_hash=<PASSWORD_HASH>' \
  .
```

## Autoinstall (`autoinstall/user-data.tpl`)

Plantilla `cloud-config`/`autoinstall` que Packer sirve por HTTP durante el boot del instalador live-server (variables `${vm_name}`, `${ssh_username}`, `${identity_password_hash}` y `${ssh_public_key}` interpoladas desde `variables.pkr.hcl`):

- **Locale/teclado**: `es_ES.UTF-8` / distribución `es`.
- **SSH solo por clave pública** (`allow-pw: false`): el login por contraseña queda deshabilitado desde el primer arranque; solo entra la clave de `ssh_public_key_file`. `identity.password` (el hash) solo sirve para `sudo`/consola local, no para SSH.
- **Paquetes horneados en el template**: `qemu-guest-agent` (necesario para que Proxmox reporte IP/estado de la VM y para *graceful shutdown*) y `cloud-init` (lo reconfigura después el rol `cloud-init` de Ansible antes de convertir la VM en template).
- **`late-commands`**: da sudo sin contraseña al usuario de build (`/etc/sudoers.d/${ssh_username}`, `NOPASSWD:ALL`) y habilita `qemu-guest-agent` como servicio. El sudo sin contraseña es aceptable aquí porque el acceso ya está restringido por clave SSH y esta VM se convierte en template inmutable, no en un host de producción de uso diario.

## Referencias

- [https://github.com/ajschroeder/proxmox-packer-examples](https://github.com/ajschroeder/proxmox-packer-examples)
- [https://devlog.brittg.com/posts/homelab-part-1-proxmox/](https://devlog.brittg.com/posts/homelab-part-1-proxmox/)
