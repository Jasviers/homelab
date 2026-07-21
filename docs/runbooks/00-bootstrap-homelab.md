# 00 — Bootstrap del homelab desde cero

Despliegue completo del homelab desde hardware recién instalado hasta el
clúster k3s con todos los servicios GitOps funcionando.

## Objetivo y cuándo usarlo

Reconstruir el homelab al completo: configuración de Proxmox y quorum, template
de VM con Packer, despliegue de VMs con Terraform, instalación de k3s con Ansible
y arranque de los servicios del clúster vía ArgoCD (GitOps). Útil para una
instalación inicial, una reconstrucción tras un desastre total, o como
referencia del orden correcto de las piezas.

- **Tiempo estimado:** 2–4 horas (la mayor parte es espera de builds y syncs).
- **Riesgo:** alto si se ejecuta sobre infraestructura existente — algunos pasos
  son destructivos (Terraform recrea VMs). En instalación inicial, bajo.

Cada paso indica si es **🤖 automatizado** o **✋ manual**. El objetivo a largo
plazo es minimizar los ✋ (ver `TODO.md`).

## Prerrequisitos

- **Hardware listo:**
  - NAS Synology (`nas.bonchan.org`, `192.168.1.1`) encendido, con servicio
    iSCSI activado y un usuario en el grupo `administrators`.
  - Raspberry Pi 4B (`luffy`, `192.168.1.2`) con Ubuntu/Debian y SSH.
  - Dos nodos Proxmox VE (`zoro` `192.168.1.3`, `nami` `192.168.1.4`).
- **Red:** red plana `192.168.0.0/23`, router ASUS en `192.168.0.1`, rango
  `192.168.1.128/25` reservado para `LoadBalancer` (Cilium LB IPAM, fuera del DHCP). Ver `README.md`.
- **DNS de la zona:** `bonchan.org` gestionada en Cloudflare.
- **Acceso SSH** por clave a `luffy`, `zoro` y `nami` como `root`
  (clave `~/.ssh/id_ed25519`, ver `ansible/inventory.ini`).
- **Herramientas locales:** `packer >= 1.10`, `terraform >= 1.5`, `ansible`,
  `kubectl`, `helm`, `git`. Plugin Helm de kustomize disponible (`kustomize` con
  `--enable-helm`). `helm` y `kubectl` son necesarios además para que el rol
  `install-k3s` despliegue Cilium desde tu máquina.
- **Secrets a mano** (no versionados, se crean durante el proceso):
  - API token de Cloudflare (`Zone / DNS / Edit` + `Zone / Zone / Read` sobre
    `bonchan.org`).
  - Credenciales del DSM del NAS (IP, usuario, contraseña).
  - Token de Proxmox para Packer/Terraform.

---

## Fase 1 — Configuración de Proxmox (✋/🤖)

### 1.1 Repos sin suscripción y quorum (🤖 Ansible)

Configura los repos `no-subscription` en ambos nodos y monta el QDevice de
quorum usando `luffy` como árbitro (clave para que un clúster de 2 nodos
mantenga quorum si cae uno).

```bash
cd ansible

# Solo repos (opcional, qdevice.yml ya lo importa):
ansible-playbook playbooks/proxmox-repos.yml

# Repos + QDevice de quorum (proxmox + raspberry_pi):
ansible-playbook playbooks/qdevice.yml
```

*Resultado esperado:* playbooks en verde. El quorum se verifica en la Fase 6.

### 1.2 Token de API de Proxmox (✋ manual)

En la UI de Proxmox (*Datacenter → Permissions → API Tokens*) crea un token con
privilegios para crear/clonar VMs. Anótalo en formato
`USER@REALM!TOKENID=UUID`; lo usarán Packer y Terraform.

---

## Fase 2 — Template de VM con Packer (🤖)

Construye el template `ubuntu26-template` en Proxmox (autoinstall de Ubuntu 26 +
provisión con Ansible vía `playbooks/packer-template.yml`).

```bash
cd packer/ubuntu26

# Completa las variables (proxmox_url, proxmox_username, proxmox_token,
# proxmox_node, ssh_public_key_file, etc.) en un archivo .pkrvars.hcl
packer init .
packer build -var-file=variables.auto.pkrvars.hcl .
```

*Resultado esperado:* aparece la plantilla `ubuntu26-template` en el nodo
Proxmox indicado. Ver `packer/README.md`.

---

## Fase 3 — VMs del clúster con Terraform (🤖)

