# Velero: backup and restore

Use this file from skill `nkp-storage-backup`. Velero is a Pro and Ultimate platform app. [live 2.19.0] On Starter, there is no Velero: say so and stop.

| File | Site variables |
|---|---|
| `~/nkp-<cluster>.env` | `VELERO_NS` `BSL_NAME` `OBJECTS_URL` `OBJECTS_BUCKET` |
| `~/nkp-site.env` | `OBJECTS_CA_FILE` `DR_KUBECONFIG` |
| `~/nkp-site.env` secrets | `OBJECTS_ACCESS_KEY` `OBJECTS_SECRET_KEY` |

- `VELERO_NS`: the namespace where Velero runs on the cluster (B1). `BSL_NAME`: the BackupStorageLocation that the backups use (`default` when not changed).
- `OBJECTS_URL`: the S3 endpoint, `https://<host>:<port>`. `OBJECTS_BUCKET`: the bucket of this cluster. Each cluster needs its own bucket. [pdf p.512] `OBJECTS_CA_FILE`: the PEM CA file of the endpoint (optional).
- `DR_KUBECONFIG`: the kubeconfig of the standby or new management cluster (B7).

## Facts

- App `velero` 12.0.0, images `velero/velero:v1.18.0` and `velero/velero-plugin-for-aws:v1.14.0` (in the Kommander image bundle). [live 2.19.0] It depends on `rook-ceph-cluster`. [live 2.19.0]
- On the management cluster, Velero runs in `kommander`, not `velero`. [pdf p.532] This is not a value for `VELERO_NS`: take `VELERO_NS` only from the B1 output.
- Default storage: the bucket `dkp-velero` in the Rook Ceph `dkp-object-store` of the same cluster, over TLS with a self-signed certificate. [pdf p.532] That is not for production: if the cluster is lost, the backups are lost too. Nutanix recommends an external S3 store (Nutanix Objects, AWS S3). [pdf p.510]
- Default schedule `velero-default`: a daily backup of all namespaces. NKP default backups take no volume snapshots. [pdf p.533]
- Restore only into the same cluster and the same NKP version. Another version or another cluster gives a cluster that does not work. [pdf p.535]
- The `velero` CLI is not in the NKP bundle. [live 2.19.0] How to get it is not in the skills. The user gets the v1.18 CLI (the same minor version as the server) on a connected host, and checks its SHA-256 against the checksum on the Velero release page. Without the CLI, use only the READ-ONLY `kubectl` blocks. B3, B4 item 3 (add a BSL), B6, B7, and B8 need the CLI: stop and tell the user.

## B1. Find Velero

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get deploy,ds -A -l app.kubernetes.io/name=velero
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get deploy -A | grep -E 'velero|NAMESPACE'
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get appdeployment velero -o jsonpath='{.spec.appRef.name}{"\t"}{.spec.configOverrides.name}{"\n"}'
command -v velero || echo "no velero CLI"
```

- The namespace of the `velero` Deployment in this output is `VELERO_NS`. Do not take it from a guide page or an example. Show it and ask the user to confirm. Then append it with rule 4. Append `BSL_NAME` too: the BSL that B2 shows with DEFAULT `true` (often `default`), or the BSL that the user names. UNKNOWN (P-03): the Velero namespace on a workload cluster (the guide says the workspace namespace). Find out with: `source ~/nkp-<cluster>.env 2>/dev/null && kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get deploy -A -l app.kubernetes.io/name=velero`.
- No Deployment and no AppDeployment: Velero is not enabled. Enable it as a platform app with skill `nkp-platform-apps-gitops` (it needs Rook Ceph, or B4 first).
- `velero: command not found`: no CLI (see Facts).

Done when: `VELERO_NS` and `BSL_NAME` are set, and you know if the CLI is there.

## B2. State, locations, schedules

The `.velero` suffix selects the Velero API group. Other apps (for example CloudNativePG) also have a `backups` resource.

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$VELERO_NS" get backupstoragelocations,volumesnapshotlocations
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$VELERO_NS" get schedules.velero,backups.velero,restores.velero
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$VELERO_NS" get pods | grep -E 'velero|node-agent'
```

- Each BSL must show PHASE `Available`. [pdf p.515] If not, B9.
- The `velero` CLI gives the same lists: `velero get backup-locations`, `velero get schedules`, `velero get backups`, `velero get restores` (add `-n "$VELERO_NS" --kubeconfig "$CLUSTER_KUBECONFIG"`). [pdf p.536]
- A `node-agent` DaemonSet means the file system backup of volumes is on (B5).

