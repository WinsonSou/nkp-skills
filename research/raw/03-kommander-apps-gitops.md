# 03 — Kommander (fleet management) + Platform Applications + GitOps

Research note for NKP 2.19. Area owner: Kommander architecture, platform/catalog applications, GitOps.
Sources: `[pdf p.N]` = NKP 2.19 PDF (research/raw/pdf/2.19), `[web: url]`, `[field: <note>]`.

---

## Components

### Kommander (fleet manager / application manager)
- **What**: Fleet-management component of NKP. Central observability, control, governance, policy, and application management for one or many clusters.
- **Upstream**: D2iQ Kommander (proprietary), built on Flux CD.
- **NKP role / name**: platform app `kommander` (management cluster only, `kommander` namespace). Controller is `deployment/kommander-cm`; also called "Kommander Host".
- **Runs on**: management cluster.
- **Deployed by**: `nkp install kommander --installer-config kommander.yaml` (after Konvoy cluster exists) → creates HelmReleases/AppDeployments.
- **Default**: enabled; requires a license (Starter/Pro/Ultimate). Management-cluster LCM (incl. Upgrade Management Cluster) is in all three tiers. [pdf p.26-27]
- **Version in 2.19**: UNKNOWN (PDF defers to portal release notes; `kommanderChartsVersion` installer parameter).
- **Depends on / talks to**: Flux (`kommander-flux`), kommander-appmanagement, git-operator (internal git), kubefed, Traefik, Dex, cert-manager (`kommander-ca`).
- **Air-gap notes**: install with `nkp install kommander --init --airgapped`. AI Navigator is **not** installed in air-gapped environments. ChartMuseum is installed **only** in air-gapped mode.
- **Key CRDs / namespaces / CLI**: ns `kommander`; `nkp install kommander`, `nkp upgrade kommander`, `nkp open dashboard`, secret `kommander/nkp-credentials`.
- **Sources**: [pdf p.20, 941-956, 1058-1059, 1068-1070, 954]

### Kommander UI (dashboard)
- **What**: Web UI. Three levels: **Global** (IT admin, all clusters), **Workspace** (DevOps admin), **Projects** (devs).
- **NKP role / name**: platform app `kommander-ui`, ns `kommander`, PriorityClass `nkp-critical-priority` (100002000).
- **Default**: enabled on management cluster.
- **Key commands**: `nkp open dashboard`; `kubectl -n kommander get secret nkp-credentials -o go-template='{{.data.username|base64decode}}...'`. Branding: header/footer/logo upload is supported.
- **Sources**: [pdf p.318, 954-956, 699, 271]

### kommander-flux (Flux CD)
- **What**: GitOps engine that reconciles everything Kommander installs.
- **Upstream**: https://github.com/fluxcd/flux2 (source-controller, kustomize-controller, helm-controller).
- **NKP role / name**: platform app id **`kommander-flux`** (the only platform app marked "Internal: Yes" besides centralized-grafana, git-operator-backed items, thanos, karma, pulse, gateway-api-crds, kubetunnel, cilium-hubble-relay-traefik). Namespace `kommander-flux`.
- **Runs on**: management cluster **and** every attached/managed cluster.
- **Deployed by**: Kommander platform app (AppDeployment → ClusterApp → HelmRelease).
- **Default**: enabled in **all** tiers, mgmt + workload. Feature matrix: "FluxCD (as an application)" = Pro+Ultimate; "Continuous Deployment (FluxCD)" = Ultimate only.
- **Depends on / talks to**: git-operator (management GitRepository `kommander/kommander`), registry mirror (Helm charts), Gatekeeper network policy.
- **Key CRDs / CLI**: `GitRepository`, `OCIRepository`, `Kustomization`, `HelmRepository`, `HelmRelease`, `HelmChart`; controllers `deploy/source-controller`, `deploy/kustomize-controller`, `deploy/helm-controller` in `kommander-flux`.
- **Sources**: [pdf p.299, 954, 1059, 358, 699]

### kommander-appmanagement (App / ClusterApp / AppDeployment controller)
- **What**: Controller that manages the application abstraction: `App`, `ClusterApp`, `AppDeployment` and the generated `Kustomization`s.
- **NKP role / name**: platform app `kommander-appmanagement`, deployment `kommander-appmanagement` in ns `kommander`. Image tags overridable via `appManagementImageTag`, `appManagementImageRepository`, `appManagementKubetoolsImageRepository`.
- **Default**: enabled (management cluster).
- **Deployment chain (memorise)**: `AppDeployment` → (`ClusterApp` | `App`) → Flux `Kustomization` → `HelmRelease` → `HelmChart`.
- **Key CRDs**: `apps.kommander.d2iq.io/v1alpha3` — `AppDeployment`, `ClusterApp`, `App`.
  - `ClusterApp` = cluster-scoped (platform apps, deployable to all workspaces/projects).
  - `App` = namespace-scoped (NKP catalog + custom apps; only in the workspace/project where created).
- **Key fields**: `spec.appRef{name,kind}`, `spec.configOverrides.name` (ConfigMap, workspace-wide), `spec.clusterSelector.matchExpressions` (`kommander.d2iq.io/cluster-name`), `spec.clusterConfigOverrides[]{configMapName, clusterSelector}`.
- **Sources**: [pdf p.271-273, 1058-1063, 699]

### kommander-applications (repository of platform app manifests)
- **What**: Git repository holding the declarative definitions of every platform application (Flux manifests, HelmRepositories, defaults ConfigMaps).
- **Upstream**: https://github.com/mesosphere/kommander-applications (public per PDF links; structure `common/helm-repositories`, app dirs). *Public read access not re-verified in this pass → treat as PDF-asserted.*
- **NKP role / name**: committed into the internal management git repo; `kustomization apps-kommander` deploys `apps` into the `kommander` namespace.
- **Default**: always present after Kommander install.
- **Air-gap notes**: HelmRepository URLs use substitution `${helmMirrorURL:=https://...}`; the installer sets `helmRepositoryURL` to the mirror before applying them.
- **Sources**: [pdf p.1068-1070]

