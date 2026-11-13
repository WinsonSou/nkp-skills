# Protect one cluster: applications, snapshots, restore, schedules, ndkcli

Each write block is CHANGES. Before you run it, show the values and the file path, and stop for "yes" (rule 2). Then do the dry run, show the plan again, and stop for "yes" before the apply.

Use this file from skill `nkp-ndk`. NDK must run on the cluster (SKILL.md step 1), with a `StorageCluster` (step 4). Each write block makes a file on the operator host. Then do SKILL.md step 5 (dry run, plan, "yes", apply) with that file.

All kinds here are `dataservices.nutanix.com/v1alpha1`, except `JobScheduler` (`scheduler.nutanix.com/v1alpha1`). [live 2.19.0]

## P1. Define an application

An `Application` selects the objects of one app in one namespace: the workloads, their config, and their PVCs. [portal] NDK protects only volumes from Nutanix CSI (Volumes, Files). [portal]

1. Read the namespace and its labels (READ-ONLY). Ask the user which label selects the app.

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
ns=''; : "${ns:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" get deploy,sts,pvc,svc,cm --show-labels
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" get pvc -o custom-columns='NAME:.metadata.name,SC:.spec.storageClassName,STATUS:.status.phase'
```

- Every PVC must use a `csi.nutanix.com` StorageClass (skill `nkp-storage-backup`, step 1).
- Never use namespace `ntnx-system`. [portal]

2. Write the file. Set `ns`, `name`, and `sel` (one label, as `key=value`) to the values that the user gives. Show the plan, stop for "yes":

```bash
# CHANGES  (writes the Application file on the operator host; changes no cluster)
source ~/nkp-<cluster>.env 2>/dev/null
ns=''; name=''; sel=''
: "${ns:?}" "${name:?}" "${sel:?set one label as key=value}"
f="$HOME/$CLUSTER_NAME-ndk-app-$ns-$name.yaml"
cat > "$f" <<EOF
apiVersion: dataservices.nutanix.com/v1alpha1
kind: Application
metadata:
  name: $name
  namespace: $ns
spec:
  applicationSelector:
    resourceLabelSelectors:
    - labelSelector:
        matchLabels:
          ${sel%%=*}: "${sel#*=}"
EOF
cat "$f"
```

- `applicationSelector: {}` selects all objects in the namespace. Nutanix does not recommend it. [portal]
- `includeResources` and `excludeResources` (lists of `group` and `kind`) limit the kinds. [live 2.19.0 CRD] A field setup excludes the Cilium `CiliumEndpoint` kind when it selects all objects. [field]
- An application in more than one namespace (`namespaceSelectors.includeNamespaces`) needs `--enable-multins` on the NDK controllers of both clusters, AOS and PC 7.5.1, and has no cross-namespace restore. [portal] Its install values are not in the skills.

3. Step 5 of SKILL.md. Done when (READ-ONLY): `kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" get applications.dataservices.nutanix.com` shows ACTIVE `True`.

## P2. Take a snapshot now (out-of-band)

`expiresAfter` is required for a snapshot that you take by hand, and it cannot change. [live 2.19.0 CRD] Use `m` or `h`; the maximum is `1440h` (60 days). [portal] Ask the user for the time. Show the plan, stop for "yes":

```bash
# CHANGES  (writes the ApplicationSnapshot file on the operator host; changes no cluster)
source ~/nkp-<cluster>.env 2>/dev/null
ns=''; app=''; snap=''; expires=''
: "${ns:?}" "${app:?}" "${snap:?}" "${expires:?for example 24h}"
f="$HOME/$CLUSTER_NAME-ndk-snap-$ns-$snap.yaml"
cat > "$f" <<EOF
apiVersion: dataservices.nutanix.com/v1alpha1
kind: ApplicationSnapshot
metadata:
  name: $snap
  namespace: $ns
spec:
  source:
    applicationRef:
      name: $app
  expiresAfter: $expires
EOF
cat "$f"
```

