# Non-ClusterClass upgrade (AWS, Azure, GCP, vSphere, pre-provisioned)

Use this file from skill `nkp-upgrade`, steps 5 and 6. A non-ClusterClass cluster has no value in the CLUSTERCLASS column (step 1). The upgrade has separate commands: the platform apps (workload clusters only), the core addons, the control plane, then each node pool. [pdf p.1025]

Site variables of this file (rule 4; same use as the rules table):

| File | Site variables |
|---|---|
| `~/nkp-site.env` | `TARGET_K8S_VERSION` `AWS_AMI_ID` `AZURE_IMAGE_ID` `GCP_IMAGE` `VSPHERE_TEMPLATE` |

- `TARGET_K8S_VERSION`: the Kubernetes version of the target NKP version, with a `v`, for example `v1.36.2`. The target CLI prints it: `nkp upgrade cluster nutanix --help | head -1`. [live 2.19.0]
- The image of the target Kubernetes version, built with NIB and the target CLI (skill `nkp-airgap`, OS images and NIB) [pdf p.1028]: `AWS_AMI_ID` (AMI ID), `AZURE_IMAGE_ID` (Compute Gallery image ID), `GCP_IMAGE` (`projects/<project>/global/images/<image>`), `VSPHERE_TEMPLATE` (vSphere template). Pre-provisioned hosts need no image: upload the artifacts first (skill `nkp-upgrade`, step 3). Append the **new** value (rule 4).
- FIPS clusters: the version has the suffix `+fips.0` (for example `v1.36.2+fips.0`), and the image is a FIPS image. [pdf p.1029]
- Attached clusters: the tool that made them upgrades them. [pdf p.1035] AKS: the AKS steps are not in the skills.