Clona el template y crea las 5 VMs del clúster con roles heterogéneos: 2
control-plane (`vm-ubuntu26-zoro-01` `192.168.1.21`, `vm-ubuntu26-nami-01`
`192.168.1.22`, 2 vCPU/2 GB cada una), 2 workers (`vm-ubuntu26-zoro-02`
`192.168.1.30`, `vm-ubuntu26-nami-02` `192.168.1.31`, 4 vCPU/6 GB) y 1 nodo de
IA (`vm-ubuntu26-zoro-ai` `192.168.1.40`, 8 vCPU/48 GB).

```bash
cd terraform/proxmox-vm

cp terraform.tfvars.example terraform.tfvars
# Edita terraform.tfvars: proxmox_endpoint, proxmox_api_token, template,
# ssh_keys, ipv4_gateway... (las IPs/VMIDs/sizing de cada VM están en el mapa
# `vms` de terraform.tfvars, con overrides por VM de cores/memory/disk_gb)

terraform init
terraform plan
terraform apply
```

*Resultado esperado:* `terraform apply` crea las 5 VMs. Comprueba las salidas:

```bash
terraform output vm_ids
terraform output ipv4_addresses
```

---

## Fase 4 — Instalación de k3s con Ansible (🤖)

Instala k3s con roles diferenciados según el grupo de `ansible/inventory.ini`:
los 2 nodos de `k3s_control_plane` se instalan como **server** con etcd
embebido (el primero con `--cluster-init`, el segundo se une con
`--server`/`--token`) y quedan tainted (`node-role.kubernetes.io/control-plane`)
para no recibir cargas; los nodos de `k3s_workers` y `k3s_ai` se instalan como
**agent** (worker), y el de `k3s_ai` añade además el taint `dedicated=ai` y el
label `workload-type=ai` para que solo se programen ahí los pods que declaren
la toleration/selector correspondiente. Se despliega sin `servicelb`, `traefik`
ni `local-storage` (el `LoadBalancer` lo da Cilium y el almacenamiento el CSI
de Synology) y sin el networking integrado (`flannel`, `kube-proxy`,
`network-policy`), que se sustituye por **Cilium** (con tolerations para correr
también en los nodos tainted). El propio rol instala Cilium vía Helm desde tu
máquina (requiere `helm` y `kubectl` locales) usando el endpoint
`127.0.0.1:6443` del apiserver, con LB IPAM y anuncios L2 habilitados. Al final
descarga el kubeconfig a `~/.kube/config`.

> El quorum de etcd es 2/2 (2 control-plane): perder cualquiera de los dos deja
> el API server sin quorum. Es una limitación aceptada, no un bug.

```bash
cd ansible
ansible-playbook playbooks/install-k3s.yml
```

---

## Fase 5 — Servicios del clúster (GitOps) (🤖/✋)

El orden importa porque el clúster no trae LoadBalancer ni ingress por defecto.
Detalle completo en `services/README.md`.

### 5.1 Cilium LB IPAM (🤖)

El dataplane de Cilium (con LB IPAM y L2 habilitados) ya lo instaló la Fase 4;
aquí solo se aplica el pool de IPs y la política de anuncio L2.

```bash
kustomize build services/cilium-lb | kubectl apply -f -
```

*Resultado esperado:* `CiliumLoadBalancerIPPool` `pool` con el rango
`192.168.1.128/25` y la `CiliumL2AnnouncementPolicy` `pool` (sobre `eth0`).
Comprobar: `kubectl get ciliumloadbalancerippool,ciliuml2announcementpolicy`.

### 5.2 ArgoCD (🤖)

```bash
kustomize build --enable-helm services/argocd | kubectl apply -f -
```

Contraseña inicial del admin:

```bash
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d; echo
```

### 5.3 App-of-apps (🤖)

A partir de aquí ArgoCD sincroniza el resto desde el repo (cert-manager,
gateway, homepage, synology-csi, kubevip, authentik, cnpg-operator y el propio
argocd).

```bash
kubectl apply -f services/argocd-apps/root-app.yaml
```

*Resultado esperado:* las `Application` aparecen en ArgoCD. Algunas quedarán
`Degraded`/`Progressing` hasta crear los secrets manuales del paso 5.4.

### 5.4 Secrets manuales (✋ — imprescindible)

Estos secrets **no se versionan en git**; sin ellos cert-manager y Synology CSI
no funcionan.

**Cloudflare (cert-manager):**

