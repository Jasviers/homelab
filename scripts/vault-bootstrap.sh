#!/usr/bin/env bash
#
# Bootstrap único de Vault para el homelab. Se ejecuta UNA vez, después de que
# ArgoCD haya desplegado services/vault y services/external-secrets.
#
# Hace, en orden:
#   1. Init + unseal del Vault transit (raíz de confianza) y motor transit para
#      auto-unseal del Vault principal.
#   2. Crea el token de auto-unseal y lo guarda como secret vault-transit-token.
#   3. Reinicia el Vault principal (auto-unseal), lo inicializa y habilita KV v2 +
#      Kubernetes auth con un rol de solo-lectura para External Secrets Operator.
#   4. Siembra en kv/ todos los secretos del cluster (los mismos valores que antes
#      se creaban a mano en la sección 5.4 del runbook).
#
# Requisitos: kubectl con acceso al cluster. Guarda en lugar SEGURO las claves de
# unseal/recovery y los root tokens que imprime el script.
#
# ¡OJO! No es idempotente: relanzarlo sobre un Vault ya inicializado fallará en el
# init. Para resembrar secretos usa directamente `vault kv put` (ver más abajo).

set -euo pipefail

NS="vault"
ESO_NS="external-secrets"
TRANSIT_POD="vault-transit-0"
MAIN_POD="vault-0"

# Ejecuta un comando de vault dentro de un pod, con el token indicado.
vexec() { # <pod> <token> <args...>
  local pod="$1" token="$2"; shift 2
  kubectl -n "$NS" exec -i "$pod" -- sh -c "VAULT_TOKEN='$token' VAULT_ADDR=http://127.0.0.1:8200 $*"
}

echo "==> 1. Inicializando Vault transit ($TRANSIT_POD)"
TRANSIT_INIT=$(kubectl -n "$NS" exec -i "$TRANSIT_POD" -- \
  vault operator init -key-shares=1 -key-threshold=1 -format=json)
TRANSIT_UNSEAL=$(echo "$TRANSIT_INIT" | jq -r '.unseal_keys_b64[0]')
TRANSIT_ROOT=$(echo "$TRANSIT_INIT"  | jq -r '.root_token')

echo "    -> Desellando transit"
kubectl -n "$NS" exec -i "$TRANSIT_POD" -- vault operator unseal "$TRANSIT_UNSEAL" >/dev/null

echo "==> 2. Configurando motor transit + token de auto-unseal"
vexec "$TRANSIT_POD" "$TRANSIT_ROOT" "vault secrets enable transit" || true
vexec "$TRANSIT_POD" "$TRANSIT_ROOT" "vault write -f transit/keys/autounseal" >/dev/null

# Política que solo permite usar la clave de auto-unseal.
vexec "$TRANSIT_POD" "$TRANSIT_ROOT" "vault policy write autounseal - <<'EOF'
path \"transit/encrypt/autounseal\" { capabilities = [\"update\"] }
path \"transit/decrypt/autounseal\" { capabilities = [\"update\"] }
EOF" >/dev/null

AUTOUNSEAL_TOKEN=$(vexec "$TRANSIT_POD" "$TRANSIT_ROOT" \
  "vault token create -policy=autounseal -orphan -period=24h -format=json" | jq -r '.auth.client_token')

echo "    -> Guardando secret vault-transit-token en ns $NS"
kubectl -n "$NS" create secret generic vault-transit-token \
  --from-literal=token="$AUTOUNSEAL_TOKEN" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "==> 3. Reiniciando Vault principal para que tome el token y auto-deselle"
kubectl -n "$NS" delete pod "$MAIN_POD" --ignore-not-found
kubectl -n "$NS" rollout status statefulset/vault --timeout=180s

echo "    -> Inicializando Vault principal (recovery keys por auto-unseal)"
MAIN_INIT=$(kubectl -n "$NS" exec -i "$MAIN_POD" -- \
  vault operator init -recovery-shares=1 -recovery-threshold=1 -format=json)
MAIN_ROOT=$(echo "$MAIN_INIT" | jq -r '.root_token')