## N1. Select the cluster and the provider

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get nkpcluster "$CLUSTER_NAME" -o custom-columns='CAPI:.status.capiClusterRef.name,CAPI_NS:.status.capiClusterRef.namespace,K8S:.status.kubernetesVersion'
kubectl --kubeconfig "$MGMT_KUBECONFIG" get workspaces -o custom-columns='WORKSPACE:.metadata.name,NAMESPACE:.status.namespaceRef.name'
nkp get nodepools --cluster-name "$CLUSTER_NAME" --namespace "$WORKSPACE_NS" --kubeconfig "$MGMT_KUBECONFIG"
```

- Ask the user for `infra`: `aws`, `azure`, `gcp`, `vsphere`, or `preprovisioned`. [live 2.19.0]
- Use CAPI and CAPI_NS as `capi` and `capins` in the blocks below. From 2.18, the management cluster is in namespace `kommander`. Always give the namespace: the CLI default `default` is wrong. [pdf p.1030][live 2.19.0]
- `ws`: the WORKSPACE whose NAMESPACE is `WORKSPACE_NS`. `nkp upgrade platform-apps --workspace` takes the workspace **name**, not the namespace. [live 2.19.0]
- UNKNOWN (P-14): the namespace of a pre-provisioned management cluster. Find out with: `source ~/nkp-site.env 2>/dev/null && kubectl --kubeconfig "$MGMT_KUBECONFIG" get clusters -A`.

Done when: you have `infra`, `capi`, `capins`, the pool names, and (workload cluster) `ws`.

## N2. Platform apps (workload cluster only)

The platform apps of the management cluster were upgraded by `nkp upgrade kommander`. [pdf p.1017] For a workload cluster, upgrade them first. No other upgrade or lifecycle job may run on the cluster. Check the app overrides for the new version (skill `nkp-platform-apps-gitops`). [pdf p.1031]

The PDF uses `--namespace`. The 2.19.0 CLI has only `--workspace` (mandatory) for this command. [pdf p.1032][live 2.19.0] The dry run makes no change. It prints the UpgradePlan that it would create. [live 2.19.0]

```bash
# CHANGES  (server dry run only: prints the UpgradePlan; creates nothing)
source ~/nkp-<cluster>.env 2>/dev/null
ws=''
: "${ws:?}"
nkp upgrade platform-apps --cluster-name "$CLUSTER_NAME" --workspace "$ws" --version "$NKP_TARGET_VERSION" --kubeconfig "$MGMT_KUBECONFIG" --dry-run
```

Error "no Workspace with this name": `ws` is a namespace. Use the WORKSPACE column of N1. [live 2.19.0]

```bash
# CHANGES  (creates an UpgradePlan; upgrades the platform apps of one workload cluster)
source ~/nkp-<cluster>.env 2>/dev/null
ws=''
: "${ws:?}"
( set -o pipefail; nkp upgrade platform-apps --cluster-name "$CLUSTER_NAME" --workspace "$ws" --version "$NKP_TARGET_VERSION" --kubeconfig "$MGMT_KUBECONFIG" 2>&1 | tee -a "$HOME/nkp-upgrade-$CLUSTER_NAME.log" ); echo "exit: $?"
```

Done when: `exit: 0`, and the HelmRelease list of step 7 (last line) has only the header line.

## N3. Core addons

The addons are the CSI, the CNI, the cluster autoscaler, and Node Feature Discovery. NKP replaces the global ClusterResourceSets with one set for each cluster. [pdf p.1026] Changes that the user made to a ClusterResourceSet are lost. [pdf p.1027] Ask the user first. The dry run writes the new objects to a file; the guide re-applies the custom changes from it after the upgrade. [pdf p.1027]

```bash
# CHANGES  (writes the new addon objects to a local file; changes nothing in the cluster)
source ~/nkp-<cluster>.env 2>/dev/null
infra=''; capi=''; capins=''
: "${infra:?}" "${capi:?}" "${capins:?}"
umask 077 && nkp upgrade addons "$infra" --cluster-name "$capi" --namespace "$capins" --kubeconfig "$MGMT_KUBECONFIG" --dry-run -o yaml > "$PWD/$CLUSTER_NAME-addons-dryrun.yaml"
grep -c '^kind:' "$PWD/$CLUSTER_NAME-addons-dryrun.yaml"
```

```bash
# CHANGES  (upgrades the core addons of one cluster; replaces its ClusterResourceSets)
source ~/nkp-site.env 2>/dev/null
infra=''; capi=''; capins=''
: "${infra:?}" "${capi:?}" "${capins:?}"
nkp upgrade addons "$infra" --cluster-name "$capi" --namespace "$capins" --kubeconfig "$MGMT_KUBECONFIG"
```

Done when: each line of the output ends with `upgraded`. [pdf p.1027]

## N4. Control plane

The image flags for each provider [pdf p.1028-1030][live 2.19.0]:

| infra | Image flag | Also |
|---|---|---|
| `aws` | `--ami "$AWS_AMI_ID"` | These blocks need `AWS_AMI_ID`. An AMI lookup with `--ami-owner`, `--ami-base-os`, `--ami-format` is not in the skills (see `--help`). |
| `azure` | `--compute-gallery-id "$AZURE_IMAGE_ID"` | Created with `--plan-offer`, `--plan-publisher`, `--plan-sku`: give them again in `extra`. |
| `gcp` | `--image "$GCP_IMAGE"` | — |
| `vsphere` | `--vm-template "$VSPHERE_TEMPLATE"` | — |
| `preprovisioned` | none | The hosts have the new artifacts. |

`extra`: the flags from the Also column, with the values that the user gives, for example `extra=(--plan-sku 'value')`. Else keep `extra=()`.

The plan for the user: "NKP replaces the control-plane nodes one at a time". Wait for "yes". Default timeout 30m. [live 2.19.0]

```bash
# CHANGES  (upgrades Kubernetes on the control plane; replaces the control-plane nodes)
source ~/nkp-site.env 2>/dev/null
infra=''; capi=''; capins=''; extra=()
: "${infra:?}" "${capi:?}" "${capins:?}" "${TARGET_K8S_VERSION:?}"
case "$infra" in aws) img=(--ami "${AWS_AMI_ID:?}");; azure) img=(--compute-gallery-id "${AZURE_IMAGE_ID:?}");; gcp) img=(--image "${GCP_IMAGE:?}");; vsphere) img=(--vm-template "${VSPHERE_TEMPLATE:?}");; *) img=();; esac
nkp update controlplane "$infra" --cluster-name "$capi" --namespace "$capins" --kubernetes-version "$TARGET_K8S_VERSION" "${img[@]}" "${extra[@]}" --kubeconfig "$MGMT_KUBECONFIG"
```

"timed out waiting for the condition": do not run it again at once. Check the control-plane machine versions first [pdf p.1029]:

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
capi=''; capins=''
: "${capi:?}" "${capins:?}"
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$capins" get machines -l "cluster.x-k8s.io/cluster-name=$capi" -o wide
```

Done when: all control-plane machines are `Running` with `TARGET_K8S_VERSION`.

## N5. Node pools

Do each pool from N1, one at a time. NKP drains the old nodes and makes new ones. Pod Disruption Budgets keep critical apps up. [pdf p.1030] Same image flags as N4.

```bash
# CHANGES  (upgrades Kubernetes on one node pool; replaces its nodes)
source ~/nkp-site.env 2>/dev/null
infra=''; capi=''; capins=''; pool=''; extra=()
: "${infra:?}" "${capi:?}" "${capins:?}" "${pool:?}" "${TARGET_K8S_VERSION:?}"
case "$infra" in aws) img=(--ami "${AWS_AMI_ID:?}");; azure) img=(--compute-gallery-id "${AZURE_IMAGE_ID:?}");; gcp) img=(--image "${GCP_IMAGE:?}");; vsphere) img=(--vm-template "${VSPHERE_TEMPLATE:?}");; *) img=();; esac
nkp update nodepool "$infra" "$pool" --cluster-name "$capi" --namespace "$capins" --kubernetes-version "$TARGET_K8S_VERSION" "${img[@]}" "${extra[@]}" --kubeconfig "$MGMT_KUBECONFIG"
```

Done when: `nkp get nodepools` (N1) shows the target version for every pool, then skill `nkp-upgrade`, step 7 passes.

## Order

- **Management cluster:** N1, N3, N4, N5. [pdf p.1025-1031]
- **Workload cluster:** N1, N2, N3, N4, N5. [pdf p.1031-1035]
