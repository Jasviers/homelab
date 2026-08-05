# 03 — Migración de disco de un nodo Proxmox

> Sustituir el disco físico de un nodo Proxmox del clúster (host completo, no
> solo un disco de datos) por uno nuevo, preservando las VMs que aloja.

## Objetivo y cuándo usarlo

- Sustitución de disco por avería, mejora de rendimiento (p. ej. pasar a un
  disco con caché DRAM para evitar cuellos de I/O como los descritos en
  [2026-07-27-etcd-fsync-kubevip-crashloop.md](../postmortems/2026-07-27-etcd-fsync-kubevip-crashloop.md)),
  o cualquier cambio de hardware que obligue a reinstalar Proxmox.
- Aplica a **cualquiera de los dos nodos** del clúster (`zoro` o `nami`); en
  los pasos, `<nodo>` es el que se migra y `<nodo-par>` el otro miembro del
  clúster que permanece arriba dando quorum (junto con el qdevice en `luffy`).
- **Tiempo estimado:** 1–3 horas (depende del tamaño de los discos a copiar).
- **Riesgo:** alto — implica parar VMs con estado (etcd, workers). Seguir el
  orden exacto de los pasos.

## Prerrequisitos

- SSH root a `<nodo>`, `<nodo-par>` y `luffy`.
- Storage NFS/CIFS accesible desde Proxmox para alojar backups temporales
  (p. ej. una carpeta compartida en el NAS Synology), con espacio libre ≥ la
  suma de los discos de las VMs a migrar.
- `ansible` y `kubectl` disponibles en local.
- Disco de reemplazo listo para el swap físico.
- Antes de empezar, obtén el inventario **real** de VMs de `<nodo>` — no
  asumas vmids ni cuántas hay, difieren entre `zoro` y `nami`:

  ```bash
  ssh root@<nodo> 'qm list'
  ```

  El mapa de referencia (nombres, vmid, tamaño) vive en
  `terraform/proxmox-vm/terraform.tfvars.example`, pero el estado en vivo
  puede diferir (VMs apagadas a propósito, etc.) — confía en `qm list`.

---

## Pasos

### 1. Decidir estrategia por VM: migración en vivo vs. backup/restore

Para cada VM en `<nodo>`, comprueba si `<nodo-par>` tiene margen de RAM/CPU
para alojarla temporalmente:

```bash
ssh root@<nodo-par> 'pvesh get /nodes/<nodo-par>/status --output-format json | grep -A2 memory'
ssh root@<nodo> 'qm list'   # memoria asignada de cada VM a migrar
```

- **Cabe con margen** → migración en vivo (paso 2A): sin downtime, sin
  backup/restore.
- **No cabe** (nodo par ya ajustado de RAM, o VM demasiado grande) →
  backup a NAS + restore tras reinstalar (paso 2B). Es la opción universal:
  úsala si tienes dudas o si el nodo par no tiene hueco.

Se puede combinar: migrar en vivo las VMs pequeñas y hacer backup/restore
solo de la(s) que no quepan.

### 2A. Opción preferente — Migración en vivo al nodo par

```bash
# Los discos son locales (local-lvm), no storage compartido → --with-local-disks
qm migrate <vmid> <nodo-par> --online --with-local-disks
```

*Resultado esperado:* `qm list` en `<nodo-par>` muestra la VM `running`, sin
corte de red apreciable.

Las VMs migradas así no necesitan el paso 2B; pasa directamente al 3.

### 2B. Opción universal — Backup a NAS + restore

1. Añade un storage temporal de backups en Proxmox (*Datacenter → Storage →
   Add → NFS*), apuntando a una carpeta del NAS.
2. Comprueba si `local-lvm` es thin (permite snapshot en caliente) o no:

   ```bash
   pvesm status
   ```

3. Backup de cada VM. Para las que llevan estado sensible a inconsistencias
   (control-plane/etcd) usa `--mode stop` (breve downtime, backup
   consistente); para el resto puedes usar `snapshot` si el storage lo
   soporta:

   ```bash
   vzdump <vmid> --storage <backup-nas> --mode stop --compress zstd
   ```

