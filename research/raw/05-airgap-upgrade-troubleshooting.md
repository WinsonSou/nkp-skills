# 05 — Air-gapped operations, registry, upgrades, troubleshooting (NKP 2.19)

Scope: air-gapped bundle contents and layout, `nkp push bundle` / mirror seeding, registry mirror + CA/credentials,
Harbor/Nexus/Artifactory/ECR, internal registry mirror, OS package bundles and offline image building,
air-gapped Kommander install + catalog bundles, licensing, air-gapped upgrade order, Pulse/Insights offline,
and the troubleshooting surface (`nkp diagnose`, CAPI/Flux/HelmRelease debugging, Rook Ceph).

Source tags: `[pdf p.N]` = `Nutanix-Kubernetes-Platform-v2_19.pdf` page; `[field: <note>]` = Obsidian vault
`~/Documents/<vault>`; `[repo: <path>]` = `~/Documents/everything-nkp`.

---

## Components

### NKP CLI (`nkp`)

- **What**: Single declarative binary that creates bootstrap/manage clusters, pushes bundles to registries, builds OS images, upgrades, and diagnoses.
- **Upstream**: Nutanix/D2iQ proprietary; `nkp diagnose` is a fork of `troubleshoot.sh` (`github.com/mesosphere/troubleshoot` v0.92.2-d2iq) `[pdf p.1049]`.
- **NKP role / name**: `nkp`; also shipped inside the air-gapped bundle under `./cli/nkp` and `./nkp` `[pdf p.770]` `[field: NKP Upgrade Notes]`.
- **Runs on**: operator machine / bastion host (Linux or macOS x86_64) `[pdf p.50]`.
- **Deployed by**: manual install from the Nutanix Portal (`tar -xzvf nkp_version_os_arch.tar.gz`, `sudo mv nkp /usr/local/bin/`, `nkp version`) `[pdf p.17]`.
- **Default**: required. **Version in 2.19**: must match target NKP version for create, upgrade and Kommander operations — mismatched binary breaks `nkp upgrade kommander` `[pdf p.1018]`.
- **Depends on / talks to**: Docker 27.4.0 (or Podman ≥4.0) for the KIND bootstrap cluster `[pdf p.50]`; `kubectl` 1.36.x `[pdf p.50]`; the infrastructure provider API; the local/internal registry.
- **Air-gap notes**: `nkp version` output lists the bundled sub-binaries and their versions: `catalog`, `diagnose`, `imagebuilder`, `kommander`, `konvoy`, `konvoybundlepusher`, `mindthegap` `[pdf p.1013]`. Sub-command families that matter air-gapped: `nkp push bundle`, `nkp create package-bundle`, `nkp create image <provider>`, `nkp upload image-artifacts`, `nkp create catalog-bundle`, `nkp install kommander --init --airgapped`, `nkp upgrade *`, `nkp diagnose`.
- **Note**: a plain `nkp create bundle` command is **not documented** in 2.19 — the documented bundle-creating commands are `nkp create package-bundle` (OS packages) and `nkp create catalog-bundle` (OCI catalog apps). See Gaps.
- **Key CLI**: `nkp version`, `nkp push bundle`, `nkp diagnose`, `nkp get kubeconfig`, `nkp describe cluster`
- **Sources**: `[pdf p.17-18, 50, 1013, 1018, 1049]`

### NKP air-gapped bundle (`nkp-air-gapped-bundle_<nkp-version>_linux_amd64.tar.gz`)

- **What**: The single tarball that carries every NKP artifact for a disconnected install or upgrade.
- **NKP role / name**: `nkp-air-gapped-bundle_<version>_linux_amd64.tar.gz`, extracted into `nkp-<version>/` (older docs wrote `NKP-air-gapped-bundle_...`) `[pdf p.51-52, 995]`.
- **Layout after extraction** (2.19 doc examples, pre-provisioned + control-plane pages):

```text
nkp-<nkp-version>/
├── application-charts/            NOTICES.txt, nkp-kommander-charts-bundle-<ver>.tar.gz,
│                                  nkp-insights-charts-bundle-<ver>.tar.gz
├── application-repositories/      nkp-insights-<ver>.tar.gz   (catalog GitRepository tarballs)
├── container-images/              NOTICES.txt, konvoy-image-bundle-<ver>.tar,
│                                  kommander-image-bundle-<ver>.tar,
│                                  nkp-insights-image-bundle-<ver>.tar,
│                                  nutanix-product-catalog-<ver>-airgapped.tar,
│                                  nkp-release-specs-<ver>.tar,
│                                  kubernetes-os-<os>-nkp-<ver>-v<k8s>_linux_amd64.tar
├── nkp                            nkp binary
├── cli/                           nkp (+ kubectl) used as ./cli/nkp
├── kib/                           Konvoy Image Builder: ansible, artifacts, goss, images,
│                                  konvoy-image, overrides, LICENSE, README.md
├── nib/                           Nutanix Image Builder artifacts dir (nkp create package-bundle target)
├── nkp-image-builder-<ver>.tar     NIB container image (docker load in air-gap)
├── konvoy-bootstrap-image-<ver>.tar  KIND bootstrap image
└── kubectl
```

  `[pdf p.770]` `[pdf p.997]` `[pdf p.712, 715]` (image names) `[pdf p.93]` (`konvoy-bootstrap-image-*.tar`)
- **What it does NOT contain**: distro/OS packages. "In previous NKP releases, the distro package bundles were included in the downloaded air-gapped bundle. Currently, that air-gapped bundle contains … with the exception of the distro packages." Contents listed as: NKP Kubernetes packages, Python packages (upstream), containerd tarball `[pdf p.73, 92, 1013]`.
- **Deployed by**: manual `tar -xzvf` on a bastion host with internet access during the download step, then carried in.
- **Default**: required for any air-gapped install/upgrade. Also usable in non-air-gapped environments to run a local registry `[pdf p.51]`.
- **Air-gap notes**: bootstrap image must be loaded first: `docker load -i konvoy-bootstrap-image-<ver>.tar` (podman allowed) `[pdf p.93, 770]`. `nkp push bundle` needs temp disk — set `TMPDIR` if `/tmp` is small `[pdf p.694]`.
- **Sources**: `[pdf p.51-52, 73, 92-93, 712, 715, 770, 995-996, 997, 1013]`

### `container-images/konvoy-image-bundle-<ver>.tar`

- **What**: Tar of all container images the Konvoy (cluster) layer needs — Kubernetes control plane, kube-proxy, CNI, CSI, kube-vip, node feature discovery, autoscaler.
- **NKP role / name**: `konvoy-image-bundle-<nkp-version>.tar`; pushed with `nkp push bundle --bundle ./container-images/konvoy-image-bundle-<ver>.tar --to-registry=...`
- **Runs on**: node OS (pulled at kubelet/containerd level).
- **Deployed by**: `nkp push bundle`; or declared to `nkp create cluster ... --bundle` (internal registry mirror mode); or baked into the OS image with `nkp create image ... --bundle` `[pdf p.61, 712]`.
- **Default**: required, every install/upgrade.
- **Depends on / talks to**: the registry mirror the node's containerd is configured to use.
- **Air-gap notes**: must be pushed **before** cluster create and **before** upgrade of management/workload clusters `[pdf p.1014]`; also included in the OS-image `--bundle` flag path.
- **Sources**: `[pdf p.95, 996, 1014, 715]`

### `container-images/kommander-image-bundle-<ver>.tar`

