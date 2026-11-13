# ClusterClass upgrade (AHV, EKS, Metal)

Use this file from skill `nkp-upgrade`, steps 5 and 6. A ClusterClass cluster has a value in the CLUSTERCLASS column (step 1).

One command upgrades the cluster: the CAPI objects, the ClusterClass, the CNI, the CSI driver, the control plane, and the worker pools. [pdf p.1018-1021] On a workload cluster, the same command upgrades the platform apps first. [pdf p.1023]

Before you start: Kommander is upgraded (step 4). For a workload cluster, the management cluster is upgraded too (step 5). [pdf p.1022] The gates of step 2 pass. The cluster env file of this cluster is sourced.

## C1. Find the CAPI cluster name

The command needs the CAPI cluster name and namespace from `status.capiClusterRef` of the NKPCluster, not the NKPCluster name. They can differ on a management cluster that came from an older NKP version. [pdf p.1020]

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get nkpcluster "$CLUSTER_NAME" -o custom-columns='CAPI:.status.capiClusterRef.name,CAPI_NS:.status.capiClusterRef.namespace,K8S:.status.kubernetesVersion,PROVIDER:.metadata.labels.cluster\.x-k8s\.io/provider'
nkp get nodepools --cluster-name "$CLUSTER_NAME" --namespace "$WORKSPACE_NS" --kubeconfig "$MGMT_KUBECONFIG"
kubectl --kubeconfig "$MGMT_KUBECONFIG" get clusters.cluster.x-k8s.io -A
kubectl --kubeconfig "$MGMT_KUBECONFIG" get clusters.cluster.x-k8s.io -A -o custom-columns='NAMESPACE:.metadata.namespace,NAME:.metadata.name,CONCURRENCY:.metadata.annotations.topology\.cluster\.x-k8s\.io/upgrade-concurrency'
```

- The CLUSTERCLASS prefix of the CAPI cluster gives `infra` for C3: `nkp-nutanix` → `nutanix`, `nkp-eks` → `eks`, `nkp-host-agent` (Metal) → `metal`. [live 2.19.0]
- Provider pre-provisioned (pre-provisioned clusters can also use `nkp-host-agent`), or a class `nkp-aws-*`: stop. `nkp upgrade cluster` has no matching `infra`. UNKNOWN (P-06): which providers make ClusterClass clusters in 2.19. Find out with: `source ~/nkp-site.env 2>/dev/null && kubectl --kubeconfig "$MGMT_KUBECONFIG" get clusters -A` (column CLUSTERCLASS).
- `nkp get nodepools` lists the pools. Do all pools use the same image? Then use `VM_IMAGE`. Else ask the user for one image for the control plane and one for **each** pool, and append `CP_VM_IMAGE` and `WORKER_VM_IMAGES` (`pool=image,pool=image`) to the cluster env file (rule 4). [pdf p.1020-1021][live 2.19.0] Ask again for these images at each upgrade: an old `WORKER_VM_IMAGES` value overrides the new `VM_IMAGE`.

Done when: you have CAPI, CAPI_NS, `infra`, and the image values.

## C2. Parallel pools (optional)

By default, NKP upgrades one worker pool at a time. The annotation `topology.cluster.x-k8s.io/upgrade-concurrency` on the cluster object sets how many pools upgrade at the same time, for example `"3"`. [pdf p.1020] The CONCURRENCY column of C1 shows the value. Empty means 1.

UNKNOWN (P-22): whether the NKPCluster controller keeps this annotation on the CAPI `Cluster`, or removes it. Find out with: `source ~/nkp-<cluster>.env 2>/dev/null && kubectl --kubeconfig "$MGMT_KUBECONFIG" get clusters.cluster.x-k8s.io -A -o custom-columns='NAME:.metadata.name,CONCURRENCY:.metadata.annotations.topology\.cluster\.x-k8s\.io/upgrade-concurrency'` some minutes after you set it.

Set `capi`, `capins` (from C1), and `n` (the number of pools). A server dry run accepted this annotation on the CAPI `Cluster`. [live 2.19.0] It does not change `spec.topology`.

```bash
# CHANGES  (sets how many worker pools of the cluster upgrade at the same time)
source ~/nkp-site.env 2>/dev/null
capi=''; capins=''; n=''
: "${capi:?}" "${capins:?}" "${n:?}"
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$capins" annotate clusters.cluster.x-k8s.io "$capi" "topology.cluster.x-k8s.io/upgrade-concurrency=$n" --overwrite
```

More pools at the same time need more free resources (one more VM for each pool). [pdf p.1020]

## C3. Dry run

Set `infra`, `capi`, and `capins` from C1. The dry run writes the objects to a local file with mode 600. Never print it: it can hold Secrets. A cluster that is already on the target version prints "already using the latest supported Kubernetes version" and an empty file. [live 2.19.0]

```bash
# CHANGES  (writes the dry-run objects to a local file; upgrades nothing)
source ~/nkp-<cluster>.env 2>/dev/null
infra=''; capi=''; capins=''
: "${infra:?}" "${capi:?}" "${capins:?}"
img=(); if [ "$infra" = nutanix ] && [ -n "$WORKER_VM_IMAGES" ]; then img=(--control-plane-vm-image "${CP_VM_IMAGE:?}" --worker-vm-images "$WORKER_VM_IMAGES"); elif [ "$infra" = nutanix ]; then img=(--vm-image "${VM_IMAGE:?}"); fi
umask 077 && nkp upgrade cluster "$infra" --cluster-name "$capi" --namespace "$capins" "${img[@]}" --kubeconfig "$MGMT_KUBECONFIG" --dry-run -o yaml > "$PWD/$CLUSTER_NAME-upgrade-dryrun.yaml"
```

Show the user only these lines:

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
grep -n -E '^kind:|^  name:|classRef:|^ *version:|image:|name: nkp-' "$PWD/$CLUSTER_NAME-upgrade-dryrun.yaml"
```

