# Batch 4 answers: kubernetes-core

Notes that apply to every answer below:

- The operator host login shell is zsh. Rule 3 says "Run blocks with bash", so I run every block with bash (`bash` for a file, `bash -c '...'` for the one-liners). The blocks are POSIX `sh`-clean, so zsh would also parse them, but I do not rely on that.
- The cluster env file for cluster `app-01` is `~/nkp-app-01.env`. Each answer first checks that the file exists and prints `set:` for its four variables (skill `nkp-cluster-lifecycle`, step 1). If the check shows `MISSING`, I stop and ask for the values instead of guessing.
- Skill files read for this batch: `skills/nkp/SKILL.md` (router), `skills/_shared/RULES.md` (rules master copy), `skills/kubernetes-core/SKILL.md` + `references/pods.md`, `references/scheduling.md`, `references/networking.md`, `references/workloads.md`, `skills/nkp-cluster-lifecycle/SKILL.md` + `references/variables.md`, `references/maintenance.md`, `skills/nkp-troubleshooting/SKILL.md` + `references/rollouts.md`, `skills/nkp-platform-apps-gitops/SKILL.md` + `references/overrides.md`, `skills/nkp-networking/SKILL.md`, `skills/nkp-install/SKILL.md` (the "Prepare the env files" and "Set the kubeconfig variables" steps).
- Each prompt is a new conversation. So I do not carry the `shop` namespace, the pod name, or any earlier answer into the next prompt.

---

## kubernetes-core K1

**Skills used:** `nkp` (router) → `kubernetes-core` (step 1, step 3, `references/pods.md` P1, P2, P3, P4). Helper skills that the answer points to: `nkp-cluster-lifecycle` (step 1, cluster env file), `nkp-platform-apps-gitops` (if a Helm or Flux owner shows up), `nkp-airgap` (image pull, not the case here).

### What I would ask first (question tool)

I would ask these with the question tool:

1. Is `~/nkp-app-01.env` on this host the env file for cluster `app-01`, and does it already hold `CLUSTER_KUBECONFIG`? (Recommended: yes, use `~/nkp-app-01.env`)
2. When did the crash loop start, and what changed just before it (an app deploy, a Helm release, a limit change, a node event)? "This morning" is not enough to pick a cause.
3. Do you know the app owner of Deployment `cart` (your team, or a platform app in an NKP namespace)? This decides where the fix goes (step 3).

### Step 1: read the state (READ-ONLY)

First the env check, then the namespace read (skill `kubernetes-core`, step 1):

```bash
# READ-ONLY
source ~/nkp-app-01.env 2>/dev/null
for v in CLUSTER_NAME WORKSPACE_NS CLUSTER_KUBECONFIG MGMT_KUBECONFIG; do if [ -n "$(printenv "$v")" ]; then echo "set: $v"; else echo "MISSING: $v"; fi; done
```

```bash
# READ-ONLY
source ~/nkp-app-01.env 2>/dev/null
ns='shop'
: "${ns:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" get pods -o wide
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" get deploy,sts,ds,jobs,svc,pvc
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" events --types=Warning
```

Then the pod itself and the log of the container that already stopped (the `--previous` flag is the important one: the current container of a `CrashLoopBackOff` pod usually has an empty or short log):

```bash
# READ-ONLY
source ~/nkp-app-01.env 2>/dev/null
ns='shop'; pod='cart-7d9f-abcde'
: "${ns:?}" "${pod:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" describe pod "$pod"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" logs "$pod" --all-containers --previous --tail=50
```

I read `describe` in this order: `Status` and `Reason`, each container `State` and `Last State` with `Exit Code`, `Conditions`, then `Events`. If `--previous` prints "previous terminated container not found", the container has not restarted yet, and I run the same line without `--previous`.

### Step 2 of the diagnosis: the container state and the exit code (P1, READ-ONLY)

```bash
# READ-ONLY
source ~/nkp-app-01.env 2>/dev/null
ns='shop'; pod='cart-7d9f-abcde'
: "${ns:?}" "${pod:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" get pod "$pod" -o jsonpath='{range .status.initContainerStatuses[*]}init {.name}: ready={.ready} restarts={.restartCount} waiting={.state.waiting.reason} last={.lastState.terminated.reason} exit={.lastState.terminated.exitCode}{"\n"}{end}{range .status.containerStatuses[*]}{.name}: ready={.ready} restarts={.restartCount} waiting={.state.waiting.reason} last={.lastState.terminated.reason} exit={.lastState.terminated.exitCode}{"\n"}{end}'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" get pod "$pod" -o jsonpath='{range .spec.containers[*]}{.name}: requests={.resources.requests} limits={.resources.limits}{"\n"}{end}'
```

How I read the result (P1 table):

| `waiting` or `last` | Exit code | Meaning | Next |
|---|---|---|---|
| `CrashLoopBackOff`, last `Error` | 1, 2, or an app code | The app itself exits. | P2, the app log that I read with `--previous`. |
| last `OOMKilled` | 137 | The container went over its memory limit. | P4 (resources). |
| last `Error` | 137, no OOM | SIGKILL, for example a failed liveness probe or a kill after the grace period. | P3 (probes). |
| last `Error` | 143 | SIGTERM: a normal stop, or a liveness restart. | P3 (probes). |

So the answer to "why" comes from this table plus the first error lines of the `--previous` log. I will not name a cause before I see the exit code and that log.

If the troubleshooting goes into resources, note that `kubectl top` needs the Metrics API and is not proof on its own. The Starter lab has no Metrics API and prints `error: Metrics API not available` [live 2.19.0]. Which tiers give it is UNKNOWN (Q-10):

```bash
# READ-ONLY
source ~/nkp-app-01.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get apiservices | grep metrics
```

### What I will not do

- I do not delete or restart the pod to "try" a fix. A delete is CHANGES with a plan, and it hides the evidence (the `--previous` log and the `Last State`).
- I do not change the Deployment before step 3 tells me who owns it.

### Step 3 before any fix: who owns the object (READ-ONLY)

The pod belongs to a ReplicaSet, so the fix goes into the Deployment, not the pod:

