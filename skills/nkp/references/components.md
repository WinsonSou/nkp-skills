# NKP 2.19 components, namespaces, and CRDs

Load this file for a "what is X" or "where does X run" question. Versions here are examples from one live 2.19.0 cluster. Before you give a version to the user, read it from the user's cluster (see "Find versions" in `SKILL.md`).

## Namespaces on a 2.19 management cluster [live 2.19.0]

| Namespace | What runs there |
|---|---|
| `caaph-system` | CAAPH (Cluster API add-on provider for Helm), `HelmChartProxy` controller |
| `capa-system`, `capg-system`, `capv-system`, `capz-system` | AWS, GCP, vSphere, Azure CAPI providers (installed on every management cluster) |
| `capi-system` | Cluster API core |
| `capi-kubeadm-bootstrap-system`, `capi-kubeadm-control-plane-system` | kubeadm bootstrap and control-plane providers |
| `capi-operator-system`, `capi-stack-operator`, `capi-stack-operator-installer` | CAPI operator and the Nutanix CAPI stack operator (install CAPI, providers, and CAREN as one stack) |
| `cappp-system` | pre-provisioned provider (CAPPP) |
| `capx-system` | Nutanix AHV provider (CAPX) |
| `caren-system` | CAREN runtime extension and the in-cluster addon chart registry `helm-repository` |
| `cluster-api-provider-host-agent-system` | host-agent provider (NKP Metal) |
| `cert-manager` | cert-manager |
| `cilium-secrets` | Cilium internal secrets |
| `container-object-storage-system` | COSI controller |
| `external-secrets` | External Secrets Operator |
| `git-operator-system` | internal git server that is the source of truth for Kommander |
| `kommander` | Kommander controllers, management NKPCluster, Traefik, Dex, management workspace apps |
| `kommander-default-workspace` | default workspace |
| `kommander-flux` | Flux controllers, `flux-oci-mirror` |
| `kube-federation-system` | KubeFed (runs in 2.19) |
| `kube-system` | Cilium, CoreDNS, kube-vip static pods, Nutanix CCM, Multus, snapshot controller |
| `metallb-system` | MetalLB controller and speakers |
| `node-feature-discovery` | NFD |
| `ntnx-system` | Nutanix CSI, konnector-agent (and NDK when installed) |

Pro and Ultimate apps add more namespaces when you enable them.

## Lifecycle components (Konvoy)

| Component | Name / namespace | Notes |
|---|---|---|
| Cluster API core | `capi-system` | v1.12.11 [live 2.19.0] |
| CAREN | Deployment `cluster-api-runtime-extensions-nutanix`, `caren-system` | patches `clusterConfig` / `workerConfig`, installs addons. v0.62.7 [live 2.19.0] |
| CAPX (Nutanix AHV) | `capx-system` | calls the Prism Central API. v1.10.15 [live 2.19.0] |
| CAAPH | `caaph-system` | `HelmChartProxy` name pattern `<addon>-<cluster-uid>` [live 2.19.0] |
| ClusterClass | `nkp-nutanix-v2.19.0`, `nkp-aws-v2.19.0`, `nkp-eks-v2.19.0`, `nkp-host-agent-v2.19.0` | each class is in `kommander`, `kommander-default-workspace`, and `default`. Worker class `default-worker` [live 2.19.0] |
| NKPCluster | `clusters.nkp.nutanix.com/v1alpha1` | owns `Cluster` + `KommanderCluster`. Columns: NKP VERSION, KUBERNETES VERSION, PHASE (`Reconciled`) [live 2.19.0] |
| UpgradePlan | `upgradeplans.upgrade.nkp.nutanix.com` | object behind UI upgrades [live 2.19.0] |
| kube-vip | static pod `kube-vip-<node>`, `kube-system` | control-plane VIP only. Not a service load balancer [live 2.19.0] |
| etcd | static pods on control-plane nodes | encryption at rest is on by default (`secretbox`) [live 2.19.0] |
| konnector-agent | CAREN addon, `ntnx-system` | shows the cluster in Prism Central. `--onboard-to-prism-central=false` turns it off [pdf p.724] |
| NIB | `nkp create image`, `nkp create package-bundle` | runs as a container on the operator host |

## Cluster addons from CAREN

