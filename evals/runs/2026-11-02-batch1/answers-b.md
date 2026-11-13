# Batch 1 answers (b)

Answers for `/tmp/nkp-eval-b1/prompts-b.md`. Each section is an independent conversation.
No cluster is connected. I did not run the READ-ONLY blocks below. They are the blocks I would run first.
Every reply obeys the rules block: marks, approval before CHANGES, env files, values, secrets, UNKNOWN lines.

---

## nkp-cluster-lifecycle L1

Files read: `skills/nkp/SKILL.md`, `skills/_shared/RULES.md`, `skills/nkp-cluster-lifecycle/SKILL.md`, `skills/nkp-cluster-lifecycle/references/variables.md`, `skills/nkp-cluster-lifecycle/references/maintenance.md`.

**Reply to the user**

Skill `nkp-cluster-lifecycle`, step 4 (scale). I do not guess the namespace. "Default workspace" is the workspace namespace of the cluster, and step 1 shows it.

**1. Find the cluster and its namespace.**

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" get nkpclusters -A -o custom-columns='NAMESPACE:.metadata.namespace,NAME:.metadata.name,CAPI:.status.capiClusterRef.name,PHASE:.status.phase,K8S:.status.kubernetesVersion,CLASS:.spec.capiCluster.topology.classRef.name,MGMT:.metadata.labels.kommander\.d2iq\.io/host'
```

Take the NAMESPACE of `dev-01` from that output. It is `kommander-default-workspace` when the cluster is in the default workspace, but I use the value that the cluster shows. `MGMT` must be empty or `false`. `CLASS` must not be empty. If `CLASS` is empty, this skill has no steps for the cluster. I stop.

**2. Make the cluster env file.** Replace `dev-01` with the NAME. The cluster file does not exist yet, so this block makes it and adds the two values that I know:

```bash
# CHANGES  (makes ~/nkp-dev-01.env with mode 600 and writes CLUSTER_NAME and WORKSPACE_NS)
test -e ~/nkp-dev-01.env || { (umask 077 && echo 'source ~/nkp-site.env 2>/dev/null' > ~/nkp-dev-01.env); }
echo "export CLUSTER_NAME='dev-01'" >> ~/nkp-dev-01.env
echo "export WORKSPACE_NS='kommander-default-workspace'" >> ~/nkp-dev-01.env
```

Target: the operator host only. Result: one cluster env file with two values. I run it after your "yes". If step 1 shows a different NAMESPACE, I write that value instead.

**3. Check the file and read the pool.**

```bash
# READ-ONLY
source ~/nkp-dev-01.env 2>/dev/null
for v in CLUSTER_NAME WORKSPACE_NS CLUSTER_KUBECONFIG MGMT_KUBECONFIG; do if [ -n "$(printenv "$v")" ]; then echo "set: $v"; else echo "MISSING: $v"; fi; done
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get nkpcluster "$CLUSTER_NAME" -o go-template='{{range $i, $v := .spec.capiCluster.topology.variables}}variable {{$i}}: {{$v.name}}{{"\n"}}{{end}}controlPlane: replicas={{.spec.capiCluster.topology.controlPlane.replicas}}{{"\n"}}{{range $i, $p := .spec.capiCluster.topology.workers.machineDeployments}}pool {{$i}}: name={{$p.name}} class={{$p.class}} replicas={{or $p.replicas "-"}}{{with $p.metadata}}{{with .annotations}} min={{index . "cluster.x-k8s.io/cluster-api-autoscaler-node-group-min-size"}} max={{index . "cluster.x-k8s.io/cluster-api-autoscaler-node-group-max-size"}}{{end}}{{end}}{{with $p.variables}}{{range $j, $o := .overrides}} override {{$j}}={{$o.name}}{{end}}{{end}}{{"\n"}}{{end}}'
nkp get nodepools --cluster-name "$CLUSTER_NAME" --namespace "$WORKSPACE_NS" --kubeconfig "$MGMT_KUBECONFIG"
```

`CLUSTER_KUBECONFIG` is missing at this point. I set it with the skill `nkp-install` step "Set the kubeconfig variables". The scale does not need it.

**4. The scale. Plan first.**

Target: pool `md-0` of workload cluster `dev-01`, namespace from step 1, management cluster `"$MGMT_KUBECONFIG"`.
Result: `md-0` goes from its current DESIRED count to 6. NKP adds the missing machines and their VMs in Prism Central, then the new nodes join. No existing node is replaced.

```bash
# CHANGES  (sets the size of one node pool; NKP adds or deletes machines and VMs)
source ~/nkp-dev-01.env 2>/dev/null
pool='md-0'; replicas='6'; nodes=''
: "${pool:?}" "${replicas:?}"
nkp scale nodepool "$pool" --replicas "$replicas" ${nodes:+--nodes-to-delete "$nodes"} --cluster-name "$CLUSTER_NAME" --namespace "$WORKSPACE_NS" --kubeconfig "$MGMT_KUBECONFIG"
```

Before the scale:
- The new size must be inside the `min` and `max` annotations. If step 3 shows `min=4 max=4`, `nkp` stops with "greater than the configured max size annotation" [pdf p.934]. Then I change `min` and `max` first with `references/maintenance.md` section M1 (that also sets the size of a fixed pool). I show that patch as a second plan.
- For a scale up, Prism Central needs 6 minus the current count of free IPs in the subnet pool and free vCPU and memory for the new VMs.
- UNKNOWN (P-08): whether `nkp scale nodepool` also changes the `min` and `max` annotations. Find out with: `source ~/nkp-dev-01.env 2>/dev/null && nkp get nodepools --cluster-name "$CLUSTER_NAME" --namespace "$WORKSPACE_NS" --kubeconfig "$MGMT_KUBECONFIG"` and step 3 after the scale.

**5. Questions before I run it.**
1. `md-0` has annotations. What are its `min` and `max`? I read them in step 3. Is 6 inside them? If not, do we change `min` and `max` to 6?
2. Is a short roll of nothing acceptable? A scale up does not drain nodes. A scale down does. This is a scale up, so no workload stops.

**6. After "yes", watch.**

```bash
# READ-ONLY
source ~/nkp-dev-01.env 2>/dev/null
capi=$(kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get nkpcluster "$CLUSTER_NAME" -o jsonpath='{.status.capiClusterRef.name}'); sleep 60
for c in RollingOut=False ScalingUp=False ScalingDown=False Remediating=False Available; do kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" wait "clusters.cluster.x-k8s.io/$capi" --for=condition="$c" --timeout=60m; done
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" wait "nkpclusters.clusters.nkp.nutanix.com/$CLUSTER_NAME" --for=jsonpath='{.status.phase}'=Reconciled --timeout=30m
nkp get nodepools --cluster-name "$CLUSTER_NAME" --namespace "$WORKSPACE_NS" --kubeconfig "$MGMT_KUBECONFIG"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get nodes
```

Done when each wait prints "condition met", `nkp get nodepools` shows DESIRED = READY 6, and all nodes are `Ready`. If a wait times out, skill `nkp-troubleshooting` owns that. That skill is not installed, so I would give only READ-ONLY checks and stop.

---

## nkp-cluster-lifecycle L2

Files read: `skills/nkp/SKILL.md`, `skills/_shared/RULES.md`, `skills/nkp-cluster-lifecycle/SKILL.md`, `skills/nkp-cluster-lifecycle/references/variables.md`.

**Reply to the user**

I do not patch the CAPI objects. Facts from the skill [live 2.19.0]:
- The topology controller owns the MachineDeployments and the MachineHealthChecks (label `topology.cluster.x-k8s.io/owned`). Change them only through the NKPCluster.
- The webhook rejects a direct edit of `Cluster.spec.topology`: "CAPI Cluster topology spec is managed by NKPCluster".

So a `kubectl patch` on the MachineDeployment is reverted. A `kubectl patch` is still the right tool, but the target is the NKPCluster, with a JSON patch file (skill step 3). `maxPods` is 50-256, so 150 is valid [live 2.19.0].

**1. Select the cluster and read the topology.**

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" get nkpclusters -A -o custom-columns='NAMESPACE:.metadata.namespace,NAME:.metadata.name,CAPI:.status.capiClusterRef.name,PHASE:.status.phase,K8S:.status.kubernetesVersion,CLASS:.spec.capiCluster.topology.classRef.name,MGMT:.metadata.labels.kommander\.d2iq\.io/host'
```

For the management cluster, `MGMT` is `true` and the namespace is `kommander`. I take the NAME from the output and use it as `<cluster>` in `~/nkp-<cluster>.env` (below: `~/nkp-mgmt.env`).

```bash
# CHANGES  (makes the management cluster env file with mode 600 and writes CLUSTER_NAME and WORKSPACE_NS)
test -e ~/nkp-mgmt.env || { (umask 077 && echo 'source ~/nkp-site.env 2>/dev/null' > ~/nkp-mgmt.env); }
echo "export CLUSTER_NAME='<NAME from step 1>'" >> ~/nkp-mgmt.env
echo "export WORKSPACE_NS='kommander'" >> ~/nkp-mgmt.env
```

I fill the NAME from step 1 into that line before I run the block, and I stop for "yes" first. Rule 4: no empty value and no placeholder is ever written to the file. The next block gives `v`, `i` and `j`:

