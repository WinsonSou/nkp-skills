# Scheduling: `Pending` pods, taints, affinity, PDBs, priority

Use this file from skill `kubernetes-core`. Set the empty shell values from the user or from the `SKILL.md` step 1 output.

## S1. Why is the pod `Pending`?

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
ns=''; pod=''
: "${ns:?}" "${pod:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" events --for "pod/$pod"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" get pod "$pod" -o jsonpath='nodeSelector={.spec.nodeSelector}{"\n"}affinity={.spec.affinity}{"\n"}tolerations={.spec.tolerations}{"\n"}spread={.spec.topologySpreadConstraints}{"\n"}gates={.spec.schedulingGates}{"\n"}priorityClass={.spec.priorityClassName}{"\n"}pvcs={.spec.volumes[*].persistentVolumeClaim.claimName}{"\n"}'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get nodes -o custom-columns='NAME:.metadata.name,READY:.status.conditions[?(@.type=="Ready")].status,UNSCHED:.spec.unschedulable,TAINTS:.spec.taints[*].key,CPU:.status.allocatable.cpu,MEM:.status.allocatable.memory'
```

The `FailedScheduling` event has one line like `0/5 nodes are available: 1 node(s) had untolerated taint {node-role.kubernetes.io/control-plane: }, 4 Insufficient cpu.` Each part names a reason and the count of nodes. Fix the reason with the largest count first.

| Part of the message | Cause | Next |
|---|---|---|
| `Insufficient cpu`, `Insufficient memory` | The **requests** of the pod do not fit the free requests on any node. | S2. |
| `had untolerated taint {key: value}` | The node has a taint, and the pod has no matching toleration. | S3. |
| `didn't match Pod's node affinity/selector` | `nodeSelector` or node affinity names a label that no node has. | S4. |
| `didn't match pod affinity rules`, `didn't match pod anti-affinity rules` | Pod (anti-)affinity. A required anti-affinity with more replicas than nodes always leaves pods `Pending`. | S4. |
| `didn't match pod topology spread constraints` | `whenUnsatisfiable: DoNotSchedule` and the skew is too large. | S4. |
| `node(s) were unschedulable` | The node is cordoned (`SchedulingDisabled`). | S5. |
| `pod has unbound immediate PersistentVolumeClaims` | The PVC is not `Bound`. | skill `nkp-storage-backup`, step 2. |
| `volume node affinity conflict` | The PV can attach only to some nodes (zone, Metal node). | skill `nkp-storage-backup`. |
| `Too many pods` | The node has its maximum pod count (allocatable `pods`; 110 on the lab nodes [live 2.19.0]). | More nodes, or a kubelet change (skill `nkp-cluster-lifecycle`). |
| `didn't have free ports for the requested pod ports` | `hostPort` is used by another pod on each node. | Remove `hostPort`, or fewer replicas than nodes. |
| No event, `gates=` not empty | A scheduling gate holds the pod. The controller that added the gate must remove it. | Ask the app owner. |
| No event and no gate | The scheduler did not try yet, or the events expired (1 hour). | Wait 1 minute, then run the block again. |

A cluster with the autoscaler adds nodes for `Insufficient` pods (skill `nkp-cluster-lifecycle`, file `maintenance.md` M1). It does not help with taints, selectors, or PVCs.

Done when: you can name the reason for each node group in the message.

## S2. `Insufficient cpu` or `memory`

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
for n in $(kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get nodes -o name); do echo "== $n"; kubectl --kubeconfig "$CLUSTER_KUBECONFIG" describe "$n" | sed -n '/^Allocated resources/,/^Events/p' | grep -E '^ +(cpu|memory) '; done
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get resourcequota -A
```

- The columns are: requests (percent of allocatable), limits (percent). The scheduler uses the requests. [live 2.19.0]
- The pod requests more than the allocatable of every node: it never fits. Lower the request, or use a larger pool.
- The pods fit in total but not on one node: free capacity is split across nodes. Add a node, or lower the request.
- A `ResourceQuota` gives a different error: the controller cannot create the pod (`exceeded quota` in `kubectl describe replicaset` or the Job events). Then no pod exists. NKP has quotas in some of its own namespaces (for example `kommander-critical-pods`). [live 2.19.0] Do not change them.

## S3. Taints and tolerations

- Taint effects [live 2.19.0]: `NoSchedule` (no new pods), `PreferNoSchedule` (avoid), `NoExecute` (also evicts running pods without a toleration).
- Control-plane nodes have the taint `node-role.kubernetes.io/control-plane:NoSchedule`. [live 2.19.0] Do not add a toleration for it to an app.
- A toleration only **allows** a tainted node. To force a node, also add a `nodeSelector` or node affinity (S4).
- Taints on NKP nodes come from the node pool. Change them with skill `nkp-cluster-lifecycle` (`taints`), not with `kubectl taint`. A `kubectl taint` on a CAPI node is lost when the machine is replaced.

Toleration in the pod template (`kubectl explain pod.spec.tolerations`):

```yaml
tolerations:
- key: dedicated
  operator: Equal
  value: gpu
  effect: NoSchedule
```

## S4. Node selector, affinity, topology spread

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
key=''
: "${key:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get nodes -L "$key"
```