echo "    -> Habilitando KV v2 en kv/ y Kubernetes auth para ESO"
vexec "$MAIN_POD" "$MAIN_ROOT" "vault secrets enable -path=kv kv-v2" || true
vexec "$MAIN_POD" "$MAIN_ROOT" "vault auth enable kubernetes" || true
vexec "$MAIN_POD" "$MAIN_ROOT" \
  "vault write auth/kubernetes/config kubernetes_host=https://kubernetes.default.svc" >/dev/null

# Política de solo-lectura sobre todos los secretos kv/.
vexec "$MAIN_POD" "$MAIN_ROOT" "vault policy write external-secrets - <<'EOF'
path \"kv/data/*\" { capabilities = [\"read\"] }
path \"kv/metadata/*\" { capabilities = [\"read\", \"list\"] }
EOF" >/dev/null

vexec "$MAIN_POD" "$MAIN_ROOT" \
  "vault write auth/kubernetes/role/external-secrets \
     bound_service_account_names=external-secrets \
     bound_service_account_namespaces=$ESO_NS \
     policies=external-secrets ttl=1h" >/dev/null

echo "==> 4. Sembrando secretos en kv/"
# put <ruta-kv> <clave=valor> [clave=valor ...]
put() { local path="$1"; shift; vexec "$MAIN_POD" "$MAIN_ROOT" "vault kv put kv/$path $*" >/dev/null; echo "    -> kv/$path"; }
ask()  { local var="$1" prompt="$2"; read -rsp "$prompt: " "$var"; echo; }

ask CF_TOKEN          "Cloudflare API token (cert-manager)"
ask AUTHENTIK_SECRET  "Authentik secret_key (vacío = generar)"
[ -z "$AUTHENTIK_SECRET" ] && AUTHENTIK_SECRET=$(openssl rand -base64 60 | tr -d '\n')
ask GRAFANA_PASS      "Grafana admin password"
ask ARGOCD_OIDC       "client_secret OIDC de ArgoCD"
ask GRAFANA_OIDC      "client_secret OIDC de Grafana"
ask HUBBLE_OIDC       "client_secret OIDC de Hubble"
ask PROXMOX_OIDC      "client_secret OIDC de Proxmox"
ask ROUTER_OIDC       "client_secret OIDC de Router"
ask HA_OIDC           "client_secret OIDC de Home Assistant"

put cert-manager/cloudflare "api-token='$CF_TOKEN'"
put authentik/secret-key    "secret_key='$AUTHENTIK_SECRET'"
put authentik/oidc \
  "argocd-client-secret='$ARGOCD_OIDC'" \
  "grafana-client-secret='$GRAFANA_OIDC'" \
  "hubble-client-secret='$HUBBLE_OIDC'" \
  "proxmox-client-secret='$PROXMOX_OIDC'" \
  "router-client-secret='$ROUTER_OIDC'" \
  "home-assistant-client-secret='$HA_OIDC'"
put grafana/admin "admin-user=admin" "admin-password='$GRAFANA_PASS'"
put grafana/oidc  "client-secret='$GRAFANA_OIDC'"
put hubble/oidc   "client-secret='$HUBBLE_OIDC'"
put argocd/oidc   "clientSecret='$ARGOCD_OIDC'"

echo
echo "    Synology y túnel de Cloudflare usan ficheros; siémbralos así:"
echo "      vault kv put kv/synology/client-info client-info.yml=@client-info.yml"
echo "      vault kv put kv/cloudflared/tunnel credentials.json=@credentials.json"
echo "    (ejecútalo desde dentro de $MAIN_POD con VAULT_TOKEN del root)"

cat <<EOF

==========================================================================
 GUARDA ESTAS CREDENCIALES EN UN LUGAR SEGURO (NO en git):

   Transit  unseal key : $TRANSIT_UNSEAL
   Transit  root token : $TRANSIT_ROOT
   Vault recovery keys : $(echo "$MAIN_INIT" | jq -r '.recovery_keys_b64[0]')
   Vault    root token : $MAIN_ROOT

 Tras un reinicio total del cluster solo hay que desellar el transit:
   kubectl -n $NS exec -it $TRANSIT_POD -- vault operator unseal <unseal-key>
==========================================================================
EOF