### Git Operator (internal git service) + management git repository
- **What**: Serves the **internal git repository** that holds Kommander's own GitOps state; Flux clones it. Provides the Gitea-backed git server plus age/SOPS secret handling.
- **NKP role / name**: platform app id `git-operator`; namespace `git-operator-system`; secret `kommander-flux/gitserver-ca` on workload clusters holds CA + username + password used to pull from it.
- **Runs on**: management cluster.
- **Default**: enabled in all tiers (management cluster) — Table 22 shows Starter/Pro/Ultimate mgmt only.
- **Depends on / talks to**: Flux (`GitRepository` named `management` in `kommander-flux`), `kommander-vars` ConfigMap (substitution variables), `DefaultCatalogGitRepository` controller (propagates catalog `GitRepository`s to workspaces/projects), Age encryption secret `sops-age`.
- **Key commands / names**: repo URL form `https://<mgmt-domain>/dkp/kommander/git-operator/repositories/kommander/kommander.git` (in-cluster: `http://git-operator-git.git-operator-system.svc.cluster.local/...`); installer params `ageEncryptionSecretName` (default `sops-age`).
- **Sources**: [pdf p.392, 1068-1070, 960; field: NKP - Flux.md]

### ChartMuseum (air-gapped Helm chart store)
- **What**: Local Helm chart repository used only when air-gapped.
- **NKP role / name**: installed by the Kommander installer via the Helm library; its `HelmRelease` only reconciles once the internal Git repo is populated. Sets `helmRepositoryURL` in the installer config. In non-air-gapped installs charts come from upstream repos and ChartMuseum is **not** installed. Installer params `air-gapped.helmMirrorImageTag` / `helmMirrorImageRepository`.
- **Default**: air-gapped only (`--init --airgapped`).
- **Sources**: [pdf p.962, 1069]

### KubeFed (federation) — still present in 2.19
- **What**: Federates namespaced configuration from the management cluster to project member clusters (federated namespaces, roles, role bindings, configmaps, secrets).
- **NKP role / name**: platform app id `kubefed`; namespace `kube-federation-system`. Federated namespace type short name `fns` (e.g. `kubectl patch fns -n kommander kommander`). `nkp-insights-management` has a **required dependency on `kubefed`**. `kommander-cm` (Kommander controller) drives federation; Kommander RBAC resources are "federated to clusters within a given scope".
- **Default**: `kubefed.enabled: true` in the default installer config; **not** in Table 22's license table (installer-level app). Ultimate is the tier where Projects/federation is usable; Pro is single-cluster.
- **Replacement status**: **not replaced** — KubeFed still ships in 2.19. The *newer* abstraction is `NKPCluster` (2.19) which wraps CAPI `Cluster` + `KommanderCluster`; federation of namespaced objects still uses kubefed.
- **Sources**: [pdf p.369, 954-955, 960, 307, 227-228, 2161-2205, 3835-3837, 0957 p.983, 1035-1036]

### Workspace (`Workspaces` CRD)
- **What**: Logical grouping of clusters with shared configuration; the unit for platform-application rollout and RBAC. Cluster **cannot** be moved between workspaces after creation/attachment.
- **NKP role / name**: CRD `workspaces.kommander.mesosphere.io` (`kind: Workspace`, `v1alpha1`); each workspace gets a namespace. Labels on the workspace are applied to all `kommanderclusters` in it. Reserved workspace **`kommander-workspace`** ("Management Cluster Workspace") = management cluster only — never attach into it.
- **Runs on**: management cluster (control plane object).
- **Default**: a **Default Workspace** exists out of the box. Workspaces Management = Ultimate only (feature matrix); Pro configures/deploys applications to a single cluster in a workspace.
- **Key commands**: `nkp get workspaces`; `kubectl get workspaces`; `kubectl describe workspace <name>`; controller `deploy/kommander-cm` in `kommander`.
- **Sources**: [pdf p.317-323, 1058, 427-428, 27]

### Project (`Project` CRD) + project CD (`GitopsRepository`)
- **What**: Sub-set of clusters inside a workspace that share federated configuration; adds multi-tenant logging, quotas, project roles. Creating a Project creates a **Kubernetes federated namespace** on all matching clusters.
- **NKP role / name**: CRD `workspaces.kommander.mesosphere.io/v1alpha1`, `kind: Project`; auto namespace name = first 57 chars of project name + 5 random chars. Project CD source CRD: `gitopsrepositories.dispatch.d2iq.io` (`GitopsRepository`, controller `GitopsRepositoryController`).
- **Deployed by**: UI/CLI/kubectl apply.
- **Default**: Projects = Ultimate only (feature matrix); project-level platform apps only in Ultimate.
- **Key commands**: `nkp create appdeployment <name> --app <APP-ID>-<ver> --workspace <ws> --project <proj>`; `nkp upgrade catalogapp <ad> --workspace=... --project=... --to-version=...`; project CD resources `GitRepository` + `Kustomization` in the project namespace.
- **Multi-tenant safety**: project CD auto-creates a ServiceAccount named after the project, namespace-scoped RBAC only, applied to the root Kustomization; tenants must not ship cluster-scoped resources.
- **Sources**: [pdf p.369-397, 387-397]

### KommanderCluster
- **What**: Object that registers a workload cluster with Kommander and drives its platform-application management.
- **NKP role / name**: CRD `kommander.mesosphere.io/v1beta1`, `kind: KommanderCluster`, namespaced in the workspace namespace. Annotation `kommander.mesosphere.io/display-name`. Label selector key used by AppDeployments: `kommander.d2iq.io/cluster-name`. Host cluster is labelled `kommander.d2iq.io/host=true`, ingress address read from `status.ingress.address`. Phase: `Joined`.
- **Runs on**: management cluster (object); represents the attached/managed cluster.
- **Deployed by**: CAPI/NKPCluster controller (managed clusters) or manual apply (attached, incl. network-restricted via `spec.clusterTunnelConnectorRef`).
- **Default**: one per cluster in a workspace.
- **Key commands**: `kubectl get kommanderclusters -n <ws-ns> -o yaml`; `kubectl get kommandercluster -A -l 'kommander.d2iq.io/host=true'`.
- **Sources**: [pdf p.426-454, 1058, 271-273, 284, 323]

