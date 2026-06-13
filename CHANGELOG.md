# Changelog

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