## B3. On-demand backup (before an upgrade, a big change, or a delete)

The guide asks for a backup before an upgrade or a configuration change. [pdf p.535] No `velero` CLI (B1): stop. Tell the user that the backup needs the CLI (Facts), and that the upgrade has no Velero backup until then. Do not write a `Backup` object with `kubectl apply`: its form is not in the skills (the guide gives only the CLI, and the lab has no Velero CRD [live 2.19.0]). Set `name` (for example `pre-upgrade-2-19`). Show the plan. After "yes":

```bash
# CHANGES  (Velero writes a backup of all namespaces to the BSL)
source ~/nkp-<cluster>.env 2>/dev/null
name=''
: "${name:?}" "${VELERO_NS:?}" "${BSL_NAME:?}"
velero backup create "$name" -n "$VELERO_NS" --kubeconfig "$CLUSTER_KUBECONFIG" --storage-location "$BSL_NAME" --snapshot-volumes=false --wait
```

- For some namespaces only, add `--include-namespaces=ns1,ns2`. To include cluster-scoped objects, add `--include-cluster-resources`. [pdf p.480, p.534]
- `--snapshot-volumes=false` is the NKP form. This backup has the Kubernetes objects, **not the data in the volumes**. For volume data, use B5 first.
- **Before a cluster delete**: the default BSL is Rook Ceph in the same cluster, so the backup goes away with the cluster. Use an external BSL (B4). Tell the user.

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
name=''
: "${name:?}"
velero backup describe "$name" -n "$VELERO_NS" --kubeconfig "$CLUSTER_KUBECONFIG" --details --insecure-skip-tls-verify
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$VELERO_NS" get backups.velero "$name" -o jsonpath='{.status.phase}{" errors="}{.status.errors}{" warnings="}{.status.warnings}{"\n"}'
```

- With the in-cluster Ceph BSL, `describe` and `logs` can fail, because the CLI cannot reach the object store from outside. [pdf p.536] Then read the phase with `kubectl` (second line) and the log with `kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$VELERO_NS" logs -l name=velero --tail=200`.
- `--insecure-skip-tls-verify` is for the self-signed Ceph certificate. [pdf p.532]

Done when: the phase is `Completed` with 0 errors. `PartiallyFailed`: read the log, tell the user what failed.

## B4. External object store (BYOS): Nutanix Objects or S3

The user makes the bucket and an access key in Nutanix Objects (or S3). The endpoint name must resolve inside the cluster. [pdf p.511] Each cluster needs its own bucket. [pdf p.512]

1. Values: the user gives `OBJECTS_URL`, `OBJECTS_BUCKET`, `BSL_NAME` (often the bucket name [pdf p.511]), and `OBJECTS_CA_FILE` if the endpoint has a private CA (rule 4). The user types `OBJECTS_ACCESS_KEY` and `OBJECTS_SECRET_KEY` into `~/nkp-site.env` with an editor (rule 5). Check:

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
for v in VELERO_NS BSL_NAME OBJECTS_URL OBJECTS_BUCKET OBJECTS_ACCESS_KEY OBJECTS_SECRET_KEY; do if [ -n "$(printenv "$v")" ]; then echo "set: $v"; else echo "MISSING: $v"; fi; done
```

2. The credential Secret on the cluster where Velero runs (profile name = `BSL_NAME`). [pdf p.512] After "yes":

```bash
# CHANGES  (creates the Secret velero-objects-credentials in the Velero namespace)
source ~/nkp-<cluster>.env 2>/dev/null
: "${VELERO_NS:?}" "${BSL_NAME:?}" "${OBJECTS_ACCESS_KEY:?}" "${OBJECTS_SECRET_KEY:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" apply -f - >/dev/null <<EOF && echo "secret applied"
apiVersion: v1
kind: Secret
metadata:
  name: velero-objects-credentials
  namespace: $VELERO_NS
type: Opaque
stringData:
  aws: |
    [$BSL_NAME]
    aws_access_key_id = $OBJECTS_ACCESS_KEY
    aws_secret_access_key = $OBJECTS_SECRET_KEY