### NKPCluster (2.19 unified cluster CRD) + admission webhook
- **What**: Wraps a CAPI `Cluster` and a `KommanderCluster` into one resource; single source of truth for cluster lifecycle, and the target for GitOps-managed workload clusters.
- **NKP role / name**: CRD `clusters.nkp.nutanix.com/v1alpha1`, `kind: NKPCluster`. Fields `spec.capiCluster` (ClusterClass ref, k8s version, network, CP replicas, machineDeployments), `spec.kommanderCluster`, `spec.version` (NKP platform version, e.g. `v2.19.0`), plus `status`-side refs `capiClusterRef` / `kommanderClusterRef`. Labels `cluster.x-k8s.io/cluster-name`, `cluster.x-k8s.io/provider`. ClusterClass name carries the NKP version, e.g. `nkp-nutanix-v2.19.0`.
- **Default**: created for all CAPI clusters; introduced by the Kommander upgrade (auto-adopts existing CAPI clusters). **GitOps create/upgrade supported for workload clusters only.**
- **Admission webhook**: rejects direct edits to `spec.topology` of a managed `CAPICluster` from any source (kubectl/other controllers/Flux). Only the NKPCluster controller may change topology. Consequence: GitOps repos must move from `CAPICluster` to `NKPCluster`; set `spec.prune: false` on the managing Kustomization **before** the upgrade or Flux deletes the live cluster.
- **Sources**: [pdf p.1035-1041]

### Kubetunnel (attach clusters with networking restrictions)
- **What**: Reverse tunnel so the management cluster can reach a workload cluster's API server without exposing it (no ingress/route needed).
- **NKP role / name**: platform app id `kubetunnel` (Internal: Yes, required). Namespace `kubetunnel`. CRDs include `TunnelConnector` (status `Connected`). `KommanderCluster.spec.clusterTunnelConnectorRef.name` links them.
- **Runs on**: management cluster (tunnel server) + attached cluster (`tunnel-agent` deployment, `post-kubeconfig` job).
- **Default**: enabled (mgmt + workload, Pro/Ultimate per Table 22; `kubetunnel.enabled: true` in installer).
- **Air-gap / security**: NetworkPolicy label `kubetunnel.d2iq.io/tunnel-connector`, type `kubetunnel.d2iq.io/networkpolicy-type: tunnel-server`; opt-in per namespace `kubetunnel.d2iq.io/networkpolicy=<connector>-<ns>`; allowed peers commonly `kommander` and `kube-federation-system`.
- **Sources**: [pdf p.310, 2100-2230, 445-455]

### Konnector (KonnectorAgent add-on) — *not* kubetunnel
- **What**: Cluster **add-on** that registers an NKP-provisioned cluster with **Prism Central** so it appears in the PC infrastructure tab. Part of `clusterConfig.addons` in the CAPI cluster, not a Kommander attach mechanism.
- **NKP role / name**: `konnectorAgent` add-on with credential secret `<CLUSTER>-pc-credentials-for-konnector-agent`; auto-enabled during cluster upgrade.
- **Runs on**: workload cluster (managed by KONVOY/CAPI, not Kommander).
- **Sources**: [pdf p.4700-4765, 507-508]

### Platform Applications (deployment model)
- **What**: Curated set of applications baked into NKP. Deployed as a **bundle per workspace**: "Platform applications are bundled and tested as a single unit. You must deploy or upgrade the entire bundle in one operation per workspace. As a result, all clusters within a workspace run the same set and version of the deployed platform applications." [pdf p.305]
- **NKP role / name**: each enabled app ⇒ one `AppDeployment` + one cluster-scoped `ClusterApp` named `<app-id>-<app-version>` (e.g. `kiali-2.24.0`, `kube-prometheus-stack-82.13.6`).
- **Deployed by**: Kommander via Flux (`Kustomization` → `HelmRelease`).
- **Default / tier**: see table below.
- **Key commands**: `nkp create appdeployment <name> --app <APP-ID>-<version> --workspace <WS> [--clusters a,b]`; `nkp get appdeployments -w <ws>`; `nkp get appdeployment <name> -w <ws> --output yaml`; `nkp edit appdeployment <name> -n <ns>`; `kubectl get apps,clusterapps,appdeployments -A`; `kubectl get helmreleases -n ${WORKSPACE_NAMESPACE} -w`.
- **Upgrade rule**: platform apps cannot be upgraded one-off — upgrade together per workspace. Catalog apps can (`nkp upgrade catalogapp`).
- **Upstream chart/registry hosts** (the "Required Domains" list doubles as the map of where platform-app charts come from when **not** air-gapped): `charts.jetstack.io` (cert-manager), `charts.rook.io` (rook-ceph/-cluster), `cloudnative-pg.io` (CloudNativePG), `grafana.github.io` (grafana-logging), `fluent.github.io` + `kube-logging.github.io` (fluent-bit / logging-operator), `helm.goharbor.io` (Harbor), `helm.traefik.io` (Traefik, ForwardAuth), `prometheus-community.github.io` (kube-prometheus-stack, prometheus-adapter), `open-policy-agent.github.io` (Gatekeeper), `kiali.io` (Kiali), `jaegertracing.github.io` (Jaeger), `kubernetes.github.io` (kubernetes-dashboard), `helm.ngc.nvidia.com` (NVIDIA GPU Operator), `nvcr.io`, `mesosphere.github.io` (legacy D2iQ charts), `kubecost.github.io` (legacy), plus `registry.k8s.io`/`docker.io`/`quay.io`/`gcr.io`/`mcr.microsoft.com`/`pkg-containers.githubusercontent.com`. In an air-gapped install these need not be reachable. `[pdf p.53-54]`
- **Sources**: [pdf p.271-274, 297-316, 350-351, 1058-1063, 53-54]

