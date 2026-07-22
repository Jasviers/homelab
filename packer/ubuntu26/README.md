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

## Referencias

- [https://github.com/ajschroeder/proxmox-packer-examples](https://github.com/ajschroeder/proxmox-packer-examples)
- [https://devlog.brittg.com/posts/homelab-part-1-proxmox/](https://devlog.brittg.com/posts/homelab-part-1-proxmox/)
