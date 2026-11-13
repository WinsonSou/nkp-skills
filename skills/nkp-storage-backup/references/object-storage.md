# Object storage: Rook Ceph, COSI, BYOS

Use this file from skill `nkp-storage-backup`. Rook Ceph and the COSI driver app are Pro and Ultimate platform apps. [live 2.19.0] On Starter, they are not there.

## Facts

- Apps `rook-ceph` (operator) and `rook-ceph-cluster` (CephCluster, object store `dkp-object-store`, buckets). Live ClusterApps: 1.19.5. Images `rook/ceph:v1.19.5`, `ceph/ceph:v19.2.3`. [live 2.19.0] The guide names `rook-ceph-cluster-1.19.6`. [pdf p.652] Read the version from the cluster.
- Ceph is the object store for Loki, Velero, Harbor, OpenCost, and NKP Insights only. It is not storage for user apps. [pdf p.646]
- PVC mode: Ceph puts its disks on PVCs from the default StorageClass, which must give `volumeMode: Block`. So Ceph cannot be the CSI of the cluster. [pdf p.648, p.650]
- Default layout: 4 OSDs of 40 GiB (160 GiB raw), 3 MON PVCs of 10 GiB, erasure coding k=3 m=1: about 120 GiB usable, one OSD can fail. [pdf p.649-650]
- Resources: about 2000m CPU and 8 GiB memory. 4 worker nodes, one OSD for each node. OSDs on the same node can stop an upgrade (PodDisruptionBudgets). [pdf p.649-650]
- You need Ceph for `grafana-loki`. Velero and OpenCost need it only without an external store. [pdf p.647]
- On the target cluster, Rook Ceph runs in `kommander`. [pdf p.652] On the management cluster, the workspace namespace is `kommander`, and the blocks below work. A workload cluster has no `kommander` namespace: its platform apps are in the workspace namespace. [live 2.19.0] UNKNOWN (D-61): the namespace of Rook Ceph on a workload cluster. Find out with: `source ~/nkp-<cluster>.env 2>/dev/null && kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get cephclusters -A`. On a workload cluster, run that check first and use its namespace in place of `kommander` in the blocks below.

## O1. Ceph health

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get cephclusters,cephobjectstores,objectbucketclaims -A
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n kommander get pods -l app=rook-ceph-osd -o wide
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n kommander get pvc -l ceph.rook.io/DeviceSet
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n kommander exec deploy/rook-ceph-tools -- ceph status
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n kommander exec deploy/rook-ceph-tools -- ceph osd df
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n kommander exec deploy/rook-ceph-tools -- ceph df
```

- `ceph status` shows `HEALTH_OK` on a healthy cluster. `HEALTH_WARN` during a rebalance is normal. [pdf p.654]
- Usable space: `MAX AVAIL` of the pool `dkp-object-store.rgw.buckets.data` in `ceph df`. [pdf p.654]
- `cephobjectstores` must show `dkp-object-store` `Connected`. If not, O3.
- The Ceph dashboard password is a Secret. Give the user this block (user `admin`) [pdf p.655]:

```bash
# USER-TERMINAL  (prints the Ceph dashboard password)
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n kommander get secret rook-ceph-dashboard-password -o go-template='{{ .data.password | base64decode | printf "%s\n" }}'
```

## O2. Grow Ceph or a full bucket

Rule: **never** edit the ConfigMap `rook-ceph-cluster-<version>-config-defaults`, and never patch the `CephCluster` or the OSD objects. The changes go back at reconcile and upgrade. Use an AppDeployment override. [pdf p.651]

| Method | Field | Needs |
|---|---|---|
| Scale up | `volumeClaimTemplates` storage size | The OSD StorageClass allows expansion, and Ceph 19.2.3 or later. On 19.2.1 and 19.2.2 the OSD crashes. [pdf p.652] |
| Scale out | `storageClassDeviceSets` `count` (at least 4) | 250m CPU and 1 GiB memory for each new OSD. [pdf p.652] |

1. Read the version and the defaults (on the management cluster, `WORKSPACE_NS` of the cluster):

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get appdeployment rook-ceph-cluster -o jsonpath='{.spec.appRef.name}{"\t"}{.spec.configOverrides.name}{"\n"}'
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get cm -o name | grep 'rook-ceph-cluster-.*-config-defaults'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n kommander exec deploy/rook-ceph-tools -- ceph versions
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get sc -o custom-columns=NAME:.metadata.name,EXPAND:.allowVolumeExpansion
```