### Catalog applications (NKP catalog, custom, partner)
- **What**: Third-party/OSS and Nutanix-product applications shown in the Catalog, deployed for customer workloads. Individual deploy/upgrade per workspace or project.
- **NKP role / name**: `App` + `AppDeployment` (namespace-scoped). Catalog sources are Flux `GitRepository`/`OCIRepository` objects labelled `kommander.d2iq.io/gitrepository-type: catalog` and `kommander.d2iq.io/gitapps-gitrepository-type: catalog`.
- **Catalog repo layout (2.19, OCI)**: `applications/<app-name>/<app-version>/` containing
  - `helmrelease/helmrelease.yaml` — **OCIRepository + HelmRelease**
  - `helmrelease/cm.yaml` — defaults values ConfigMap
  - `helmrelease/kustomization.yaml`, outer `helmrelease.yaml` (Flux Kustomization), outer `kustomization.yaml`
  - `metadata.yaml` — UI metadata, schema id `catalog.nkp.nutanix.com/v1/application-metadata`
- **Substitution variables** (Flux post-build): `${releaseName} ${releaseNamespace} ${workspaceName} ${workspaceNamespace} ${appName} ${appVersion} ${projectName} ${projectNamespace} ${clusterName} ${clusterType} ${clusterUUID}` (project vars only populated for project deployments; cluster labels unavailable).
- **Legacy layout (pre-OCI, still seen in field repos)**: `helm-repositories/<app>/<app>-repo.yaml` + `services/<app>/metadata.yaml` + `services/<app>/<version>/{<app>.yaml,defaults/cm.yaml,kustomization.yaml}`. [field: NKP - Creating a Custom App Catalog Item.md, nkp-kasten-catalog]
- **metadata.yaml fields**: `displayName, allowMultipleInstances(default true), category([general]), description, dependencies, requiredDependencies, k8sVersionSupport, icon(base64 svg), nkpVersionSupport, overview(markdown), supportLink, scope([project]|workspace), upgradesFrom, licensing([Pro,Ultimate]), certifications, type(custom)`.
- **Key commands**: `nkp generate catalog-repository [--apps=<app>=<ver>]`; `nkp validate catalog-repository --repo-dir=<path>` (Bloodhound linter, `.bloodhound.yaml`); `nkp create catalog-bundle --collection-tag <tag> [--apps=..] [--airgapped]`; `nkp push bundle --bundle <tar> --to-registry <url>`; `nkp create catalog-collection --url oci://<reg>/<repo>/collection --workspace <ns> --tag <tag>`; `nkp create catalog-application --url oci://<reg>/<app> --tag <ver> --workspace <ns>`; `kubectl get apps -n ${WORKSPACE_NAMESPACE}`; `kubectl get ocirepository -n <ns>`.
- **Propagation**: a catalog created in `kommander-workspace` propagates to all workspaces/projects (controller `DefaultCatalogGitRepository`, driven by labels); use `--workspace`/`--project` to scope.
- **Partner catalog**: https://github.com/nutanix-cloud-native/nkp-partner-catalog — fork, `devbox shell`, `nkp generate catalog-repository --apps=...`, OCI artifacts auto-pushed to `ghcr.io/nutanix-cloud-native/nkp-partner-catalog/<app-name>`; CI validates install+upgrade.
- **Sources**: [pdf p.327-368, 350-368, 355-361, 348-350; field: nkp-kasten-catalog/README, kubeflow-catalog.yaml]

### Nutanix product catalog (NDK / NAI) + air-gapped catalog bundles
- **What**: Nutanix-shipped catalog repo containing Nutanix product applications (NDK, Nutanix Enterprise AI, etc.).
- **Upstream**: https://github.com/nutanix-cloud-native/nkp-nutanix-product-catalog. Release specs `.release/stable.yaml` (2.16–2.19) define catalog collections with pinned app versions; schema `catalog.nkp.nutanix.com/v1/catalog-release-spec` [web: github.com/nutanix-cloud-native/nkp-nutanix-product-catalog/blob/release-2.x/.release/README.md].
- **Air-gapped path**: `git clone` the catalog → `nkp create catalog-bundle --airgapped --apps=ndk="<ver>"` → `nkp push bundle --bundle <tar> --to-registry-mirror-url=... ` → `nkp create catalog-application --url oci://<mirror>/nkp-nutanix-product-catalog/ndk --tag <ver> --workspace kommander-workspace`.
- **NDK**: cluster-scoped catalog app, ns `ntnx-system`, needs DockerHub image-pull secret per cluster (access tokens from the Nutanix portal); supported on mgmt + workload clusters; installable from UI since 2.17.
- **Sources**: [pdf p.339-346, 946, 0317 p.339-341; web: nkp-nutanix-product-catalog]

### AI Catalog applications (AI conformance)
- **What**: Validated AI/ML components deployable from the workspace catalog. **Lineup 2.19**: `KAI Scheduler`, `Slurm Operator`, `Kueue`, `Kubeflow Pipelines`, `JupyterHub`, `Milvus Operator` (+ `KServe` referenced for inference metrics).
- **Prereqs**: Pro/Ultimate license; target managed/attached cluster in a workspace; NVIDIA GPU Operator (or AMD) enabled first; for schedulers enable the GPU operator *before* the scheduler.
- **Nutanix Enterprise AI (NAI)** prerequisites (from p.329): Cert Manager, Prometheus Monitoring, NVIDIA GPU Operator, CloudNativePG, NAI-Envoy Gateway v1.8.2, KServe v0.19.0, OpenTelemetry Operator v0.114.1, LeaderWorkerSet 0.8.0; `nai-system` + `envoy-gateway-system` namespaces with docker-registry secret; NAI versions `2.8.0`/`2.8.1`; profiles `Default` (300 req/100 keys), `c1k_k200`, `c5k_k1k`.
- **Metrics**: NKP monitoring scrapes Kueue and KServe in Prometheus exposition format.
- **Sources**: [pdf p.622-628, 329-332, 0607 GPU]

