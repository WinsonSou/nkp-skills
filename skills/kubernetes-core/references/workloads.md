# Workloads: Deployment, StatefulSet, DaemonSet, Job, CronJob

Use this file from skill `kubernetes-core`. Do the `SKILL.md` step 3 owner check before every CHANGES block here. Set the empty shell values from the user or from step 1 output.

## W1. Read a workload

`kind` is `deployment`, `statefulset`, or `daemonset`.

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
ns=''; kind=''; name=''
: "${ns:?}" "${kind:?}" "${name:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" get "$kind" "$name" -o wide
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" get "$kind" "$name" -o jsonpath='{range .status.conditions[*]}{.type}={.status} {.reason}: {.message}{"\n"}{end}'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" rollout status "$kind/$name" --timeout=10s
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" rollout history "$kind/$name"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" events --for "$kind/$name" --types=Warning
```

- Deployment: `Available=True` (`MinimumReplicasAvailable`) and `Progressing=True` (`NewReplicaSetAvailable`) is healthy. [live 2.19.0] `Progressing=False` with `ProgressDeadlineExceeded`: the new pods do not become ready (`progressDeadlineSeconds`, default 600) [live 2.19.0]. Read the new pods (file [pods.md](pods.md)).
- `ReplicaFailure=True` or no pods at all: the ReplicaSet cannot make pods. Read `kubectl describe rs -n <ns> -l <selector>`: `exceeded quota`, `forbidden: violates PodSecurity`, or a Gatekeeper `denied` message (skill `nkp-identity-security`).
- `rollout status` with `--timeout=10s` prints `Waiting for ...` and exits with an error when the rollout is not done. That is not a failure of the command.
- StatefulSet: `READY` counts ready pods. With `podManagementPolicy: OrderedReady` (the default), pod `N+1` waits until pod `N` is ready. One broken pod stops the rest.
- DaemonSet: `DESIRED` = the nodes that the pod can run on. `DESIRED` lower than the node count: taints or a node selector (file [scheduling.md](scheduling.md), S3-S4).

## W2. Roll back, restart

Rollout commands work on `deployments`, `daemonsets`, `statefulsets`. [live 2.19.0]

```bash
# CHANGES  (restarts all pods of one workload with a rolling update)
source ~/nkp-<cluster>.env 2>/dev/null
ns=''; kind=''; name=''
: "${ns:?}" "${kind:?}" "${name:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" rollout restart "$kind/$name"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" rollout status "$kind/$name" --timeout=600s
```

```bash
# READ-ONLY  (server dry run: prints the images of that revision, changes nothing)
source ~/nkp-<cluster>.env 2>/dev/null
ns=''; kind=''; name=''; rev=''
: "${ns:?}" "${kind:?}" "${name:?}" "${rev:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" rollout undo "$kind/$name" --to-revision="$rev" --dry-run=server -o jsonpath='{.spec.template.spec.containers[*].image}{"\n"}'
```

```bash
# CHANGES  (rolls one workload back to an earlier revision from "rollout history")
source ~/nkp-<cluster>.env 2>/dev/null
ns=''; kind=''; name=''; rev=''
: "${ns:?}" "${kind:?}" "${name:?}" "${rev:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" rollout undo "$kind/$name" --to-revision="$rev"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" rollout status "$kind/$name" --timeout=600s
```

The dry run works on the lab. [live 2.19.0] `rollout history` shows `CHANGE-CAUSE` `<none>` for most workloads, so compare the images.

- A workload that Helm or Flux owns goes back to the Git or chart state on the next reconcile. Roll back in the source (skill `nkp-platform-apps-gitops`).

## W3. Scale

```bash
# CHANGES  (sets the replica count of one Deployment or StatefulSet)
source ~/nkp-<cluster>.env 2>/dev/null
ns=''; kind=''; name=''; replicas=''
: "${ns:?}" "${kind:?}" "${name:?}" "${replicas:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" scale "$kind/$name" --replicas="$replicas"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" rollout status "$kind/$name" --timeout=600s
```

For a preview, run only the `scale` line with `--dry-run=server` (READ-ONLY). [live 2.19.0]

- A HorizontalPodAutoscaler (`kubectl get hpa -n <ns>`) changes the replicas again. Change its `minReplicas` instead.
- A Flux-owned workload with `replicas` in Git goes back on the next reconcile. Change the values (skill `nkp-platform-apps-gitops`).
- StatefulSet scale down deletes the highest ordinals first. Their PVCs stay (W5).

## W4. Job and CronJob

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
ns=''
: "${ns:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" get cronjobs,jobs
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" get jobs -o custom-columns='NAME:.metadata.name,COMPLETE:.status.conditions[?(@.type=="Complete")].status,FAILED:.status.conditions[?(@.type=="Failed")].reason,SUCCEEDED:.status.succeeded,FAILEDPODS:.status.failed'
```