2. Copy the **full** `storageClassDeviceSets` entry (`rook-ceph-osd-set1`) from the `values.yaml` of the defaults ConfigMap. Change only `count` or `storage`. A list replaces the old list: an entry with only `name` and `count` loses `volumeClaimTemplates`, and the OSDs fail. Put it under `cephClusterSpec.storage.storageClassDeviceSets`. [pdf p.652]
3. The override ConfigMap is `rook-ceph-cluster-config-overrides` (key `values.yaml`) in `WORKSPACE_NS` on the management cluster, set in `spec.configOverrides.name` of the AppDeployment (per cluster: `clusterConfigOverrides`). [pdf p.653-654] If the AppDeployment already has an override ConfigMap, add to it. Apply it with skill `nkp-platform-apps-gitops` (AppDeployment override steps).
4. After the OSDs grow: compare `SIZE` and `WEIGHT` in `ceph osd df`. Weight is the size in TiB (250 GiB → 0.24409). An old weight (0.03909 = 40 GiB) means that Ceph does not use the new space. After the backfill, the guide sets the weight (CHANGES, one OSD each time) [pdf p.654]:

```bash
# CHANGES  (sets the CRUSH weight of one OSD; data moves)
source ~/nkp-<cluster>.env 2>/dev/null
osd=''; weight=''
: "${osd:?}" "${weight:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n kommander exec deploy/rook-ceph-tools -- ceph osd crush reweight "osd.$osd" "$weight"
```

**Full bucket.** A bucket has its own cap (`maxSize` of its ObjectBucketClaim). More OSDs do not raise it. For Loki, set `dkp.grafana-loki.additionalConfig.maxSize` in the same override. For Velero, Harbor, and project Loki, raise the cap of that app too. [pdf p.653-654] The Velero cap key is not in the skills. Read the `maxSize` of the claims in O1 (`objectbucketclaims`).
Loki retention and store, and the project Loki cap: skill `nkp-observability` (file `logging.md`, L3-L4, L10).

Done when: O1 shows the new OSDs `up`, `HEALTH_OK`, and the new `MAX AVAIL`.

## O3. `dkp-object-store` stuck (Kommander install stops at Rook Ceph)