### Headlamp (new in 2.19 — replaces Kubernetes Dashboard)
- **What**: Kubernetes web dashboard shipped as a platform app; per-cluster, UI access through NKP SSO, RBAC-driven.
- **Upstream**: https://github.com/headlamp-k8s/headlamp.
- **NKP role / name**: platform app `headlamp`; Helm support, plugin management and plugin catalog **disabled and not configurable**. Service port 4466 (port-forward example).
- **Default**: **enabled by default on fresh 2.19 installs** (mgmt + workload); **not** enabled on upgrade to 2.19 (brownfield must enable manually per workspace). Pro + Ultimate only.
- **Key commands**: `kubectl get appdeployments -A | grep headlamp`; `kubectl get helmreleases -A | grep headlamp`; `kubectl get pods -A -l app.kubernetes.io/name=headlamp`; `kubectl create token headlamp-viewer -n headlamp-viewer`.
- **Auth**: service-account token + `view` ClusterRole; do not use a `cluster-admin` token.
- **Sources**: [pdf p.313-315]

### Kubernetes Dashboard (legacy, deprecated upstream)
- **What**: Old web dashboard, still a platform app id `kubernetes-dashboard`; optional dependency `traefik`; deprecated upstream → superseded by Headlamp in 2.19. Still listed in Table 22 (Pro/Ultimate mgmt+workload) and in the minimal installer (`enabled: false`).
- **Sources**: [pdf p.296, 303, 313, 954]