- `FAILED` `BackoffLimitExceeded`: the pods failed `backoffLimit` times (default 6). `DeadlineExceeded`: `activeDeadlineSeconds` ended the Job. Read the logs of a failed pod: `kubectl logs job/<name> -n <ns>`, or the pods with the label `job-name=<name>`.
- `restartPolicy` of a Job pod is `Never` or `OnFailure`. With `OnFailure`, the same pod restarts and the old logs go; use `--previous`.
- `ttlSecondsAfterFinished` deletes the finished Job and its pods. Then the logs are gone.
- CronJob fields [live 2.19.0]: `schedule`, `timeZone`, `concurrencyPolicy` (`Allow`, `Forbid`, `Replace`), `startingDeadlineSeconds`, `suspend`, `successfulJobsHistoryLimit`, `failedJobsHistoryLimit`.
- A Job spec (except a few fields such as `suspend` and `parallelism`) cannot change. Delete and make the Job again.

Run a CronJob now (makes a new Job from its template):

```bash
# CHANGES  (makes one Job from a CronJob template; it runs the job once)
source ~/nkp-<cluster>.env 2>/dev/null
ns=''; cj=''
: "${ns:?}" "${cj:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" create job "$cj-manual-$(date +%s)" --from="cronjob/$cj"
```

## W5. StatefulSet and PVC basics

- Each pod gets a fixed name (`<sts>-0`, `<sts>-1`, ...) and its own PVC from `volumeClaimTemplates`, named `<template>-<sts>-<ordinal>`. A new pod with the same ordinal uses the same PVC.
- `serviceName` names a headless Service (`clusterIP: None`). It gives each pod the DNS name `<pod>.<service>.<ns>.svc.cluster.local`. The Service must exist.
- On a running StatefulSet, the API allows changes only to `replicas`, `ordinals`, `template`, `updateStrategy`, `revisionHistoryLimit`, `persistentVolumeClaimRetentionPolicy`, `minReadySeconds`. A change to `volumeClaimTemplates` is `Forbidden`. [live 2.19.0]
- `persistentVolumeClaimRetentionPolicy` (`whenDeleted`, `whenScaled`): the default is `Retain`, so PVCs stay after a delete or a scale down. [live 2.19.0] A new StatefulSet with the same name and template uses the old PVCs and their data.
- A bound PVC: only `resources.requests` (expand) and `volumeAttributesClassName` can change. The StorageClass cannot. [live 2.19.0] Expand with skill `nkp-storage-backup`, file `csi.md` C4.
- A `ReadWriteOnce` volume attaches to one node. A second pod on another node stays in `ContainerCreating` with `Multi-Attach error`. Use `ReadWriteMany` storage (skill `nkp-storage-backup`, file `csi.md` C5), or one replica, or `strategy.type: Recreate` for a Deployment.
- A pod stuck on a lost node keeps its PVC: file [pods.md](pods.md), P6.

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
ns=''
: "${ns:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" get pvc -o custom-columns='NAME:.metadata.name,STATUS:.status.phase,VOLUME:.spec.volumeName,CAPACITY:.status.capacity.storage,MODES:.spec.accessModes,CLASS:.spec.storageClassName'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get pv -o custom-columns='NAME:.metadata.name,CLAIM:.spec.claimRef.name,NS:.spec.claimRef.namespace,STATUS:.status.phase,RECLAIM:.spec.persistentVolumeReclaimPolicy,CLASS:.spec.storageClassName'
```

- A PV `Released`: its PVC was deleted and the policy is `Retain`. The data is still there. A new PVC does not bind to it on its own.
- PVC `Pending`, CSI errors, StorageClasses, snapshots, backups: skill `nkp-storage-backup`.

## W6. Deployment update strategy

- `strategy.type`: `RollingUpdate` (default) or `Recreate`. [live 2.19.0] `RollingUpdate` uses `maxSurge` and `maxUnavailable` (default `25%` each). [live 2.19.0]
- A rolling update needs room for `maxSurge` more pods. On a full cluster, the new pod stays `Pending` and the rollout stops. Use `maxSurge: 0` and `maxUnavailable: 1`, or add capacity.
- StatefulSet `updateStrategy`: `RollingUpdate` (highest ordinal first, one by one) or `OnDelete` (a pod updates only when you delete it).
- Field help: `kubectl explain deployment.spec.strategy --recursive`.
