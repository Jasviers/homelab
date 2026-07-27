# 2026-07-27 — Crash-loop de kube-vip por latencia de fsync de etcd

## Resumen

Los NVMe genéricos de los hosts Proxmox rinden ~100 fsync/s (deberían ser miles), esto se debe a la mala calidad de los discos de los servidores, y una VM
worker con carga de media saturaba el disco compartido con las VMs de etcd. La latencia de etcd
se disparó a ~5 s, kube-vip no podía renovar su lease y entraba en crash-loop (295-337 reinicios),
lo que hacía parpadear la VIP de la API de k8s y provocaba reinicios en cascada de pods por todo
el cluster.

## Impacto

- **Servicios afectados:** plano de control de k8s (VIP `192.168.1.20` inestable) y, en cascada,
  probes fallando en `authentik` (SSO), `jellyfin`, `grafana`/`alloy` (monitorización),
  `kube-state-metrics` y `cnpg`. Degradación intermitente, no caída total.
- **Duración:** condición crónica/intermitente durante ~5 días (reinicios de kube-vip
  acumulándose); mitigación aguda el 27-jul ~19:00–19:15 (CEST), ~30-40 min desde el diagnóstico.
- **Alcance:** homelab completo; sin usuarios externos. Sin interrupción total de servicios, sí
  inestabilidad y latencia perceptible en logins (authentik) y APIs.
- **Pérdida de datos:** no. etcd conservó quorum (3 miembros) en todo momento; solo latencia.

## Detección