```bash
kubectl -n cert-manager create secret generic cloudflare-api-token \
  --from-literal=api-token=<CLOUDFLARE_API_TOKEN>
```

**Credenciales del NAS (Synology CSI):**

```bash
cp services/synology-csi/client-info.example.yml services/synology-csi/client-info.yml
# edita client-info.yml con IP/usuario/contraseña del DSM, luego:
kubectl -n synology-csi create secret generic client-info-secret \
  --from-file=client-info.yml=services/synology-csi/client-info.yml
```

**`secret_key` de Authentik:** la contraseña de su base de datos la genera CNPG;
solo hay que crear la `secret_key`:

```bash
kubectl -n authentik create secret generic authentik-secret \
  --from-literal=secret_key=$(openssl rand -base64 60 | tr -d '\n')
```

**Credenciales de admin de Grafana:**

```bash
kubectl -n monitoring create secret generic grafana-admin \
  --from-literal=admin-user=admin \
  --from-literal=admin-password=<PASSWORD>
```

**SSO de ArgoCD con Authentik (OIDC):** el mismo `client_secret` lo conocen los
dos lados. Authentik lo lee por entorno (`authentik-oidc-secrets`) para aplicar el
blueprint; ArgoCD lo lee desde `argocd-secret` (clave `oidc.argocd.clientSecret`):

```bash
ARGOCD_OIDC_SECRET=$(openssl rand -base64 32 | tr -d '\n')

# Authentik: lo consume el worker para reconciliar el blueprint del provider.
kubectl -n authentik create secret generic authentik-oidc-secrets \
  --from-literal=argocd-client-secret="$ARGOCD_OIDC_SECRET"

# ArgoCD: lo resuelve oidc.config vía $oidc.argocd.clientSecret.
kubectl -n argocd patch secret argocd-secret --type merge \
  -p "{\"stringData\":{\"oidc.argocd.clientSecret\":\"$ARGOCD_OIDC_SECRET\"}}"
```

Tras el primer sync, asigna tu usuario al grupo `ArgoCD Admins` (creado por el
blueprint) en Authentik para tener rol admin. Reinicia `argocd-server` si no
aparece el botón de login con Authentik:
`kubectl -n argocd rollout restart deploy/argocd-server`.

**SSO de Grafana con Authentik (OIDC):** mismo esquema que ArgoCD. Authentik lee
el secret por entorno (`authentik-oidc-secrets`, clave `grafana-client-secret`) y
Grafana desde el secret `grafana-oidc`:

```bash
GRAFANA_OIDC_SECRET=$(openssl rand -base64 32 | tr -d '\n')

# Authentik: añade la clave al secret ya existente (lo recrea con ambas claves).
kubectl -n authentik patch secret authentik-oidc-secrets --type merge \
  -p "{\"stringData\":{\"grafana-client-secret\":\"$GRAFANA_OIDC_SECRET\"}}"

# Grafana: secret que consume el contenedor vía GF_AUTH_GENERIC_OAUTH_CLIENT_SECRET.
kubectl -n monitoring create secret generic grafana-oidc \
  --from-literal=client-secret="$GRAFANA_OIDC_SECRET"
```

Asigna tu usuario a `Grafana Admins` (o `Grafana Editors`) en Authentik; sin
grupo se entra como `Viewer`. El admin local sigue disponible en `/login`.

**SSO de Hubble UI con Authentik (OIDC):** Hubble UI no tiene login propio, así
que la protege Envoy Gateway como Relying Party OIDC (ver `services/hubble`).
Authentik lee el secret por entorno (`authentik-oidc-secrets`, clave
`hubble-client-secret`) y Envoy desde el secret `hubble-oidc-secret` en
`kube-system` (clave `client-secret`):

```bash
HUBBLE_OIDC_SECRET=$(openssl rand -base64 32 | tr -d '\n')

# Authentik: añade la clave al secret ya existente (lo recrea con todas las claves).
kubectl -n authentik patch secret authentik-oidc-secrets --type merge \
  -p "{\"stringData\":{\"hubble-client-secret\":\"$HUBBLE_OIDC_SECRET\"}}"

# Envoy Gateway: secret que consume la SecurityPolicy OIDC de la ruta de Hubble.
kubectl -n kube-system create secret generic hubble-oidc-secret \
  --from-literal=client-secret="$HUBBLE_OIDC_SECRET"
```

La UI es de solo lectura; basta con que el usuario autentique en Authentik.