Check the events [pdf p.1071]:

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n kommander describe cephobjectstores dkp-object-store
```

Do the fix only if the events show "failed to configure multisite for object store ... failed to commit RGW configuration period changes". Otherwise stop. The fix (CHANGES, after "yes"): set the zonegroup, commit the period (this can take some minutes), restart the operator, and wait for `Connected`. [pdf p.1072]

```bash
# CHANGES  (sets the default RGW zonegroup and restarts the Rook operator)
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n kommander exec deploy/rook-ceph-tools -- radosgw-admin zonegroup default --rgw-zonegroup=dkp-object-store
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n kommander exec deploy/rook-ceph-tools -- radosgw-admin period update --commit
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n kommander rollout restart deploy rook-ceph-operator
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n kommander wait cephobjectstore dkp-object-store --for=jsonpath='{.status.phase}'=Connected --timeout 10m
```

Other Ceph install failures:
- OSD PVCs `Pending`: the default StorageClass cannot give `volumeMode: Block` ([SKILL.md](../SKILL.md) step 2), or fewer than 4 nodes have room.
- Pre-provisioned hosts: Ceph uses raw disks. The override is in skill `nkp-install` (pre-provisioned, P8).

## O4. Disable NKP Ceph, or use your own Ceph (BYOS)

**Disable.** First move or turn off each user of Ceph (Loki, Velero, Harbor, OpenCost, Insights). Then delete in this order: the `rook-ceph-cluster` AppDeployment, wait until the CephCluster is gone (up to 20 minutes), then the `rook-ceph` AppDeployment. The order matters: else objects stay. [pdf p.655-656] All CHANGES. The CephCluster data is lost.

```bash
# CHANGES  (removes the NKP Ceph cluster and its data)
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" delete appdeployment rook-ceph-cluster
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n kommander wait --for=delete cephclusters --all --timeout=1200s
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" delete appdeployment rook-ceph
```

- The guide waits in the workspace namespace. [pdf p.656] On the target cluster, Ceph runs in `kommander`. [pdf p.652] Check the namespace with O1 first.
- Before a new install, the installer config can turn the apps off: `rook-ceph`, `rook-ceph-cluster`, `velero`, `grafana-loki`, `opencost` with `enabled: false`. [pdf p.647] Use skill `nkp-install` (Kommander).

**Your own Ceph (BYOS).** For a Ceph that NKP does not manage (for example in `rook-ceph`) [pdf p.656-661]:
1. The Rook operator watches all namespaces (`currentNamespaceOnly: false`).
2. A `CephObjectStore` `nkp-object-store` (metadata pool replicated, size 3; data pool erasure coded or replicated) and a StorageClass `nkp-object-store` (provisioner `<ceph-namespace>.ceph.rook.io/bucket`).
3. ObjectBucketClaims `nkp-loki` and `nkp-velero` in the workspace namespace. Wait until both are `Bound`.
4. Velero and Loki overrides that point to `http://rook-ceph-rgw-nkp-object-store.<ceph-namespace>.svc:80` (Velero: `extraSecretRef: nkp-velero`, region `nkp-object-store`).

The full YAML is long and must match the external Ceph. It is not in the skills. Tell the user to follow the guide section "Bring Your Own Storage (BYOS) to NKP Clusters".

External S3 for Velero (Nutanix Objects, AWS): [velero.md](velero.md), B4.

## O5. COSI

- The COSI controller (`objectstorage-controller` v0.2.2, Deployment `container-object-storage-controller` in `container-object-storage-system`) runs on every cluster as a CAREN addon. The API is `objectstorage.k8s.io`: `BucketClass`, `BucketAccessClass`, `BucketClaim`, `BucketAccess`, `Bucket`. A new cluster has no BucketClass. [live 2.19.0]
- The driver for Nutanix Objects is the platform app "COSI Driver for Nutanix" (`cosi-driver-nutanix` 0.6.3). [live 2.19.0] The user enables it in the NKP UI of the workspace and types the Prism Central endpoint and user, the Objects endpoint (`http(s)://<host>:<port>`, port 80 by default), and the Objects access and secret keys. A CA for each endpoint is optional. [pdf p.288-289] The agent does not type these credentials.
- Users: Harbor (option "Nutanix Objects") and NKP Insights. [pdf p.284, p.1095] Insights class names: `cosi-nutanix-nkp` (driver `ntnx.objectstorage.k8s.io`) and `cosi-ceph-nkp` (driver `rook-ceph.ceph.objectstorage.k8s.io`). [pdf p.1096]
- COSI cannot take a custom CA for Insights. With a private CA on Nutanix Objects, use static S3 credentials and a CA Secret. [pdf p.1095]
- Do not disable the COSI driver while an app (for example Harbor) uses it. [pdf p.1097]

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n container-object-storage-system get pods
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get bucketclasses,bucketaccessclasses
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get bucketclaims,bucketaccesses -A
```

- UNKNOWN (D-25): the namespace and the pod names of the `cosi-driver-nutanix` app, and the BucketClass that it makes. Find out with: `source ~/nkp-<cluster>.env 2>/dev/null && kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get pods -A | grep -i cosi` on a cluster with the app enabled.
