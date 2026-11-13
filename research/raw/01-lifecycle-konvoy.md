# 01 — NKP overview, licensing, CLI, and cluster lifecycle (Konvoy)

Scope: what NKP is, its three editions, the `nkp` CLI, the bootstrap/self-managed/pivot model,
Cluster API + ClusterClass + CAREN, all infrastructure providers (CAPX, CAPV, CAPA, CAPZ, CAPG,
EKS/AKS, pre-provisioned, Metal), node OS/containerd/kube-vip/etcd, upgrades, autoscaling,
AI Navigator, NKP MCP Server, NKP Insights, Pulse.

Sources: `[pdf p.N]` = `research/raw/pdf/2.19/*.txt`; `[web: url]`.

---

## Components

### NKP (the platform)
- **What**: Commercial Kubernetes platform = Konvoy (cluster lifecycle) + Kommander (fleet/app management) + NIB (image builder), plus curated platform applications. [pdf p.20]
- **Upstream**: mostly CNCF/upstream projects (Cluster API, Cilium/Calico, Flux, Helm, cert-manager, MetalLB, kube-vip, Prometheus, Velero). Nutanix-specific parts are CAPX/CAREN/NIB/konnector.
- **NKP role / name**: product. Versions `2.16 … 2.19`. NKP is the successor of D2iQ DKP; Nutanix acquired the D2iQ Kubernetes Platform in early 2024 and shipped it as NKP from **2.12**. Previous Nutanix K8s product was NKE. [web: nutanix.com/d2iq, nutanix.com blog "NKP to Remove Cloud Native Complexity", nutanixbible NKP]
- **Runs on**: bootstrap (kind) + management cluster + workload clusters + node OS.
- **Deployed by**: `nkp` CLI, NKP UI, Prism Central Marketplace app, or Flux GitOps.
- **Default**: n/a.
- **Version in 2.19**: Kubernetes **1.36.2 default**, 1.35.x also supported; PC `pc.7.5`/`pc.7.6`; AOS 7.5/7.6; NDK 2.3; NAI 2.8.0/2.8.1. [web: next.nutanix.com NKP 2.19 release post] PDF corroborates K8s version by image naming (`...-v1.36.2_linux_amd64.tar`, `kubectl 1.36.x`). [pdf p.50][pdf p.715]
- **Depends on / talks to**: Prism Central API (9440) for AHV; cloud APIs for AWS/Azure/GCP/vSphere; a container registry; Foundation Central for Metal.
- **Air-gap notes**: fully supported on all tiers (`Air-Gapped Deployments` X for Starter/Pro/Ultimate). [pdf p.28] Requires a local registry mirror **or** the NKP internal registry mirror. [pdf p.24–25]
- **Key CRDs / namespaces / CLI**: `NKPCluster` (`clusters.nkp.nutanix.com/v1alpha1`), namespaces `kommander`, `kommander-flux`, `capi-system`, `caren-system`. [pdf p.762][pdf p.671]
- **Sources**: as above.

### Licensing (Starter / Pro / Ultimate)
- **What**: License token applied per cluster; features gate on tier. Licenses are sold **by core** and apply to the vCPUs of all worker nodes (on-prem, public cloud, edge). Cannot downgrade after registering. [pdf p.26]
- **NKP role / name**: `License` CRD `kommander.mesosphere.io/v1beta1`, namespace `kommander`, referencing a Secret key `nutanix-license-key`. UI path: Global → Settings → Licensing. [pdf p.31]
- **Default**: NKP auto-assigns a default key — **Starter** for AHV, **Pro** for all other infra. Applying Pro/Ultimate installs the additional default apps (e.g. AI Navigator for Pro/Ultimate; Centralized Grafana only for Ultimate). [pdf p.28–29]
- **Tier facts (2.19)**: [pdf p.26–28]
  - Starter: Nutanix AHV only, single infrastructure provider, Rocky Linux image only (Ubuntu image needs Pro/Ultimate).
  - Pro: one infrastructure provider, multi-cluster (management + managed/attached of same provider).
  - Ultimate: multiple infrastructure providers, attaching external clusters, EKS/AKS LCM, multi-cloud/hybrid.
  - Starter-only rows: `NKP on Nutanix AHV` all three; `NKP on AWS/Azure/GCP/vSphere`, `Pre-provisioned`, `EKS Provisioning`, `Multi-Cloud Hybrid`, `Attaching Workload Cluster`, `LCM of EKS Cluster`, `LCM of AKS Cluster`, `GitOps Continuous Deployment (FluxCD)`, `Project Level Platform Applications`, `Catalog Applications`, `Multi-tenant Logging`, `Multi-tenant` extras → Pro/Ultimate or Ultimate-only. Read literally from the matrix: single-X rows = **Ultimate**.
  - Also tiered: FIPS build, NIB/BYO OS, Ubuntu image, SSO, Gatekeeper, Velero, GPU (NVIDIA/AMD), Insights, AI Navigator, NKP MCP Server.
  - Nuance: the matrix shows `Insights` with a single X (Ultimate) but the Insights chapter says the engine also runs on the Pro single-cluster management cluster. Treat as **Pro-or-Ultimate, verify with Nutanix**. [pdf p.1086]
- **Full Stack (NKPFS) license**: for Prism Central clusters (CAPX/CAPV). Generate a CSF from the PC that hosts the management cluster, upload to the Nutanix Support portal, then apply the key in NKP UI. Requires NKP ≥ 2.13.1, AOS 6.10.1 / 7.0+, PC 2024.3+. [pdf p.32–34]
- **AWS Marketplace purchases**: `AWSLicenseManagerConsumptionPolicy` must be attached to `control-plane.cluster-api-provider-aws.sigs.k8s.io` else license verification fails; gets a license token + container image that extracts the `nkp` binary. [pdf p.29–30]
- **Air-gap notes**: license activation works offline (UI or `kubectl` secret), no egress needed. Pulse and AI Navigator need internet; both are optional. [pdf p.663][pdf p.1073]

