# CSI, StorageClasses, snapshots, and volumes

Use this file from skill `nkp-storage-backup`. Read `SKILL.md` step 1 first.

| File | Site variables |
|---|---|
| `~/nkp-<cluster>.env` | `PE_UUID` `METAL_STORAGE_CONTAINER` |

- `PE_UUID`: the UUID of the Prism Element cluster that holds the volumes of a Metal pool (the user reads it in Prism Central).
- `METAL_STORAGE_CONTAINER`: the storage container for the Metal pool. It can be the same as `STORAGE_CONTAINER`.

## C1. Default StorageClass for each provider

| Provider | Driver (version) | Default StorageClass |
|---|---|---|
| Nutanix AHV | `nutanix-csi-driver` 3.9.0, provisioner `csi.nutanix.com` | `nutanix-volume` [live 2.19.0] |
| AWS, EKS | `aws-ebs-csi-driver` 1.62 (gp3) | `ebs-sc` [pdf p.37, p.40] |
| Azure | `azuredisk-csi-driver` 1.34.4 (StandardSSD_LRS) | `azuredisk-sc` [pdf p.37] |
| vSphere | `vsphere-csi-driver` 3.4.0 | `vsphere-raw-block-sc` [pdf p.37] |
| GCP | `gcp-compute-persistent-disk-csi-driver` 1.15.4 | `csi-gce-pd` [pdf p.37] |
| Pre-provisioned | `local-static-provisioner` 2.8.0 | `localvolumeprovisioner` (not for production, C9) [pdf p.37] |
| NKP Metal | Nutanix CSI 3.x [pdf p.743] | not in the skills. Check with `SKILL.md` step 3. |

- `allowVolumeExpansion` is `true` by default only on AHV. Other providers: `false`. [pdf p.38]

## C2. The CSI addon and a new StorageClass

**On AHV, CAREN owns the StorageClasses.** It makes one class for each key in `clusterConfig.addons.csi.providers.nutanix.storageClassConfigs`. The class name is `nutanix-<key>` (key `volume` → `nutanix-volume`). `defaultStorage.storageClassConfig` names the key of the default class. [live 2.19.0]

The schema of `clusterConfig.addons.csi` [live 2.19.0]:

| Field | Values |
|---|---|
| `defaultStorage` (required) | `provider: nutanix` (only value), `storageClassConfig: <key>` |
| `providers.nutanix.credentials.secretRef.name` | `<cluster>-pc-credentials-for-csi` (a Secret on the management cluster) |
| `providers.nutanix.storageClassConfigs.<key>` (required) | `allowExpansion` (bool), `parameters` (string map), `reclaimPolicy` (`Delete` default, `Retain`), `volumeBindingMode` (`WaitForFirstConsumer` default, `Immediate`) |
| `providers.nutanix.strategy`, `snapshotController.strategy` | `HelmAddon` (default) or `ClusterResourceSet` |

`clusterConfig.addons.cosi` has only `strategy: HelmAddon`. [live 2.19.0] The table has no `usePEFallback` key. NDK sync failover needs CSI `usePEFallback: false` (D-56, skill `nkp-ndk`).

Create time: the flags `--csi-storage-container`, `--csi-file-system` (`ext4` default, `xfs`), `--csi-reclaim-policy` (`Delete` default, `Retain`), `--csi-hypervisor-attached-volumes` (default `true`), `--csi-flash-mode` fill the `volume` key. [live 2.19.0] Use skill `nkp-install`.

**Facts from server dry runs on the live cluster** [live 2.19.0]:
- StorageClass `parameters` are immutable: "field is immutable". To change a parameter, make a new class. [pdf p.42]
- A new key in `storageClassConfigs` passes the NKPCluster webhooks. The CAREN preflight checks that `storageContainer` exists in Prism Central: "Found no Storage Containers with name ... on Cluster ...".
- A `defaultStorage.storageClassConfig` that names no key passes the dry run. Check the name yourself.
- UNKNOWN (D-20): whether CAREN makes a StorageClass for a key that is added to a running cluster, and what it does when the parameters of an existing key change. Find out with: `source ~/nkp-<cluster>.env 2>/dev/null && kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get storageclass` after the patch in a `skilltest-` cluster.

Until D-20 is closed, make an extra class with `kubectl apply` (C3 shows the form). Do not change the parameters of an existing key in the NKPCluster.

