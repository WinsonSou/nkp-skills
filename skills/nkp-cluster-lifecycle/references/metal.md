# NKP Metal: day-2 facts

Use this file from skill `nkp-cluster-lifecycle`. It covers only the day-2 work on Metal hosts and Metal node pools that the 2.19 guide documents. Imaging with Foundation Central and the Metal cluster create belong to skill `nkp-install`. The lab has no Metal hosts. All facts here are from the guide, not tested. [pdf]

## MT1. Model

- NKP Metal is new in 2.19. Two models: a full Metal workload cluster (control plane and workers on physical hosts), or a mixed cluster (AHV VMs plus one or more Metal worker pools). [pdf p.741, p.750]
- The management cluster needs a Pro or Ultimate license. [pdf p.744] The host OS is Ubuntu 24.04 only, from the Nutanix ISO. No FIPS and no custom images. [pdf p.745]
- A Metal pool has the class `host-agent-worker`. The ClusterClass is `nkp-host-agent-v2.19.0`. [live 2.19.0] The `workerConfig` field `hostAgent.hostSelector` selects the hosts. [pdf p.763][live 2.19.0]
- The objects: `hosts`, `assignedhosts`, `hostselectorpolicies` (`hostagent.nutanix.com`) in the workspace namespace. [live 2.19.0][pdf p.761]
- The ClusterClass has no MachineHealthCheck for `host-agent-worker`. [live 2.19.0] A failed Metal node is not replaced automatically.
- Hosts register with a bootstrap token. For the token and the imaging, use skill `nkp-install`, NKP Metal file, section M3.

UNKNOWN (P-06): which providers make ClusterClass clusters in 2.19. Find out with: `source ~/nkp-site.env 2>/dev/null && kubectl --kubeconfig "$MGMT_KUBECONFIG" get clusters -A -o custom-columns=NAME:.metadata.name,CLASS:.spec.topology.classRef.name`.

## MT2. Read the hosts

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get hosts --show-labels
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get assignedhosts
nkp get nodepools --cluster-name "$CLUSTER_NAME" --namespace "$WORKSPACE_NS" --kubeconfig "$MGMT_KUBECONFIG"
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get nkpcluster "$CLUSTER_NAME" -o jsonpath='{range .spec.capiCluster.topology.workers.machineDeployments[*]}{.name}{" "}{.class}{" "}{.variables.overrides[0].value.hostAgent.hostSelector}{"\n"}{end}'
```

The last command shows how each Metal pool selects its hosts [pdf p.763]:
- `{"names":[...]}`: hosts by name or UUID ("Individually").
- `{"matchLabels":{...}}`: hosts by label ("By Labels"). NKP picks a free host with these labels.

On Ultimate, a host must be assigned to the workspace first (UI: Administration > Metal Host Inventory > Move to Workspace). On Pro, NKP assigns hosts automatically. [pdf p.747-748]

## MT3. Add a Metal pool

`nkp create nodepool metal` flags [live 2.19.0]: `--hosts` (names or UUIDs; sets the replicas) or `--host-selector key=value` (not both), `--replicas` (default 1), `--labels key=value`, `--taints key[=value]:effect`, `--kubernetes-image-uri`, `--dry-run`, `-o yaml`. The default namespace is `kommander-default-workspace`. Always give `--namespace`.

- Label and taint keys must use the prefix `*.nutanix.com/`, for example `nkp.nutanix.com/node=metal`. [pdf p.761]
- The workspace must have enough free hosts. [pdf p.760]
- Storage: hypervisor-attached volumes do not work on Metal hosts. A mixed cluster needs a separate StorageClass for the Metal pool (`nutanix-volume-metal` in the guide). [pdf p.750-751] Use skill `nkp-storage-backup`, file `csi.md` C3.

```bash
# CHANGES  (writes the Metal pool dry-run output on the operator host; creates no pool)
source ~/nkp-<cluster>.env 2>/dev/null
pool=''; selector=''
: "${pool:?}" "${selector:?}"
(umask 077 && nkp create nodepool metal "$pool" --cluster-name "$CLUSTER_NAME" --namespace "$WORKSPACE_NS" --kubeconfig "$MGMT_KUBECONFIG" --host-selector "$selector" --replicas 1 --dry-run -o yaml > "$HOME/nkp-$CLUSTER_NAME-nodepool-dryrun.yaml")
```

For hosts by name, change `--host-selector "$selector" --replicas 1` to `--hosts "$selector"` (comma-separated names). Read the new pool in the dry run (`SKILL.md` step 4). Show it as the plan. After "yes", run the same command without `--dry-run -o yaml` and without the redirect. Then do `SKILL.md` step 3d.

## MT4. Scale a Metal pool

Use `nkp scale nodepool` (`SKILL.md` step 4). [pdf p.762-764]

- **By Labels pool:** scale up picks a free host that has the labels. Scale down resets the released host and makes it free for other pools. [pdf p.762, p.764]
- **Individually pool:** scale up also needs the new host in `hostSelector.names`. Scale down also needs the released host removed from that list. [pdf p.762, p.764] Do the list change with the `SKILL.md` step 3 pool block: `field='hostAgent/hostSelector/names'; value='["<host-1>","<host-2>"]'` (the full new list). Read the old list in MT2 first.
- `--nodes-to-delete` takes the node names. They are the host names from the imaging. Without it, NKP removes a random node. [pdf p.764]

UNKNOWN (P-12): the order of the `nkp scale` and the `hostSelector.names` change for an Individually pool. Find out with: `source ~/nkp-<cluster>.env 2>/dev/null && kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get assignedhosts -w` during a test in a lab. Until then, tell the user that this order is not confirmed.

## MT5. Host maintenance and removal

**Firmware upgrade (one host at a time)** [pdf p.749-750]. In each block, set `node` to the node name.

1. Drain the node on the workload cluster. The guide shows only `kubectl drain <node-name>`. [pdf p.750] Without the two flags, the drain stops at DaemonSet pods and `emptyDir` volumes. [field] Tell the user that `emptyDir` data is lost.

```bash
# CHANGES  (evicts all pods from the node; the node gets no new pods)
source ~/nkp-<cluster>.env 2>/dev/null
node=''; : "${node:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" drain "$node" --ignore-daemonsets --delete-emptydir-data
```

2. The user upgrades the firmware with the vendor procedure.
3. Wait until the node is `Ready`, then uncordon it:

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
node=''; : "${node:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get nodes "$node"
```

```bash
# CHANGES  (the node gets new pods again)
source ~/nkp-<cluster>.env 2>/dev/null
node=''; : "${node:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" uncordon "$node"
```

**Remove a host from a workspace.** The host must be `Available` (in no cluster). UI only: Administration > Metal Host Inventory > Remove from Workspace. The host goes back to `Unassigned` in the Global workspace. [pdf p.748]

**After a Metal cluster delete.** UNKNOWN (P-12): whether `nkp delete cluster` resets the Metal hosts to `Available`. Find out with: `source ~/nkp-<cluster>.env 2>/dev/null && kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get hosts,assignedhosts` after the delete.
