# Servicios de Kubernetes

Manifiestos y releases de Helm para los servicios que corren en el clúster k3s.

## Orden de bootstrap

El clúster k3s se despliega sin `servicelb`, `traefik`, `local-storage` ni el networking integrado de k3s (flannel/kube-proxy; el CNI es **Cilium**, instalado por el rol de Ansible `install-k3s`, ver `ansible/playbooks/install-k3s.yml`), por lo que el orden importa. Todas las kustomizations usan `helmCharts` inline, así que requieren `kustomize build --enable-helm` (ArgoCD ya lo tiene activado vía `argocd-cm-patch.yaml`).

1. **Cilium LB IPAM** (kustomize): define el `CiliumLoadBalancerIPPool` y la `CiliumL2AnnouncementPolicy` que dan IPs de tipo `LoadBalancer` en la red local (el dataplane Cilium ya lo instala Ansible). Imprescindible antes de cualquier servicio expuesto.
2. **ArgoCD** (kustomize): una vez instalado, gestiona el resto de aplicaciones vía GitOps mediante un patrón *app-of-apps*.
3. **Application raíz**: registra `argocd-apps/root-app.yaml`, que despliega el resto de `Application` (kube-vip, cert-manager, gateway, synology-csi, cnpg-operator, authentik, monitor, homepage y el propio argocd).

```bash
# 1. Cilium LB IPAM (pool + política L2)
kubectl apply -k services/cilium-lb/

# 2. ArgoCD
kubectl apply -k services/argocd/ --enable-helm

# 3. App-of-apps: a partir de aquí ArgoCD sincroniza todo lo demás
kubectl apply -f services/argocd-apps/root-app.yaml
```

> Tras el primer sync hay que crear a mano los Secrets que no se versionan: el token de Cloudflare para cert-manager y las credenciales del NAS para Synology CSI (ver secciones correspondientes).

## cilium-lb/

Kustomization con los recursos de **Cilium LB IPAM** (sustituye a MetalLB). Son CRDs
cluster-scoped servidos por el chart de Cilium ya instalado en `kube-system` (vía Ansible);
la habilitación de los anuncios L2 vive en `ansible/roles/install-k3s/templates/cilium-values.yaml.j2`
(`l2announcements.enabled: true`).

- `pool.yaml`:
  - `CiliumLoadBalancerIPPool` (`pool`) con el bloque `192.168.1.128/25` (192.168.1.128 – 192.168.1.255). Este rango está reservado para servicios `LoadBalancer` y queda fuera del DHCP del router.
  - `CiliumL2AnnouncementPolicy` (`pool`) que anuncia las IPs `LoadBalancer` por ARP sobre la interfaz `eth0`.

## argocd/

Kustomization que instala ArgoCD desde los manifiestos estables upstream (`install.yaml`) con dos patches:

- `namespace.yaml`: namespace `argocd`.
- `argocd-cm-patch.yaml`
: añade `kustomize.buildOptions: --enable-helm` para que ArgoCD pueda renderizar las kustomizations con `helmCharts` inline.
- `argocd-cmd-params-patch.yaml`: pone `server.insecure: "true"`; el TLS lo termina el Gateway, así que el `argocd-server` corre en HTTP detrás de él.
- `svc.yaml`: `HTTPRoute` que publica la UI de ArgoCD en `argocd.bonchan.org` a través del Gateway `homelab` (backend `argocd-server:80`). Incluye anotaciones de autodescubrimiento de Homepage (con widget de ArgoCD). ArgoCD ya **no** se expone con una IP `LoadBalancer` propia; el único punto de entrada HTTP/S es el Gateway (`192.168.1.128`).

Contraseña inicial del admin:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d
```

## argocd-apps/

Patrón *app-of-apps*: una `Application` raíz observa esta carpeta y despliega el resto de `Application`. Todas apuntan a este mismo repo (`https://github.com/Jasviers/homelab`) con sync automático (`prune` + `selfHeal`) y `ServerSideApply=true`.

| Manifiesto | Application | Path que sincroniza |
| --- | --- | --- |
| `root-app.yaml` | `root` | `services/argocd-apps` (se gestiona a sí misma y registra las demás) |
| `argocd-app.yaml` | `argocd-app` | `services/argocd` (ArgoCD se gestiona a sí mismo) |
| `kubevip.yml` | `kube-vip` | `services/kubevip` |
| `cilium-lb.yml` | `cilium-lb` | `services/cilium-lb` |
| `certmanager-app.yaml` | `cert-manager` | `services/certmanager` |
| `gateway.yml` | `gateway` | `services/gateway` |
| `synology-csi.yml` | `synology-csi` | `services/synology-csi` |
| `cnpg-operator.yml` | `cnpg-operator` | `services/cnpg-operator` (sync-wave `-1`: antes que quien consuma PostgreSQL) |
| `authentik.yml` | `authentik` | `services/authentik` (sync-wave `1`: tras el operador CNPG) |
| `monitor.yml` | `monitor` | `services/monitor` (sync-wave `2`; una sola Application para todo el stack de monitorización) |
| `homepage.yml` | `homepage` | `services/homepage` |
| `cloudflared.yml` | `cloudflared` | `services/cloudflared` |
| `hubble.yml` | `hubble` | `services/hubble` |
| `coredns.yml` | `coredns` | `services/coredns` |
| `proxmox.yml` | `proxmox` | `services/proxmox` |
| `router.yml` | `router` | `services/router` |
| `ollama.yml` | `ollama` | `services/ollama` |
| `whisper.yml` | `whisper` | `services/whisper` |
| `garage.yml` | `garage` | `services/garage` |
| `media.yml` | `media` | `services/media` |

