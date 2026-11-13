# Upgrade with GitOps-managed workload clusters

Use this file from skill `nkp-upgrade` when Flux applies the CAPI `Cluster` objects of ClusterClass workload clusters from a Git repository. NKP supports GitOps only for workload clusters. [pdf p.1016] The order [pdf p.1037]:

1. Turn off Flux pruning (F1 below). **Before** the Kommander upgrade.
2. Upgrade Kommander (skill `nkp-upgrade`, step 4).
3. Upgrade the management cluster (skill `nkp-upgrade`, step 5).
4. Move the Git repository to NKPCluster objects. This also upgrades each workload cluster (F3 below).

Why: the Kommander upgrade adopts each ClusterClass CAPI `Cluster` into an NKPCluster. From then on, a webhook rejects every change of `Cluster.spec.topology`, also from Flux. [pdf p.1038-1039] If pruning is on and the `Cluster` file leaves Git, Flux **deletes the live workload cluster**. [pdf p.1037, p.1048]

GitOps upgrades make no UpgradePlan, so the NKP UI does not show their progress. [pdf p.1037]

## F1. Turn off Flux pruning

Ask the user for the Flux Kustomization that applies the cluster files, and its namespace. List them:

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" get kustomizations -A -o custom-columns='NAMESPACE:.metadata.namespace,NAME:.metadata.name,PRUNE:.spec.prune,SOURCE:.spec.sourceRef.name'
```

PRUNE `false`: skip this step. [pdf p.1037] The `kommander` Kustomizations are NKP objects. Do not change them. [live 2.19.0]

- A parent Kustomization applies this Kustomization from Git: the user sets `spec.prune: false` in Git, commits, and pushes. Then wait for Flux. [pdf p.1037]
- The user applied it by hand: patch it. Set `ks` and `ns` first.

```bash
# CHANGES  (sets prune to false on one Flux Kustomization)
source ~/nkp-site.env 2>/dev/null
ks=''; ns=''
: "${ks:?}" "${ns:?}"
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$ns" patch kustomization "$ks" --type merge -p '{"spec":{"prune":false}}'
```

Done when: this block prints `false`. [pdf p.1037]

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
ks=''; ns=''
: "${ks:?}" "${ns:?}"
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$ns" get kustomization "$ks" -o jsonpath='{.spec.prune}{"\n"}'
```

After the Kommander upgrade, Flux shows the webhook error "CAPI Cluster topology spec is managed by NKPCluster" for the workload clusters. This is expected until F3. [pdf p.1039]

## F2. Management cluster

Do skill `nkp-upgrade`, step 5. This upgrades only the management cluster. The workload clusters upgrade in F3. [pdf p.1039]

## F3. Move the repository to NKPCluster and upgrade

For each workload cluster: make the NKPCluster file with the upgrade dry run, check it, and put it in Git in place of the `Cluster` file. One commit upgrades the ClusterClass, Kubernetes, and the platform apps. [pdf p.1041]

1. Make the file. Use the cluster env file of the workload cluster and the image of skill `nkp-upgrade`, step 3. The guide removes `.spec.kommanderCluster.labels` with `yq`. [pdf p.1042] The bundle has no `yq`. [live 2.19.0] First check it:

```bash
# READ-ONLY
command -v yq && yq --version
```

   - No `yq`: stop and tell the user. The Python `yq` (its version line has no "mikefarah") needs `yq -y` in the block below.
   - Pools with different images: as in [clusterclass.md](clusterclass.md), C1, the block uses `CP_VM_IMAGE` and `WORKER_VM_IMAGES`.

```bash
# CHANGES  (writes the upgraded NKPCluster object to a local file; upgrades nothing)
source ~/nkp-<cluster>.env 2>/dev/null
if [ -n "$WORKER_VM_IMAGES" ]; then img=(--control-plane-vm-image "${CP_VM_IMAGE:?}" --worker-vm-images "$WORKER_VM_IMAGES"); else img=(--vm-image "${VM_IMAGE:?}"); fi
umask 077 && nkp upgrade cluster nutanix --cluster-name "$CLUSTER_NAME" --namespace "$WORKSPACE_NS" "${img[@]}" --kubeconfig "$MGMT_KUBECONFIG" --dry-run -o yaml 2>/dev/null | yq 'del(.spec.kommanderCluster.labels)' > "$PWD/$CLUSTER_NAME-nkpcluster-upgrade.yaml"
```

2. Check the file [pdf p.1042]:

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
grep -n -E '^kind:|classRef:|^ *name: nkp-|^ *version:|image:' "$PWD/$CLUSTER_NAME-nkpcluster-upgrade.yaml"
```

   - `kind: NKPCluster`, `spec.capiCluster.topology.classRef.name` with the new ClusterClass, `spec.capiCluster.topology.version` with the new Kubernetes version, the new image names, and `spec.version` with the target NKP version.
   - Keep `metadata.name`, `metadata.namespace`, `metadata.labels`, and `metadata.annotations`. [pdf p.1042]
   - UNKNOWN (P-24): whether the dry run of an adopted GitOps cluster gives one NKPCluster object or more objects (Secrets). Find out with: `source ~/nkp-<cluster>.env 2>/dev/null && grep -c '^kind:' "$PWD/$CLUSTER_NAME-nkpcluster-upgrade.yaml"`. If it is more than 1, stop: never put a Secret in Git.

3. The user replaces the `Cluster` file in the repository (for example `clusters/<namespace>_<cluster>/cluster.yaml`) with this file, then commits and pushes. The agent does not push to Git. [pdf p.1042]

4. Flux applies it. The NKPCluster controller upgrades the platform apps, updates the topology, rolls the control plane, then the workers. [pdf p.1041-1043] Watch:

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get nkpcluster "$CLUSTER_NAME" -o jsonpath='{.status.phase}{"\n"}'
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get machines -l "cluster.x-k8s.io/cluster-name=$CLUSTER_NAME"
kubectl --kubeconfig "$MGMT_KUBECONFIG" get kustomizations -A | awk 'NR==1 || $4!="True"'
```

Done when: PHASE goes from `Reconciling...` to `Reconciled`, the Kustomization of the cluster is ready [pdf p.1046], and skill `nkp-upgrade`, step 7 passes.

5. Optional: the user turns pruning on again (`prune: true`). [pdf p.1043]

## Failures

| Symptom | Cause | Action |
|---|---|---|
| Flux: `webhook.nkpcluster.child.kommander.mesosphere.io` denied, "CAPI Cluster topology spec is managed by NKPCluster" | Git still has the `Cluster` object. [pdf p.1048] | F3. |
| The CAPI `Cluster` was deleted during the move | Pruning was on. [pdf p.1048] | Stop. Do not apply anything. Use skill `nkp-troubleshooting`. |
| NKPCluster stays `Reconciling` | Missing credential Secrets, or an image that is not in Prism Central. [pdf p.1048] | [stopped.md](stopped.md), S3. |