```bash
# READ-ONLY
source ~/nkp-app-01.env 2>/dev/null
ns='shop'; obj='deployment/cart'
: "${ns:?}" "${obj:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" get "$obj" -o jsonpath='owners={.metadata.ownerReferences[*].kind}/{.metadata.ownerReferences[*].name}{"\n"}managed-by={.metadata.labels.app\.kubernetes\.io/managed-by}{"\n"}helm-release={.metadata.annotations.meta\.helm\.sh/release-name}{"\n"}flux-helm={.metadata.labels.helm\.toolkit\.fluxcd\.io/name}{"\n"}flux-kustomization={.metadata.labels.kustomize\.toolkit\.fluxcd\.io/name}{"\n"}'
```

- All fields empty in a user namespace: the Deployment is yours (`kubectl apply`), so the fix is in this skill.
- `helm-release` or `flux-helm` or `flux-kustomization` set: the values live in an AppDeployment override or in Git (skill `nkp-platform-apps-gitops`). A manual `set resources` comes back at the next reconcile.
- The namespace is an NKP namespace (`kube-system`, `kommander*`, `caren-system`, `cap*-system`, `metallb-system`, `ntnx-system`, `cert-manager`, `git-operator-system`, `kube-federation-system`): I do not change it. I name the owner skill and stop.

### The fix (CHANGES, only after step 3 and after "yes")

Two cases:

1. Exit 137 with `OOMKilled`: raise the memory limit (P4). I read the real need first (`kubectl top` only if the Metrics API exists, otherwise the peak in the log or from the app owner). Then this block, with the values you give:

```bash
# CHANGES  (sets requests and limits of one container; the workload rolls out new pods)
source ~/nkp-app-01.env 2>/dev/null
ns='shop'; kind='deployment'; name='cart'; c=''; req=''; lim=''
: "${ns:?}" "${kind:?}" "${name:?}" "${c:?}" "${req:?}" "${lim:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" set resources "$kind/$name" -c "$c" --requests="$req" --limits="$lim"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" rollout status "$kind/$name" --timeout=300s
```

   `req` and `lim` have the form `cpu=250m,memory=256Mi`. Before the CHANGES run, the same `set` line with `--dry-run=server` (READ-ONLY) shows the new objects.

2. Exit 137 without `OOMKilled`, or 143: probes (P3). I read the probe fields and the `Liveness probe failed` events, then fix `initialDelaySeconds`/`timeoutSeconds`/the path in the Deployment. Same plan-then-"yes" flow.

The plan I show before I run it names the Deployment, the container, the old and the new values, and the result: all pods of `cart` are replaced one by one, and during the rollout some requests fail if `maxUnavailable` allows it (skill `kubernetes-core`, `references/workloads.md`, W6). Then I stop for "yes". "Just run it" is not "yes".

---

## kubernetes-core K2

**Skills used:** `nkp` (router) → `kubernetes-core`, `references/scheduling.md` (S1, S2, S3, S4) + `references/pods.md` P4 (the `set resources` block). Node side: `nkp-cluster-lifecycle` (`references/maintenance.md` M1 for the autoscaler, step 3 + `references/variables.md` V3 for a larger VM, step 4 for more nodes).

### What I would ask first (question tool)

I would ask these with the question tool:

1. Is `~/nkp-app-01.env` the env file for cluster `app-01`? (Recommended: yes)
2. What memory do you want `report-gen` to run with, and what is its real peak (from the app owner, or from the app log)? This is the input for both choices.
3. Should the pool grow (autoscaler `min` < `max`, or more or larger nodes), or should the Deployment ask for less memory? (Recommended: lower the request if the real peak fits; otherwise grow the pool)

### Cause: the message has two parts, and only one of them is a problem

S1 of `references/scheduling.md` reads the event and the pod:

```bash
# READ-ONLY
source ~/nkp-app-01.env 2>/dev/null
ns='analytics'
: "${ns:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" get pods -o wide
```

Then, with the pod name from that output:

```bash
# READ-ONLY
source ~/nkp-app-01.env 2>/dev/null
ns='analytics'; pod=''
: "${ns:?}" "${pod:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" events --for "pod/$pod"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" get pod "$pod" -o jsonpath='nodeSelector={.spec.nodeSelector}{"\n"}affinity={.spec.affinity}{"\n"}tolerations={.spec.tolerations}{"\n"}spread={.spec.topologySpreadConstraints}{"\n"}gates={.spec.schedulingGates}{"\n"}priorityClass={.spec.priorityClassName}{"\n"}pvcs={.spec.volumes[*].persistentVolumeClaim.claimName}{"\n"}'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get nodes -o custom-columns='NAME:.metadata.name,READY:.status.conditions[?(@.type=="Ready")].status,UNSCHED:.spec.unschedulable,TAINTS:.spec.taints[*].key,CPU:.status.allocatable.cpu,MEM:.status.allocatable.memory'
```

| Part of your message | Cause | What I do |
|---|---|---|
| `1 node(s) had untolerated taint {node-role.kubernetes.io/control-plane: }` | The control-plane taint `node-role.kubernetes.io/control-plane:NoSchedule` [live 2.19.0]. This is normal and by design. | Nothing. S3: do not add a toleration for it to an app. A control-plane node is not a place for `report-gen`. |
| `4 Insufficient memory` | The **requests** of the new pod do not fit the free requests on any of those 4 nodes. Not the real use, and not the limits. | S2 below. |

The count matters: 4 of 5 nodes fail on memory, so memory is the true blocker. The taint line only tells you the fifth node is off limits, which is correct.

### S2: the requests do not fit (READ-ONLY)

```bash
# READ-ONLY
source ~/nkp-app-01.env 2>/dev/null
for n in $(kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get nodes -o name); do echo "== $n"; kubectl --kubeconfig "$CLUSTER_KUBECONFIG" describe "$n" | sed -n '/^Allocated resources/,/^Events/p' | grep -E '^ +(cpu|memory) '; done
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get resourcequota -A
```

