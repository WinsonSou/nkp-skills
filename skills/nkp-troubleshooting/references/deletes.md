# Stuck deletes and finalizers

Use this file from skill `nkp-troubleshooting`. An object stays in `Terminating` or `Deleting`. Do D1 to D4 (READ-ONLY) first. D5 (remove a finalizer) is the last resort.

A finalizer is a name in `metadata.finalizers`. A controller does a cleanup, then removes its name. Kubernetes deletes the object only when the list is empty. When the controller cannot do the cleanup, the object waits. **The fix is to repair the cleanup, not to remove the name.** A removed finalizer skips the cleanup. Then VMs, disks, or IPs can stay in the infrastructure, and nothing tracks them.

## Finalizers in NKP 2.19.0 [live 2.19.0]

| Object | Finalizer | Controller (namespace/Deployment) | Cleanup |
|---|---|---|---|
| NKPCluster | `clusters.nkp.nutanix.com/capicluster-cleanup`, `clusters.nkp.nutanix.com/kommandercluster-cleanup` | `kommander/nkp-cluster-controller-manager` | deletes the CAPI `Cluster` and the KommanderCluster |
| KommanderCluster | 17 names (`kommander.mesosphere.io/*`, `nkp.nutanix.com/*`) | Kommander controllers in `kommander` | removes the cluster from Kommander, Flux, Dex, and the federation |
| Cluster | `cluster.cluster.x-k8s.io` | `capi-system/capi-controller-manager` | deletes the control plane, pools, and infrastructure cluster |
| KubeadmControlPlane | `kubeadm.controlplane.cluster.x-k8s.io` | `capi-kubeadm-control-plane-system/...` | deletes the control-plane machines |
| MachineDeployment | `cluster.x-k8s.io/machinedeployment`, `machinedeployment.topology.cluster.x-k8s.io` | CAPI | deletes the MachineSets |
| Machine | `machine.cluster.x-k8s.io` | CAPI | drains the node, deletes the node and the infrastructure machine |
| NutanixMachine | `infrastructure.cluster.x-k8s.io/nutanixmachine` | `capx-system/capx-controller-manager` | deletes the VM in Prism Central |
| NutanixCluster | `infrastructure.cluster.x-k8s.io/nutanixcluster` | CAPX | cleans up the cluster in Prism Central |
| HelmChartProxy | `helmchartproxy.addons.cluster.x-k8s.io` | `caaph-system/caaph-controller-manager` | uninstalls the addon chart |
| HelmRelease, Kustomization | `finalizers.fluxcd.io` | `kommander-flux` helm and kustomize controllers | uninstalls the release, deletes the applied objects |
| AppDeployment | `kommander.mesosphere.io/appdeployment` | `kommander/kommander-appmanagement` | removes the app from the clusters |
| Namespace | `kubernetes` (in `spec.finalizers`) | kube-controller-manager | deletes every object in the namespace |

Other providers have their own infrastructure finalizers (the `infrastructure.cluster.x-k8s.io/<kind>` form). For other objects, read the list with D1.

## D1. Read the stuck object

`kind` is the resource (for example `machine`, `nkpcluster`, `helmrelease`). `name` and `ns` are from the user or the ladder.

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
kind=''; name=''; ns=''; where='mgmt'; case "$where" in mgmt) kc="$MGMT_KUBECONFIG";; cluster) kc="$CLUSTER_KUBECONFIG";; *) kc='';; esac
: "${kind:?}" "${name:?}" "${ns:?}" "${kc:?}"
kubectl --kubeconfig "$kc" -n "$ns" get "$kind" "$name" -o jsonpath='deleting since: {.metadata.deletionTimestamp}{"\n"}finalizers: {.metadata.finalizers}{"\n"}owners: {range .metadata.ownerReferences[*]}{.kind}/{.name} {end}{"\n"}{range .status.conditions[?(@.status!="True")]}{.type}={.status} {.reason}: {.message}{"\n"}{end}'
```

- `where`: `mgmt` for the CAPI, NKP, and Kommander objects (they are on the management cluster). `cluster` for an object on the cluster itself (for example its HelmRelease or namespace).
- `deleting since` is empty: the object is not being deleted. This file does not apply.
- Each finalizer name tells you the controller (table above). The last condition message often names the cleanup error.

## D2. Is the controller healthy?

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" get deploy -A --no-headers -o custom-columns='NAMESPACE:.metadata.namespace,NAME:.metadata.name,READY:.status.readyReplicas,WANT:.spec.replicas' | awk '$3 != $4'
```

The command prints only the Deployments where READY is not equal to WANT. Healthy: no line. If it prints the controller of the finalizer, the cleanup cannot run. Read its log and its pod events ([controllers.md](controllers.md)). The fix is in the owner skill of that controller.

## D3. Read the cleanup error

Read the controller log for the object name ([controllers.md](controllers.md)). Typical causes:

| Stuck object | Typical cause | Owner of the fix |
|---|---|---|
| Machine (drain) | a PDB with 0 disruptions, or a volume that does not detach | [rollouts.md](rollouts.md), R6 |
| NutanixMachine | Prism Central does not answer, the credentials changed, or the VM has a lock (for example a backup or a snapshot task) | Prism Central admin; skill `nkp-install` for credentials |
| NKPCluster or Cluster | children are still deleting | do D1 on the child: Cluster → KubeadmControlPlane and MachineDeployments → Machines → NutanixMachines |
| HelmRelease, Kustomization | the target cluster does not answer, or the release uninstall fails | [flux.md](flux.md) |
| HelmChartProxy | the workload cluster API does not answer | rung 5 of the ladder |
| Namespace | an object in it has a finalizer whose controller is gone | D4 |
| Any object (the delete is refused, not stuck) | delete denied by `validatingadmissionpolicy/nkp-deletion-protection` (label `nkp.nutanix.com/deletion-protection`) | skill `nkp-identity-security` (`gatekeeper.md` G5) |

A deleted workload cluster can stay as an NKPCluster in the UI with state `Error`. [pdf p.496] Lab test 1 did not see it on 2.19.0: the NKPCluster was gone 82 s after the delete. [live 2.19.0] That case is in skill `nkp-cluster-lifecycle` (its file `delete.md`, section D3). Use it first.

## D4. Namespace stuck in Terminating

List what is still in the namespace. Set `where` as in D1:

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
ns=''; where='mgmt'; case "$where" in mgmt) kc="$MGMT_KUBECONFIG";; cluster) kc="$CLUSTER_KUBECONFIG";; *) kc='';; esac
: "${ns:?}" "${kc:?}"
kubectl --kubeconfig "$kc" get ns "$ns" -o jsonpath='{range .status.conditions[*]}{.type}={.status}: {.message}{"\n"}{end}'
kubectl --kubeconfig "$kc" api-resources --verbs=list --namespaced -o name | while read -r r; do kubectl --kubeconfig "$kc" -n "$ns" get "$r" --ignore-not-found -o name 2>/dev/null; done
```

The conditions name the resources and the finalizers that block. Do D1 to D3 for each object that stays. Never remove the `kubernetes` finalizer from a namespace: the objects stay in etcd without a namespace. [field]

## D5. Remove a finalizer (last resort, CHANGES)

Use D5 only when **all** these are true. Write each one in the plan with its evidence:
1. D1 to D3 are done. The cleanup error is known, and the user cannot fix it (for example, the infrastructure object was deleted by hand, or the cluster is gone for ever).
2. The controller of the finalizer is healthy (D2), or it will never come back.
3. The thing that the finalizer protects is already gone, and the user checked it. For a NutanixMachine: the VM with `status.vmUUID` is not in Prism Central. For a Machine: its NutanixMachine is gone. For an NKPCluster: its CAPI `Cluster` and all machines are gone. [pdf p.497]
4. The children of the object have no finalizers left. Remove from the bottom up (NutanixMachine first, NKPCluster last), never from the top.

**Warning for the plan.** "A finalizer removal skips the cleanup. If the VM, disk, volume, or IP still exists, it stays in Prism Central or the cloud, and NKP forgets it. The user must delete it by hand. You cannot undo the removal."

Read the VM UUID before the removal. Check it in Prism Central with skill `nutanix-nkp`, RECIPES.md "Leftover audit for a cluster". If that skill is not installed, the user does it in Prism Central.

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get nutanixmachines -l "cluster.x-k8s.io/cluster-name=$CLUSTER_NAME" -o custom-columns='NAME:.metadata.name,VM-UUID:.status.vmUUID,DELETING:.metadata.deletionTimestamp'
```

Approval: the user types `yes` **and the exact object name** in one message. Remove only the one finalizer that blocks. Set `f` to its index in the list from D1 (the first is `0`). The `test` op stops the patch when the index points to another name.

```bash
# CHANGES  (removes one finalizer: the cleanup of that controller is skipped; cannot be undone)
source ~/nkp-<cluster>.env 2>/dev/null
kind=''; name=''; ns=''; f=''; fin=''; where='mgmt'; case "$where" in mgmt) kc="$MGMT_KUBECONFIG";; cluster) kc="$CLUSTER_KUBECONFIG";; *) kc='';; esac
: "${kind:?}" "${name:?}" "${ns:?}" "${f:?}" "${fin:?}" "${kc:?}"
kubectl --kubeconfig "$kc" -n "$ns" patch "$kind" "$name" --type json -p "[{\"op\":\"test\",\"path\":\"/metadata/finalizers/$f\",\"value\":\"$fin\"},{\"op\":\"remove\",\"path\":\"/metadata/finalizers/$f\"}]"
```

`fin` is the finalizer name, for example `infrastructure.cluster.x-k8s.io/nutanixmachine`. The guide removes all finalizers of a stuck NKPCluster with `"path":"/metadata/finalizers"`. [pdf p.497] Never remove all finalizers. Use D5 for each one.

Done when: D1 prints NotFound for the object. Then do D1 on the parent. Tell the user which infrastructure objects to check and delete by hand.