### Konvoy (cluster lifecycle component)
- **What**: The NKP cluster lifecycle manager. Provisions certified Kubernetes clusters on cloud/vSphere/on-prem in connected and air-gapped environments, using Cluster API + open-source + proprietary software. [pdf p.20]
- **Upstream**: Kubernetes Cluster API (`cluster-api.sigs.k8s.io`) + providers.
- **NKP role / name**: "Konvoy" subcommand family in the `nkp` binary (`nkp version` shows `konvoy: v<ver>`). Konvoy "Cluster Manager" contains: Cluster API, CSI, CNI, Cluster Autoscaler, cert-manager, load balancers. [pdf p.20][pdf p.1013]
- **Runs on**: bootstrap cluster + management cluster.
- **Deployed by**: `nkp create cluster <provider>` (which also creates the bootstrap cluster, CAPI components, and pivots). [pdf p.666]
- **Default**: always present.
- **Depends on / talks to**: Docker/Podman on the operator machine (kind bootstrap), kubectl, registry, infra API.
- **Key CLI**: `nkp create bootstrap`, `nkp create cluster <infra>`, `nkp create capi-components`, `nkp move capi-resources`, `nkp delete bootstrap`, `nkp get kubeconfig`, `nkp describe cluster`, `nkp upgrade cluster`, `nkp update controlplane`, `nkp update nodepool`, `nkp scale nodepool`. [pdf p.22–23]
- **Operator host requirements**: x86_64 Linux/macOS (cgroups v2 on Linux), **Docker 27.4.0** or **Podman ≥4.0**, `kubectl 1.36.x`. [pdf p.48–50]

### Kommander (fleet management component)
- **What**: Fleet management: centralized observability, governance, policy, app lifecycle via Flux. Manages attached and managed clusters (Ultimate attaches external clusters). [pdf p.20]
- **NKP role / name**: installed with `nkp install kommander` (`--init` generates `kommander.yaml`, `--installer-config` applies it). On Nutanix AHV via CLI/marketplace, the NKP UI (Kommander) is installed automatically. [pdf p.46][pdf p.941]
- **Runs on**: management cluster.
- **Deployed by**: `nkp install kommander` → installs `git-operator` (StatefulSet `git-operator-git` in `git-operator-system`) → Flux → HelmReleases. [pdf p.671][pdf p.637]
- **Default**: enabled with every edition (Ultimate gates attaching + catalog apps).
- **Key CLI**: `nkp install kommander`, `nkp upgrade kommander`, `nkp get dashboard`, `nkp rotate dashboard-credentials`, `nkp open dashboard`. [pdf p.1017]

### Nutanix Image Builder (NIB)
- **What**: Builds Cluster API-compliant machine images containing everything needed for NKP nodes; also creates OS package bundles for air-gap and uploads artifacts to pre-provisioned hosts. [pdf p.20][pdf p.55]
- **NKP role / name**: shipped inside the air-gapped bundle as `nib/` (ansible, konvoy-image, overrides, goss) and as a container image loaded with `docker load`. [pdf p.73–74][pdf p.58]
- **Runs on**: operator/bastion host (not in the cluster).
- **Deployed by**: `nkp create image <provider> <os>`, `nkp create package-bundle <os>`, `nkp upload image-artifacts`. [pdf p.58][pdf p.60][pdf p.1013]
- **Default**: required for non-AHV infra; for AHV you may use Nutanix prebuilt images instead.
- **Prebuilt Nutanix images**: Rocky Linux 9.8 and Ubuntu 24.04 LTS, CIS Level 1 at OS layer (NKP/K8s components follow CIS L2). Prebuilt = CIS-hardened but **no FIPS**; custom = FIPS-capable (RHEL 8.10/9.6), GPU drivers pre-installable. [pdf p.55–56]
- **Air-gap notes**: build needs the OS package bundle created in a connected env, then `--override` file; proxy is used only during build, never baked in. [pdf p.59][pdf p.670]
- **Sources**: above.

### `nkp` CLI
- **What**: Single Go binary; the only supported entry point for cluster lifecycle. `nkp version` prints per-component versions (`catalog`, `diagnose`, `imagebuilder`, `kommander`, `konvoy`, `konvoybundlepusher`, `mindthegap`, `nkp`). [pdf p.1013]
- **Command inventory seen in the 2.19 doc set**: `create {bootstrap, cluster <infra>, capi-components, nodepool, image, package-bundle, bootstrap-token, metadata, appdeployment, catalog-*}`, `move capi-resources`, `delete {bootstrap, cluster, nodepool}`, `get {kubeconfig, dashboard, clusters, nodepools, workspaces, appdeployments}`, `describe cluster`, `check cluster`, `update {controlplane, nodepool, cluster nutanix-registry-credentials, bootstrap}`, `upgrade {kommander, capi-components, cluster, addons, platform-apps, catalogapp}`, `scale nodepool`, `install kommander`, `attach cluster`, `push bundle`, `diagnose`, `diagnose default-config`, `rotate dashboard-credentials`, `open dashboard`, `edit appdeployment`, `generate catalog-repository`, `validate catalog-repository`. [grep over pdf 2.19]
- **Deprecated / removed in 2.19**: `nkp upgrade workspace` deprecated; `--kommander-applications-repository` flag removed. [pdf p.1032][web: next.nutanix.com NKP 2.19]
- **Air-gap notes**: the CLI itself ships inside `nkp-air-gapped-bundle_<ver>_linux_amd64.tar.gz`; `nkp push bundle` supports `--to-registry` and `--to-internal-registry-mirror`; needs `TMPDIR` with free space. [pdf p.714][pdf p.1015][pdf p.694]

### Bootstrap cluster (kind)
- **What**: Ephemeral Kubernetes-in-Docker cluster that holds CAPI resources while the real cluster is created; generates certs, initializes the control plane, joins nodes, installs CNI/CSI/autoscaler. [pdf p.23]
- **Upstream**: kind (kubernetes-sigs/kind). NKP wraps it with `konvoy-bootstrap-image-<ver>.tar`.
- **Runs on**: operator machine (Docker/Podman).
- **Deployed by**: `nkp create bootstrap` (implicit in `nkp create cluster`).
- **Default**: enabled.
- **Key CLI**: `nkp create bootstrap [--http-proxy/--https-proxy/--no-proxy] [--kubeconfig]`; `nkp update bootstrap`; `nkp delete bootstrap`. [pdf p.666–667]
- **Air-gap notes**: `docker load --input nkp-<ver>/konvoy-bootstrap-image-<ver>.tar` before creating. [pdf p.718]
- **Notes**: must run in the same network/proxy domain as the target cluster. Needs ≥4 CPU/4 GB free to build a management cluster. [pdf p.666][pdf p.718]

