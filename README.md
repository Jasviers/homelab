# Homelab documentation

## Repository Overview

This repository contains the configuration and setup for a homelab environment. The homelab is managed using Kubernetes and various Helm charts to deploy and manage services. Below is an overview of the directories and their purposes:

### `external-services`

This directory contains configurations for external services deployed in the homelab.

- **values**: Contains Helm values files for different services.
  - `nginx-internal.values.yaml`: Configuration for the internal NGINX ingress controller.
  - `externaldns.values.yaml`: Configuration for ExternalDNS with Pi-hole as the provider.
  - `pihole.values.yaml`: Configuration for deploying Pi-hole.
  - `home-assistant.values.yaml`: Configuration for deploying Home Assistant.

- **kustom**: Contains Kustomize configurations.
  - `metallb/pool.yaml`: Configuration for MetalLB IP address pool and L2 advertisement.
  - `kustomization.yaml`: Kustomization file to manage resources.

- **helmfile.yaml**: Defines the Helm releases for various services including Longhorn, MetalLB, Pi-hole, NGINX ingress, ExternalDNS, ArgoCD, Home Assistant, and Cert-Manager.

- **prerequisites.sh**: Script to install custom resource definitions for Cert-Manager.

- **loadbalancer.yaml**: Defines LoadBalancer services for ArgoCD and Home Assistant.

#### Steps

```bash

# Deploy Helm releases
helmfile -f external-services/helmfile.yaml sync

# Apply Kustomize configurations
kubectl apply -k external-services/kustom
```

### `monitor`

This directory contains configurations for monitoring and logging services.

- **values**: Contains Helm values files for monitoring services.
  - `prometheus.values.yaml`: Configuration for Prometheus.
  - `loki.values.yaml`: Configuration for Loki.
  - `fluent.values.yaml`: Configuration for Fluent Bit.

- **helmfile.yaml**: Defines the Helm releases for monitoring services including Prometheus, Loki, Fluent Bit, and Tempo.

- **loadbalancer.yaml**: Defines LoadBalancer services for Prometheus, Loki, and Tempo.

### `LICENSE`

Contains the MIT License for the repository.

## Usage

To deploy the services defined in this repository, use the provided Helm and Kustomize configurations. Ensure that all prerequisites are met by running the `prerequisites.sh` script before deploying the Helm releases.
