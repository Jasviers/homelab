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

## ollama/

[Ollama](https://ollama.com) en el antiguo nodo de IA (`vm-ubuntu26-zoro-ai`, 8 vCPU / 16 GB, sin
GPU), sirviendo **Qwen3 1.7B** para *tool calling* desde Home Assistant en `ollama.bonchan.org`.
Retirado en octubre de 2026 junto con la VM de IA: reservaba 16 GB y 8 vCPU de `zoro` para ~20
tokens/s, y esos recursos se repartieron entre los workers.

- `ollama/`: kustomization (Deployment, PVC de 40Gi en `synology-nfs-storage`, Service, HTTPRoute,
  BackendTrafficPolicy y `Job` de descarga de modelos).
- `argo-apps/ollama-app.yaml`: la `Application` de ArgoCD que lo gestionaba.

Para recuperarlo: devolver ambos a `services/`, volver a añadir `ollama` a la allowlist de
`services/gateway/gateway.yml`, el `host` en `services/coredns/coredns-custom.yml` y la URL en
`services/monitor/blackbox-exporter/probes-http.yaml`. Los manifiestos llevan `nodeSelector:
{workload-type: ai}` y la toleration `dedicated=ai`: sin un nodo de IA hay que quitarlos (y bajar
los `requests`/`limits`, pensados para un nodo de 8 vCPU).

## kubevip/

[kube-vip](https://kube-vip.io) publicando la VIP `192.168.1.20` para el API de k3s (modo ARP,
*leader election* entre los control-plane). Retirado en octubre de 2026 al pasar a un único
control-plane (`zoro-01`): sin un segundo nodo al que conmutar la VIP no aporta nada, y nadie la
usaba (kubeconfig, agents y Cilium apuntan a `192.168.1.21`).

- `kubevip/`: kustomization (chart oficial v0.9.9) + `namespace.yaml`.
- `argo-apps/kubevip-app.yaml`: la `Application` de ArgoCD que lo gestionaba.

Para recuperarlo (solo tiene sentido con 3 control-plane): devolver ambos a `services/`, reinstalar
los servers de k3s con `--tls-san 192.168.1.20`, y restaurar el `host-record` `kubevip` en
`ansible/roles/home_services/defaults/main.yml` y la alerta `rules-kube-vip.yaml` de Grafana (en el
historial de git).
