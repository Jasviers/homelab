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
