---
name: nkp-storage-backup
description: >
  NKP storage and backup: Nutanix CSI (ntnx-system), StorageClasses and the default StorageClass, PVC Pending,
  volume attach or detach, VolumeSnapshot, day-1 smoke test (PVC + pod + LoadBalancer + curl), nutanix-volume-metal for Metal pools, localvolumeprovisioner,
  volumes left after a cluster delete; Velero backup, schedule, restore, management cluster disaster recovery;
  Rook Ceph dkp-object-store, COSI, BYOS object storage (Nutanix Objects, S3).
metadata:
  nkp_versions: "2.19"
  last_verified: "2026-11-03"
  sources: "live 2.19.0, pdf 2.19"
---

# NKP storage and backup

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

## The storage parts

| Part | What it is | Facts |
|---|---|---|
| Nutanix CSI | Driver `csi.nutanix.com` 3.9.0 in `ntnx-system`: Deployment `nutanix-csi-controller` (2 pods) and DaemonSet `nutanix-csi-node` (one pod on each node). CAREN installs it (addon `clusterConfig.addons.csi`). [live 2.19.0] | [references/csi.md](references/csi.md) |
| Default StorageClass | AHV: `nutanix-volume` (Nutanix Volumes, `hypervisorAttached: ENABLED`, ext4, `Delete`, `WaitForFirstConsumer`, expansion on). [live 2.19.0] Other providers: [references/csi.md](references/csi.md), C1. | Kommander needs one default StorageClass. [pdf p.942] |
| Snapshots | `snapshot-controller` v8.5.0 in `kube-system` (addon `csi.snapshotController`). VolumeSnapshotClass `nutanix-snapshot-class`, `deletionPolicy: Retain`. [live 2.19.0] | [references/csi.md](references/csi.md), C6 |
| Rook Ceph | Platform apps `rook-ceph` and `rook-ceph-cluster` 1.19.5. Object store `dkp-object-store` for Loki, Velero, Harbor, OpenCost, and NKP Insights only. Not for app volumes. [live 2.19.0][pdf p.646] Pro and Ultimate. [live 2.19.0] | [references/object-storage.md](references/object-storage.md) |
| COSI | Two parts: the CAREN addon `cosi` (controller v0.2.2 in `container-object-storage-system`, on every cluster) and the platform app `cosi-driver-nutanix` 0.6.3 (Pro and Ultimate). [live 2.19.0] | [references/object-storage.md](references/object-storage.md), O5 |
| Velero | Platform app `velero` 12.0.0 (image `velero/velero:v1.18.0`). Pro and Ultimate. It depends on `rook-ceph-cluster`. [live 2.19.0] Default: a daily backup of all namespaces, no volume snapshots. [pdf p.533] | [references/velero.md](references/velero.md) |
| BYOS | Your own object store (Nutanix Objects, S3, an external Ceph) in place of Rook Ceph. Nutanix recommends an external store for Velero in production. [pdf p.510] | [references/velero.md](references/velero.md), [references/object-storage.md](references/object-storage.md) |

Not in this skill: NDK (Nutanix Data Services for Kubernetes) snapshots, replication, and failover: skill `nkp-ndk`. Loki storage values: skill `nkp-observability`. Plain PVC and StatefulSet basics: skill `kubernetes-core`.

## Job → section

