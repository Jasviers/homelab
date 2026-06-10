# Docker Compose

Servicios que corren en `luffy` (Raspberry Pi 4B) con Docker Compose, fuera del clúster k3s.

## Servicios

| Servicio | Imagen | Acceso | Descripción |
| --- | --- | --- | --- |
| `pihole` | `pihole/pihole:latest` | DNS en `:53`, UI en `:8080` | DNS local y bloqueo de publicidad. Upstream: Cloudflare (1.1.1.1 / 1.0.0.1). |
| `homeassistant` | `ghcr.io/home-assistant/home-assistant:stable` | UI en `:8123` | Automatización del hogar. |

Ambos usan `network_mode: host` y persisten su configuración en volúmenes locales relativos a esta carpeta (`./pihole`, `./dnsmasq.d`, `./homeassistant`).

## Uso

```bash
cd docker-composes

# Cambia WEBPASSWORD antes del primer arranque
docker compose up -d
```

> Nota: `WEBPASSWORD` está como placeholder (`SET_A_PASSWORD`); cámbialo antes de levantar el stack o muévelo a un fichero `.env` no versionado.
