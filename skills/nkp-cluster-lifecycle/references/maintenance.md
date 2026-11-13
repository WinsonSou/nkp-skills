# Autoscaler, MachineHealthChecks, certificates, node replace, pool delete

Use this file from skill `nkp-cluster-lifecycle`. Each change uses the step 3 flow of `SKILL.md`: write the patch file, server dry run, plan, apply, watch. Run the `SKILL.md` steps 1 and 2 first.

## M1. Pool size and autoscaler

How NKP sets the size of a pool [live 2.19.0]:
- A pool has the annotations `cluster.x-k8s.io/cluster-api-autoscaler-node-group-min-size` and `-max-size`. `min` = `max`: a fixed size. `min` < `max`: the cluster autoscaler sets the size between them.
- `nkp create nodepool` writes `min` = `max` = `--replicas`, and no `replicas` field.
- The webhook rejects a `replicas` field on a pool that has the annotations.
- The UI calls this "Worker Node Autoscaling". It is off by default. [pdf p.412]
- The autoscaler is the CAREN addon `clusterConfig.addons.clusterAutoscaler` (`strategy: HelmAddon`). [live 2.19.0] It adds nodes when pods are `Pending` for lack of resources. It removes nodes that it does not need. [pdf p.935]
- `nkp scale nodepool` fails when the new size is outside `min` and `max`. [pdf p.934]

Check that the addon is on and that the autoscaler runs:

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get nkpcluster "$CLUSTER_NAME" -o jsonpath='{.spec.capiCluster.topology.variables[?(@.name=="clusterConfig")].value.addons.clusterAutoscaler}{"\n"}'
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get deploy -l app.kubernetes.io/name=clusterapi-cluster-autoscaler
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get deploy -A -l app.kubernetes.io/name=clusterapi-cluster-autoscaler
```

- The first line prints `{"strategy":"HelmAddon"}` when the addon is on. [live 2.19.0] An empty line: the addon is off. To turn it on, use the step 3 cluster block with `field='addons/clusterAutoscaler'; value='{"strategy":"HelmAddon"}'`.
- For the management cluster, the Deployment is `cluster-autoscaler-<uuid>` in namespace `kommander` on the management cluster. [live 2.19.0] For a workload cluster, one of the two `get deploy` lines shows it. Use that kubeconfig and namespace in the log block below.

**Set min and max of one pool.** This also changes the size of a fixed pool (`min` = `max` = the new size). Values are strings. Set the empty values from step 2 and the user.

```bash
# CHANGES  (writes the patch file on the operator host; changes no cluster)
source ~/nkp-<cluster>.env 2>/dev/null
i=''; pool=''; min=''; max=''
: "${i:?}" "${pool:?}" "${min:?}" "${max:?}"
t='/spec/capiCluster/topology'; p="$t/workers/machineDeployments/$i"
a="$p/metadata/annotations/cluster.x-k8s.io~1cluster-api-autoscaler-node-group"
(umask 077 && cat > "$HOME/nkp-$CLUSTER_NAME-patch.json" <<EOF
[{"op":"test","path":"$p/name","value":"$pool"},
 {"op":"add","path":"$a-min-size","value":"$min"},
 {"op":"add","path":"$a-max-size","value":"$max"}]
EOF
)
```

Then do `SKILL.md` steps 3b, 3c, 3d. The plan says: the pool, the old and new `min` and `max`, and the IPs and VMs that the maximum can use in Prism Central. `max` must fit the free IPs in the subnet pool and the Prism Element resources.

Done when: step 3d passes. With `min` < `max`, the autoscaler log shows the pool:

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" logs -l app.kubernetes.io/name=clusterapi-cluster-autoscaler --tail 50
```

If this prints no log lines, and the second `get deploy` line above showed the Deployment, run the same command with `--kubeconfig "$CLUSTER_KUBECONFIG"` and `-n` set to the NAMESPACE from that line.

## M2. MachineHealthChecks (self-healing)