| Job | Where |
|---|---|
| Read the storage state of a cluster | step 1 |
| Pod `Pending` with an unbound PVC | step 2 |
| No default StorageClass, two defaults, change the default (also before Kommander) | step 3 |
| A new StorageClass, StorageClass parameters, volume expansion, Nutanix Files | [references/csi.md](references/csi.md), C2-C5 |
| `nutanix-volume-metal` for the Metal pool of a mixed cluster | [references/csi.md](references/csi.md), C3 |
| `VolumeSnapshot` | [references/csi.md](references/csi.md), C6 |
| A volume does not detach; CSI is not ready on a new node (upgrade, scale) | [references/csi.md](references/csi.md), C7 and C8 |
| Pre-provisioned hosts: `localvolumeprovisioner`, a production CSI plan | [references/csi.md](references/csi.md), C9 |
| Volumes left in Prism Central after a cluster delete | [references/csi.md](references/csi.md), C10 |
| Day-1 smoke test of a new cluster: PVC + pod + `LoadBalancer` Service + `curl` (CSI, MetalLB, Cilium) | [references/csi.md](references/csi.md), C12 |
| Velero: state, backup before an upgrade or a delete, schedules, restore | [references/velero.md](references/velero.md) |
| Velero to Nutanix Objects or S3 (BYOS) | [references/velero.md](references/velero.md), B4 |
| Back up and restore the management cluster (disaster recovery) | [references/velero.md](references/velero.md), B7 |
| Rook Ceph health, capacity, `dkp-object-store` stuck, disable Ceph, COSI | [references/object-storage.md](references/object-storage.md) |
| Prism Central restore (PCBR) with a new IP | [references/csi.md](references/csi.md), C11 |
| `clusterConfig.addons.csi` and `addons.cosi` variables | [references/csi.md](references/csi.md), C2 |

## Step 1: Read the storage state

The first block reads the cluster. The second block reads the CSI addon in the NKPCluster on the management cluster.

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get storageclass
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get csidrivers
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get volumesnapshotclass
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n ntnx-system get pods -o wide
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get pvc -A
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get pv -o custom-columns='NAME:.metadata.name,NS:.spec.claimRef.namespace,PVC:.spec.claimRef.name,SC:.spec.storageClassName,STATUS:.status.phase,HANDLE:.spec.csi.volumeHandle'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get deploy -A -l app.kubernetes.io/name=velero
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get cephclusters,cephobjectstores -A
```

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get nkpcluster "$CLUSTER_NAME" -o jsonpath='{range .spec.capiCluster.topology.variables[?(@.name=="clusterConfig")]}csi={.value.addons.csi}{"\n"}cosi={.value.addons.cosi}{"\n"}{end}'
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get appdeployments | grep -E 'velero|rook-ceph|cosi'
```

What you see on a default AHV cluster [live 2.19.0]:
- One StorageClass: `nutanix-volume (default)`, provisioner `csi.nutanix.com`. One CSIDriver `csi.nutanix.com`. One VolumeSnapshotClass `nutanix-snapshot-class`.
- In `ntnx-system`: 2 `nutanix-csi-controller` pods (8/8), one `nutanix-csi-node` pod (3/3) on each node, and `konnector-agent`.
- The PV handle is `NutanixVolumes-<uuid>`. The uuid is the volume group in Prism Central.
- `custom-columns` needs one column for each path. A joined path (`.spec.claimRef.namespace/.spec.claimRef.name`) prints `<none>`. [live 2.19.0]
- `csi` shows `defaultStorage` (`provider: nutanix`, `storageClassConfig: volume`) and `storageClassConfigs.volume`. `cosi` shows `{"strategy":"HelmAddon"}`.
- On Starter: no Velero, no Ceph ("the server doesn't have a resource type"), and no storage AppDeployment.

Done when: you know the default StorageClass, the CSI pod state, and which of Velero, Rook Ceph, and COSI run.

