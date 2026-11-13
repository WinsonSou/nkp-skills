# Flux and platform apps: diagnosis only

Use this file from skill `nkp-troubleshooting`. A HelmRelease, Kustomization, AppDeployment, or Flux source is not Ready. This file finds the failing link and its message. **The fix belongs to skill `nkp-platform-apps-gitops`** (app overrides, catalogs, Flux, and the HelmRelease reset). During an upgrade, use skill `nkp-upgrade` first.

## The chain [pdf p.1059][live 2.19.0]

`AppDeployment` (workspace namespace, management cluster) → `ClusterApp` (cluster-scoped catalog version) → Flux `Kustomization` → `HelmRelease` → chart source. The chart source has two forms [live 2.19.0]:

- Most apps: HelmRelease → `OCIRepository` (`spec.chartRef`), in the namespace of the HelmRelease. There is no HelmChart.
- Some apps: HelmRelease → `HelmChart` → `GitRepository` (`spec.chart.spec.sourceRef`).

| Object | Controller (namespace/Deployment) [live 2.19.0] |
|---|---|
| AppDeployment, ClusterApp, App | `kommander/kommander-appmanagement` |
| GitRepository, OCIRepository, HelmChart | `kommander-flux/source-controller` |
| Kustomization | `kommander-flux/kustomize-controller` |
| HelmRelease | `kommander-flux/helm-controller` |
| Workspace, KommanderCluster | `kommander/kommander-cm` |

- The HelmReleases of a cluster are on that cluster, in `kommander` (management cluster) or the workspace namespace. [pdf p.1047] Their sources and HelmCharts are on the same cluster. Use `"$CLUSTER_KUBECONFIG"` for all Flux kinds. Only AppDeployments are on the management cluster.
- One app can have three versions: catalog, chart, and image. [live 2.19.0] The HelmRelease message has the chart version.
- The 2.19 sources are OCI. There are no `HelmRepository` objects. [live 2.19.0]

## F1. Find the failing links

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get helmreleases -A -o custom-columns='NAMESPACE:.metadata.namespace,NAME:.metadata.name,READY:.status.conditions[?(@.type=="Ready")].status,REASON:.status.conditions[?(@.type=="Ready")].reason,SUSPEND:.spec.suspend' | grep -v -w True
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get kustomizations -A | grep -v -w True
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get ocirepositories,gitrepositories,helmcharts -A | grep -v -w True
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get appdeployments
```

- Each command prints only the header when all is Ready. [live 2.19.0]
- `SUSPEND` `true`: someone suspended the HelmRelease. Ask the user why before you continue.
- Start with the lowest link that fails: source (`OCIRepository` or `GitRepository`) → HelmChart (if any) → HelmRelease → Kustomization. A failed source makes every link above it fail.
- For a workload cluster, the management cluster has its own sources. They are not the sources of the workload cluster.

Done when: you have the lowest failing object, its namespace, and its cluster.

## F2. Read the message

`kind` is `helmrelease`, `kustomization`, `ocirepository`, `gitrepository`, `helmchart`, or `appdeployment`. Keep `where='cluster'` for every Flux kind (they are on the target cluster). Set `where='mgmt'` only for an AppDeployment.

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
kind=''; name=''; ns=''; where='cluster'; case "$where" in mgmt) kc="$MGMT_KUBECONFIG";; cluster) kc="$CLUSTER_KUBECONFIG";; *) kc='';; esac
: "${kind:?}" "${name:?}" "${ns:?}" "${kc:?}"
kubectl --kubeconfig "$kc" -n "$ns" get "$kind" "$name" -o jsonpath='{range .status.conditions[*]}{.type}={.status} {.reason}: {.message}{"\n"}{end}{.status.history[0].status}{"\n"}'
kubectl --kubeconfig "$kc" -n "$ns" get events --field-selector "involvedObject.name=$name" --sort-by=.lastTimestamp | tail -10
```

Then read the controller log for the name ([controllers.md](controllers.md), log block, Flux rows).

## F3. Message → owner

| Message text | Meaning | Owner of the fix |
|---|---|---|
| `exhausted`, `another rollback/release in progress`, `upgrade retries exhausted` | The Helm release is stuck. The guide resets it with `spec.suspend` true, then false. [pdf p.1047] | skill `nkp-platform-apps-gitops`, step 3 |
| `dependency ... is not ready` | Another HelmRelease or Kustomization must be Ready first. | do F2 on the dependency |
| `failed to pull`, `unauthorized`, `x509`, `not found` on an OCI source | The source cannot reach the registry, or the artifact is not pushed. | skill `nkp-airgap` |
| `chart ... version ... not found` during an upgrade | A field note: run the upgrade again. [field] | skill `nkp-upgrade` |
| `admission webhook "validation.gatekeeper.sh" denied`, constraint `helmrelease-must-have-sa` or `kustomization-must-have-sa` | A HelmRelease or Kustomization without a service account. [live 2.19.0] | skill `nkp-identity-security`, file `gatekeeper.md` G2 |
| `spec.topology: Forbidden: CAPI Cluster topology spec is managed by NKPCluster` | A Kustomization applies a CAPI `Cluster`. [pdf p.1048] | skill `nkp-upgrade` (GitOps migration) |
| Helm `context deadline exceeded`, pods not Ready | The app pods do not start. | rung 5 of the ladder; the app skill (step 3 of SKILL.md) |
| `values` or schema error | A bad override ConfigMap. | skill `nkp-platform-apps-gitops`, file `overrides.md` O5 |
| AppDeployment ok, no HelmRelease on the target cluster | The workspace or the cluster attach is the problem. | F4 |

## F4. Workspace and attached cluster

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" get workspaces
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get kommanderclusters
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get nkpcluster "$CLUSTER_NAME" -o jsonpath='{range .status.kommanderCluster.conditions[*]}{.type}={.status} {.reason}: {.message}{"\n"}{end}'
```

The KommanderCluster PHASE must be `Joined`. [live 2.19.0] If not, read the `kommander-cm` log ([controllers.md](controllers.md)). The fix is in skill `nkp-platform-apps-gitops`, step 4.

Done when: you have the failing object, its message, and the owner skill. Give these to the user. Then load the owner skill.