EOF
```

3. Choose one path with the user:
   - **Add a BSL** (the Ceph BSL stays the default). The CLI form of the guide [pdf p.518]:

```bash
# CHANGES  (adds a BackupStorageLocation; the default BSL does not change)
source ~/nkp-<cluster>.env 2>/dev/null
: "${VELERO_NS:?}" "${BSL_NAME:?}" "${OBJECTS_BUCKET:?}" "${OBJECTS_URL:?}"
velero backup-location create "$BSL_NAME" -n "$VELERO_NS" --kubeconfig "$CLUSTER_KUBECONFIG" --provider aws --bucket "$OBJECTS_BUCKET" --credential velero-objects-credentials=aws --config "region=us-east-1,s3ForcePathStyle=true,profile=$BSL_NAME,s3Url=$OBJECTS_URL"
```

   The guide adds `insecureSkipTLSVerify="true"` to `--config`. [pdf p.518] Add it only when the user accepts no TLS check. With a private CA, use the next path (`caCert`).

   - **Replace the default BSL** (and run without Rook Ceph): a `velero-overrides` ConfigMap on the AppDeployment. The values are below. Put the values of this cluster in place of `<bsl-name>`, `<bucket>`, and `<objects-url>` (from `BSL_NAME`, `OBJECTS_BUCKET`, `OBJECTS_URL`). Get the `caCert` value with the block after the values. Without a CA file, remove the `caCert` line. Apply them with skill `nkp-platform-apps-gitops` (AppDeployment `configOverrides`, or `clusterConfigOverrides` when the workspace has more than one cluster, because each cluster needs its own bucket). [pdf p.513-515]

```yaml
credentials:
  extraSecretRef: ""
configuration:
  features: EnableCSI
  backupStorageLocation:
    - name: <bsl-name>
      bucket: <bucket>
      provider: "aws"
      default: true
      caCert: <the output of the caCert block>
      config:
        region: us-east-1
        s3ForcePathStyle: "true"
        insecureSkipTLSVerify: "false"
        s3Url: "<objects-url>"
        profile: <bsl-name>
      credential:
        key: aws
        name: velero-objects-credentials
deployNodeAgent: true
nodeAgent:
  podVolumePath: /var/lib/kubelet/pods
  tolerations:
    - operator: Exists
```

The `caCert` value is the PEM CA file in Base64, on one line. A CA certificate is not a secret.

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
: "${OBJECTS_CA_FILE:?}"
base64 < "$OBJECTS_CA_FILE" | tr -d '\n'; echo
```

- Without a CA file, the guide sets `insecureSkipTLSVerify: "true"` and no `caCert`. [pdf p.514] Use it only when the user accepts no TLS check.
- Without Rook Ceph, the `velero-pre-install` job can wait for one hour. The guide deletes it and applies a job that only sleeps. [pdf p.516] Do that only with the user, and only when `rook-ceph-cluster` is not enabled.
- On a management cluster with Ultimate, the license deploys `rook-ceph`, `rook-ceph-cluster`, and `velero`. The guide disables them right after the license when Velero must run without Ceph. [pdf p.511]
- AWS S3: the same form, with the AWS region, `s3ForcePathStyle: "false"`, and an empty `s3Url`. [pdf p.520]

Done when: B2 shows the new BSL `Available`.

## B5. Volume data (file system backup)

NKP default backups take no volume snapshots. [pdf p.533] To back up the data in PVs, the guide uses the Velero node agent (restic). [pdf p.479, p.544]

1. Add `deployNodeAgent: true` to the Velero overrides (skill `nkp-platform-apps-gitops`). The `node-agent` DaemonSet starts in `VELERO_NS`. [pdf p.479]
2. Annotate each pod with `backup.velero.io/backup-volumes` and the **volume name** (not the PVC name). [pdf p.545] The annotation is lost when the pod is made again. Put it in the pod template of the app for a lasting setting (the app owner).

```bash
# CHANGES  (annotates one pod so that Velero copies its volume data)
source ~/nkp-<cluster>.env 2>/dev/null
ns=''; pod=''; vol=''
: "${ns:?}" "${pod:?}" "${vol:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" annotate pod "$pod" "backup.velero.io/backup-volumes=$vol"
```

3. Run B3 for that namespace. Then check the volume copies: `kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get podvolumebackups -A` (READ-ONLY). STATUS must be `Completed`. [pdf p.481]

- A field note uses `uploaderType: kopia` in place of restic. [field]
- Velero CSI snapshots with the Nutanix CSI are not in the skills ([csi.md](csi.md), C6).

## B6. Schedules

```bash
# CHANGES  (adds a backup schedule)
source ~/nkp-<cluster>.env 2>/dev/null
name=''; every=''; nss=''
: "${name:?}" "${every:?}"
velero create schedule "$name" -n "$VELERO_NS" --kubeconfig "$CLUSTER_KUBECONFIG" --snapshot-volumes=false --schedule="@every $every" ${nss:+--include-namespaces="$nss"}
```