- **What**: Tar of all images for the Kommander platform layer (UI, Flux, Gatekeeper, monitoring/logging/rook, catalog tooling).
- **NKP role / name**: `kommander-image-bundle-<nkp-version>.tar`
- **Runs on**: management cluster + workload clusters (platform apps).
- **Deployed by**: `nkp push bundle` then `nkp install kommander` / `nkp upgrade kommander`.
- **Default**: required for Kommander tier installs and for every NKP upgrade.
- **Air-gap notes**: Kommander install additionally requires the charts and catalog repos from the same bundle — the documented 2.19 push command bundles four tars at once:
  `--bundle ./container-images/kommander-image-bundle-<ver>.tar,./container-images/konvoy-image-bundle-<ver>.tar,./container-images/nutanix-product-catalog-<ver>-airgapped.tar,./container-images/nkp-release-specs-<ver>.tar` `[pdf p.945, 1014-1015]`
- **Sources**: `[pdf p.903-907, 945, 1014]`

### `container-images/nutanix-product-catalog-<ver>-airgapped.tar` (NDK catalog)

- **What**: Images for the Nutanix product catalog, exclusively Nutanix Data Services for Kubernetes (NDK).
- **NKP role / name**: `nutanix-product-catalog-<nkp-version>-airgapped.tar`; air-gapped variant of `github.com/nutanix-cloud-native/nkp-nutanix-product-catalog`.
- **Runs on**: management or workload cluster (NDK is cluster-scoped).
- **Deployed by**: `nkp create catalog-bundle --airgapped --apps=ndk=<ndk-version>` → `nkp push bundle` → `nkp create catalog-application --url oci://<registry>/nkp-nutanix-product-catalog/ndk --tag <ver> --workspace kommander-workspace` `[pdf p.340]`
- **Default**: optional.
- **Air-gap notes**: **Nutanix infrastructure only** — exclude this bundle on Pre-provisioned, AWS, Azure, vSphere, GCP `[pdf p.946, 1015]`. Requires Nutanix DockerHub credentials (`docker login --username nutanixndk`) when building the bundle; max two access tokens per org `[pdf p.340, 675]`.
- **Sources**: `[pdf p.340, 675, 946, 1015]`

### `container-images/nkp-release-specs-<ver>.tar`

- **What**: Release metadata images (version/compatibility specs) consumed by the platform.
- **NKP role / name**: `nkp-release-specs-<nkp-version>.tar`
- **Deployed by**: `nkp push bundle` (part of the four-tar Kommander set).
- **Default**: required when installing/upgrading Kommander air-gapped `[pdf p.945]`.
- **Sources**: `[pdf p.945, 715, 1014]`

### NKP Insights bundles (`nkp-insights-image-bundle`, `nkp-insights-charts-bundle`, `application-repositories/nkp-insights-*`)

- **What**: Images + Helm charts + catalog repository tarball for NKP Insights (predictive analytics/alerts).
- **NKP role / name**: `container-images/nkp-insights-image-bundle-<ver>.tar`, `application-charts/nkp-insights-charts-bundle-<ver>.tar.gz`, `application-repositories/nkp-insights-<ver>.tar.gz` `[pdf p.770]`
- **Runs on**: management cluster (`nkp-insights-management`) and each monitored managed/attached cluster.
- **Deployed by**: Kommander platform app; enabled in `kommander.yaml` under `apps.nkp-insights-management.enabled: true` `[pdf p.1100]`.
- **Default**: optional (documented as a Kommander install decision) `[pdf p.941]`.
- **Air-gap notes**: air-gapped install sets Ceph-backed S3 storage in the installer config (`backend.s3.endpoint: rook-ceph-rgw-nkp-object-store`, `storageClassName: nkp-object-store`, `enableObjectBucketClaim: true`) `[pdf p.1100]`; the air-gapped catalog repository is registered as `catalog.repositories[].path: ./application-repositories/nkp-insights-v<ver>.tar.gz` `[pdf p.1101]`. The Trivy vulnerability DB is **frozen at the release build** in air-gap; refresh requires building `mesosphere/trivy-bundles` (`make create-airgapped-image-bundle`), pushing it to the registry, and updating the Trivy CronJob image `[pdf p.1119-1120]`.
- **Sources**: `[pdf p.770, 1100, 1101, 1119-1120]`

### `application-charts/` (ChartMuseum chart bundles)

- **What**: Helm chart tarballs consumed by ChartMuseum in air-gapped installs.
- **NKP role / name**: `nkp-kommander-charts-bundle-<ver>.tar.gz`, `nkp-insights-charts-bundle-<ver>.tar.gz`, plus `NOTICES.txt` `[pdf p.770, 997]`
- **Runs on**: management cluster (ChartMuseum pod).
- **Deployed by**: Kommander installer; ChartMuseum is **installed only in air-gapped installations** — "In non-air-gapped installations, the charts are fetched from upstream repositories, and ChartMuseum is not installed" `[pdf p.1068]`.
- **Default**: automatic in air-gap.
- **Air-gap notes**: ChartMuseum first reconciles only after the management Git repository is created and populated (its chart lives in the GitRepository) `[pdf p.1070]`. Helm repository URLs can be redirected with the `${helmMirrorURL:=...}` substitution variable `[pdf p.1070]`.
- **Key objects**: `chartmuseum` HelmRelease, `kommander-flux` namespace, `kommander-vars` ConfigMap
- **Sources**: `[pdf p.1068-1070]`

### `application-repositories/` + `nkp create catalog-bundle` (OCI catalog apps)

- **What**: Flux `OCIRepository`-consumable OCI artifacts holding catalog applications and (with `--airgapped`) their container images.
- **NKP role / name**: `nkp create catalog-bundle --collection-tag <tag>` (all app versions in cwd), `--apps=<name>=<version>` to select, `--airgapped` to include images. Output is a `.tar` pushed with `nkp push bundle --to-registry <registry>` `[pdf p.357]`. Default catalog repos live under `application-repositories/*.tar.gz`.
- **Runs on**: management cluster (catalog propagation to workspaces/projects).
- **Deployed by**: `nkp create catalog-collection --url oci://<registry>/<repo>/collection --workspace <ns> --tag <tag>` or `nkp create catalog-application`; a catalog created in `kommander-workspace` propagates to **all** workspaces `[pdf p.340, 357]`.
- **Default**: optional.
- **Air-gap notes**: `--airgapped` is **required** for air-gapped environments (it embeds container images); registry must be OCI-compliant; verify `kubectl get ocirepository -n <ns>` READY `[pdf p.357]`.
- **Sources**: `[pdf p.340, 357, 379]`

### Konvoy Image Builder (`kib/`) and Nutanix Image Builder (`nkp-image-builder`, `nib/`, NIB)