All rows are AHV defaults seen on a live 2.19.0 cluster, except the rows with their own tag.

| Addon | Namespace | Notes |
|---|---|---|
| Cilium | `kube-system` | default CNI on AHV. kube-proxy is replaced (no kube-proxy DaemonSet) [live 2.19.0]. The guide says EKS also uses Cilium [pdf p.20]. For EKS, see the UNKNOWN line below the table. |
| Calico | `calico-system` | default CNI on the other providers [pdf p.20]. Namespace from the pre-provisioned and AKS chapters [pdf p.187]. Not installed on AHV [live 2.19.0] |
| Flow CNI | `flow-cni-system` | AHV only, opt-in [live 2.19.0: ClusterClass enum only]. Namespace from the Flow guide [portal]. Use skill `nkp-flow-cni` |
| MetalLB | `metallb-system` | service `LoadBalancer` IPs. Pool from `--kubernetes-service-load-balancer-ip-range` |
| Nutanix CCM | `kube-system` | node metadata only |
| Nutanix CSI | `ntnx-system` | default StorageClass `nutanix-volume` |
| snapshot controller | `kube-system` | VolumeSnapshotClass `nutanix-snapshot-class` |
| NFD | `node-feature-discovery` | node labels for GPU operators |
| cluster autoscaler | `kommander` (management cluster) | per node pool, with min/max annotations |
| COSI controller | `container-object-storage-system` | object storage API |
| Multus | `kube-system` | installed, idle |

UNKNOWN (P-05): the CNI on an EKS cluster. Find out with: `source ~/nkp-<cluster>.env 2>/dev/null && kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get pods -A | grep -E 'cilium|calico'`.

## Kommander components [live 2.19.0]

A row with its own tag uses that tag for the extra fact.

| Component | Namespace | Notes |
|---|---|---|
| `kommander-cm` | `kommander` | workspaces, projects, KommanderClusters |
| `kommander-ui` | `kommander` | NKP UI. Get the URL with `nkp get dashboard` (the output also has the admin password: the user runs it) |
| `kommander-appmanagement` | `kommander` | AppDeployment, ClusterApp, App (`apps.kommander.d2iq.io`) |
| `nkp-cluster-controller-manager` + webhook | `kommander` | reconciles NKPCluster |
| Flux (source, kustomize, helm, notification) | `kommander-flux` | delivers platform apps |
| git-operator | `git-operator-system` | internal git repo |
| KubeFed | `kube-federation-system` | federates Kommander RBAC. Deprecated since 2.18 [field], but it still runs in 2.19 [live 2.19.0] |

## Platform apps on every tier [pdf p.295-297]

cert-manager, Flux, Gatekeeper, Gateway API CRDs, kube-oidc-proxy, Reloader, Traefik (all clusters). Dex, dex-k8s-authenticator, git-operator, Traefik Forward Auth mgmt (management cluster). External Secrets, Traefik Forward Auth (workload clusters).

- For the Pro and Ultimate apps, see "License tiers" in `SKILL.md`. To read the tier of one app, use its ClusterApp annotation.

## Important API groups [live 2.19.0]

| Group | Kinds |
|---|---|
| `clusters.nkp.nutanix.com` | `NKPCluster` |
| `cluster.x-k8s.io` | `Cluster`, `Machine`, `MachineDeployment`, `MachineHealthCheck`, `ClusterClass` |
| `infrastructure.cluster.x-k8s.io` | `NutanixCluster`, `NutanixMachineTemplate` |
| `addons.cluster.x-k8s.io` | `HelmChartProxy`, `HelmReleaseProxy`, `ClusterResourceSet` |
| `hostagent.nutanix.com` | `Host`, `AssignedHost`, `HostSelectorPolicy` (NKP Metal) |
| `upgrade.nkp.nutanix.com` | `UpgradePlan` |
| `apps.kommander.d2iq.io` | `AppDeployment`, `ClusterApp`, `App` |
| `kommander.mesosphere.io` | `KommanderCluster`, `License`, `VirtualGroup` |
| `workspaces.kommander.mesosphere.io` | `Workspace`, `Project` |

## PriorityClasses [live 2.19.0]

NKP uses `dkp-critical-priority` (100002000) and `dkp-high-priority` (100001000). The PDF says `nkp-*`. Use the names that `kubectl get priorityclass` shows.
