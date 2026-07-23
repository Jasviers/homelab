# 01 — Recovery parcial del homelab

Escenarios de recuperación parcial: caída de un nodo, pérdida de quorum o
pérdida de datos en el NAS.

## Objetivo y cuándo usarlo

Cuando algo falla a nivel parcial (un nodo Proxmox, el quorum, un disco del NAS)
y no se necesita reconstruir todo el homelab. Para una reconstrucción completa
ver [00-bootstrap-homelab.md](00-bootstrap-homelab.md).

- **Tiempo estimado:** 30 min – 2 horas según el escenario.
- **Riesgo:** medio — algunos pasos son destructivos para el nodo afectado.

---

## Escenario 1 — Caída de un nodo Proxmox

Si un nodo (`zoro` o `nami`) cae y el otro sigue funcionando:

### 1.1 Diagnosticar

```bash
# En el nodo superviviente (p. ej. nami):
ssh root@nami 'pvecm status'
# Debe verse "Quorate: Yes" — el QDevice (luffy) mantiene el quorum.

# Comprobar qué VMs quedaron en Running:
ssh root@nami 'qm list'
```

### 1.2 Migrar VMs manualmente (si el nodo caído no vuelve)

Si el nodo no va a volver y necesitas las VMs en el nodo superviviente:

```bash
# En el nodo superviviente, eliminar el nodo caído del clúster
ssh root@nami 'pvecm nodes'
ssh root@nami 'pvecm delnode zoro'  # solo si zoro está realmente caído

# Recrear las VMs que estaban en zoro con Terraform
cd terraform/proxmox-vm
terraform plan -target=module.vms["zoro"]
terraform apply -target=module.vms["zoro"]
```

### 1.3 Reconstruir el nodo

1. Reinstalar Proxmox en el hardware.
2. Añadir el nodo al clúster desde `nami`: `pvecm add <IP-nami>`.
3. Configurar repos: `ansible-playbook playbooks/proxmox-repos.yml -l <nodo>`.
4. Volver a unir al QDevice: `ansible-playbook playbooks/qdevice.yml`.

---

## Escenario 2 — Pérdida de quorum (ambos control-plane caen)

El quorum de etcd es 2/2: si caen ambos control-plane, el API server se queda
sin quorum y el clúster deja de funcionar.

### 2.1 Diagnosticar

```bash
# Desde un worker o vía SSH directo a un nodo:
ssh root@zoro 'systemctl status k3s'
# Verás "etcd cluster has no healthy member" o similar.
```

### 2.2 Recuperar si al menos un nodo vuelve

1. Arranca el nodo que falte (o reinstálalo si está dañado).

2. En el nodo que ya estaba arrancado, reiniciar k3s:

   ```bash
   ssh root@zoro 'systemctl restart k3s'
   ```

3. Esperar ~30s y comprobar quorum:

   ```bash
   kubectl get nodes
   kubectl -n kube-system get pods -l app.kubernetes.io/name=etcd
   ```

### 2.3 Recuperar si ambos están perdidos (restauración de etcd)

Si no queda ningún nodo con etcd funcional, hay que restaurar desde un backup:

```bash
# En el nodo que vaya a ser el primero en arrancar:
ssh root@zoro

# Detener k3s
systemctl stop k3s

# Restaurar desde el backup más reciente de etcd
k3s etcd-snapshot restore --data-dir /var/lib/rancher/k3s/server/db \
  --name $(ls -t /var/lib/rancher/k3s/server/db/snapshots/ | head -1)

# Reiniciar
systemctl start k3s

# En el segundo nodo, unirse al cluster restaurado
ssh root@nami
systemctl stop k3s
rm -rf /var/lib/rancher/k3s/server/db/*
k3s agent --server https://zoro:6443 --token <token>
```

> **Nota:** si no hay snapshots de etcd, la única opción es un `k3s-uninstall.sh`
> seguido de un `install-k3s.yml` completo (ver runbook 00).

---

## Escenario 3 — Pérdida de un disco del NAS / corrupción de LUNs iSCSI o carpetas NFS

Si un disco del Synology falla, las LUNs iSCSI se corrompen, o falla el
servicio NFS / las carpetas compartidas que respaldan `synology-nfs-storage`:

### 3.1 Diagnosticar

```bash
# Comprobar el estado del StorageClass
kubectl get storageclass
kubectl get pv | grep -i pending

# Ver logs del Synology CSI
kubectl -n synology-csi logs sts/synology-csi-controller -c csi-plugin --tail=50
```

### 3.2 Si el NAS sigue accesible pero las LUNs/carpetas están dañadas

1. En la DSM, eliminar las LUNs dañadas y recrearlas con el mismo `location`
   (`/volume1` para `synology-iscsi-storage`), o recrear la carpeta compartida
   `nfs_kubernetes` (`/volume1/nfs_kubernetes` para `synology-nfs-storage`),
   reactivando el servicio NFS y los permisos (lectura/escritura, sin *root
   squash*, subred de los nodos) si hiciera falta.
2. El Synology CSI re-creará los PVs dinámicamente al hacer `kubectl apply` de
   `storage-class.yml` / `storage-class-nfs.yml` de nuevo.

### 3.3 Si el NAS completo está perdido

1. Restaurar datos desde backup (si existe).

2. Recrear las LUNs iSCSI y la carpeta compartida NFS (`nfs_kubernetes`,
   con el servicio NFS activado y permisos para la subred de los nodos) en el
   DSM nuevo.

3. Recrear el Secret `client-info-secret`:

   ```bash
   cp services/synology-csi/client-info.example.yml services/synology-csi/client-info.yml
   # Editar con las credenciales del DSM
   kubectl -n synology-csi create secret generic client-info-secret \
     --from-file=client-info.yml=services/synology-csi/client-info.yml
   ```

4. Los PVs existentes quedarán en `Released` o `Failed`; hay que eliminarlos y
   recrear los PVCs:

   ```bash
   kubectl delete pv <pv-name>
   # Los pods que usaban ese PVC perderán los datos; si hay backups con Velero,
   # restaurar desde ahí.
   ```

---

## Verificación tras recovery

```bash
# Quorum
ssh root@zoro 'pvecm status'  # Quorate: Yes

# Nodos k3s
kubectl get nodes  # Todos Ready

# Pods del sistema
kubectl -n kube-system get pods  # Todos Running

# PVCs
kubectl get pvc -A | grep -v Bound  # No debe haber Pending

# Servicios accesibles
kubectl -n envoy-gateway-system get gateway homelab
```

## Referencias

- Bootstrap completo: [00-bootstrap-homelab.md](00-bootstrap-homelab.md).
- Estructura del repo: [README.md](../../README.md).
- Servicios: [services/README.md](../../services/README.md).
