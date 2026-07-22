# Tareas futuras

[x] Packer para templates de Proxmox

[x] Terraform para promox

[x] k3s

[x] metallb

[x] ArgoCD

[x] cert manager

[x] Renovate para gestión de actualizaciones

[x] Gateway API

[x] Homepage

[x] Almacenamiento synology CSI

[x] PostgreSQL: operador CloudNativePG (CNPG)

[x] SSO con Authentik

[x] Endpoint HA para API de k8s (kubevip)

[x] Automatizar configuración proxmox y quorum

[x] Automatizar despliegue de Pi-hole y Home Assistant

[x] Manual paso a paso para instalación y configuración de todo el homelab (automatización de todo lo posib)

[x] Cilium como CNI

[x] Monitorización (grafana, prometheus, loki y alloy)

[x] Asegurar que todos los logins vayan por authentik (Solo Grafana y argoCD de momento)

[x] Mejoras de documentación

---
[x] Sustituir metallb por cilium

[x] Mejor control de cloudflare tunnels (cloudflared en k8s)

[x] Ruta y DNS al router (añadirlo a homepage)

[x] Red de trabajo separada (Solo acceso a internet y no al resto de la red)

[x] Activar hubble en cilium

[x] Activar cifrado pod-to-pod en cilium

[x] Mejorar el gateway api

[x] Mejorar infraestructura de maquinas virtuales y k8s

[x] Despliegue de modelo de IA local (Ollama: Qwen3-Coder para código, Qwen3 4B para Home Assistant)

[x] Despliegue de whisper en el cluster

[ ] Mejoras en DNS (control automatico de la configuración, posible sustitución de pihole por coredns o bind9, nebulasync?)

[ ] Monitorización de la red (Paneles en grafana, sistemas de monitorización de red, etc.)

[ ] VPN foosha (Site B — túnel site-to-site con el homelab principal)

[ ] Netbox (IPAM/DCIM)

[ ] Network policies para aislar servicios

[ ] Mejora de gateway api (HA, Politicas de trafico, health checks, etc.)

[ ] Mejorar configuración de Proxmox (Que use por ejemplo versiones especificas de x86 por defecto)

[ ] Revisar escalabilidad de los PVC de k8s con synology y el formato de ISCSI (iSCSI vs NFS)

---

[ ] vault

[x] Desplegar Garage buckets

[ ] Jellyfin

[ ] Mejorar el homepage (más información, más servicios, etc.)

[ ] backups (proxmox backups + velero)

[ ] Convertidor de medios

[ ] Servicio de descarga de videos de youtube

[ ] SSO para pihole

---

[ ] Enchufes y luces (home assistant)

[ ] Mejoras de seguridad

[ ] Ansible de bastionado (CIS hardening)

[ ] Mejoras en el CI

[ ] Mejoras de monitorización

[ ] Mejoras de quorum para k8s

[ ] Karpenter (karpenter-provider-proxmox)

[ ] Chaos engineering (litmuschaos, kube-monkey, gremlin, etc.)

