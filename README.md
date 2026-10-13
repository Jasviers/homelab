# Homelab — Arquitectura y servicios

Esta documentación describe la disposición actual de la red y servicios del homelab.

## Red y direccionamiento

- CIDR principal: `192.168.0.0/23` (192.168.0.0 – 192.168.1.255), red plana sobre el router ASUS.
- Router ASUS: `192.168.0.1` (gateway por defecto).
- DHCP: `192.168.0.2 - 192.168.0.254`.
- Rango reservado para `LoadBalancer` (Cilium LB IPAM): `192.168.1.128/25` (192.168.1.128 – 192.168.1.255), fuera del DHCP.
- Hosts e infraestructura usan IPs estáticas en `192.168.1.0/24` (ver tablas siguientes).
- Red IOT aislada: `192.168.52.0/24` (bridge `br52` en el router ASUS), separada del resto por firewall (ver [scripts/](scripts/)).
- Red remota aislada (otra ubicación física): `192.168.20.0/24`, ver [Red remota (site B)](#red-remota-site-b) más abajo.

## Hosts y roles

| Host | IP | Hardware | Rol/Descripción |
| --- | --- | --- | --- |
| `nas.bonchan.org` | `192.168.1.1` | Synology DS223J · 2 bahías (1×4 TB, 1 libre) | NAS: almacenamiento e iSCSI (LUNs para el CSI del clúster) |
| `luffy.bonchan.org` | `192.168.1.2` | Raspberry Pi 4B · 8 GB RAM | Pi-hole, Home Assistant + Piper (TTS), quorum (QDevice) de Proxmox |
| `zoro.bonchan.org` | `192.168.1.3` | Geekom A5 · AMD Ryzen 5 7430U · 64 GB RAM | Proxmox Nodo 1 (hospeda `vm-ubuntu26-zoro-01`) |
| `nami.bonchan.org` | `192.168.1.4` | Geekom A5 · AMD Ryzen 5 7430U · 16 GB RAM | Proxmox Nodo 2 (hospeda `vm-ubuntu26-nami-02`) |

> El QDevice de quorum corre en `luffy`: permite que el clúster Proxmox de 2 nodos
> mantenga quorum aunque caiga uno de ellos.

## Lista de servicios

- **Pi-hole** en `luffy.bonchan.org` para DNS local y resolución de dominios internos.
- **Home Assistant** en `luffy.bonchan.org`. Cerebro de la automatización del hogar.
- **Asistente de voz**: **Piper** (TTS) en `luffy.bonchan.org` y **Whisper** (STT) en
  el clúster k3s (workers), ambos vía protocolo Wyoming, integrados con Home
  Assistant.
- **Proxmox** con dos nodos (`zoro` y `nami`) y quorum que incluye el Raspberry Pi (`luffy`).
- **Clúster k3s** sobre cuatro VMs Ubuntu 26 (ver sección siguiente) con todos los
  servicios del homelab gestionados por GitOps (ArgoCD): SSO con Authentik,
  PostgreSQL con CloudNativePG, monitorización (Grafana/Prometheus/Loki/Alloy),
  **Whisper** (STT), etc.

## Dominio y DNS

- Dominio principal: `bonchan.org` (gestionado en Cloudflare).
- Los dominios locales se resuelven mediante Pi-hole.

## Red remota (site B)

Segunda ubicación física, independiente del domicilio principal, conectada a la
LAN principal (`192.168.0.0/23`) mediante un túnel VPN site-to-site.

- **Hardware**: Raspberry Pi 2B.
- **Software**: PiVPN con servidor OpenVPN propio, independiente del servidor
  OpenVPN del router ASUS del site principal.
- **Red**: `192.168.20.0/24`.
- **IP de la Raspberry**: `192.168.20.134`.
- **Router**: ZTE ZXV10 en `192.168.20.1`, publicado en
  `foosha-router.bonchan.org` a través del Gateway API con SSO de Authentik
  (ver `services/router/`).
- **Estado**: la red es alcanzable desde la LAN principal a través del router
  ASUS (RTT ~10-25 ms), que es lo que permite que Envoy enrute a
  `192.168.20.1`.

## Acceso remoto

- **VPN**: el router ASUS expone un servidor **OpenVPN**.
- **Cloudflare Zero Trust**: permite exponer servicios de forma segura sin necesidad de abrir puertos en el router, utilizando túneles y autenticación de Cloudflare.

## Clúster k3s

4 VMs Ubuntu 26 repartidas entre los 2 nodos Proxmox forman el clúster k3s: 1 control-plane (etcd embebido single-node, sin cargas de trabajo) y 3 workers. Desplegado sin `servicelb`, `traefik`, `local-storage` ni el networking integrado (`flannel`, `kube-proxy` y `network-policy`):

| VM | IP | Nodo Proxmox | VMID | Rol k3s |
| --- | --- | --- | --- | --- |
| `vm-ubuntu26-zoro-01` | `192.168.1.21` | `zoro` | 210 | control-plane (server + etcd), taint `node-role.kubernetes.io/control-plane` |
| `vm-ubuntu26-zoro-02` | `192.168.1.30` | `zoro` | 211 | worker (agent), sin taint |
| `vm-ubuntu26-nami-02` | `192.168.1.31` | `nami` | 221 | worker (agent), sin taint |
| `vm-ubuntu26-zoro-04` | `192.168.1.32` | `zoro` | 214 | worker (agent), sin taint |

> El clúster tiene **un único control-plane** (`zoro-01`) con etcd single-node:
> es una decisión deliberada tras el postmortem
> `docs/postmortems/2026-07-27-etcd-fsync-kubevip-crashloop.md`. No hay HA de
> control-plane (si cae `zoro-01` el API no responde, aunque los pods ya
> programados siguen corriendo), a cambio de eliminar la replicación de etcd
> entre hosts y los problemas de quorum. Por lo mismo no hay VIP para el API:
> kubeconfig, agents y Cilium apuntan directamente a `192.168.1.21`. Ver
> `docs/runbooks/01-recovery-parcial.md`.
>
> Reparto de recursos: `zoro-01` 2 vCPU / 8 GB; `zoro-02` y `zoro-04` 6 vCPU / 24 GB (56 de 64 GB de `zoro` asignados); `nami-02` 6 vCPU / 12 GB sin ballooning (de 16 GB de `nami`). Todas las VMs usan `cpu_type = "host"` (ambos nodos Proxmox comparten CPU) — ver `terraform/proxmox-vm/README.md`. El antiguo nodo de IA (`vm-ubuntu26-zoro-ai`), el segundo control-plane (`vm-ubuntu26-nami-01`), Ollama y kube-vip se retiraron en octubre de 2026 (ver `old_services/`).

- **Cilium** es el CNI del clúster (dataplane eBPF con *kube-proxy replacement*), sustituyendo a flannel y kube-proxy. Lo instala el rol de Ansible `install-k3s` vía Helm, no GitOps (es la red que el resto necesita para arrancar). Tolera todos los taints (`tolerations: [{operator: Exists}]`) para correr también en el nodo control-plane.
- **Cilium LB IPAM + L2 announcements** asigna IPs `LoadBalancer` del rango reservado `192.168.1.128/25` (192.168.1.128 – 192.168.1.255), sustituyendo a MetalLB. El pool y la política L2 se definen en `services/cilium-lb/`.
- **Cifrado pod-to-pod con WireGuard** habilitado en Cilium: el tráfico entre pods de distintos nodos viaja cifrado de forma transparente, sin gestión manual de claves.
- **Envoy Gateway** (Gateway API) es el único punto de entrada HTTP/HTTPS del clúster: tiene la IP `192.168.1.128` y termina TLS para `*.bonchan.org` con un certificado wildcard emitido por cert-manager. El resto de servicios se publican como `HTTPRoute` bajo subdominios (p. ej. `argocd.bonchan.org`, `homepage.bonchan.org`).
- **ArgoCD** gestiona las aplicaciones del clúster vía GitOps desde este repositorio con un patrón *app-of-apps* y se expone a través del Gateway en `argocd.bonchan.org`.
- **cert-manager** emite los certificados Let's Encrypt mediante challenge DNS-01 contra Cloudflare.
- **Synology CSI** aprovisiona volúmenes persistentes (LUNs iSCSI) dinámicamente desde el NAS.
- **CloudNativePG (CNPG)** es el operador de PostgreSQL: cada servicio que necesita base de datos declara su propio `Cluster` (p. ej. el de Authentik).
- **Authentik** es el proveedor de identidad (SSO/IdP) del homelab, en `authentik.bonchan.org`, con su PostgreSQL dedicado gestionado por CNPG. También publica un **provider LDAP** para clientes sin OIDC (la NAS Synology), servido por un outpost propio con IP `LoadBalancer` dedicada (`192.168.1.130`, `ldap.bonchan.org`) — ver `services/README.md`.
- **Monitorización**: **Prometheus** (métricas), **Loki** (logs), **Alloy** (recolección de logs) y **Grafana** (dashboards y alertas) en `grafana.bonchan.org`.
- **Homepage** es el portal/dashboard del homelab en `homepage.bonchan.org`, con autodescubrimiento de servicios.
- **Whisper** (STT, protocolo Wyoming) corre en los workers con una IP `LoadBalancer` dedicada (`192.168.1.129`), reemplazando al Whisper que antes corría en `luffy`; Piper (TTS) sigue en `luffy`.
- **Cloudflare Tunnel** (`cloudflared`) expone servicios a internet sin abrir puertos en el router: Home Assistant vía `hs-lakasa.bonchan.org` (túnel locally-managed con reglas en git).
- **Hubble** (relay + UI) da observabilidad de red sobre eBPF en `hubble.bonchan.org`, protegido por OIDC.

## Estructura del repositorio

| Carpeta | Contenido |
| --- | --- |
| [packer/](packer/) | Template de Ubuntu 26 para Proxmox (autoinstall + provisión con Ansible). |
| [terraform/](terraform/proxmox-vm/) | Despliegue de las VMs del clúster desde el template (`proxmox-vm` como root module, `modules/proxmox-vm` como módulo reutilizable versionado). |
| [ansible/](ansible/) | Playbooks y roles: configuración de Proxmox y quorum (QDevice), actualización de paquetes, instalación/desinstalación de k3s, preparación del template de Packer y despliegue de los servicios de `luffy` (Pi-hole, Home Assistant y Piper) vía Docker Compose. |
| [services/](services/) | Manifiestos GitOps de los servicios del clúster gestionados por ArgoCD (Cilium LB IPAM, ArgoCD, cert-manager, Envoy Gateway API, Homepage, Synology CSI, CNPG, Authentik, monitorización, Hubble, Cloudflared, Whisper, Garage, Media, CoreDNS, Proxmox, Router, BentoPDF, Transmute, Servicios). |
| [grafana/](grafana/) | Dashboards de Grafana versionados como JSON. Se empaquetan en ConfigMaps y los consume la app `monitor` de ArgoCD (`resources: ../../grafana`); no tiene `Application` propia. |
| [old_services/](old_services/) | Servicios retirados, conservados como referencia y **no** gestionados por ArgoCD (p. ej. MetalLB, sustituido por Cilium LB IPAM). |
| [scripts/](scripts/) | Scripts auxiliares: DDNS contra Cloudflare y firewall de la red IOT en el router. |
| [docs/](docs/) | Documentación operativa: runbooks (manuales paso a paso) y postmortems *blameless*. |


## Flujo de despliegue

1. **Proxmox** (`ansible/playbooks/qdevice.yml`): configura los repos sin suscripción y el QDevice de quorum (árbitro en `luffy`).
2. **Packer** (`packer/ubuntu26`): construye el template `ubuntu26-template` en Proxmox.
3. **Terraform** (`terraform/proxmox-vm`): clona el template y crea las 4 VMs del clúster con cloud-init (1 control-plane, 3 workers).
4. **Ansible** (`ansible/playbooks/install-k3s.yml`): instala k3s en las VMs, despliega Cilium y descarga el kubeconfig.
5. **Servicios** (`services/`): se aplican manualmente el pool de Cilium LB (`services/cilium-lb`) y ArgoCD; después se registra la `Application` raíz (*app-of-apps*) y ArgoCD sincroniza el resto de servicios desde este repositorio.
6. **Servicios de `luffy`** (`ansible/playbooks/home-services.yml`): despliega Pi-hole, Home Assistant y Piper en la Raspberry.

El procedimiento completo paso a paso está en el runbook
[docs/runbooks/00-bootstrap-homelab.md](docs/runbooks/00-bootstrap-homelab.md).
Cada carpeta tiene además su propio README con el detalle de uso.

## Diagrama de red

```mermaid
flowchart TB
    internet([Internet])
    cf[Cloudflare<br/>DNS · Zero Trust Tunnel]
    internet <--> cf

    subgraph asus["Router ASUS 192.168.0.1 · 192.168.0.0/23"]
        vpn[/OpenVPN server/]
    end
    internet <-->|OpenVPN| vpn
    cf -.->|Tunnel| asus

    subgraph lan["LAN 192.168.1.0/24 (estática)"]
        nas["NAS Synology<br/>192.168.1.1"]
        luffy["luffy · RPi 4B<br/>192.168.1.2<br/>Pi-hole · Home Assistant · quorum"]
        zoro["zoro · Proxmox 1<br/>192.168.1.3"]
        nami["nami · Proxmox 2<br/>192.168.1.4"]
        vm1["vm-zoro-01 (control-plane)<br/>192.168.1.21"]
        vm3["vm-zoro-02 (worker)<br/>192.168.1.30"]
        vm4["vm-nami-02 (worker)<br/>192.168.1.31"]
        vm7["vm-zoro-04 (worker)<br/>192.168.1.32"]
        gw["Envoy Gateway (Cilium LB)<br/>192.168.1.128<br/>*.bonchan.org"]
    end

    asus --- lan
    zoro -.->|hospeda| vm1
    zoro -.->|hospeda| vm3
    zoro -.->|hospeda| vm7
    nami -.->|hospeda| vm4
    vm3 & vm4 & vm7 ==>|clúster k3s| gw
    vm1 & vm3 & vm4 & vm7 -.->|iSCSI| nas

    subgraph iot["Red IOT 192.168.52.0/24 (br52, aislada)"]
        dispositivos["Dispositivos IOT"]
    end
    asus --- iot
    luffy <-->|"único acceso permitido (firewall)"| iot

    cf -.->|*.bonchan.org| gw

    subgraph siteb["Site B · 192.168.20.0/24 (túnel site-to-site)"]
        pivpn["Raspberry Pi 2B<br/>192.168.20.134<br/>PiVPN · servidor OpenVPN propio"]
        siterouter["ZTE ZXV10<br/>192.168.20.1"]
    end
    asus <-->|"VPN site-to-site"| siteb

```

> El acceso a internet de la IOT y el tráfico desde/hacia el resto de la LAN están bloqueados por iptables en el router; solo Home Assistant (`luffy`) puede comunicarse con ella (ver [scripts/firewall-start.sh](scripts/firewall-start.sh)).
>
> El **Site B** (`192.168.20.0/24`) es una segunda ubicación física con su propio servidor OpenVPN (PiVPN), conectada a la LAN principal mediante un túnel VPN site-to-site; ver [Red remota (site B)](#red-remota-site-b).

## Diagrama del clúster y servicios

```mermaid
flowchart TB
    repo["Repositorio Git<br/>github.com/Jasviers/homelab"]

    subgraph k3s["Clúster k3s (2 control-plane + 3 workers + 1 IA)"]
        subgraph argocd["ArgoCD (GitOps)"]
            root["Application: root<br/>(app-of-apps)"]
            root --> appCiliumLb[cilium-lb]
            root --> appCert[cert-manager]
            root --> appGw[gateway]
            root --> appCsi[synology-csi]
            root --> appCnpg[cnpg-operator]
            root --> appAuth[authentik]
            root --> appMon[monitor]
            root --> appHome[homepage]
            root --> appArgo["argocd (self-managed)"]
            root --> appHubble[hubble]
            root --> appCloudflared[cloudflared]
            root --> appCoreDns[coredns]
            root --> appProxmox[proxmox]
            root --> appRouter[router]
            root --> appWhisper[whisper]
            root --> appGarage[garage]
            root --> appMedia[media]
            root --> appBentopdf[bentopdf]
            root --> appTransmute[transmute]
            root --> appServicios[servicios]
        end

        ciliumLb["Cilium LB IPAM + L2<br/>pool 192.168.1.128/25"]
        cert["cert-manager<br/>ClusterIssuer letsencrypt (DNS-01)"]
        gateway["Envoy Gateway<br/>192.168.1.128:443 · TLS *.bonchan.org"]
        homepage["Homepage<br/>homepage.bonchan.org"]
        argoUI["argocd-server<br/>argocd.bonchan.org"]
        csi["Synology CSI<br/>StorageClass por defecto"]
        cnpg["CloudNativePG<br/>operador PostgreSQL"]
        authentik["Authentik (SSO/IdP)<br/>authentik.bonchan.org"]
        ldap["Authentik LDAP outpost<br/>LoadBalancer 192.168.1.130"]
        monitor["Monitorización<br/>Prometheus · Loki · Alloy<br/>Grafana · grafana.bonchan.org"]
        hubble["Hubble UI<br/>hubble.bonchan.org"]
        cloudflared["cloudflared<br/>Tunnel → hs-lakasa.bonchan.org"]
        coredns["CoreDNS custom<br/>resolución interna *.bonchan.org"]
        proxmox["Proxmox UI<br/>proxmox/zoro/nami.bonchan.org"]
        routerSvc["Router ASUS UI<br/>router.bonchan.org"]
        whisper["Whisper STT (nodo IA)<br/>LoadBalancer 192.168.1.129:10300"]
        garage["Garage (S3)<br/>garage.bonchan.org"]
        media["Media stack<br/>jellyfin/radarr/sonarr/..."]
        bentopdf["BentoPDF<br/>bentopdf.bonchan.org"]
        transmute["Transmute<br/>transmute.bonchan.org"]
        servicios["Servicios (portal usuarios)<br/>servicios.bonchan.org"]
    end

    nas[("NAS Synology<br/>LUNs iSCSI")]
    cloudflare["Cloudflare DNS<br/>(challenge DNS-01)"]
    users([Usuarios · *.bonchan.org])

    repo -->|sync| argocd
    appCiliumLb -.->|gestiona| ciliumLb
    appCert -.->|gestiona| cert
    appGw -.->|gestiona| gateway
    appHome -.->|gestiona| homepage
    appArgo -.->|gestiona| argoUI
    appCsi -.->|gestiona| csi
    appCnpg -.->|gestiona| cnpg
    appAuth -.->|gestiona| authentik
    appMon -.->|gestiona| monitor
    appHubble -.->|gestiona| hubble
    appCloudflared -.->|gestiona| cloudflared
    appCoreDns -.->|gestiona| coredns
    appProxmox -.->|gestiona| proxmox
    appRouter -.->|gestiona| routerSvc
    appWhisper -.->|gestiona| whisper
    appGarage -.->|gestiona| garage
    appMedia -.->|gestiona| media
    appBentopdf -.->|gestiona| bentopdf
    appTransmute -.->|gestiona| transmute
    appServicios -.->|gestiona| servicios
    appAuth -.->|gestiona| ldap

    users -->|HTTPS| gateway
    gateway -->|HTTPRoute| homepage
    gateway -->|HTTPRoute| argoUI
    gateway -->|HTTPRoute| authentik
    gateway -->|HTTPRoute| monitor
    gateway -->|HTTPRoute| hubble
    gateway -->|HTTPRoute| proxmox
    gateway -->|HTTPRoute| routerSvc
    gateway -->|HTTPRoute| garage
    gateway -->|HTTPRoute| media
    gateway -->|HTTPRoute| bentopdf
    gateway -->|HTTPRoute| transmute
    gateway -->|HTTPRoute| servicios
    ciliumLb -->|IP LB| gateway
    ciliumLb -->|IP LB dedicada| whisper
    ciliumLb -->|IP LB dedicada| ldap
    cert <-->|valida dominio| cloudflare
    cert -->|wildcard TLS| gateway
    cnpg -->|Cluster PG| authentik
    csi -->|aprovisiona PV| nas
    monitor -->|PVC| csi
```
