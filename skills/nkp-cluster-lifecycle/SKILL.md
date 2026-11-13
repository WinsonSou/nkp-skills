---
name: nkp-cluster-lifecycle
description: >
  NKP day 2 on an existing cluster: edit the NKPCluster (ClusterClass variables clusterConfig and
  workerConfig), add, scale, change, or delete node pools (also GPU and Metal pools), cluster autoscaler,
  MachineHealthChecks, kubelet settings, control-plane certificate renewal, replace a node, delete a cluster.
metadata:
  nkp_versions: "2.19"
  last_verified: "2026-11-02"
  sources: "live 2.19.0, pdf 2.19"
---

# NKP cluster lifecycle (day 2)

<!-- RULES:BEGIN -->
## Rules for every NKP skill

1. **Marks.** Line 1 of each command block is `# READ-ONLY`, `# CHANGES`, or `# USER-TERMINAL`. CHANGES: it changes a cluster, the infrastructure, a registry, the container engine, or a file on the operator host. USER-TERMINAL: it shows a secret on the screen, or it runs on another host (the text after the mark names the host). Give it to the user to run in their own terminal. Do not run it.
2. **Approval.** Before a CHANGES block, show the command, the target, and the result. Stop. Run it only after the user types "yes" to that plan. "Just run it" is not "yes". If the user answers with another word (for example "proceed" or "ok"), ask them to type "yes".
3. **Env files.** Run blocks with bash. `~/nkp-site.env` holds the site values and the secrets. `~/nkp-<cluster>.env` holds the values of one cluster. Its first line is `source ~/nkp-site.env 2>/dev/null`. Line 2 of a block is `source ~/nkp-<cluster>.env 2>/dev/null` when the block uses a cluster-file variable. Otherwise line 2 is `source ~/nkp-site.env 2>/dev/null`. Before you run a block, replace `<cluster>` in `~/nkp-<cluster>.env` with the cluster name. If the user has not named the cluster, keep `~/nkp-<cluster>.env` in the block and ask for the name. Do not take a name from an example or another conversation. After the cluster env file exists, use its real name (for example `~/nkp-dev-01.env`) in every block that you show. Commands use the variables as `"$VAR"`.
4. **Values.** When you know a value, append one line to its file: `echo "export VAR='value'" >> ~/nkp-site.env` (CHANGES). Write a line only after the user gives or confirms the value. Ask first, and write the line in a later reply, after the answer. If the user has not given the value, do not show the append block. Do not put an example or a guessed value in it. Never write an empty value or a placeholder such as `<ip>`. A shell value inside a block (for example `obj=''`) stays empty, with its `:?` guard, until the user gives it. Never put `<...>` text in it. To change a value, append a new line. The last line wins. Some skill files add a `| File | Site variables |` table with more variables. For a value with no variable in these tables, make an UPPER_SNAKE name and ask the user. If `~/nkp-site.env` does not exist, make it: `touch ~/nkp-site.env && chmod 600 ~/nkp-site.env` (CHANGES).
5. **Secrets.** The user types the secret lines into `~/nkp-site.env` with an editor. Do not repeat or use a secret from the chat, and do not write it into an example line. Tell the user to put it in the file and to change it. Check a secret only with `printenv VAR >/dev/null` or `[ -n "$(printenv VAR)" ]`. Never print an env file, `env`, `set`, a kubeconfig, or Secret data.
6. **Unknowns.** Use only the UNKNOWN lines in the skills: `UNKNOWN (<id>): <what>. Find out with: <command>`. Run the check or ask the user. For a fact that is not in the skills, say "not in the skills" and give a READ-ONLY check. Never make up an ID or a fact.
7. **Offline.** Use only these skills, the bundle, `--help`, and the cluster. Read versions from the cluster or from `nkp version`.
8. **Tags.** `[live 2.19.0]` live cluster · `[pdf p.N]` NKP 2.19 guide · `[portal]` Nutanix portal · `[field]` not confirmed. Trust them in this order.