Algunas `Application` usan `argocd.argoproj.io/sync-wave` para ordenar el despliegue: el operador CNPG (`-1`) se instala antes de que Authentik (`1`) cree su `Cluster` de PostgreSQL, y la monitorización (`2`) va después.

Para añadir un servicio nuevo: crea su carpeta bajo `services/` y un `Application` aquí; ArgoCD lo recogerá en el siguiente sync de `root`.

## Taints de nodos

El clúster tiene 3 nodos tainted (los aplica el rol de Ansible `install-k3s` al
instalar k3s, no GitOps):

- **Control-plane** (`vm-ubuntu26-zoro-01`/`nami-01`): taint
  `node-role.kubernetes.io/control-plane=true:NoSchedule`. Solo lo toleran
  kube-vip (ver `kubevip/` más abajo) y el propio DaemonSet de Cilium
  (`tolerations: [{operator: Exists}]` en `cilium-values.yaml.j2`).
- **Nodo de IA** (`vm-ubuntu26-zoro-ai`, 8 vCPU/48 GB, sin GPU): taint
  `dedicated=ai:NoSchedule` + label `workload-type=ai`. Aloja `ollama/` y
  `whisper/` (ver secciones más abajo). Es el patrón a seguir para cualquier
  servicio de IA futuro: su manifiesto debe incluir

  ```yaml
  tolerations:
    - key: dedicated
      operator: Equal
      value: ai
      effect: NoSchedule
  nodeSelector:
    workload-type: ai
  ```

  Sin esta toleration + selector, el pod nunca se programa ahí; el resto de
  servicios (que no la declaran) nunca aterrizan en este nodo aunque haya
  hueco, por el taint.

## kubevip/

