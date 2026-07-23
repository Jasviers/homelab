# Changelog

## [1.14.0](https://github.com/Jasviers/homelab/compare/v1.13.3...v1.14.0) (2026-07-23)


### Features

* add garage buckets and improve cloudflared ([f294be3](https://github.com/Jasviers/homelab/commit/f294be36a3c48438c67517e2a572d43d767a362f))
* add garage buckets and improve cloudflared ([91e8afc](https://github.com/Jasviers/homelab/commit/91e8afc3ebab2858f8f5e472db17203d9f65da84))
* add media server with jellyfin ([a01cff8](https://github.com/Jasviers/homelab/commit/a01cff8d2f6f2f1747af1c1ae6bcc2af14fdaef6))


### Bug Fixes

* add nfs storage class, we reach the limit of LUNs in Synology NA… ([7cf4b09](https://github.com/Jasviers/homelab/commit/7cf4b0917dfa57026399576b689a11bd84a4b64d))
* add nfs storage class, we reach the limit of LUNs in Synology NAS server ([99b0eee](https://github.com/Jasviers/homelab/commit/99b0eee2a0114bba86ff4f23a81052437d187053))

## [1.13.3](https://github.com/Jasviers/homelab/compare/v1.13.2...v1.13.3) (2026-07-22)


### Bug Fixes

* ollama only use small model and big context, repair cloudflared … ([2acf1d9](https://github.com/Jasviers/homelab/commit/2acf1d9e6e1239f6dcccb33f280a3cf9749fb6d0))
* ollama only use small model and big context, repair cloudflared deploy ([29d2389](https://github.com/Jasviers/homelab/commit/29d238932838953ba6878a61c2278345e729e64d))

## [1.13.2](https://github.com/Jasviers/homelab/compare/v1.13.1...v1.13.2) (2026-07-22)


### Bug Fixes

* ollama exposed and cloudflared automatic deploy ([fcac3e3](https://github.com/Jasviers/homelab/commit/fcac3e3a849bacc9a4a34d091160a03c76f0c91f))
* ollama exposed and cloudflared automatic deploy ([6e85aa0](https://github.com/Jasviers/homelab/commit/6e85aa076b699ae5c5007ce466719a7a287c22cb))

## [1.13.1](https://github.com/Jasviers/homelab/compare/v1.13.0...v1.13.1) (2026-07-22)


### Bug Fixes

* HA for cilium lease and envoy api gateway ([b030138](https://github.com/Jasviers/homelab/commit/b03013847b26e92c2acfe9e2281465b79a5f3428))
* update automaticaly uuid of cloudflare tunnel ([eec7d6b](https://github.com/Jasviers/homelab/commit/eec7d6bf5271247c83b224ad69a2778eb22f7fda))

## [1.13.0](https://github.com/Jasviers/homelab/compare/v1.12.0...v1.13.0) (2026-07-22)


### Features

* add .gitignore ([3a7b13f](https://github.com/Jasviers/homelab/commit/3a7b13f11ac494dfc448e4236c0eac8e92afc9e3))
* add ansible folder with role and playbook to update homelab ([205615f](https://github.com/Jasviers/homelab/commit/205615f9c7b0f1189e67127fe1654dd27dc0cfa4))
* add ansible folder with role and playbook to update homelab ([40b9a0d](https://github.com/Jasviers/homelab/commit/40b9a0dc51991b28d15a68cb1729a20fe29fa3c6))
* add argocd apps with a root app to manage all ([50f43bb](https://github.com/Jasviers/homelab/commit/50f43bbbaa9451eb92d85684dc9be085e9f60892))
* add cilium as CNI and modify instalation playbooks ([fcccbbc](https://github.com/Jasviers/homelab/commit/fcccbbc8ec39b7ec18e783e669baaca07d6e000a))
* add cilium pod cipher and http routes to proxmox and router ([7413798](https://github.com/Jasviers/homelab/commit/7413798792b14c343618cab05b6a307de8cdfeee))
* add clouflared and create tunnel to expose home assistant and give ([e435987](https://github.com/Jasviers/homelab/commit/e43598781633de59d6c11611993ce3111e385f23))
* add cnpg-operator and authentik to manage databases and SSO login ([ebec5e2](https://github.com/Jasviers/homelab/commit/ebec5e20f5f117fef49eec1b536c666be12cd1d4))
* add concurrency to whisper ([60e6fa7](https://github.com/Jasviers/homelab/commit/60e6fa76c19d7522263dabec78694933ec60fa7d))
* add control to cilium version with renovate ([174eae1](https://github.com/Jasviers/homelab/commit/174eae1ef1390326fe431c0c8e3bd3f65351458f))
* add gateway api with envoy ([bb47ce3](https://github.com/Jasviers/homelab/commit/bb47ce3b2d0bb246266cba5b8cb729efdb3d3ff8))
* add gitignore ([d371633](https://github.com/Jasviers/homelab/commit/d3716332c7e845f7d710fa41b59cbca499e3414c))
* add homepage portal ([e9a77d1](https://github.com/Jasviers/homelab/commit/e9a77d1b19ca2e4d89854f0d72eff7b84152282c))
* add hubble to monitor k8s network ([40a63f4](https://github.com/Jasviers/homelab/commit/40a63f4397a15059ff06c7a702af91778d40a478))
* add install and uninstall playbooks and roles for k3s ([3fb0227](https://github.com/Jasviers/homelab/commit/3fb022716d1bd2fe961c78192b515b7ebd282551))
* add kubevip IP and modify configuration k3s to add the IP as valid ([2825c86](https://github.com/Jasviers/homelab/commit/2825c8612be665c11c58ea29a023d1d41d777afa))
* add markdownlint file ([db5e728](https://github.com/Jasviers/homelab/commit/db5e728b18f2875a5be491213b1e0802aa5623e2))
* add monitoring services ([a5b9e1b](https://github.com/Jasviers/homelab/commit/a5b9e1bd1cf79886004c586c915c3c9b5cb943c6))
* add monitoring stack with grafana, prometheus, loki and alloy ([f028ae5](https://github.com/Jasviers/homelab/commit/f028ae54c192fbca3cd1a61bbe34f5381363d835))
* add new work network's firewall rules ([5e6daf7](https://github.com/Jasviers/homelab/commit/5e6daf7a25390f97ba57ab03e164aaae8ec50dba))
* add renovate to check and update dependencies ([534cdf9](https://github.com/Jasviers/homelab/commit/534cdf942c7a5b33f7bdf9f56c4dea38a414f7d4))
* add SSO config to argo and grafana ([b10ba20](https://github.com/Jasviers/homelab/commit/b10ba202e7f070b3b1b5b6af1f3499ccb2177a64))
* add synology-csi to manage volumens ([5ea970f](https://github.com/Jasviers/homelab/commit/5ea970ffd982e10fd504a12956377dbb00cab0d0))
* argocd enable use helm ([d60c738](https://github.com/Jasviers/homelab/commit/d60c738b5ec1459a4500749bfafb6126c80cfbd5))
* **argocd:** add argocd deploy files ([9a5176a](https://github.com/Jasviers/homelab/commit/9a5176aeb3e2b8ca76956aa0d81f6b7e7dd600dc))
* **argocd:** argocd basic deployment ([4db23ed](https://github.com/Jasviers/homelab/commit/4db23eddd3b918e29956b27109c81e7a7664fe94))
* backup docker compose file from raspberry pi ([573eb3b](https://github.com/Jasviers/homelab/commit/573eb3b53659692adc9db7f60b276c1ec78d7a86))
* **certmanager:** create manifest to deploy certmanager ([8f99b44](https://github.com/Jasviers/homelab/commit/8f99b44ad7cde073ac4644958379d13caea009c2))
* change argocd deafault ip to gateway ([e9f59d7](https://github.com/Jasviers/homelab/commit/e9f59d7faed0f894e63bcec7dbd12fd4a6c02070))
* change argocd deafault ip to gateway ([7b70f00](https://github.com/Jasviers/homelab/commit/7b70f0080f31ddad0520c97a75cf48cfe7c634e9))
* change vm architecture to have 2 vms to control plane, 2 workers and 1 worker for AI ([91990b2](https://github.com/Jasviers/homelab/commit/91990b214868b6f5ff721efb2ce66c3594a7885d))
* create roles and playbooks to install and configure homelab ([48cce6f](https://github.com/Jasviers/homelab/commit/48cce6f506378d283043a501440936be947a8854))
* first set up of services ([79610ad](https://github.com/Jasviers/homelab/commit/79610ad8fac436b869a04990785b2b80e58ba229))
* improve k3s deploy ([0e297c2](https://github.com/Jasviers/homelab/commit/0e297c2e79273cb3f48648cba8b84cb76b0d1cd2))
* improvement to gateway api. Headers and tls restrictions ([5779719](https://github.com/Jasviers/homelab/commit/577971985f5a7fd7b8042728659eb1a18cc3aba7))
* inprove IOT network script and add whisper and piper for home ([cf544ef](https://github.com/Jasviers/homelab/commit/cf544ef5ab3752a1b2f8afbaa3eabb10f60e45d4))
* metallb deploy configuration ([76e8b22](https://github.com/Jasviers/homelab/commit/76e8b22368d2bc3a28e86aa2f8afcb76f809bf56))
* **metallb:** new network configuration for metallb ([72b941b](https://github.com/Jasviers/homelab/commit/72b941bea87848bfae9d409e8d2f21a1a879a775))
* **metallb:** remove helmfile and change to use helm with kustomize ([de0b697](https://github.com/Jasviers/homelab/commit/de0b6970e8d743e50375ce7dcc1be044479344e8))
* packer template to create ubuntu 26 templates in promox ([44943ee](https://github.com/Jasviers/homelab/commit/44943ee6c2229dd9daa781711295146c01a73f00))
* script to configure firewall rules for IOT network ([ac2c5e7](https://github.com/Jasviers/homelab/commit/ac2c5e7e60ef2d4070bd9dac856df9a2b8900ed1))
* script to update dns register with current IP ([3db1336](https://github.com/Jasviers/homelab/commit/3db133695dc55ef8ca3633de0fae0fe69a855ece))
* **services:** add ollama and whisper AI services with ArgoCD integration ([eef1afb](https://github.com/Jasviers/homelab/commit/eef1afbd2e8b216a6ccb9b69a2de0e5cfaf02583))
* terraform to deploy initial vms setup ([2e36643](https://github.com/Jasviers/homelab/commit/2e36643e9f11887b603abc485286edd2faf17486))
* **terraform:** proxmox vm module ([5993910](https://github.com/Jasviers/homelab/commit/599391079cb9de15c0a01b5e40b4271c9d19e4e0))
* update ansible inventory ([d3ae10d](https://github.com/Jasviers/homelab/commit/d3ae10d25bd6ee98d23eb2d76e0e9a0b3094195f))
* update k3s playbooks to use directly k8s ips ([7e97eea](https://github.com/Jasviers/homelab/commit/7e97eea882b69e212d8e24cc9562da74a822dfdb))
* use ansible to configure packer template and cloud-init ([726ad93](https://github.com/Jasviers/homelab/commit/726ad9388463132df478cb0fe970ad9b67cdf130))


### Bug Fixes

* add grant_types to authentik blueprints ([410096f](https://github.com/Jasviers/homelab/commit/410096f25d508e6a3e523f9484ec59d2b07ff1c9))
* add grant_types to authentik blueprints ([4b36e76](https://github.com/Jasviers/homelab/commit/4b36e760948c7b1b20f621d9e8ae02c01729dab0))
* argo resolve bad dns ([c0e0ebf](https://github.com/Jasviers/homelab/commit/c0e0ebf0d0acfd8078454d9e59b9401708b67286))
* change argocd to run as insecure to repair loop of DNS redirections ([359b3db](https://github.com/Jasviers/homelab/commit/359b3db426b58dfad73ed82fd86c0fd658f1f35a))
* change fluentbit image ([c41ce71](https://github.com/Jasviers/homelab/commit/c41ce71295c1e1d1487621634cb000342c24490c))
* change trim to trimspace ([c2ac244](https://github.com/Jasviers/homelab/commit/c2ac2441885d0810734bb5e8c7e202dd0a8fc7e1))
* change trim to trimspace ([fee3c27](https://github.com/Jasviers/homelab/commit/fee3c272a2e51a3bd9cafa9c11885e5e54807b78))
* **ci:** typo on secrets reference ([f5131a0](https://github.com/Jasviers/homelab/commit/f5131a0db6effabee2bb9196b318291fc378ecdb))
* cloudflared token and whisper threads ([202562d](https://github.com/Jasviers/homelab/commit/202562d9e1345804321efd13a38672bd3c3f3675))
* cloudflared token and whisper threads ([d5cbbd4](https://github.com/Jasviers/homelab/commit/d5cbbd4035b614df6c52c84988748ab1b7c383e6))
* gateway kutomize files extension reference ([9b02beb](https://github.com/Jasviers/homelab/commit/9b02beb5c54de063d17c96572de84c8f60323410))
* gateway kutomize files extension reference ([5dd85eb](https://github.com/Jasviers/homelab/commit/5dd85eb5ed1d88afd9ad23e9c006edee38bac274))
* homepage autodiscovery and routing to argocd ([8081147](https://github.com/Jasviers/homelab/commit/80811479bca41fd21f0aae1ca1beb2451cf44f5f))
* homepage autodiscovery for gateway api ([d285dea](https://github.com/Jasviers/homelab/commit/d285dea5ec276bb5f78411aabb389dec3c105a3b))
* homepage autodiscovery for gateway api ([c7261fb](https://github.com/Jasviers/homelab/commit/c7261fbfab63843ffd5f5c10949f5d38c5e45406))
* internal domain resolution to resolve authentik login ([a5f5115](https://github.com/Jasviers/homelab/commit/a5f5115850a4b2d26305ca53718b330299e381d2))
* rename to add initial dot ([6909f0d](https://github.com/Jasviers/homelab/commit/6909f0d934aa9b1b34e83547c46bf83a284e8094))
* repair proxmox missing file errors ([b181b26](https://github.com/Jasviers/homelab/commit/b181b268d325a2a686025a0ee0a268f6f81ea8a1))
* repair proxmox missing file errors ([8a99488](https://github.com/Jasviers/homelab/commit/8a994886e46b4a7edd5958acb7bc40e91b41273f))
* repair renovate analysis ([c873755](https://github.com/Jasviers/homelab/commit/c8737556703f85d9144f2cc12ce4302a8732ec46))
* **synology-csi:** tolerate ai-dedicated taint on csi node daemonset ([f558a80](https://github.com/Jasviers/homelab/commit/f558a80c8cb0213e1e1acf4447f1e48154f91a52))
* typo in certmanager config ([72c78ca](https://github.com/Jasviers/homelab/commit/72c78ca9f0e5721c6390dbdad2ad344dd4240968))
* typo in certmanager config ([01c1c97](https://github.com/Jasviers/homelab/commit/01c1c9733bba79fbd7cf75f2b2763c3efa8e9e66))

## [1.12.0](https://github.com/Jasviers/homelab/compare/v1.11.0...v1.12.0) (2026-07-22)


### Features

* change vm architecture to have 2 vms to control plane, 2 workers and 1 worker for AI ([91990b2](https://github.com/Jasviers/homelab/commit/91990b214868b6f5ff721efb2ce66c3594a7885d))
* **services:** add ollama and whisper AI services with ArgoCD integration ([eef1afb](https://github.com/Jasviers/homelab/commit/eef1afbd2e8b216a6ccb9b69a2de0e5cfaf02583))


### Bug Fixes

* **synology-csi:** tolerate ai-dedicated taint on csi node daemonset ([f558a80](https://github.com/Jasviers/homelab/commit/f558a80c8cb0213e1e1acf4447f1e48154f91a52))

## [1.11.0](https://github.com/Jasviers/homelab/compare/v1.10.0...v1.11.0) (2026-06-20)


### Features

* add cilium pod cipher and http routes to proxmox and router ([7413798](https://github.com/Jasviers/homelab/commit/7413798792b14c343618cab05b6a307de8cdfeee))
* add clouflared and create tunnel to expose home assistant and give ([e435987](https://github.com/Jasviers/homelab/commit/e43598781633de59d6c11611993ce3111e385f23))
* add hubble to monitor k8s network ([40a63f4](https://github.com/Jasviers/homelab/commit/40a63f4397a15059ff06c7a702af91778d40a478))
* add new work network's firewall rules ([5e6daf7](https://github.com/Jasviers/homelab/commit/5e6daf7a25390f97ba57ab03e164aaae8ec50dba))
* improvement to gateway api. Headers and tls restrictions ([5779719](https://github.com/Jasviers/homelab/commit/577971985f5a7fd7b8042728659eb1a18cc3aba7))

## [1.10.0](https://github.com/Jasviers/homelab/compare/v1.9.0...v1.10.0) (2026-06-17)


### Features

* add concurrency to whisper ([60e6fa7](https://github.com/Jasviers/homelab/commit/60e6fa76c19d7522263dabec78694933ec60fa7d))


### Bug Fixes

* add grant_types to authentik blueprints ([410096f](https://github.com/Jasviers/homelab/commit/410096f25d508e6a3e523f9484ec59d2b07ff1c9))
* add grant_types to authentik blueprints ([4b36e76](https://github.com/Jasviers/homelab/commit/4b36e760948c7b1b20f621d9e8ae02c01729dab0))
* argo resolve bad dns ([c0e0ebf](https://github.com/Jasviers/homelab/commit/c0e0ebf0d0acfd8078454d9e59b9401708b67286))
* internal domain resolution to resolve authentik login ([a5f5115](https://github.com/Jasviers/homelab/commit/a5f5115850a4b2d26305ca53718b330299e381d2))

## [1.9.0](https://github.com/Jasviers/homelab/compare/v1.8.0...v1.9.0) (2026-06-17)


### Features

* add control to cilium version with renovate ([174eae1](https://github.com/Jasviers/homelab/commit/174eae1ef1390326fe431c0c8e3bd3f65351458f))
* add SSO config to argo and grafana ([b10ba20](https://github.com/Jasviers/homelab/commit/b10ba202e7f070b3b1b5b6af1f3499ccb2177a64))

## [1.8.0](https://github.com/Jasviers/homelab/compare/v1.7.0...v1.8.0) (2026-06-16)


### Features

* add cilium as CNI and modify instalation playbooks ([fcccbbc](https://github.com/Jasviers/homelab/commit/fcccbbc8ec39b7ec18e783e669baaca07d6e000a))
* add monitoring stack with grafana, prometheus, loki and alloy ([f028ae5](https://github.com/Jasviers/homelab/commit/f028ae54c192fbca3cd1a61bbe34f5381363d835))

## [1.7.0](https://github.com/Jasviers/homelab/compare/v1.6.2...v1.7.0) (2026-06-14)


### Features

* add synology-csi to manage volumens ([5ea970f](https://github.com/Jasviers/homelab/commit/5ea970ffd982e10fd504a12956377dbb00cab0d0))


### Bug Fixes

* homepage autodiscovery and routing to argocd ([8081147](https://github.com/Jasviers/homelab/commit/80811479bca41fd21f0aae1ca1beb2451cf44f5f))

## [1.6.2](https://github.com/Jasviers/homelab/compare/v1.6.1...v1.6.2) (2026-06-14)


### Bug Fixes

* homepage autodiscovery for gateway api ([d285dea](https://github.com/Jasviers/homelab/commit/d285dea5ec276bb5f78411aabb389dec3c105a3b))
* homepage autodiscovery for gateway api ([c7261fb](https://github.com/Jasviers/homelab/commit/c7261fbfab63843ffd5f5c10949f5d38c5e45406))

## [1.6.1](https://github.com/Jasviers/homelab/compare/v1.6.0...v1.6.1) (2026-06-14)


### Bug Fixes

* repair proxmox missing file errors ([b181b26](https://github.com/Jasviers/homelab/commit/b181b268d325a2a686025a0ee0a268f6f81ea8a1))
* repair proxmox missing file errors ([8a99488](https://github.com/Jasviers/homelab/commit/8a994886e46b4a7edd5958acb7bc40e91b41273f))

## [1.6.0](https://github.com/Jasviers/homelab/compare/v1.5.0...v1.6.0) (2026-06-13)


### Features

* add homepage portal ([e9a77d1](https://github.com/Jasviers/homelab/commit/e9a77d1b19ca2e4d89854f0d72eff7b84152282c))
* inprove IOT network script and add whisper and piper for home ([cf544ef](https://github.com/Jasviers/homelab/commit/cf544ef5ab3752a1b2f8afbaa3eabb10f60e45d4))


### Bug Fixes

* change argocd to run as insecure to repair loop of DNS redirections ([359b3db](https://github.com/Jasviers/homelab/commit/359b3db426b58dfad73ed82fd86c0fd658f1f35a))
* repair renovate analysis ([c873755](https://github.com/Jasviers/homelab/commit/c8737556703f85d9144f2cc12ce4302a8732ec46))

## [1.5.0](https://github.com/Jasviers/homelab/compare/v1.4.2...v1.5.0) (2026-06-13)


### Features

* change argocd deafault ip to gateway ([e9f59d7](https://github.com/Jasviers/homelab/commit/e9f59d7faed0f894e63bcec7dbd12fd4a6c02070))
* change argocd deafault ip to gateway ([7b70f00](https://github.com/Jasviers/homelab/commit/7b70f0080f31ddad0520c97a75cf48cfe7c634e9))

## [1.4.2](https://github.com/Jasviers/homelab/compare/v1.4.1...v1.4.2) (2026-06-12)


### Bug Fixes

* gateway kutomize files extension reference ([9b02beb](https://github.com/Jasviers/homelab/commit/9b02beb5c54de063d17c96572de84c8f60323410))
* gateway kutomize files extension reference ([5dd85eb](https://github.com/Jasviers/homelab/commit/5dd85eb5ed1d88afd9ad23e9c006edee38bac274))

## [1.4.1](https://github.com/Jasviers/homelab/compare/v1.4.0...v1.4.1) (2026-06-12)


### Bug Fixes

* typo in certmanager config ([72c78ca](https://github.com/Jasviers/homelab/commit/72c78ca9f0e5721c6390dbdad2ad344dd4240968))
* typo in certmanager config ([01c1c97](https://github.com/Jasviers/homelab/commit/01c1c9733bba79fbd7cf75f2b2763c3efa8e9e66))

## [1.4.0](https://github.com/Jasviers/homelab/compare/v1.3.0...v1.4.0) (2026-06-12)


### Features

* add gateway api with envoy ([bb47ce3](https://github.com/Jasviers/homelab/commit/bb47ce3b2d0bb246266cba5b8cb729efdb3d3ff8))
* add renovate to check and update dependencies ([534cdf9](https://github.com/Jasviers/homelab/commit/534cdf942c7a5b33f7bdf9f56c4dea38a414f7d4))

## [1.3.0](https://github.com/Jasviers/homelab/compare/v1.2.1...v1.3.0) (2026-06-10)


### Features

* add argocd apps with a root app to manage all ([50f43bb](https://github.com/Jasviers/homelab/commit/50f43bbbaa9451eb92d85684dc9be085e9f60892))
* argocd enable use helm ([d60c738](https://github.com/Jasviers/homelab/commit/d60c738b5ec1459a4500749bfafb6126c80cfbd5))
* **argocd:** add argocd deploy files ([9a5176a](https://github.com/Jasviers/homelab/commit/9a5176aeb3e2b8ca76956aa0d81f6b7e7dd600dc))
* backup docker compose file from raspberry pi ([573eb3b](https://github.com/Jasviers/homelab/commit/573eb3b53659692adc9db7f60b276c1ec78d7a86))
* **certmanager:** create manifest to deploy certmanager ([8f99b44](https://github.com/Jasviers/homelab/commit/8f99b44ad7cde073ac4644958379d13caea009c2))
* improve k3s deploy ([0e297c2](https://github.com/Jasviers/homelab/commit/0e297c2e79273cb3f48648cba8b84cb76b0d1cd2))
* metallb deploy configuration ([76e8b22](https://github.com/Jasviers/homelab/commit/76e8b22368d2bc3a28e86aa2f8afcb76f809bf56))
* **metallb:** remove helmfile and change to use helm with kustomize ([de0b697](https://github.com/Jasviers/homelab/commit/de0b6970e8d743e50375ce7dcc1be044479344e8))
* script to configure firewall rules for IOT network ([ac2c5e7](https://github.com/Jasviers/homelab/commit/ac2c5e7e60ef2d4070bd9dac856df9a2b8900ed1))
* terraform to deploy initial vms setup ([2e36643](https://github.com/Jasviers/homelab/commit/2e36643e9f11887b603abc485286edd2faf17486))
* update k3s playbooks to use directly k8s ips ([7e97eea](https://github.com/Jasviers/homelab/commit/7e97eea882b69e212d8e24cc9562da74a822dfdb))
* use ansible to configure packer template and cloud-init ([726ad93](https://github.com/Jasviers/homelab/commit/726ad9388463132df478cb0fe970ad9b67cdf130))

## [1.2.1](https://github.com/Jasviers/homelab/compare/v1.2.0...v1.2.1) (2026-06-02)


### Bug Fixes

* change trim to trimspace ([c2ac244](https://github.com/Jasviers/homelab/commit/c2ac2441885d0810734bb5e8c7e202dd0a8fc7e1))
* change trim to trimspace ([fee3c27](https://github.com/Jasviers/homelab/commit/fee3c272a2e51a3bd9cafa9c11885e5e54807b78))

## [1.2.0](https://github.com/Jasviers/homelab/compare/v1.1.0...v1.2.0) (2026-06-02)


### Features

* add gitignore ([d371633](https://github.com/Jasviers/homelab/commit/d3716332c7e845f7d710fa41b59cbca499e3414c))
* **argocd:** argocd basic deployment ([4db23ed](https://github.com/Jasviers/homelab/commit/4db23eddd3b918e29956b27109c81e7a7664fe94))
* **metallb:** new network configuration for metallb ([72b941b](https://github.com/Jasviers/homelab/commit/72b941bea87848bfae9d409e8d2f21a1a879a775))
* packer template to create ubuntu 26 templates in promox ([44943ee](https://github.com/Jasviers/homelab/commit/44943ee6c2229dd9daa781711295146c01a73f00))
* script to update dns register with current IP ([3db1336](https://github.com/Jasviers/homelab/commit/3db133695dc55ef8ca3633de0fae0fe69a855ece))
* **terraform:** proxmox vm module ([5993910](https://github.com/Jasviers/homelab/commit/599391079cb9de15c0a01b5e40b4271c9d19e4e0))
* update ansible inventory ([d3ae10d](https://github.com/Jasviers/homelab/commit/d3ae10d25bd6ee98d23eb2d76e0e9a0b3094195f))

## [1.1.0](https://github.com/Jasviers/homelab/compare/v1.0.0...v1.1.0) (2025-06-22)


### Features

* add markdownlint file ([db5e728](https://github.com/Jasviers/homelab/commit/db5e728b18f2875a5be491213b1e0802aa5623e2))


### Bug Fixes

* **ci:** typo on secrets reference ([f5131a0](https://github.com/Jasviers/homelab/commit/f5131a0db6effabee2bb9196b318291fc378ecdb))
* rename to add initial dot ([6909f0d](https://github.com/Jasviers/homelab/commit/6909f0d934aa9b1b34e83547c46bf83a284e8094))