- Expect the new ClusterClass (`nkp-<infra>-v<target>`), the new Kubernetes version, and the new image names.
- The upgrade turns on the konnector-agent addon of a workload cluster. [pdf p.1047] To keep it off, the guide edits this file and applies it. [pdf p.507] This is not in the skills. Stop and tell the user.

Done when: the dry run ends without an error, and the user agrees with the shown lines.

## C4. Upgrade one cluster

The plan for the user: the cluster, the new versions from C3, and "NKP replaces every node, the control plane first, then the pools". [pdf p.1043] On a workload cluster, the platform apps upgrade first. [pdf p.1023] Wait for "yes".

- Default `--timeout` is 40m (`eks` 40m, `metal` 1h). [live 2.19.0] Each node takes some minutes. For a large cluster, ask the user for a longer value, for example `--timeout 3h`, and add it to the command.
- Metal: the OS image comes from the registry mirror. `--kubernetes-image-uri` sets it in the form `oci://<registry>/<path>/<image>:<tag>`. [live 2.19.0] For the image artifact, use skill `nkp-airgap`.
- When the agent runs the command, the output is not interactive. It shows only that the upgrade is in progress. [pdf p.1024] Use C5 to watch.

```bash
# CHANGES  (upgrades the cluster: new ClusterClass, Kubernetes, addons; replaces all nodes)
source ~/nkp-<cluster>.env 2>/dev/null
infra=''; capi=''; capins=''
: "${infra:?}" "${capi:?}" "${capins:?}"
img=(); if [ "$infra" = nutanix ] && [ -n "$WORKER_VM_IMAGES" ]; then img=(--control-plane-vm-image "${CP_VM_IMAGE:?}" --worker-vm-images "$WORKER_VM_IMAGES"); elif [ "$infra" = nutanix ]; then img=(--vm-image "${VM_IMAGE:?}"); fi
( set -o pipefail; nkp upgrade cluster "$infra" --cluster-name "$capi" --namespace "$capins" "${img[@]}" --kubeconfig "$MGMT_KUBECONFIG" 2>&1 | tee -a "$HOME/nkp-upgrade-$CLUSTER_NAME.log" ); echo "exit: $?"
```

The output shows "Waiting for ClusterClasses to be ready", "Running preflight checks", "Upgrading the cluster". [pdf p.1020] A preflight check that fails stops the upgrade before any change. Read the `Check:` and `Message:` lines, fix the cause, then run C3 and C4 again. [pdf p.1021] Never use `--skip-preflight-checks=all`.

Done when: `exit: 0`, then skill `nkp-upgrade`, step 7 passes.

## C5. Watch the upgrade

Run this block in a second terminal, or after the command returns. An UpgradePlan is the object behind UI and CLI upgrades. Its phases: `ValidatingInputs`, `UpgradingManagementPlane`, `UpgradingKommander`, `UpgradingPlatformApplications`, `UpgradingKubernetes`, `Upgraded`, `Failed`. Each step has a state `NotStarted`, `Progressing`, or `Completed`, and an `error`. [live 2.19.0]

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get upgradeplans -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.phase}{"\n"}{range .status.steps[*]}{"  "}{.name}{"\t"}{.state}{"\t"}{.error}{"\n"}{end}{end}'
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get nkpcluster "$CLUSTER_NAME"
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get machines -l "cluster.x-k8s.io/cluster-name=$CLUSTER_NAME"
```

- UNKNOWN (P-25): whether `nkp upgrade cluster` (CLI) makes an UpgradePlan, or only the UI and `nkp upgrade platform-apps` do. Find out with: `source ~/nkp-site.env 2>/dev/null && kubectl --kubeconfig "$MGMT_KUBECONFIG" get upgradeplans -A` during an upgrade. If there is no UpgradePlan, watch the NKPCluster PHASE and the machines.
- The NKPCluster PHASE is `Reconciling` during the upgrade and `Reconciled` at the end. [pdf p.1046]
- A warning that clears without action is normal while a part reconciles. A warning that stays, or an error: record the stage, the part, and the message, then go to [stopped.md](stopped.md). [pdf p.1044]
- The user can see the same progress in the NKP UI, Administration > Upgrades. A page refresh does not restart the upgrade. [pdf p.1044]