- `every`: for example `8h` or `24h`. `nss`: optional, a comma list of namespaces. [pdf p.533-534]
- To change `velero-default`, the guide deletes it (`velero delete schedule velero-default`) and makes it again with the new interval. [pdf p.534] Both are CHANGES.

## B7. Management cluster disaster recovery

The guide backs up the management plane (workspaces, projects, apps, RBAC, KommanderClusters, CAPI objects and Secrets) to restore it into a standby or new management cluster. [pdf p.538-544]
- **It does not back up app volumes.** [pdf p.539]
- The target is either the `dkp-velero` bucket of a reachable standby management cluster, or an external S3 store (B4). [pdf p.539]

**Backup (on the primary).** All four blocks are CHANGES; show the whole plan once, then run them in order after "yes".

1. Pause all CAPI clusters. The guide patches the CAPI `Cluster` here. This is the one case where the skills patch the CAPI `Cluster` (only `spec.paused`; the webhooks accept it [live 2.19.0]). While paused, CAPI does not repair or scale any cluster. The same block resumes: `paused='false'`. Set `kc` to `$MGMT_KUBECONFIG` on the primary, or to `$DR_KUBECONFIG` on the target (write `kc="$MGMT_KUBECONFIG"` or `kc="$DR_KUBECONFIG"`).

```bash
# CHANGES  (pauses or resumes CAPI reconcile of every cluster)
source ~/nkp-site.env 2>/dev/null
paused=''; kc=''
: "${paused:?}" "${kc:?}"
kubectl --kubeconfig "$kc" get clusters.cluster.x-k8s.io -A --no-headers -o custom-columns=NS:.metadata.namespace,NAME:.metadata.name | while read -r ns n; do kubectl --kubeconfig "$kc" -n "$ns" patch clusters.cluster.x-k8s.io "$n" --type merge -p "{\"spec\":{\"paused\":$paused}}"; done
```

UNKNOWN (D-24): whether the NKPCluster controller sets `spec.paused` back to false. Find out with: `source ~/nkp-site.env 2>/dev/null && kubectl --kubeconfig "$MGMT_KUBECONFIG" get clusters.cluster.x-k8s.io -A -o custom-columns=NAME:.metadata.name,PAUSED:.spec.paused` one minute after the pause.

2. The backup (`name` and the target BSL `bsl`):

```bash
# CHANGES  (Velero writes the management plane backup)
source ~/nkp-site.env 2>/dev/null
name=''; bsl=''
: "${name:?}" "${bsl:?}"
velero --kubeconfig "$MGMT_KUBECONFIG" backup create "$name" -n kommander --storage-location "$bsl" --snapshot-volumes=false --wait
```

3. Check it (B3 check block, with `-n kommander`).
4. Resume: the step 1 block with `paused='false'`. Do the resume also when the backup fails.

**Restore (on the target).** `DR_KUBECONFIG` points to the target. The target must see the same BSL. Restore in this order, one run of the block below for each row [pdf p.542-544]. Show the whole plan once (all rows); after "yes", run the rows in order. Set `row` (the suffix), `res` (the resources, a comma list), and `sel` (the other flags, a bash array; `sel=()` when the row shows `()`).

| # | `row` | `res` | `sel` |
|---|---|---|---|
| 1 | `ws` | `workspaces` | `()` |
| 2 | `pr` | `workspaces,projects` | `()` |
| 3 | `cm` | `configmaps` | `(-l kommander.d2iq.io/managed-by-kind=AppDeployment)` |
| 4 | `misc` | appdeployments, kommanderprojectroles, kommanderworkspaceroles, projectroles, virtualgroups, and the `virtualgroup*rolebindings` (the guide text is cut; list them with `kubectl api-resources -o name` and a grep for `virtualgroup`) | `()` |
| 5 | `kc` | `kommanderclusters` | `()` |
| 6 | `secrets` | `secrets` | `(--exclude-namespaces default -l cluster.x-k8s.io/cluster-name)` |
| 7 | `provider-secrets` | `secrets` | `(--exclude-namespaces default -l cluster.x-k8s.io/provider)` |
| 8 | `cap-secrets` | `secrets` | `(--include-namespaces ns1,ns2)`: the namespaces whose name has `cap` |
| 9 | `capi` | every CRD name with `cluster.x` or `preprovisioned` | `(--exclude-namespaces default)` |
| 10 | resume | the step 1 block with `paused='false'` and `kc="$DR_KUBECONFIG"` | |

