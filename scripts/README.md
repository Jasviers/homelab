# Scripts

Scripts auxiliares que se ejecutan fuera del clúster.

## false-ddns.sh

DDNS casero contra Cloudflare: comprueba la IP pública actual (api.ipify.org) y, si ha cambiado, actualiza el registro A correspondiente en la zona `bonchan.org`.

- Requiere la variable de entorno `token_cloudflare` con un token de API de Cloudflare con permisos de edición de DNS sobre la zona.
- Edita `RECORD_NAME` con el registro real antes de usarlo.
- Pensado para ejecutarse periódicamente vía cron, por ejemplo:

```cron
*/5 * * * * token_cloudflare=<TOKEN> /path/to/false-ddns.sh >> /var/log/false-ddns.log 2>&1
```

## firewall-start.sh

Reglas de iptables para aislar la red de IOT (`192.168.52.0/24`, bridge `br52`) en el router ASUS (firmware Merlin, usa `nvram`):

- Permite tráfico bidireccional solo entre el servidor de Home Assistant (`192.168.1.2`, luffy) y la red IOT.
- Bloquea el acceso del resto de la red local (`192.168.0.0/23`) a la red IOT y viceversa.
- Bloquea la salida a internet de la red IOT.
- Restringe el acceso de la red IOT a las IPs del router.

Se instala como script de arranque del firewall en el router (`/jffs/scripts/firewall-start` en ASUS Merlin).

> Aviso: el script usa `iptables -I` sin comprobar si las reglas ya existen; ejecutarlo varias veces duplica reglas.