Then SKILL.md step 5. Check (READ-ONLY):

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
ns=''; : "${ns:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" get applicationsnapshots
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get applicationsnapshotcontents
```

Done when: the snapshot shows READY-TO-USE `true` and a BOUND-SNAPSHOTCONTENT. [live 2.19.0 CRD]

- The snapshot fails when the config of the app (the objects, not the volume data) is more than 8 MB. NDK keeps it as a Secret in etcd. [portal]
- Crash consistency for each volume. Group consistency only for block volumes. [portal]
- NDK snapshots are not Velero backups. For Velero, use skill `nkp-storage-backup`.

## P3. Restore in the same namespace

A restore always goes into the namespace of the snapshot (P4 for another namespace). [portal] Nutanix recommends to delete the app and its PVCs first. [portal] That deletes data: ask the user. Show the plan for the delete and for the restore separately. The delete is the user's own step (`kubectl delete` of the app manifests); this skill does not give a delete block for app data.

1. List the snapshots (P2 check). Ask the user which one. A replicated snapshot on the replication cluster is listed the same way (replication.md R4).
2. Write the restore file. Its spec cannot change after the create. [live 2.19.0 CRD] Show the plan, stop for "yes":

```bash
# CHANGES  (writes the ApplicationSnapshotRestore file on the operator host; changes no cluster)
source ~/nkp-<cluster>.env 2>/dev/null
ns=''; snap=''; restore=''
: "${ns:?}" "${snap:?}" "${restore:?}"
f="$HOME/$CLUSTER_NAME-ndk-restore-$ns-$restore.yaml"
cat > "$f" <<EOF
apiVersion: dataservices.nutanix.com/v1alpha1
kind: ApplicationSnapshotRestore
metadata:
  name: $restore
  namespace: $ns
spec:
  applicationSnapshotName: $snap
EOF
cat "$f"
```

3. SKILL.md step 5. Check (READ-ONLY): `kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" get applicationsnapshotrestores` shows COMPLETED `true`. [live 2.19.0 CRD] Then the app pods and PVCs are back (P1 item 1).

## P4. Restore into another namespace (ReferenceGrant)

Only for an application in one namespace. [portal] The target namespace must exist.

1. The CRD `referencegrants.gateway.networking.k8s.io` (`v1beta1`) is on NKP 2.19.0 clusters (app `gateway-api-crds`). Check it with SKILL.md step 1. Do not download it. [live 2.19.0]
2. The `ReferenceGrant` goes in the **source** namespace (where the snapshot is). It lets an `ApplicationSnapshotRestore` in the target namespace read that one snapshot. [portal] Write both objects into one file. Show the plan, stop for "yes":

```bash
# CHANGES  (writes the ReferenceGrant and ApplicationSnapshotRestore file on the operator host; changes no cluster)
source ~/nkp-<cluster>.env 2>/dev/null
src=''; dst=''; snap=''; restore=''
: "${src:?}" "${dst:?}" "${snap:?}" "${restore:?}"
f="$HOME/$CLUSTER_NAME-ndk-xns-restore-$dst-$restore.yaml"
cat > "$f" <<EOF
apiVersion: gateway.networking.k8s.io/v1beta1
kind: ReferenceGrant
metadata:
  name: ndk-restore-$snap-to-$dst
  namespace: $src
spec:
  from:
  - group: dataservices.nutanix.com
    kind: ApplicationSnapshotRestore
    namespace: $dst
  to:
  - group: dataservices.nutanix.com
    kind: ApplicationSnapshot
    name: $snap
---
apiVersion: dataservices.nutanix.com/v1alpha1
kind: ApplicationSnapshotRestore
metadata:
  name: $restore
  namespace: $dst
spec:
  applicationSnapshotName: $snap
  applicationSnapshotNamespace: $src
EOF
cat "$f"
```

3. SKILL.md step 5. Check as in P3, item 3, in namespace `dst`.

- The ReferenceGrant name in the block is only a name; NDK does not read it. Remove the grant after the restore (CHANGES, plan, "yes").

## P5. Local schedule (snapshots with retention, no replication)

Three objects: a `JobScheduler` (when), a `ProtectionPlan` (how many to keep), and an `AppProtectionPlan` (which application). [portal] A local plan has no `protectionType` and no `replicationConfigs`. [portal]

- `interval_min` is the time between snapshots in minutes: 60 or more. [live 2.19.0 CRD] The CRD says this only in its description, so the dry run can accept a lower value. Other schedule forms: `daily: {time: "10:00"}`, `weekly: {days: MON-FRI, time: "10:00"}`, `monthly: {dates: "1,15", time: "10:00"}`, `cronSchedule`. [live 2.19.0 CRD][portal] `startTime` is optional, RFC 3339, in the future. `timeZoneName` is an IANA name (default UTC). [portal]
- `keep` is 1 to 15. [portal]
- The `ProtectionPlan` spec cannot change. [live 2.19.0 CRD] To change the schedule or the count, make a new plan and point the `AppProtectionPlan` to it.

Show the plan, stop for "yes":

