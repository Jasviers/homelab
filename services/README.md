# Servicios de Kubernetes

Manifiestos y releases de Helm para los servicios que corren en el clúster k3s.

## Orden de bootstrap

El clúster k3s se despliega sin `servicelb`, `traefik` ni `local-storage` (ver `ansible/playbooks/install-k3s.yml`), por lo que el orden importa. Todas las kustomizations usan `helmCharts` inline, así que requieren `kustomize build --enable-helm` (ArgoCD ya lo tiene activado vía `argocd-cm-patch.yaml`).

1. **MetalLB** (kustomize + Helm): proporciona IPs de tipo `LoadBalancer` en la red local. Imprescindible antes de cualquier servicio expuesto.
2. **ArgoCD** (kustomize): una vez instalado, gestiona el resto de aplicaciones vía GitOps mediante un patrón *app-of-apps*.
3. **Application raíz**: registra `argocd-apps/root-app.yaml`, que despliega el resto de `Application` (cert-manager, gateway, homepage, synology-csi y el propio argocd).

```bash
# 1. MetalLB
kubectl apply -k services/metallb/ --enable-helm

# 2. ArgoCD
kubectl apply -k services/argocd/ --enable-helm

# 3. App-of-apps: a partir de aquí ArgoCD sincroniza todo lo demás
kubectl apply -f services/argocd-apps/root-app.yaml
```

> Tras el primer sync hay que crear a mano los Secrets que no se versionan: el token de Cloudflare para cert-manager y las credenciales del NAS para Synology CSI (ver secciones correspondientes).

## metallb/

Kustomization que instala el chart oficial de MetalLB (`metallb-system`) vía `helmCharts` inline.

- `kustomization.yaml`: chart `metallb` v0.16.1 + los recursos `namespace.yaml` y `pool.yaml`.
- `pool.yaml`: `IPAddressPool` (`pool`) con el rango `192.168.1.128/25` (192.168.1.128 – 192.168.1.255) y su `L2Advertisement`. Este rango está reservado para servicios `LoadBalancer` y queda fuera del DHCP del router.

## argocd/

Kustomization que instala ArgoCD desde los manifiestos estables upstream (`install.yaml`) con dos patches:

- `namespace.yaml`: namespace `argocd`.
- `argocd-cm-patch.yaml`: añade `kustomize.buildOptions: --enable-helm` para que ArgoCD pueda renderizar las kustomizations con `helmCharts` inline.
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
| `metallb-app.yaml` | `metallb` | `services/metallb` |
| `certmanager-app.yaml` | `cert-manager` | `services/certmanager` |
| `gateway.yml` | `gateway` | `services/gateway` |
| `homepage.yml` | `homepage` | `services/homepage` |
| `synology-csi.yml` | `synology-csi` | `services/synology-csi` |

Para añadir un servicio nuevo: crea su carpeta bajo `services/` y un `Application` aquí; ArgoCD lo recogerá en el siguiente sync de `root`.

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
  - `Gateway` `homelab` con un listener HTTPS (443) para `*.bonchan.org`. Recibe la IP fija `192.168.1.128` vía anotación de MetalLB (`metallb.io/loadBalancerIPs`) y un certificado wildcard emitido por cert-manager (anotación `cert-manager.io/cluster-issuer: letsencrypt`, secret `bonchan-org-tls`). Acepta `HTTPRoute` desde **todos** los namespaces.

Cada servicio se publica creando un `HTTPRoute` con `parentRefs` al Gateway `homelab` y un hostname bajo `bonchan.org` (ver ejemplos en `argocd/svc.yaml` y `homepage/httproute.yml`).

## homepage/

Kustomization que despliega [Homepage](https://gethomepage.dev) como portal/dashboard del homelab, expuesto en `homepage.bonchan.org`:

- `deployment.yml` / `service.yml` / `namespace.yml`: la app (`ghcr.io/gethomepage/homepage`) y su `Service` ClusterIP en el puerto 3000.
- `rbac.yml`: `ServiceAccount` + `ClusterRole` de solo lectura (namespaces, pods, nodes, ingresses, httproutes/gateways y `metrics.k8s.io`) para los widgets de Kubernetes y el autodescubrimiento de servicios.
- `configmap.yml`: configuración de Homepage (settings, widgets de cluster/nodos, bookmarks a Proxmox/NAS/repo). El modo cluster y el descubrimiento por Gateway API están activados (`kubernetes.yaml: gateway: true`).
- `httproute.yml`: `HTTPRoute` que enruta `homepage.bonchan.org` al Service.

**Autodescubrimiento**: otros servicios aparecen automáticamente en el dashboard añadiendo anotaciones `gethomepage.dev/*` a su `HTTPRoute` (nombre, grupo, icono, href y, opcionalmente, un widget). El widget de ArgoCD necesita un token, que se inyecta vía el Secret opcional `homepage-secrets` (clave `argocd-token`).

