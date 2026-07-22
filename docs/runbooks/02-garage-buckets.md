# 02 — Gestión de buckets en Garage (S3)

> Operaciones básicas de administración de Garage: crear/borrar buckets, gestionar claves de acceso y permisos.

## Objetivo y cuándo usarlo

- Cada vez que una app nueva necesita almacenamiento S3 (crear bucket + clave), o hay que rotar/revocar credenciales de una app existente.
- **Tiempo estimado:** unos minutos por operación.
- **Riesgo:** bajo en general — el borrado de buckets y claves es irreversible (ver [Rollback](#rollback--si-algo-falla)).

## Prerrequisitos

- `kubectl` con acceso al clúster y al namespace `garage`.
- Garage ya desplegado y con el *layout* del clúster aplicado (ver [services/README.md](../../services/README.md), sección `garage/`, y su bootstrap manual).
- No hay panel web ni SSO: toda la administración es por CLI, ejecutando el propio binario `/garage` dentro del pod vía `kubectl exec`.

Para abreviar los ejemplos, se asume este alias:

```bash
alias grg='kubectl -n garage exec deploy/garage --'
```

Sin el alias, sustituye `grg` por `kubectl -n garage exec deploy/garage --` en cualquier comando.

## Pasos

### 1. Crear un bucket

```bash
grg /garage bucket create mi-bucket
```

*Resultado esperado:* `Bucket mi-bucket was created.`

### 2. Crear una clave de acceso

Una clave por aplicación/uso, no por persona (Garage no tiene concepto de "usuario"):

```bash
grg /garage key create mi-app-key
```

La salida incluye `Key ID` y `Secret key`. **El secret solo se muestra esta vez** — guárdalo donde lo vaya a consumir la app (p. ej. un `Secret` de Kubernetes si es un servicio del propio clúster).

### 3. Dar permisos de la clave sobre el bucket

```bash
grg /garage bucket allow --key mi-app-key --read --write mi-bucket
```

Usa `--owner` (además de o en vez de `--read --write`) si esa clave también debe poder gestionar los permisos de otras claves sobre el bucket.

### 4. Consultar el estado (buckets, claves, permisos)

```bash
grg /garage bucket list
grg /garage bucket info mi-bucket
grg /garage key list
grg /garage key info mi-app-key --show-secret   # recupera el secret si aún no expiró
```

### 5. Revocar acceso sin borrar la clave

```bash
grg /garage bucket deny --key mi-app-key --read --write mi-bucket
```

### 6. Cuotas (opcional)

```bash
grg /garage bucket set-quotas --max-size 20GiB --max-objects 100000 mi-bucket

# Quitar la cuota:
grg /garage bucket set-quotas --max-size none mi-bucket
```

### 7. Borrar una clave de acceso

```bash
grg /garage key delete --yes mi-app-key
```

> Irreversible: cualquier cliente S3 que use esa clave deja de poder autenticarse de inmediato.

### 8. Borrar un bucket

Garage no borra un bucket que todavía tiene objetos dentro, y el CLI de Garage no borra objetos (solo administra buckets y claves) — hay que vaciarlo primero con un cliente S3:

```bash
# Vaciar el bucket con aws-cli contra el endpoint de Garage (ver Verificación):
aws --endpoint-url https://garage.bonchan.org s3 rm s3://mi-bucket --recursive

# Con el bucket ya vacío:
grg /garage bucket delete --yes mi-bucket
```

> Irreversible y no versionado — no hay papelera ni recuperación salvo backup externo (Velero, snapshot del NAS).

### 9. Bucket público para servir contenido a una web (opcional)

Requiere el endpoint `[s3_web]` activado en `garage.toml` (ver `services/README.md`, sección `garage/`). Resumen:

```bash
grg /garage bucket alias mi-bucket img.bonchan.org
grg /garage bucket website --allow img.bonchan.org
```

Y una regla en `services/cloudflared/configmap.yml` apuntando a `http://garage.garage.svc.cluster.local:3902`, igual que se hace con Home Assistant (bypass del Gateway — `*.bonchan.org` normalmente solo es accesible por LAN/VPN, no público en internet).

## Verificación

Probar con un cliente S3 real. Importante: como no hay `root_domain` configurado en `[s3_api]`, los clientes deben usar **path-style addressing** (`--endpoint-url` + `s3://bucket`, no `bucket.garage.bonchan.org`):

```bash
aws configure set aws_access_key_id <KEY_ID> --profile garage
aws configure set aws_secret_access_key <SECRET_KEY> --profile garage
aws --profile garage --endpoint-url https://garage.bonchan.org s3 ls s3://mi-bucket
```

Si falla la conexión o el certificado, comprueba que `garage.bonchan.org` resuelve (estás en LAN o VPN) y que el pod está sirviendo tráfico:

```bash
grg /garage status
```

## Rollback / si algo falla

- **Clave borrada por error**: el secret no se puede recuperar. Crea una nueva (`key create`) y repite `bucket allow` sobre los buckets que necesitaba.
- **Bucket borrado por error**: los datos se pierden si no había backup — Garage no tiene papelera de reciclaje.
- **El API S3 no responde / `garage status` no muestra el nodo como sano**: revisa que el *layout* del clúster esté aplicado (bootstrap en `services/README.md`, sección `garage/`).

## Referencias

- Documentación del servicio: [services/README.md](../../services/README.md) (sección `garage/`).
- CLI de referencia de Garage: [reference-manual/cli-v2](https://garagehq.deuxfleurs.fr/documentation/reference-manual/cli-v2/).
- Bootstrap completo del homelab: [00-bootstrap-homelab.md](00-bootstrap-homelab.md).
