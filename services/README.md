# Servicios de Kubernetes

Manifiestos y releases de Helm para los servicios que corren en el clúster k3s.

## Orden de bootstrap

El clúster k3s se despliega sin `servicelb` ni `traefik` (ver `ansible/playbooks/install-k3s.yml`), por lo que el orden importa:

1. **MetalLB** (helmfile + kustomize): proporciona IPs de tipo `LoadBalancer` en la red local.
2. **ArgoCD** (kustomize): una vez instalado, gestiona el resto de aplicaciones vía GitOps desde este repositorio.

```bash
# 1. MetalLB
cd services/metallb
helmfile apply
kubectl apply -k kustom/

# 2. ArgoCD
kubectl apply -k services/argocd/

# 3. Registrar la Application que hace que ArgoCD se gestione a sí mismo
kubectl apply -f services/argocd-apps/argocd-app.yaml
```

## metallb/

- `helmfile.yaml`: release del chart oficial de MetalLB (`metallb-system`).
- `kustom/metallb/pool.yaml`: `IPAddressPool` con el rango `192.168.1.128/25` (192.168.1.128 – 192.168.1.255) y su `L2Advertisement`. Este rango está reservado para servicios `LoadBalancer` y queda fuera del DHCP del router.

## argocd/

Kustomization que instala ArgoCD desde los manifiestos estables upstream:

- `namespace.yaml`: namespace `argocd`.
- `svc.yaml`: Service `LoadBalancer` adicional (`argocd-server-external`) con IP fija `192.168.1.128` vía anotación de MetalLB, exponiendo la UI en 80/443.

Contraseña inicial del admin:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d
```

## argocd-apps/

- `argocd-app.yaml`: `Application` que apunta a `services/argocd` de este mismo repo (`https://github.com/Jasviers/homelab`) con sync automático (`prune` + `selfHeal`). Es el punto de partida para un patrón *app-of-apps*: las futuras aplicaciones se añadirán aquí.

## certmanager/

Kustomization que instala cert-manager (chart `cert-manager` de Jetstack) y los emisores de certificados de Let's Encrypt:

- `kustomization.yml`: chart v1.20.2 con los CRDs incluidos (`crds.enabled`) y los checks de propagación DNS-01 forzados contra DNS públicos (`1.1.1.1`, `9.9.9.9`) para evitar el DNS local.
- `cluster-issuers.yaml`: dos `ClusterIssuer` ACME con challenge **DNS-01 vía Cloudflare** para la zona `bonchan.org`:
  - `letsencrypt-staging`: para pruebas (certificados no confiables, sin rate limits estrictos).
  - `letsencrypt-prod`: para certificados reales.

Ambos issuers requieren un Secret con un API token de Cloudflare (permisos `Zone / DNS / Edit` y `Zone / Zone / Read` sobre `bonchan.org`). El token **no se versiona en git**; hay que crearlo a mano tras el primer sync (cuando ya exista el namespace):

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
    name: letsencrypt-prod
    kind: ClusterIssuer
  dnsNames:
    - mi-servicio.bonchan.org
```

O, cuando haya ingress controller, basta con la anotación `cert-manager.io/cluster-issuer: letsencrypt-prod` en el Ingress.

Verificación:

```bash
kubectl get clusterissuers          # READY=True cuando el token funciona
kubectl describe certificate <name> # estado de la emisión
```