- The columns are requests (percent of allocatable) and limits (percent). The scheduler uses the **requests** [live 2.19.0].
- If the pod requests more memory than the allocatable of every node, it never fits. Lower the request, or use a larger pool.
- If the pods fit in total but not on one node, the free capacity is split across nodes. Add a node, or lower the request.
- A `ResourceQuota` prints a different error (`exceeded quota`, and then no pod exists at all). NKP has quotas in some of its own namespaces (for example `kommander-critical-pods`). I do not change those.

I also read the requests of the Deployment itself, because `Insufficient` is about that number (P1, second line of the block in K1, but with `kind=deployment`).

### The two choices (you decide)

**Choice A: lower the memory request.** Only if the real peak fits. Step 3 owner check first (the Deployment in `analytics` may be Helm- or Flux-owned), then:

```bash
# CHANGES  (sets requests and limits of one container; the workload rolls out new pods)
source ~/nkp-app-01.env 2>/dev/null
ns='analytics'; kind='deployment'; name='report-gen'; c=''; req=''; lim=''
: "${ns:?}" "${kind:?}" "${name:?}" "${c:?}" "${req:?}" "${lim:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" set resources "$kind/$name" -c "$c" --requests="$req" --limits="$lim"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" rollout status "$kind/$name" --timeout=300s
```

`--dry-run=server` on the `set` line previews it. I show the plan and wait for "yes".

**Choice B: more or larger nodes** (skill `nkp-cluster-lifecycle`). First check whether the autoscaler is on, because the autoscaler adds nodes for `Insufficient` pods by itself (`references/maintenance.md` M1):

```bash
# READ-ONLY
source ~/nkp-app-01.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get nkpcluster "$CLUSTER_NAME" -o jsonpath='{.spec.capiCluster.topology.variables[?(@.name=="clusterConfig")].value.addons.clusterAutoscaler}{"\n"}'
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get deploy -l app.kubernetes.io/name=clusterapi-cluster-autoscaler
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get deploy -A -l app.kubernetes.io/name=clusterapi-cluster-autoscaler
```

- First line `{"strategy":"HelmAddon"}`: the autoscaler is on. It adds nodes when pods are `Pending` for lack of resources, so with `min` < `max` on the pool this `Pending` pod may solve itself. An empty line: the addon is off.
- The pool size is the annotations `min` and `max`, not a `replicas` field (`nkp-cluster-lifecycle`, step 2). A fixed pool (`min` = `max`) never grows.
- Larger nodes or another pool: skill `nkp-cluster-lifecycle`, step 3 (`workerConfig`, `nutanix/machineDetails/memorySize`) or step 4 (`nkp scale nodepool`, `nkp create nodepool nutanix`). Both replace or add VMs, so they are CHANGES with a plan and a "yes".

### What I will not do

- I will not add a toleration for `node-role.kubernetes.io/control-plane` (S3). The taint is correct, and a toleration only allows the node, it does not make it a good place for the app.
- I will not run `kubectl taint` or `kubectl label node`. On NKP, taints and labels come from the node pool; a `kubectl` change is lost when CAPI replaces the machine (S3, S4).
- I will not say the limits decide the scheduling. Only the requests do.

---

## kubernetes-core K3

**Skills used:** `nkp` (router) → `nkp-troubleshooting` (rung 1-2, `references/rollouts.md` R1, R2, R6) → `kubernetes-core`, `references/scheduling.md` S6 (the PDB) + step 3 (owner check) + `references/workloads.md` W3 (scale up). On the NKP side: `nkp-cluster-lifecycle` (step 2 for the pool index, step 3 topology block for `deletion`), `nkp-platform-apps-gitops` (`references/overrides.md`) when the PDB is Helm- or Flux-owned.

### What I would ask first (question tool)

I would ask these with the question tool:

1. Is `~/nkp-app-01.env` the env file for cluster `app-01`? (Recommended: yes)
2. Which of the three ways do you want (see below): scale the app up, change the PDB, or set a pool drain timeout? (Recommended: scale the app up to 2 replicas, then the drain continues by itself)
3. If you choose the PDB change: which value do you want, `maxUnavailable: 1`, or `unhealthyPodEvictionPolicy: AlwaysAllow`? I need the number before I show the patch block.
4. If you choose the drain timeout: how many seconds, and is the app allowed to go down when the timeout hits?

### Step 1: confirm the stuck drain (READ-ONLY, `nkp-troubleshooting` R1)

```bash
# READ-ONLY
source ~/nkp-app-01.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get kubeadmcontrolplanes,machinedeployments,machinesets -l "cluster.x-k8s.io/cluster-name=$CLUSTER_NAME"
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get machines -l "cluster.x-k8s.io/cluster-name=$CLUSTER_NAME" -o custom-columns='NAME:.metadata.name,NODE:.status.nodeRef.name,PHASE:.status.phase,READY:.status.conditions[?(@.type=="Ready")].status,UPTODATE:.status.conditions[?(@.type=="UpToDate")].status,DELETING:.metadata.deletionTimestamp,AGE:.metadata.creationTimestamp'
```

A Machine `Deleting` for 40 minutes is R2 → R6: the drain, the VM delete, or a finalizer blocks. You already have the answer from `nkp-troubleshooting`: a PDB. So the next read is S6.

### Step 2: the PDBs (READ-ONLY, S6)

```bash
# READ-ONLY
source ~/nkp-app-01.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get pdb -A -o custom-columns='NAMESPACE:.metadata.namespace,NAME:.metadata.name,MIN:.spec.minAvailable,MAX:.spec.maxUnavailable,ALLOWED:.status.disruptionsAllowed,HEALTHY:.status.currentHealthy,DESIRED:.status.desiredHealthy,SELECTOR:.spec.selector.matchLabels'
```

I look for the row in `payments` with `ALLOWED` `0`. Typical causes: `MIN` equal to the replica count (for example 1 of 1), `MAX` `0`, or `HEALTHY` lower than `DESIRED` (pods not ready, so the budget allows nothing).

```bash
# READ-ONLY
source ~/nkp-app-01.env 2>/dev/null
node=''
: "${node:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get pods -A -o wide --field-selector "spec.nodeName=$node"
```

