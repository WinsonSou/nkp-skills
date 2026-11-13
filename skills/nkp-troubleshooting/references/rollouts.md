# Stuck rollouts: Machines, MachineDeployments, KubeadmControlPlane

Use this file from skill `nkp-troubleshooting`. A rollout, a scale, a node replace, or an upgrade does not end. All objects are on the management cluster, in `"$WORKSPACE_NS"`. Do the sections in order.

How a rollout works [live 2.19.0]:
- CAPI machines are immutable. A change makes a new machine, then deletes an old one. [pdf p.24]
- One new node must be Ready before an old node drains. So one rollout needs one free IP and the resources of one more VM. The rollout settings are in skill `nkp-cluster-lifecycle`, variables.md, V2.
- The controller rolls the control plane first, then the pools. [pdf p.1047] By default, one pool at a time. [pdf p.1018]
- A pool has no drain timeout by default (`deletion.nodeDrainTimeoutSeconds` is not set). A drain that a Pod Disruption Budget blocks waits for ever.

## R1. Read the state

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get kubeadmcontrolplanes,machinedeployments,machinesets -l "cluster.x-k8s.io/cluster-name=$CLUSTER_NAME"
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get machines -l "cluster.x-k8s.io/cluster-name=$CLUSTER_NAME" -o custom-columns='NAME:.metadata.name,NODE:.status.nodeRef.name,PHASE:.status.phase,READY:.status.conditions[?(@.type=="Ready")].status,UPTODATE:.status.conditions[?(@.type=="UpToDate")].status,DELETING:.metadata.deletionTimestamp,AGE:.metadata.creationTimestamp'
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get machines -l "cluster.x-k8s.io/cluster-name=$CLUSTER_NAME" -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{range .status.conditions[?(@.status!="True")]}  {.type}={.status} {.reason}: {.message}{"\n"}{end}{end}'
```

- On a healthy machine, the only conditions that are not `True` are `Updating=False`, `Paused=False`, and `Deleting=False`. [live 2.19.0]
- Find the **oldest** machine that is not `Running`, or that is `Deleting`. Its first condition that is not healthy is the cause. Go to the row in R2.

Done when: you have the machine name, its PHASE, and the message of its first bad condition.

## R2. Phase → cause

| Machine PHASE and condition | Meaning | Next |
|---|---|---|
| `Pending`, `BootstrapConfigReady` not `True` | No bootstrap data yet. Often the control plane is not ready. | R3 (kubeadm bootstrap log) |
| `Provisioning`, `InfrastructureReady` not `True` | The VM is not made or not started. | R3 (CAPX log), R4 |
| `Provisioned`, `NodeHealthy` or `NodeReady` not `True` | The VM runs, but the node did not join. | R5 (node-level checks) |
| `Running`, but the rollout waits | A drain is blocked, or the new node is not Ready. | R6 |
| `Deleting` for more than 15 minutes | The drain, the VM delete, or a finalizer blocks. | R6, then skill file `deletes.md` of this skill ([deletes.md](deletes.md)) |
| `Failed` | The provider gave a final error. | R3. The MachineHealthCheck replaces it, if it is on (R7). |
| `Remediating=True` on the pool or control plane | The MachineHealthCheck replaces machines. | R7 |
| `Paused=True` | Reconcile is paused (`spec.paused` on the `Cluster`). | R8 |

## R3. Read the controller log

Use [controllers.md](controllers.md), the log block. Use the provider row (CAPX on AHV) for `Provisioning` and `Deleting`, `capi-kubeadm-bootstrap` for `Pending`, and `capi-kubeadm-control-plane` for a control-plane rollout. Search for the machine name.

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
m=''
: "${m:?}"
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get nutanixmachines -l "cluster.x-k8s.io/cluster-name=$CLUSTER_NAME" -o custom-columns='NAME:.metadata.name,READY:.status.ready,PROVIDERID:.spec.providerID'
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" describe machine "$m"
```

Set `m` to the machine name from R1. On AHV, the `NutanixMachine` has the same name as its Machine. [live 2.19.0] Its conditions `VMProvisioned` and `VMAddressesAssigned` must be `True`. `status.vmUUID` is the VM UUID in Prism Central. [live 2.19.0]

## R4. VM not made (AHV)

The CAPX log names the Prism Central error. Common causes [pdf p.1048][pdf p.725-726]:
- Prism Central credentials are wrong or changed. The fix: skill `nkp-install` (credentials) or the PC admin.
- The image in the topology is not in Prism Central, or its name has no Kubernetes version. The fix: skill `nkp-upgrade` (upgrade image) or skill `nkp-install`.
- The subnet IP pool is full, or the Prism Element cluster has no free CPU or memory for one more VM (R1, `maxSurge: 1`). Read the free pool IPs with skill `nutanix-networking`, RECIPES.md "Pool capacity: free IPs in a subnet pool". If that skill is not installed, the user does it in Prism Central. The user frees IPs or resources.
- The Prism Central project does not allow the subnet or the image. The fix: skill `nkp-cluster-lifecycle` (V7 says do not change the project of a running cluster).

## R5. Node-level checks (VM runs, no node)