Kustomization que instala [kube-vip](https://kube-vip.io) (chart oficial v0.6.6) para dar al *control plane* de k3s una **VIP de alta disponibilidad** en `192.168.1.20`:

- `kustomization.yml`: chart `kube-vip` con `cp_enable: true` y `svc_enable: false` (solo control-plane; los `LoadBalancer` los gestiona Cilium LB IPAM), modo **ARP** (`vip_arp`), *leader election* entre nodos y `vip_interface: eth0`.
- Corre como DaemonSet en los nodos control-plane (nodeSelector + tolerations sobre `node-role.kubernetes.io/control-plane`).

La VIP `192.168.1.20` es el endpoint estable del API de Kubernetes y está registrada en Pi-hole como `kubevip` (ver `ansible/roles/home-services/defaults/main.yml`). Aunque ArgoCD la gestiona vía GitOps, conviene tenerla en cuenta desde el bootstrap del clúster.

## certmanager/

Kustomization que instala cert-manager (chart `cert-manager` de Jetstack) y los emisores de certificados de Let's Encrypt:

- `kustomization.yml`: chart v1.20.2 con los CRDs incluidos (`crds.enabled`), el soporte de Gateway API activado (`config.enableGatewayAPI: true`) y los checks de propagación DNS-01 forzados contra DNS públicos (`1.1.1.1`, `9.9.9.9`) para evitar el DNS local.
- `cluster-issuers.yaml`: un `ClusterIssuer` ACME llamado `letsencrypt` con challenge **DNS-01 vía Cloudflare** para la zona `bonchan.org`, apuntando al endpoint de **producción** de Let's Encrypt. Es el issuer que usa el Gateway (anotación `cert-manager.io/cluster-issuer: letsencrypt`) para el certificado wildcard `*.bonchan.org`.

El issuer requiere un Secret con un API token de Cloudflare (permisos `Zone / DNS / Edit` y `Zone / Zone / Read` sobre `bonchan.org`). El token **no se versiona en git**; hay que crearlo a mano tras el primer sync (cuando ya exista el namespace):

```bash
kubectl -n cert-manager create secret generic cloudflare-api-token \
  --from-literal=api-token=<CLOUDFLARE_API_TOKEN>
```

Para pedir un certificado desde cualquier namespace:

```yaml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: mi-servicio
spec:
  secretName: mi-servicio-tls
  issuerRef:
    name: letsencrypt
    kind: ClusterIssuer
  dnsNames:
    - mi-servicio.bonchan.org
```

Como el Gateway ya termina TLS para `*.bonchan.org` con un único certificado wildcard, normalmente basta con publicar el servicio mediante un `HTTPRoute` bajo un subdominio de `bonchan.org` y no hace falta pedir un certificado por servicio.

Verificación:

```bash
kubectl get clusterissuers          # READY=True cuando el token funciona
kubectl describe certificate <name> # estado de la emisión
```

La renovación del certificado wildcard es **automática**: cert-manager vigila la caducidad y renueva el certificado antes de que expire. Si el token de Cloudflare caduca, la renovación fallará y el `Certificate` pasará a `False`; habría que recrear el secret `cloudflare-api-token` con un token nuevo y cert-manager reintentará automáticamente.

## synology-csi/

Kustomization que despliega el [CSI de Synology](https://github.com/SynologyOpenSource/synology-csi) (v1.3.0, manifiestos oficiales de `deploy/kubernetes/v1.20`) para aprovisionar volúmenes iSCSI dinámicos desde el NAS:

- `namespace.yml`, `csi-driver.yml`, `controller.yml`, `node.yml`: el `CSIDriver`, el controller (StatefulSet con provisioner/attacher/resizer) y el node (DaemonSet) con su RBAC.
- `storage-class.yml`: StorageClass `synology-iscsi-storage`, marcada como **default** del clúster, `reclaimPolicy: Retain` y expansión de volumen habilitada. Usa `protocol: iscsi`, por lo que cada PV es una **LUN iSCSI** creada en el volumen DSM indicado en `location` (`/volume1`); las LUNs no se crean dentro de carpetas compartidas.
- `storage-class-nfs.yml`: StorageClass `synology-nfs-storage`, mismo provisioner pero `protocol: nfs`. Aquí cada PV es una **carpeta compartida** creada dinámicamente por el driver dentro de `location` (`/volume1/nfs_kubernetes`, carpeta compartida precreada en el DSM con el servicio NFS activado y permisos para la subred de los nodos), no una LUN — no cuenta contra el límite de LUNs iSCSI del NAS. También soporta `ReadWriteMany`. El NAS usado en este homelab (Synology DS223j, 2 bahías) solo admite un número reducido de LUNs iSCSI (10), así que `synology-nfs-storage` es la clase recomendada para cualquier PVC que no necesite semántica de bloque: solo se deja en iSCSI lo que se beneficia de ella (bases de datos, Loki, Garage).
- El snapshotter no se incluye (requeriría las CRDs de `snapshot.storage.k8s.io` y el snapshot-controller).

Las credenciales del NAS **no se versionan en git** (`client-info.yml` está en `.gitignore`). Hay que crear el Secret a mano tras el primer sync, partiendo de la plantilla `client-info.example.yml`:

```bash
cp services/synology-csi/client-info.example.yml services/synology-csi/client-info.yml
# editar client-info.yml con IP/usuario/contraseña del DSM, luego:
kubectl -n synology-csi create secret generic client-info-secret \
  --from-file=client-info.yml=services/synology-csi/client-info.yml
```

El usuario del DSM debe estar en el grupo `administrators` y tener el servicio iSCSI activado en el NAS. Para `synology-nfs-storage` además hay que activar el servicio NFS (Panel de control → Servicios de archivos → NFS) y dar permisos NFS (lectura/escritura, sin *root squash*) a la subred de los nodos sobre la carpeta compartida usada en `location`. Verificación:

```bash
kubectl -n synology-csi get pods                 # controller + node Running
kubectl get storageclass                          # synology-iscsi-storage (default) y synology-nfs-storage
kubectl -n synology-csi logs sts/synology-csi-controller -c csi-plugin
```

## gateway/

Kustomization que instala **Envoy Gateway** (implementación de la Gateway API) y define el punto de entrada HTTP/S del clúster:

- `kustomization.yml`: chart `gateway-helm` v1.5.5 (OCI `docker.io/envoyproxy`) con sus CRDs, en el namespace `envoy-gateway-system`.
- `gateway.yml`:
  - `GatewayClass` `envoy` (controller `gateway.envoyproxy.io/gatewayclass-controller`).
  - `Gateway` `homelab` con un listener HTTPS (443) para `*.bonchan.org`. Recibe la IP fija `192.168.1.128` vía anotación de Cilium LB IPAM (`lbipam.cilium.io/ips`) y un certificado wildcard emitido por cert-manager (anotación `cert-manager.io/cluster-issuer: letsencrypt`, secret `bonchan-org-tls`). Acepta `HTTPRoute` desde **todos** los namespaces.

Cada servicio se publica creando un `HTTPRoute` con `parentRefs` al Gateway `homelab` y un hostname bajo `bonchan.org` (ver ejemplos en `argocd/svc.yaml` y `homepage/httproute.yml`).

## homepage/

Kustomization que despliega [Homepage](https://gethomepage.dev) como portal/dashboard del homelab, expuesto en `homepage.bonchan.org`:

- `deployment.yml` / `service.yml` / `namespace.yml`: la app (`ghcr.io/gethomepage/homepage`) y su `Service` ClusterIP en el puerto 3000.
- `rbac.yml`: `ServiceAccount` + `ClusterRole` de solo lectura (namespaces, pods, nodes, ingresses, httproutes/gateways y `metrics.k8s.io`) para los widgets de Kubernetes y el autodescubrimiento de servicios.
- `configmap.yml`: configuración de Homepage (settings, widgets de cluster/nodos, bookmarks a Proxmox/NAS/repo). El modo cluster y el descubrimiento por Gateway API están activados (`kubernetes.yaml: gateway: true`).
- `httproute.yml`: `HTTPRoute` que enruta `homepage.bonchan.org` al Service.

**Autodescubrimiento**: otros servicios aparecen automáticamente en el dashboard añadiendo anotaciones `gethomepage.dev/*` a su `HTTPRoute` (nombre, grupo, icono, href y, opcionalmente, un widget). El widget de ArgoCD necesita un token, que se inyecta vía el Secret opcional `homepage-secrets` (clave `argocd-token`).

## hubble/

Kustomization que expone la UI de [Hubble](https://docs.cilium.io/en/stable/network/observability/) (observabilidad de red basada en eBPF de Cilium) en `hubble.bonchan.org`:

- `httproute.yml`: `HTTPRoute` en `kube-system` que enruta `hubble.bonchan.org` al Service `hubble-ui:80` (el DaemonSet de Cilium ya despliega Hubble UI). Incluye anotaciones de autodescubrimiento de Homepage.
- `securitypolicy.yml`: `SecurityPolicy` de Envoy Gateway que protege la ruta con OIDC contra Authentik (`client_id: hubble`). El `client_secret` se inyecta vía el Secret `hubble-oidc-secret` en `kube-system`.

Se despliega con sync-wave `2` (junto con monitorización). El OIDC se configura en el paso 5.4 del runbook de bootstrap.

## cnpg-operator/

Kustomization que instala el operador [CloudNativePG](https://cloudnative-pg.io) (chart `cloudnative-pg` v0.28.3) en el namespace `cnpg-system`. Es el operador que gestiona las bases de datos PostgreSQL del clúster mediante el CRD `Cluster`.

- `kustomization.yml`: chart `cloudnative-pg` + `namespace.yaml`.
- Se despliega con sync-wave `-1` para estar disponible **antes** de que cualquier servicio (p. ej. Authentik) declare su `Cluster`.

Cada servicio que necesite PostgreSQL crea su propio `Cluster` en su namespace; el operador aprovisiona los pods, los Secrets de credenciales (`<cluster>-app`) y los Services de acceso (`<cluster>-rw` / `-ro`). El almacenamiento sale del Synology CSI.

## authentik/

Kustomization que despliega [Authentik](https://goauthentik.io) como proveedor de identidad (SSO/IdP) del homelab, expuesto en `authentik.bonchan.org`:

- `kustomization.yml`: chart `authentik` v2026.5.3 con el PostgreSQL **embebido del chart desactivado** (`postgresql.enabled: false`); usa en su lugar el `Cluster` de CNPG. Variables de conexión y recursos (server/worker) en `valuesInline`.
- `postgres-cluster.yml`: `Cluster` de CNPG `authentik-db` (1 instancia, 5Gi en `synology-iscsi-storage`) que crea la base de datos `authentik`. El chart se conecta al Service `authentik-db-rw` y toma la contraseña del Secret `authentik-db-app` que genera CNPG.
- `redis.yml`: un Redis ligero (`redis:7-alpine`, sin persistencia, `maxmemory` 96 MB) para la caché/cola de Authentik.
- `httproute.yml`: `HTTPRoute` que publica `authentik.bonchan.org` a través del Gateway, con anotaciones de autodescubrimiento de Homepage.

Se despliega con sync-wave `1` (después del operador CNPG). Requiere un Secret **no versionado** con la `secret_key` de Authentik, que hay que crear a mano tras el primer sync:

```bash
kubectl -n authentik create secret generic authentik-secret \
  --from-literal=secret_key=$(openssl rand -base64 60 | tr -d '\n')
```

La contraseña de la base de datos (`authentik-db-app`) la genera CNPG automáticamente; no hay que crearla.

## monitor/

Stack de monitorización (Grafana + Prometheus + Loki + Alloy) en el namespace `monitoring`. A diferencia del resto, **una sola `Application` de ArgoCD** (`monitor.yml`) sincroniza la carpeta `services/monitor/` completa: el `kustomization.yaml` raíz agrega cada componente, que vive en su propia subcarpeta como kustomization con `helmCharts` inline.

Reparto de responsabilidades:

- **kube-prometheus-stack/** (chart `kube-prometheus-stack`): el operador de Prometheus + `kube-state-metrics` + `node-exporter`. Prometheus scrapea todo vía `ServiceMonitor`/`PodMonitor` (de **todos** los namespaces) y almacena en un PVC del Synology CSI (`retention: 15d`).
  - **Alertmanager desactivado**: el alerting local se gestiona desde Grafana (unified alerting trae su propio Alertmanager embebido).
  - **Grafana del stack desactivada**: se despliega aparte (carpeta `grafana/`).
  - `kube-state-metrics` es imprescindible (expone el estado de los objetos de k8s; Alloy no puede generar esas métricas, solo scrapearlas). `node-exporter` da las métricas de host.
- **loki/** (chart `loki`): almacenamiento de logs en modo `SingleBinary` sobre filesystem (PVC del Synology CSI, retención 7 días). Cuando exista MinIO se puede migrar a object storage (S3).
- **grafana/** (chart `grafana`): Grafana **local** para dashboards y alertas. Datasources de Prometheus y Loki preconfigurados, sidecar de dashboards activado y un par de dashboards de arranque (node-exporter, vistas de k8s, logs de Loki). Expuesta en `grafana.bonchan.org` vía `httproute.yml`.
- **alloy/** (chart `alloy`): Alloy como **DaemonSet** que recoge los **logs** de los pods (vía la API de k8s) y los envía a Loki. Es el sucesor del Grafana Agent: no hace falta un agente aparte para hablar con Grafana Cloud.
- **tempo/**: pendiente. Las trazas solo aportan valor con apps instrumentadas emitiendo OTLP; se añadirá cuando haya una.

Secretos que **no se versionan** y hay que crear a mano tras el primer sync:

```bash
# Credenciales de admin de Grafana
kubectl -n monitoring create secret generic grafana-admin \
  --from-literal=admin-user=admin \
  --from-literal=admin-password=<PASSWORD>
```

### Alerta de caída total (Grafana Cloud)

Si Prometheus, Loki y Grafana viven **solo** en el clúster y el clúster se cae, no recibes la alerta justo cuando más la necesitas. Para que Grafana Cloud te avise de una caída total se hace `remoteWrite` de un subconjunto crítico de métricas (incluida la regla siempre activa `Watchdog`): si el latido deja de llegar, Cloud dispara la alerta (patrón DeadMansSwitch). Logs y trazas (lo caro de ingerir) se quedan en local.

Para activarlo: descomenta el bloque `remoteWrite` en `kube-prometheus-stack/kustomization.yaml`, ajusta la URL de tu cuenta y crea el Secret:

```bash
kubectl -n monitoring create secret generic grafana-cloud-credentials \
  --from-literal=prometheus-username=<INSTANCE_ID> \
  --from-literal=prometheus-password=<API_TOKEN>
```

Como segunda red, conviene además una sonda externa (Synthetic Monitoring de Grafana Cloud) que pruebe los endpoints desde fuera del clúster.

## cloudflared/

Kustomization que despliega [`cloudflared`](https://developers.cloudflare.com/cloudflare-tunnel/) como **Cloudflare Tunnel** para exponer servicios del homelab a internet **sin abrir puertos** en el router: el pod abre una conexión saliente a la red de Cloudflare y esta enruta el tráfico de los hostnames públicos al túnel.

A diferencia del resto, el túnel es **locally-managed**: las reglas de ingress se versionan en git (`configmap.yml`), no en el panel de Cloudflare. Esto da el control GitOps que pedía el TODO.

- `namespace.yml`: namespace `cloudflared`.
- `configmap.yml`: plantilla del `config.yaml` de cloudflared. Contiene el placeholder `<TUNNEL_ID>` que el init container reemplaza automáticamente con el UUID real al extraerlo del `TUNNEL_TOKEN` (JWT). Define las reglas de `ingress`: la primera enruta `hs-lakasa.bonchan.org` → `http://192.168.1.2:8123` (**Home Assistant**, que corre en Docker sobre `luffy` con `network_mode: host`); la última (`http_status:404`) es el *catch-all* obligatorio.
- `deployment.yml`: Deployment de `cloudflared` con **2 réplicas** (anti-afinidad por nodo para no perder el túnel si cae uno), `securityContext` sin privilegios y métricas en `:2000` (probes `/ready`). La autenticación del túnel se hace vía `TUNNEL_TOKEN` (env var desde el Secret `tunnel-credentials`). Un **init container** (`busybox`) decodifica el JWT del token, extrae el UUID del campo `t` y genera el `config.yaml` definitivo en un volumen `emptyDir` compartido con el container principal.

**Importante**: el túnel apunta **directo** a Home Assistant, **no** pasa por el Gateway. Es deliberado: el SSO de HA lo hace el propio Home Assistant vía OIDC contra Authentik (ver más abajo), no el forward-auth del Gateway (que rompería la app móvil, los webhooks y los tokens de API de HA).

### Bootstrap del túnel (pasos manuales)

El UUID del túnel y su token **no se versionan**. Tras crear el túnel hay que crear el Secret a mano; el UUID se resuelve automáticamente:

```bash
# 1. Autenticar y crear el túnel (genera ~/.cloudflared/<UUID>.json)
cloudflared tunnel login
cloudflared tunnel create homelab

# 2. Obtener el token del túnel (misma credencial que el .json, en base64)
cloudflared tunnel token homelab

# 3. Secret con el token (clave fija `token`, leída como TUNNEL_TOKEN)
kubectl -n cloudflared create secret generic tunnel-credentials \
  --from-literal=token=<TOKEN_DEL_PASO_2>

# 4. Registrar el DNS público (CNAME a <UUID>.cfargotunnel.com en bonchan.org)
cloudflared tunnel route dns homelab hs-lakasa.bonchan.org
```

> **UUID automático**: el init container decodifica el JWT del `TUNNEL_TOKEN`, extrae el UUID del campo `t` y lo inyecta en el `config.yaml`. No es necesario editar `configmap.yml` con el UUID.

Para añadir más servicios al túnel basta con una nueva regla en `ingress:` (antes del `http_status:404`) y su `route dns` correspondiente.

Verificación:

```bash
kubectl -n cloudflared get pods                       # 2 réplicas Running
kubectl -n cloudflared logs deploy/cloudflared        # "Registered tunnel connection"
```

### Home Assistant detrás del proxy

Como HA queda detrás de cloudflared, hay que declararlo como proxy de confianza en su `configuration.yaml` (volumen de HA en `luffy`, **fuera de este repo**) y reiniciar HA:

```yaml
http:
  use_x_forwarded_for: true
  trusted_proxies:
    - 192.168.1.30/32
    - 192.168.1.31/32

# Recomendado para que los enlaces y el redirect OIDC usen la URL pública
external_url: "https://hs-lakasa.bonchan.org"
```

### SSO sobre Home Assistant (OIDC contra Authentik)

El blueprint `authentik/blueprints/home-assistant.yaml` crea un provider OAuth2/OIDC **confidential** (`client_id: home-assistant`, callback `https://hs-lakasa.bonchan.org/auth/oidc/callback`) y la aplicación correspondiente. El `client_secret` se inyecta vía la variable `HOMEASSISTANT_CLIENT_SECRET` desde el Secret **no versionado** `authentik-oidc-secrets` (clave `home-assistant-client-secret`); añádela igual que el resto de clientes OIDC:

```bash
kubectl -n authentik create secret generic authentik-oidc-secrets \
  --from-literal=home-assistant-client-secret=$(openssl rand -base64 60 | tr -d '\n') \
  # ... junto al resto de claves (argocd/grafana/hubble/proxmox/router)
```

> Si el Secret `authentik-oidc-secrets` ya existe, usa `patch` en lugar de `create` para no perder las claves existentes (ver el runbook de bootstrap para el patrón correcto create-or-patch).

En el lado de Home Assistant se usa el componente [`hass-oidc-auth`](https://github.com/christiaangoossens/hass-oidc-auth) (instalable vía HACS). Configúralo en `configuration.yaml` (mismo `client_secret` que en Authentik, idealmente en `secrets.yaml`) y reinicia HA:

```yaml
auth_oidc:
  client_id: home-assistant
  client_secret: !secret oidc_client_secret
  discovery_url: "https://authentik.bonchan.org/application/o/home-assistant/.well-known/openid-configuration"
```

Tras esto, la pantalla de login de HA ofrece la opción de entrar con Authentik. La app móvil y la API siguen funcionando con el login nativo de HA, ya que el OIDC se añade como proveedor adicional y no como forward-auth.

## Cómo añadir un servicio nuevo al clúster

1. **Crear la carpeta** bajo `services/<nombre>/` con un `kustomization.yml` que use `helmCharts` inline o manifiestos estáticos.

2. **Definir un `HTTPRoute`** con `parentRefs` al Gateway `homelab` y un hostname bajo `bonchan.org`:

   ```yaml
   apiVersion: gateway.networking.k8s.io/v1
   kind: HTTPRoute
   metadata:
     name: mi-servicio
   spec:
     parentRefs:
       - name: homelab
         namespace: envoy-gateway-system
     hostnames:
       - mi-servicio.bonchan.org
     rules:
       - backendRefs:
           - name: mi-servicio
             port: 80
   ```

3. **Anotaciones de Homepage** (opcional) para autodescubrimiento:

   ```yaml
   annotations:
     gethomepage.dev/enabled: "true"
     gethomepage.dev/name: Mi Servicio
     gethomepage.dev/group: Grupo
     gethomepage.dev/icon: <icono>.png
     gethomepage.dev/href: https://mi-servicio.bonchan.org
   ```

4. **Crear la Application de ArgoCD** en `services/argocd-apps/<nombre>.yml`:

   ```yaml
   apiVersion: argoproj.io/v1alpha1
   kind: Application
   metadata:
     name: mi-servicio
     namespace: argocd
   spec:
     project: default
     source:
       repoURL: 'https://github.com/Jasviers/homelab'
       targetRevision: HEAD
       path: services/mi-servicio
     destination:
       server: 'https://kubernetes.default.svc'
       namespace: mi-servicio
     syncPolicy:
       automated:
         prune: true
         selfHeal: true
       syncOptions:
         - CreateNamespace=true
         - ServerSideApply=true
   ```

5. **Crear secrets no versionados** si el servicio los necesita (credenciales, tokens OIDC, etc.).

6. **Aplicar** con `kubectl apply -k services/<nombre>/` o esperar a que ArgoCD lo sincronice en el siguiente sync de `root`.

## ollama/

Kustomization que despliega [Ollama](https://ollama.com) en el nodo de IA (`vm-ubuntu26-zoro-ai`, sin GPU), expuesto en `ollama.bonchan.org`:

- `deployment.yml`: un único Pod (`OLLAMA_KEEP_ALIVE: "-1"`, `OLLAMA_MAX_LOADED_MODELS: "1"`) que mantiene un único modelo residente en RAM: **`qwen3:1.7b-q4_K_M`**, dedicado a *tool calling* desde la integración Ollama de Home Assistant (respuestas cortas y rápidas para controlar dispositivos).
  - `OLLAMA_NUM_PARALLEL: "1"`: sin GPU, decodificar en paralelo solo reparte los mismos vCPU entre peticiones simultáneas; en serie se sirve más rápido.
  - `OLLAMA_CONTEXT_LENGTH: "8192"`: suficiente para el historial + definiciones de herramientas de una interacción de voz con HA. Antes estaba en `200000`, lo que reservaba un KV cache dimensionado para 200K tokens (~31Gi de RAM en reposo con el modelo de 4B que se usaba entonces) sin necesidad real.
  - `OLLAMA_FLASH_ATTENTION: "1"` / `OLLAMA_KV_CACHE_TYPE: "q8_0"`: reducen el footprint de memoria/ancho de banda del KV cache.
- `pvc.yml`: PVC de 40Gi en `synology-iscsi-storage` montado en `/root/.ollama` (persiste los modelos entre reinicios del pod).
- `job-pull-models.yml`: `Job` (sync-wave `1`, tras el Deployment) que ejecuta `ollama pull` del modelo contra el Service; idempotente, así que ArgoCD puede reaplicarlo sin volver a descargar si el digest no cambió.
- `httproute.yml`: publica la API en `ollama.bonchan.org` a través del Gateway (añadido a la allowlist de namespaces en `services/gateway/gateway.yml`).

Recursos: `requests` 3 vCPU/4Gi, `limits` 7 vCPU/10Gi (bajado desde 24Gi/32Gi tras reducir el contexto; deja mucho más margen para Whisper en el mismo nodo).

### Benchmark e historial de la elección de modelo

Se probó originalmente con dos modelos residentes (`qwen3-coder:30b` MoE para código + `qwen3:4b-instruct-2507-q4_K_M` para HA), pero se descartó el modelo de 30B por problemas de rendimiento en este nodo sin GPU (commit `29d2389`, "ollama only use small model and big context").

Con solo el modelo de 4B, medido en vivo contra `ollama.bonchan.org` (`/api/generate` y `/api/chat` con *tool calling*, hardware: Ryzen 5 7430U, 6c/12t, sin GPU):

| Modelo | Tokens/s (generación) | Precisión *tool calling* (4 casos de prueba) |
| --- | --- | --- |
| `qwen3:4b-instruct-2507-q4_K_M` | ~10 tok/s | 4/4 correctos |
| `qwen3:1.7b-q4_K_M` (sin *thinking*) | ~18-26 tok/s | 4/4 correctos |
| `qwen3:0.6b-q4_K_M` (sin *thinking*) | ~25-50 tok/s | 3/4 (falló una consulta de estado) |

La carga es *memory-bandwidth-bound* (el cuello de botella es leer los pesos del modelo en cada token, no el cómputo), por lo que tokens/s escala aproximadamente de forma inversa al tamaño del modelo. Se eligió **`qwen3:1.7b-q4_K_M`** como mejor compromiso: ~2x más rápido que el 4B con la misma precisión observada en las pruebas, mientras que el 0.6B ya empezaba a fallar *tool calls*. Si en uso real el 1.7B da problemas de precisión, el 4B queda como alternativa documentada (cambiar `job-pull-models.yml` y el nombre del modelo en la integración de HA).

Para usar otro modelo o ajustar cuántos quedan cargados, edita `job-pull-models.yml` (qué se descarga) y `OLLAMA_MAX_LOADED_MODELS` en `deployment.yml` (cuántos quedan residentes a la vez).

## garage/

Kustomization que despliega [Garage](https://garagehq.deuxfleurs.fr/) como almacenamiento de objetos compatible con S3, en `garage.bonchan.org`. Se eligió sobre MinIO porque MinIO Community Edition quedó sin mantenimiento (repositorio archivado en 2026); Garage es un binario único en Rust, ligero, con años de uso en producción por terceros y sin depender de una empresa que monetice el mismo artefacto.

Despliegue de un solo nodo (`replication_factor = 1`, sin HA real — no tiene sentido con un único NAS detrás):

- `configmap.yml`: `garage.toml` con la configuración no sensible (rutas de `metadata_dir`/`data_dir` bajo `/var/lib/garage`, bind del API S3 en `3900`, RPC en `3901` y API de administración en `3903`). Los secretos (`rpc_secret`, `admin_token`, `metrics_token`) se referencian vía `*_file` apuntando a `/etc/garage-secrets/`, montados desde el Secret manual `garage-secrets`.
- `pvc.yml`: PVC de 100Gi en `synology-iscsi-storage` montado en `/var/lib/garage` (datos + metadatos comparten el mismo volumen). Como la StorageClass tiene `allowVolumeExpansion: true`, crecer el almacenamiento más adelante es tan sencillo como subir `spec.resources.requests.storage` en este manifiesto y dejar que ArgoCD lo sincronice; no hay auto-scaling dinámico del tamaño (eso requeriría un controlador aparte tipo `pvc-autoscaler`), es una expansión online bajo demanda.
- `deployment.yml`: un único Pod (`command: /garage server`).
- `service.yml`: expone `3900` (S3 API) y `3903` (Admin API, solo para uso interno vía `kubectl exec`; **no** se publica en el Gateway).
- `httproute.yml`: publica únicamente el API S3 en `garage.bonchan.org` (añadido a la allowlist de namespaces en `services/gateway/gateway.yml`). No se configuró `root_domain` en `[s3_api]`, así que los clientes S3 deben usar **path-style addressing** (`force_path_style` / `s3ForcePathStyle: true`), no virtual-hosted-style.

No hay usuarios ni SSO: Garage se administra por completo con la CLI embebida en el propio binario (`garage <subcomando>`, ejecutado vía `kubectl exec` contra el pod), y el "control de acceso" son API keys con permisos por bucket — normalmente una key por aplicación/servicio, no por persona. Por eso no se integró con Authentik: el endpoint S3 se autentica con SigV4 (access key/secret key), que un login OIDC no puede sustituir.

> **Manual**: antes del primer despliegue, crear el Secret con los tokens (no se versiona en git):
>
> ```bash
> kubectl create namespace garage
> kubectl -n garage create secret generic garage-secrets \
>   --from-literal=rpc_secret="$(openssl rand -hex 32)" \
>   --from-literal=admin_token="$(openssl rand -base64 32)" \
>   --from-literal=metrics_token="$(openssl rand -base64 32)"
> ```
>
> Tras el primer arranque del Pod hay que asignar el *layout* del clúster de un solo nodo (Garage no sirve tráfico S3 sin esto):
>
> ```bash
> kubectl -n garage exec deploy/garage -- /garage node id
> # con el <node-id> que devuelve (parte antes de la @):
> kubectl -n garage exec deploy/garage -- /garage layout assign -z dc1 -c 100G <node-id>
> kubectl -n garage exec deploy/garage -- /garage layout show
> kubectl -n garage exec deploy/garage -- /garage layout apply
> ```
>
> Gestión de buckets y claves de acceso (una key por aplicación/uso, con permisos por bucket):
>
> ```bash
> kubectl -n garage exec deploy/garage -- /garage bucket create mi-bucket
> kubectl -n garage exec deploy/garage -- /garage key create mi-app-key
> kubectl -n garage exec deploy/garage -- /garage bucket allow --read --write mi-bucket --key mi-app-key
> # las credenciales (access key id + secret) se muestran una sola vez en la salida de `key create`/`key info --show-secret`
> ```

Para usar otro modelo o ajustar los que se mantienen cargados, edita `job-pull-models.yml` (qué se descarga) y `OLLAMA_MAX_LOADED_MODELS` en `deployment.yml` (cuántos quedan residentes a la vez).

## media/

Kustomization que despliega el stack multimedia (Jellyfin + Jellyseerr + Radarr + Sonarr + Prowlarr + qBittorrent) como un único namespace `media`, en `jellyfin.bonchan.org`, `jellyseerr.bonchan.org`, `radarr.bonchan.org`, `sonarr.bonchan.org`, `prowlarr.bonchan.org` y `qbittorrent.bonchan.org`.

A diferencia del resto de servicios (1 namespace por app), aquí todo comparte namespace porque Jellyfin/Radarr/Sonarr/qBittorrent necesitan ver **exactamente el mismo volumen** para que Radarr/Sonarr puedan importar con *hardlink* (instantáneo, sin duplicar espacio) en vez de copiar. `media-library` usa la StorageClass `synology-nfs-storage` (carpetas compartidas del CSI de Synology, no LUNs iSCSI) con `accessModes: ReadWriteMany`, así que ese volumen compartido puede montarse en varios Pods sin necesidad de fijarlos al mismo nodo. Al ser un único namespace con varias apps, sigue el mismo patrón que `monitor/`: una carpeta por app (cada una con su propio `kustomization.yml` con `namespace: media`) referenciadas desde el `kustomization.yml` raíz junto con los recursos compartidos:

- `namespace.yml`: el único `Namespace` (`media`) para todas las apps.
- `media-library-pvc.yml`: PVC compartido de 500Gi en `synology-nfs-storage` (`ReadWriteMany`) — el único recurso que no pertenece a una app concreta, por eso vive en la raíz.
- `jellyfin/`, `jellyseerr/`, `radarr/`, `sonarr/`, `prowlarr/`, `qbittorrent/`: cada carpeta tiene `pvc.yml` (config propia en `synology-nfs-storage`, 10Gi para Jellyfin, 1-2Gi para el resto), `deployment.yml`, `service.yml` y `httproute.yml` (con las anotaciones de Homepage bajo el grupo `Media`), publicando en `<app>.bonchan.org`.
- `jellyfin/deployment.yml`, `radarr/deployment.yml`, `sonarr/deployment.yml`, `qbittorrent/deployment.yml`: montan `media-library` en `/data` (Jellyfin en solo lectura, el resto en lectura-escritura). Dentro de `/data`, la convención es `/data/torrents/{movies,tv}` para las descargas y `/data/media/{movies,tv}` para la biblioteca final — así el hardlink entre ambas carpetas es posible por estar en el mismo filesystem. Esta estructura se crea a mano (o desde la propia UI) en el primer arranque; no está en git porque vive dentro del PVC.
- `jellyseerr/deployment.yml`, `prowlarr/deployment.yml`: no montan `media-library` (solo hablan por API con Jellyfin/Radarr/Sonarr).
- Como todas las apps están en el mismo namespace `media`, el Gateway solo necesita una entrada (`media`) en la allowlist de `services/gateway/gateway.yml` para dar acceso a las 6 rutas.

> **Manual tras el primer despliegue** (nada de esto se versiona en git, es configuración desde cada UI):
>
> 1. Crear en `media-library` (por ejemplo con `kubectl -n media exec deploy/qbittorrent -- mkdir -p /data/torrents/movies /data/torrents/tv /data/media/movies /data/media/tv`) la estructura de carpetas anterior.
> 2. **Prowlarr**: añadir los indexadores y conectarlo a Radarr/Sonarr (Settings → Apps) para que sincronice los indexadores automáticamente.
> 3. **qBittorrent**: carpeta de descargas por defecto `/data/torrents`.
> 4. **Radarr/Sonarr**: root folder `/data/media/movies` / `/data/media/tv`; añadir qBittorrent como *download client* (`qbittorrent.media.svc.cluster.local:8080`) y usar categorías (`radarr`/`sonarr`) para que qBittorrent separe las descargas por app.
> 5. **Jellyfin**: crear las bibliotecas apuntando a `/data/media/movies` y `/data/media/tv` (montado en solo lectura).
> 6. **Jellyseerr**: conectarlo a Jellyfin (`jellyfin.media.svc.cluster.local:8096`) y a Radarr/Sonarr (`radarr.media.svc.cluster.local:7878` / `sonarr.media.svc.cluster.local:8989`) desde su asistente de configuración inicial.
>
> Ninguna de estas apps tiene SSO con Authentik configurado — cada una gestiona su propio login (o ninguno, en el caso de qBittorrent/Radarr/Sonarr/Prowlarr si se restringe el acceso solo a la LAN).

## whisper/

Kustomization que despliega Whisper (STT, protocolo Wyoming) en el nodo de IA, migrado desde el rol de Ansible `home-services` (antes corría en `luffy`):

- `deployment.yml`: imagen `rhasspy/wyoming-whisper`, modelo **`small-int8`** (mejor precisión que el `base-int8` anterior, manteniendo latencia baja al compartir CPU con Ollama en el mismo nodo), `--language es`.
- `pvc.yml`: PVC de 5Gi en `synology-iscsi-storage` montado en `/data` para no volver a descargar el modelo en cada reinicio.
- `service.yml`: a diferencia del resto de servicios HTTP, Wyoming es un protocolo TCP a medida y **no** puede publicarse vía `HTTPRoute`. Se expone con una IP `LoadBalancer` propia de Cilium LB IPAM (`192.168.1.129:10300`), igual que el Gateway tiene la suya.

> **Manual**: la integración Wyoming de Home Assistant apuntaba a `localhost:10300` (Whisper corría junto a HA en `luffy`). Hay que actualizarla a `192.168.1.129:10300` en la configuración de HA (fuera de este repo). Piper (TTS) sigue en `luffy` sin cambios.