```bash
# CHANGES  (restores one row of the management plane backup into the target management cluster)
source ~/nkp-site.env 2>/dev/null
name=''; row=''; res=''; sel=()
: "${name:?}" "${row:?}" "${res:?}" "${DR_KUBECONFIG:?}"
velero --kubeconfig "$DR_KUBECONFIG" restore create "$name-$row" -n kommander --include-resources "$res" "${sel[@]}" --from-backup "$name" --wait
```

- A workspace with a generated namespace: make it by hand on the target with the old `spec.namespaceName` before row 1. [pdf p.542]
- Then the user checks the workspaces, projects, apps, RBAC, and nodes in the target UI. [pdf p.544]
- Prism Central itself (PCBR): [csi.md](csi.md), C11.

## B8. Restore into the same cluster

Rules [pdf p.535-536]: same cluster, same NKP version, Rook Ceph (or the BSL) and Velero work. The guide also asks for "restore-only mode" to stop backups during the restore. UNKNOWN (D-23): how NKP sets Velero restore-only mode. Find out with: `source ~/nkp-<cluster>.env 2>/dev/null && kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$VELERO_NS" get backupstoragelocations -o custom-columns=NAME:.metadata.name,MODE:.spec.accessMode`. Until then, tell the user that a schedule can run during the restore.

On the management cluster, these steps are needed (all CHANGES, one plan, "yes"):

1. Delete the ResourceQuota (the restore brings it back). [pdf p.535] It exists on 2.19.0. [live 2.19.0]

```bash
# CHANGES  (deletes the KommanderCluster quota; the restore brings it back)
source ~/nkp-site.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n kommander delete resourcequota one-kommandercluster-per-kommander-workspace
```

2. Remove `CREATE` from rule 3 of the webhook `kommander-validating` (rule 3 = workspaces and projects [live 2.19.0]). The `test` ops stop the patch when the index is wrong. [live 2.19.0]

```bash
# CHANGES  (lets the restore create workspaces; turn it back on in step 5)
source ~/nkp-site.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" patch validatingwebhookconfigurations kommander-validating --type json -p '[{"op":"test","path":"/webhooks/0/rules/3/resources/1","value":"workspaces"},{"op":"test","path":"/webhooks/0/rules/3/operations/0","value":"CREATE"},{"op":"remove","path":"/webhooks/0/rules/3/operations/0"}]'
```

3. Restore the backup `name` (list them with `velero backup get` [pdf p.536]):

```bash
# CHANGES  (restores the backup into this cluster)
source ~/nkp-site.env 2>/dev/null
name=''
: "${name:?}"
velero restore create --from-backup "$name" -n kommander --kubeconfig "$MGMT_KUBECONFIG" --wait
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n kommander get restores.velero
```

   The phase must be `Completed`. Read the log as in B3.
4. Check: `kubectl --kubeconfig "$MGMT_KUBECONFIG" -n kommander get resourcequota one-kommandercluster-per-kommander-workspace`. [pdf p.536]
5. Put `CREATE` back:

```bash
# CHANGES  (turns the kommander-validating CREATE rule back on)
source ~/nkp-site.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" patch validatingwebhookconfigurations kommander-validating --type json -p '[{"op":"test","path":"/webhooks/0/rules/3/resources/1","value":"workspaces"},{"op":"add","path":"/webhooks/0/rules/3/operations/0","value":"CREATE"}]'
```

Done when: the restore phase is `Completed`, the quota exists, and rule 3 shows `["CREATE","UPDATE"]`.

## B9. Velero failures

| Symptom | Cause | Fix |
|---|---|---|
| BSL not `Available` | Wrong URL, bucket, profile, key, or CA; the endpoint name does not resolve in the cluster. [pdf p.511] | `kubectl describe backupstoragelocations -n "$VELERO_NS"`. [pdf p.518] Fix the value. DNS: skill `nkp-networking`. |
| HelmRelease `velero` does not use the overrides | The AppDeployment does not point to the ConfigMap. | `kubectl get hr -n "$VELERO_NS" velero -o jsonpath='{.spec.valuesFrom}'` must list `velero-overrides`. [pdf p.515] |
| `velero-pre-install` job waits | Rook Ceph is not there. [pdf p.516] | B4 note. |
| `describe` or `logs` fails | In-cluster Ceph BSL. [pdf p.536] | B3: `kubectl logs -l name=velero`. |
| Ceph bucket full | The Velero bucket has a size cap. | [object-storage.md](object-storage.md), O2. |