`node` is the NODE column of the stuck machine. This shows which pod of that PDB sits on the node that must drain.

A PDB limits **voluntary** evictions only (drain, node replace, upgrade). It does not stop a node crash or a `kubectl delete pod` — but a delete pod is not a fix here: the new pod has the same PDB and the drain then hits the next one.

### Step 3: who owns the PDB (READ-ONLY)

The PDB in `payments` is almost certainly the app's, not NKP's. Confirm before you touch it:

```bash
# READ-ONLY
source ~/nkp-app-01.env 2>/dev/null
ns='payments'; obj=''
: "${ns:?}" "${obj:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" get "$obj" -o jsonpath='owners={.metadata.ownerReferences[*].kind}/{.metadata.ownerReferences[*].name}{"\n"}managed-by={.metadata.labels.app\.kubernetes\.io/managed-by}{"\n"}helm-release={.metadata.annotations.meta\.helm\.sh/release-name}{"\n"}flux-helm={.metadata.labels.helm\.toolkit\.fluxcd\.io/name}{"\n"}flux-kustomization={.metadata.labels.kustomize\.toolkit\.fluxcd\.io/name}{"\n"}'
```

I fill `obj` with the real PDB name from step 2. Then:

- `managed-by=Helm` or `flux-helm` or `flux-kustomization` set: the PDB comes back at the next reconcile, so the change belongs in the app values (skill `nkp-platform-apps-gitops`, `references/overrides.md`). I tell you that before any patch.
- All empty in a user namespace: the PDB is yours, and S6 applies directly.
- The namespace is an NKP namespace: I do not edit it. NKP PDBs (for example `kommander/gatekeeper-controller-manager`) are not yours to change.

### The three choices (you decide, S6)

**1. Scale the app up, so one pod may go** (skill `kubernetes-core`, W3). This is the least invasive and needs no PDB edit:

```bash
# CHANGES  (sets the replica count of one Deployment or StatefulSet)
source ~/nkp-app-01.env 2>/dev/null
ns='payments'; kind='deployment'; name=''; replicas=''
: "${ns:?}" "${kind:?}" "${name:?}" "${replicas:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" scale "$kind/$name" --replicas="$replicas"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" rollout status "$kind/$name" --timeout=600s
```

The plan names the app, the old and the new replica count, and the result: one more pod, the budget then allows one disruption, and the drain continues. It also checks for a HorizontalPodAutoscaler first (`kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n payments get hpa`), because an HPA sets the replicas back — then the change goes into its `minReplicas`.

**2. Change the PDB to `maxUnavailable`** — only with your value. First the server dry run (READ-ONLY):

```bash
# READ-ONLY  (server dry run: changes nothing)
source ~/nkp-app-01.env 2>/dev/null
ns='payments'; pdb=''; max=''
: "${ns:?}" "${pdb:?}" "${max:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" patch pdb "$pdb" --type merge -p "{\"spec\":{\"minAvailable\":null,\"maxUnavailable\":$max}}" --dry-run=server
```

```bash
# CHANGES  (changes one PodDisruptionBudget)
source ~/nkp-app-01.env 2>/dev/null
ns='payments'; pdb=''; max=''
: "${ns:?}" "${pdb:?}" "${max:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" patch pdb "$pdb" --type merge -p "{\"spec\":{\"minAvailable\":null,\"maxUnavailable\":$max}}"
```

`max` stays empty with its `:?` guard until you give the value. I do not choose it for you. The plan says which PDB, the old budget, the new budget, and the effect: one pod of `payments` may be evicted at a time, so a short reduction of capacity is possible. Then I stop for "yes". `unhealthyPodEvictionPolicy: AlwaysAllow` is the alternative when `HEALTHY` is below `DESIRED` (the pods are not ready, so `maxUnavailable` alone does not help).

**3. Set a drain timeout on the pool** (skill `nkp-cluster-lifecycle`, step 2 for the pool index, step 3 topology block):

Read the topology first (READ-ONLY), because the block needs the pool index `i`:

```bash
# READ-ONLY
source ~/nkp-app-01.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get nkpcluster "$CLUSTER_NAME" -o go-template='{{range $i, $v := .spec.capiCluster.topology.variables}}variable {{$i}}: {{$v.name}}{{"\n"}}{{end}}controlPlane: replicas={{.spec.capiCluster.topology.controlPlane.replicas}}{{"\n"}}{{range $i, $p := .spec.capiCluster.topology.workers.machineDeployments}}pool {{$i}}: name={{$p.name}} class={{$p.class}} replicas={{or $p.replicas "-"}}{{"\n"}}{{end}}'
```

```bash
# CHANGES  (writes the patch file on the operator host; changes no cluster)
source ~/nkp-app-01.env 2>/dev/null
field=''; value=''
: "${field:?}" "${value:?}"
(umask 077 && cat > "$HOME/nkp-$CLUSTER_NAME-patch.json" <<EOF
[{"op":"test","path":"/metadata/name","value":"$CLUSTER_NAME"},
 {"op":"add","path":"/spec/capiCluster/topology/$field","value":$value}]
EOF
)
```

`field` is the `deletion` field of the stuck pool (`workers/machineDeployments`, then the index `i` in it, then `deletion`), and `value` is a JSON object that holds `nodeDrainTimeoutSeconds` with the number you choose. There is no drain timeout by default, which is exactly why the drain waits for ever (`references/rollouts.md`). The plan must say this clearly: **after the timeout CAPI deletes the node with the pods still on it**, so the `payments` pods on that node are killed, not evicted. A dry run of the patch (step 3b, READ-ONLY) comes before the apply.

### What I will not do

- I do not delete the PDB or the pod to get the drain moving. Neither is a plan, and both come back or make the drain block again.
- I do not use `kubectl drain --disable-eviction` or `--force`. That bypasses the PDB and the budget, which is the opposite of the app owner's intent.
- I do not edit a PDB in an NKP namespace.
- I do not put a `max` value in a block before you chose it.

---

## kubernetes-core K4

