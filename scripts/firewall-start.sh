#!/bin/sh

# Este script se encarga de configurar unas reglas de red entre la red de IOT y el servidor con el homeAssistant

# Inserta una regla en una posicion concreta solo si no existe ya, evitando duplicados
# Uso: ins <CHAIN> <POS> <resto de argumentos de la regla>
ins() {
	chain=$1
	pos=$2
	shift 2
	if ! iptables -C "$chain" "$@" 2>/dev/null; then
		iptables -I "$chain" "$pos" "$@"
	fi
}

# Acceso entre la red de IOT y el servidor de HomeAssistant
ins FORWARD 1 -s 192.168.1.2 -d 192.168.52.0/24 -j ACCEPT
ins FORWARD 2 -s 192.168.52.0/24 -d 192.168.1.2 -j ACCEPT

# Bloquear acceso a la red de IOT desde el resto de la red local
ins FORWARD 3 -s 192.168.0.0/23 -d 192.168.52.0/24 -j DROP
ins FORWARD 4 -s 192.168.52.0/24 -d 192.168.0.0/23 -j DROP

# Bloquear acceso a internet desde la red de IOT
WAN_IF=$(nvram get wan0_ifname)
ins FORWARD 5 -i br52 -o "$WAN_IF" -j DROP


# Bloquear que la red de IOT acceda a la IP de la red principal
ins INPUT 1 -i br52 -d 192.168.0.1 -j DROP

# Permitir que la IP del servidor de HomeAssistant acceda a la IP del router y denegar el resto de la red local
ins INPUT 2 -s 192.168.1.2 -d 192.168.52.1 -j ACCEPT
ins INPUT 3 -s 192.168.0.0/23 -d 192.168.52.1 -j DROP