- **Cómo:** reporte manual del usuario ("el cluster parece que tiene algún problema y se están
  reiniciando los pods"). **No había alerta** que lo detectara automáticamente.
- **Tiempo hasta detección:** días. Los reinicios de kube-vip llevaban acumulándose ~5 días sin
  que nadie lo notara, porque la VIP se recuperaba sola tras cada reinicio y el impacto era
  intermitente.

## Timeline

Horas en zona local (Europe/Madrid), aproximadas.

| Hora | Evento |
| --- | --- |
| ~5 días antes | kube-vip empieza a acumular reinicios (295→337); latencia de etcd degradándose sin alerta. |
| 27-jul, mañana | En logs de kube-vip: `failed to renew lease ... context deadline exceeded` → `fatal: lost leadership, restarting`. |
| 27-jul, tarde | El usuario reporta pods reiniciándose. Comienza la investigación. |
| ~19:00 | Diagnóstico: p99 apiserver→etcd `update` 4.8 s / `list` 8 s con CPU/RAM bajos → capa de disco. `pveperf`+`dd` confirman **~100 fsync/s** en el NVMe. VM `nami-02` (media) satura el disco de `nami` (SSH al host y a la VM llegan a dar timeout). |
| ~19:05 | Mitigación 1: `etcd-arg heartbeat-interval=500/election-timeout=5000` en los 3 control-plane; reinicio *rolling* de k3s (quorum intacto). Baja el *churn* de líder pero no la latencia. |
| ~19:14 | Mitigación 2 (decisiva): **throttle de I/O a la VM `vm-221` (nami-02)** en Proxmox. La latencia de etcd cae de ~4.7 s a ~1 s y **kube-vip deja de reiniciarse**. |
| 19:38 | Verificado estable: 6 nodos `Ready`, kube-vip sin reinicios ~21 min, cascada de timeouts parada. |

## Causa raíz

Cadena completa (técnica de los "5 porqués"):

1. **Los pods se reiniciaban** → porque sus *probes* (readiness/liveness) daban timeout
   (`context deadline exceeded`) y la VIP de la API parpadeaba.
2. **La VIP parpadeaba** → porque `kube-vip` hacía `fatal: lost leadership, restarting`.
3. **kube-vip perdía el liderazgo** → porque no lograba renovar su lease (`plndr-cp-lock`, un
   `update` contra etcd) dentro del `renewDeadline` por defecto (3 s).
4. **El `update` a etcd tardaba ~5 s** → porque el fsync del disco de etcd estaba disparado. La
   VM worker `nami-02` (jellyfin/sonarr, ~11,5 TB leídos acumulados) saturaba el NVMe que
   comparte físicamente con la VM de etcd `nami-01` en el host `nami`.
5. **El fsync colapsaba bajo esa contención** → porque el disco es un **NVMe genérico QLC sin
   DRAM ni PLP** (`Shenzhen Wodposit WPBSNM8-512GMP`) que rinde **~100 fsync/s** (etcd necesita
   >2000), y **todas** las VMs (etcd incluidas) comparten el mismo `local-lvm` sobre ese disco.

Causa raíz de fondo: **hardware de disco inadecuado para etcd + ausencia de aislamiento de I/O**
entre las VMs de control-plane y las de carga pesada.

## Qué funcionó / qué costó

- **Funcionó bien:**
  - La métrica `etcd_request_duration_seconds` (vía Prometheus) apuntó directa a la capa de
    disco al ver CPU/RAM bajos.
  - etcd mantuvo quorum (3 miembros) durante todo el incidente y los reinicios *rolling* de k3s;
    cero pérdida de datos.
  - El throttle de I/O a nivel de Proxmox (host) funcionó aun cuando la VM saturada no era
    accesible por SSH.
- **Costó / faltó:**
  - **No había alerta**: el incidente llevaba ~5 días activo y se detectó por casualidad.
  - Métricas de etcd del servidor (`etcd_disk_wal_fsync_duration_seconds`) **no se scrapean**;
    hubo que inferir el fsync con `pveperf`/`dd` por SSH.
  - Bajo saturación, el propio acceso (SSH al host y a la VM) daba timeout, dificultando el
    diagnóstico en caliente.
  - Diseño: VMs de etcd y de carga pesada compartiendo un disco lento, sin límites de I/O.

## Acciones de mejora

- [ ] **Disco dedicado a etcd (fix definitivo):** instalar un SSD SATA con DRAM+TLC
      (Transcend MTS430S 128GB) en la ranura M.2 2242 libre de cada host, datastore `local-ssd`
      dedicado, y mover ahí los discos de las VMs de etcd. Ver plan y runbook (crear
      `docs/runbooks/03-migrar-etcd-a-disco-dedicado.md`). Al terminar, **retirar el throttle**.
- [ ] **Alerta de kube-vip / etcd:** alerta en Prometheus por `kube_pod_container_status_restarts_total`
      de kube-vip creciendo y por p99 alto de `etcd_request_duration_seconds` / apiserver.
- [ ] **Scrapear métricas del etcd embebido de k3s** (fsync/backend commit, leader changes).
- [ ] **Persistir los límites de I/O en IaC:** el throttle de `vm-221` es un parche en vivo; no
      está en `terraform/modules/proxmox-vm`. Añadir soporte de `iops`/`mbps` por VM o
      documentarlo para que no se pierda si se recrea la VM.
- [ ] **Desplegar** el tuning de timeouts de kube-vip (`services/kubevip/kustomization.yml`) vía
      commit+push → ArgoCD (margen extra ante futuros picos).
- [ ] **RAM de `nami`** (15 GiB, muy justo) y valorar **UPS** (los SSD de consumo no tienen PLP).
- [ ] Añadir esta entrada a `TODO.md`.

## Referencias

- Runbooks relacionados: [`docs/runbooks/01-recovery-parcial.md`](../runbooks/01-recovery-parcial.md)
  (quorum de etcd).
- Plan de estabilización y mejora de discos (con todos los datos medidos):
  `~/.claude/plans/el-cluster-de-k8s-floating-hopcroft.md`.
- Cambios de la mitigación:
  - `services/kubevip/kustomization.yml` — `vip_leaseduration/renewdeadline/retryperiod`.
  - `ansible/roles/install-k3s/tasks/main.yml` — `--etcd-arg heartbeat-interval/election-timeout`.
  - `services/ollama/job-pull-models.yml` — `nodeSelector`/`tolerations` al nodo de IA.
  - En vivo (no en repo): `etcd-arg` en `/etc/rancher/k3s/config.yaml` de los 3 CP; throttle
    `iops_rd=2000,iops_wr=1000,mbps_rd=150,mbps_wr=100` en `vm-221`.
- Evidencia clave: `pveperf` → `FSYNCS/SECOND: 103/110`; apiserver→etcd p99 `update` 4.8 s → ~1 s
  tras la mitigación.
