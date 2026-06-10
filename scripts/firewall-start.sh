#!/bin/sh

# Este script se encarga de configurar unas reglas de red entre la red de IOT y el servidor con el homeAssistant

# Acceso entre la red de IOT y el servidor de HomeAssistant
iptables -I FORWARD 1 -s 192.168.1.2 -d 192.168.52.0/24 -j ACCEPT
iptables -I FORWARD 2 -s 192.168.52.0/24 -d 192.168.1.2 -j ACCEPT

# Bloquear acceso a la red de IOT desde el resto de la red local
iptables -I FORWARD 3 -s 192.168.0.0/23 -d 192.168.52.0/24 -j DROP
iptables -I FORWARD 4 -s 192.168.52.0/24 -d 192.168.0.0/23 -j DROP

# Bloquear acceso a internet desde la red de IOT
WAN_IF=$(nvram get wan0_ifname)
iptables -I FORWARD 5 -i br52 -o $WAN_IF -j DROP


# Bloquear que la red de IOT acceda a la IP de la red principal
iptables -I INPUT 1 -i br52 -d 192.168.0.1 -j DROP

# Permitir que la IP del servidor de HomeAssistant acceda a la IP del router y denegar el resto de la red local
iptables -I INPUT 2 -s 192.168.1.2 -d 192.168.52.1 -j ACCEPT
iptables -I INPUT 3 -s 192.168.0.0/23 -d 192.168.52.1 -j DROP

