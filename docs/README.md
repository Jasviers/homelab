# Documentación operativa

Manuales paso a paso y análisis post-incidente del homelab. Complementa a los
READMEs de cada carpeta (que describen *qué* es cada componente) con el *cómo*
operarlo y el *qué hacer cuando algo falla*.

## Estructura

| Carpeta | Contenido |
| --- | --- |
| [runbooks/](runbooks/) | Manuales paso a paso para procesos manuales o recurrentes (instalación, recuperación, mantenimiento). |
| [postmortems/](postmortems/) | Análisis *blameless* de incidentes: qué pasó, causa raíz y acciones de mejora. |

Runbooks y postmortems se retroalimentan: un postmortem suele terminar creando o
corrigiendo un runbook, y un runbook puede enlazar al postmortem que lo originó.

## Runbooks

| Runbook | Estado | Descripción |
| --- | --- | --- |
| [00 — Bootstrap del homelab desde cero](runbooks/00-bootstrap-homelab.md) | ✅ | Despliegue completo: Proxmox → Packer → Terraform → Ansible (k3s) → servicios GitOps. |
| [01 — Recovery parcial](runbooks/01-recovery-parcial.md) | ✅ | Caída de un nodo, pérdida de quorum o pérdida de datos en el NAS. |
| [02 — Gestión de buckets en Garage](runbooks/02-garage-buckets.md) | ✅ | Crear/borrar buckets, gestionar claves de acceso y permisos en Garage (S3). |
| [03 — Migración de disco de un nodo Proxmox](runbooks/03-migracion-disco-nodo.md) | ✅ | Sustituir el disco físico de `zoro` o `nami` preservando las VMs (migración en vivo o backup/restore vía NAS). |

## Postmortems

| Postmortem | Descripción |
| --- | --- |
| [2026-07-27 — Crash-loop de kube-vip por latencia de fsync de etcd](postmortems/2026-07-27-etcd-fsync-kubevip-crashloop.md) | NVMe genérico (~100 fsync/s) + worker de media saturando el disco de etcd → latencia de etcd ~5 s → kube-vip en crash-loop y reinicios en cascada. |

*Formato: seguir [postmortems/_template.md](postmortems/_template.md) con el nombre
`YYYY-MM-DD-titulo-corto.md`.*