### Harbor (NKP-shipped registry)
- **What**: Cloud-native registry for storing/signing/scanning images and OCI artifacts; also usable as a **registry mirror / pull-through cache**.
- **Upstream**: https://goharbor.io.
- **NKP role / name**: platform app id `harbor` — **management cluster only**, Pro + Ultimate. Namespace `ncr-system` (secret `harbor-admin-password`). Registry URL: `https://$(kubectl get kommandercluster -A -l 'kommander.d2iq.io/host=true' -o jsonpath='{.items[0].status.ingress.address}'):5000`.
- **Default**: **not** deployed by default (Pro/Ultimate, optional). Requires **CloudNativePG** and S3-compatible object storage: Nutanix Objects (via COSI Driver for Nutanix), Rook Ceph, or manual bucket (endpoint/access key/secret key/region/bucket).
- **Sizing**: ≥100 GB recommended; Rook Ceph default ≈120 GB usable shared with logging/backup; default 4 OSDs × 40 GiB, scale with `storageClassDeviceSets[].count` **through an AppDeployment override** (never edit the `rook-ceph-cluster-<version>-config-defaults` ConfigMap).
- **Air-gap notes**: primary air-gapped pattern — mirror registry or private registry for managed/attached clusters; CA cert must be configured when the ingress cert is from a private CA (`certSecretRef`-style config on the cluster's `imageRegistry`).
- **Sources**: [pdf p.282-293, 296, 308, 646-651, 713-714]

### Velero (backup — only named here)
- **What**: Backup/restore + DR platform app; optional dependency `rook-ceph-cluster` (can be overridden away). Pro + Ultimate, mgmt + workload, **not** enabled by default. Detail lives in the backup area note.
- **Sources**: [pdf p.297, 305, 703]

### OpenCost / Centralized OpenCost / Centralized Grafana (cost + central metrics)
- **What**: `centralized-grafana` (mgmt, **Internal: Yes**, Ultimate only) and `centralized-opencost` (Ultimate, PV 10Gi) provide centralized metrics/cost; `opencost` is the per-cluster cost app (Ultimate, mgmt + workload).
- **Kubecost status**: **Kubecost is gone from the 2.19 platform app list** — replaced by OpenCost. The PDF only mentions `kubecost-prometheus-server.kommander` in a proxy `noProxy` example and `kubecost.github.io` in the required-domains list, i.e. legacy leftovers; upgrades from ≤2.16 may still carry a Kubecost install. Treat Kubecost as **removed/legacy**, OpenCost as the supported cost app.
- **Default**: per Table 22 = Ultimate only; `opencost` / `centralized-opencost` marked "Deployed by default: Yes" in the mgmt/workspace requirement tables (Ultimate `*`).
- **Sources**: [pdf p.295-296, 699, 702, 981, 53]

### Reloader
- **What**: Restarts pods when their ConfigMaps/Secrets change; **foundational** platform app (needed by the rest).
- **NKP role / name**: app id `reloader`; all tiers, mgmt + workload; deployed by default; PriorityClass NKP High; internal: No.
- **Sources**: [pdf p.299, 703]

---

## FULL TABLE — Supported Platform Applications per license (PDF Table 22, p.295-297)

Column key: `M` = management cluster, `W` = workload cluster. Reconstructed from the PDF table's column geometry (a naive text dump garbles it).
`Default` column sources: `M` = management-cluster requirement table [p.699], `W` = workspace requirement table [p.700-703], `I` = installer `apps:` default [p.960], `T` = prose. `n/s` = not stated.

| Platform application | APP ID | Starter M | Starter W | Pro M | Pro W | Ult M | Ult W | Default | Internal | Req. dep | Opt. dep |
|---|---|---|---|---|---|---|---|---|---|---|---|
| AI Navigator App | `ai-navigator-app` | – | – | X | – | X | – | yes (I; non-air-gapped only) | No | – | – |
| AI Navigator Cluster Info Agent | `ai-navigator-cluster-info-agent` | – | – | X | – | X | – | yes (T) | No | cloudnative-pg | – |
| AI Navigator RAG | `ai-navigator-rag` | – | – | X | – | X | – | yes (T) | No | cloudnative-pg | – |
| Centralized Grafana | `centralized-grafana` | – | – | – | – | X | – | yes (M) | **Yes** | – | – |
| Cert Manager | `cert-manager` | X | X | X | X | X | X | yes (W) | No | – | – |
| Cilium Hubble Relay Traefik | `cilium-hubble-relay-traefik` | – | – | X | X | X | X | n/s | **Yes** | traefik | – |
| CloudNativePG | `cloudnative-pg` | – | – | X | X | X | X | no (W) | No | – | – |
| COSI Driver Nutanix | `cosi-driver-nutanix` | – | – | X | X | X | X | no (W) | No | – | – |
| Dex | `dex` | X | – | X | – | X | – | yes (M) | No | – | – |
| Dex K8s Authenticator | `dex-k8s-authenticator` | X | – | X | – | X | – | yes (M) | No | dex, kommander, traefik | – |
| External DNS | `external-dns` | – | – | X | X | X | X | no (W) | No | – | – |
| External Secrets | `external-secrets` | – | X | – | X | – | X | no (W); **mgmt pre-installed since 2.17, not disableable** (T) | No | – | – |
| Fluent Bit | `fluent-bit` | – | – | X | X | X | X | no (W) | No | – | – |
| Flux | `kommander-flux` | X | X | X | X | X | X | yes (M) | **Yes** | – | – |
| Gatekeeper | `gatekeeper` | X | X | X | X | X | X | yes (W) | No | – | – |
| Gateway API CRDs | `gateway-api-crds` | X | X | X | X | X | X | n/s | **Yes** | – | – |
| Git Operator | `git-operator` | X | – | X | – | X | – | yes (I) | No | – | – |
| Grafana Logging | `grafana-logging` | – | – | X | X | X | X | no (W) | No | – | grafana-loki |
| Grafana Loki | `grafana-loki` | – | – | X | X | X | X | no (W) | No | – | rook-ceph-cluster |
| Harbor | `harbor` | – | – | X | – | X | – | no (W/T) | No | cloudnative-pg | – |
| Istio Helm | `istio-helm` | – | – | X | X | X | X | no (W) | No | kube-prometheus-stack | – |
| Jaeger | `jaeger` | – | – | X | X | X | X | no (W) | No | istio | – |
| Karma | `karma` | – | – | – | – | X | – | yes (M) | **Yes** | karma-traefik | – |
| Kiali | `kiali` | – | – | X | X | X | X | no (W) | No | istio | jaeger |
| Knative | `knative` | – | – | X | X | X | X | no (W) | No | istio | – |
| Kube OIDC Proxy | `kube-oidc-proxy` | X | X | X | X | X | X | yes (W) | No | – | cert-manager, traefik |
| Kube Prometheus Stack | `kube-prometheus-stack` | – | – | X | X | X | X | yes (W) | No | – | – |
| OpenCost | `opencost` | – | – | – | – | X | X | yes (W) | No | – | kube-prometheus-stack |
| Kubernetes Dashboard | `kubernetes-dashboard` | – | – | X | X | X | X | yes (W); legacy, Headlamp on 2.19 (T) | No | – | traefik |
| Kubetunnel | `kubetunnel` | – | – | X | X | X | X | yes (M) | **Yes** | – | – |
| Logging Operator | `logging-operator` | – | – | X | X | X | X | no (W) | No | – | – |
| NKP Insights | `nkp-insights` | – | – | – | – | X | X | no (T) | No | kube-prometheus-stack, cloudnative-pg | – |
| NKP Insights Management | `nkp-insights-management` | – | – | – | – | X | – | yes (I) | No | kubefed | – |
| NKP Pulse Management | `nkp-pulse-management` | X | – | X | – | X | – | n/s | **Yes** | – | – |
| NKP Pulse Workspace | `nkp-pulse-workspace` | – | X | – | X | – | X | n/s | **Yes** | – | – |
| NVIDIA GPU Operator | `nvidia-gpu-operator` | – | – | X | X | X | X | no (W) | No | – | – |
| AMD GPU Operator | `amd-gpu-operator` | – | – | X | X | X | X | no | No | – | amd-gpu-operator (sic) |
| AMD KMM Operator | `amd-kmm-operator` | – | – | X | X | X | X | no | No | – | – |
| Project Grafana Logging | `project-grafana-logging` | – | – | – | – | X | X | no (T, p.371) | No | – | project-grafana-loki |
| Project Grafana Loki | `project-grafana-loki` | – | – | – | – | X | X | no (T, p.371) | No | – | project-logging, grafana-loki, logging-operator |
| Project Logging | `project-logging` | – | – | – | – | X | X | no (T, p.371) | No | – | logging-operator |
| Prometheus Adapter | `prometheus-adapter` | – | – | X | X | X | X | yes (W) | No | kube-prometheus-stack | – |
| Reloader | `reloader` | X | X | X | X | X | X | yes (W) | No | – | – |
| Rook Ceph | `rook-ceph` | – | – | X | X | X | X | yes (W) | No | – | – |
| Rook Ceph Cluster | `rook-ceph-cluster` | – | – | X | X | X | X | yes (W) | No | – | rook-ceph |
| Thanos | `thanos` | – | – | – | – | X | – | yes (M) | **Yes** | – | – |
| Traefik | `traefik` | X | X | X | X | X | X | yes (W) | No | – | cert-manager, reloader |
| Traefik ForwardAuth | `traefik-forward-auth` | – | X | – | X | – | X | yes (W) | No | traefik | – |
| Traefik Forward Auth Mgmt | `traefik-forward-auth-mgmt` | X | – | X | – | X | – | yes (M) | No | dex, kommander, traefik | – |
| Velero | `velero` | – | – | X | X | X | X | no (W) | No | – | rook-ceph-cluster |
| vGPU Token Operator | `vgpu-token-operator` | – | – | X | X | X | X | no | No | – | – |
| **Headlamp** *(not in Table 22; new in 2.19, p.313)* | `headlamp` | – | – | X | X | X | X | **yes**, fresh 2.19 installs only (T) | – | – | – |

**Not in Table 22 but real platform apps** (installer `apps:` block, mgmt requirement table, or docs): `kommander`, `kommander-ui`, `kommander-appmanagement`, `kommander-flux`, `kubefed`, `centralized-opencost`, `git-operator`, `ai-navigator-info-api` (part of AI Navigator), `headlamp`. `[pdf p.699-703, 954-955, 960]`

**Foundational apps** (must be enabled or nothing else works): `kommander-flux`, `reloader`, `traefik`. `[pdf p.299]`

**PriorityClasses** (NKP-owned): `nkp-critical-priority` = 100002000 (highest; Kommander, Flux, Traefik, Dex, kubefed, rooks…), `nkp-high-priority` = 100001000 (Prometheus adapter, reloader, external-dns, GPU operator…); platform default `system-cluster-critical` = 2000000000 for cert-manager, gatekeeper, rook-ceph, nvidia-gpu-operator. Override per app by setting `priorityClassName` in the AppDeployment override ConfigMap. `[pdf p.316, 698-704]`

**Default-deployed per cluster type** (from p.700-703 "Deployed by Default"):
- Management cluster: centralized-grafana, centralized-opencost, dex, dex-k8s-authenticator, karma, kommander, kommander-appmanagement, kommander-flux, kommander-ui, kubefed, kubetunnel, thanos, traefik-forward-auth-mgmt.
- Workspace/attached cluster: cert-manager, gatekeeper, kube-oidc-proxy, kube-prometheus-stack, opencost, kubernetes-dashboard, prometheus-adapter, reloader, rook-ceph, rook-ceph-cluster, traefik, traefik-forward-auth. **Note**: NKP automatically manages `traefik-forward-auth` and `kube-oidc-proxy` on attach and does **not** show them in the UI.

---

## Namespace quick map (management cluster unless noted)

| Namespace | What lives there |
|---|---|
| `kommander` | Kommander controller (`kommander-cm`), `kommander-appmanagement`, `kommander-ui`, `kommander-ca` certs, `nkp-credentials`, `kommander-vars` ConfigMap, `apps-kommander` Kustomization, the management workspace objects |
| `kommander-flux` | Flux controllers (`source-controller`, `kustomize-controller`, `helm-controller`), `GitRepository/management`, `gitserver-ca` secret (also on workload clusters, `[field]`) |
| `kube-federation-system` | kubefed controllers |
| `git-operator-system` | internal git server for the management repository |
| `ncr-system` | Harbor (secret `harbor-admin-password`) |
| `nai-system` | Nutanix Enterprise AI (+ pull secret `nai-regcred`) |
| `envoy-gateway-system` | NAI Envoy Gateway (pre-existing on the cluster) |
| `kubetunnel` | Kubetunnel server/agent pods, `TunnelConnector` |
| `ntnx-system` | NDK (catalog app), CSI/CSI-secret conventions |
| `capx-system` | CAPX (Nutanix CAPI provider) credentials — different area, listed for orientation |
| `kommander-workspace` | namespace of the reserved "Management Cluster Workspace" |
| `workspace-<suffix>` / `<ws>` | one namespace per workspace; contains `AppDeployment`s and `KommanderCluster`s |
| `<project-ns>` | project namespace: `App`, `AppDeployment`, `GitRepository`, `Kustomization`, `GitopsRepository` |
| `headlamp-viewer` | example only — dashboard access namespace created by the operator |

## Relationships

- `nkp install kommander` → creates ns `kommander` + `kommander-flux` → installs Flux from `kommander-applications` → creates `kommander-ca` (cert-manager ClusterIssuer/Certificate) → ChartMuseum (air-gapped only) + HelmRepositories → `apps-kommander` Kustomization → commits manifests to the **internal git repo (git-operator)** → `kommander` + `kommander-appmanagement` HelmReleases → core + optional `AppDeployment`s → catalog `GitRepository` loader. `[pdf p.1069-1070]`
- `AppDeployment` → `ClusterApp` (platform) or `App` (catalog/custom) → Flux `Kustomization` → `HelmRelease` → `HelmChart`. `[pdf p.271, 1059]`
- Kommander controller (`kommander-cm`, ns `kommander`) → `Workspaces`, `Projects`, `KommanderCluster`s → federation through **kubefed** (`kube-federation-system`) → federated namespace per Project on every member cluster.
- `KommanderCluster` → one per cluster per workspace; its labels (`kommander.d2iq.io/cluster-name`) are what `AppDeployment.spec.clusterSelector` matches.
- `NKPCluster` → owns CAPI `Cluster` + `KommanderCluster`; admission webhook blocks Flux/kubectl from touching `CAPICluster.spec.topology`; therefore GitOps repos must manage `NKPCluster`, with `prune: false` during migration.
- `kubetunnel` (`TunnelConnector`) → `KommanderCluster.spec.clusterTunnelConnectorRef` → attach cluster that has no reachable API server.
- `git-operator` (internal git) ← Flux `GitRepository` `kommander-flux/management`; workload clusters authenticate with secret `kommander-flux/gitserver-ca`. `[field: NKP - Flux.md]`
- `DefaultCatalogGitRepository` controller → propagates catalog `GitRepository`/`OCIRepository` objects (matched by labels) from `kommander-workspace` to all workspaces/projects. `[pdf p.1069, 357]`
- Catalog app → `OCIRepository` (OCI artifact built by `nkp create catalog-bundle`) → Flux Kustomization → `HelmRelease` → chart (ocirepository in `helmrelease/helmrelease.yaml`) — 2.19 uses **OCI**, not git-HelmRepository, for the NKP/partner/product catalogs.
- Harbor → needs `cloudnative-pg` + S3 (COSI/Nutanix Objects or `rook-ceph-cluster`); Harbor then feeds the cluster `imageRegistry`/`registry mirror` config used by every platform app and by `kommander-flux` chart pulls.
- NKP Insights Management → requires `kubefed` (aggregates alerts from member clusters).
- Karma → requires `karma-traefik`; centralized Grafana/Thanos/OpenCost → Ultimate only, management cluster.
- AI Catalog apps → require NVIDIA/AMD GPU operator + (for NAI) KServe, Envoy Gateway, OpenTelemetry Operator, LeaderWorkerSet, CloudNativePG, CloudNative PG-backed database, `nai-system` pull secret.
- Headlamp → replaces `kubernetes-dashboard` on fresh 2.19; RBAC via service-account token; SSO from NKP.
- Konnector (`konnectorAgent` add-on) → Prism Central registration; **unrelated** to Kommander attach (that is kubetunnel / kubeconfig attach).
- Field pattern for "cluster gitops" (managing Workspaces + clusters from one repo): a `GitRepository` in ns `kommander` feeding two Flux `Kustomization`s — `<ws>-workspace` (`path: ./kustomizations/workspaces`, annotation `kustomize.toolkit.fluxcd.io/reconcile-order: "1"`) then `<ws>-cluster` (`path: ./kustomizations/clusters`, `"2"`, `dependsOn` the first). Ordering matters because workspace/cluster objects must exist before their AppDeployments. `[field: everything-nkp/cluster-gitops]`
- Project CD secrets support three auth modes with different keys: HTTPS (`username`,`password`), HTTPS self-signed (`username`,`password`,`caFile`), SSH (`identity`,`identity.pub`,`known_hosts`). SSH URLs must be `ssh://user@host:port/org/repo` (no SCP syntax). Multi-tenant rule: manifests must be namespace-scoped only (no Namespace/ClusterRole/ClusterRoleBinding). `[pdf p.394, 396]`

---

## Version deltas (2.16 → 2.19, only what the sources show)

- **2.17**: External Secrets Operator (ESO) **pre-installed by default on the management cluster** (cannot be disabled; `createPushSecrets`/`processPushSecrets` must stay `true`); ESO also available as a workload-cluster platform app. WAS: platform app; NOW: mandatory on mgmt. `[pdf p.311]`
- **2.17**: NDK installable directly from the NKP UI (replaces most `nkp create catalog` CLI use). NDK added to the NKP product catalog; air-gapped NDK path uses `nkp create catalog-bundle --airgapped`. `[pdf p.339-340]`
- **2.17**: Kubecost → **OpenCost** (Kubecost only appears as legacy leftovers in the 2.19 doc). `[pdf p.295, 981]`
- **2.16**: NAI accessible from the NKP UI; `nkp create catalog` CLI deprecated. `[pdf p.329]`
- **2.19**: **Headlamp replaces Kubernetes Dashboard** for new deployments (upstream Dashboard deprecated); enabled by default on **fresh** installs only, Pro/Ultimate; Dashboard still listed. `[pdf p.313]`
- **2.19**: **`NKPCluster` CRD** (`clusters.nkp.nutanix.com/v1alpha1`) + admission webhook unify CAPI `Cluster` + `KommanderCluster`; GitOps-managed workload clusters must migrate repo from `CAPICluster` to `NKPCluster`; `prune: false` required during migration; GitOps upgrades produce **no `UpgradePlan`**. `[pdf p.1035-1041]`
- **2.19**: AMD GPU Operator + AMD KMM Operator added to the platform app list; vGPU Token Operator present (NVIDIA vGPU licensing). `[pdf p.296-297, 308-309]`
- **2.19**: NKP Insights / NKP Insights Management and Pulse are listed as platform apps with license gates; AI Navigator (App/Cluster Info Agent/RAG) on Pro **and** Ultimate management clusters. `[pdf p.295-296, 307, 310]`
- **Bundle rename**: older releases shipped `nkp-catalog-applications-image-bundle-<ver>.tar`; 2.19 air-gapped bundle contains `kommander-image-bundle`, `konvoy-image-bundle`, `nutanix-product-catalog-<ver>-airgapped.tar` (Nutanix infra only, NDK images only) and `nkp-release-specs-<ver>.tar`. `[pdf p.945-946, 238-242; field: NKP Notes.md]`
- **Catalog CLI rename**: `nkp create catalog --url --secret --branch --workspace` (≤2.13) → `nkp create catalog-collection` / `nkp create catalog-application` with `oci://` URLs (2.19). `[field: nai-product-catalog/README; pdf p.357]`
- **Catalog repo layout**: `helm-repositories/` + `services/<app>/<ver>/` (Carvel/Kustomize era) → `applications/<app>/<ver>/` with `OCIRepository` + `HelmRelease` + `metadata.yaml` (2.19). Old-layout repos still exist in the field. `[pdf p.355-356; field: NKP - Creating a Custom App Catalog Item.md]`
- **Cilium CNI** for Nutanix/EKS providers, Calico for others (context for `cilium-hubble-relay-traefik`), unchanged in 2.19. `[pdf p.20]`

## Gaps / open questions

- **Exact application versions in 2.19**: the PDF never lists them; it always says "see NKP Release Notes on the Nutanix Support Portal". Only two version strings appear in examples: `kiali-2.24.0`, `kube-prometheus-stack-82.13.6`, plus `project-grafana-logging-11.3.3`, `project-grafana-loki-v3-3.6.7`, `project-logging-1.1.0`, `kube-oidc-proxy-0.3.2`. Real per-app versions must be read from the portal release notes or from `kubectl get clusterapps -A`. **UNKNOWN.**
- **Flux upstream version** shipped as `kommander-flux` in 2.19: **UNKNOWN** from PDF.
- Whether `github.com/mesosphere/kommander-applications` is publicly readable today: **UNVERIFIED** (PDF cites `github.com/mesosphere/kommander-applications/tree/main/common/helm-repositories`). Same for `github.com/mesosphere/kommander`.
- **Table 22 is stale vs p.313/p.699**: it has no `headlamp`, no `centralized-opencost`, no `kommander`, `kommander-ui`, `kommander-appmanagement`, `kubefed`. Do not treat Table 22 as the complete app list.
- Table 22 marks AI Navigator for **Pro** and Ultimate management clusters; the AI Navigator chapter says "included with Pro and Ultimate" — consistent, but some portal pages describe it as Ultimate-only. Prefer PDF.
- "Internal: Yes" column meaning is not defined in the PDF (likely shipped/owned by Nutanix rather than upstream Helm chart). Flagged as an assumption.
- `amd-gpu-operator` listed as its own optional dependency — almost certainly a doc bug (should be `amd-kmm-operator`). `[pdf p.309]`
- Pro vs Ultimate cluster-scoped app configuration: cluster-scoped enablement + `clusterConfigOverrides` is **Ultimate-only**; Pro can customize but only for a single cluster in a workspace. `[pdf p.321, 1062]`
- Whether `kubefed` will be replaced in a later release (KubeFed upstream is archived/stale) — no statement found. Open question for the skills author.
- Field-note claim not re-verified in the PDF: Kommander UI banner/footer/logo upload is under "Operations" (p.269-271) and coexists with the new UI — verify whether Pro-only.