4. Si la VM es control-plane de etcd, añade una capa extra de seguridad
   antes del backup:

   ```bash
   ssh root@<nodo> 'k3s etcd-snapshot save'
   ```

5. Verifica que los ficheros `.vma.zst` aparecen en *Storage → Backups* del
   NAS. Opcional pero recomendado: restaura uno a un vmid de prueba
   (`qmrestore ... --unique`) para confirmar integridad antes de seguir.

### 3. Vaciar y apagar el nodo

```bash
ssh root@<nodo> 'qm list'   # confirmar que no queda ninguna VM running
ssh root@<nodo> 'qm shutdown <vmid>'   # para las que tengan backup pero sigan encendidas
```

### 4. Sustituir el disco y reinstalar Proxmox

1. Apaga `<nodo>` por completo y cambia el disco físico.
2. Instala Proxmox VE (misma versión que `<nodo-par>` — comprobar con
   `pveversion` antes de desmontar el disco viejo si es posible).

### 5. Reincorporar el nodo al clúster

```bash
# Desde <nodo>, unirse al clúster existente
pvecm add <ip-nodo-par>
```

```bash
cd ansible
ansible-playbook playbooks/proxmox-repos.yml -l <nodo>
ansible-playbook playbooks/proxmox-tuning.yml -l <nodo>
ansible-playbook playbooks/qdevice.yml
```

*Resultado esperado:* `pvecm status` muestra `Quorate: Yes` con ambos nodos
listados.

### 6. Recuperar las VMs

- **Migradas en vivo (2A):** muévelas de vuelta cuando `<nodo>` esté listo:

  ```bash
  qm migrate <vmid> <nodo> --online --with-local-disks
  ```

- **Restauradas desde backup (2B):** vuelve a montar el storage NFS de
  backups en el `<nodo>` reinstalado y restaura respetando el **vmid
  original** (para que Terraform/Ansible sigan cuadrando con el estado real):

  ```bash
  qmrestore <backup-file.vma.zst> <vmid> --storage local-lvm
  ```

### 7. Arrancar en orden

Arranca primero las VMs de control-plane/etcd, espera a que estén healthy, y
luego el resto (workers, nodo IA). Respeta el `startup_order` definido en
`terraform/proxmox-vm/terraform.tfvars` para saber qué va primero. **No**
arranques VMs que estuvieran apagadas a propósito antes de la migración —
comprueba el estado previo (memoria de sesiones/decisiones operativas
recientes) antes de asumir que "todo encendido" es lo correcto.

---

## Verificación

```bash
ssh root@<nodo> 'pvecm status'        # Quorate: Yes, ambos nodos listados
kubectl get nodes                     # todos Ready
kubectl -n kube-system get pods       # todos Running
scripts/etcd-disk-health.sh           # PSI io normal en el disco nuevo
kubectl get pvc -A | grep -v Bound    # no debe haber Pending
```

## Rollback / si algo falla

- Si `<nodo>` no consigue reincorporarse al clúster: revisar `pvecm status`
  en `<nodo-par>`; puede hacer falta `pvecm delnode <nodo>` antes de
  reintentar `pvecm add`.
- Si una VM restaurada no arranca: comprobar integridad del backup
  restaurándolo a un vmid de prueba (`qmrestore ... --unique`) antes de
  sobrescribir el original.
- Si el clúster pierde quorum durante la migración: seguir
  [01-recovery-parcial.md](01-recovery-parcial.md) (Escenario 2).
- No borres los backups del NAS hasta confirmar que el clúster restaurado
  lleva funcionando de forma estable al menos un ciclo completo (p. ej. 24h).

## Referencias

- Bootstrap completo: [00-bootstrap-homelab.md](00-bootstrap-homelab.md).
- Recovery parcial: [01-recovery-parcial.md](01-recovery-parcial.md).
- Postmortem que motivó esta necesidad:
  [2026-07-27-etcd-fsync-kubevip-crashloop.md](../postmortems/2026-07-27-etcd-fsync-kubevip-crashloop.md).
- Definición de VMs: `terraform/proxmox-vm/terraform.tfvars.example`.
- Script de diagnóstico de I/O: `scripts/etcd-disk-health.sh`.