### Cluster API core (CAPI)
- **What**: Declarative cluster lifecycle (`Cluster`, `Machine`, `MachineDeployment`, `MachineSet`, `MachineHealthCheck`), plus `ClusterResourceSet` for core add-ons. [pdf p.23–24]
- **Upstream**: https://github.com/kubernetes-sigs/cluster-api , book: https://cluster-api.sigs.k8s.io
- **NKP role / name**: installed by `nkp create capi-components` (+ cert-manager) and by `nkp upgrade capi-components`. Namespaces `capi-system`, `capi-kubeadm-bootstrap-system`, `capi-kubeadm-control-plane-system`. [pdf p.671]
- **Runs on**: bootstrap cluster, then pivoted to the management cluster (self-managed).
- **Deployed by**: `nkp create capi-components` / implicitly by `nkp create cluster --self-managed`.
- **Default**: enabled.
- **Key CRDs**: `clusters.cluster.x-k8s.io`, `machines`, `machinedeployments`, `machinehealthchecks`, `clusterresourcesets.addons.cluster.x-k8s.io`.
- **Default MHC `maxUnhealthy`: 40%**; `nodeStartupTimeout: 10m`. [pdf p.24][pdf p.685]
- **Facts**: Machine immutability — changing a machine spec replaces the machine. Node pools are MachineDeployments and roll like a Deployment. [pdf p.24]

### kubeadm bootstrap / control plane providers (CABPK / KCP)
- **What**: `KubeadmConfig`/`KubeadmConfigTemplate` render cloud-init for nodes; `KubeadmControlPlane` (KCP) owns control-plane machines, rolling updates, cert renewal, etcd membership. [pdf p.997–1001]
- **NKP role / name**: `KubeadmControlPlane` is the object users patch for control-plane customization (audit policy, etcd image tag, kube-proxy config, containerd metrics). [pdf p.997]
- **Deployed by**: CAPI.
- **Key facts**: KCP `rolloutStrategy.rollingUpdate.maxSurge: 1`; kube-proxy config injected via `preKubeadmCommands` script because CAPI has no KubeProxyConfiguration API; containerd metrics scraped on `0.0.0.0:1338` via `/etc/containerd/conf.d/konvoy-metrics.toml`. [pdf p.1000–1001]
- **Air-gap notes**: `--kubernetes-image-repository` and `+fips.0` tags are rendered into the kubeadm config. [pdf p.682]

### cert-manager (CAPI dependency)
- **What**: Issues the webhook/CA certificates CAPI and providers need.
- **NKP role / name**: created together with CAPI components; absence is why a non-`--self-managed` cluster has no CAPI controllers/cert-manager. [pdf p.667]
- **Runs on**: bootstrap, then management cluster.
- **Deployed by**: `nkp create capi-components`.
- **Default**: enabled. Attaching a cluster that already has cert-manager makes the NKP cert-manager HelmRelease fail — documented as ignorable. [pdf p.428]
- **Note**: separate from the *control-plane* certificate feature (KCP certs are auto-renewed 180 days before expiry by default — see upgrade section). [pdf p.686]

### CAREN — Cluster API Runtime Extensions Nutanix
- **What**: CAPI Runtime SDK extension providing discovery+patch hooks and lifecycle-hook addon installers for ClusterClass-managed clusters. Everything a user needs is expressed as variables on one `Cluster` resource. [web: nutanix-cloud-native.github.io/cluster-api-runtime-extensions-nutanix]
- **Upstream**: https://github.com/nutanix-cloud-native/cluster-api-runtime-extensions-nutanix (group `caren.nutanix.com`).
- **NKP role / name**: part of the "Cluster API (CAPI) components" installed/upgraded by `nkp`; Deployment `cluster-api-runtime-extensions-nutanix` in namespace **`caren-system`**. [pdf p.671]
- **Runs on**: bootstrap cluster, then management cluster (it patches `Cluster` topology and installs addons into workload clusters).
- **Deployed by**: `nkp create capi-components` / `nkp upgrade capi-components`; upstream Helm chart or `clusterctl` with `--runtime-extension caren:vX`.
- **Supported providers** (external patch names): Nutanix (`nutanixclusterconfigvars` / `nutanixclusterv7configpatch`, plus `nutanixworkerconfigvars`), AWS (self-managed), EKS (worker config), Docker (tests), Generic (provider-independent). [web: .../getting-started/integrating-with-your-clusterclass/]
- **Two variables**: `clusterConfig` (cluster-wide) and `workerConfig` (per MachineDeployment, under `topology.workers.machineDeployments[].variables.overrides`). [pdf p.418][pdf p.995]
- **Addons it installs** (from `clusterConfig.addons`):
  - `cni` — providers **Calico**, **Cilium**, **Flow** (Nutanix-only); strategies `HelmAddon` (via Cluster API Add-on Provider for Helm) or `ClusterResourceSet`. [web: .../addons/cni/]
  - `csi` — providers `nutanix`, `aws-ebs`, `local-path`. [web: pkg.go.dev constants]
  - `cosi` (container object storage interface).
  - `serviceLoadBalancer` — **MetalLB** with IPv4 `addressRanges`. [web: .../addons/serviceloadbalancer/]
  - `ingress` — `aws-lb-controller` provider. [web: pkg.go.dev constants]
  - `nfd` (Node Feature Discovery; namespace `node-feature-discovery` labeled `pod-security.kubernetes.io/enforce=privileged`). [web: .../addons/nfd/]
  - `konnectorAgent` — Prism Central registration agent (Nutanix only). [pdf p.507–509]
  - Virtual IP provider **KubeVIP** (`VirtualIPProviderKubeVIP`). [web: pkg.go.dev constants]
  - Registry mirror provider `CNCF Distribution`. [web: pkg.go.dev constants]
  - Standard k8s addon pieces NKP also ships via ClusterResourceSet: **Cluster Autoscaler**, NFD, NVIDIA feature discovery. [pdf p.1027]