- **What**: Builds NKP-compatible OS images (all providers) and configures pre-provisioned hosts; run by the CLI as a container.
- **Upstream**: `github.com/nutanix-cloud-native/konvoy-image-builder` (kib/KIBA) and NIB (packer-based; field note shows `mesosphere/nkp-image-builder:vX` container running `packer build`) `[field: NKP Image Builder Find temp SSH Key and Username]`.
- **NKP role / name**: bundle dirs `kib/` and `nib/`; container tarball `nkp-image-builder-<ver>.tar`.
- **Runs on**: bastion / operator machine (container), plus a temporary VM on the target infrastructure.
- **Deployed by**: `nkp create image <provider> <os> ...`; for pre-provisioned `nkp upload image-artifacts`.
- **Default**: required except when using the Nutanix-provided AHV images `[pdf p.694]`.
- **Air-gap notes (critical)**:
  - Load the builder image first: `docker load --input "nkp-<ver>/nkp-image-builder-<ver>.tar"` `[pdf p.712]`.
  - OS packages are **not** in the bundle: build a package bundle on an internet-connected machine with vendor repos reachable, then carry it in: `nkp create package-bundle <OS_TYPE> --artifacts-directory <dir>` (`ubuntu-22.04`, `rocky-9.6`, `rhel-8.10`; RHEL needs `RHSM_ORG_ID` + `RHSM_ACTIVATION_KEY`) `[pdf p.73, 711]`. Result lands in `nkp-<ver>/nib/artifacts` (`OS_BUNDLE_DIR`).
  - Point the builder at it: `--artifacts-directory nkp-<ver>/nib/artifacts` `[pdf p.712]`.
  - Bake images into the OS image when the node cannot reach a registry: `nkp create image nutanix $OS ... --bundle ./nkp-<ver>/container-images/konvoy-image-bundle-<ver>.tar` (comma-separated list allowed, `.tar` only) `[pdf p.61, 712]`.
  - Bastion jump: `--bastion-host`, `--bastion-username`, `--bastion-private-key-file`, `--bastion-port` `[pdf p.59, 73-74]`.
  - FIPS: `--fips` plus `fips.yaml` override file shipped with the image bundles `[pdf p.989]`.
  - NIB can build without internet when given `--override` (per upgrade doc wording; see Gaps) `[pdf p.1012]`.
  - `nkp create package-bundle` must run **outside** the air gap (needs vendor package repos) `[pdf p.60]`.
- **Key CLI**: `nkp create image {nutanix|aws|azure|gcp|vsphere}`, `nkp create package-bundle`, `nkp upload image-artifacts`
- **Sources**: `[pdf p.59-61, 71-74, 711-712, 989, 1012-1014, 1015]` `[field: NKP Image Builder Find temp SSH Key and Username]` `[field: NKP CIS Ubuntu Custom Image]`

### `nkp upload image-artifacts` (pre-provisioned host configuration)

- **What**: Pushes the OS packages, container images, containerd tarball, pip packages and optional NVIDIA driver onto existing hosts over SSH (Ansible under the hood).
- **NKP role / name**: `nkp upload image-artifacts`; target paths on the host: `/opt/dkp/packages/`, `/opt/dkp/containerd/`, etc. `[pdf p.74]`
- **Runs on**: pre-provisioned node OS.
- **Deployed by**: CLI; also invoked implicitly during pre-provisioned cluster creation ("NIB is built into NKP and automatically runs the machine configuration process against the set of nodes that you defined") `[pdf p.99]`.
- **Default**: required for pre-provisioned air-gap.
- **Air-gap notes**: 2.19 form is `--artifacts-directory <dir>` (bundle + package bundle), **not** the older `--os-packages-bundle/--containerd-bundle/--pip-packages-bundle` KIBA form `[pdf p.73-74]` vs `[repo: nkp-preprov/5.upload_package_bundle.sh]`. Optional flags: `--nvidia-runfile <runfile>`, `--provider aws|azure|gcp|vsphere|nutanix`, `--fips`, `--ssh-host a,b,c`, `--ssh-username`, `--ssh-private-key-file|--ssh-password`, `--ssh-port`.
- **Sources**: `[pdf p.71-74, 99, 801-802, 1014]`

### Local registry mirror (Harbor / Nexus / Artifactory / AWS ECR)

- **What**: A registry (or proxy-cache) reachable from the bastion **and** every cluster node, holding all NKP images.
- **NKP role / name**: "local registry mirror"; `--registry-mirror-url`, `--registry-mirror-cacert`, `--registry-mirror-username`, `--registry-mirror-password`.
- **Runs on**: bastion host or dedicated VM, outside the cluster.
- **Deployed by**: manual (vendor installer) + `nkp push bundle --to-registry=$REGISTRY_URL --to-registry-username= --to-registry-password= --to-registry-ca-cert-file=`.
- **Default**: required for air-gap.
- **Supported tools**: JFrog Artifactory (**must be newer than 7.11**), Nexus Repository (Proxy/Hosted/Group), Harbor (**≥ v2.1.1-5f52168e for OCI**), AWS ECR `[pdf p.991-992]`.
- **Air-gap notes**:
  - CA chain: `export REGISTRY_CA=<path>`; or fetch it: `openssl s_client -showcerts -connect $HOST:$PORT </dev/null | openssl x509 -outform PEM > $CA` `[pdf p.714]`.
  - Harbor + `nkp push`: `... mount=sha256:... UNAUTHORIZED: project not found, name: mesosphere` is a **false positive** for NKP > 2.14.0 — the image *is* pushed; safe to ignore (Nexus/Artifactory unaffected) `[pdf p.992]`.
  - ECR: `--to-registry=<acct>.dkr.ecr.<region>.amazonaws.com/<repo>`; no static ECR credentials needed for cluster creation — the push host must be AWS-authenticated `[pdf p.991-992]`.
  - Docker Hub rate limits: you may point `--registry-mirror-url=https://registry-1.docker.io` with Docker Hub creds `[pdf p.682]`. In a **connected** cluster without a mirror, NKP pulls platform images from `docker.io/nutanix` using a Nutanix PAT (`--nutanix-registry-username/--nutanix-registry-password`, rotate with `nkp update cluster nutanix-registry-credentials`) — **not used air-gapped** `[pdf p.675, 677-678]`.
- **Key objects/flags**: `/etc/containerd/certs.d`, `ca-konvoy-mirror.crt`, `--to-registry-ca-cert-file`, `--to-registry-insecure-skip-tls-verify`
- **Sources**: `[pdf p.674-675, 681-682, 713-715, 990-992]` `[field: Harbor Installation on a VM]` `[field: Registry for Lab]`

### Internal registry mirror (in-cluster)

