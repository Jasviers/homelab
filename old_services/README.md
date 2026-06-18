# Servicios retirados

Manifiestos de servicios que **ya no se despliegan** en el clúster, conservados como
referencia histórica. **No los vigila ArgoCD** (el *app-of-apps* solo apunta a
`services/argocd-apps/`), así que están aquí únicamente para consulta y para poder
recuperar la configuración sin tener que buscar la versión del código que la contenía.

## metallb/

MetalLB como balanceador `LoadBalancer` (rango `192.168.1.128/25`, modo L2). Sustituido por
**Cilium** (LB IPAM + L2 announcements) — ver `services/cilium-lb/` y los valores de Cilium en
`ansible/roles/install-k3s/templates/cilium-values.yaml.j2`.

- `metallb/`: kustomization (chart oficial v0.16.1) + `namespace.yaml` + `pool.yaml`.
- `argo-apps/metallb-app.yaml`: la `Application` de ArgoCD que lo gestionaba.
