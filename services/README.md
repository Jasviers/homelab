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

Algunas `Application` usan `argocd.argoproj.io/sync-wave` para ordenar el despliegue: el operador CNPG (`-1`) se instala antes de que Authentik (`1`) cree su `Cluster` de PostgreSQL, y la monitorización (`2`) va después.

Para añadir un servicio nuevo: crea su carpeta bajo `services/` y un `Application` aquí; ArgoCD lo recogerá en el siguiente sync de `root`.

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

## synology-csi/

Kustomization que despliega el [CSI de Synology](https://github.com/SynologyOpenSource/synology-csi) (v1.3.0, manifiestos oficiales de `deploy/kubernetes/v1.20`) para aprovisionar volúmenes iSCSI dinámicos desde el NAS:

- `namespace.yml`, `csi-driver.yml`, `controller.yml`, `node.yml`: el `CSIDriver`, el controller (StatefulSet con provisioner/attacher/resizer) y el node (DaemonSet) con su RBAC.
- `storage-class.yml`: StorageClass `synology-iscsi-storage`, marcada como **default** del clúster, `reclaimPolicy: Retain` y expansión de volumen habilitada. Usa `protocol: iscsi`, por lo que cada PV es una **LUN iSCSI** creada en el volumen DSM indicado en `location` (`/volume1`); las LUNs no se crean dentro de carpetas compartidas. Ajusta `location` al volumen que toque.
- El snapshotter no se incluye (requeriría las CRDs de `snapshot.storage.k8s.io` y el snapshot-controller).

Las credenciales del NAS **no se versionan en git** (`client-info.yml` está en `.gitignore`). Hay que crear el Secret a mano tras el primer sync, partiendo de la plantilla `client-info.example.yml`:

```bash
cp services/synology-csi/client-info.example.yml services/synology-csi/client-info.yml
# editar client-info.yml con IP/usuario/contraseña del DSM, luego:
kubectl -n synology-csi create secret generic client-info-secret \
  --from-file=client-info.yml=services/synology-csi/client-info.yml
```

El usuario del DSM debe estar en el grupo `administrators` y tener el servicio iSCSI activado en el NAS. Verificación:

```bash
kubectl -n synology-csi get pods                 # controller + node Running
kubectl get storageclass                          # synology-iscsi-storage (default)
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
- `configmap.yml`: el `config.yaml` de cloudflared. Define el `tunnel` (UUID), el `credentials-file` y las reglas de `ingress`. La primera regla enruta `hs-lakasa.bonchan.org` → `http://192.168.1.2:8123` (**Home Assistant**, que corre en Docker sobre `luffy` con `network_mode: host`); la última (`http_status:404`) es el *catch-all* obligatorio.
- `deployment.yml`: Deployment de `cloudflared` con **2 réplicas** (anti-afinidad por nodo para no perder el túnel si cae uno), `securityContext` sin privilegios y métricas en `:2000` (probes `/ready`).

**Importante**: el túnel apunta **directo** a Home Assistant, **no** pasa por el Gateway. Es deliberado: el SSO de HA lo hace el propio Home Assistant vía OIDC contra Authentik (ver más abajo), no el forward-auth del Gateway (que rompería la app móvil, los webhooks y los tokens de API de HA).

### Bootstrap del túnel (pasos manuales)

El UUID del túnel y sus credenciales **no se versionan**. Tras crear el túnel hay que rellenar el UUID en `configmap.yml` y crear el Secret a mano:

```bash
# 1. Autenticar y crear el túnel (genera ~/.cloudflared/<UUID>.json)
cloudflared tunnel login
cloudflared tunnel create homelab

# 2. Secret con las credenciales del túnel (clave fija credentials.json)
kubectl -n cloudflared create secret generic tunnel-credentials \
  --from-file=credentials.json=$HOME/.cloudflared/<UUID>.json

# 3. Registrar el DNS público (CNAME a <UUID>.cfargotunnel.com en bonchan.org)
cloudflared tunnel route dns homelab hs-lakasa.bonchan.org

# 4. Editar services/cloudflared/configmap.yml y poner el UUID en `tunnel:`
```

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
    - 192.168.1.21/32   # nodos k8s donde corre cloudflared (origen del tráfico tras SNAT)
    - 192.168.1.22/32

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

> Si el Secret ya existe, edítalo (`kubectl -n authentik edit secret authentik-oidc-secrets`) para añadir la clave en lugar de recrearlo.

En el lado de Home Assistant se usa el componente [`hass-oidc-auth`](https://github.com/christiaangoossens/hass-oidc-auth) (instalable vía HACS). Configúralo en `configuration.yaml` (mismo `client_secret` que en Authentik, idealmente en `secrets.yaml`) y reinicia HA:

```yaml
auth_oidc:
  client_id: home-assistant
  client_secret: !secret oidc_client_secret
  discovery_url: "https://authentik.bonchan.org/application/o/home-assistant/.well-known/openid-configuration"
```

Tras esto, la pantalla de login de HA ofrece la opción de entrar con Authentik. La app móvil y la API siguen funcionando con el login nativo de HA, ya que el OIDC se añade como proveedor adicional y no como forward-auth.