| File | Site variables |
|---|---|
| `~/nkp-site.env` | `MGMT_KUBECONFIG` `BUNDLE_DIR` `IMAGE_BUNDLES` `REGISTRY_URL` `REGISTRY_CA_FILE` `PC_ENDPOINT` `PC_CA_FILE` `PC_PROJECT` `PE_CLUSTER` `SUBNET` `STORAGE_CONTAINER` `VM_IMAGE` `SSH_PUBKEY_FILE` `NTP_SERVERS` `NKP_HTTP_PROXY` `NKP_HTTPS_PROXY` |
| `~/nkp-site.env` secrets | `NUTANIX_USER` `NUTANIX_PASSWORD` `REGISTRY_MIRROR_USERNAME` `REGISTRY_MIRROR_PASSWORD` `NUTANIX_REGISTRY_USERNAME` `NUTANIX_REGISTRY_TOKEN` |
| `~/nkp-<cluster>.env` | `CLUSTER_NAME` `CP_VIP` `LB_IP_RANGE` `WORKSPACE_NS` `CLUSTER_KUBECONFIG` `NO_PROXY_LIST` |
<!-- RULES:END -->

## The NKPCluster model

- The **NKPCluster** (`clusters.nkp.nutanix.com/v1alpha1`) owns the CAPI `Cluster` (`spec.capiCluster`) and the `KommanderCluster` (`spec.kommanderCluster`). [live 2.19.0]
- **Edit the NKPCluster. Never edit the CAPI `Cluster`.** The webhook denies it: "CAPI Cluster topology spec is managed by NKPCluster". [live 2.19.0]
- The topology controller owns the MachineDeployments, the KubeadmControlPlane, and the MachineHealthChecks (label `topology.cluster.x-k8s.io/owned`). [live 2.19.0] Change them only through the NKPCluster.
- A node pool is one entry in `spec.capiCluster.topology.workers.machineDeployments[]` (class `default-worker` on AHV, `host-agent-worker` on Metal). [live 2.19.0]
- The NKPCluster is on the management cluster. [live 2.19.0] Its namespace is `kommander` for the management cluster. For a workload cluster, it is the workspace namespace. [live 2.19.0]
- All commands use `"$MGMT_KUBECONFIG"` and `--namespace "$WORKSPACE_NS"`. The CLI default namespaces are wrong for most clusters. [live 2.19.0]
- The agent cannot use `kubectl edit` or the UI. Use the `nkp` CLI, or a JSON patch file (step 3).

## Job → section

| Job | Where |
|---|---|
| Scale or add a node pool (also a GPU pool) | step 4 |
| Change a pool or the control plane: vCPU, memory, disk, image, kubelet, labels, taints, replicas | step 3, then [references/variables.md](references/variables.md) |
| Cluster autoscaler, MachineHealthChecks, certificate renewal, replace a node, delete a pool | [references/maintenance.md](references/maintenance.md) |
| Delete a cluster, then its leftovers (volume groups, mirror Secrets, files) | [references/delete.md](references/delete.md) |
| NKP Metal pools and hosts | [references/metal.md](references/metal.md) |
| Upgrade Kubernetes or NKP, change `version` or `classRef` | skill `nkp-upgrade` |
| Create a cluster | skill `nkp-install` |

## Step 1: Select the cluster

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" get nkpclusters -A -o custom-columns='NAMESPACE:.metadata.namespace,NAME:.metadata.name,CAPI:.status.capiClusterRef.name,PHASE:.status.phase,K8S:.status.kubernetesVersion,CLASS:.spec.capiCluster.topology.classRef.name,MGMT:.metadata.labels.kommander\.d2iq\.io/host'
```

- `MGMT` `true`, or NAMESPACE `kommander`: the management cluster. [live 2.19.0] An empty `CLASS`: no ClusterClass. This skill has no steps for it. Stop.
- UNKNOWN (P-06): which providers make ClusterClass clusters in 2.19. Find out with: `source ~/nkp-site.env 2>/dev/null && kubectl --kubeconfig "$MGMT_KUBECONFIG" get clusters -A -o custom-columns=NAME:.metadata.name,CLASS:.spec.topology.classRef.name`.

Check the cluster env file. Replace `<cluster>` with the NAME first. If the file does not exist, make it with skill `nkp-install`, step "Prepare the env files", item 2 (CHANGES). Then append `CLUSTER_NAME` (the NAME) and `WORKSPACE_NS` (the NAMESPACE) with rule 4. For `CLUSTER_KUBECONFIG`, use skill `nkp-install`, step "Set the kubeconfig variables". On the management cluster, `CLUSTER_KUBECONFIG` is the same file as `MGMT_KUBECONFIG`.

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
for v in CLUSTER_NAME WORKSPACE_NS CLUSTER_KUBECONFIG MGMT_KUBECONFIG; do if [ -n "$(printenv "$v")" ]; then echo "set: $v"; else echo "MISSING: $v"; fi; done
```