```bash
# CHANGES  (writes the JobScheduler, ProtectionPlan, and AppProtectionPlan file on the operator host; changes no cluster)
source ~/nkp-<cluster>.env 2>/dev/null
ns=''; app=''; plan=''; interval_min=''; keep=''; tz=''
: "${ns:?}" "${app:?}" "${plan:?}" "${interval_min:?}" "${keep:?1 to 15}" "${tz:?for example UTC}"
f="$HOME/$CLUSTER_NAME-ndk-plan-$ns-$plan.yaml"
cat > "$f" <<EOF
apiVersion: scheduler.nutanix.com/v1alpha1
kind: JobScheduler
metadata:
  name: $plan
  namespace: $ns
spec:
  interval:
    minutes: $interval_min
  timeZoneName: "$tz"
---
apiVersion: dataservices.nutanix.com/v1alpha1
kind: ProtectionPlan
metadata:
  name: $plan
  namespace: $ns
spec:
  scheduleName: $plan
  retentionPolicy:
    retentionCount: $keep
---
apiVersion: dataservices.nutanix.com/v1alpha1
kind: AppProtectionPlan
metadata:
  name: $app-$plan
  namespace: $ns
spec:
  applicationName: $app
  protectionPlanNames:
  - $plan
EOF
cat "$f"
```

Then SKILL.md step 5, and P6.

## P6. Check the protection

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
ns=''; : "${ns:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" get jobschedulers,protectionplans,appprotectionplans
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" get applicationsnapshots --sort-by=.metadata.creationTimestamp
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" get events --sort-by=.lastTimestamp | tail -20
```

Done when: the `ProtectionPlan` and the `AppProtectionPlan` show AVAILABLE `True` and DEGRADED not `True`, the `JobScheduler` shows a NEXTACTIVATION, and a new snapshot is READY-TO-USE `true` after one interval. [live 2.19.0 CRD]

Snapshot conditions, in order: `Progressing`, `AppConfigAcquired`, `VolumeSnapshotsCreated`, `ApplicationSnapshotFinalized`. [portal] The first one that is not `True` is the failed stage: `kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" describe applicationsnapshot <name>` (READ-ONLY; put the name in place of `<name>`).

## P7. ndkcli

`ndkcli` makes the same objects with short commands (NDK 2.1 and later). It is not in the NKP bundle: the user gets the NDK CLI bundle from the portal (skill `nkp-airgap`, its file `prestage.md`, P7). [portal] It uses the current kubeconfig context. [portal] The flags below are from the guide and field notes, not from a lab run (D-04). Check each with `ndkcli <command> --help` first.

Use `ndkcli` only with `--dry-run=client -o yaml`: it then prints the object and changes nothing. [portal] Save the output to a file and use SKILL.md step 5. Then the approval gate and the server dry run are the same as for the files above. Show the plan, stop for "yes":

```bash
# CHANGES  (writes the object that ndkcli prints to a file on the operator host; changes no cluster)
source ~/nkp-<cluster>.env 2>/dev/null
ns=''; app=''; sel=''; : "${ns:?}" "${app:?}" "${sel:?}"
f="$HOME/$CLUSTER_NAME-ndkcli-app-$ns-$app.yaml"
KUBECONFIG="$CLUSTER_KUBECONFIG" ndkcli create application "$app" -n "$ns" --selector="$sel" --dry-run=client -o yaml > "$f" && cat "$f"
```

Other commands, same pattern (`--dry-run=client -o yaml > file`) [portal][field]:

| Job | Command |
|---|---|
| Snapshot now | `ndkcli create snapshot SNAP --application=APP --expires-after=24h -n NS` |
| Replication target | `ndkcli create replicationtarget NAME --target-cluster=PEER --target-namespace=NS -n NS` |
| Replicate a snapshot | `ndkcli replicate snapshot SNAP --replication-target=NAME -n NS` |
| Restore | `ndkcli perform restore NAME --application-snapshot-name=SNAP -n NS` |
| Async plan | `ndkcli create protectionplan NAME --type=async --target-cluster=PEER --target-namespace=NS --schedule="interval:60" -n NS` |
| Protect | `ndkcli protect application APP --protection-plans=NAME -n NS` |
| Failover (sync, NearSync) | `ndkcli perform failover NAME --type=planned --application=APP -n NS` (`--type=unplanned` for UPFO) |

- The upper-case words are the values that the user gives.
- `create replicationtarget` and `create protectionplan` with `--target-cluster` can also make the `Remote` for you. [portal] Then the dry-run file can hold more than one object: read all of it in the plan.
- Two clusters: `KUBECONFIG=a.conf:b.conf` and `kubectl config use-context`. [portal] In this skill, run one cluster at a time with `KUBECONFIG="$CLUSTER_KUBECONFIG"`.
