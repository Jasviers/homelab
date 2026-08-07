# Grafana dashboards

Dashboards de Grafana versionados. Cada JSON se empaqueta como un ConfigMap que el sidecar de Grafana descubre y monta automáticamente.

No tiene Application propia en ArgoCD: se consume desde `services/monitor/kustomization.yaml` con `resources: - ../../grafana`, así que forma parte de la app `monitor`.

## Por qué esta carpeta tiene su propio kustomization.yaml

Kustomize prohíbe que un `configMapGenerator` lea ficheros por encima del directorio de su kustomization (`security; file ... is not in or below ...`). Referenciar el *directorio* desde `resources:` sí está permitido, y entonces los JSON se cargan desde el root de *esta* kustomization. Por eso `services/monitor` no puede apuntar directamente a los ficheros.

## Estructura

```text
dashboards/
├── infra/        → carpeta "Infra" en Grafana
├── kubernetes/   → carpeta "Kubernetes"
└── apps/         → carpeta "Apps"
```

Las subcarpetas son organización para humanos. Lo que decide la carpeta real en Grafana es la anotación `grafana_folder` del ConfigMap.

## Añadir un dashboard

1. Guardar el JSON en `dashboards/<carpeta>/<nombre>.json`.
1. Añadir la entrada en `kustomization.yaml`:

```yaml
configMapGenerator:
  - name: grafana-dashboard-etcd
    files:
      - dashboards/infra/etcd.json
    options:
      disableNameSuffixHash: true
      labels:
        grafana_dashboard: "1"
      annotations:
        grafana_folder: "Infra"
```

1. Comprobar el render antes de commitear:

```sh
kustomize build --enable-helm services/monitor | grep -A5 "name: grafana-dashboard-etcd"
```

`disableNameSuffixHash: true` es obligatorio: sin él cada cambio genera un ConfigMap con nombre nuevo y deja huérfano el anterior. Con él el sidecar recibe un evento `MODIFY` sobre el mismo objeto y reescribe el fichero en disco.

## Flujo de trabajo

Editar en la UI → *Save* → *Export → Save to file* (sin marcar "export for sharing externally") → guardar el JSON en la carpeta → commit.

## Trampas conocidas

**UIDs de datasource.** Este Grafana provisiona `uid: prometheus` y `uid: loki` (ver `services/monitor/grafana/kustomization.yaml`). Un JSON descargado de grafana.com trae referencias `${DS_PROMETHEUS}` y un bloque `__inputs`: hay que sustituirlas por los uid literales y borrar `__inputs`, o el dashboard aparece sin datos.

**El campo `version` y `allowUiUpdates`.** El provider corre con `allowUiUpdates: true`, así que Grafana solo aplica el fichero si su `version` es **mayor** que la que ya tiene en base de datos. Exportar siempre desde la UI, que lo incrementa sola. Si se edita el JSON a mano hay que subir `version` manualmente, o el cambio se ignora en silencio.

**Límite de 1 MiB por ConfigMap.** Por eso un ConfigMap por dashboard y no uno agregado. Un dashboard de comunidad muy grande puede no caber por esta vía.

**Carpetas.** El sidecar coloca el dashboard según la anotación `grafana_folder`. Esto depende de `folderAnnotation: grafana_folder` **junto con** `provider.foldersFromFilesStructure: true` en los values del chart; con solo la primera, las anotaciones se ignoran.
