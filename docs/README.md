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

## Postmortems

Aún no hay incidentes documentados.
Seguir el formato [postmortems/_template.md](postmortems/_template.md) con el nombre
`YYYY-MM-DD-titulo-corto.md`.