**Skills used:** `nkp` (router) → `kubernetes-core`, `references/networking.md` (N1, N2, N3, N4) + `references/pods.md` P3 (readiness) and P7 (`kubectl debug`). If the answer turns out to be MetalLB or Cilium: `nkp-networking`.

### What I would ask first (question tool)

I would ask these with the question tool:

1. Is `~/nkp-app-01.env` the env file for cluster `app-01`? (Recommended: yes)
2. What is the exact error in the frontend: a timeout on the name, a timeout on the ClusterIP, or `connection refused`? A timeout on the name is DNS; on the IP it is the endpoint path.
3. Does `api` have a readiness probe, and did it ever work (or is this a new Service)?

### Step 1: from the Service to the pods (READ-ONLY, N1)

```bash
# READ-ONLY
source ~/nkp-app-01.env 2>/dev/null
ns='orders'; svc='api'
: "${ns:?}" "${svc:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" get svc "$svc" -o jsonpath='type={.spec.type} clusterIP={.spec.clusterIP} selector={.spec.selector} ports={.spec.ports}{"\n"}lb={.status.loadBalancer.ingress}{"\n"}'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" get endpointslices -l "kubernetes.io/service-name=$svc" -o wide
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" get pods -o wide --show-labels
```

`Running` pods with an empty EndpointSlice is the classic case: the pods run, but they are not **ready**, so no endpoint is made. The status column hides that — a pod can be `Running` with READY `0/1`. So I read the third line (`--show-labels`) against the Service `selector` of the first line.

| What I see | Cause | Fix |
|---|---|---|
| EndpointSlice ENDPOINTS `<unset>` or empty, selector does not match the pod labels | Selector typo or a changed pod label | Correct the one that is wrong. Which side is the owner's decision. |
| Endpoints empty, selector matches, pods READY `0/1` | The readiness probe fails, so the pod gets no Service traffic | `references/pods.md` P3: probe path, port, `initialDelaySeconds`, `httpGet` to `127.0.0.1` |
| Endpoints exist, traffic still fails | `targetPort` is not the container port | `targetPort` must be the port the container listens on (a number or a named container port) |
| `selector` empty | A Service without a selector; someone must manage the EndpointSlices | Usually a mistake. Add the selector. |
| Works from the same namespace, fails from other namespaces | A NetworkPolicy | N3 (the CNI is Cilium and enforces NetworkPolicy) |
| Works by IP, fails by name | DNS | N2 |
| type `LoadBalancer`, `lb` empty (`<pending>`) | No IP from the load balancer | skill `nkp-networking` (MetalLB) |

Your Service answers from the frontend pods in another namespace, so if the endpoints are fine, the order is: N3 (NetworkPolicy) first, then N2 (DNS). A `ClusterIP` Service never involves MetalLB, so I do not send you there. The IP comes from the Service CIDR, and the CNI routes it.

### Step 2: probes when the pods are not ready (READ-ONLY, P3)

```bash
# READ-ONLY
source ~/nkp-app-01.env 2>/dev/null
ns='orders'; pod=''
: "${ns:?}" "${pod:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" get pod "$pod" -o jsonpath='{range .spec.containers[*]}{.name}{"\n"}  startup={.startupProbe}{"\n"}  liveness={.livenessProbe}{"\n"}  readiness={.readinessProbe}{"\n"}{end}'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" events --for "pod/$pod" --types=Warning
```

`Readiness probe failed` does not restart the pod — it only keeps it out of the endpoints. That fits your symptom exactly.

### Step 3: NetworkPolicy and DNS (READ-ONLY, N3, N2)

```bash
# READ-ONLY
source ~/nkp-app-01.env 2>/dev/null
ns='orders'
: "${ns:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" get networkpolicies
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" describe networkpolicies
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get ciliumnetworkpolicies -A
```

```bash
# READ-ONLY
source ~/nkp-app-01.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n kube-system get deploy coredns
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n kube-system get endpointslices -l kubernetes.io/service-name=kube-dns
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n kube-system logs deploy/coredns --tail=50
```

A NetworkPolicy in `orders` that selects the `api` pods and does not allow the frontend namespace blocks the traffic, even with healthy endpoints. Only a policy that selects a pod restricts it; policies add up, and there is no "deny" rule of its own.

### The test (CHANGES, after a plan and "yes")

If the reads do not settle it, I need one packet from a pod in the cluster. Two options, both CHANGES, both with a plan, neither with `-it` (I cannot type into a terminal):

```bash
# CHANGES  (runs one short test pod in the namespace, then deletes it)
source ~/nkp-app-01.env 2>/dev/null
ns='orders'; name='api.orders.svc.cluster.local'
: "${ns:?}" "${name:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" run "dnscheck-$(date +%s)" --image=busybox:1 --restart=Never --rm --attach --quiet --overrides='{"apiVersion":"v1","spec":{"securityContext":{"runAsNonRoot":true,"runAsUser":65534,"seccompProfile":{"type":"RuntimeDefault"}},"containers":[{"name":"c","image":"busybox:1","args":["nslookup","'"$name"'"],"securityContext":{"allowPrivilegeEscalation":false,"capabilities":{"drop":["ALL"]}}}]}}' --pod-running-timeout=2m
```

That separates DNS from the endpoint path: `NXDOMAIN` means a wrong name or namespace, a timeout on the name means DNS or a policy on port 53, and a resolved IP with a failed connect means the endpoint path (selector, `targetPort`, readiness, policy on 8443 or whatever the port is).

The other option is an ephemeral debug container in a running frontend pod (a `kubectl debug` line on the target pod with a new `-c` name, `--image=busybox:1`, `--target` set to the app container and `--profile=general`, then follow it with a `sh -c` test and read the output with `logs`; the exact block is `references/pods.md`, P7). It shares the network of the pod. It is also CHANGES: the container stays in the pod spec until the pod is replaced.

### What I will not do

- I do not restart the `api` pods first. They are `Running`; a restart would remove the evidence and change nothing if the cause is the selector, the port, or a policy.
- I do not change the Service before I read the endpoints. If the endpoints are correct, the Service is not the problem.
- I do not send a `ClusterIP` Service to MetalLB.

---

## kubernetes-core K5

