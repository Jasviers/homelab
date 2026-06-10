# Módulo proxmox-vm

Módulo de Terraform que clona una VM desde un template de Proxmox (provider `bpg/proxmox`) y la configura con cloud-init.

Lo consume el root module `terraform/proxmox-vm`, que lo referencia por tag de git (`git::git@github.com:Jasviers/homelab.git//terraform/modules/proxmox-vm?ref=vX.Y.Z`), por lo que los cambios en el módulo solo aplican tras crear una release nueva y actualizar el `ref`.

## Qué hace

- Busca el template por nombre en el nodo destino (data source `proxmox_virtual_environment_vms`).
- Clona la VM (clone completo) con el VMID, nombre, tags y descripción indicados.
- Configura CPU (`x86-64-v2-AES`), memoria, disco (`scsi0`) y red (`virtio`).
- Inicializa con cloud-init: IP estática, gateway, usuario, password y claves SSH.
- Habilita el QEMU guest agent.

## Entradas principales

| Variable | Descripción | Default |
| --- | --- | --- |
| `vm_name` | Nombre de la VM | — |
| `target_node` | Nodo Proxmox destino | — |
| `template` | Nombre del template a clonar | — |
| `vm_id` | VMID (null = auto) | `null` |
| `cores` / `memory` / `disk_gb` | Sizing | `2` / `2048` / `20` |
| `storage` | Datastore del disco | — |
| `network_bridge` | Bridge de red | `vmbr0` |
| `ipv4_cidr` / `ipv4_gateway` | Red de la VM | — |
| `ciuser` / `cipassword` / `ssh_keys` | Acceso cloud-init | `ubuntu` / `null` / `[]` |

## Salidas

- `vm_id`, `vm_name`, `ipv4_addresses`.