- **Generic (non-addon) customizations** exposed through `clusterConfig`/`workerConfig`: `kubernetesImageRepository`, `etcd.image`, `extraAPIServerCertSANs`, `proxy` (http/https/additionalNo), `imageRegistries.credentials`, `ntp`, `users`, node tainting, audit policy, **auto-renewal of control-plane certs**, containerd metrics, DNS (`CoreDNS`), **encryption at rest**, `kubeProxy` mode, **kubeletConfiguration**, node registration, parallel image pulls, Pod Security Admission. [web: .../customization/][pdf p.993–994]
- **Nutanix-specific**: `controlPlaneEndpoint`, `machineDetails`, `prismCentralEndpoint`, `failureDomains`, `project`. [web: .../customization/ Nutanix section][pdf p.417–419]
- **Air-gap notes**: image registry mirror + credentials are CAREN variables; the Caren Deployment itself takes HTTP(S)/NO_PROXY env (`kubectl set env deployment/cluster-api-runtime-extensions-nutanix -n caren-system`). [pdf p.671]
- **Key CLI/CRD**: `ExtenstionConfig` objects, `preflight.cluster.caren.nutanix.com/skip` annotation for per-cluster preflight skip. [web: pkg.go.dev v1alpha1]

### ClusterClass + topology + NKPCluster CRD
- **What**: ClusterClass is a CAPI template set; a `Cluster` with `spec.topology` (class, version, controlPlane, workers, variables) is the single object you mutate to create/upgrade. NKP wraps it in `NKPCluster` (`clusters.nkp.nutanix.com/v1alpha1`) which owns the underlying CAPI `Cluster` in `spec.capiCluster` and reports `status.capiClusterRef`. [pdf p.762][pdf p.1015][pdf p.1020]
- **NKP role / name**: ClusterClass names are versioned per release: e.g. `nkp-nutanix-v2.19.0`, older `nkp-nutanix-2-18-...`; examples also show `nutanix-quick-start`. Worker MachineDeployment classes: `default-worker` and (Metal) `host-agent-worker`. [pdf p.1035][pdf p.508][pdf p.418][pdf p.762]
- **Runs on**: management cluster (definitions), reconciled into workload clusters.
- **Deployed by**: CAPI components (`nkp upgrade kommander` "now includes the CAPI components and ClusterClass resources"). [pdf p.1017]
- **Default**: enabled for Nutanix AHV, Metal and EKS in 2.19; AWS/Azure/GCP/vSphere/pre-provisioned remain **non-ClusterClass** in 2.19 [pdf p.1016, p.1025].
- **Important behaviour**: an admission webhook **denies direct edits to the CAPI `Cluster`** ("spec.topology: Forbidden: CAPI Cluster topology spec is managed by NKPCluster"); edit `NKPCluster` instead. GitOps repos must switch from `Cluster` to `NKPCluster`. [pdf p.1048][pdf p.1041]
- **Upgrade concurrency**: annotation `topology.cluster.x-k8s.io/upgrade-concurrency: "3"` upgrades up to 3 worker node pools in parallel; absent → one at a time. [pdf p.1018, p.1020]
- **Ranking / rollout**: "the NKPCluster controller rolls the control plane nodes first, then rolls the worker nodes after the control plane is healthy." [pdf p.1047]

### CAPX — Cluster API Provider Nutanix (AHV)
- **What**: CAPI infrastructure provider for Nutanix Cloud Infrastructure (AHV/Prism Element, Prism Central API).
- **Upstream**: https://github.com/nutanix-cloud-native/cluster-api-provider-nutanix ; docs https://opendocs.nutanix.com/capx/v1.10.x/ . v1.10.x requires PC 7.5+/AOS 7.5+. [web: github CAPX README]
- **NKP role / name**: default provider for `nkp create cluster nutanix`; Deployment `capx-controller-manager` in `capx-system`. [pdf p.671]
- **Runs on**: management cluster (and bootstrap during creation).
- **Default**: enabled; Nutanix CSI is the default StorageClass on AHV. [pdf p.49]
- **Key CRDs**: `NutanixCluster`, `NutanixMachine(Template)`, `NutanixFailureDomain` (`infrastructure.cluster.x-k8s.io/v1beta1`). [pdf p.405–419]
- **Key flags**: `--endpoint`, `--control-plane-prism-element-cluster`, `--control-plane-subnets`, `--control-plane-endpoint-ip`, `--control-plane-vm-image`, `--worker-*`, `--csi-storage-container`, `--kubernetes-service-load-balancer-ip-range`, `--vm-profile`, `--fips`, `--onboard-to-prism-central=false`. [pdf p.724–725]
- **Air-gap notes**: `--bundle` (internal mirror) **xor** `--registry-mirror-url/...` **xor** `--registry-url/...`; `--airgapped=true`. [pdf p.722–725]
- **2.19 gotcha**: control plane and **all** node pools must use one Prism Central project (`_internal` or one user project); `nkp update nodepool` cannot change a pool's project. [pdf p.1015–1016]

### CAPV — Cluster API Provider vSphere
- **What**: CAPI provider for vSphere (`VSphereCluster`, `VSphereMachineTemplate`).
- **Upstream**: https://github.com/kubernetes-sigs/cluster-api-provider-vsphere
- **NKP role / name**: `nkp create cluster vsphere`; `capv-controller-manager` in `capv-system`. Non-ClusterClass in 2.19. [pdf p.671][pdf p.1016]
- **Default**: Pro/Ultimate only. [pdf p.28]
- **Key flags**: `--vm-template`, `--kubernetes-version`, `--control-plane-*`, `--worker-*`. [pdf p.1029]
- **Air-gap notes**: vSphere template built by NIB, loaded into the registry; `--vm-template` must match K8s version. [pdf p.841]

### CAPA — Cluster API Provider AWS (self-managed AWS)
- **What**: CAPI provider for AWS EC2 (`AWSCluster`, `AWSMachineTemplate`), and the base for EKS managed control planes.
- **Upstream**: https://github.com/kubernetes-sigs/cluster-api-provider-aws
- **NKP role / name**: `nkp create cluster aws`; `capa-controller-manager` in `capa-system`; IAM role `control-plane.cluster-api-provider-aws.sigs.k8s.io`. [pdf p.671][pdf p.29]
- **Default**: Pro/Ultimate.
- **Key flags**: `--ami`, `--ami-owner`, `--ami-base-os`, `--ami-format`, `--instance-type`, `--region`. [pdf p.1028]
- **Air-gap notes**: PDF explicitly prefers a **bundle image** over upstream CAPA project AMIs for production; you must specify an AMI. [pdf p.1012]

