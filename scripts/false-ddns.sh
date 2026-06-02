#!/bin/bash

set -e

ZONE_NAME="bonchan.org"
RECORD_NAME="xxxxx.bonchan.org"

if [ -z "$token_cloudflare" ]; then
    echo "Error: La variable de entorno CLOUDFLARE_TOKEN no está definida."
    exit 1
fi

echo "Iniciando comprobación de IP para $RECORD_NAME..."

CURRENT_IP=$(curl -s https://api.ipify.org)

if [ -z "$CURRENT_IP" ]; then
    echo "Error: No se pudo obtener la IP pública actual."
    exit 1
fi
echo "Tu IP pública actual es: $CURRENT_IP"

ZONE_ID=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$ZONE_NAME" \
     -H "Authorization: Bearer $token_cloudflare" \
     -H "Content-Type: application/json" | grep -o '"id":"[^"]*' | head -n 1 | grep -o '[^"]*$')

if [ -z "$ZONE_ID" ]; then
    echo "Error: No se pudo obtener el Zone ID para $ZONE_NAME. Verifica tu Token."
    exit 1
fi

RECORD_DATA=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records?name=$RECORD_NAME" \
     -H "Authorization: Bearer $token_cloudflare" \
     -H "Content-Type: application/json")

RECORD_ID=$(echo "$RECORD_DATA" | grep -o '"id":"[^"]*' | head -n 1 | grep -o '[^"]*$')
CLOUDFLARE_IP=$(echo "$RECORD_DATA" | grep -o '"content":"[^"]*' | head -n 1 | grep -o '[^"]*$')

if [ -z "$RECORD_ID" ]; then
    echo "Error: No se encontró el registro DNS para $RECORD_NAME. Asegúrate de crearlo primero en la web de Cloudflare."
    exit 1
fi

if [ "$CURRENT_IP" = "$CLOUDFLARE_IP" ]; then
    echo "La IP no ha cambiado ($CURRENT_IP). No es necesario actualizar Cloudflare."
else
    echo "La IP ha cambiado (Antes: $CLOUDFLARE_IP -> Ahora: $CURRENT_IP). Actualizando Cloudflare..."
    
    UPDATE_RESULT=$(curl -s -X PUT "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$RECORD_ID" \
         -H "Authorization: Bearer $token_cloudflare" \
         -H "Content-Type: application/json" \
         --data "{\"type\":\"A\",\"name\":\"$RECORD_NAME\",\"content\":\"$CURRENT_IP\",\"proxied\":false}")
         
    if echo "$UPDATE_RESULT" | grep -q '"success":true'; then
        echo "¡Éxito! El DNS de Cloudflare ha sido actualizado a $CURRENT_IP."
    else
        echo "Error al actualizar el registro DNS."
        echo "Detalle del error: $UPDATE_RESULT"
        exit 1
    fi
fi