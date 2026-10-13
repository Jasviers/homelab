# Proxmox VM (Terraform)

Este root module usa el módulo `../modules/proxmox-vm` para desplegar el clúster k3s del homelab: 4 VMs repartidas entre `zoro` y `nami` (1 control-plane, 3 workers).

## Archivos principales

- `main.tf`: referencia el módulo y crea las 4 VMs vía `for_each` sobre `vms`.
- `providers.tf`: configuración del provider de Proxmox vía API.
- `variables.tf`: variables del root module; `vms` admite overrides opcionales por VM (`cores`, `memory`, `disk_gb`, `storage`, `memory_floating`, `startup_order`, `startup_up_delay`) que caen a los globales del mismo nombre si se omiten.
- `terraform.tfvars.example`: ejemplo con las 4 VMs (1 control-plane de 2 vCPU/8 GB, 3 workers de 6 vCPU/12-24 GB). `cpu_type = "host"` por defecto (ambos nodos comparten CPU).
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
- `vms`: mapa con las 4 VMs que se crean por defecto (cada entrada puede sobreescribir `cores`/`memory`/`disk_gb`/`storage`/`memory_floating`/`startup_order`/`startup_up_delay`).
- `storage`, `disk_gb`, `cores`, `memory`: sizing y storage por defecto, usados por las VMs que no definen su propio override.
- `cpu_type`: tipo de CPU global (default `host`; máximo rendimiento cuando todos los nodos comparten la misma CPU física).
- `on_boot`: arranque automático de las VMs con el host (default `true`).
- `ipv4_gateway`: gateway para cloud-init.

### Notas de RAM y rendimiento (zoro/nami)

`zoro` y `nami` comparten CPU (Ryzen 5 7430U) pero no RAM (64 GB / 16 GB), así
que `cpu_type = "host"` no compromete la migración. Reparto actual: en `zoro`
el control-plane (8 GB) y dos workers de 24 GB (56 GB asignados, ~7 GB para el
host); en `nami` un único worker de 12 GB (~3 GB para el host). El nodo de IA
y el segundo control-plane (`nami_cp`) se retiraron en octubre de 2026 y su
RAM se repartió entre los workers.
`memory_floating` (ballooning) no se usa en ninguna VM: con el balloon activo
`nami_worker` se quedaba sin page cache y releía continuamente del disco
compartido con etcd. El control-plane tampoco lo usa porque etcd es sensible
a la latencia del balloon driver. `startup_order` asegura que el control-plane
arranque antes que los workers tras un reinicio del host.

## Salidas

- `vm_ids`: IDs de las VMs en Proxmox, por nodo.
- `vm_names`: nombres de las VMs, por nodo.
- `ipv4_addresses`: configuración aplicada, por nodo.

## Flujo recomendado

1. Crea el token en Proxmox con privilegios mínimos necesarios.
2. Copia el `.tfvars.example` al `.tfvars` real y añade el token.
3. Ejecuta `terraform plan` y luego `terraform apply`.