### EKS provider (CAPA managed control plane)
- **What**: EKS clusters created/managed through CAPI using `AWSManagedControlPlane`; NKP gives full LCM (create, upgrade, delete) of EKS clusters. [pdf p.843][pdf p.794]
- **NKP role / name**: "EKS Provisioning" (Ultimate), `nkp create cluster eks` / UI; CAREN has an **EKS** provider for worker config. [pdf p.28][web: CAREN README]
- **Default**: Ultimate only; **Kubernetes ≥1.34**; lifecycle ops only for **ClusterClass-based** EKS clusters (non-ClusterClass EKS unsupported → migrate, KB-21858). [pdf p.1011]
- **Air-gap notes**: EKS itself needs AWS; air-gapped EKS clusters are attach-only (no egress path for image pulls unless mirrored).
- **Key facts**: IAM authenticator config lives on `AWSManagedControlPlane`; node pools via `nkp create/scale/delete nodepool`; delete via CLI or UI. [pdf p.774][pdf p.867–869]

### AKS provider (CAPZ managed control plane)
- **What**: AKS clusters via `AzureManagedControlPlane`; NKP creates, explores, deletes AKS clusters. [pdf p.150][pdf p.901]
- **Upstream**: https://github.com/kubernetes-sigs/cluster-api-provider-azure
- **NKP role / name**: "LCM of AKS Cluster" (Ultimate); `nkp create cluster aks`; `capz-controller-manager` in `capz-system`. [pdf p.28][pdf p.671]
- **Key flags**: `--compute-gallery-id`, `--plan-offer/--plan-publisher/--plan-sku`. [pdf p.1029]
- **Default**: Ultimate only.

### CAPZ — Azure (self-managed)
- **What**: CAPI provider for Azure IaaS (`AzureCluster`, `AzureMachineTemplate`).
- **NKP role / name**: `nkp create cluster azure`; Pro/Ultimate. Default VM shape `Standard_D4s_v3`, 128 GiB OS + 80 GiB etcd volume. [pdf p.697]
- **Air-gap notes**: images from NIB are published as an Azure Compute Gallery; pass `--compute-gallery-id`. [pdf p.1029]

### CAPG — Cluster API Provider GCP
- **What**: CAPI provider for GCP (`GCPCluster`, `GCPMachineTemplate`).
- **NKP role / name**: `nkp create cluster gcp`; `capg-controller-manager` in `capg-system`; Pro/Ultimate. [pdf p.671]
- **Key flags**: `--image=projects/<proj>/global/images/<img>`, `--kubernetes-version`. [pdf p.1029]

### CAPPP — Cluster API Provider Pre-Provisioned (`preprovisioned`)
- **What**: CAPI infrastructure provider that installs Kubernetes onto **already provisioned** machines over **SSH** (bare metal, AHV, or cloud). No VM creation.
- **NKP role / name**: `nkp create cluster preprovisioned`; `cappp-controller-manager` in **`cappp-system`**. [pdf p.671]
- **Runs on**: management cluster.
- **Deployed by**: CAPI components.
- **Default**: Pro/Ultimate. [pdf p.28]
- **Key CRDs**: `PreprovisionedInventory` — docs show `apiVersion: infrastructure.cluster.konvoy.d2iq.io/v1alpha1` while the apply output shows `infrastructure.cluster.konvoy.nutanix.io` (doc inconsistency; group is the Konvoy pre-provisioned group, not `cluster.x-k8s.io`). [pdf p.768–769]
- **Key flags**: `--pre-provisioned-inventory-file`, `--ssh-private-key-file`, `--control-plane-endpoint-host`, `--virtual-ip-interface`. [pdf p.598–601][pdf p.787]
- **Default storage**: `localvolumeprovisioner` — explicitly **not production suitable**. [pdf p.766]
- **Machine requirements**: CP ≥3 nodes, 4 cores/16 GB/80 GB free, firewalld disabled, swap off; workers ≥4 nodes 8 cores/32 GiB, ≥4 volumes of ≥55 GB at `/mnt/disks` if using local PV. [pdf p.767]
- **Air-gap notes**: requires artifacts uploaded to hosts (`nkp upload image-artifacts`) and a local registry; NIC must be specified for Flatcar/IPv6 edge cases. [pdf p.1014][pdf p.683]

### NKP Metal (bare-metal provider)
- **What**: 2.19 feature. NKP manages physical servers as first-class cluster nodes. Two models: **full bare-metal workload cluster** (CP + workers on metal) and **mixed workload cluster** (CP/standard workers as AHV VMs, extra worker pool on metal). [pdf p.741]
- **NKP role / name**: infrastructure type "Nutanix Metal"; `nkp create cluster metal`, `nkp create nodepool metal`; CRD `NKPCluster` with MachineDeployment class **`host-agent-worker`**; machine templates **`HostAgentMachineTemplate`** and **`NutanixBareMetalMachineTemplate`**. [pdf p.756][pdf p.758][pdf p.762]
- **Runs on**: management cluster + physical hosts (node OS image).
- **Deployed by**: Foundation Central images hosts → host agent self-registers with the management cluster using a **bootstrap token** → hosts appear in **Metal Host Inventory**. [pdf p.745–747]
- **Default**: Pro/Ultimate only; management cluster must be Pro or Ultimate. [pdf p.744]
- **Host OS**: **Ubuntu 24.04 LTS only**, Nutanix-supplied ISO + metadata JSON, **no FIPS**, no customer images, IPv4 only. [pdf p.743, p.745]
- **Key CLI**: `nkp create bootstrap-token`, `nkp create cluster metal --control-plane-host-selector/--worker-host-selector --csi-prism-central-endpoint --csi-storage-container --csi-prism-element-cluster`, `nkp create nodepool metal <name> --hosts|--host-selector`, `nkp scale nodepool`, `kubectl get hosts|assignedhosts -n <ws>`. [pdf p.746–761]
- **Node pools**: hosts selected **Individually** (names/UUIDs — you must edit `NKPCluster` when scaling) or **By Labels** (NKP picks a free host automatically). Labels/taint keys must use `*.nutanix.com/` prefix. [pdf p.762–764]
- **Storage**: hypervisor-attached volumes unavailable; CSI Volumes go straight to Prism Element; a dedicated `nutanix-volume-metal` StorageClass is needed for the metal pool of a mixed cluster. [pdf p.750][pdf p.755]
- **Air-gap notes**: host OS ISO + container images staged in the local/internal mirror before imaging. [pdf p.743]
- **UNKNOWN**: exact CRD group/version of the Metal infrastructure types and the host-agent component name (not stated in the 2.19 guide).

