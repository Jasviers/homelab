# Ansible

Playbooks y roles para configurar las VMs del homelab y dar soporte al build de Packer.

## Inventario

Definido en `inventory.ini`:

| Grupo | Hosts | Descripción |
| --- | --- | --- |
| `homelab` | `luffy`, `zoro`, `nami` | Hosts físicos (Raspberry Pi y nodos Proxmox) |
| `proxmox` | `zoro`, `nami` | Nodos Proxmox |
| `raspberry_pi` | `luffy` | Raspberry Pi 4B |
| `k8s_cluster` | `192.168.1.21`, `192.168.1.22` | VMs Ubuntu 26 donde se instala k3s |

La conexión usa `root` con la clave SSH `~/.ssh/id_ed25519` (ver `[homelab:vars]`).

## Playbooks

| Playbook | Descripción |
| --- | --- |
| `playbooks/update-ubuntu.yml` | Actualiza paquetes apt (update, dist-upgrade, autoremove). |
| `playbooks/install-k3s.yml` | Instala k3s en el grupo objetivo: inicializa el primer nodo con `--cluster-init`, recupera el token y une el resto de nodos. Deshabilita `servicelb`, `traefik` y `local-storage` (se sustituyen por MetalLB y el CSI de Synology). Al final descarga el kubeconfig a `~/.kube/config` y reescribe la URL del server. |
| `playbooks/uninstall-k3s.yml` | Para el servicio, ejecuta el script oficial de desinstalación y limpia directorios residuales. |
| `playbooks/packer-template.yml` | Lo invoca Packer como provisioner durante el build del template: actualiza paquetes y prepara cloud-init (rol `cloud-init`). No está pensado para ejecutarse a mano. |

## Roles

| Rol | Descripción |
| --- | --- |
| `update-packages` | Actualización de paquetes apt. |
| `install-k3s` | Instalación de k3s multi-nodo (server con etcd embebido). |
| `uninstall-k3s` | Desinstalación y limpieza de k3s. |
| `cloud-init` | Preparación del template de Proxmox: instala paquetes base, resetea `machine-id`, limpia configuración del instalador y deja cloud-init listo (`datasource_list: [NoCloud, ConfigDrive]`, `cloud-init clean`). |

## Uso

```bash
cd ansible

# Actualizar todos los hosts físicos
ansible-playbook playbooks/update-ubuntu.yml -l homelab

# Instalar k3s en las VMs
ansible-playbook playbooks/install-k3s.yml

# Desinstalar k3s
ansible-playbook playbooks/uninstall-k3s.yml
```