- An empty column for every node: no node has the label. Labels on NKP nodes come from the node pool (skill `nkp-cluster-lifecycle`). A `kubectl label node` is lost when the machine is replaced.
- `required...` node affinity (`nodeSelectorTerms`): a hard rule. `preferred...`: a soft rule with a `weight`. Operators: `In`, `NotIn`, `Exists`, `DoesNotExist`, `Gt`, `Lt`. [live 2.19.0]
- Pod anti-affinity on `kubernetes.io/hostname` puts each replica on its own node. With `required`, replicas > nodes gives `Pending` pods. Use `preferred` or `topologySpreadConstraints` with `whenUnsatisfiable: ScheduleAnyway`.
- Topology spread fields [live 2.19.0]: `maxSkew`, `topologyKey`, `whenUnsatisfiable` (`DoNotSchedule`, `ScheduleAnyway`), `labelSelector`, `matchLabelKeys`, `minDomains`, `nodeAffinityPolicy`, `nodeTaintsPolicy`.

Spread over nodes (soft):

```yaml
topologySpreadConstraints:
- maxSkew: 1
  topologyKey: kubernetes.io/hostname
  whenUnsatisfiable: ScheduleAnyway
  labelSelector:
    matchLabels:
      app: web
```

## S5. Cordoned node and drain

A cordoned node shows `SchedulingDisabled` in `kubectl get nodes`. On NKP, CAPI cordons and drains a node before it deletes the machine (rollout, scale down, upgrade). Do not uncordon such a node. For a stuck rollout, use skill `nkp-troubleshooting`, file `rollouts.md` R6.

A manual drain (for example for node work) is CHANGES. It evicts the pods, and the PDBs can block it (S6):

```bash
# CHANGES  (cordons the node and evicts its pods; DaemonSet pods stay; emptyDir data is lost)
source ~/nkp-<cluster>.env 2>/dev/null
node=''
: "${node:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" drain "$node" --ignore-daemonsets --delete-emptydir-data --timeout=600s
```

After the work: `kubectl uncordon <node>` (CHANGES). For a Metal host, use skill `nkp-cluster-lifecycle`, file `metal.md`.

## S6. PodDisruptionBudget (PDB)

A PDB limits **voluntary** evictions (drain, node replace, upgrade). It does not stop a node crash or a pod delete.

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get pdb -A -o custom-columns='NAMESPACE:.metadata.namespace,NAME:.metadata.name,MIN:.spec.minAvailable,MAX:.spec.maxUnavailable,ALLOWED:.status.disruptionsAllowed,HEALTHY:.status.currentHealthy,DESIRED:.status.desiredHealthy,SELECTOR:.spec.selector.matchLabels'
```

- `ALLOWED` `0` blocks every drain of a node with one of its pods. Common causes: `minAvailable` equal to the replicas (for example 1 of 1), `maxUnavailable: 0`, or the pods are not ready.
- Fields [live 2.19.0]: `minAvailable` or `maxUnavailable` (not both; a number or a percent), `selector`, `unhealthyPodEvictionPolicy` (`IfHealthyBudget`, the default, or `AlwaysAllow`: unready pods can be evicted).
- The PDB belongs to the app owner. The fix is a choice for the user (show it in the plan):
  1. Scale the app up, so that one pod can go (for example 2 replicas with `maxUnavailable: 1`). Use [workloads.md](workloads.md), W3.
  2. Change the PDB: `maxUnavailable: 1`, or `unhealthyPodEvictionPolicy: AlwaysAllow` when the pods are not ready.
  3. NKP drain timeout on the pool (skill `nkp-cluster-lifecycle`): after the timeout, CAPI deletes the node with the pods on it.
- A PDB that Helm or Flux made (labels `app.kubernetes.io/managed-by: Helm`, `helm.toolkit.fluxcd.io/name`) comes back on the next reconcile. Change its values with skill `nkp-platform-apps-gitops`. Do not edit NKP PDBs (for example `kommander/gatekeeper-controller-manager`). [live 2.19.0]

Change an app PDB to `maxUnavailable`. `max` is a whole number (`1`) or a percent in JSON quotes (`'"50%"'`). The first block is a server dry run (the matching webhooks have `sideEffects: None` [live 2.19.0]):

```bash
# READ-ONLY  (server dry run: changes nothing)
source ~/nkp-<cluster>.env 2>/dev/null
ns=''; pdb=''; max=''
: "${ns:?}" "${pdb:?}" "${max:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" patch pdb "$pdb" --type merge -p "{\"spec\":{\"minAvailable\":null,\"maxUnavailable\":$max}}" --dry-run=server
```

```bash
# CHANGES  (changes one PodDisruptionBudget)
source ~/nkp-<cluster>.env 2>/dev/null
ns=''; pdb=''; max=''
: "${ns:?}" "${pdb:?}" "${max:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" patch pdb "$pdb" --type merge -p "{\"spec\":{\"minAvailable\":null,\"maxUnavailable\":$max}}"
```

`"minAvailable":null` removes that field. A new PDB: `kubectl create pdb <name> -n <ns> --selector=app=<app> --max-unavailable=1` (CHANGES). [live 2.19.0]

## S7. Priority and preemption

- A pod with a higher `priorityClassName` can evict (preempt) lower pods to fit. The event is `Preempted`.
- PriorityClasses on 2.19.0: `system-node-critical`, `system-cluster-critical`, `dkp-critical-priority`, `dkp-high-priority`. [live 2.19.0] Do not give these classes to apps.
- `kubectl get priorityclass` lists them. An app class with `preemptionPolicy: Never` gets a higher place in the queue but evicts nothing.
