# NN — Título del runbook

> Una frase: qué consigue este manual.

## Objetivo y cuándo usarlo

- Qué problema resuelve o qué tarea automatiza.
- Cuándo aplicarlo (síntomas, evento programado, parte de otro proceso).
- Tiempo estimado y nivel de impacto/riesgo.

## Prerrequisitos

- Accesos necesarios (SSH, kubeconfig, VPN, consola de Proxmox, DSM…).
- Credenciales o secrets requeridos.
- Herramientas locales (`kubectl`, `terraform`, `packer`, `ansible`, `helm`…).
- Estado de partida esperado.

## Pasos

1. **Descripción del paso.**

   ```bash
   comando exacto
   ```

   *Resultado esperado:* qué deberías ver si va bien.

2. **Siguiente paso.**

   ...

## Verificación

Cómo confirmar que todo quedó correcto (comandos y salida esperada).

```bash
# checks finales
```

## Rollback / si algo falla

- Cómo deshacer o mitigar si un paso falla.
- Errores comunes y su solución.

## Referencias

- READMEs relacionados: `services/...`, `ansible/...`, etc.
- Postmortems relacionados: `docs/postmortems/...`.
- Documentación externa.
