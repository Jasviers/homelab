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
| `k3s_workers` | `192.168.1.30`, `192.168.1.31`, `192.168.1.32` | VMs worker de k3s (agent), sin taint |
| `k3s_ai` | `192.168.1.40` | VM worker de k3s (agent) para IA, taint `dedicated=ai` + label `workload-type=ai` |
| `k8s_cluster` | grupo padre de `k3s_control_plane` + `k3s_workers` + `k3s_ai` | Todas las VMs del clúster k3s |

La conexión usa `root` con la clave SSH `~/.ssh/id_ed25519` (ver `[homelab:vars]`).

## Playbooks

| Playbook | Descripción |
| --- | --- |
| `playbooks/proxmox-repos.yml` | Configura los repos `no-subscription` de Proxmox VE en los nodos `proxmox`. |
| `playbooks/proxmox-config.yml` | Aplica `proxmox-repos` + `proxmox-tuning` sobre `proxmox`. Lo importa `playbooks/qdevice.yml`, así que normalmente no hace falta ejecutarlo suelto salvo que se quiera limitar a un nodo concreto con `-l` (p. ej. al reincorporar un nodo tras una migración de disco, antes de rehacer el quorum). |
| `playbooks/qdevice.yml` | Importa `proxmox-config.yml` (repos + tuning) y monta el QDevice de quorum usando `luffy` como árbitro, para que un clúster Proxmox de 2 nodos mantenga quorum si cae uno. |
| `playbooks/update-ubuntu.yml` | Actualiza paquetes apt (update, dist-upgrade, autoremove). |
| `playbooks/install-k3s.yml` | Instala k3s con roles diferenciados: `k3s_control_plane` se instala como **server** con etcd embebido (el primero con `--cluster-init`, el resto se une con `--server`/`--token`), taggeado con el taint `node-role.kubernetes.io/control-plane=true:NoSchedule` para no recibir cargas; `k3s_workers` y `k3s_ai` se instalan como **agent** (worker), y `k3s_ai` añade además el taint `dedicated=ai:NoSchedule` y el label `workload-type=ai` para restringir qué se despliega ahí. Deshabilita `servicelb`, `traefik` y `local-storage` (el `LoadBalancer` lo da Cilium LB IPAM y el almacenamiento el CSI de Synology) y el networking integrado (`flannel`, `kube-proxy` y `network-policy`), que se sustituyen por **Cilium** (con LB IPAM, anuncios L2 y tolerations para correr también en los nodos tainted). Descarga el kubeconfig a `~/.kube/config`, reescribe la URL del server e instala Cilium vía Helm desde localhost. |
| `playbooks/uninstall-k3s.yml` | Para el servicio (`k3s` en control-plane, `k3s-agent` en workers/IA), ejecuta el script oficial de desinstalación correspondiente (`k3s-uninstall.sh` o `k3s-agent-uninstall.sh`) y limpia directorios residuales. |
| `playbooks/home-services.yml` | Despliega en `luffy` (vía Docker Compose) Pi-hole, Home Assistant y Piper (TTS, protocolo Wyoming). Configura los `host-record` de DNS local. Whisper (STT) se trasladó al clúster k3s, ver `services/whisper/`. |
| `playbooks/packer-template.yml` | Lo invoca Packer como provisioner durante el build del template: actualiza paquetes, aplica el tuning de `vm.swappiness` (rol `vm-tuning`) y prepara cloud-init (rol `cloud-init`). No está pensado para ejecutarse a mano; no existe un playbook independiente para reaplicar `vm-tuning` contra VMs ya desplegadas — solo queda "horneado" en las plantillas nuevas. |

## Roles

| Rol | Descripción |
| --- | --- |
| `proxmox-repos` | Configura los repos `no-subscription` de Proxmox VE (desactiva el repo enterprise). |
| `proxmox-tuning` | Tuning del host Proxmox: fija el governor de CPU en `performance` (paquete `linux-cpupower` + unidad systemd propia que lo reaplica en cada arranque, porque `cpupower` no persiste el governor por sí solo), `vm.swappiness=10` y se asegura de que `ksmtuned` (ya viene instalado de fábrica en PVE) esté activo. Pensado para mini PCs que arrancan en `powersave`/`schedutil`; afecta a la latencia de etcd si no se aplica (ver `docs/postmortems/2026-07-27-etcd-fsync-kubevip-crashloop.md`). Variables en `defaults/main.yml`. |
| `qdevice` | Instala y configura el QDevice de quorum (corosync-qnetd en `luffy`, cliente en los nodos Proxmox). |
| `update-packages` | Actualización de paquetes apt. |
| `install-docker` | Instala Docker Engine + Compose plugin (usado en `luffy` para los servicios del hogar). |
| `install-k3s` | Instalación de k3s con roles server (control-plane, etcd embebido, taint) y agent (workers/IA, uno de ellos tainted para IA), sin flannel ni kube-proxy + Cilium como CNI vía Helm (con cifrado pod-to-pod WireGuard y Hubble habilitados). Variables en `defaults/main.yml` (versión del chart, endpoint del API). |
| `uninstall-k3s` | Desinstalación y limpieza de k3s (server o agent según el grupo del host, incluye restos de red de Cilium). |
| `home-services` | Despliega el stack Docker Compose de `luffy` (Pi-hole, Home Assistant, Piper) y los `host-record` de DNS local. En una instalación desde 0 siembra `configuration.yaml` de Home Assistant con `http.trusted_proxies` (necesario para aceptar el `X-Forwarded-For` que añade Cloudflare Tunnel; sin esto HA responde 400 Bad Request a las peticiones proxied). Variables en `defaults/main.yml`: `pihole_web_password` (contraseña de la UI, por defecto `"changeme"` — **rotarla** al desplegar, sobreescribiendo la variable en el inventario/vault, no en el propio `defaults/main.yml`); `home_services_dns_servers` (host-records para `luffy`/`zoro`/`nami`/`kubevip`) y `home_services_gateway_ip`/`gateway_domain` (wildcard `*.bonchan.org` → IP del Gateway, `192.168.1.128`), que generan la configuración de Pi-hole (`02-homelab.conf.j2`); `home_services_dns_overrides` son las excepciones a ese wildcard para los hosts con IP `LoadBalancer` propia en vez de pasar por el Gateway — hoy `ldap.bonchan.org` (`192.168.1.130`, outpost LDAP de Authentik) y `mail.bonchan.org` (`192.168.1.131`, Stalwart); si se añade un nuevo servicio con IP dedicada (ver `services/README.md`), su entrada va aquí. |
| `cloud-init` | Preparación del template de Proxmox: instala paquetes base, resetea `machine-id`, limpia configuración del instalador y deja cloud-init listo (`datasource_list: [NoCloud, ConfigDrive]`, `cloud-init clean`). |
| `vm-tuning` | Fija `vm.swappiness=10` dentro del **guest**. Solo se aplica una vez, al construir la plantilla de Packer (rol invocado desde `playbooks/packer-template.yml`, junto a `cloud-init`); las VMs clonadas del template ya heredan el valor, pero no hay forma de reaplicarlo a posteriori sin reconstruir la plantilla o correr el rol a mano. Variables en `defaults/main.yml`. |

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

# Servicios del hogar en luffy (Pi-hole, Home Assistant, Piper)
ansible-playbook playbooks/home-services.yml
```