```bash
# READ-ONLY
source ~/nkp-mgmt.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get nkpcluster "$CLUSTER_NAME" -o go-template='{{range $i, $v := .spec.capiCluster.topology.variables}}variable {{$i}}: {{$v.name}}{{"\n"}}{{end}}controlPlane: replicas={{.spec.capiCluster.topology.controlPlane.replicas}}{{"\n"}}{{range $i, $p := .spec.capiCluster.topology.workers.machineDeployments}}pool {{$i}}: name={{$p.name}} class={{$p.class}} replicas={{or $p.replicas "-"}}{{with $p.metadata}}{{with .annotations}} min={{index . "cluster.x-k8s.io/cluster-api-autoscaler-node-group-min-size"}} max={{index . "cluster.x-k8s.io/cluster-api-autoscaler-node-group-max-size"}}{{end}}{{end}}{{with $p.variables}}{{range $j, $o := .overrides}} override {{$j}}={{$o.name}}{{end}}{{end}}{{"\n"}}{{end}}'
```

`i` is the index of `md-0`, `j` is the index of its `workerConfig` override.

**2. Read the old `kubeletConfiguration` of `md-0`.** `add` replaces the whole object, so I must keep the fields that are there now. Use the `j` from step 1 (here `0`):

```bash
# READ-ONLY
source ~/nkp-mgmt.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get nkpcluster "$CLUSTER_NAME" -o jsonpath='{.spec.capiCluster.topology.workers.machineDeployments[0].variables.overrides[0].value.kubeletConfiguration}{"\n"}'
```

**3. Write the patch file.**

```bash
# CHANGES  (writes the patch file on the operator host; changes no cluster)
source ~/nkp-mgmt.env 2>/dev/null
i='<i>'; pool='md-0'; j='<j>'; field='kubeletConfiguration'; value='{"maxPods":150}'
: "${i:?}" "${pool:?}" "${j:?}" "${field:?}" "${value:?}"
t='/spec/capiCluster/topology'; p="$t/workers/machineDeployments/$i"
(umask 077 && cat > "$HOME/nkp-$CLUSTER_NAME-patch.json" <<EOF
[{"op":"test","path":"$p/name","value":"$pool"},
 {"op":"test","path":"$p/variables/overrides/$j/name","value":"workerConfig"},
 {"op":"add","path":"$p/variables/overrides/$j/value/$field","value":$value}]
EOF
)
```

If step 2 shows fields such as `systemReserved`, I put them into `value` too. A lost field changes the kubelet config of the new nodes.

**4. Server dry run.**

```bash
# READ-ONLY  (server dry run: the API server checks the patch and changes nothing)
source ~/nkp-mgmt.env 2>/dev/null
new=$(kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" patch nkpcluster "$CLUSTER_NAME" --type json --patch-file "$HOME/nkp-$CLUSTER_NAME-patch.json" --dry-run=server -o yaml) && diff <(kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get nkpcluster "$CLUSTER_NAME" -o yaml) - <<< "$new"
```

The diff must show `maxPods: 150` added under `kubeletConfiguration`. A `test failed` error means a wrong index. I do step 1 again.

**5. Plan. I stop here for "yes".**

- Target: pool `md-0` of the management cluster, namespace `kommander`.
- Command: the step 3c patch below.
- Result: the new `md-0` machines get kubelet `maxPods: 150`.
- Effect: CAPI machines are immutable. A kubelet change replaces **all** nodes of `md-0`, one by one, with `maxSurge: 1` and `maxUnavailable: 0` [pdf p.993][live 2.19.0]. It does not touch the control plane.
- On the management cluster, Kommander, the NKP UI, Flux and the platform apps move with the pool. Workloads with one replica stop for a short time. A PodDisruptionBudget that allows 0 disruptions stops the drain.
- Prism Central needs room for one more VM (vCPU, memory, one IP) during the roll.

```bash
# CHANGES  (applies the patch file to the NKPCluster; NKP changes the cluster)
source ~/nkp-mgmt.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" patch nkpcluster "$CLUSTER_NAME" --type json --patch-file "$HOME/nkp-$CLUSTER_NAME-patch.json"
```

**6. Watch.** Same block as L1 step 6, with `~/nkp-mgmt.env`.

**Question.** The control plane has its own `kubeletConfiguration` and there is no cluster-wide default [pdf p.993]. Do you want `maxPods: 150` on the control plane too? That change replaces all control-plane nodes. "Just a kubectl patch is fine" is not a "yes" for the plan above.

---

## nkp-cluster-lifecycle L3

Files read: `skills/nkp/SKILL.md`, `skills/_shared/RULES.md`, `skills/nkp-cluster-lifecycle/SKILL.md`, `skills/nkp-cluster-lifecycle/references/maintenance.md`, `skills/nkp-cluster-lifecycle/references/variables.md`.

**Reply to the user**

Do not use `kubectl edit machinehealthcheck`. Two facts [live 2.19.0]:
- NKP makes the MHC and the topology controller owns it (label `topology.cluster.x-k8s.io/owned`). An edit is reverted.
- The guide shows `machineHealthCheck` with `maxUnhealthy` and `kubectl edit` [pdf p.684]. In 2.19 the API **drops that field without an error**, so it has no effect [live 2.19.0]. The field is `healthCheck`, on the pool of the NKPCluster.

**1. Read the cluster, the pool and the machines.**

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" get nkpclusters -A -o custom-columns='NAMESPACE:.metadata.namespace,NAME:.metadata.name,PHASE:.status.phase,CLASS:.spec.capiCluster.topology.classRef.name,MGMT:.metadata.labels.kommander\.d2iq\.io/host'
```

The prompt gives no cluster name. Give it to me. Then the cluster env file is `~/nkp-<that-name>.env`, and every `<cluster>` below is that name. With `CLUSTER_NAME`, `WORKSPACE_NS` in the file, and the pool index `i` for `gpu-0` from the step 2 go-template block:

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get machinehealthchecks -l "cluster.x-k8s.io/cluster-name=$CLUSTER_NAME"
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get machines -l "cluster.x-k8s.io/cluster-name=$CLUSTER_NAME" -o custom-columns='NAME:.metadata.name,NODE:.status.nodeRef.name,PHASE:.status.phase,HEALTHY:.status.conditions[?(@.type=="HealthCheckSucceeded")].status'
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get nkpcluster "$CLUSTER_NAME" -o jsonpath='{.spec.capiCluster.topology.workers.machineDeployments[<i>]}{"\n"}'
```