**Otros clientes OIDC de Authentik (Proxmox, router ASUS, Home Assistant):** a
diferencia de ArgoCD/Grafana/Hubble, el otro lado de estos 3 no es un Secret de
Kubernetes, sino configuración manual en cada sistema (Proxmox: *Datacenter →
Realms*; router ASUS: su propia config OIDC; Home Assistant: `configuration.yaml`
en `luffy`, ver `services/README.md`). Aun así, sus blueprints de Authentik
(`services/authentik/blueprints/`) esperan sus claves en `authentik-oidc-secrets`
**desde el primer arranque** (si faltan, `authentik-server`/`authentik-worker`
se quedan en `CreateContainerConfigError`):

```bash
PROXMOX_OIDC_SECRET=$(openssl rand -base64 32 | tr -d '\n')
ROUTER_OIDC_SECRET=$(openssl rand -base64 32 | tr -d '\n')
HA_OIDC_SECRET=$(openssl rand -base64 32 | tr -d '\n')

kubectl -n authentik patch secret authentik-oidc-secrets --type merge \
  -p "{\"stringData\":{\"proxmox-client-secret\":\"$PROXMOX_OIDC_SECRET\",\"router-client-secret\":\"$ROUTER_OIDC_SECRET\",\"home-assistant-client-secret\":\"$HA_OIDC_SECRET\"}}"
```

Copia cada valor a su sistema correspondiente (Proxmox, router, HA) cuando
configures su lado del OIDC.

---

## Fase 6 — Servicios en `luffy` (Pi-hole y Home Assistant) (🤖)

DNS local y automatización del hogar, en contenedores Docker sobre la Raspberry.

```bash
cd ansible
# Revisa/ajusta defaults sensibles (pihole_web_password, etc.) antes de ejecutar:
#   ansible/roles/home-services/defaults/main.yml
ansible-playbook playbooks/home-services.yml
```

*Resultado esperado:* Pi-hole sirviendo DNS local con los `host-record` de los
hosts del homelab (incluido `kubevip` `192.168.1.20`) y Home Assistant arriba.

---

## Verificación

```bash
# Quorum de Proxmox (en zoro o nami): debe verse Quorate: Yes y el QDevice
ssh root@zoro 'pvecm status'

# Nodos del clúster
kubectl get nodes

# Todas las Application sincronizadas
kubectl -n argocd get applications

# Emisor de certificados listo (depende del token de Cloudflare)
kubectl get clusterissuers

# Gateway con su IP y certificado wildcard
kubectl -n envoy-gateway-system get gateway homelab
kubectl get certificate -A

# StorageClass por defecto
kubectl get storageclass

# Acceso a los servicios (resolución vía Pi-hole)
#   https://argocd.bonchan.org
#   https://homepage.bonchan.org
```

Todo correcto cuando: el quorum está `Quorate`, los nodos `Ready`, todas las
`Application` en `Synced/Healthy`, el `ClusterIssuer` y el certificado wildcard
en `READY=True`, y los servicios responden por HTTPS bajo `*.bonchan.org`.

## Rollback / si algo falla

- **Packer falla a mitad de build:** suele dejar una VM temporal en Proxmox;
  elimínala antes de reintentar.
- **`kubectl` no conecta tras Ansible:** revisa que `~/.kube/config` apunte a la
  IP correcta del server (el playbook reescribe la URL).
- **`ClusterIssuer` no pasa a `READY`:** casi siempre es el token de Cloudflare
  (permisos o secret mal creado). `kubectl -n cert-manager describe clusterissuer letsencrypt`.
- **PVCs en `Pending`:** revisa el secret `client-info-secret`, que el usuario
  del DSM esté en `administrators` y que iSCSI esté activo en el NAS.
  `kubectl -n synology-csi logs sts/synology-csi-controller -c csi-plugin`.
- **Desinstalar k3s** (deja las VMs limpias para reintentar):

  ```bash
  cd ansible && ansible-playbook playbooks/uninstall-k3s.yml
  ```

- **Reconstrucción total de VMs:** `terraform destroy` en
  `terraform/proxmox-vm/` y vuelve a la Fase 3.

## Referencias

- Arquitectura general y diagramas: [README.md](../../README.md)
- Packer: [packer/README.md](../../packer/README.md)
- Terraform: [terraform/proxmox-vm/README.md](../../terraform/proxmox-vm/README.md)
- Ansible: [ansible/README.md](../../ansible/README.md)
- Servicios y orden de bootstrap: [services/README.md](../../services/README.md)
- Tareas y mejoras pendientes: [TODO.md](../../TODO.md)