**Skills used:** `nkp` (router) → `kubernetes-core`, `references/networking.md` N3 (the two policies) + `SKILL.md` step 4 (write file, server dry run, diff, plan, apply). Cilium detail if a drop needs proof: `nkp-networking`, step 2 (Hubble).

### What I would ask first (question tool)

I would ask these with the question tool:

1. What is the label of the `billing` pods (the key and the value, for example `app: billing-api`)? You gave the label of the gateway pods but not of the target pods. (Recommended: read it from the running pods with the READ-ONLY block below, and confirm)
2. Is port 8443 the container port of the `billing` pods, or the port of their Service? The policy matches the pod port, not the Service port.
3. Do other things talk to the `billing` pods today: the Traefik ingress controller, a Prometheus scraper, a backup job, a health check from another namespace? (Recommended: yes, list them, so we allow them in the same policy)
4. Is `~/nkp-app-01.env` the env file for cluster `app-01`? (Recommended: yes)

To get the label myself, READ-ONLY:

```bash
# READ-ONLY
source ~/nkp-app-01.env 2>/dev/null
ns='billing'
: "${ns:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" get pods -o wide --show-labels
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" get networkpolicies
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" describe networkpolicies
```

The current policies decide what the new ones add (policies add up, there is no deny rule of its own).

### Step 1: write the file (CHANGES, the file on the operator host only)

Two `NetworkPolicy` objects, exactly as N3 gives them: a deny-all ingress (an empty `podSelector` with `policyTypes: [Ingress]`) and one allow rule from `app: gateway` in the same namespace on TCP 8443. The billing label stays a guarded shell value until you confirm it:

```bash
# CHANGES  (writes the NetworkPolicy file on the operator host; changes no cluster)
source ~/nkp-app-01.env 2>/dev/null
sel=''
: "${sel:?}"
f="$HOME/nkp-billing-default-deny.yaml"
(umask 077 && cat > "$f" <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-ingress
  namespace: billing
spec:
  podSelector: {}
  policyTypes: [Ingress]
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-gateway-8443
  namespace: billing
spec:
  podSelector:
    matchLabels:
      app: $sel
  policyTypes: [Ingress]
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: gateway
    ports:
    - port: 8443
      protocol: TCP
EOF
)
```

The `from` list has **one** item that holds the `podSelector`. `app: gateway` in the same namespace needs no `namespaceSelector`, so there is no AND/OR trap here: two list items would be an OR, and I am not writing two.

I do not add a `CiliumNetworkPolicy`. Cilium enforces the plain Kubernetes `NetworkPolicy` (`enable-k8s-networkpolicy=true` [live 2.19.0]), so the plain object is the correct and portable one.

### Step 2: server dry run and diff (READ-ONLY, step 4)

```bash
# READ-ONLY  (server dry run and diff: change nothing)
source ~/nkp-app-01.env 2>/dev/null
f="$HOME/nkp-billing-default-deny.yaml"
: "${f:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" apply --dry-run=server -f "$f"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" diff -f "$f"
```

The dry run runs the API server and the admission webhooks (a Gatekeeper `denied` message shows here). `diff` exit code 0 means no difference, 1 means differences, more than 1 is an error. I show you the diff.

### Step 3: the plan, then stop for "yes"

The plan says:

- **Target:** the cluster `app-01`, namespace `billing`, two `NetworkPolicy` objects (`created`).
- **Result:** ingress to the `billing` pods is denied by default; only pods with `app: gateway` in `billing` may reach port 8443/TCP.
- **What stops working:** every other ingress path to those pods. Concretely: the Traefik ingress controller (`kommander-traefik`) if an Ingress points at them, a Prometheus or other scraper, a backup or job pod, and a second namespace. If you name them now, I add them as extra `from` items in the same policy before we apply, so we do not break them.
- **What does not change:** egress. The pods keep full egress (DNS included). This policy set is ingress-only, on purpose. If you also want egress, it is a separate policy with `policyTypes: [Egress]`, and a deny-all egress blocks DNS, so it needs a port-53 rule to `kube-dns`.
- **Also:** a `LoadBalancer` or `NodePort` path to these pods is ingress too, so it is covered by the same rules. Cilium keeps enforcing them after a restart; nothing else is needed.

Then:

```bash
# CHANGES  (applies the file to the cluster)
source ~/nkp-app-01.env 2>/dev/null
f="$HOME/nkp-billing-default-deny.yaml"
: "${f:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" apply -f "$f"
```

I run this only after you type "yes" to that plan.

### Step 4: the check after apply (READ-ONLY)

```bash
# READ-ONLY
source ~/nkp-app-01.env 2>/dev/null
ns='billing'
: "${ns:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" get networkpolicies
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" describe networkpolicies
```

Then one allowed flow (a gateway pod to `billing:8443`) and one blocked flow (from another namespace). If a flow is dropped and you need proof, Hubble is the tool: skill `nkp-networking`, step 2, `hubble observe --verdict DROPPED`.

---

## kubernetes-core K6

**Skills used:** `nkp` (router) → `kubernetes-core`, `SKILL.md` step 3 (owner check) + `references/workloads.md` W2 (rollout restart) and W3 (scale), plus W6 (update strategy) for the plan.

### What I would ask first (question tool)

I would ask these with the question tool:

1. Is `~/nkp-app-01.env` the env file for cluster `app-01`? (Recommended: yes)
2. Do you need the pods replaced, or do you need the app to pick up a changed ConfigMap or Secret? A `rollout restart` reloads both config and image; a scale to 0 and back also reloads them, but with downtime. (Recommended: `rollout restart`)
3. Is `web` in `shop` your Deployment, or is it Helm- or Flux-managed? If it is managed, the restart belongs in the values or in Git, otherwise the reconcile brings the old pods back.

### Step 1: the owner check (READ-ONLY, step 3) — before anything else