## Step 2: Pod `Pending` with an unbound PVC

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
ns=''; pvc=''
: "${ns:?}" "${pvc:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" describe pvc "$pvc"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" get events --field-selector "involvedObject.name=$pvc" --sort-by=.lastTimestamp
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n ntnx-system logs deploy/nutanix-csi-controller -c csi-provisioner --tail=50
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n ntnx-system logs deploy/nutanix-csi-controller -c nutanix-csi-plugin --tail=50
```

| What `describe pvc` shows | Cause | Fix |
|---|---|---|
| `waiting for first consumer to be created before binding` | Normal for `WaitForFirstConsumer`. No pod uses the PVC yet. [live 2.19.0] | Start the pod. If the pod is also `Pending`, read `kubectl describe pod` (node selector, taints, resources: skill `kubernetes-core`). |
| No StorageClass in the PVC, and no event | No default StorageClass. | Step 3. |
| `storageclass ... not found` | The PVC names a StorageClass that does not exist. | Fix the PVC, or make the class (C2). The PVC `storageClassName` cannot change. Delete and make the PVC again (CHANGES, the user decides). |
| Provisioning errors from `csi.nutanix.com` (credentials, storage container, Prism Central) | The CSI cannot reach Prism Central, or the container is wrong. | [references/csi.md](references/csi.md), C11 (credentials and endpoint). Check the container name in the StorageClass. |
| The pod runs on a Metal node of a mixed cluster | The StorageClass uses hypervisor-attached volumes. [pdf p.750] | [references/csi.md](references/csi.md), C3. |
| `localvolumeprovisioner`, no free PV | No disk mounted under `/mnt/disks` on a node. [pdf p.44] | [references/csi.md](references/csi.md), C9. |
| CSI pods not `Running` | The driver is down. | [references/csi.md](references/csi.md), C8. |

Done when: the PVC is `Bound`, or you showed the user the row and the fix.

## Step 3: The default StorageClass

Exactly one StorageClass must show `(default)`. Kommander needs it before the install. [pdf p.942] With two defaults, the newest class wins for a PVC with no class (Kubernetes behaviour). Make only one the default.

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get storageclass -o custom-columns='NAME:.metadata.name,DEFAULT:.metadata.annotations.storageclass\.kubernetes\.io/is-default-class,PROVISIONER:.provisioner,BINDING:.volumeBindingMode,EXPAND:.allowVolumeExpansion'
```

- AHV: CAREN makes `nutanix-volume` the default. [live 2.19.0] If it is missing, the CSI addon failed: read C8.
- Pre-provisioned: `localvolumeprovisioner` is the default. It is not for production. [pdf p.37] See C9.
- Other providers: [references/csi.md](references/csi.md), C1.

To change the default, set `old` (the current default) and `new`. Show the plan. After "yes":

```bash
# CHANGES  (moves the default StorageClass annotation; new PVCs with no class use the new class)
source ~/nkp-<cluster>.env 2>/dev/null
old=''; new=''
: "${new:?}"
[ -n "$old" ] && kubectl --kubeconfig "$CLUSTER_KUBECONFIG" patch storageclass "$old" -p '{"metadata":{"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" patch storageclass "$new" -p '{"metadata":{"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}'
```

- The annotation patch passes a server dry run on `nutanix-volume`. [live 2.19.0]
- Existing PVCs keep their class. Only new PVCs change.
- UNKNOWN (D-21): whether CAREN puts the default annotation back on `nutanix-volume` at the next reconcile or upgrade. Find out with: `source ~/nkp-<cluster>.env 2>/dev/null && kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get storageclass` after the next cluster upgrade.
- When no class is the default, keep `old` empty. On AHV, `new` is then `nutanix-volume`.

Done when: the READ-ONLY block shows `true` on one line only.

## Common failures

| Symptom | Where |
|---|---|
| PVC `Pending` | step 2 |
| `Multi-Attach error` or `AttachVolume.Attach failed`; a node delete waits for volumes | [references/csi.md](references/csi.md), C7 |
| New node: `nutanix-csi-node` pod not `Running`; `driver name csi.nutanix.com not found in the list of registered CSI drivers` | [references/csi.md](references/csi.md), C8 |
| `field is immutable` on a StorageClass patch | StorageClass parameters cannot change. [live 2.19.0] Make a new class (C2). |
| PVC resize does nothing | [references/csi.md](references/csi.md), C4 |
| Velero BSL not `Available`; `velero-pre-install` job waits | [references/velero.md](references/velero.md), B9 |
| Kommander install stops at Rook Ceph; `dkp-object-store` not `Connected` | [references/object-storage.md](references/object-storage.md), O3 |
| Loki or Velero bucket full | [references/object-storage.md](references/object-storage.md), O2 |

For the debug ladder and other failures, use skill `nkp-troubleshooting`.

## Related skills

Create flags (`--csi-*`): skill `nkp-install`. The NKPCluster JSON patch method and node pool `deletion` settings: skill `nkp-cluster-lifecycle`, step 3. AppDeployment overrides and per-cluster overrides: skill `nkp-platform-apps-gitops`. Upgrade gates: skill `nkp-upgrade`. Images in a closed site: skill `nkp-airgap`. NDK: skill `nkp-ndk`. Loki, logging: skill `nkp-observability`.