### Cluster API Add-on Provider for Helm (CAAPH)
- **What**: Lets CAPI install Helm charts into a cluster via `HelmChartProxy` (`hcp`) objects. [pdf p.741]
- **Upstream**: https://github.com/kubernetes-sigs/cluster-api-addon-provider-helm
- **NKP role / name**: `caaph-controller-manager` in **`caaph-system`**; the `HelmAddon` strategy of CAREN addons (CNI/CSI/MetalLB) uses it. [pdf p.671][web: CAREN CNI doc]
- **Default**: enabled where CAREN addons use `strategy: HelmAddon`.

### ClusterResourceSet (CAPI add-ons)
- **What**: CAPI CRD grouping ConfigMaps to install core add-ons after cluster creation.
- **NKP role / name**: used for **CSI, CNI, Cluster Autoscaler, Node Feature Discovery, NVIDIA feature discovery**; per-cluster names suffixed with cluster name (e.g. `calico-cni-installation-my-aws-cluster`). Non-ClusterClass upgrades migrate global CRSes to cluster-specific ones; **customizations to CRS definitions are not preserved**. [pdf p.1026–1027]

### Cluster Autoscaler
- **What**: Scales worker MachineDeployments on pending pods.
- **NKP role / name**: shipped core addon (`cluster-autoscaler` Deployment in `kube-system` for non-ClusterClass clusters; CAREN addon otherwise). Enabled per node pool by annotations `cluster.x-k8s.io/cluster-api-autoscaler-node-group-min-size` / `-max-size`. [pdf p.935–936][pdf p.762]
- **Default**: optional; UI has a "Worker Node Autoscaling" toggle with min/max. [pdf p.759]
- **Note**: scale-down default delay 10 minutes. [pdf p.937]

### kube-vip (control-plane virtual IP)
- **What**: Virtual IP for the Kubernetes API endpoint when no external load balancer exists.
- **NKP role / name**: "built-in virtual IP" for pre-provisioned clusters; also used by AWS/Flatcar deployments for the first control-plane VIP. Flags `--virtual-ip-interface`, `--control-plane-endpoint`. [pdf p.786–787][pdf p.683]
- **Default**: optional (external LB recommended).
- **Air-gap notes**: none.
- **Caveat**: not a load balancer — it moves the VIP, it does not spread requests. [pdf p.786]

### etcd
- **What**: Kubernetes key-value store; runs as static pods on control-plane nodes under KCP.
- **NKP role / name**: version pinned by NKP; FIPS builds use `--etcd-version=<ver>+fips.0`; per-cluster etcd image override via `clusterConfig.etcd.image.repository/tag`. [pdf p.682][web: CAREN customization]
- **Version in 2.19**: **UNKNOWN** (PDF defers to release notes "Supported Components"; a legacy example shows `imageTag: 3.5.7`). 2.19 fixed "etcd learner promotion failures that prevented new clusters from becoming ready". [pdf p.998][web: NKP 2.19 post]

### Node OS + containerd
- **What**: Node operating system and CRI.
- **NKP role / name**: supported OS matrix per infra; **cgroups v2 required** (NKP supports only images that boot with cgroups v2; it validates mode before provisioning). [pdf p.1009]
- **Supported in 2.19** (highlights): Rocky Linux 9.8 (all Nutanix tiers), Ubuntu 22.04/24.04 (Pro/Ultimate), RHEL 8.10/9.6/9.8 (FIPS), Flatcar 4081.x (AWS/pre-provisioned/vSphere), Oracle Linux 8.9/9.4, Amazon Linux 2023 (EKS nodes), Ubuntu 24.04.4 (AKS nodes). x86_64 only — **no ARM**. [pdf p.13–16]
- **containerd**: default runtime on nodes; Konvoy adds `/etc/containerd/conf.d/konvoy-metrics.toml` (metrics on `1338`) and restarts containerd via `preKubeadmCommands`. [pdf p.1000–1001]
- **Swap**: disabled; kubelet does not support it. [pdf p.767]

### MetalLB
- **What**: External load balancer for `LoadBalancer` services (L2/ARP or BGP).
- **NKP role / name**: deployed by default on supported clusters (`metallb-system`); CAREN `addons.serviceLoadBalancer.provider: MetalLB` with `addressRanges`. [pdf p.672][web: CAREN]
- **Default**: enabled (Nutanix/metal/pre-provisioned families).
- **Warning**: **do not edit** the default `IPAddressPool` / `L2Advertisement` — it stalls cluster upgrades; create new pools instead. [pdf p.672]

### konnector-agent
- **What**: Registers the NKP cluster with Prism Central so it shows in the PC infrastructure tab; enabled automatically during upgrades.
- **NKP role / name**: CAREN addon `clusterConfig.addons.konnectorAgent.credentials.secretRef`; secret name must be `<cluster>-pc-credentials-for-konnector-agent`. [pdf p.507–509]
- **Default**: enabled (`--onboard-to-prism-central=false` to disable).
- **Note**: if the konnector pod is stuck in Init, enable `karbon-core` in PC 7.3 and upgrade karbon-core to 2.10.2. [pdf p.724]

### AI Navigator
- **What**: Chat-style assistant answering NKP/Kubernetes questions from NKP docs, Nutanix KB, upstream K8s docs. [pdf p.1073]
- **NKP role / name**: platform application `ai-navigator-app`; RAG service; since 2.19 the **NKP MCP Server deploys automatically alongside it**. [pdf p.1073]
- **Runs on**: management cluster (app + RAG workload); inference via Nutanix-managed Azure OpenAI or your own Azure OpenAI (BYOM). [pdf p.1074][pdf p.1081]
- **Default**: installed by default on Pro/Ultimate **when internet is available**; requires accepting the user agreement (NKP ≥2.12 / DKP ≥2.6). [pdf p.1074]
- **Air-gap notes**: **not supported air-gapped** — explicitly excluded for public sector/defense/network-restricted. [pdf p.1073]
- **Disable on upgrade**: `nkp upgrade kommander --disable-appdeployments ai-navigator-app`. [pdf p.1018]

