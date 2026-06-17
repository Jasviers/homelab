# YYYY-MM-DD — Título corto del incidente

> **Postmortem blameless.** El objetivo es aprender y mejorar el sistema siguiendo la filosofía y concepto de *blameless* postmortems.

## Resumen

Una o dos frases: qué pasó y cuál fue el efecto.

## Impacto

- **Servicios afectados:**
- **Duración:** desde `HH:MM` hasta `HH:MM` (`X` min/horas).
- **Alcance:** quién/qué se vio afectado (usuarios, datos, otros servicios).
- **Pérdida de datos:** sí/no — detalle.

## Detección

- ¿Cómo se detectó? (alerta, fallo visible, casualidad).
- ¿Cuánto tardó en detectarse desde que empezó?

## Timeline

Horas en zona local (Europe/Madrid).

| Hora | Evento |
| --- | --- |
| `HH:MM` | Comienza el incidente. |
| `HH:MM` | Detección. |
| `HH:MM` | Diagnóstico / hipótesis. |
| `HH:MM` | Mitigación aplicada. |
| `HH:MM` | Servicio restablecido. |

## Causa raíz

Qué condición técnica permitió el incidente. Profundiza más allá del síntoma
(técnica de los "5 porqués"): no "el pod se cayó", sino *por qué* se cayó y *por
qué* eso tumbó el servicio.

## Qué funcionó / qué costó

- **Funcionó bien:** detección, herramientas, runbooks útiles…
- **Costó / faltó:** ausencia de alertas, runbook inexistente, dependencias
  ocultas, acceso difícil…

## Acciones de mejora

Concretas, accionables y con responsable. Enlázalas a `TODO.md` o a issues.

- [ ] Acción 1 (p. ej. crear runbook `docs/runbooks/NN-...`).
- [ ] Acción 2 (p. ej. añadir alerta / monitorización).
- [ ] Acción 3 (p. ej. automatizar paso manual).

## Referencias

- Runbooks relacionados: `docs/runbooks/...`.
- Commits / PRs de la mitigación.
- Logs o capturas relevantes.