NKP makes one MachineHealthCheck (MHC) for the control plane and one for each pool. The defaults come from the ClusterClass [live 2.19.0]:
- Node condition `Ready` is `False` or `Unknown` for 300 s, or `MemoryPressure`, `DiskPressure`, `PIDPressure`, or `NetworkUnavailable` is `True` for 300 s: the machine is unhealthy.
- A new node that does not join in 600 s is unhealthy.
- CAPI replaces unhealthy machines only when 40% or less of the machines are unhealthy (`unhealthyLessThanOrEqualTo: 40%`). Above 40%, it does nothing. [live 2.19.0][pdf p.24]
- Metal pools (class `host-agent-worker`) have no MHC in the ClusterClass. [live 2.19.0]

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get machinehealthchecks -l "cluster.x-k8s.io/cluster-name=$CLUSTER_NAME"
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get machines -l "cluster.x-k8s.io/cluster-name=$CLUSTER_NAME" -o custom-columns='NAME:.metadata.name,NODE:.status.nodeRef.name,PHASE:.status.phase,HEALTHY:.status.conditions[?(@.type=="HealthCheckSucceeded")].status'
```

**Change the MHC of one pool.** The MHC belongs to the topology. Change it in the NKPCluster, field `healthCheck` of the pool (or `controlPlane/healthCheck`). [live 2.19.0]
- The guide shows `machineHealthCheck` with `maxUnhealthy` and `kubectl edit`. [pdf p.684] In 2.19 the API drops that field without an error, so it has no effect. [live 2.19.0] Use `healthCheck`.
- Fields of `healthCheck` [live 2.19.0]: `enabled` (false turns the MHC off), `checks.nodeStartupTimeoutSeconds`, `checks.unhealthyNodeConditions[]` (`type`, `status`, `timeoutSeconds`), `remediation.triggerIf.unhealthyLessThanOrEqualTo` (for example `"50%"`), `remediation.maxInFlight`.

Use the step 3 topology block. Examples:
- Allow up to 50% unhealthy machines: `field='workers/machineDeployments/<i>/healthCheck'; value='{"remediation":{"triggerIf":{"unhealthyLessThanOrEqualTo":"50%"}}}'` [live 2.19.0]
- Turn off remediation of one pool (for example during a maintenance): `value='{"enabled":false}'`. Turn it on again after the work.

Replace `<i>` with the pool index before you run the block. Then do steps 3b to 3d. The dry-run diff must show the `healthCheck` lines. If the diff shows no change, the field was dropped. Stop.

UNKNOWN (P-09): whether a `healthCheck` change or a pool label change replaces the nodes. Find out with: `source ~/nkp-<cluster>.env 2>/dev/null && kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get machines -l "cluster.x-k8s.io/cluster-name=$CLUSTER_NAME" -w`.

## M3. Control-plane certificate renewal

- The control-plane certificates expire 1 year after the create. A Kubernetes upgrade renews them. [pdf p.685]
- From 2.18, CAPI renews them: it replaces the control-plane machines when the certificates expire within `daysBeforeExpiry` days. Default 180. [pdf p.686][live 2.19.0] Before 2.18, a systemd job on the nodes renewed them. [field] The guide asks you to use only the CAPI method. [pdf p.685]
- The value is 0 (off) or 7-360. [live 2.19.0] The NKPCluster field is `clusterConfig.controlPlane.autoRenewCertificates.daysBeforeExpiry`. [live 2.19.0]
- Not for EKS, AKS, or attached clusters. Renew those by hand. [pdf p.685] The manual procedure is not in the skills.
- The UI shows the alerts "Renews in X days", "Renewal In Progress", "Renewal Might Fail", "Expired", "Auto-Renewal Disabled", and "Unknown". [pdf p.687-688]

Read the expiry date and the setting:

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get nkpcluster "$CLUSTER_NAME" -o jsonpath='expiry={.status.capiCluster.certificatesExpiryDate} daysBeforeExpiry={.status.capiCluster.certificatesRolloutBeforeExpiryDays}{"\n"}'
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get machines -l "cluster.x-k8s.io/cluster-name=$CLUSTER_NAME,cluster.x-k8s.io/control-plane" -o custom-columns='NAME:.metadata.name,CERTS-EXPIRE:.status.certificatesExpiryDate'
```