### NKP MCP Server
- **What**: MCP-compliant server giving AI Navigator real-time, identity-aware, **read-only** access to cluster state (queries the K8s API; forwards user identity so RBAC applies). [pdf p.1078]
- **NKP role / name**: platform application "NKP MCP Server"; tools `list`/`get` plus `discover_resource_types` and `list_resource_fields` (≥0.2.0). [pdf p.1078]
- **Default**: Pro/Ultimate, internet only; enable it (Ultimate: deploy in the management cluster workspace); ~1 minute for the agent to discover tools. [pdf p.1078–1079]
- **Air-gap notes**: same exclusion as AI Navigator.
- **Data**: read-only metadata/status for core workloads, storage, autoscaling, Flux GitOps (`HelmRelease`, `Kustomization`, `GitRepository`, `HelmRepository`, `HelmChart`, `OCIRepository`); only queried fields returned. [pdf p.1080]

### NKP Insights
- **What**: Predictive analytics that detect current/future anomalies and give root cause + remediation. Two parts: **Insights Management** (management cluster) and **Insights Engine** (each managed/attached cluster; on the management cluster for Pro single-cluster). [pdf p.1086]
- **NKP role / name**: platform application + UI "Insights" page; alert table + alert detail page; alerts also feed the certificate-renewal alerts. [pdf p.1086][pdf p.690]
- **Default**: requires explicit enablement of the engine per cluster. [pdf p.1086]
- **Version in 2.19**: NKP Insights **1.9** (adds security alert forwarding, tracked-resource state restore, image-tag CVE reports). [web: NKP 2.19 post]
- **Air-gap notes**: bundles ship as `nkp-insights-charts-bundle` + `nkp-insights-image-bundle` inside the air-gapped bundle → works offline. [pdf p.73–74]
- **Tier**: matrix shows Ultimate; Insights chapter mentions Pro single-cluster — verify. [pdf p.27][pdf p.1086]

### Pulse telemetry
- **What**: Opt-in telemetry to Nutanix (`https://insights.nutanix.com:443`).
- **NKP role / name**: Global → Settings → Pulse; shown for **Starter, Pro and Ultimate**; global-admin only. [pdf p.663]
- **Data shared**: NKP version, license type, cluster K8s version, cluster type (management/managed/attached), infra provider, node pool sizes and OS/CPU/memory, containerd/kubelet/kube-proxy versions, enabled NKP applications + versions, CSI driver name/version, NVIDIA driver version/memory. [pdf p.664]
- **Air-gap notes**: needs egress to insights.nutanix.com:443; leave disabled in air-gapped sites. [pdf p.663]

### Flux / git-operator (Kommander delivery tier — boundary note)
- **What**: Flux reconciles platform apps, projects/workspaces and GitOps-managed workload clusters; `git-operator` seeds the management Git repository. [pdf p.637][pdf p.671]
- **NKP role / name**: `git-operator-system` StatefulSet `git-operator-git`, `kommander-flux` namespace; `nkp upgrade workspace` deprecated in 2.19. [pdf p.1032]
- **GitOps upgrade gotcha**: must **disable Flux pruning** before upgrading GitOps-managed workload clusters, else the CAPI `Cluster` gets deleted when removed from Git. [pdf p.1037][pdf p.1048]

---

## `nkp` CLI and lifecycle flows (consolidated)

**Self-managed cluster creation (the canonical 5-step):**
1. `nkp create bootstrap`
2. `nkp create cluster <infra> ...`
3. `nkp get kubeconfig --cluster-name <c> > <c>.conf`
4. `nkp create capi-components --kubeconfig <c>.conf`
5. `nkp move capi-resources --to-kubeconfig <c>.conf`  (pivot)
6. `nkp delete bootstrap`
`--self-managed` does steps 4–5 for you. CAPI components include **cert-manager**; a non-self-managed cluster has neither CAPI nor cert-manager. [pdf p.22–23][pdf p.667]

**Cluster lifecycle verbs:** `create cluster <nutanix|metal|aws|eks|azure|aks|gcp|vsphere|preprovisioned>`, `create nodepool`, `scale nodepool`, `delete nodepool`, `get nodepools`, `delete cluster`, `describe cluster`, `check cluster`, `attach cluster`. [grep pdf]

**Upgrade order (2.19):** Kommander → management cluster → workload clusters.
- ClusterClass path (Nutanix AHV, EKS, Metal): `nkp upgrade kommander` → `nkp upgrade cluster <infra> --vm-image|--control-plane-vm-image/--worker-vm-images` (CLI mandatory 2.18→2.19) → per-workload-cluster UI (**Administration > Upgrades**) or CLI. [pdf p.1017–1024]
- Non-ClusterClass path (AWS/Azure/GCP/vSphere/pre-provisioned): `nkp upgrade kommander` → `nkp upgrade addons <infra>` → `nkp update controlplane <infra> --kubernetes-version` → `nkp update nodepool <infra> <pool>` (×N) → same for each workload cluster, with `nkp upgrade platform-apps --cluster-name --namespace` first. [pdf p.1025–1034]
- Version policy: **sequential minor versions**, patch versions skippable; official upgrade matrix 2.15.0…2.19.0. [pdf p.1011–1012]
- `kommander` namespace holds the management cluster's node pools from **2.18** onward — `-n kommander` on nodepool commands. [pdf p.1030]
- Management cluster name/namespace are read from `NKPCluster.status.capiClusterRef`, not `metadata.name`. [pdf p.1020]

**Upgrade levers documented:** `topology.cluster.x-k8s.io/upgrade-concurrency`; PDBs on critical apps; `--skip-preflight-checks=<Check>|all`; `nkp upgrade kommander -v 6` for verbose failures. [pdf p.1018][pdf p.726][pdf p.1047]

---

## Relationships