**Nutanix StorageClass parameters** [pdf p.39, p.41][live 2.19.0]:
- `storageType`: `NutanixVolumes` (block) or `NutanixFiles` (NFS, C5).
- `storageContainer`: the container name. The CSI looks for the name on all Prism Element clusters of Prism Central. [pdf p.694]
- `hypervisorAttached`: `ENABLED` (the disk attaches through AHV) or `DISABLED` (iSCSI from the node; needs the iSCSI data services IP of the PE cluster). A cluster in a user-defined Prism Central project must keep `ENABLED`. [pdf p.413]
- `flashMode`: `ENABLED` or `DISABLED`. `csi.storage.k8s.io/fstype`: `ext4` or `xfs`.
- The six `csi.storage.k8s.io/*-secret-name` and `*-secret-namespace` keys point to `nutanix-csi-credentials` in `ntnx-system`. Copy them unchanged.

Done when: you showed the class YAML and the user agreed.

## C3. `nutanix-volume-metal` for the Metal pool of a mixed cluster

A mixed cluster has AHV VMs and a Metal node pool. The default class uses hypervisor-attached volumes, so it cannot give volumes to Metal nodes (they have no hypervisor). Make a second class and use it for every PVC on the Metal pool. [pdf p.750] On Metal hosts, the volume traffic goes straight to Prism Element. [pdf p.754]

1. The user gives `PE_UUID` and `METAL_STORAGE_CONTAINER` (rule 4).
2. Write the file:

```bash
# CHANGES  (writes the StorageClass file on the operator host; changes no cluster)
source ~/nkp-<cluster>.env 2>/dev/null
: "${PE_UUID:?}" "${METAL_STORAGE_CONTAINER:?}"
cat > "$HOME/nkp-$CLUSTER_NAME-sc-metal.yaml" <<EOF
allowVolumeExpansion: true
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: nutanix-volume-metal
parameters:
  csi.storage.k8s.io/controller-expand-secret-name: nutanix-csi-credentials
  csi.storage.k8s.io/controller-expand-secret-namespace: ntnx-system
  csi.storage.k8s.io/fstype: xfs
  csi.storage.k8s.io/node-publish-secret-name: nutanix-csi-credentials
  csi.storage.k8s.io/node-publish-secret-namespace: ntnx-system
  csi.storage.k8s.io/provisioner-secret-name: nutanix-csi-credentials
  csi.storage.k8s.io/provisioner-secret-namespace: ntnx-system
  fileSystem: ext4
  prismElementRef: $PE_UUID
  storageContainer: $METAL_STORAGE_CONTAINER
  storageType: NutanixVolumes
provisioner: csi.nutanix.com
reclaimPolicy: Delete
volumeBindingMode: WaitForFirstConsumer
EOF
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" apply --dry-run=server -f "$HOME/nkp-$CLUSTER_NAME-sc-metal.yaml"
```

- This is the guide form, unchanged. It has both `csi.storage.k8s.io/fstype: xfs` and `fileSystem: ext4`. [pdf p.751] UNKNOWN (D-22): which file system the Metal volumes get. Find out with: `source ~/nkp-<cluster>.env 2>/dev/null && kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get pv -o custom-columns=NAME:.metadata.name,SC:.spec.storageClassName,FS:.spec.csi.fsType` after the first Metal PVC.
- The server dry run does not check the container or the UUID. [live 2.19.0] Check both values with the user.
- The class is not the default. Do not make it the default: the VM nodes need `nutanix-volume`.

3. Show the file and the dry-run output as the plan. After "yes":

```bash
# CHANGES  (creates StorageClass nutanix-volume-metal on the cluster)
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" apply -f "$HOME/nkp-$CLUSTER_NAME-sc-metal.yaml"
```

4. Tell the user: a workload on the Metal pool must set `storageClassName: nutanix-volume-metal` in its PVC, and a node selector or toleration for the Metal pool (skill `nkp-cluster-lifecycle`, Metal pools).

Done when: `kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get storageclass nutanix-volume-metal` shows the class, and a test PVC on a Metal node is `Bound`.

## C4. Expand a volume

1. The class must have `allowVolumeExpansion: true`: `kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get sc -o custom-columns=NAME:.metadata.name,EXPAND:.allowVolumeExpansion` (READ-ONLY). On AHV, `nutanix-volume` has it. [live 2.19.0]
2. If it is `false`: the guide patches the class (`allowVolumeExpansion` is not a parameter, so it can change), and then sets the same value in the cluster spec (`allowExpansion`). [pdf p.38-40] On AHV, the cluster value is `allowExpansion` of the key in `storageClassConfigs` (C2), in `clusterConfig` (skill `nkp-cluster-lifecycle`, step 3, cluster field block, `value='true'`). Set both. The class patch (after "yes"):

