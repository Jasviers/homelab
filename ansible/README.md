# Ansible

Playbooks y roles para configurar las VMs del homelab y dar soporte al build de Packer.

## Inventario

Definido en `inventory.ini`:

| Grupo | Hosts | Descripción |
| --- | --- | --- |
| `homelab` | `luffy`, `zoro`, `nami` | Hosts físicos (Raspberry Pi y nodos Proxmox) |
| `proxmox` | `zoro`, `nami` | Nodos Proxmox |
| `raspberry_pi` | `luffy` | Raspberry Pi 4B |
| `k3s_control_plane` | `192.168.1.21`, `192.168.1.22` | VMs control-plane de k3s (server + etcd embebido), sin cargas de trabajo (taint `node-role.kubernetes.io/control-plane`) |
| `k3s_workers` | `192.168.1.30`, `192.168.1.31` | VMs worker de k3s (agent), sin taint |
| `k3s_ai` | `192.168.1.40` | VM worker de k3s (agent) para IA, taint `dedicated=ai` + label `workload-type=ai` |
| `k8s_cluster` | grupo padre de `k3s_control_plane` + `k3s_workers` + `k3s_ai` | Todas las VMs del clúster k3s |

La conexión usa `root` con la clave SSH `~/.ssh/id_ed25519` (ver `[homelab:vars]`).

## Playbooks

| Playbook | Descripción |
| --- | --- |
| `playbooks/proxmox-repos.yml` | Configura los repos `no-subscription` de Proxmox VE en los nodos `proxmox`. |
| `playbooks/qdevice.yml` | Importa `proxmox-repos` y monta el QDevice de quorum usando `luffy` como árbitro, para que un clúster Proxmox de 2 nodos mantenga quorum si cae uno. |
| `playbooks/update-ubuntu.yml` | Actualiza paquetes apt (update, dist-upgrade, autoremove). |
| `playbooks/install-k3s.yml` | Instala k3s con roles diferenciados: `k3s_control_plane` se instala como **server** con etcd embebido (el primero con `--cluster-init`, el resto se une con `--server`/`--token`), taggeado con el taint `node-role.kubernetes.io/control-plane=true:NoSchedule` para no recibir cargas; `k3s_workers` y `k3s_ai` se instalan como **agent** (worker), y `k3s_ai` añade además el taint `dedicated=ai:NoSchedule` y el label `workload-type=ai` para restringir qué se despliega ahí. Deshabilita `servicelb`, `traefik` y `local-storage` (el `LoadBalancer` lo da Cilium LB IPAM y el almacenamiento el CSI de Synology) y el networking integrado (`flannel`, `kube-proxy` y `network-policy`), que se sustituyen por **Cilium** (con LB IPAM, anuncios L2 y tolerations para correr también en los nodos tainted). Descarga el kubeconfig a `~/.kube/config`, reescribe la URL del server e instala Cilium vía Helm desde localhost. |
| `playbooks/uninstall-k3s.yml` | Para el servicio (`k3s` en control-plane, `k3s-agent` en workers/IA), ejecuta el script oficial de desinstalación correspondiente (`k3s-uninstall.sh` o `k3s-agent-uninstall.sh`) y limpia directorios residuales. |
| `playbooks/home-services.yml` | Despliega en `luffy` (vía Docker Compose) Pi-hole, Home Assistant y el asistente de voz (Whisper + Piper, protocolo Wyoming). Configura los `host-record` de DNS local. |
| `playbooks/packer-template.yml` | Lo invoca Packer como provisioner durante el build del template: actualiza paquetes y prepara cloud-init (rol `cloud-init`). No está pensado para ejecutarse a mano. |

## Roles

| Rol | Descripción |
| --- | --- |
| `proxmox-repos` | Configura los repos `no-subscription` de Proxmox VE (desactiva el repo enterprise). |
| `qdevice` | Instala y configura el QDevice de quorum (corosync-qnetd en `luffy`, cliente en los nodos Proxmox). |
| `update-packages` | Actualización de paquetes apt. |
| `install-docker` | Instala Docker Engine + Compose plugin (usado en `luffy` para los servicios del hogar). |
| `install-k3s` | Instalación de k3s con roles server (control-plane, etcd embebido, taint) y agent (workers/IA, uno de ellos tainted para IA), sin flannel ni kube-proxy + Cilium como CNI vía Helm (con cifrado pod-to-pod WireGuard y Hubble habilitados). Variables en `defaults/main.yml` (versión del chart, endpoint del API). |
| `uninstall-k3s` | Desinstalación y limpieza de k3s (server o agent según el grupo del host, incluye restos de red de Cilium). |
| `home-services` | Despliega el stack Docker Compose de `luffy` (Pi-hole, Home Assistant, Whisper, Piper) y los `host-record` de DNS local. Variables en `defaults/main.yml`. |
| `cloud-init` | Preparación del template de Proxmox: instala paquetes base, resetea `machine-id`, limpia configuración del instalador y deja cloud-init listo (`datasource_list: [NoCloud, ConfigDrive]`, `cloud-init clean`). |

## Uso

```bash
cd ansible

# Repos no-subscription + QDevice de quorum en Proxmox
ansible-playbook playbooks/qdevice.yml

# Actualizar todos los hosts físicos
ansible-playbook playbooks/update-ubuntu.yml -l homelab

# Instalar k3s en las VMs (incluye Cilium)
ansible-playbook playbooks/install-k3s.yml

# Desinstalar k3s
ansible-playbook playbooks/uninstall-k3s.yml

# Servicios del hogar en luffy (Pi-hole, Home Assistant, asistente de voz)
ansible-playbook playbooks/home-services.yml
```