- **What**: A registry hosted **on** an NKP cluster, populated from the air-gapped bundle by NKP itself; nodes pull platform images from it.
- **NKP role / name**: "Internal Registry Mirror" `[pdf p.24-25]`; CLI surface: `nkp push bundle ... --to-internal-registry-mirror --kubeconfig=<mgmt.conf>` `[pdf p.946]`, and `nkp create cluster ... --bundle <tars>` on the create path `[pdf p.722-723]`.
- **Runs on**: management cluster (and can be seeded per workload cluster with that cluster's kubeconfig).
- **Deployed by**: NKP (auto-deployed when neither a mirror nor a private registry is supplied: "the system automatically deploys an in-cluster private registry that acts as a pull-through cache") `[pdf p.717]`.
- **Default**: air-gap default when you do not bring your own mirror.
- **Air-gap notes**:
  - **Do not combine** `--bundle` (internal registry mirror) with `--registry-mirror-*` (local mirror) in one create: "Do not use both BUNDLE_FLAG and REGISTRY_MIRROR_FLAG simultaneously" `[pdf p.725]`.
  - `--airgapped=true` is a separate flag that "runs the NKP UI, and other NKP applications in an air-gapped environment" `[pdf p.723]`.
  - Seeding a pre-existing/internal registry is **optional since NKP 2.16**: "This procedure is optional and not mandatory for clusters created from NKP 2.16 onwards" `[pdf p.996]`.
- **Sources**: `[pdf p.24-25, 717, 722-725, 946, 995-996]`

### containerd registry mirror + dynamic-credential-provider (node plumbing)

- **What**: Per-node containerd mirror config and kubelet `CredentialProviderConfig` / `DynamicCredentialProviderConfig` that make node image pulls work with one or many registries.
- **NKP role / name**: NKP renders these into CAPI `KubeadmConfig`/`KubeadmConfigTemplate` `files:`; the mirror blob is stored in secrets `<cluster>-control-plane-containerd-configuration` and `<cluster>-md-0-containerd-configuration` under key `mirror` `[field: Multiple Registry Configuration for Preprovisioned]`. Plugin: `ghcr.io/mesosphere/dynamic-credential-provider` (`apiVersion: credentialprovider.d2iq.com/v1alpha1`) `[repo: preprov-registry-stuff/multiple-registry.yaml]`.
- **Runs on**: node OS.
- **Deployed by**: CAREN ClusterClass node template (`caren.nutanix.com/version` annotation on generated templates) `[repo: preprov-registry-stuff/multiple-registry.yaml]`.
- **Air-gap notes**:
  - Mirror default pattern: `[plugins."io.containerd.grpc.v1.cri".registry.mirrors."*"] endpoint = ["https://<registry>/v2", "https://<registry>/v2/mirror"]`, `docker.io` overridden explicitly, CA at `/etc/containerd/ca-konvoy-mirror.crt` `[field: Multiple Registry Configuration for Preprovisioned]`.
  - `credentialsStrategy: MirrorCredentialsOnly` vs `MirrorCredentialsFirst` (fallback to origin registry) `[repo: preprov-registry-stuff/how-to-replicate-registry-config.md]`.
  - Adding a registry with a **path** needs `override_path = true` in `hosts.toml` (containerd mis-adds `/v2/` for path mirrors) `[repo: preprov-registry-stuff/how-to-replicate-registry-config.md]`.
  - Existing nodes only pick up changes on new machines — force a rollout:
    `kubectl patch machinedeployment -n <ns> <name> --type=merge -p '{"spec":{"rolloutAfter":"<RFC3339>"}}'` (same for `kubeadmcontrolplane`), after running the image-artifact upload first `[field: Multiple Registry Configuration for Preprovisioned]` `[field: Troubleshooting NKP Deployment]`.
- **Sources**: `[field: Multiple Registry Configuration for Preprovisioned]` `[repo: preprov-registry-stuff/]`

### Bastion host (air-gap operator host)

- **What**: The machine in the disconnected network that holds the bundle, the registry and runs `nkp`.
- **NKP role / name**: "bastion VM / bastion host"; naming template suggestion `<folder>/NKP-bastion-template` or `NKP-e2e-bastion-template` `[pdf p.46, 694]`.
- **Runs on**: infrastructure VM (needs provider API access, and registry access).
- **Deployed by**: manual.
- **Default**: required air-gap.
- **Air-gap notes**: sizing vCPU 8 / 16 GB RAM / 80 GB disk `[pdf p.680]`; needs `kubectl` 1.36.x and Docker 27.4.0 (or Podman ≥4.0) `[pdf p.50, 680]`; must be able to reach the registry **and** the provider API `[pdf p.679-680]`. For AWS the bastion must sit in the target VPC `[pdf p.821]`.
- **Sources**: `[pdf p.46, 50, 679-681, 694, 821]`

### Kommander (platform application manager) — air-gapped install path

- **What**: Installs and manages the platform applications on the management cluster (UI dashboard, Flux, catalogs) and federates them to workspaces/clusters.
- **Upstream**: D2iQ/Nutanix Kommander on Flux v2 `[pdf p.1058-1059]`.
- **NKP role / name**: Kommander component; installer config `kommander.yaml` from `nkp install kommander --init --airgapped`.
- **Runs on**: management cluster (namespace `kommander`, Flux in `kommander-flux`).
- **Deployed by**: `nkp install kommander --installer-config kommander.yaml --kubeconfig=<mgmt.conf>`; upstream chain per `[pdf p.1069-1070]`: Base → Flux → Root CA (`kommander-ca`) → ChartMuseum (air-gap only) → Helm Repositories → Ingress Certificate → Bootstrap Repository (`apps-kommander` Kustomization) → Age → Flux Configuration (`kommander-vars`) → Gatekeeper → AppManagement → Core AppDeployments → Optional AppDeployments → Catalog Repository Loader.
- **Default**: enabled (Pro/Ultimate = Kommander UI; Starter = Konvoy only; **Air-Gapped Deployments** row is marked for all three tiers in the feature matrix) `[pdf p.26]`.
- **Air-gap notes**:
  - `nkp install kommander --init --airgapped > kommander.yaml`, then `nkp install kommander --installer-config kommander.yaml --kubeconfig=<mgmt.conf>` `[pdf p.943-944]`.
  - **AI Navigator is not installed in air-gapped environments** "for security purposes" `[pdf p.942]`.
  - Pre-provisioned air-gap needs an explicit `rook-ceph-cluster` storage override because the default PVC/`volumeMode: Block` path is impossible on `localvolumeprovisioner`: `storageClassDeviceSets: []`, `useAllNodes: true`, `useAllDevices: true` (or a `deviceFilter` such as `^sdb.`) `[pdf p.103]`.
  - Certificate: public ACME/Let's Encrypt does not work air-gapped — use the cluster-issued self-signed cert (default) or a certificate created manually with a trusted CA `[pdf p.491]`.
  - Required connectivity between management and attached clusters: both must reach the local registry; management must reach every attached cluster's API server and any platform-service load balancers `[pdf p.52, 945]`.
  - No internet → no Kommander upgrade via Nutanix Marketplace; marketplace installs also cannot be upgraded that way `[pdf p.718]`.
- **Key CLI/objects**: `nkp install kommander`, `nkp upgrade kommander`, `AppDeployment`, `ClusterApp`, `HelmRelease`, `Kustomization`, `OCIRepository`
- **Sources**: `[pdf p.52, 103-104, 941-946, 1068-1070]`

### NKPCluster CRD + admission webhook

- **What**: Single source of truth wrapping a CAPI `Cluster` + `KommanderCluster`; blocks direct `spec.topology` edits.
- **NKP role / name**: `clusters.nkp.nutanix.com/v1alpha1 NKPCluster`; webhook `webhook.nkpcluster.child.kommander.mesosphere.io`.
- **Runs on**: management cluster (namespace = workspace).
- **Deployed by**: Kommander upgrade (2.18+ model).
- **Air-gap notes**: GitOps-managed workload clusters must migrate from `Cluster` to `NKPCluster` before upgrade; a Flux apply against the old `Cluster` fails with `spec.topology: Forbidden: CAPI Cluster topology spec is managed by NKPCluster` `[pdf p.1048]`. Status traverses `Reconciling…` → `Reconciled` `[pdf p.1046]`.
- **Sources**: `[pdf p.1035-1036, 1046-1048]`

### `nkp diagnose` (support bundle)

- **What**: Collects a support bundle (cluster info, cluster resources incl. all CRDs/CRs, configmaps, secret metadata only, node diagnostics, all pod logs) for the last 48 h.
- **Upstream**: `troubleshoot.sh` v0.92.2 with NKP patches — `github.com/mesosphere/troubleshoot` `[pdf p.1049]`.
- **NKP role / name**: `nkp diagnose`; collectors `clusterInfo`, `clusterResources`, `configMap`, `secrets`, `execCopyFromHost`, `allLogs`.
- **Runs on**: operator machine (uses `--kubeconfig`, defaults like kubectl).
- **Deployed by**: CLI.
- **Default**: the primary support artifact.
- **Air-gap notes**: the node collector needs the images `mesosphere/pause-alpine:3.2` and `mesosphere/nkp-diagnostics-node-collector:<nkp-diagnose version>` **in the air-gapped registry** or they will not pull. Default collector timeout 30 s can be too short — raise it or set `timeout: 0` `[pdf p.1053-1054]`. Bootstrap-cluster bundle: `nkp diagnose --bootstrap-kubeconfig <path>` → `bootstrap-support-bundle-<date>.tar.gz` `[pdf p.1050-1051]`. API-server-down fallback: `nkp diagnose ssh <ansible-inventory.yaml>` (only `ansible_host/port/user/ssh_private_key_file` honoured) `[pdf p.1051-1052]`. Custom collectors: `nkp diagnose default-config > bundle.yaml`, edit, `nkp diagnose bundle.yaml`.
- **Key CLI**: `nkp diagnose`, `nkp diagnose default-config`, `nkp diagnose ssh`, `--bundle-name-prefix`
- **Sources**: `[pdf p.1049-1056, 1003]`

### Pulse telemetry

- **What**: Opt-in usage telemetry to Nutanix.
- **Runs on**: management cluster; toggle in UI `Settings > Pulse` (global admin only).
- **Default**: prompt on first login; visible for Starter/Pro/Ultimate.
- **Air-gap notes**: Pulse **requires** `https://insights.nutanix.com:443`. In air-gap that domain is unreachable, so Pulse cannot send; the "Required Domains" list states the domains "need not be accessible" in an air-gapped installation and names `insights.nutanix.com` only for Pulse `[pdf p.53-54, 663]`. Leave Pulse disabled air-gapped; nothing in the platform depends on it.
- **Sources**: `[pdf p.53-54, 662-664]`

### NKP license

- **What**: Core-count license token enabling Starter/Pro/Ultimate feature sets.
- **Runs on**: management cluster (`kommander` namespace).
- **Deployed by**: UI `Settings > Licensing > Activate/Update`, **or** offline via kubectl: `kubectl create secret generic <name> --from-literal=nutanix-license-key=<token> -n kommander` + `License` object (`kommander.mesosphere.io/v1beta1`, `spec.nutanixLicenseRef.name`) `[pdf p.31]`.
- **Default**: a default key is auto-assigned (Starter on AHV, Pro elsewhere); replace with the purchased key. **No downgrade** after registration `[pdf p.26, 28]`.
- **Air-gap notes**: the license **token** is a string — activation via UI or kubectl secret works with no internet. The **AWS Marketplace** license path (License Manager, `AWSLicenseManagerConsumptionPolicy`, ARN, ECR image pull) explicitly requires "Active Internet connectivity" and is therefore not an air-gap path `[pdf p.29-31]`. Applying Pro/Ultimate triggers extra app installs (AI Navigator, Centralized Grafana) — AI Navigator will not install air-gapped `[pdf p.29, 942]`.
- **Sources**: `[pdf p.26, 28-31, 942]`

### Rook Ceph (air-gapped Kommander storage dependency)

- **What**: Provides block storage and the `dkp-object-store` CephObjectStore used by Loki/NKP Insights in air-gap.
- **NKP role / name**: platform apps `rook-ceph`, `rook-ceph-cluster`; `CephObjectStore/dkp-object-store` in the workspace namespace.
- **Runs on**: management cluster and workload clusters (Ultimate).
- **Deployed by**: Kommander AppDeployments.
- **Air-gap notes**: images come from `kommander-image-bundle`; pre-provisioned needs the host-mode override (see Kommander). Install failure signature and fix: see Troubleshooting below `[pdf p.1071-1072]`.
- **Sources**: `[pdf p.103, 1071-1072]`

### MetalLB / kube-vip (air-gap load balancing)

- **What**: Announces `LoadBalancer` service IPs where no external LB exists.
- **NKP role / name**: `metallb-system` namespace, `IPAddressPool` + `L2Advertisement`/`BGPAdvertisement`; or kube-vip via `--virtual-ip-interface`.
- **Runs on**: management + workload clusters.
- **Deployed by**: manual manifests for pre-provisioned (`kubectl apply -f metallb-conf.yaml`); automatic for cloud providers.
- **Air-gap notes**: images ship in `konvoy-image-bundle`; the LB IP range must be routable from the air-gapped client network `[pdf p.102, 593]`.
- **Sources**: `[pdf p.102, 1150-1247 (pre-prov MetalLB), 593]`

---

## Air-gapped install/upgrade runbook (as documented, per infrastructure)

Common ordering that the 2.19 docs imply across all providers:

1. Outside the air gap: download bundle + CLI; if OS images are needed, `nkp create package-bundle <os>` (needs vendor repos).
2. Carry bundle in; `tar -xzvf`; put `./cli/nkp` (or `nkp`) on PATH; verify `nkp version`.
3. `docker load -i konvoy-bootstrap-image-<ver>.tar`; for NIB builds `docker load --input nkp-image-builder-<ver>.tar`.
4. `nkp push bundle` konvoy (+ Kommander set, + OS image tar, + catalog) into the local mirror **or** `--to-internal-registry-mirror`.
5. Pre-provisioned only: `nkp upload image-artifacts --artifacts-directory …` to every host.
6. `nkp create cluster <provider> … --registry-mirror-url/-cacert/-username/-password` (or `--bundle …` + `--airgapped=true`).
7. `nkp install kommander --init --airgapped > kommander.yaml` → edit → `nkp install kommander --installer-config kommander.yaml`.
8. Managed clusters: repeat step 6 without `--self-managed`.

Per-infrastructure summary of what "air-gapped" changes:

| Infrastructure | Air-gap specifics |
|---|---|
| Nutanix AHV | Bastion VM template with local-registry access; `nkp create package-bundle` + `nkp create image nutanix $OS --artifacts-directory … --bundle konvoy-image-bundle…` (or use the Nutanix-provided image); choose exactly one of internal-registry (`--bundle`) or local mirror (`--registry-mirror-*`) `[pdf p.693-694, 710-725]`. Nutanix Marketplace UI deploy supports a Registry tab where leaving both mirror fields empty auto-deploys an internal registry `[pdf p.717]`. |
| Pre-provisioned (bare metal / AHV / cloud) | Full air-gap chapter: artifacts → hosts, registry seed, MetalLB, Kommander; GPU variants add `--nvidia-runfile` (NVIDIA runfile e.g. `NVIDIA-Linux-x86_64-580.126.18.run` staged in `artifacts/`) `[pdf p.92-109, 154-161, 800-802]`. |
| vSphere | "Loading the Registry: required for air-gapped, optional otherwise"; bastion VM with local registry; append `--registry-mirror-url/-username/-password` to `nkp create cluster vsphere`; image build supports `--artifacts-directory` and bastion flags `[pdf p.834, 841, 409 (create), 68-70, 71]`. |
| AWS / EKS | Bastion **inside the VPC**; push to ECR or Harbor/JFrog; `nkp push bundle` from `cli/` dir with `--to-registry-ca-cert-file`; specify a **bundle AMI** ("Nutanix does not recommend upstream CAPA images for production"; AMI required) `[pdf p.821, 827-828, 1012]`. |
| Azure / AKS | Registry load before install; Azure Compute Gallery image built by NIB; upgrade needs `--compute-gallery-id` (+ `--plan-offer/--plan-publisher/--plan-sku` if used at create) `[pdf p.188-190, 1029-1030]`. |
| GCP | Registry load before install; NIB-built GCP image; upgrade needs `--image=projects/<proj>/global/images/<img>` `[pdf p.227-230, 1030]`. |
| Metal (NKP Metal) | Stage the host OS **ISO** *and* container images in the local/internal mirror; "Defining a mirror registry is required if you have an air-gapped environment"; `nkp create cluster metal --help` lists registry/air-gap flags `[pdf p.741, 749-755, 801]`. |

Required external domains (non-air-gap only; **not** needed air-gapped): `docker.io, gcr.io, k8s.gcr.io, mcr.microsoft.com, quay.io, us.gcr.io, registry.k8s.io, nvcr.io, pkg-containers.githubusercontent.com, charts.bitnami.com, charts.jetstack.io, charts.rook.io, cloudnative-pg.io, grafana.github.io, helm.goharbor.io, helm.ngc.nvidia.com, helm.traefik.io, jaegertracing.github.io, kiali.io, kubecost.github.io, kubernetes.github.io, mesosphere.github.io, open-policy-agent.github.io, prometheus-community.github.io, fluent.github.io, kube-logging.github.io, raw.githubusercontent.com, insights.nutanix.com` `[pdf p.53-54]`.

---

## Air-gapped upgrade

**Order (mandatory)** `[pdf p.1008-1047]`:

1. Install the **target NKP CLI** (must match target version).
2. Seed the registry: `nkp push bundle` for the target version's bundles (local mirror) **or** `--to-internal-registry-mirror --kubeconfig=<mgmt.conf>`; for pre-provisioned also refresh host artifacts with `nkp upload image-artifacts`; build `nkp create package-bundle <os>` for the target k8s version if images are built.
3. `nkp upgrade kommander` — **Kommander first**, before any cluster infrastructure. Upgrades the management plane (CAPI + ClusterClass + platform apps).
4. Upgrade the **management cluster** (`nkp upgrade cluster <provider> --cluster-name … --namespace … --vm-image …`).
5. Upgrade **workload clusters** (UI *Administration > Upgrades* or `nkp upgrade cluster …`), each one individually, any order after 4.

Key rules and gotchas:

- **Sequential minor versions only**; patch versions may be skipped (2.15.0 → 2.16.1 directly is fine, 2.14 → 2.16 is not). 2.19 upgrade matrix accepts **2.18.0 → 2.19.0** and **2.17.x → 2.19.0** `[pdf p.1011-1012]`.
- **ClusterClass path** (Nutanix AHV, EKS): one combined command upgrades platform apps + k8s + infra: `nkp upgrade cluster infrastructure-provider`. **Non-ClusterClass path** (AWS, Azure, vSphere, GCP, pre-provisioned): `nkp upgrade addons <provider>` → `nkp update controlplane <provider>` → `nkp update nodepool <provider> <pool>` (`-n kommander` for the management cluster **since 2.18**) `[pdf p.1016, 1018-1034]`.
- Read cluster name/namespace from the host `NKPCluster.status.capiClusterRef`, not `metadata.name` `[pdf p.1020]`.
- Parallel node pools: annotation `topology.cluster.x-k8s.io/upgrade-concurrency: "3"` (default = one pool at a time) `[pdf p.1018, 1020]`.
- **NKP 2.18 → 2.19 gating items**: (a) Kommander *and* management-cluster upgrade must be done from the **CLI**; (b) converge every cluster to a **single Prism Central project** first (`nkp update nodepool` cannot fix the project); (c) disable **Flux pruning** on GitOps kustomizations before migrating. `[pdf p.1015-1016, 1019, 1037, 1048]`
- Kubernetes version skew: the target CLI picks its default Kubernetes version; override only with `--kubernetes-version`; OS image must match the target k8s version; control plane first, then node pools `[pdf p.1020, 1027-1031]`. EKS supports k8s ≥1.34 and needs ClusterClass — non-ClusterClass EKS clusters cannot be upgraded (KB-21858) `[pdf p.1011]`.
- Upgrading Kommander logs users out of attached clusters (auth token change): re-fetch kubeconfig from `https://<traefik>/token/plugin/kubeconfig` `[pdf p.1017-1018]`.
- Air-gapped Kommander upgrade **no longer takes chart-bundle/`--disallow-charts-download` flags** in 2.19 docs — seeding images is the whole offline step (contrast 2.13/2.16 field notes) `[pdf p.945, 1014-1015]` vs `[field: NKP Upgrade Notes]`.
- Verify: `nkp version`; `kubectl get nkpclusters,machines -n kommander|<workspace>`; `kubectl get nodes`; `kubectl get pods -A`; GitOps: `kubectl get kustomizations -n <ns>` ready and `nkpcluster … status.phase` = `Reconciled` `[pdf p.1044-1047]`.
- Do **not** assume rollback: "Do not assume that an error triggers automatic remediation or rollback" `[pdf p.1044]`.

---

## Relationships

- air-gapped bundle → local registry mirror: `nkp push bundle` is the only supported way to load NKP images offline; nodes then pull only through containerd mirrors `[pdf p.995-996]`.
- air-gapped bundle → NIB/KIBA: `nib/artifacts` is the `--artifacts-directory` that receives the OS package bundle; `konvoy-image-bundle` can be baked in with `--bundle` `[pdf p.61, 711-712]`.
- `nkp create package-bundle` → must run **outside** the air gap (vendor repos) → transferred in → `nkp upload image-artifacts` (pre-provisioned) or `nkp create image` (image providers) `[pdf p.60, 73, 711]`.
- local registry mirror **xor** internal registry mirror for one cluster: `--registry-mirror-*` vs `--bundle` `[pdf p.725]`.
- `--airgapped=true` → affects NKP UI/platform app behaviour, independent of which registry mode you chose `[pdf p.723]`.
- registry (any mode) ← required by: bootstrap cluster image load, `nkp create cluster`, `nkp install kommander`, `nkp upgrade kommander`, catalog app pulls, `nkp diagnose` node-collector images `[pdf p.93, 945, 1054]`.
- ChartMuseum ← only in air-gap; reduces to upstream Helm repos otherwise `[pdf p.1068]`.
- Pulse → `insights.nutanix.com`: dead in air-gap, nothing depends on it `[pdf p.54, 663]`.
- License token → platform app set (Pro/Ultimate add AI Navigator [not air-gap], Centralized Grafana) `[pdf p.29, 942]`.
- NKPCluster webhook → blocks Flux/kubectl edits of CAPI `Cluster.spec.topology` → forces GitOps migration before upgrade `[pdf p.1036, 1048]`.
- Flux chain: GitRepository → Kustomization (kustomize-controller) → HelmRelease (helm-controller) → HelmChart ← ChartMuseum (air-gap) `[pdf p.1057-1058, 1068-1070]`.
- AppDeployment → ClusterApp → Kustomization → HelmRelease `[pdf p.1059]`.
- Prism Central project ← NKP 2.19 requires one project per cluster (control plane + all node pools) `[pdf p.1015]`.
- Rook Ceph `dkp-object-store` ← Loki and NKP Insights object storage in air-gap `[pdf p.662, 1100, 1071]`.

---

## Troubleshooting (what to run, in order)

### Gather data for support

```bash
nkp diagnose                                   # support-bundle-<ts>.tar.gz
nkp diagnose --bootstrap-kubeconfig <kc>       # + bootstrap-support-bundle-<ts>.tar.gz (pre-pivot)
nkp diagnose default-config > bundle.yaml       # inspect/customize collectors
nkp diagnose bundle.yaml
nkp diagnose ssh <ansible-inventory.yaml>       # when the API server is down
```
Bundle dirs: `cluster-info/ cluster-resources/ configmaps/ node-diagnostics/ pod-logs/ secrets/ version.yaml` `[pdf p.1050]`.
Audit logs live in `support-bundle-*/node-diagnostics/<node>/data/kube_apiserver_audit.log` (Fluent Bit is off by default on the management cluster) `[pdf p.1003]`.
Node-collector images must exist in the air-gapped registry `[pdf p.1054]`.

### Discovery commands

| Goal | Command |
|---|---|
| CAPI/cluster health tree | `nkp describe cluster -c <cluster>` / `--kubeconfig <kc>` `[pdf p.1004]` |
| All CAPI objects | `kubectl get cluster-api` `[pdf p.1005]` |
| Clusters / classes / versions | `kubectl get nkpclusters -A`, `kubectl get clusters.cluster.x-k8s.io -A` `[pdf p.1024, 1046]` |
| Machines / MHC | `kubectl get machines -n <ns> -l cluster.x-k8s.io/cluster-name=<c>`, `kubectl get MachineHealthCheck` (default `maxUnhealthy: 40%`) `[pdf p.1029, 684]` |
| Node pools | `nkp get nodepools --cluster-name <c> -n <ns>` `[pdf p.1021]` |
| Git sources | `kubectl get gitrepository -A`, `kubectl logs -n kommander-flux deploy/source-controller --tail -1` `[pdf p.1057]` |
| App chain | `kubectl get apps,clusterapps,appdeployments -A`, `kubectl get kustomization -A`, `kubectl get helmrelease -A`, `kubectl get helmchart -A` `[pdf p.1057-1058]` |
| Flux controllers | `kubectl describe/logs -n kommander-flux deploy/{source,kustomize,helm}-controller` `[pdf p.1057-1058]` |
| App manager | `kubectl describe -n kommander deploy/kommander-appmanagement` `[pdf p.1057]` |
| Workspaces | `kubectl get workspaces`, `kubectl describe workspace <n>`, `kubectl logs -n kommander deploy/kommander-cm --all-containers --tail -1` `[pdf p.1058]` |
| Attached clusters | `kubectl get kommanderclusters -n <workspace-ns> -o yaml` `[pdf p.1058]` |
| AppDeployment detail | `nkp get appdeployments -w <ws>`, `nkp get appdeployment <name> -o yaml`, `nkp edit appdeployment <name> -n <ns>` `[pdf p.1061-1063]` |
| Node-level (air-gap safe) | `journalctl -u kubelet -f`, `journalctl -u containerd -f`, `cat /var/log/cloud-init-output.log`, `crictl ps -a` `[field: Troubleshooting NKP Deployment]` |

### Common failure playbooks

**HelmRelease stuck (`exhausted`, `another rollback/release in progress`)** — toggle suspend to force reconcile:
```bash
kubectl -n kommander patch helmrelease <HR> --type='json' -p='[{"op":"replace","path":"/spec/suspend","value":true}]'
kubectl -n kommander patch helmrelease <HR> --type='json' -p='[{"op":"replace","path":"/spec/suspend","value":false}]'
```
Workspace clusters: same with `-n ${WORKSPACE_NAMESPACE}` and `--kubeconfig <attached-kc>` `[pdf p.104, 1047]`.

**Upgrade failed / timed out** — re-run with verbosity: `nkp upgrade kommander -v 6` `[pdf p.1047]`. If HelmRelease reports the kommander-appmanagement chart "version not found", simply re-run the upgrade `[field: Troubleshooting NKP Deployment]`. Raise timeouts on large air-gapped installs: `--platform-apps-timeout 999m --request-timeout 999m --core-app-timeout 1h` `[field: NKP Upgrade Notes]`.

**Docker Hub credentials missing on upgrade** (non-air-gap only): `docker.io/nutanix credentials are missing for count cluster(s)…` → `nkp update cluster nutanix-registry-credentials --all-namespaces --nutanix-registry-username <u> --nutanix-registry-password <pat>` then retry `[pdf p.1017]`.

**Kommander install failures** — rerun the install command; it retries `[pdf p.102, 104]`. Watch `kubectl -n kommander wait --for condition=Ready helmreleases --all --timeout 15m` `[pdf p.104]`.

**Rook Ceph install error** (`failed to configure multisite for object store`, `signal: interrupt`):
```bash
kubectl describe CephObjectStores dkp-object-store -n <workspace-ns>     # look for ReconcileFailed
CEPH_TOOLS_POD=$(kubectl get pods -l app=rook-ceph-tools -n <ws> -o name)
kubectl exec -it -n <ws> $CEPH_TOOLS_POD bash
  radosgw-admin zonegroup default --rgw-zonegroup=dkp-object-store
  radosgw-admin period update --commit            # may take minutes
kubectl rollout restart deploy -n <ws> rook-ceph-operator
kubectl wait CephObjectStore --for=jsonpath='{.status.phase}'=Connected dkp-object-store -n <ws> --timeout 10m
```
`[pdf p.1071-1072]`

**Flux webhook rejection after Kommander upgrade**: `admission webhook "webhook.nkpcluster.child.kommander.mesosphere.io" denied the request: spec.topology: Forbidden: CAPI Cluster topology spec is managed by NKPCluster` → complete the GitOps migration (`Cluster` → `NKPCluster`) `[pdf p.1048]`.

**NKPCluster stuck Reconciling**: `kubectl get nkpcluster <c> -n <ns> -o yaml` + `kubectl get cluster … -o yaml` + `kubectl get machines -l cluster.x-k8s.io/cluster-name=<c>`; read `.status.conditions`; usual causes are missing credential secrets or image references absent on the infrastructure `[pdf p.1048]`.

**Cluster deleted during GitOps migration**: Flux pruning removed the `Cluster` because `prune: true` and the file was deleted from Git — disable pruning before the upgrade `[pdf p.1037, 1048]`.

**Force a machine rollout** (registry/mirror config or stuck rollout):
```bash
ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
kubectl patch kubeadmcontrolplane <cluster>-control-plane --type merge -p "{\"spec\":{\"rolloutAfter\":\"${ts}\"}}"
kubectl patch machinedeployment <name> -n <ns> --type merge -p "{\"spec\":{\"rolloutAfter\":\"${ts}\"}}"
kubectl annotate helmchartproxy <n> -n <ns> reconcile-trigger="$(date +%s)" --overwrite
kubectl annotate helmreleaseproxy <n> -n <ns> reconcile-trigger="$(date +%s)" --overwrite
```
`[field: Troubleshooting NKP Deployment]` `[field: Multiple Registry Configuration for Preprovisioned]`

**etcd recovery** (single-member rebuild):
```bash
ETCDCTL_API=3 etcdctl --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt --cert=/etc/kubernetes/pki/etcd/peer.crt \
  --key=/etc/kubernetes/pki/etcd/peer.key member list -w table
# then member remove <id>; or rebuild:
systemctl stop kubelet; cp -r /var/lib/etcd /var/lib/etcd.backup.$(date +%s)
# edit /etc/kubernetes/manifests/etcd.yaml: single-member --initial-cluster, --initial-cluster-state=new
systemctl start kubelet
```
`[field: etcd troubleshooting]`

**Preflight blocks on cluster create** (Nutanix): PC reachability, valid credentials, VM image present, **k8s version appears in the image name**, CSI storage containers exist, pod/service CIDRs valid and non-overlapping; for the local registry: reachable + valid credentials `[pdf p.726]`.

**Air-gap specific failure modes**
- Push fails with `UNAUTHORIZED: project not found, name: mesosphere` on Harbor → false positive for NKP >2.14.0, ignore `[pdf p.992]`.
- Registry reachable from bastion but not from nodes → cluster nodes cannot pull: verify mirror is reachable "from both the bastion machine and … the machines that will be created" `[pdf p.995]`.
- `nkp push bundle` fails on disk → `export TMPDIR=/path/to/your/directory` `[pdf p.694]`.
- Image name / version mismatch in `nkp create image`: version must be part of the image name; don't rename Portal-downloaded images `[pdf p.726, 1019]`.
- NTP not configured → certificate/time skew: `--ntp-servers` is mandatory air-gapped `[pdf p.724]`.
- LDAP/ACME/external identity unreachable → use built-in CA/self-signed, configure IDP that exists on-network `[pdf p.583, 103]`.
- Image builder temp SSH key/username lookup when debugging NIB: `docker exec -it <nkp-image-builder container> /bin/bash` then `packer console .` and read `local.ssh_private_key_file`, `var.ssh_username` (`.nkp-image-builder-*` dir is the build cwd) `[field: NKP Image Builder Find temp SSH Key and Username]`.
- Hardened air-gap host: a permission error on an unusable folder during `nkp upgrade` was worked around by temporarily `chmod 777` on that folder `[field: NKP Upgrade Notes]` (scrub: treat as last resort).
- Custom CIS Ubuntu image build: start `nkp create image nutanix … --debug`, and on the temp VM resize `/opt /tmp /var` LVM, set `umask 022`, `mount -o remount,exec /tmp` before continuing `[field: NKP CIS Ubuntu Custom Image]`.

### CAPI / platform object locations (what owns what)

| Object | Managed resource |
|---|---|
| `kommander-applications` repository | Deploys Flux (manifests) |
| Helm Repositories from that repo | `HelmRepository` objects (`common/helm-repositories`) |
| ChartMuseum | (air-gapped only) chart storage |
| Gatekeeper / kommander-appmanagement | HelmRelease applied directly, adopted by AppDeployment |
| Core AppDeployments | AppDeployments for Flux, kommander-appmanagement, ChartMuseum |
| `apps-kommander` bootstrap repository | `apps-kommander` Kustomization → apps into `kommander` ns |
| `kommander-ca` | `ClusterIssuer` + `Certificate` + self-signed `ClusterIssuer` |
| `kommander` (ingress cert) | self-attached KommanderCluster + ACME `ClusterIssuer`s |
| `kommander-vars` | Flux substitution variables ConfigMap + management GitRepository |
| Catalog Repository Loader | catalog `GitRepository` objects, propagated to workspaces/projects by `DefaultCatalogGitRepository` |

`[pdf p.1068-1070]`

---

## Version deltas

| Area | ≤2.16 | 2.17 / 2.18 | 2.19 |
|---|---|---|---|
| Air-gap bundle OS packages | Distro package bundles **included** in the air-gapped bundle (e.g. `nkp-air-gapped-bundle_v2.8.2_…`) `[pdf p.1013]` | Not included; must build with `nkp create package-bundle` `[pdf p.73]` | Same: bundle = NKP k8s packages + python packages + containerd tarball only `[pdf p.73, 92]` |
| Registry seeding | Mandatory step for every air-gapped cluster | **Optional from NKP 2.16 onwards** `[pdf p.996]` | Same |
| Internal registry mirror | — | Auto-deployed pull-through registry when no mirror/private registry is supplied `[pdf p.717]` | Same + `--bundle` create flag + `--to-internal-registry-mirror` `[pdf p.722-723, 946]` |
| Kommander air-gap upgrade flags | `--charts-bundle … --kommander-applications-repository … --disallow-charts-download` (2.13/2.16 field practice) `[field: NKP Upgrade Notes]` | `--kommander-applications-repository` still used in 2.16.1; dropped by 2.17 practice `[field: NKP Upgrade Notes]` | Not documented at all — images via `nkp push bundle` only `[pdf p.945, 1014]` |
| Host artifact upload | KIBA form: `konvoy-image upload artifacts --os-packages-bundle --containerd-bundle --pip-packages-bundle` `[repo: nkp-preprov/5.upload_package_bundle.sh]` | — | `nkp upload image-artifacts --artifacts-directory` `[pdf p.73-74]` |
| Upgrade model | per-workspace `nkp upgrade workspace` + `nkp upgrade cluster <provider>` | NKPCluster CRD + webhook introduced (2.18) `[pdf p.1035-1036]`; `nkp upgrade workspace` **deprecated**, use `nkp upgrade platform-apps` `[pdf p.1032]` | ClusterClass combined path `nkp upgrade cluster infrastructure-provider`; **Flux pruning must be disabled before 2.18** `[pdf p.1011, 1018]` |
| Management-cluster namespace | 2.17 and earlier: no `-n kommander` needed for nodepool commands | 2.18+: management cluster runs in `kommander`; always pass `-n kommander` `[pdf p.1030]` | Same |
| Prism Central projects | multi-project clusters supported `[pdf p.1015]` | 2.18 clusters may span projects | 2.19 requires **one** PC project per cluster; converge before upgrade |
| kubelet configuration | not configurable | CAREN-based kubelet config (2.18+) `[pdf p.993]` | Same |
| AI Navigator | — | installed by default when connected | never installed air-gapped `[pdf p.942]` |
| Kubernetes | — | — | CLI 1.36.x; ClusterClass `nkp-nutanix-v2.19.0`, k8s `v1.36.2` examples `[pdf p.1036]`; EKS k8s ≥1.34 `[pdf p.1011]` |

---

## Gaps / open questions

1. `nkp create bundle` — the task list names it; **no such command appears in the 2.19 PDF**. Only `nkp create package-bundle` and `nkp create catalog-bundle` are documented. Confirm against `nkp --help` on a real binary.
2. Exact **full file listing** of the 2.19 `nkp-<ver>/` directory — the PDF examples are `2.8.0-rc.2`-era and disagree between pages (p.770 shows `kib/`, p.997 shows `nib/`; neither lists `nkp-image-builder-*.tar`). Needs a real extracted bundle.
3. `--os-packages-bundle` / `--containerd-bundle` / `--pip-packages-bundle` are **not** documented for 2.19 (KIBA-era flags). Whether they still exist behind `nkp upload image-artifacts` is UNKNOWN — verify with `--help`.
4. NIB `--override` (offline image build) is mentioned only in one sentence on p.1012 and is not documented as a flag surface. UNKNOWN semantics.
5. Air-gapped **licence activation** is never stated explicitly; inferred from the `kubectl` secret + `License` CR path which needs no internet. The UI path's offline behaviour (does it call home?) is UNKNOWN.
6. `nkp diagnose` node-collector image tag scheme (`nkp-diagnostics-node-collector:<nkp-diagnose version>`) — the exact tag for 2.19 and whether it is inside `konvoy-image-bundle` is UNKNOWN.
7. NKP Insights air-gapped: whether the Insights images are in `kommander-image-bundle` **or** only in `nkp-insights-image-bundle` differs across pages (p.770 lists a separate insights bundle; the four-tar push on p.945 omits it). UNKNOWN which is authoritative for 2.19.
8. Upgrade matrix (p.1011-1012) suggests 2.17.x → 2.19.0 directly, but the "sequential minor versions" rule (p.1011) says never skip a minor. The 2.17→2.19 cell being `Yes` looks like a doc inconsistency — flag for the skills.
9. Air-gapped **Kommander custom certificate / custom domain** details in air-gap (no ACME) are only partially covered; the full procedure lives in "Kommander Customizations" (p.957+, not read here) — needs a second pass.
10. `nkp upgrade kommander` flag set for 2.19 air-gap (`--platform-apps-timeout`, `--request-timeout`, `--core-app-timeout`, `--disable-appdeployments`) is attested only by field notes `[field: NKP Upgrade Notes]`, not by the PDF.
11. Trivy DB refresh in air-gap requires building `mesosphere/trivy-bundles` **with internet** — no NKP-native offline update path documented.