Done when: the block prints `set:` for all four names.

## Step 2: Read the topology

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get nkpcluster "$CLUSTER_NAME" -o go-template='{{range $i, $v := .spec.capiCluster.topology.variables}}variable {{$i}}: {{$v.name}}{{"\n"}}{{end}}controlPlane: replicas={{.spec.capiCluster.topology.controlPlane.replicas}}{{"\n"}}{{range $i, $p := .spec.capiCluster.topology.workers.machineDeployments}}pool {{$i}}: name={{$p.name}} class={{$p.class}} replicas={{or $p.replicas "-"}}{{with $p.metadata}}{{with .annotations}} min={{index . "cluster.x-k8s.io/cluster-api-autoscaler-node-group-min-size"}} max={{index . "cluster.x-k8s.io/cluster-api-autoscaler-node-group-max-size"}}{{end}}{{end}}{{with $p.variables}}{{range $j, $o := .overrides}} override {{$j}}={{$o.name}}{{end}}{{end}}{{"\n"}}{{end}}'
nkp get nodepools --cluster-name "$CLUSTER_NAME" --namespace "$WORKSPACE_NS" --kubeconfig "$MGMT_KUBECONFIG"
nkp describe cluster --cluster-name "$CLUSTER_NAME" --namespace "$WORKSPACE_NS" --kubeconfig "$MGMT_KUBECONFIG"
```

Example output of the first command [live 2.19.0]:

```text
variable 0: clusterConfig
controlPlane: replicas=1
pool 0: name=md-0 class=default-worker replicas=- min=4 max=4 override 0=workerConfig
```

- Write down the numbers: `v` = the index of `clusterConfig`, `i` = the index of the pool, `j` = the index of `workerConfig` in that pool. Step 3 uses them.
- A pool made by `nkp` has no `replicas` field. Its annotations `min` and `max` set the size. [live 2.19.0] The webhook rejects `replicas` on a pool that has these annotations. [live 2.19.0]

Done when: you have `v`, and `i` and `j` for each pool that you change.

## Step 3: Change the NKPCluster with a JSON patch

Use this for every change that has no `nkp` command. [references/variables.md](references/variables.md) gives the field paths, the value rules, and which changes replace nodes.

**3a. Write the patch file.** Use one of the blocks. Set the empty values first (from step 2 and the user). JSON values: a number `8`, a string `'"64Gi"'`, an object `'{"maxPods":150}'`. Each patch starts with a `test` op. It stops the patch when the index points to the wrong item. [live 2.19.0]

Pool field (inside `workerConfig` of one pool):

```bash
# CHANGES  (writes the patch file on the operator host; changes no cluster)
source ~/nkp-<cluster>.env 2>/dev/null
i=''; pool=''; j=''; field=''; value=''
: "${i:?}" "${pool:?}" "${j:?}" "${field:?}" "${value:?}"
t='/spec/capiCluster/topology'; p="$t/workers/machineDeployments/$i"
(umask 077 && cat > "$HOME/nkp-$CLUSTER_NAME-patch.json" <<EOF
[{"op":"test","path":"$p/name","value":"$pool"},
 {"op":"test","path":"$p/variables/overrides/$j/name","value":"workerConfig"},
 {"op":"add","path":"$p/variables/overrides/$j/value/$field","value":$value}]
EOF
)
```

Cluster field (inside `clusterConfig`, for example the control plane):

```bash
# CHANGES  (writes the patch file on the operator host; changes no cluster)
source ~/nkp-<cluster>.env 2>/dev/null
v=''; field=''; value=''
: "${v:?}" "${field:?}" "${value:?}"
(umask 077 && cat > "$HOME/nkp-$CLUSTER_NAME-patch.json" <<EOF
[{"op":"test","path":"/spec/capiCluster/topology/variables/$v/name","value":"clusterConfig"},
 {"op":"add","path":"/spec/capiCluster/topology/variables/$v/value/$field","value":$value}]
EOF
)
```

Topology field (not a variable): `field` is `controlPlane/replicas`, `workers/machineDeployments/<i>/healthCheck`, `workers/machineDeployments/<i>/metadata/labels`, or `workers/machineDeployments/<i>/deletion` (drain timeout, for example `value='{"nodeDrainTimeoutSeconds":600}'`; no timeout by default [live 2.19.0]).

```bash
# CHANGES  (writes the patch file on the operator host; changes no cluster)
source ~/nkp-<cluster>.env 2>/dev/null
field=''; value=''
: "${field:?}" "${value:?}"
(umask 077 && cat > "$HOME/nkp-$CLUSTER_NAME-patch.json" <<EOF
[{"op":"test","path":"/metadata/name","value":"$CLUSTER_NAME"},
 {"op":"add","path":"/spec/capiCluster/topology/$field","value":$value}]
EOF
)
```

`add` sets the value when the field exists, and makes it when only the parent exists. For an object or a list, `add` replaces all of it. Read the old value first and keep the items that the user wants.

**3b. Preview with a server dry run.** The API server runs the webhooks and the schema checks, and changes nothing. [live 2.19.0]

```bash
# READ-ONLY  (server dry run: the API server checks the patch and changes nothing)
source ~/nkp-<cluster>.env 2>/dev/null
new=$(kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" patch nkpcluster "$CLUSTER_NAME" --type json --patch-file "$HOME/nkp-$CLUSTER_NAME-patch.json" --dry-run=server -o yaml) && diff <(kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get nkpcluster "$CLUSTER_NAME" -o yaml) - <<< "$new"
```

- `<` lines are the old values. `>` lines are the new values. `generation` also changes.
- An error and no diff: the patch is not valid. "the server rejected our request" or `test failed`: an index or name is wrong. Do step 2 again. Other errors name the bad value. Fix the patch file. Do not apply.
- A dry run that passes is not proof that the change is safe. The API accepts some changes that break a cluster (see "Do not change").

**3c. Show the plan and apply.** The plan has the diff, the cluster, and the effect from [references/variables.md](references/variables.md) (for example "replaces all nodes of pool md-0, one by one"). Stop for "yes".

```bash
# CHANGES  (applies the patch file to the NKPCluster; NKP changes the cluster)
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" patch nkpcluster "$CLUSTER_NAME" --type json --patch-file "$HOME/nkp-$CLUSTER_NAME-patch.json"
```

**3d. Watch.** The block waits 60 s for the controllers to start, then up to 60 minutes. [live 2.19.0]

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
capi=$(kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get nkpcluster "$CLUSTER_NAME" -o jsonpath='{.status.capiClusterRef.name}'); sleep 60
for c in RollingOut=False ScalingUp=False ScalingDown=False Remediating=False Available; do kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" wait "clusters.cluster.x-k8s.io/$capi" --for=condition="$c" --timeout=60m; done
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" wait "nkpclusters.clusters.nkp.nutanix.com/$CLUSTER_NAME" --for=jsonpath='{.status.phase}'=Reconciled --timeout=30m
nkp get nodepools --cluster-name "$CLUSTER_NAME" --namespace "$WORKSPACE_NS" --kubeconfig "$MGMT_KUBECONFIG"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get nodes
```

Done when: each wait prints "condition met", `nkp get nodepools` shows DESIRED = READY with the new values, and all nodes are `Ready`. If a wait times out, use skill `nkp-troubleshooting`.

## Step 4: Node pools with the nkp CLI

**Scale.** Set the empty values. For a scale down, `nodes` can name the nodes to remove (comma-separated). Without it, NKP picks random nodes. [pdf p.934]

```bash
# CHANGES  (sets the size of one node pool; NKP adds or deletes machines and VMs)
source ~/nkp-<cluster>.env 2>/dev/null
pool=''; replicas=''; nodes=''
: "${pool:?}" "${replicas:?}"
nkp scale nodepool "$pool" --replicas "$replicas" ${nodes:+--nodes-to-delete "$nodes"} --cluster-name "$CLUSTER_NAME" --namespace "$WORKSPACE_NS" --kubeconfig "$MGMT_KUBECONFIG"
```

- The new size must be inside the `min` and `max` annotations. If not, `nkp` stops with "greater than the configured max size annotation" (or min). [pdf p.934] Then change `min` and `max` with [references/maintenance.md](references/maintenance.md), section "Pool size and autoscaler".
- UNKNOWN (P-08): whether `nkp scale nodepool` also changes the `min` and `max` annotations. Find out with: `source ~/nkp-<cluster>.env 2>/dev/null && nkp get nodepools --cluster-name "$CLUSTER_NAME" --namespace "$WORKSPACE_NS" --kubeconfig "$MGMT_KUBECONFIG"` and step 2 after the scale.
- Then do step 3d.

**Add a pool on AHV.** The pool name: only `a-z`, `0-9`, `.`, `-`, at most 63 characters. [live 2.19.0] `nkp update nodepool` has no `nutanix` command. Use `nkp create nodepool nutanix`. [live 2.19.0] Defaults: 1 replica, 8 vCPU, 32 GiB, 80 GiB disk. [live 2.19.0] The new pool gets `min` = `max` = replicas. [live 2.19.0] All pools of a cluster use one Prism Central project. [pdf p.1015] For a GPU pool, read [references/variables.md](references/variables.md), section "GPU pool", first.

```bash
# CHANGES  (writes the node pool script and its dry-run output on the operator host; creates no pool)
source ~/nkp-<cluster>.env 2>/dev/null
pool=''; replicas=''; vcpus='8'; memory='32'; disk='80'
: "${pool:?}" "${replicas:?}"
(umask 077 && cat > "$HOME/nkp-$CLUSTER_NAME-nodepool.sh" <<EOF
nkp create nodepool nutanix '$pool' \\
  --cluster-name "\$CLUSTER_NAME" --namespace "\$WORKSPACE_NS" --kubeconfig "\$MGMT_KUBECONFIG" \\
  --vm-image "\$VM_IMAGE" --prism-element-cluster "\$PE_CLUSTER" --subnets "\$SUBNET" \\
  \${PC_PROJECT:+--pc-project "\$PC_PROJECT"} \\
  --replicas $replicas --vcpus $vcpus --memory $memory --disk-size $disk \\
  "\$@"
EOF
bash "$HOME/nkp-$CLUSTER_NAME-nodepool.sh" --dry-run -o yaml > "$HOME/nkp-$CLUSTER_NAME-nodepool-dryrun.yaml")
```

The script keeps the pool values. Read the new pool in the dry run:

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
sed -n '/machineDeployments:/,/kommanderCluster:/p' "$HOME/nkp-$CLUSTER_NAME-nodepool-dryrun.yaml"
```

Show the new pool as the plan. After "yes":

```bash
# CHANGES  (adds the node pool: NKP creates VMs in Prism Central)
source ~/nkp-<cluster>.env 2>/dev/null
bash "$HOME/nkp-$CLUSTER_NAME-nodepool.sh" --wait
```

Then do step 3d.

**Delete a pool:** [references/maintenance.md](references/maintenance.md), section M5.

Done when (scale and add): step 3d passes.

## Do not change

Pod and service CIDR, FIPS mode, the Prism Central project, and the CNI provider of a running cluster. The API accepts some of these changes, but they break the cluster. Details: [references/variables.md](references/variables.md), section V7.

## Related skills

Proxy, CNI, MetalLB, CCM: skill `nkp-networking`. CSI and COSI: skill `nkp-storage-backup`. GPU operator: skill `nkp-gpu-ai`. Registry seeding and Docker Hub credentials: skill `nkp-airgap`. Registry mirror or CA change on a running cluster: this skill, variables.md, V8. A failed rollout: skill `nkp-troubleshooting`.