- NKP -> Konvoy + Kommander + NIB: the three product components; Konvoy builds clusters, Kommander operates fleets/apps, NIB builds the images both need. [pdf p.20]
- `nkp` CLI -> bootstrap cluster (kind): every cluster creation starts by standing up a throw-away kind cluster on the operator machine. [pdf p.23]
- bootstrap cluster -> CAPI + cert-manager + infra provider: `nkp create capi-components` installs the control loops into the bootstrap cluster. [pdf p.667]
- CAPI resources -> management cluster: `nkp move capi-resources` (pivot) makes the new cluster self-managed so it manages its own MachineDeployments. [pdf p.23]
- management cluster -> workload clusters: CAPI + ClusterClass + CAREN reconcile workload cluster lifecycle and addons from the management cluster. [pdf p.1019]
- CAREN -> ClusterClass: `spec.patches[].external.discoverVariablesExtension/generateExtension` hooks expose `clusterConfig`/`workerConfig` on the ClusterClass. [pdf p.418][web: CAREN]
- `Cluster` -> `NKPCluster`: NKPCluster owns/controls the CAPI Cluster via `spec.capiCluster`; webhook blocks direct Cluster topology edits. [pdf p.1015][pdf p.1048]
- CAREN -> CAAPH / ClusterResourceSet: addons are installed by HelmChartProxy (`HelmAddon`) or ClusterResourceSet. [web: CAREN CNI]
- CAPX -> Prism Central: provider authenticates to PC (9440) and to PE for VM/subnet placement; failure/session expiry leaves nodes `NotReady`. [pdf p.692][web: NKP 2.19]
- CAPX -> Nutanix CSI -> storage container: CSI is the default StorageClass on AHV; PVCs live in a PE storage container. [pdf p.694]
- Metal hosts -> Foundation Central -> host agent -> management cluster: imaging bakes in a bootstrap token; the host agent then CSRs against the management cluster API. [pdf p.745–747]
- Kommander -> Flux (git-operator): apps, workspaces and GitOps workload clusters are reconciled by Flux from the management Git repo. [pdf p.637]
- License `License` CR -> default platform applications: applying a Pro/Ultimate key is what makes NKP install the extra default apps (AI Navigator, Centralized Grafana). [pdf p.28–29]
- AI Navigator -> NKP MCP Server -> Kubernetes API: MCP returns RBAC-filtered live cluster data into the RAG answer. [pdf p.1078]
- NKP Insights Engine -> Insights Management: engine on each cluster raises alerts surfaced on the management cluster. [pdf p.1086]
- Pulse -> Nutanix: telemetry inventory used for product analytics, not control. [pdf p.664]
- konnector-agent -> Prism Central: makes NKP clusters visible in PC; enabled automatically on upgrade unless disabled. [pdf p.507]

---

## Version deltas

| Version | Notable lifecycle-relevant change | Source |
|---|---|---|
| pre-2.12 | Product was D2iQ DKP; Nutanix K8s product was NKE. NKE customers migrate to NKP 2.12+. | [web: nutanix.com/d2iq, nutanixbible] |
| 2.12 | First NKP release on Nutanix technology; full NCI support. | [web: nutanix.com tech-center "NKP the Nutanix way"] |
| DKP 2.6 | Attach of all conformant clusters; HTTP proxy handled via Konvoy flags instead of NIB override. | [pdf p.426][pdf p.1147] |
| 2.13.1 | `nkp create metadata nutanix`; Full Stack license support begins. | [pdf p.33] |
| 2.16 | Kubernetes **1.33**; Ubuntu Pro images as an option (Pro/Ultimate); Partner Catalog self-service. Seeding the registry became optional for clusters created from 2.16 on. | [web: nutanix.com "NKP 2.16 Is Here"][pdf p.996] |
| 2.17 | Kubernetes **1.34**; validated STIG-compliant Ubuntu image; NDK available through the app catalog. | [web: itcs.lu part 6][web: "Putting Security First with NKP 2.17"] |
| 2.18 | Kubernetes **1.35** support; `NKPCluster` API + admission webhook guarding CAPI `Cluster`; kubelet config via CAREN; control-plane cert renewal moved from systemd to CAPI; legacy EKS workflow + KubeFed + Kubernetes Dashboard + AI Navigator Cluster Info Agent deprecated; management cluster node pools live in `kommander` namespace. | [web: timeline.ntnx.to][web: itcs.lu nkp-218-released-verified][pdf p.993][pdf p.685][pdf p.1030] |
| 2.19 | **NKP Metal** (Foundation Central + Metal Host Inventory); Kubernetes **1.36.2**; Prism Central Projects 2.0 → one project per cluster; ClusterClass-based simplified upgrades for AHV/EKS; NKP MCP Server auto-deployed with AI Navigator; **Headlamp replaces Kubernetes Dashboard**; GitRepository catalogs removed (must migrate AppDeployments to OCIRepository); `--kommander-applications-repository` removed; `nkp upgrade workspace` deprecated; Nutanix Docker Hub credentials required at upgrade for connected clusters; Insights 1.9; NDK 2.3; NAI 2.8.x. | [web: next.nutanix.com NKP 2.19][pdf p.1015][pdf p.1017][pdf p.1032] |

---

## Gaps / open questions

- **etcd version in 2.19**: not in the PDF (defers to release notes "Supported Components"). Need the release-notes PDF/portal page.
- **Metal infrastructure provider internals**: CRD group/version for `NutanixBareMetalMachineTemplate` / `HostAgentMachineTemplate`, and the host-agent component name/namespace — UNKNOWN.
- **ClusterClass inventory**: exact set of ClusterClass names shipped in 2.19 (only `nkp-nutanix-v2.19.0`, `nkp-nutanix-2-18-...`, `nutanix-quick-start`, `default-worker`, `host-agent-worker` observed). Need `kubectl get clusterclass -A` on a live 2.19 management cluster or the CAPI components manifest.
- **CAREN version** shipped in 2.19 (upstream docs mention v0.50.0 examples) — not stated in the PDF.
- **NKP Insights tier**: matrix implies Ultimate-only; Insights chapter implies Pro single-cluster works. Needs confirmation.
- **CAPX version** shipped in 2.19 (upstream is v1.10.x) — not stated.
- **"Flow" CNI**: documented upstream (Nutanix-only, `HelmAddon` only, images on docker.io/nutanix), but the 2.19 NKP PDF only names Cilium (AHV/EKS) and Calico (all other providers). Need to confirm whether NKP 2.19 exposes Flow CNI as a supported choice.
- **`nkp create cluster metal` full flag list**: PDF says "run `nkp create cluster metal --help`" — needs a live CLI.
- **vCluster / third-party provider**: `nkp create cluster ... vcd` appears once in a registry example (`gcp, vsphere, vcd, pre-provisioned, aws`) [pdf p.675] but VCD is not in the supported-provider lists — likely doc residue. Do not document VCD as supported.
- Legacy doc residue to ignore: `kubefed` cluster statuses (Join/Unjoin) in the Cluster Statuses table are pre-2.18 leftovers. [pdf p.498–499]