**2. Read the current `healthCheck` of `gpu-0` first.** `add` replaces the whole object, so I keep every other key (`enabled`, `checks`, `remediation.maxInFlight`):

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get nkpcluster "$CLUSTER_NAME" -o jsonpath='{.spec.capiCluster.topology.workers.machineDeployments[<i>].healthCheck}{"\n"}'
```

**3. Stop condition before any patch.** Two cases in which a `maxUnhealthy` bump cannot help:
- `get machinehealthchecks` shows no MHC for the `gpu-0` pool. A Metal pool (class `host-agent-worker`) has **no** MHC in the ClusterClass [live 2.19.0]. Then nothing remediates, and a percentage does nothing. I stop and tell you.
- The unhealthy machines are more than the current threshold, and the pool is small. CAPI replaces unhealthy machines only while 40% or less of the machines are unhealthy (default) [live 2.19.0][pdf p.24].

**4. Write the patch file. `field` is a topology field.**

```bash
# CHANGES  (writes the patch file on the operator host; changes no cluster)
source ~/nkp-<cluster>.env 2>/dev/null
field='workers/machineDeployments/<i>/healthCheck'; value='{"remediation":{"triggerIf":{"unhealthyLessThanOrEqualTo":"60%"}}}'
: "${field:?}" "${value:?}"
(umask 077 && cat > "$HOME/nkp-$CLUSTER_NAME-patch.json" <<EOF
[{"op":"test","path":"/metadata/name","value":"$CLUSTER_NAME"},
 {"op":"add","path":"/spec/capiCluster/topology/$field","value":$value}]
EOF
)
```

If step 2 printed other keys, `value` must contain them in the same object.

**5. Server dry run.**

```bash
# READ-ONLY  (server dry run: the API server checks the patch and changes nothing)
source ~/nkp-<cluster>.env 2>/dev/null
new=$(kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" patch nkpcluster "$CLUSTER_NAME" --type json --patch-file "$HOME/nkp-$CLUSTER_NAME-patch.json" --dry-run=server -o yaml) && diff <(kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get nkpcluster "$CLUSTER_NAME" -o yaml) - <<< "$new"
```

The diff **must** show the `healthCheck` lines. If it shows no change, the API dropped the field. Stop. Do not apply.

**6. Plan. I stop here for "yes".**
- Target: pool `gpu-0` of cluster `<cluster>`, namespace `<WORKSPACE_NS>`.
- Result: the pooled MHC remediates while up to 60% of the machines of `gpu-0` are unhealthy. Above 60%, it does nothing.
- Effect: the skill expects no rollout for a `healthCheck` change, but UNKNOWN (P-09): whether a `healthCheck` change or a pool label change replaces the nodes. Find out with: `source ~/nkp-<cluster>.env 2>/dev/null && kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get machines -l "cluster.x-k8s.io/cluster-name=$CLUSTER_NAME" -w`.
- Risk: 60% is more than the 40% default. With a small pool, CAPI can replace most of the pool at one time. For a 2-node pool, 1 of 2 is 50% and 2 of 2 is 100%, so tell me the DESIRED count of `gpu-0` and I say how many machines the new threshold allows.

```bash
# CHANGES  (applies the patch file to the NKPCluster; NKP changes the MHC)
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" patch nkpcluster "$CLUSTER_NAME" --type json --patch-file "$HOME/nkp-$CLUSTER_NAME-patch.json"
```

Then watch (same block as L1 step 6).

**Question.** Why does the MHC refuse to remediate? The skills give the defaults (300 s unhealthy, `unhealthyLessThanOrEqualTo: 40%`, new node 600 s) [live 2.19.0]. If the machines are healthy but the node is bad, a threshold change does nothing. Give me the NODE column and the HEALTHY column of the block in step 1.

---

## nkp-cluster-lifecycle L4

Files read: `skills/nkp/SKILL.md`, `skills/_shared/RULES.md`, `skills/nkp-cluster-lifecycle/SKILL.md`, `skills/nkp-cluster-lifecycle/references/variables.md`, `skills/nkp-cluster-lifecycle/references/maintenance.md`.

**Reply to the user**

This job has two parts. Part 1 (the GPU pool) is in skill `nkp-cluster-lifecycle` step 4 with `references/variables.md` section V6. Part 2 (the NVIDIA operator) is skill `nkp-gpu-ai`. **Skill `nkp-gpu-ai` is not installed.** So I do part 1 and I give no command for part 2.

**Facts for part 1** [live 2.19.0][pdf p.614]:
- `nkp update nodepool` has no `nutanix` command. The tool is `nkp create nodepool nutanix`.
- On Prism Central 7.6 or later, `--gpu-name` is not valid. Use `--gpu-profile-name` with the AHV GPU profile. `--gpu-profile-name` and `--gpu-name` are mutually exclusive.
- `--gpu-count` defaults to 1. The create fails when `gpu-count` × replicas is more than the free GPUs in the Prism Element cluster. `PE_CLUSTER` must be the cluster with the GPUs.
- A **vGPU** pool needs a vGPU-enabled node image and the vGPU token operator **first**. "NVIDIA L40S-48Q" is a profile name with a vGPU-style suffix. The vGPU token operator setup is in `nkp-gpu-ai`, which is not installed.
- The new pool gets `min` = `max` = `--replicas` [live 2.19.0].

**Questions before I touch anything.**
1. Is `NVIDIA L40S-48Q` the name of an AHV GPU **profile** in Prism Central 7.6? A profile is not a passthrough GPU device name.
2. Is it a vGPU profile? If yes, the pool also needs a vGPU-enabled `VM_IMAGE` and the vGPU token operator installed first. That setup is `nkp-gpu-ai`, which is not installed. I cannot do part 1 in the correct order until that is solved. Say if the image is already vGPU-enabled and the operator is already installed.
3. Which Prism Element cluster holds at least 2 free L40S GPUs? That value goes into `PE_CLUSTER`.
4. Is `ml-01` in a workspace namespace? I read it in step 1. I do not assume `kommander-default-workspace`.

**1. Select the cluster and read the topology.**

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" get nkpclusters -A -o custom-columns='NAMESPACE:.metadata.namespace,NAME:.metadata.name,PHASE:.status.phase,K8S:.status.kubernetesVersion,CLASS:.spec.capiCluster.topology.classRef.name,MGMT:.metadata.labels.kommander\.d2iq\.io/host'
```

Then make `~/nkp-ml-01.env` (CHANGES, same block shape as L1 step 2, with `CLUSTER_NAME='ml-01'` and the NAMESPACE from the output), and run the step 2 go-template block. Write down the pool count and the `clusterConfig` index `v`.

**2. Write the node pool script with the GPU flags.**

```bash
# CHANGES  (writes the node pool script and its dry-run output on the operator host; creates no pool)
source ~/nkp-ml-01.env 2>/dev/null
pool='gpu-a'; replicas='2'; vcpus='8'; memory='32'; disk='80'
: "${pool:?}" "${replicas:?}"
(umask 077 && cat > "$HOME/nkp-$CLUSTER_NAME-nodepool.sh" <<EOF
nkp create nodepool nutanix '$pool' \\
  --cluster-name "\$CLUSTER_NAME" --namespace "\$WORKSPACE_NS" --kubeconfig "\$MGMT_KUBECONFIG" \\
  --vm-image "\$VM_IMAGE" --prism-element-cluster "\$PE_CLUSTER" --subnets "\$SUBNET" \\
  \${PC_PROJECT:+--pc-project "\$PC_PROJECT"} \\
  --replicas $replicas --vcpus $vcpus --memory $memory --disk-size $disk \\
  "\$@"
EOF
bash "$HOME/nkp-$CLUSTER_NAME-nodepool.sh" --dry-run -o yaml --gpu-profile-name "NVIDIA L40S-48Q" --gpu-count 1 > "$HOME/nkp-$CLUSTER_NAME-nodepool-dryrun.yaml")
```

`--gpu-count 1` with `--replicas 2` needs 2 free L40S GPUs in `PE_CLUSTER`.

**3. Read the new pool in the dry run.**

```bash
# READ-ONLY
source ~/nkp-ml-01.env 2>/dev/null
sed -n '/machineDeployments:/,/kommanderCluster:/p' "$HOME/nkp-$CLUSTER_NAME-nodepool-dryrun.yaml"
```

Check in that output: `name: gpu-a`, `replicas: 2`, `gpus` with `profile` = `NVIDIA L40S-48Q`, and the `min`/`max` annotations of 2.

**4. Plan for the pool. I stop here for "yes".**
- Target: workload cluster `ml-01`, namespace `<WORKSPACE_NS>`, pool `gpu-a`, 2 VMs.
- Result: NKP makes 2 VMs in Prism Central, each with one `NVIDIA L40S-48Q` GPU profile. They join as a new pool. No existing node is replaced.
- Taint: I add `dedicated=gpu:NoSchedule` afterwards (step 1 topology block, `field='workers/machineDeployments/<i>/metadata/labels'` for labels and the pool block with `field='taints'`). Tell me if you want it, and if the GPU operator must tolerate it.
- If the GPU count is too high for the free GPUs, the create fails and makes no pool.
- The script takes the mirror password and the Docker Hub token only as flags. Other users on the host can see them in the process list.

```bash
# CHANGES  (adds the node pool: NKP creates VMs in Prism Central)
source ~/nkp-ml-01.env 2>/dev/null
bash "$HOME/nkp-$CLUSTER_NAME-nodepool.sh" --wait --gpu-profile-name "NVIDIA L40S-48Q" --gpu-count 1
```

Then watch with the L1 step 6 block. Done when `nkp get nodepools` shows `gpu-a` DESIRED = READY 2 and both nodes are `Ready`.

**5. Part 2: the NVIDIA operator. Skill `nkp-gpu-ai` is not installed.**
I give no CHANGES command for it. Only these READ-ONLY checks, from the skills that are loaded. Label: not from a skill.

```bash
# READ-ONLY  (not from a skill: READ-ONLY checks only)
source ~/nkp-ml-01.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get nodes --show-labels
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n node-feature-discovery get pods
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get clusterapps
nkp describe cluster --cluster-name "$CLUSTER_NAME" --namespace "$WORKSPACE_NS" --kubeconfig "$MGMT_KUBECONFIG"
```

Facts I can state: NFD runs in namespace `node-feature-discovery` and gives the GPU node labels [live 2.19.0]; the GPU operator is a Pro and Ultimate app [pdf p.295-297]; the tier of each app is the ClusterApp annotation `apps.kommander.d2iq.io/licensing` [live 2.19.0]. The operator install steps are not in the installed skills. I stop there.

---

## nkp-cluster-lifecycle L5

Files read: `skills/nkp/SKILL.md`, `skills/_shared/RULES.md`, `skills/nkp-cluster-lifecycle/SKILL.md`, `skills/nkp-cluster-lifecycle/references/delete.md`.

**Reply to the user**

A cluster delete cannot be undone. The rules block says a plan needs "yes" and, for a delete, `references/delete.md` D2 also needs **the exact cluster name in the same message**. "yes I'm sure, go" has no cluster name. So I show the plan and the safety gate now, and I run nothing.

**D1. Identify the cluster.**

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" get nkpclusters -A
```

Take the NAMESPACE of `test-02`. The default workspace is usually `kommander-default-workspace`, but I use the value from the output. `nkp delete cluster` uses `kommander` when you give no `--namespace` [live 2.19.0], so every block gives it.

**Make the cluster env file** (`~/nkp-test-02.env`): the same CHANGES block shape as L1 step 2, with `CLUSTER_NAME='test-02'` and the NAMESPACE from the output. I run it after your "yes".

**D2. Safety gate (READ-ONLY).**

```bash
# READ-ONLY
source ~/nkp-test-02.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get nkpcluster "$CLUSTER_NAME" -o custom-columns='NAMESPACE:.metadata.namespace,NAME:.metadata.name,MGMT:.metadata.labels.kommander\.d2iq\.io/host,PHASE:.status.phase,CP:.spec.capiCluster.topology.controlPlane.replicas'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get nodes
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get ns
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get pvc -A
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get svc -A --field-selector spec.type=LoadBalancer
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get nkpclusters -A
```

`CLUSTER_KUBECONFIG` does not exist for `test-02` on this host yet. I set it with the skill `nkp-install` step "Set the kubeconfig variables" (workload cluster) before the gate can run:

```bash
# CHANGES  (writes a local kubeconfig file and appends its path to the cluster env file)
source ~/nkp-test-02.env 2>/dev/null
umask 077 && nkp get kubeconfig --cluster-name "$CLUSTER_NAME" --namespace "$WORKSPACE_NS" --kubeconfig "$MGMT_KUBECONFIG" > "$PWD/$CLUSTER_NAME.conf" && echo "export CLUSTER_KUBECONFIG='$PWD/$CLUSTER_NAME.conf'" >> ~/nkp-test-02.env
```

I stop before this block too, because it writes a file with credentials. Never print the file.

**The plan.**
1. Command: the D3 block below. Cluster `test-02`, namespace `<WORKSPACE_NS>`, management cluster `"$MGMT_KUBECONFIG"`.
2. What goes: all nodes and VMs of `test-02`, all pods, all PVC data in the cluster. First NKP deletes every `LoadBalancer` service (the list from the gate) [pdf p.814].
3. What stays: see below.
4. Approval: `yes test-02` in one message.

```bash
# CHANGES  (deletes the workload cluster: its VMs, nodes, and data; cannot be undone)
source ~/nkp-test-02.env 2>/dev/null
nkp delete cluster --cluster-name "$CLUSTER_NAME" --namespace "$WORKSPACE_NS" --kubeconfig "$MGMT_KUBECONFIG" --timeout 30m
```

Output: "Deleting Services with type LoadBalancer", "Deleting ClusterResourceSets", "Deleting cluster resources", "Waiting for the cluster to be fully deleted", "Deleted ... cluster" [pdf p.814]. Default `--timeout` is 15m; the block uses 30m [live 2.19.0].

**Three stop conditions from the gate.**
- The last command lists an NKPCluster: `test-02` manages other clusters. Delete those first [pdf p.718].
- PVCs hold data that you need. A backup is skill `nkp-storage-backup`, which is **not installed**. Then I ask you to confirm the backup, or to confirm that the data can go.
- The gate shows `MGMT` `true`: then it is the management cluster and `references/delete.md` D4 applies instead. Tell me.

**What stays after the delete (D5).**
- Persistent volumes: on AHV it is UNKNOWN (P-11) whether the Nutanix CSI volume groups stay. Find out with: `source ~/nkp-test-02.env 2>/dev/null && kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get pv -o custom-columns=NAME:.metadata.name,HANDLE:.spec.csi.volumeHandle` **before** the delete. I save that list, and you look for those volume groups in Prism Central afterwards.
- The operator host keeps the files of the cluster: `~/nkp-test-02.env`, the kubeconfig file, the patch and node pool files. `CP_VIP` and `LB_IP_RANGE` are free again. Prism Central images stay.
- The cluster can stay in the UI in `Error` state [pdf p.496]. The fix needs a check that the machines are gone first (D3).

**Question.** Do any PVCs in `test-02` hold data that you need? Give me the answer with the approval: `yes test-02`.

---

## nkp-cluster-lifecycle L6

Files read: `skills/nkp/SKILL.md`, `skills/_shared/RULES.md`, `skills/nkp-cluster-lifecycle/SKILL.md`, `skills/nkp-cluster-lifecycle/references/delete.md`, `skills/nkp-install/SKILL.md`.

**Reply to the user**

Order: the two workload clusters first, the management cluster last. After the management cluster is gone, NKP cannot delete a workload cluster [pdf p.496]. Each delete is its own plan and its own approval with the exact cluster name. I do not group them.

**0. I need the names. READ-ONLY first.**

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" get nkpclusters -A
kubectl --kubeconfig "$MGMT_KUBECONFIG" get nkpclusters -A -o custom-columns='NAMESPACE:.metadata.namespace,NAME:.metadata.name,MGMT:.metadata.labels.kommander\.d2iq\.io/host,PHASE:.status.phase'
```

Give me the two workload cluster names. The row with `MGMT` `true` is the management cluster, and its namespace is `kommander`. The other two are in their workspace namespaces.

**1. Workload cluster A** (same for B): D1, then the D2 safety gate (nodes, namespaces, PVCs, LoadBalancer services, and `get nkpclusters -A` inside the cluster). Stop if the cluster holds other NKPClusters (delete those first), or if PVC data must stay.

Plan, then the block, on `yes <name-A>`:

```bash
# CHANGES  (deletes one workload cluster: its VMs, nodes, and data; cannot be undone)
source ~/nkp-<name-A>.env 2>/dev/null
nkp delete cluster --cluster-name "$CLUSTER_NAME" --namespace "$WORKSPACE_NS" --kubeconfig "$MGMT_KUBECONFIG" --timeout 30m
```

Check both commands show no object for the cluster, then do it again for cluster B.

**2. Management cluster: the D4 gate.**

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" get nkpclusters -A
ls "$BUNDLE_DIR"/konvoy-bootstrap-image-*.tar
```

The first command must list **only** the management cluster. If it lists more, I stop. The second names the bootstrap image for an air-gapped site.

**Plan for the management cluster. I stop here for `yes <mgmt-name>`.**
- Target: the management cluster. Command: the block below. It makes a kind bootstrap cluster on this host, moves the CAPI resources there, then deletes the cluster [live 2.19.0][pdf p.832].
- What goes: Kommander, the NKP UI, all platform apps, every namespace, every VM, every PVC in the management cluster, and the workload clusters are already gone.
- The operator host needs the bootstrap requirements of skill `nkp-install`: a container engine, and 4 CPU and 4 GB memory free [pdf p.718].
- Air-gapped: `BUNDLE_DIR` gives the bootstrap image. On a connected site without `BUNDLE_DIR`, the block uses the default image.

```bash
# CHANGES  (deletes the management cluster; makes a kind bootstrap cluster on this host; cannot be undone)
source ~/nkp-<mgmt>.env 2>/dev/null
nkp delete cluster --self-managed --cluster-name "$CLUSTER_NAME" --namespace "$WORKSPACE_NS" --kubeconfig "$MGMT_KUBECONFIG" --timeout 60m ${BUNDLE_DIR:+--bootstrap-cluster-image "$(ls "$BUNDLE_DIR"/konvoy-bootstrap-image-*.tar)"}
```

**3. After it.**

```bash
# READ-ONLY
docker ps --format '{{.Names}}'
```

On Podman, use `podman ps`. If a name has `bootstrap` in it, `nkp delete bootstrap` removes it (CHANGES, skill `nkp-install`; I show that plan and wait for "yes").

**4. Leftovers (D5).**
- `MGMT_KUBECONFIG` in `~/nkp-site.env` points at a deleted cluster. Tell me if you want that line changed.
- Prism Central images stay. The Metal hosts (if any) need a check (UNKNOWN P-12).
- Local files of each deleted cluster stay: the cluster env file, the kubeconfig file, the patch and node pool files; `CP_VIP` and `LB_IP_RANGE` are free. This block removes them, one cluster at a time, only after "yes":

```bash
# CHANGES  (deletes the local files of one deleted cluster)
source ~/nkp-<cluster>.env 2>/dev/null
ls -l "$CLUSTER_KUBECONFIG" "$HOME/nkp-$CLUSTER_NAME.env" "$HOME/nkp-$CLUSTER_NAME-"*
rm -f -- "$CLUSTER_KUBECONFIG" "$HOME/nkp-$CLUSTER_NAME-"* && rm -f -- "$HOME/nkp-$CLUSTER_NAME.env"
```

Never `~/nkp-site.env`.

**Approvals I need, in order:** `yes <name-A>`, `yes <name-B>`, `yes <mgmt-name>`. Each one deletes data that cannot come back.

---

## nkp-cluster-lifecycle L7

Files read: `skills/nkp/SKILL.md`, `skills/_shared/RULES.md`, `skills/nkp-cluster-lifecycle/SKILL.md`, `skills/nkp-cluster-lifecycle/references/maintenance.md`, `skills/nkp-cluster-lifecycle/references/variables.md`, `skills/nkp/references/components.md`.

**Reply to the user**

Skill `nkp-cluster-lifecycle`, `references/maintenance.md` section M3. The no-upgrade path is CAPI certificate auto-renewal. Since 2.18, CAPI replaces the control-plane machines when the certificates expire within `daysBeforeExpiry` days. Default 180 [pdf p.686][live 2.19.0]. The value is 0 (off) or 7-360 [live 2.19.0]. The field is `clusterConfig.controlPlane.autoRenewCertificates.daysBeforeExpiry`.

**1. Read the real dates and the setting. Do not trust the 40 days yet.**

```bash
# READ-ONLY
source ~/nkp-prod-01.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get nkpcluster "$CLUSTER_NAME" -o jsonpath='expiry={.status.capiCluster.certificatesExpiryDate} daysBeforeExpiry={.status.capiCluster.certificatesRolloutBeforeExpiryDays}{"\n"}'
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get machines -l "cluster.x-k8s.io/cluster-name=$CLUSTER_NAME,cluster.x-k8s.io/control-plane" -o custom-columns='NAME:.metadata.name,CERTS-EXPIRE:.status.certificatesExpiryDate'
```

Make `~/nkp-prod-01.env` first (L1 step 2 shape, with the NAME and NAMESPACE from step 1 of the skill).

**2. Read the result.**
- `daysBeforeExpiry=0`: auto-renewal is off. Then the setting is the cause.
- `daysBeforeExpiry=180` (the default) and 40 days left: the cluster is already past the trigger, so CAPI should already replace the control-plane machines. Then the question is why no rollout started, not how to start one. The UI alerts help: "Renews in X days", "Renewal In Progress", "Renewal Might Fail", "Expired", "Auto-Renewal Disabled", "Unknown" [pdf p.687-688].
- `daysBeforeExpiry` inside 7-360 but below the days left: the setting is too low for `prod-01`.

**3. Change the setting (this is the renewal without an upgrade).**

Plan, then stop for "yes":
- Target: workload cluster `prod-01`, namespace `<WORKSPACE_NS>`.
- Command: the block below with `days='180'` (or 360). The comparison is the days left (40) against the new value: when the days left are fewer than the new value, CAPI replaces all control-plane nodes now [field].
- Result: new control-plane machines with new certificates, one at a time, `maxSurge: 1` [live 2.19.0]. `expiry` becomes about 1 year in the future after the renewal.
- Impact: `prod-01` is production. The API server is served by the remaining control-plane nodes during the roll. With **one** control-plane node, the API is **down** during the replace. Tell me the control-plane replica count (the step 1 `CP` column).
- Prism Central needs room for one extra control-plane VM (vCPU, memory, one IP) during the roll.
- Other providers: `nkp update controlplane` has `aks`, `aws`, `azure`, `gcp`, `nutanix`, `preprovisioned`, `vsphere` [live 2.19.0]. This skill tests only `nutanix`. If `prod-01` is not on AHV, tell me and I check the subcommand with `--help` first.

```bash
# CHANGES  (sets the control-plane certificate renewal; can start a control-plane rollout)
source ~/nkp-prod-01.env 2>/dev/null
days='180'
: "${days:?}"
nkp update controlplane nutanix --control-plane-renew-certificates-before "$days" --cluster-name "$CLUSTER_NAME" --namespace "$WORKSPACE_NS" --kubeconfig "$MGMT_KUBECONFIG"
```

Same result with the step 3 cluster patch block and `field='controlPlane/autoRenewCertificates'`, `value='{"daysBeforeExpiry":180}'`. I use the CLI, as the skill does.

**4. Watch.** L1 step 6 block, with `~/nkp-prod-01.env`. Done when `daysBeforeExpiry` shows the new value, the step 3d waits pass, and `expiry` is about 1 year out.

**What I cannot give you.**
- `nkp update controlplane` with `days='0'` turns renewal off. Then a human must renew by hand before the expiry or the cluster stops [pdf p.686]. The manual procedure is **not in the skills**. Do not ask me for it.
- EKS, AKS and attached clusters: renew by hand; that procedure is not in the skills either.
- A Kubernetes or NKP upgrade also renews the certificates [pdf p.685], but you asked for no upgrade. Skill `nkp-upgrade` is not installed.

**Question.** Is `prod-01` on AHV, and how many control-plane replicas does it have?

---

## nkp-cluster-lifecycle L8

Files read: `skills/nkp/SKILL.md`, `skills/_shared/RULES.md`, `skills/nkp-cluster-lifecycle/SKILL.md`, `skills/nkp-cluster-lifecycle/references/maintenance.md`, `skills/nkp-cluster-lifecycle/references/variables.md`, `skills/nkp/references/components.md`.

**Reply to the user**

The scale-down delay of the cluster autoscaler in NKP 2.19 is **not in the skills**. I do not give a number. The skills give these facts only:
- The autoscaler is the CAREN addon `clusterConfig.addons.clusterAutoscaler` with `strategy: HelmAddon` [live 2.19.0]. The NKPCluster value prints `{"strategy":"HelmAddon"}` when the addon is on and an empty line when it is off.
- A pool has the annotations `cluster.x-k8s.io/cluster-api-autoscaler-node-group-min-size` and `-max-size`. The autoscaler sets the size between them. `min` = `max` means a fixed size, and then the autoscaler has nothing to do [live 2.19.0].
- The autoscaler Deployment is `cluster-autoscaler-<uuid>` in namespace `kommander` for the management cluster [live 2.19.0].

Give me the cluster name first. Then the cluster env file is `~/nkp-<that-name>.env`, and every `<cluster>` in the block below is that name.

**How to find the value. READ-ONLY.**

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get nkpcluster "$CLUSTER_NAME" -o jsonpath='{.spec.capiCluster.topology.variables[?(@.name=="clusterConfig")].value.addons.clusterAutoscaler}{"\n"}'
kubectl --kubeconfig "$MGMT_KUBECONFIG" get deploy -A -l app.kubernetes.io/name=clusterapi-cluster-autoscaler -o yaml | grep -n -E 'scale-down|scale-up|image:|cluster-autoscaler'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get deploy -A -l app.kubernetes.io/name=clusterapi-cluster-autoscaler -o yaml | grep -n -E 'scale-down|scale-up|image:'
```

The `args` of the running Deployment show the flags that are set, and one of them is the delay. A flag that is absent uses the chart default. The `--help` of the autoscaler image is the other source:

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
img=$(kubectl --kubeconfig "$MGMT_KUBECONFIG" get deploy -A -l app.kubernetes.io/name=clusterapi-cluster-autoscaler -o jsonpath='{.items[0].spec.template.spec.containers[0].image}')
echo "$img"
```

**How to change it.** Not in the skills. The supported surface is the ClusterClass schema. Read it before you write anything:

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
class=$(kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get nkpcluster "$CLUSTER_NAME" -o jsonpath='{.spec.capiCluster.topology.classRef.name}')
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get clusterclass "$class" -o yaml | sed -n '/clusterAutoscaler:/,/^ *[a-z]*Configuration:/p'
```

- If the schema shows a delay field, the change goes through the skill step 3 cluster patch block with `field='addons/clusterAutoscaler'` and a `value` object. `add` replaces the whole object, so keep `{"strategy":"HelmAddon"}` in the value. Then the server dry run, the plan, and "yes".
- If the schema shows no delay field, the value is the chart default and a change is **not in the skills**. I would then say: do not patch the Deployment by hand. The autoscaler Deployment belongs to the CAREN addon (a `HelmChartProxy` in `caph` terms). A manual edit is not in the skills, and skill `nkp-upgrade`/`nkp-troubleshooting` are not installed.

**One question.** Which cluster: the management cluster (namespace `kommander`, Deployment `cluster-autoscaler-<uuid>`) or a workload cluster? And which pool do you want to scale down faster? If the pool has `min` = `max`, the delay has no effect at all.

---

## nkp-install E12

Files read: `skills/nkp/SKILL.md`, `skills/_shared/RULES.md`, `skills/nkp-install/SKILL.md`, `skills/nkp-install/references/metal.md`, `skills/nkp-install/references/nutanix.md`, `skills/nkp-cluster-lifecycle/references/metal.md`, `skills/nkp/references/components.md`.

**Reply to the user**

Skill `nkp-install`, provider file `references/metal.md`. Facts [live 2.19.0][pdf p.741-757]:
- An NKP Metal cluster is always a **workload** cluster. There is no `--self-managed` and no bootstrap cluster. Your management cluster on AHV is the right starting point.
- The management cluster needs a **Pro or Ultimate** license. You have Ultimate, so it is supported.
- The host OS is **Ubuntu 24.04 LTS only**, from the Nutanix ISO. No FIPS, no custom images. A `role=gpu` pool on Metal is therefore an Ubuntu pool.
- Defaults: 3 control-plane hosts and 4 workers [live 2.19.0][pdf p.756]. Your 7 servers fit exactly: `role=cp` gives 3, `role=gpu` gives 4.
- `--control-plane-hosts` and `--control-plane-host-selector` are mutually exclusive [live 2.19.0]. I use selectors only.
- A host selector takes a `key=value` label. The `*.nutanix.com/` prefix rule applies to **node** labels and taints that you set on a pool with `nkp create nodepool metal --labels/--taints` [pdf p.761]. For **host** labels in the Metal Host Inventory, the skill gives no prefix rule.
- Ultimate: a host must be **moved to the workspace** in the UI first (Administration > Metal Host Inventory > Move to Workspace). On Pro, NKP assigns automatically [pdf p.747-748].

**Questions.**
1. Are the 7 servers in the `kommander-default-workspace`, or in another workspace? I need `WORKSPACE_NS`.
2. Connected or air-gapped site? If air-gapped, I need `REGISTRY_URL` and `REGISTRY_CA_FILE`, and the registry mirror must have the NKP images and the host OS ISO [pdf p.743].
3. `CP_VIP`: a static IPv4 on the Layer 2 network of the `role=cp` hosts, outside the DHCP pool.
4. `LB_IP_RANGE`: `<first-ip>-<last-ip>`, contiguous, outside the DHCP pool, in the same Layer 2 network [pdf p.756].
5. `PE_CLUSTER` (the AOS cluster with the storage container), `STORAGE_CONTAINER`, and `PC_ENDPOINT` (`https://<host>:9440`). Metal hosts have no hypervisor, so the CSI volume traffic goes directly to Prism Element [pdf p.744, p.754].
6. Optional: an SSH public key file for user `konvoy`.

**M1. Confirm these. I cannot check them from the operator host.**
- Foundation Central is deployed and must stay available [pdf p.743].
- The servers are x86_64, on the hardware compatibility list, and their BMCs are on the out-of-band network.
- The NKP host OS ISO (Ubuntu 24.04 LTS) **and** its metadata JSON are from the Nutanix portal, kept together.
- DHCP on the host network, IPv4 only. DNS and NTP reach the servers. Each server reaches the management cluster.
- The management cluster has Kommander installed.

**M2. Values. Plan (CHANGES), then stop for "yes".**

`MGMT_KUBECONFIG` is the one value you gave me. I write it so that `$HOME` expands when the file is sourced:

```bash
# CHANGES  (writes the site and cluster env files of gpu-01; mode 600)
test -e ~/nkp-site.env || { touch ~/nkp-site.env && chmod 600 ~/nkp-site.env; }
echo 'export MGMT_KUBECONFIG="$HOME/mgmt.conf"' >> ~/nkp-site.env
test -e ~/nkp-gpu-01.env || { (umask 077 && echo 'source ~/nkp-site.env 2>/dev/null' > ~/nkp-gpu-01.env); }
echo "export CLUSTER_NAME='gpu-01'" >> ~/nkp-gpu-01.env
echo "export CP_HOST_SELECTOR='role=cp'" >> ~/nkp-gpu-01.env
echo "export WORKER_HOST_SELECTOR='role=gpu'" >> ~/nkp-gpu-01.env
```

I add `WORKSPACE_NS`, `CP_VIP`, `LB_IP_RANGE`, `PC_ENDPOINT`, `PE_CLUSTER`, `STORAGE_CONTAINER`, and (if air-gapped) `REGISTRY_URL` and `REGISTRY_CA_FILE` as one line each, **after** you give the values. Never an empty value and never a placeholder. The secrets go in by your hand:

```bash
# USER-TERMINAL  (you add the secret lines with an editor)
vi ~/nkp-site.env
```

Secret lines for this case: `NUTANIX_USER`, `NUTANIX_PASSWORD` (Prism Central, for the CSI driver). With a mirror: `REGISTRY_MIRROR_USERNAME`, `REGISTRY_MIRROR_PASSWORD`. Connected with no mirror: `NUTANIX_REGISTRY_USERNAME`, `NUTANIX_REGISTRY_TOKEN`.

Then the check:

```bash
# READ-ONLY
source ~/nkp-gpu-01.env 2>/dev/null
for v in CLUSTER_NAME WORKSPACE_NS CP_VIP LB_IP_RANGE PC_ENDPOINT PE_CLUSTER STORAGE_CONTAINER MGMT_KUBECONFIG NUTANIX_USER NUTANIX_PASSWORD; do if [ -n "$(printenv "$v")" ]; then echo "set: $v"; else echo "MISSING: $v"; fi; done
for v in CP_HOST_SELECTOR CP_HOSTS WORKER_HOST_SELECTOR WORKER_HOSTS; do if [ -n "$(printenv "$v")" ]; then echo "set: $v"; fi; done
```

Done when the first loop prints only `set:` lines and the second prints `set: CP_HOST_SELECTOR` and `set: WORKER_HOST_SELECTOR`.

**M3. Make the bootstrap token. Plan, then stop for "yes".**
Target: the management cluster. Result: a token file `~/nkp-bootstrap-token.conf` with mode 600. It holds a credential. Never print it, and do not change it. Use it only with this management cluster [pdf p.745-746].

```bash
# CHANGES  (creates a bootstrap token in the management cluster and writes it to a local file, mode 600)
source ~/nkp-site.env 2>/dev/null
umask 077 && nkp create bootstrap-token --kubeconfig "$MGMT_KUBECONFIG" > "$HOME/nkp-bootstrap-token.conf"
```

Done when `test -s "$HOME/nkp-bootstrap-token.conf" && echo ok` prints `ok`.

**M4. You do these in Foundation Central and the NKP UI. I cannot.**
1. Add the NKP host OS image (the ISO and its metadata JSON).
2. Onboard the 7 servers (Foundation Central connects to the BMCs).
3. Image the servers and give the bootstrap token file.
4. Ultimate: Administration > Metal Host Inventory, select the hosts with Usage `Unassigned`, Move to Workspace (the workspace from question 1).
5. Optional but needed here: **Edit Labels** so that 3 hosts have `role=cp` and 4 hosts have `role=gpu`.

Then I check:

```bash
# READ-ONLY
source ~/nkp-gpu-01.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get hosts --show-labels
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get assignedhosts
```

Done when the workspace shows 3 free hosts with `role=cp` and 4 free hosts with `role=gpu`, and no host is unlabeled.

**M5. Write the create script. Plan, then stop for "yes".** The script uses a host selector for each group, adds the optional flags only when the variable has a value, and ends with `"$@"` so the dry run adds its flags.

```bash
# CHANGES  (writes the create script of this cluster; creates nothing yet)
source ~/nkp-gpu-01.env 2>/dev/null
(umask 077 && cat > "$HOME/nkp-$CLUSTER_NAME-create.sh" <<'EOF'
nkp create cluster metal \
  --kubeconfig "$MGMT_KUBECONFIG" \
  --namespace "$WORKSPACE_NS" \
  --cluster-name "$CLUSTER_NAME" \
  --control-plane-endpoint-ip "$CP_VIP" \
  --kubernetes-service-load-balancer-ip-range "$LB_IP_RANGE" \
  ${CP_HOST_SELECTOR:+--control-plane-host-selector "$CP_HOST_SELECTOR"} \
  ${CP_HOSTS:+--control-plane-hosts "$CP_HOSTS"} \
  ${WORKER_HOST_SELECTOR:+--worker-host-selector "$WORKER_HOST_SELECTOR"} \
  ${WORKER_HOSTS:+--worker-hosts "$WORKER_HOSTS"} \
  --csi-prism-central-endpoint "$PC_ENDPOINT" \
  --csi-prism-element-cluster "$PE_CLUSTER" \
  --csi-storage-container "$STORAGE_CONTAINER" \
  ${SSH_PUBKEY_FILE:+--ssh-public-key-file "$SSH_PUBKEY_FILE"} \
  ${REGISTRY_URL:+--registry-mirror-url "$REGISTRY_URL"} \
  ${REGISTRY_CA_FILE:+--registry-mirror-cacert "$REGISTRY_CA_FILE"} \
  ${REGISTRY_MIRROR_USERNAME:+--registry-mirror-username "$REGISTRY_MIRROR_USERNAME"} \
  ${REGISTRY_MIRROR_PASSWORD:+--registry-mirror-password "$REGISTRY_MIRROR_PASSWORD"} \
  ${NUTANIX_REGISTRY_TOKEN:+--nutanix-registry-username "$NUTANIX_REGISTRY_USERNAME" --nutanix-registry-password "$NUTANIX_REGISTRY_TOKEN"} \
  "$@"
EOF
)
```

`--control-plane-replicas` and `--worker-replicas` are not needed: a host list sets the replica count, and the selectors give 3 and 4 [live 2.19.0]. If you want other counts, I add those two flags as lines before `"$@"`. The CLI takes the mirror password and the Docker Hub token only as flags, so other users on the host can see them in the process list [live 2.19.0].

**M6. Dry run, check, then create. Two plans.**
Plan 1: write the dry-run objects to `$PWD/gpu-01-dryrun.yaml` (mode 600, holds Secrets, never printed). Result: no cluster.

```bash
# CHANGES  (writes the dry-run objects to a local file; creates no cluster)
source ~/nkp-gpu-01.env 2>/dev/null
umask 077 && bash "$HOME/nkp-$CLUSTER_NAME-create.sh" --dry-run --output yaml > "$PWD/$CLUSTER_NAME-dryrun.yaml"
```

```bash
# READ-ONLY
source ~/nkp-gpu-01.env 2>/dev/null
grep -n -E '^kind:|^  name:|^  namespace:|host:|hostSelector|matchLabels|start:|end:|url:' "$PWD/$CLUSTER_NAME-dryrun.yaml"
```

Check in those lines: the 4 `hostSelector`/`matchLabels` entries, the CP VIP, the LB range start and end, the Prism Central URL, and the 7 host names.

UNKNOWN (P-13): how `nkp create cluster metal` gets the Prism Central credentials for the CSI driver. The help has no credential flag. Find out with: `source ~/nkp-gpu-01.env 2>/dev/null && grep -n -E '^kind: Secret|^  name: ' "$PWD/$CLUSTER_NAME-dryrun.yaml"`. Then confirm that the CSI Secret is in the dry run.

Plan 2: the create. Target: 7 Metal hosts in the workspace on the management cluster. Result: NKP claims 3 hosts for the control plane and 4 for the workers, installs Kubernetes on them, and installs the Nutanix CSI. `--wait` is on by default with a 1h timeout [live 2.19.0]; creation takes longer when hosts are still imaging [pdf p.757].

```bash
# CHANGES  (creates the Metal cluster: claims the hosts, installs Kubernetes on them)
source ~/nkp-gpu-01.env 2>/dev/null
bash "$HOME/nkp-$CLUSTER_NAME-create.sh"
```

**After the create.**
- Skill `nkp-install` step "Set the kubeconfig variables", workload cluster branch: `nkp get kubeconfig` writes `$PWD/gpu-01.conf` and appends `CLUSTER_KUBECONFIG`. CHANGES with credentials; plan, then "yes".
- The Verify step and the Metal checks (M7): every Machine `Running`, node pool READY = DESIRED, one StorageClass `(default)`.
- `role=gpu` hosts: the skills do not cover GPU drivers on Metal hosts. Skill `nkp-gpu-ai` is **not installed**, so I give no operator command. Facts only: NFD runs in `node-feature-discovery` and the Pro/Ultimate tier includes the GPU operators [pdf p.295-297]. I stop there.
- Kommander is not installed on a workload cluster. It is already on the management cluster.

**Approvals I need:** `yes` for the env file, `yes` for the bootstrap token, `yes` for the create script, `yes` for the dry run, `yes` for the create.

---

## nkp-install E13

Files read: `skills/nkp/SKILL.md`, `skills/_shared/RULES.md`, `skills/nkp-install/SKILL.md`, `skills/nkp-install/references/preprovisioned.md`, `skills/nkp-install/references/kommander.md`, `skills/nkp-airgap/SKILL.md`.

**Reply to the user**

Skill `nkp-install`, provider file `references/preprovisioned.md` (management cluster: `--self-managed`). Facts:
- License must be **Pro or Ultimate**. Starter supports only Nutanix AHV [pdf p.27-28]. Which tier does the site have?
- Management cluster: `WORKSPACE_NS='default'`, **not** `kommander` [live 2.19.0][pdf p.768].
- The default storage is `localvolumeprovisioner`. It is not for production [pdf p.766]. Plan a CSI driver later; skill `nkp-storage-backup` is not installed, so I give no CSI command.
- The CNI on pre-provisioned clusters is Calico in the guide [pdf p.765].
- The pod CIDR (`192.168.0.0/16`) and the service CIDR (`10.96.0.0/12`) must not overlap the host subnet or `CP_VIP` [live 2.19.0][pdf p.788].
- The VIP interface name must be the same on each control-plane host [live 2.19.0].
- The OS package bundle is **not** in the air-gapped bundle. Make it on a connected host with `nkp create package-bundle` and put it in `$BUNDLE_DIR/image-artifacts` [pdf p.73].
- The skills do not list the supported host OS versions. I check which OS artifacts the bundle has (below) and you confirm Rocky 9.8.

**Questions.**
1. Cluster name? (Only `a-z`, `0-9`, `.`, `-`.)
2. The 3 control-plane IPs and the 4 worker IPs, comma-separated.
3. `CP_VIP`: a static IPv4 on the Layer 2 network of the control-plane hosts, outside DHCP. `ens192` is the interface on each control-plane host — confirm.
4. `LB_IP_RANGE`: `<first-ip>-<last-ip>` in the host subnet, for MetalLB [pdf p.83]. With no external LB this range gives the service IPs.
5. License tier? (Pro or Ultimate.)
6. The host subnet, so that I check the two CIDRs against it. And 4 local volumes under `/mnt/disks/` on each worker? If not, the local provisioner cannot give volumes [pdf p.767].
7. Registry mirror: `REGISTRY_URL` and `REGISTRY_CA_FILE`. Is it seeded with the NKP images (skill `nkp-airgap` step 4)?

**P1. Confirm these** [pdf p.766-767]: x86_64, an unencrypted private key, `nkpadmin` with passwordless `sudo`, 3 control-plane hosts at 4 cores/16 GB/80 GB free, 4 workers at 8 cores/32 GiB, 15% free on the root file system, swap off, `firewalld` stopped and disabled, the NKP ports open.

**P2. Values. Plan (CHANGES), then stop for "yes".** These four values come from your message:

```bash
# CHANGES  (writes the site and cluster env files; mode 600)
test -e ~/nkp-site.env || { touch ~/nkp-site.env && chmod 600 ~/nkp-site.env; }
echo "export SSH_USER='nkpadmin'" >> ~/nkp-site.env
echo "export SSH_PRIVATE_KEY_FILE='/home/ops/.ssh/nkp'" >> ~/nkp-site.env
test -e ~/nkp-<cluster>.env || { (umask 077 && echo 'source ~/nkp-site.env 2>/dev/null' > ~/nkp-<cluster>.env); }
echo "export WORKSPACE_NS='default'" >> ~/nkp-<cluster>.env
echo "export VIP_INTERFACE='ens192'" >> ~/nkp-<cluster>.env
```

`~/nkp-<cluster>.env` above becomes `~/nkp-<the name from question 1>.env`. I replace `<cluster>` in every later block with that name. I add `CLUSTER_NAME`, `CP_HOSTS`, `WORKER_HOSTS`, `CP_VIP`, `LB_IP_RANGE`, `BUNDLE_DIR`, `REGISTRY_URL`, and `REGISTRY_CA_FILE` as one line each after you give the values. Secrets by your hand:

```bash
# USER-TERMINAL  (you add the secret lines with an editor)
vi ~/nkp-site.env
```

Lines for a mirror: `REGISTRY_MIRROR_USERNAME` and `REGISTRY_MIRROR_PASSWORD`.

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
for v in CLUSTER_NAME CP_HOSTS WORKER_HOSTS CP_VIP LB_IP_RANGE WORKSPACE_NS SSH_USER SSH_PRIVATE_KEY_FILE BUNDLE_DIR REGISTRY_URL; do if [ -n "$(printenv "$v")" ]; then echo "set: $v"; else echo "MISSING: $v"; fi; done
for v in REGISTRY_MIRROR_USERNAME REGISTRY_MIRROR_PASSWORD; do printenv "$v" >/dev/null && echo "set: $v" || echo "MISSING: $v"; done
```

**SSH check to each host. READ-ONLY.**

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
for h in ${CP_HOSTS//,/ } ${WORKER_HOSTS//,/ }; do ssh -i "$SSH_PRIVATE_KEY_FILE" -o BatchMode=yes "$SSH_USER@$h" 'hostname; sudo -n true && echo sudo-ok; swapon --show | wc -l'; done
```

Done when each of the 7 hosts prints its name, `sudo-ok`, and `0`.

**OS artifacts check. READ-ONLY.**

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
ls "$BUNDLE_DIR"/image-artifacts/ "$BUNDLE_DIR"/image-artifacts/images/
```

The 2.19.0 bundle has containerd files for each OS and the Kubernetes image files [live 2.19.0]. Tell me if one of the containerd files is for Rocky 9.8. If not, that is a STOP: the skills do not list the supported host OS for pre-provisioned hosts, and the artifacts are what the hosts need.

**P3. Air-gapped upload. Plan, then stop for "yes".** Target: all 7 hosts over SSH. Result: NKP copies the packages, containerd, and the images and installs them. First confirm that the OS package bundle for Rocky 9.8 is in `$BUNDLE_DIR/image-artifacts` [pdf p.73].

```bash
# CHANGES  (copies packages, containerd, and images to every host over SSH and installs them)
source ~/nkp-<cluster>.env 2>/dev/null
nkp upload image-artifacts \
  --ssh-host "$CP_HOSTS,$WORKER_HOSTS" \
  --ssh-private-key-file "$SSH_PRIVATE_KEY_FILE" \
  --artifacts-directory "$BUNDLE_DIR/image-artifacts"
```

**P4. Inventory file. Plan, then stop for "yes".** Result: `~/nkp-<cluster>-inventory.yaml` with the control-plane pool and the `md-0` pool, and one `address:` line for each host.

```bash
# CHANGES  (writes the inventory file of this cluster; creates nothing yet)
source ~/nkp-<cluster>.env 2>/dev/null
f="$HOME/nkp-$CLUSTER_NAME-inventory.yaml"
{ for pool in control-plane md-0; do
    hosts="$CP_HOSTS"; [ "$pool" = md-0 ] && hosts="$WORKER_HOSTS"
    printf -- '---\napiVersion: infrastructure.cluster.konvoy.d2iq.io/v1alpha1\nkind: PreprovisionedInventory\nmetadata:\n  name: %s-%s\n  namespace: %s\n  labels:\n    cluster.x-k8s.io/cluster-name: %s\n    clusterctl.cluster.x-k8s.io/move: ""\nspec:\n  hosts:\n' "$CLUSTER_NAME" "$pool" "$WORKSPACE_NS" "$CLUSTER_NAME"
    for h in ${hosts//,/ }; do printf '    - address: %s\n' "$h"; done
    printf '  sshConfig:\n    port: 22\n    user: %s\n    privateKeyRef:\n      name: %s-ssh-key\n      namespace: %s\n' "$SSH_USER" "$CLUSTER_NAME" "$WORKSPACE_NS"
  done; } > "$f"
```

Done when `grep -c 'address:' "$f"` prints 7.

**P5. Create script. Plan, then stop for "yes".** `VIP_INTERFACE` gives `--virtual-ip-interface ens192`, so NKP uses the built-in VIP (kube-vip) instead of an external load balancer. Air-gapped management cluster: `--bootstrap-cluster-image` from the bundle.

```bash
# CHANGES  (writes the create script of this cluster; creates nothing yet)
source ~/nkp-<cluster>.env 2>/dev/null
(umask 077 && cat > "$HOME/nkp-$CLUSTER_NAME-create.sh" <<'EOF'
nkp create cluster preprovisioned \
  --self-managed \
  --namespace "$WORKSPACE_NS" \
  --cluster-name "$CLUSTER_NAME" \
  --control-plane-endpoint-host "$CP_VIP" \
  ${VIP_INTERFACE:+--virtual-ip-interface "$VIP_INTERFACE"} \
  --pre-provisioned-inventory-file "$HOME/nkp-$CLUSTER_NAME-inventory.yaml" \
  --ssh-private-key-file "$SSH_PRIVATE_KEY_FILE" \
  --ssh-username "$SSH_USER" \
  ${REGISTRY_URL:+--registry-mirror-url "$REGISTRY_URL"} \
  ${REGISTRY_CA_FILE:+--registry-mirror-cacert "$REGISTRY_CA_FILE"} \
  ${REGISTRY_MIRROR_USERNAME:+--registry-mirror-username "$REGISTRY_MIRROR_USERNAME"} \
  ${REGISTRY_MIRROR_PASSWORD:+--registry-mirror-password "$REGISTRY_MIRROR_PASSWORD"} \
  ${BUNDLE_DIR:+--bootstrap-cluster-image "$(ls "$BUNDLE_DIR"/konvoy-bootstrap-image-*.tar)"} \
  "$@"
EOF
)
```

Note: `--ssh-username` is the user that NKP creates on the nodes (default `konvoy`). It is not `SSH_USER`; NKP connects with the user in the inventory [live 2.19.0]. If you want a different node user, I change that line. The CLI takes the mirror password as a flag; other users on the host can see it.

**P6. Dry run, then create. Two plans.**
- Dry run writes `$PWD/<cluster>-dryrun.yaml` (mode 600, holds Secrets, never printed).
- Create: `--self-managed` makes the kind bootstrap cluster, installs Kubernetes on the 7 hosts over SSH, pivots, and runs Kommander. Default timeout 45m [live 2.19.0]; I add `--timeout 90m` before `"$@"` because there are 7 hosts.

```bash
# CHANGES  (writes the dry-run objects to a local file; creates no cluster)
source ~/nkp-<cluster>.env 2>/dev/null
umask 077 && bash "$HOME/nkp-$CLUSTER_NAME-create.sh" --dry-run --output yaml > "$PWD/$CLUSTER_NAME-dryrun.yaml"
```

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
grep -n -E '^kind:|^  name:|^  namespace:|address:|host:|cidrBlocks|url:' "$PWD/$CLUSTER_NAME-dryrun.yaml"
```

```bash
# CHANGES  (installs Kubernetes on the hosts over SSH; with --self-managed also the bootstrap cluster and the pivot)
source ~/nkp-<cluster>.env 2>/dev/null
bash "$HOME/nkp-$CLUSTER_NAME-create.sh"
```

**P7. MetalLB. Plan, then stop for "yes".** The pre-provisioned provider has no load-balancer range flag [live 2.19.0]. With no external LB, MetalLB gives the service IPs from `LB_IP_RANGE` in Layer 2 mode [pdf p.83-84].

```bash
# CHANGES  (writes metallb-conf.yaml and applies the MetalLB pool to the new cluster)
source ~/nkp-<cluster>.env 2>/dev/null
printf -- 'apiVersion: metallb.io/v1beta1\nkind: IPAddressPool\nmetadata:\n  name: default\n  namespace: metallb-system\nspec:\n  addresses:\n  - %s\n---\napiVersion: metallb.io/v1beta1\nkind: L2Advertisement\nmetadata:\n  name: default\n  namespace: metallb-system\nspec:\n  ipAddressPools:\n  - default\n' "$LB_IP_RANGE" > "$PWD/$CLUSTER_NAME-metallb-conf.yaml"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" apply -f "$PWD/$CLUSTER_NAME-metallb-conf.yaml"
```

**P8. Kommander.** The "Check or install Kommander" step first. If `kommander-flux` and the HelmReleases are absent, the install needs one Rook Ceph override, because the local static provisioner cannot give `volumeMode: Block` PVCs [pdf p.85-86]:

```yaml
rook-ceph-cluster:
    enabled: true
    values: |
      cephClusterSpec:
        storage:
          storageClassDeviceSets: []
          useAllDevices: true
          useAllNodes: true
```

Ceph **deletes the data on the disks it uses**. Tell me which disks Ceph may use, or I use `useAllDevices: false` with a `deviceFilter`. Then:
- `nkp install kommander --init --airgapped > kommander.yaml` (CHANGES, plan + "yes"),
- `nkp install kommander --installer-config kommander.yaml --kubeconfig "$MGMT_KUBECONFIG" --wait-timeout 2h` (CHANGES, plan + "yes").
The install needs one default StorageClass. If no StorageClass is `(default)`, stop [pdf p.942].

**Approvals, in order:** `yes` (env values), `yes` (upload artifacts), `yes` (inventory), `yes` (create script), `yes` (dry run), `yes` (create), `yes` (MetalLB), `yes` (Kommander). Nothing runs before the values in the questions are in the env files.

---

## nkp-install E14

Files read: `skills/nkp/SKILL.md`, `skills/_shared/RULES.md`, `skills/nkp-install/SKILL.md`, `skills/nkp-install/references/cloud.md`, `skills/nkp/references/components.md`, `skills/nkp-install/references/nutanix.md`.

**Reply to the user**

**The CNI: the skills do not confirm it.** UNKNOWN (P-05): the CNI on an EKS cluster. Find out with: `source ~/nkp-eks-01.env 2>/dev/null && kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get pods -A | grep -E 'cilium|calico'`.

What the skills do say, with tags:
- The 2.19 guide says EKS also uses **Cilium** [pdf p.20], and it says Calico is the default CNI on the other providers [pdf p.20].
- On a live 2.19.0 AHV cluster, Cilium is the default and Calico is not installed [live 2.19.0]. That row is AHV only.
- So: the guide points at Cilium, but no live EKS cluster was checked. I do not state it as a fact. Read it from the cluster after the create with the check above. The namespace is `kube-system` for Cilium and `calico-system` for Calico [live 2.19.0][pdf p.187].

**The rest of your case.** Skill `nkp-install`, provider file `references/cloud.md` section C4 (EKS).
- EKS is **Ultimate** only [pdf p.28] (you have Ultimate) and **workload cluster only**: `--self-managed` is refused [pdf p.856].
- The management cluster on AHV plus a workload cluster on EKS is two infrastructures, which needs Ultimate (Multi-Cloud) [pdf p.28]. Supported.
- EKS needs Kubernetes **1.34 or later** [pdf p.856]. Before 1.34 you must use `nkp legacy create cluster eks`, which is deprecated.
- EKS uses the Amazon EKS optimized AMI. No NIB image.
- The NKP version that creates the cluster must also delete it [pdf p.856].
- Prerequisites that you do: the EKS IAM stack and the EBS CSI policy on the node role [pdf p.848-855].

**Steps.**
1. Values. Plan (CHANGES), then "yes": `~/nkp-eks-01.env` with `CLUSTER_NAME='eks-01'` and `WORKSPACE_NS` = the namespace of workspace `team-a`. I do not guess the namespace name; `kubectl --kubeconfig "$MGMT_KUBECONFIG" get workspaces -A` shows it. Site values: `AWS_REGION`, `AWS_PROFILE`, `MGMT_KUBECONFIG`. Secrets, by your hand:

```bash
# USER-TERMINAL  (you add the secret lines with an editor)
vi ~/nkp-site.env
```

Secret lines only when you have no AWS profile on the bastion: `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN`.
2. Only with access keys: refresh the bootstrap credentials in the management cluster (CHANGES, plan + "yes"):

```bash
# CHANGES  (updates the AWS credentials that the management cluster uses)
source ~/nkp-site.env 2>/dev/null
KUBECONFIG="$MGMT_KUBECONFIG" nkp update bootstrap credentials aws
```

3. Check the flags in the CLI before I write the script, as the skill asks:

```bash
# READ-ONLY
nkp create cluster eks --help
```

4. Write the create script (CHANGES, plan + "yes"):

```bash
# CHANGES  (writes the create script of this cluster; creates nothing yet)
source ~/nkp-eks-01.env 2>/dev/null
(umask 077 && cat > "$HOME/nkp-$CLUSTER_NAME-create.sh" <<'EOF'
nkp create cluster eks \
  --kubeconfig "$MGMT_KUBECONFIG" \
  --namespace "$WORKSPACE_NS" \
  --cluster-name "$CLUSTER_NAME" \
  ${REGISTRY_URL:+--registry-mirror-url "$REGISTRY_URL"} \
  ${REGISTRY_MIRROR_USERNAME:+--registry-mirror-username "$REGISTRY_MIRROR_USERNAME"} \
  ${REGISTRY_MIRROR_PASSWORD:+--registry-mirror-password "$REGISTRY_MIRROR_PASSWORD"} \
  "$@"
EOF
)
```

With ECR as the mirror, the guide uses `REGISTRY_MIRROR_USERNAME='AWS'` and the output of `aws ecr get-login-password` as the password [pdf p.855]. You put that password into `~/nkp-site.env` with an editor; I never write it.
5. Dry run (CHANGES: writes `$PWD/eks-01-dryrun.yaml`, no cluster), grep the `kind:`/`name:`/`namespace:` lines, then create (CHANGES). Each with its own plan and "yes". Then the skill step "Set the kubeconfig variables" (workload cluster) and "Verify".
6. Then read the CNI with the UNKNOWN (P-05) command and tell me the answer.

**Question.** Which AWS region and profile, and is there a registry mirror on this site?

---

## nkp-install E15

Files read: `skills/nkp/SKILL.md`, `skills/_shared/RULES.md`, `skills/nkp-install/SKILL.md`, `skills/nkp-install/references/cloud.md`, `skills/nkp/references/components.md`.

**Reply to the user**

**Both answers are not in the skills.**

1. **The default CSI StorageClass name on vSphere:** not in the skills. The skills name a default StorageClass only for Nutanix AHV, `nutanix-volume` [live 2.19.0], and for Azure, the Azure CSI driver [pdf p.197]. For vSphere, `references/cloud.md` says only that "the service `LoadBalancer` setup on vSphere is not in the skills". Skill `nkp-storage-backup` owns CSI and StorageClasses, and it is **not installed**. I do not make up a name.
2. **kube-vip for the API on vSphere:** not in the skills. Facts I can give, with tags:
   - kube-vip is a static pod `kube-vip-<node>` in `kube-system`, and it holds **only the control-plane VIP**. It is not a service load balancer [live 2.19.0]. That row is from one live 2.19.0 AHV cluster.
   - The pre-provisioned provider gives a choice: an external load balancer on 6443, or the built-in virtual IP (kube-vip) with `--virtual-ip-interface` [pdf p.80, p.787][live 2.19.0]. That is the pre-provisioned provider, not vSphere.
   - The vSphere create script uses `--control-plane-endpoint-host "$CP_VIP"` with a static IP outside the DHCP range [pdf p.842][field]. What answers on that IP is not in the skills.
   - On AHV, MetalLB gives the service `LoadBalancer` IPs and the Nutanix CCM gives node metadata only [live 2.19.0].

Give me the cluster name first. Then `~/nkp-<cluster>.env` below is `~/nkp-<that-name>.env`, and I create it if it does not exist.

**READ-ONLY checks that answer both questions on a real vSphere cluster** (not from a skill):

```bash
# READ-ONLY  (not from a skill: answers the two questions from the cluster)
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get storageclass
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get pods -A | grep -E 'kube-vip|metallb|vsphere|cloud-controller|csi'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n kube-system get pods -o wide | grep kube-vip
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get nkpcluster "$CLUSTER_NAME" -o jsonpath='{.spec.capiCluster.topology.variables[?(@.name=="clusterConfig")].value.addons}{"\n"}'
```

The `(default)` mark on one StorageClass line gives the name. A `kube-vip-<node>` pod in `kube-system` on a control-plane node shows that kube-vip holds the API VIP, unless the cluster has an external load balancer in front of it — then ask the platform owner which one.

If you want the supported answer instead of a check, someone with skill `nkp-storage-backup` and skill `nkp-networking` must answer. Both are not installed here, so I give no CHANGES command.

**Question.** Is `eks-01`-style vSphere cluster already created, or do you plan the name now? With a cluster name I make the cluster env file (CHANGES, plan + "yes") and run the checks above.