```bash
# READ-ONLY
source ~/nkp-app-01.env 2>/dev/null
ns='shop'; obj='deployment/web'
: "${ns:?}" "${obj:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" get "$obj" -o jsonpath='owners={.metadata.ownerReferences[*].kind}/{.metadata.ownerReferences[*].name}{"\n"}managed-by={.metadata.labels.app\.kubernetes\.io/managed-by}{"\n"}helm-release={.metadata.annotations.meta\.helm\.sh/release-name}{"\n"}flux-helm={.metadata.labels.helm\.toolkit\.fluxcd\.io/name}{"\n"}flux-kustomization={.metadata.labels.kustomize\.toolkit\.fluxcd\.io/name}{"\n"}'
```

And the current state, because a restart of a Deployment that is already unhealthy is a different plan:

```bash
# READ-ONLY
source ~/nkp-app-01.env 2>/dev/null
ns='shop'
: "${ns:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" get deploy web -o wide
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" get hpa
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" rollout history deployment/web
```

- `flux-kustomization` or `flux-helm` or `helm-release` set: I tell you the owner, and the restart goes through skill `nkp-platform-apps-gitops` (the change comes back on reconcile otherwise).
- All empty in `shop`: the Deployment is yours and this skill applies.

### Step 2: the right tool for "a quick restart" (W2, W3)

For a restart, `rollout restart` is the correct tool: it is a rolling update, so the pods are replaced one at a time and the app stays up. Scale to 0 and back to 3 takes the app down completely for the whole time between the two commands, and it also drops the Service endpoints.

```bash
# CHANGES  (restarts all pods of one workload with a rolling update)
source ~/nkp-app-01.env 2>/dev/null
ns='shop'; kind='deployment'; name='web'
: "${ns:?}" "${kind:?}" "${name:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" rollout restart "$kind/$name"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" rollout status "$kind/$name" --timeout=600s
```

If you truly want the scale path, it is two CHANGES commands, and I show both in one plan so you see the downtime window:

```bash
# CHANGES  (sets the replica count of one Deployment or StatefulSet)
source ~/nkp-app-01.env 2>/dev/null
ns='shop'; kind='deployment'; name='web'; replicas='0'
: "${ns:?}" "${kind:?}" "${name:?}" "${replicas:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" scale "$kind/$name" --replicas="$replicas"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" rollout status "$kind/$name" --timeout=600s
```

`replicas='3'` in the same block for the way back.

### Step 3: the plan, then stop

The plan states:

- **Target:** the cluster `app-01`, namespace `shop`, `deployment/web`, owner: you (from step 1).
- **Command:** `rollout restart` (recommended), or `scale 0` then `scale 3`.
- **Result:** with `rollout restart`, all pods of `web` are replaced one by one under `maxSurge`/`maxUnavailable` (`25%` each by default [live 2.19.0]), so some pods answer during the change. With `scale 0` then `scale 3`, **all three pods stop and the app is down** until the new pods are ready.
- If an HPA exists, the scale to 0 is reset by the HPA. Then the restart is the only sane option.

Then I stop. "go" and "just run it" are not "yes" — rule 2 asks for the word "yes" to the shown plan, and a plan I have not shown is not approved either. The user typing "yes" after this plan is the gate.

---

## kubernetes-core K7

**Skills used:** `nkp` (router) → `kubernetes-core`, `SKILL.md` step 5 (RBAC). If the subject turns out to be a Dex user or a workspace role: `nkp-identity-security`, `references/rbac.md`.

### What I would ask first (question tool)

I would ask these with the question tool:

1. Is `~/nkp-app-01.env` the env file for cluster `app-01`? (Recommended: yes)
2. Does the CI job need only Deployments in `staging`, or also Services, ConfigMaps, and logs (the `edit` set)? (Recommended: `edit` in `staging` only, if it deploys a whole app)
3. Is this ServiceAccount `build/ci` yours to change, or is it a platform one?

### Step 1: read the message

`User "system:serviceaccount:build:ci" cannot create resource "deployments" in API group "apps" in the namespace "staging"` has five parts, and a Role needs exactly these: the **subject** (`system:serviceaccount:build:ci`, that is ServiceAccount `ci` in namespace `build`), the **verb** (`create`), the **resource** (`deployments`), the **API group** (`apps`), and the **namespace** (`staging`). The ServiceAccount lives in `build`, the object is in `staging`, and a RoleBinding is namespace-scoped, so it must live in `staging`.

### Step 2: prove it, and see what is bound now (READ-ONLY, step 5)

```bash
# READ-ONLY
source ~/nkp-app-01.env 2>/dev/null
ns='staging'; who='system:serviceaccount:build:ci'
: "${ns:?}" "${who:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" auth whoami
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" auth can-i --list --as="$who"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get rolebindings -n "$ns" -o custom-columns='NAME:.metadata.name,ROLE:.roleRef.kind/.roleRef.name,SUBJECTS:.subjects[*].name'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get clusterrolebindings -o custom-columns='NAME:.metadata.name,ROLE:.roleRef.name,SUBJECTS:.subjects[*].name' | grep -F -e "${who##*:}"
```

And the one action from the error:

```bash
# READ-ONLY
source ~/nkp-app-01.env 2>/dev/null
ns='staging'
: "${ns:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" auth can-i create deployments -n "$ns" --as=system:serviceaccount:build:ci
```

`auth can-i` asks the API server and changes nothing. It prints `no`, which confirms the message. The RoleBinding list in `staging` shows the bindings that exist: a binding in `build` (the ServiceAccount namespace) does not help, because it grants nothing in `staging`.

### Step 3: the fix (CHANGES, plan first, "yes" after)

One namespace, one ServiceAccount: a **RoleBinding** in `staging` to the built-in ClusterRole `edit`. A RoleBinding to a ClusterRole gives its rights in one namespace only, which is exactly the need.

```bash
# CHANGES  (gives one ServiceAccount the "edit" rights in one namespace)
source ~/nkp-app-01.env 2>/dev/null
ns='staging'; sa='ci'
: "${ns:?}" "${sa:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" create rolebinding "$sa-edit" --clusterrole=edit --serviceaccount="build:$sa"
```

Careful with the two namespaces in that line: `-n staging` is where the **binding** goes, and `--serviceaccount=build:ci` is where the **ServiceAccount** lives. A plain `--serviceaccount="$ns:$sa"` would point at `staging/ci`, which probably does not exist, and the binding would then grant the rights to nobody.

