# Homelab — Arquitectura y servicios

Esta documentación describe la disposición actual de la red y servicios del homelab.

## Red y direccionamiento

- CIDR: `192.168.0.0/23`
- Router ASUS: `192.168.0.1`
- DHCP: `192.168.0.2 - 192.168.0.254`

## Hosts y roles

| Host | IP | Rol/Descripción |
| --- | --- | --- |
| `nas.bonchan.org` | `192.168.1.1` | NAS Synology (almacenamiento) |
| `luffy.bonchan.org` | `192.168.1.2` | Raspberry Pi 4B (Pi-hole, Home Assistant, quorum Proxmox) |
| `zoro.bonchan.org` | `192.168.1.3` | Proxmox Nodo 1 |
| `nami.bonchan.org` | `192.168.1.4` | Proxmox Nodo 2 |

## Lista de servicios

- **Pi-hole** en `luffy.bonchan.org` para DNS local y resolución de dominios internos.
- **Home Assistant** en `luffy.bonchan.org`. Cerebro de la automatización del hogar.
- **Proxmox** con dos nodos (`zoro` y `nami`) y quorum que incluye el Raspberry Pi (`luffy`).

## Dominio y DNS

- Dominio principal: `bonchan.org` (gestionado en Cloudflare).
- Los dominios locales se resuelven mediante Pi-hole.

## Acceso remoto

- **VPN**: el router ASUS expone un servidor **OpenVPN**.
- **Cloudflare Zero Trust**: permite exponer servicios de forma segura sin necesidad de abrir puertos en el router, utilizando túneles y autenticación de Cloudflare.

## Clúster k3s

Dos VMs Ubuntu 26 (una por nodo Proxmox) forman un clúster k3s con etcd embebido, desplegado sin `servicelb`, `traefik` ni `local-storage`:

| VM | IP | Nodo Proxmox | VMID |
| --- | --- | --- | --- |
| `vm-ubuntu26-zoro-01` | `192.168.1.21` | `zoro` | 210 |
| `vm-ubuntu26-nami-01` | `192.168.1.22` | `nami` | 220 |

- **MetalLB** asigna IPs `LoadBalancer` del rango reservado `192.168.1.128/25` (192.168.1.128 – 192.168.1.255).
- **ArgoCD** (UI en `192.168.1.128`) gestiona las aplicaciones del clúster vía GitOps desde este repositorio.

## Estructura del repositorio

| Carpeta | Contenido |
| --- | --- |
| [packer/](packer/) | Template de Ubuntu 26 para Proxmox (autoinstall + provisión con Ansible). |
| [terraform/](terraform/proxmox-vm/) | Despliegue de las VMs del clúster desde el template (`proxmox-vm` como root module, `modules/proxmox-vm` como módulo reutilizable versionado). |
| [ansible/](ansible/) | Playbooks y roles: actualización de paquetes, instalación/desinstalación de k3s y preparación del template de Packer. |
| [services/](services/) | Manifiestos y helmfiles de los servicios del clúster (MetalLB, ArgoCD). |
| [docker-composes/](docker-composes/) | Servicios que corren en `luffy` con Docker Compose (Pi-hole, Home Assistant). |
| [scripts/](scripts/) | Scripts auxiliares: DDNS contra Cloudflare y firewall de la red IOT en el router. |
| `temp/` | Material en transición, pendiente de migrar a `services/`. |

## Flujo de despliegue

1. **Packer** (`packer/ubuntu26`): construye el template `ubuntu26-template` en Proxmox.
2. **Terraform** (`terraform/proxmox-vm`): clona el template y crea las dos VMs del clúster con cloud-init.
3. **Ansible** (`ansible/playbooks/install-k3s.yml`): instala k3s en las VMs y descarga el kubeconfig.
4. **Servicios** (`services/`): se aplica MetalLB y ArgoCD; a partir de ahí ArgoCD sincroniza desde este repositorio.

Cada carpeta tiene su propio README con el detalle de uso.