Change the setting with the `nkp` CLI (`--control-plane-renew-certificates-before`, 0 or 7-360). [live 2.19.0][pdf p.687]

```bash
# CHANGES  (sets the control-plane certificate renewal; can start a control-plane rollout)
source ~/nkp-<cluster>.env 2>/dev/null
days=''
: "${days:?}"
nkp update controlplane nutanix --control-plane-renew-certificates-before "$days" --cluster-name "$CLUSTER_NAME" --namespace "$WORKSPACE_NS" --kubeconfig "$MGMT_KUBECONFIG"
```

- The renewal makes new control-plane machines. [live 2.19.0] The plan compares the days left until `expiry` with the new value. When the days left are fewer than the new value, CAPI replaces all control-plane nodes now. [field] Use this to renew certificates early. On one control-plane node, the API is down during the replace.
- `0` turns the renewal off. Then the user must renew by hand before the expiry, or the cluster stops. [pdf p.686] Tell the user this in the plan.
- Other providers: `nkp update controlplane` has the subcommands `aks`, `aws`, `azure`, `gcp`, `nutanix`, `preprovisioned`, `vsphere`. [live 2.19.0] This skill tests only `nutanix`.

Done when: `daysBeforeExpiry` shows the new value, and `SKILL.md` step 3d passes. After a renewal, `expiry` is about 1 year in the future.

## M4. Replace a node

**Automatic.** The MHC (M2) replaces an unhealthy node after 300 s.

**One worker node.** Delete its Machine on the management cluster. CAPI drains the node, deletes the VM, and the pool makes a new machine. [pdf p.24] First find the Machine of the node:

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get machines -l "cluster.x-k8s.io/cluster-name=$CLUSTER_NAME" -o custom-columns='MACHINE:.metadata.name,NODE:.status.nodeRef.name,POOL:.metadata.labels.topology\.cluster\.x-k8s\.io/deployment-name,PHASE:.status.phase'
node=''
[ -n "$node" ] && kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get pods -A -o wide --field-selector "spec.nodeName=$node"
```

Set `node` to the node that the user names. The plan lists the pods that move. A PDB that allows 0 disruptions stops the drain. [pdf p.1003]

```bash
# CHANGES  (deletes one worker Machine: CAPI drains the node, deletes the VM, and makes a new one)
source ~/nkp-<cluster>.env 2>/dev/null
machine=''
: "${machine:?}"
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" delete machine "$machine" --wait=false
```

Then do `SKILL.md` step 3d. Done when: a new machine is `Running` and the new node is `Ready`.

- To remove a node and make the pool smaller, use `nkp scale nodepool ... --nodes-to-delete` (`SKILL.md` step 4). It marks the Machine with `cluster.x-k8s.io/delete-machine=yes`. [pdf p.934]
- A control-plane node: do not delete its Machine with this block. To replace all control-plane nodes, change a `clusterConfig.controlPlane` field ([variables.md](variables.md), section V2) or the certificate value (M3).
- A Metal node: [metal.md](metal.md).
- For a node that does not start or a drain that does not end, use skill `nkp-troubleshooting`.

## M5. Delete a node pool

NKP drains the nodes, then deletes the machines and the VMs. [pdf p.817] First list the nodes of the pool and the pods on them:

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get machines -l "cluster.x-k8s.io/cluster-name=$CLUSTER_NAME" -o custom-columns='POOL:.metadata.labels.topology\.cluster\.x-k8s\.io/deployment-name,NODE:.status.nodeRef.name,PHASE:.status.phase'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get pods -A -o wide
```

The plan names the pool, its nodes, and the pods that move. If it is the last worker pool, the workloads have no node. Tell the user. After "yes":

```bash
# CHANGES  (deletes one node pool: drains and deletes its nodes and VMs)
source ~/nkp-<cluster>.env 2>/dev/null
pool=''
: "${pool:?}"
nkp delete nodepool "$pool" --cluster-name "$CLUSTER_NAME" --namespace "$WORKSPACE_NS" --kubeconfig "$MGMT_KUBECONFIG"
```

Then do `SKILL.md` step 3d. Done when: step 3d passes and `nkp get nodepools` does not list the pool.