The plan says: target the cluster `app-01`, namespace `staging`, a new RoleBinding `ci-edit`; result: ServiceAccount `build/ci` gets the `edit` ClusterRole rights in `staging` only, so it can create Deployments there and still cannot touch `build`, `payments`, or any cluster-scoped object.

If you want less than `edit` (for example Deployments and Services only), the alternative is a narrow Role in `staging` plus a RoleBinding to it. Then I write the Role from `kubectl explain` fields (step 2), and the same plan/"yes" flow applies.

Not this:

- `cluster-admin` (or any ClusterRoleBinding) for a one-namespace need. That gives the CI job the whole cluster, including Secrets in every namespace.
- A RoleBinding in `build`. It grants nothing in `staging`, which is the namespace in the error.

### Step 4: the check after "yes" (READ-ONLY)

```bash
# READ-ONLY
source ~/nkp-app-01.env 2>/dev/null
ns='staging'
: "${ns:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" auth can-i create deployments -n "$ns" --as=system:serviceaccount:build:ci
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get rolebindings -n "$ns" -o custom-columns='NAME:.metadata.name,ROLE:.roleRef.kind/.roleRef.name,SUBJECTS:.subjects[*].name'
```

Done when `can-i` prints `yes` and the binding row shows `Role/ClusterRole edit` with subject `ci`. Then the CI job runs again.

---

## kubernetes-core K8

**Skills used:** `nkp` (router) → `kubernetes-core`, `SKILL.md` step 1 and step 2 (`kubectl explain`) + `references/scheduling.md` S1 (the `Too many pods` row, which is where the 110 comes from). For the kubelet settings: `nkp-cluster-lifecycle`, `references/variables.md` V4.

Short answer: the skills have one of your three facts, and the other two are **not in the skills**. I will not guess a number for you.

### 1. Default `--max-pods` on NKP worker nodes

The skills state that the lab nodes have allocatable `pods` = 110 [live 2.19.0] (skill `kubernetes-core`, `references/scheduling.md`, the `Too many pods` row). That is the observed allocatable value of the live reference cluster, not a documented NKP default, and it is not necessarily the value on your nodes. Read yours (READ-ONLY):

```bash
# READ-ONLY
source ~/nkp-app-01.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get nodes -o custom-columns='NAME:.metadata.name,PODS:.status.allocatable.pods,CPU:.status.allocatable.cpu,MEM:.status.allocatable.memory'
```

To see whether NKP sets it explicitly, read the pool's `kubeletConfiguration` in the NKPCluster (READ-ONLY, no Secret):

```bash
# READ-ONLY
source ~/nkp-app-01.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get nkpcluster "$CLUSTER_NAME" -o jsonpath='{.spec.capiCluster.topology.workers.machineDeployments[*].variables.overrides[*].value.kubeletConfiguration.maxPods}{"\n"}'
```

An empty line: NKP sets no `maxPods`, so the kubelet default applies — and that default is not in the skills. The allowed input range in 2.19 is 50-256 (`nkp-cluster-lifecycle`, `references/variables.md` V4), and a change **replaces the nodes of that pool** [pdf p.993]. Owner skill: `nkp-cluster-lifecycle`, step 3 (pool block, `field='kubeletConfiguration'`).

### 2. Image GC threshold

Not in the skills. There is no default number for `imageGCHighThresholdPercent`/`imageGCLowThresholdPercent` anywhere in the skills, and I will not invent one. What the skills do give: the field names and their range (0-100) in `workerConfig.kubeletConfiguration` / `clusterConfig.controlPlane.kubeletConfiguration` (`nkp-cluster-lifecycle`, `references/variables.md` V4), and that a change replaces the nodes [pdf p.993].

Two READ-ONLY checks that do not print Secret data:

```bash
# READ-ONLY
source ~/nkp-app-01.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get nkpcluster "$CLUSTER_NAME" -o jsonpath='{.spec.capiCluster.topology.workers.machineDeployments[*].variables.overrides[*].value.kubeletConfiguration.imageGCHighThresholdPercent}{" "}{.spec.capiCluster.topology.workers.machineDeployments[*].variables.overrides[*].value.kubeletConfiguration.imageGCLowThresholdPercent}{"\n"}'
```

```bash
# READ-ONLY
source ~/nkp-app-01.env 2>/dev/null
node=''
: "${node:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get --raw "/api/v1/nodes/$node/proxy/configz"
```

The first line shows the NKPCluster value (empty means NKP does not set it). The second is the live kubelet configuration of one node; it needs `get nodes/proxy` on the kubeconfig, which the admin kubeconfig has. If you prefer not to use the node proxy, the same values are in the kubelet config file on the node (USER-TERMINAL on the node, over SSH as user `konvoy`):

```bash
# USER-TERMINAL  (on the node, over SSH as user konvoy; the user runs it and sends the output)
sudo grep -E 'imageGC(High|Low)ThresholdPercent|maxPods' /var/lib/kubelet/config.yaml
```

### 3. In-place pod resize

Not in the skills. The cluster is Kubernetes v1.36.2 [live 2.19.0], but whether the feature gate and the `resizePolicy` field are usable there is not stated in the skills, and NKP does not document it. So I do not say "supported" or "not supported". Step 2 checks the cluster itself (READ-ONLY):

```bash
# READ-ONLY
source ~/nkp-app-01.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" explain pod.spec.containers.resizePolicy
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" explain pod.status.resize
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" version
```

If `resizePolicy` is in the schema of your API server, the field exists there; then a test on one non-production pod answers whether it works in practice (CHANGES: a `set resources` on one pod-owning workload plus a read of `status.resize`, with a plan and a "yes"). Without that evidence I tell you: not in the skills, check it on a test workload first.

### What I will not do

- I will not give a GC threshold percentage. It is not in the skills.
- I will not say in-place resize is supported or unsupported without the check above.
- I will not make up an UNKNOWN id for these. The skills have no UNKNOWN line for them, so the honest answer is "not in the skills" plus the checks.
