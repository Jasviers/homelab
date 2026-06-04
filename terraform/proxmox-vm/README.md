# Proxmox VM (Terraform)

Este root module usa el módulo `../modules/proxmox-vm` para desplegar dos VMs desde el template de Ubuntu 26: una en `zoro` y otra en `nami`.

## Archivos principales

- `main.tf`: referencia el módulo y crea ambas VMs.
- `providers.tf`: configuración del provider de Proxmox vía API.
- `variables.tf`: variables del root module y defaults de las dos VMs.
- `terraform.tfvars.example`: ejemplo de configuración compartida.
- `zoro.tfvars.example` / `nami.tfvars.example`: ejemplos heredados compatibles.

## Uso rápido

1. Copia `terraform.tfvars.example` al nombre real que usarás.
2. Completa el token de Proxmox y cualquier valor compartido que necesites ajustar.
3. Ejecuta Terraform desde esta carpeta.

## Notas de formato y ejemplos

- Los archivos `*.tfvars.example` se mantienen como plantillas: copia y renombra a `*.tfvars` antes de ejecutar `terraform plan`.
- Las IPs, nombres y VMIDs de `zoro` y `nami` se definen en `variables.tf` dentro de `vms`.
- Las variables sueltas heredadas siguen declaradas por compatibilidad, pero ya no controlan el despliegue.
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
- `vms`: mapa con las dos VMs que se crean por defecto.
- `storage`, `disk_gb`, `cores`, `memory`: sizing y storage.
- `ipv4_gateway`: gateway para cloud-init.

## Salidas

- `vm_ids`: IDs de las VMs en Proxmox, por nodo.
- `vm_names`: nombres de las VMs, por nodo.
- `ipv4_addresses`: configuración aplicada, por nodo.

## Flujo recomendado

1. Crea el token en Proxmox con privilegios mínimos necesarios.
2. Copia el `.tfvars.example` al `.tfvars` real y añade el token.
3. Ejecuta `terraform plan` y luego `terraform apply`.