The user runs these on the node over SSH. NKP adds the `SSH_PUBKEY_FILE` key for user `konvoy` on AHV nodes. [live 2.19.0] Get the node IP:

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get machines -l "cluster.x-k8s.io/cluster-name=$CLUSTER_NAME" -o custom-columns='NAME:.metadata.name,IP:.status.addresses[?(@.type=="InternalIP")].address,PHASE:.status.phase'
```

Give this block to the user [field]:

```bash
# USER-TERMINAL  (on the node, over SSH as user konvoy; the user runs it and sends the error lines)
sudo tail -50 /var/log/cloud-init-output.log
sudo journalctl -u containerd --no-pager --since -30min | tail -50
sudo journalctl -u kubelet --no-pager --since -30min | tail -50
sudo crictl ps -a
```

| Error in the output | Owner of the fix |
|---|---|
| Image pull fails, `x509`, registry not reachable | skill `nkp-airgap` (its file `nodes.md`) |
| kubeadm join cannot reach the API VIP | skill `nkp-networking` (kube-vip, routes) |
| Time or certificate errors (`certificate has expired or is not yet valid`) | NTP: skill `nkp-install` (`NTP_SERVERS`) |
| Disk full, cloud-init script error | skill `nkp-cluster-lifecycle` (pool disk size) |

## R6. Drain or delete does not end

1. Find the node of the old machine (R1, column NODE). Check the pods that stay on it and the PDBs:

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
node=''
: "${node:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get pods -A -o wide --field-selector "spec.nodeName=$node"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get pdb -A -o custom-columns='NAMESPACE:.metadata.namespace,NAME:.metadata.name,ALLOWED:.status.disruptionsAllowed'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get pvc -A
```

2. A PDB with ALLOWED `0`, and one of its pods is on the node: the drain waits for it. [pdf p.1003] Tell the user the app and the PDB. Choices (the user decides):
   - The app owner scales the app up, or changes the PDB (skill `kubernetes-core`).
   - Set a drain timeout on the pool: skill `nkp-cluster-lifecycle`, step 3, topology block (`deletion` field). After the timeout, CAPI deletes the node with the pods still on it. Say this in the plan.
3. The pods are gone, but a volume does not detach: skill `nkp-storage-backup`, file `csi.md` C7.
4. The node is gone, but the Machine stays `Deleting`: the VM delete fails. Read the CAPX log (R3). Then use [deletes.md](deletes.md).

## R7. MachineHealthCheck does not replace a machine

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get machinehealthchecks -l "cluster.x-k8s.io/cluster-name=$CLUSTER_NAME"
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get machines -l "cluster.x-k8s.io/cluster-name=$CLUSTER_NAME" -o custom-columns='NAME:.metadata.name,HEALTHY:.status.conditions[?(@.type=="HealthCheckSucceeded")].status,MSG:.status.conditions[?(@.type=="HealthCheckSucceeded")].message'
```

- The MHC limits (the unhealthy share, and the times) are in skill `nkp-cluster-lifecycle`, maintenance.md, M2. Above the limit, CAPI waits. Fix the common cause first (R4, R5).
- A Metal pool has no MHC. [live 2.19.0]

## R8. Paused cluster

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get clusters.cluster.x-k8s.io -l "cluster.x-k8s.io/cluster-name=$CLUSTER_NAME" -o custom-columns='NAME:.metadata.name,PAUSED:.spec.paused,PAUSED-ANNOTATION:.metadata.annotations.cluster\.x-k8s\.io/paused'
```

A pivot (`nkp move capi-resources`) pauses the cluster while it moves the objects. [field] If a move failed, the cluster can stay paused. Ask the user what ran last. The fix is not in the skills. Do not unpause a cluster that two management clusters can see.

## R9. Roll all machines again (last resort)

Use this only when the topology must not change, but the machines must be made again. A registry URL change in the NKPCluster rolls the nodes by itself [pdf p.287]: do not use R9 for it. Use R9 for a registry CA change in the Secret only, when the nodes do not roll (skill `nkp-cluster-lifecycle`, variables.md, V8, P-27). First try the owner fix (a topology change rolls the machines by itself).

- The field is `spec.rollout.after` (RFC3339 time) on the MachineDeployment or the KubeadmControlPlane. The server dry run accepts it on both. [live 2.19.0]
- The old name `spec.rolloutAfter` is dropped in this CAPI API version. It has no effect. [live 2.19.0]
- The NKPCluster drops `rollout.after` from a pool. [live 2.19.0] So this is the only direct patch of a topology object in the skills.
- UNKNOWN (A-20): whether the topology controller keeps a `rollout.after` that you set on a topology-owned MachineDeployment or KubeadmControlPlane. Find out with: `source ~/nkp-<cluster>.env 2>/dev/null && kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get machinedeployments,kubeadmcontrolplanes -l "cluster.x-k8s.io/cluster-name=$CLUSTER_NAME" -o custom-columns=NAME:.metadata.name,AFTER:.spec.rollout.after` (after the patch).

Preview with a server dry run. `obj` is `machinedeployment/<name>` or `kubeadmcontrolplane/<name>` from R1.

```bash
# READ-ONLY  (server dry run: the API server checks the patch and changes nothing)
source ~/nkp-<cluster>.env 2>/dev/null
obj=''
: "${obj:?}"
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" patch "$obj" --type merge -p "{\"spec\":{\"rollout\":{\"after\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}}}" --dry-run=server -o jsonpath='{.spec.rollout}{"\n"}'
```

The output must have `"after"`. The plan says: which object, that every machine of it is replaced one by one, one more IP and VM during the roll, and for a control plane with 1 node, API downtime. Roll the control plane first, then the pools. After "yes":

```bash
# CHANGES  (sets spec.rollout.after: CAPI replaces every machine of this object, one by one)
source ~/nkp-<cluster>.env 2>/dev/null
obj=''
: "${obj:?}"
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" patch "$obj" --type merge -p "{\"spec\":{\"rollout\":{\"after\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}}}"
```

Then watch with skill `nkp-cluster-lifecycle`, step 3d. Done when: all machines of the object have a new AGE and are `Running`, and step 3d passes.