```bash
# CHANGES  (allows volume expansion on one StorageClass)
source ~/nkp-<cluster>.env 2>/dev/null
sc=''
: "${sc:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" patch storageclass "$sc" -p '{"allowVolumeExpansion":true}'
```

3. Raise `spec.resources.requests.storage` of the PVC (CHANGES). A PVC cannot get smaller.

```bash
# CHANGES  (raises the size of one PVC)
source ~/nkp-<cluster>.env 2>/dev/null
ns=''; pvc=''; size=''
: "${ns:?}" "${pvc:?}" "${size:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" patch pvc "$pvc" -p "{\"spec\":{\"resources\":{\"requests\":{\"storage\":\"$size\"}}}}"
```

Done when: `kubectl get pvc` shows the new CAPACITY. A file system resize can wait until the pod restarts.

## C5. Nutanix Files (NFS) StorageClass

The guide shows a static Files class for NAI [pdf p.329]:

```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: nai-nfs-storage
parameters:
  nfsPath: <nfs-path>
  nfsServer: <nfs-server>
  storageType: NutanixFiles
provisioner: csi.nutanix.com
reclaimPolicy: Delete
volumeBindingMode: Immediate
```

- The user gives the export path and the file server. Write the file with real values (rule 4), then apply it like C3 (dry run, plan, "yes").
- Dynamic Files shares (`dynamicProv: ENABLED`, `nfsServerName`) need a second credential Secret with a Files REST user. [field] The steps are not in the skills.

## C6. VolumeSnapshot

The snapshot controller and `nutanix-snapshot-class` (driver `csi.nutanix.com`, `deletionPolicy: Retain`, `storageType: NutanixVolumes`) are on every AHV cluster. [live 2.19.0] `Retain`: the snapshot in Prism Central stays when you delete the `VolumeSnapshot`.

```bash
# CHANGES  (takes a CSI snapshot of one PVC)
source ~/nkp-<cluster>.env 2>/dev/null
ns=''; pvc=''; snap=''
: "${ns:?}" "${pvc:?}" "${snap:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" apply -f - <<EOF
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshot
metadata:
  name: $snap
spec:
  volumeSnapshotClassName: nutanix-snapshot-class
  source:
    persistentVolumeClaimName: $pvc
EOF
```

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get volumesnapshot,volumesnapshotcontent -A
```

- Done when: `READYTOUSE` is `true`. If not, run `kubectl describe volumesnapshot` and read the `csi-snapshotter` container log of `nutanix-csi-controller`.
- To restore, make a new PVC with `dataSource` (`kind: VolumeSnapshot`, `apiGroup: snapshot.storage.k8s.io`) and a size not smaller than the source.
- Velero CSI snapshots need a VolumeSnapshotClass with the Velero CSI label (the guide shows it only for AWS). [pdf p.476] `nutanix-snapshot-class` has no labels. [live 2.19.0] NKP default backups take no volume snapshots. [pdf p.533] Velero with Nutanix CSI snapshots is not in the skills. Use the file system backup ([velero.md](velero.md), B5).
- App-consistent snapshots, replication, and failover: skill `nkp-ndk`.

## C7. A volume does not attach or detach

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get volumeattachments -o custom-columns='NAME:.metadata.name,PV:.spec.source.persistentVolumeName,NODE:.spec.nodeName,ATTACHED:.status.attached,ERR:.status.detachError.message'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n ntnx-system logs deploy/nutanix-csi-controller -c csi-attacher --tail=50
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get events -A --field-selector reason=FailedAttachVolume
```

