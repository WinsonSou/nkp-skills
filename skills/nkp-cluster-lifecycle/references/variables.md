# ClusterClass variables: clusterConfig and workerConfig

Use this file from skill `nkp-cluster-lifecycle`, step 3. It gives the field paths, the value rules, and the effect of each change. Facts are from the `nkp-nutanix-v2.19.0` ClusterClass schema. [live 2.19.0]

## V1. Where the fields are

| Variable | Path in the NKPCluster | Scope |
|---|---|---|
| `clusterConfig` | `spec.capiCluster.topology.variables[v].value` | the whole cluster and the control plane |
| `workerConfig` | `spec.capiCluster.topology.workers.machineDeployments[i].variables.overrides[j].value` | one node pool |

- The `field` value in the step 3 patch blocks is the path below the `value`, with `/` between the parts. Example: `nutanix/machineDetails/memorySize`.
- Pools that `nkp` made always have a `workerConfig` override. [live 2.19.0]
- The ClusterClass has only these two variables. [live 2.19.0]

To read the full schema of one field:

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
class=$(kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get nkpcluster "$CLUSTER_NAME" -o jsonpath='{.spec.capiCluster.topology.classRef.name}')
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get clusterclass "$class" -o json | jq '.status.variables[] | select(.name=="workerConfig") | .definitions[0].schema.openAPIV3Schema.properties.kubeletConfiguration'
```

Change `workerConfig` to `clusterConfig` and `kubeletConfiguration` to the field name as necessary. If `jq` is not on the operator host, use `-o yaml` and read the `status.variables` part.

## V2. Effect of a change

CAPI machines are immutable. A change to a machine spec deletes each old machine and makes a new one. [pdf p.24] A pool rolls with `maxSurge: 1`, `maxUnavailable: 0`: one new node joins, then one old node drains and goes. [live 2.19.0] The control plane rolls the same way with `maxSurge: 1`. [live 2.19.0] The controller rolls the control plane first, then the workers. [pdf p.1047]

| Change | Effect |
|---|---|
| `workerConfig` of one pool (machineDetails, kubelet, taints, nodeRegistration) | Replaces all nodes of that pool. [pdf p.993] |
| `clusterConfig.controlPlane.*` (machineDetails, kubelet, taints) | Replaces all control-plane nodes. [pdf p.993] |
| `clusterConfig.proxy` | Replaces nodes. [pdf p.671-672] Use skill `nkp-networking` for the full proxy change. |
| `clusterConfig.controlPlane.autoRenewCertificates` | Sets when CAPI replaces the control-plane nodes. No rollout while the expiry is further away than the new value. See [maintenance.md](maintenance.md), section M3. |
| `clusterConfig.addons.*` | Changes the addon HelmChartProxy. Use the skill that owns the addon (V5). |
| pool `metadata.annotations` (autoscaler min and max) | No rollout. |
| pool `metadata.labels`, `healthCheck` | UNKNOWN (P-09): whether a change of pool labels replaces the nodes. Find out with: `source ~/nkp-<cluster>.env 2>/dev/null && kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get machines -l "cluster.x-k8s.io/cluster-name=$CLUSTER_NAME" -w` after the change. |
| `controlPlane/replicas` | Adds or deletes control-plane nodes. Use 1 (test only), 3, or 5. The API also accepts an even count. [live 2.19.0] etcd needs an odd count for a quorum. |

Before a change that replaces nodes:
- Each pool must have room for one more VM in Prism Central (vCPU, memory, one IP in the subnet pool).
- Workloads with one replica stop for a short time. Pod Disruption Budgets protect critical apps. [pdf p.1003] A PDB that allows 0 disruptions stops the drain.
- On a cluster with one control-plane node, the API is down during the replace.

## V3. workerConfig fields (one pool)

| Field | Rule |
|---|---|
| `nutanix/machineDetails/vcpuSockets` | integer ≥ 1. The CLI flag `--vcpus` sets this. [live 2.19.0] |
| `nutanix/machineDetails/vcpusPerSocket` | integer ≥ 1. The flag `--cores-per-vcpu` sets this. [live 2.19.0] |
| `nutanix/machineDetails/memorySize` | quantity string, for example `"64Gi"` [live 2.19.0] |
| `nutanix/machineDetails/systemDiskSize` | quantity string. Minimum `20Gi`. The dry run does not check this minimum. [live 2.19.0] |
| `nutanix/machineDetails/image` | `{"type":"name","name":"<image>"}`. For an image change during an upgrade, use skill `nkp-upgrade`. |
| `nutanix/machineDetails/subnets`, `cluster` | `[{"type":"name","name":"..."}]`, `{"type":"name","name":"..."}` |
| `nutanix/machineDetails/vmProfile` | Excludes the vCPU, memory, `bootType`, and `gpus` fields. [live 2.19.0] |
| `nutanix/machineDetails/gpus` | See V6. |
| `nutanix/machineDetails/project` | Do not change (one project for each cluster). [pdf p.1015] |
| `nutanix/machineDetails/` + `additionalCategories` | Prism Central categories. |
| `kubeletConfiguration` | See V4. 2.18 and later. [pdf p.993] |
| `taints` | list of `{"key":"...","value":"...","effect":"NoSchedule"}`. Effects: `NoSchedule`, `PreferNoSchedule`, `NoExecute`. Max 32. [live 2.19.0] |
| `nodeRegistration/ignorePreflightErrors` | NKP sets `["SystemVerification"]`. [live 2.19.0] Keep it. |
| `hostAgent/*` | Metal pools only. See [metal.md](metal.md). |

Node labels: set them on the pool, path `workers/machineDeployments/<i>/metadata/labels` (topology block in step 3). CAPI copies machine labels and annotations that match `^(.*\.)?nutanix\.com/.*`, `^nvidia\.com/.*`, and `^amd\.com/.*` to the nodes. [live 2.19.0] Use a key with one of these prefixes, for example `nkp.nutanix.com/pool`. UNKNOWN (P-10): whether a pool label without these prefixes reaches the node. Find out with: `source ~/nkp-<cluster>.env 2>/dev/null && kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get nodes --show-labels`.

Example values for the step 3 pool block: `field='nutanix/machineDetails/memorySize'; value='"64Gi"'`, or `field='taints'; value='[{"key":"dedicated","value":"gpu","effect":"NoSchedule"}]'`.

## V4. kubeletConfiguration (2.18 and later)

- Control plane: `clusterConfig.controlPlane.kubeletConfiguration`. Workers: `workerConfig.kubeletConfiguration`. There is no cluster-wide default. [pdf p.993]
- Only the documented fields are supported. [pdf p.993] A change replaces the nodes. [pdf p.993]

| Field | Rule [live 2.19.0] |
|---|---|
| `maxPods` | 50-256 |
| `podPidsLimit` | 1024-16384 |
| `systemReserved`, `kubeReserved` | map, for example `{"cpu":"500m","memory":"1Gi"}` |
| `enforceNodeAllocatable` | list of `pods`, `system-reserved`, `kube-reserved`, `system-reserved-compressible`, `kube-reserved-compressible` [pdf p.993] |
| `evictionHard`, `evictionSoft`, `evictionSoftGracePeriod` | map |
| `cpuManagerPolicy` | `none`, `static` |
| `memoryManagerPolicy` | `None`, `Static` |
| `topologyManagerPolicy` | `none`, `best-effort`, `restricted`, `single-numa-node` |
| `protectKernelDefaults`, `seccompDefault` | boolean |
| `containerLogMaxSize` | string, for example `"50Mi"` |
| `containerLogMaxFiles` | integer ≥ 2 |
| `imageGCHighThresholdPercent`, `imageGCLowThresholdPercent` | 0-100 |
| `maxParallelImagePulls` | integer ≥ 0 |
| `shutdownGracePeriod`, `shutdownGracePeriodCriticalPods` | duration string, for example `"30s"` |
| `automaticReservations` | object. Read the schema (V1) before you set it. |

Example for the step 3 pool block: `field='kubeletConfiguration'; value='{"maxPods":150}'`. `add` replaces the whole `kubeletConfiguration` object. Read the old object first and put its fields in the new value. A value out of range fails the server dry run (for example "maxPods ... should be greater than or equal to 50"). [live 2.19.0]

## V5. clusterConfig fields

| Field | Owner or rule |
|---|---|
| `controlPlane/nutanix/machineDetails/*` | Same rules as V3. Replaces the control-plane nodes. |
| `controlPlane/kubeletConfiguration` | V4 |
| `controlPlane/taints` | Same form as worker `taints`. |
| `controlPlane/autoRenewCertificates` | `{"daysBeforeExpiry":N}`, N is 0 or 7-360. See [maintenance.md](maintenance.md), section M3. |
| `addons/clusterAutoscaler` | See [maintenance.md](maintenance.md), section M1. |
| `addons/cni`, `addons/serviceLoadBalancer`, `addons/ccm` | skill `nkp-networking` (`serviceLoadBalancer`: its file `metallb.md`). The AHV class allows the CNI providers Calico, Cilium, and Flow. [live 2.19.0] Flow: skill `nkp-flow-cni`. |
| `addons/csi`, `addons/cosi` | skill `nkp-storage-backup`, file `csi.md` C2 |
| `addons/konnectorAgent`, `addons/nfd`, `addons/ingress`, `addons/registry` | Not in this skill. |
| `proxy`, `kubeProxy`, `dns`, `extraAPIServerCertSANs` | skill `nkp-networking` (`proxy`: its file `proxy.md`, X5) |
| `globalImageRegistryMirror`, `imageRegistries` | V8 (this skill). Seeding the registry: skill `nkp-airgap`. |
| `kubernetesImageRepository` | Not in this skill. |
| `encryptionAtRest`, `podSecurityAdmission`, `users` | skill `nkp-identity-security`, file `cluster-security.md` C1-C3 |
| `ntp/servers`, `maxParallelImagePullsPerNode` | Replaces nodes. |
| `etcd/image` | Not in this skill. |
| `nutanix/controlPlaneEndpoint`, `nutanix/prismCentralEndpoint` | Do not change. The PC address cannot change after the deploy. [pdf p.497] |

Other clusterConfig keys in the schema: `aws`, `eks`, `hostAgent`. [live 2.19.0] They are for other providers.

## V6. GPU pool (node-pool part only)

The GPU operator, drivers, MIG, and time-slicing: skill `nkp-gpu-ai`. This section only makes the VMs.

- Flags of `nkp create nodepool nutanix`: `--gpu-name` (vGPU profile or passthrough GPU name), `--gpu-profile-name` (AHV GPU profile, Prism Central 7.6 or later), `--gpu-count` (default 1). `--gpu-name` and `--gpu-profile-name` are mutually exclusive. `--vm-profile` excludes all GPU and size flags. [live 2.19.0]
- On Prism Central 7.6 or later, `--gpu-name` is not valid. Use `--gpu-profile-name`. [pdf p.614][live 2.19.0]
- The create fails when `gpu-count` × replicas is more than the free GPUs in the Prism Element cluster. [pdf p.614] Set `PE_CLUSTER` to the cluster that has the GPUs.
- A vGPU pool needs a vGPU-enabled image and the vGPU token operator first (skill `nkp-gpu-ai`). [pdf p.614]
- In the schema, `gpus` is a list of max 32 items. Each item has `type` `name`, `deviceID`, or `profile`. [live 2.19.0]

Add the GPU flags as extra arguments to the step 4 node pool script, for example `bash "$HOME/nkp-$CLUSTER_NAME-nodepool.sh" --dry-run -o yaml --gpu-profile-name "<profile>" --gpu-count 1`. Ask the user for the profile name. Use the same arguments for the real run. Add a taint so that only GPU pods use the pool (V3): key `nvidia.com/gpu`, effect `NoSchedule`. The GPU operator and the DRA driver tolerate only this key (skill `nkp-gpu-ai`, step 2).

## V8. Registry mirror or registry CA of a running cluster

This skill owns this change. CAREN writes the registry files on each node only at bootstrap, so only new machines get a change. [live 2.19.0] Seed the new registry first (skill `nkp-airgap`, step 4).

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get nkpcluster "$CLUSTER_NAME" -o jsonpath='{range .spec.capiCluster.topology.variables[?(@.name=="clusterConfig")].value}mirror={.globalImageRegistryMirror.url} secret={.globalImageRegistryMirror.credentials.secretRef.name}{"\n"}{range .imageRegistries[*]}registry={.url} secret={.credentials.secretRef.name}{"\n"}{end}{end}'
```

**A. New URL (mirror or registry).** Use step 3 with the cluster field block: `field='globalImageRegistryMirror/url'` and `value` = the URL that the user gives, as a JSON string. Or `field='imageRegistries'` and `value` = the whole list (read the old list first, and keep the items that the user wants).
- The NKPCluster webhook pings each URL from the management cluster. The server dry run rejects a URL that it cannot reach ("Failed to ping registry"). [live 2.19.0]
- Effect: a change of the image registry configuration replaces all nodes of the cluster. [pdf p.287] Say this in the plan (V2 rules).

**B. New CA only (same URL).** The node file `/etc/containerd/certs.d/<registry-host>/ca.crt` comes from the key `ca.crt` of the Secret in the `secret=` column. [live 2.19.0] Set `sec` to that name. The plan: the Secret, the CA file, and "running nodes keep the old CA". After "yes":

```bash
# CHANGES  (replaces the key ca.crt in the registry credentials Secret; the username and password stay)
source ~/nkp-<cluster>.env 2>/dev/null
sec=''
: "${sec:?}" "${REGISTRY_CA_FILE:?}"
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" patch secret "$sec" --type merge -p "$(jq -n --rawfile ca "$REGISTRY_CA_FILE" '{stringData:{"ca.crt":$ca}}')" -o name
```

UNKNOWN (P-27): whether a change to the Secret only (B) rolls the nodes. Find out with: `source ~/nkp-<cluster>.env 2>/dev/null && kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get machines -l "cluster.x-k8s.io/cluster-name=$CLUSTER_NAME"` 10 minutes after the change (a new AGE means a roll). No roll: roll the machines with skill `nkp-troubleshooting`, file `rollouts.md`, R9.

Done when: step 3d passes (A), or every machine is new (B). Then check the nodes with skill `nkp-airgap`, step 5.

## V7. Do not change

| Item | Why |
|---|---|
| Pod CIDR, service CIDR | Cannot change after the create. [pdf p.724] The API dry run accepts the change. [live 2.19.0] |
| FIPS mode | Set only at create time. [pdf p.988] |
| Prism Central project of a pool | One project for the whole cluster. [pdf p.1015] |
| CNI provider of a running cluster | The API accepts it [live 2.19.0], but a CNI switch is not in the skills. Stop. |
| `version`, `classRef`, OS image for an upgrade | Use skill `nkp-upgrade`. |
