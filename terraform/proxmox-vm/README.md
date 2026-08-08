# Proxmox VM (Terraform)

Este root module usa el módulo `../modules/proxmox-vm` para desplegar el clúster k3s del homelab: 6 VMs heterogéneas repartidas entre `zoro` y `nami` (2 control-plane, 3 workers, 1 nodo de IA).

## Archivos principales

- `main.tf`: referencia el módulo y crea las 6 VMs vía `for_each` sobre `vms`.
- `providers.tf`: configuración del provider de Proxmox vía API.
- `variables.tf`: variables del root module; `vms` admite overrides opcionales por VM (`cores`, `memory`, `disk_gb`, `storage`, `memory_floating`, `startup_order`, `startup_up_delay`) que caen a los globales del mismo nombre si se omiten.
- `terraform.tfvars.example`: ejemplo con las 6 VMs (2 control-plane de 2 vCPU/4-8 GB, 3 workers de 4 vCPU/8-16 GB, 1 nodo de IA de 8 vCPU/16 GB). `cpu_type = "host"` por defecto (ambos nodos comparten CPU).
- `zoro.tfvars.example` / `nami.tfvars.example`: ejemplos heredados compatibles.

## Uso rápido

1. Copia `terraform.tfvars.example` al nombre real que usarás.
2. Completa el token de Proxmox y cualquier valor compartido que necesites ajustar.
3. Ejecuta Terraform desde esta carpeta.

## Notas de formato y ejemplos

- Los archivos `*.tfvars.example` se mantienen como plantillas: copia y renombra a `*.tfvars` antes de ejecutar `terraform plan`.
- Las IPs, nombres, VMIDs y sizing (`cores`/`memory`/`disk_gb`) de cada VM se definen por entrada dentro de `vms` en tu `terraform.tfvars`.
- Las variables sueltas `cores`/`memory`/`disk_gb`/`storage` son ahora **defaults globales**: se usan solo si una VM concreta no define su propio override en `vms` (patrón `coalesce(each.value.X, var.X)`, igual que ya existía para `description`).
- `ipv4_gateway` corresponde al gateway de tu red.
- `ssh_keys` debe ser una lista de claves públicas en una línea cada una — si no usas `ssh_keys`, deja `cipassword` no nulo o usa acceso por otro método.

### Ejemplo mínimo de uso

1. `cp terraform.tfvars.example terraform.tfvars`  
2. Editar `terraform.tfvars` y completar `proxmox_api_token`  
3. `terraform init`  
4. `terraform plan`  
5. `terraform apply`

Verifica salidas en `outputs.tf` para obtener `vm_ids`, `vm_names` e `ipv4_addresses`.

## Variables principales

- `proxmox_endpoint`: URL de la API de Proxmox.
- `proxmox_api_token`: token de acceso.
- `template`: template base para clonado.
- `vms`: mapa con las 6 VMs que se crean por defecto (cada entrada puede sobreescribir `cores`/`memory`/`disk_gb`/`storage`/`memory_floating`/`startup_order`/`startup_up_delay`).
- `storage`, `disk_gb`, `cores`, `memory`: sizing y storage por defecto, usados por las VMs que no definen su propio override.
- `cpu_type`: tipo de CPU global (default `host`; máximo rendimiento cuando todos los nodos comparten la misma CPU física).
- `on_boot`: arranque automático de las VMs con el host (default `true`).
- `ipv4_gateway`: gateway para cloud-init.

### Notas de RAM y rendimiento (zoro/nami)

`zoro` y `nami` comparten CPU (Ryzen 5 7430U) pero no RAM (64 GB / 16 GB), así
que `cpu_type = "host"` no compromete la migración. El nodo IA se dimensionó
en 16 GB (antes 32, y antes 48) para liberar presupuesto en `zoro` y poder
sumar un segundo worker (`zoro_worker2`) sin apretar al host Proxmox: con el
reparto actual (2 control-plane + 3 workers + 1 IA, todos en `zoro` salvo
`nami_cp`/`nami_worker`) quedan ~6 GB libres en `zoro` para el propio host —
justo, vigilar si se satura el swap del host (ver Fase 3 del runbook de
bootstrap).
`memory_floating` activa ballooning solo en los workers (para que Proxmox
pueda reclamar RAM no usada); se deja desactivado en los control-plane y en
el nodo IA porque etcd y Ollama son sensibles a la latencia que introduce el
balloon driver. `startup_order` asegura que el control-plane arranque antes
que los workers y el nodo IA tras un reinicio del host.

## Salidas

- `vm_ids`: IDs de las VMs en Proxmox, por nodo.
- `vm_names`: nombres de las VMs, por nodo.
- `ipv4_addresses`: configuración aplicada, por nodo.

## Flujo recomendado

1. Crea el token en Proxmox con privilegios mínimos necesarios.
2. Copia el `.tfvars.example` al `.tfvars` real y añade el token.
3. Ejecuta `terraform plan` y luego `terraform apply`.