- `Multi-Attach error`: an RWO volume is still attached to the old node. Usually the old pod is still on that node, or the node is down. Wait for the old pod to stop. A `ReadWriteOnce` volume can attach to one node only.
- A node delete (upgrade, scale down, pool delete) waits for its volumes to detach. CAPI waits without a limit unless the pool has `deletion.nodeVolumeDetachTimeoutSeconds`. The field passes a server dry run on the NKPCluster pool. [live 2.19.0] Set it with skill `nkp-cluster-lifecycle`, step 3, topology block (`field='workers/machineDeployments/<i>/deletion'`, `value='{"nodeVolumeDetachTimeoutSeconds":600}'`). `add` replaces all of `deletion`: read the old object first (lifecycle step 2) and keep its keys (for example `nodeDrainTimeoutSeconds`) in `value`. After the timeout, CAPI deletes the machine with the volume still attached. Say this in the plan.
- In Prism Central, the volume group of the PV has the PV handle uuid (`NutanixVolumes-<uuid>`) and the description "CSI StorageClass ... PVC:<pvc>, NS:<namespace>". [live 2.19.0] Find the VM that holds it with skill `nutanix-storage`, RECIPES.md "Read entries in the description and the attachment sub-resource". If that skill is not installed, the user does it in Prism Central. The NKP Prism Central role has "Detach Volume Group From AHV VM". [pdf p.706]
- Never delete a `VolumeAttachment` or remove its finalizer while the pod runs. That can corrupt data. If the node is gone and the attachment stays, use skill `nkp-troubleshooting` (finalizers).

## C8. CSI pods not ready (new node, upgrade)

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n ntnx-system get ds nutanix-csi-node
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n ntnx-system get pods -o wide
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get csinode -o custom-columns='NODE:.metadata.name,DRIVERS:.spec.drivers[*].name'
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get helmchartproxies | grep -E 'nutanix-csi|snapshot|cosi'
```

- Healthy [live 2.19.0]: DESIRED = READY on `nutanix-csi-node`, each node pod `3/3`, each controller pod `8/8`, every CSINode lists `csi.nutanix.com`.
- A node pod not `Running`: `kubectl describe pod` on it. `ImagePullBackOff`: the images `docker.io/nutanix/ntnx-csi:3.9.0` and the `registry.k8s.io/sig-storage/*` images must be in the registry mirror (skill `nkp-airgap`). [live 2.19.0]
- A node is not `Ready` for a CNI reason: skill `nkp-networking`.
- The node has no `csi.nutanix.com` in CSINode: the node pod did not register. Read its `driver-registrar` container log.
- The HelmChartProxy `nutanix-csi-<uid>` is the CAREN addon. When it is not Ready, use skill `nkp-troubleshooting` (HelmChartProxy and CAREN).

## C9. Pre-provisioned hosts: `localvolumeprovisioner`

- The default class `localvolumeprovisioner` makes one PV for each mount under `/mnt/disks` on each node. [pdf p.44] It is not for production. [pdf p.37]
- Add a disk: mount it under `/mnt/disks/<name>` on the node (the node admin does it). Then `kubectl get pv` shows a `local-pv-*` PV. [pdf p.45]
- A local PV is tied to one node. If the node goes, the data goes.
- Rook Ceph on pre-provisioned hosts uses raw disks (skill `nkp-install`, pre-provisioned P8), because this provisioner cannot give `volumeMode: Block` PVCs.

**Production plan.** The guide says only: install a production CSI driver for your storage, make its class the default, and set `localvolumeprovisioner` to non-default (`SKILL.md` step 3). [pdf p.41] Ask the user which storage system the site has. The install steps of a third-party CSI driver are not in the skills. Do the switch before you enable platform apps that need storage. [pdf p.44]

## C10. Volumes left after a cluster delete

Before a delete, save the volume list (READ-ONLY):

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get pv -o custom-columns='HANDLE:.spec.csi.volumeHandle,RECLAIM:.spec.persistentVolumeReclaimPolicy,NS:.spec.claimRef.namespace,PVC:.spec.claimRef.name'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get pvc -A
```

- Use one column for each path. `custom-columns` cannot join two paths: `CLAIM:.spec.claimRef.namespace/.spec.claimRef.name` prints `<none>` on every row. [live 2.19.0]
- `Retain` PVs (and a class with `--csi-reclaim-policy Retain`) keep the volume group when the PVC goes.
- `deletionPolicy: Retain` keeps the snapshots of `nutanix-snapshot-class` in Prism Central.
- The guide says only that PVs stay on AWS after a delete. [pdf p.833]
- `nkp delete cluster` on AHV deletes the VMs and keeps **every** Nutanix CSI volume group of a PVC: the user PVCs and the platform PVCs. Measured: 3 groups after a Starter management cluster, 20 after an Ultimate management cluster, 4 after a workload cluster with PVCs, 0 after a cluster with no PVC. Prism Central removes their VM attachments. [live 2.19.0]
- The volume group `extId` is the uuid of the PV handle (`NutanixVolumes-<uuid>`). Its description has `K8sClusterID` and `for <cluster>, PVC:<pvc>, NS:<ns>`. [live 2.19.0]

After the delete, find and delete the leftovers. Delete the cluster first, then the volume groups. Use skill `nutanix-storage`, RECIPES.md "What an NKP cluster leaves behind" (it matches `for <cluster>,`, needs `K8sClusterID`, and keeps only groups with no VM attachment), then "Delete a volume group". The recipe runs Python on the operator host with `PC_ENDPOINT`, `NUTANIX_USER`, `NUTANIX_PASSWORD` from `~/nkp-site.env`. A volume group delete is a CHANGES step: show the list (count, PVC names, namespaces) as the plan and stop for "yes". Ask about a backup first. Data in a deleted volume group is gone. Also check the recovery points (snapshots, `Retain`). If skill `nutanix-storage` is not installed, the user does it in Prism Central: search the volume groups for the uuids from the list and for `for <cluster>,`.

## C11. Credentials and Prism Central endpoint

- The CSI uses the Secret `nutanix-csi-credentials` (one key `key`) in `ntnx-system` on each cluster. On the management cluster, the source is the Secret `<cluster>-pc-credentials-for-csi` in the NKPCluster namespace. [live 2.19.0] Never print these Secrets.
- A Prism Central password change needs a credential update on all clusters. The guide scales down CAPX, CAREN, CCM, and the CSI first, then edits the Secrets `global-nutanix-credentials`, `<cluster>-pc-credentials`, and `<cluster>-pc-credentials-for-csi`. [pdf p.730-733] The steps print and edit Secrets. They are not in the skills. Tell the user to use the guide procedure (or KB-18296).
- A Prism Central restore (PCBR) with the same IP: re-import the NKP OS images, set the PC name back, and keep the same password for the NKP user. With a new IP, also update the PC endpoint in the cluster resource, and in the CCM and CSI Secrets. [pdf p.537-538] Use a custom PC user, not `admin`: the restore resets the `admin` password. [pdf p.537]

## C12. Day-1 smoke test: PVC, pod, LoadBalancer, curl

One test proves the Nutanix CSI, MetalLB, and Cilium on a new cluster: a PVC on the default class, a pod that mounts it, a `LoadBalancer` Service, and an HTTP request from the operator host. It passed on a 2.19.0 workload cluster: PVC `Bound` and pod `Running` in about 70 s, EXTERNAL-IP from `LB_IP_RANGE`, `http=200` with the file from the volume. [live 2.19.0]

**Images.** Use only images that the registry mirror has. Never guess an image name, and never pull from the internet. On the 2.19.0 lab mirror, `library/nginx` and `library/alpine` gave 404. [live 2.19.0] The test needs two images:
- `web_img`: an nginx image that runs as non-root on port 8080. The 2.19.0 kommander bundle has `nginxinc/nginx-unprivileged:1.29.5-alpine`. [live 2.19.0]
- `init_img`: a busybox image. The 2.19.0 kommander bundle has `library/busybox:1`. [live 2.19.0]

The user gives the two image names, or you read them from the mirror with the READ-ONLY tag list in skill `nkp-airgap`, file `nodes.md`, section "Check that the site mirror has an image". The bundle image list is in skill `nkp-airgap`, step 2. Do not use a name that the mirror tag list does not show. Write the name in the form that the pods use: `docker.io/<path>:<tag>`. The node mirror config sends `docker.io` pulls to the mirror. [live 2.19.0]

**When.** MetalLB gives the first free IP. On a workload cluster, a test Service that came before the platform apps took the first IP of `LB_IP_RANGE`, and `kommander-traefik` got the next IP. [live 2.19.0] When a FIP or a DNS name must point to `kommander-traefik` on the first IP (skill `nkp-vpc`), run the test after the platform apps are ready (skill `nkp-install`, Verify).

1. Read the state (READ-ONLY). The default class must be there (`SKILL.md` step 3), and the pool must have a free IP (skill `nkp-networking`, `metallb.md` M1):

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get storageclass
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n metallb-system get ipaddresspools
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get svc -A --field-selector spec.type=LoadBalancer
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get pods -A -o jsonpath='{range .items[*]}{range .spec.containers[*]}{.image}{"\n"}{end}{end}' | sort -u | grep -E 'nginx|busybox'
```

The last line shows the images that already run on the cluster. Use it as a cross-check, not as the source.

2. Ask the user for a new namespace name (`ns`) and the two image names. Show the plan: the cluster, the namespace, the file `$PWD/<cluster>-smoke.yaml`, a 1 GiB PVC on the default class, the pod, the Service (port 80 → 8080), one IP from the pool, and step 5 (remove). Stop for "yes". Then write the file:

```bash
# CHANGES  (writes the smoke test file on the operator host; changes no cluster)
source ~/nkp-<cluster>.env 2>/dev/null
web_img=''; init_img=''
: "${web_img:?}" "${init_img:?}"
cat > "$PWD/$CLUSTER_NAME-smoke.yaml" <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: smoke-data
spec:
  accessModes: ["ReadWriteOnce"]
  resources:
    requests:
      storage: 1Gi
---
apiVersion: v1
kind: Pod
metadata:
  name: smoke
  labels:
    app: smoke
spec:
  initContainers:
  - name: seed
    image: $init_img
    command: ["sh", "-c", "echo smoke test $CLUSTER_NAME > /data/index.html"]
    volumeMounts:
    - name: data
      mountPath: /data
  containers:
  - name: web
    image: $web_img
    ports:
    - containerPort: 8080
    volumeMounts:
    - name: data
      mountPath: /usr/share/nginx/html
  volumes:
  - name: data
    persistentVolumeClaim:
      claimName: smoke-data
---
apiVersion: v1
kind: Service
metadata:
  name: smoke-lb
spec:
  type: LoadBalancer
  selector:
    app: smoke
  ports:
  - port: 80
    targetPort: 8080
EOF
```

The file has no Namespace object. A server dry run of a file that also makes its namespace fails for the later objects (`namespaces "..." not found`). [live 2.19.0] So the next block makes the namespace first.

3. Apply. The "yes" of step 2 covers it. The apply runs only when the server dry run passes:

```bash
# CHANGES  (creates the namespace, the PVC, the pod, and the LoadBalancer Service)
source ~/nkp-<cluster>.env 2>/dev/null
ns=''
: "${ns:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" create namespace "$ns"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" apply --dry-run=server -f "$PWD/$CLUSTER_NAME-smoke.yaml" && kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" apply -f "$PWD/$CLUSTER_NAME-smoke.yaml"
```

4. Check (READ-ONLY). The operator host must be on the Layer 2 subnet of the nodes, or have a route to the pool:

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
ns=''
: "${ns:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" wait --for=condition=Ready pod/smoke --timeout=5m
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" get pvc smoke-data
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get pv -o custom-columns='NAME:.metadata.name,NS:.spec.claimRef.namespace,PVC:.spec.claimRef.name,HANDLE:.spec.csi.volumeHandle' | grep -E "^NAME|$ns"
ip=$(kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" get svc smoke-lb -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
echo "ip=$ip"
curl -s --noproxy '*' --max-time 10 -o /dev/null -w 'http=%{http_code}\n' "http://$ip/"
curl -s --noproxy '*' --max-time 10 "http://$ip/"
```

| Result | Cause | Next |
|---|---|---|
| `wait` times out, PVC `Pending` | CSI or StorageClass | `SKILL.md` step 2 |
| Pod `ErrImagePull` or `ImagePullBackOff` | the mirror does not have the image | skill `nkp-airgap`. Ask for another image name. |
| `ip=` is empty | no free pool IP, or no advertisement | skill `nkp-networking`, `metallb.md` M1 |
| `http=000` | no route from the operator host, ARP, or Cilium DSR | skill `nkp-networking`, `metallb.md` M1 (last row) |
| `http=403` or `404` | nginx cannot read the file | `kubectl logs pod/smoke -c web` and `-c seed` |

Done when: the PVC is `Bound`, the PV handle is `NutanixVolumes-<uuid>`, `ip=` is an IP of the pool, the first `curl` prints `http=200`, and the second prints `smoke test <cluster>`.

5. Remove the test. Do it before a cluster delete: an NKP delete keeps the volume group of each PVC (C10). Show the plan and stop for "yes":

```bash
# CHANGES  (deletes the namespace with the PVC, the pod, and the Service; frees the LB IP)
source ~/nkp-<cluster>.env 2>/dev/null
ns=''
: "${ns:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" delete namespace "$ns" --timeout=5m
```

`nutanix-volume` has `reclaimPolicy: Delete`, so the CSI deletes the PV. UNKNOWN (D-60): whether the CSI also deletes the volume group in Prism Central when a PVC of `nutanix-volume` is deleted. Find out with: `source ~/nkp-<cluster>.env 2>/dev/null && kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get pv -o custom-columns=NAME:.metadata.name,HANDLE:.spec.csi.volumeHandle` before the delete; after it, look for the handle uuid with skill `nutanix-storage`, RECIPES.md "List and find volume groups".
