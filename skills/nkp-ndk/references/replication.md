# Replication, failover, and failback

Each write block is CHANGES. Before you run it, show the values and the file path, and stop for "yes" (rule 2). Then do the dry run, show the plan again, and stop for "yes" before the apply.

Use this file from skill `nkp-ndk`. Both clusters must run NDK with the same TLS mode, and each must have its `StorageCluster` (SKILL.md steps 3-4). The **primary** cluster runs the app. The **replication** cluster gets the copies. Each block runs on one cluster: use the cluster env file of that cluster. Write blocks make a file; then do SKILL.md step 5 on the same cluster.

No lab run of these steps exists (D-04). The facts are from the NDK 2.3 guide [portal], the chart in the 2.19.0 bundle [live 2.19.0], and field notes [field].

## R0. Choose the replication type

| | Async | Sync | NearSync (`nearSyncDR`) |
|---|---|---|---|
| RPO | 1 hour or more (the schedule) | 0 | 10-15 min |
| Network | WAN is OK | RTT < 5 ms | WAN is OK |
| Prism Central | one, or two paired (Availability Zones `Reachable`) | **one** (the witness is in Prism Central) | one or two paired |
| Storage | Volumes, Files | Volumes, Files | Volumes only (and CN-RWX) |
| Targets | one or more (Files: one) | one | one |
| Failover | recipe jobs (R7), or a restore of a replicated snapshot | `AppPlannedFailover`, `AppUnplannedFailover` (R6) | same as sync (R6) |
| Point-in-time restore | yes | — | no (newest state only) |

[portal] Not allowed: async and NearSync on one app; two plan types to the same target cluster; more than one sync plan for one app. Allowed (3DC): sync to site 2 plus async or NearSync to site 3, in one `AppProtectionPlan`. [portal]

Common needs: the same StorageClass names and the same storage container names on both sites. [portal] Sync also needs Disaster Recovery on in Prism Central and the Prism Element ports 2030, 2036, 2073, 2090, 8740 open (on a separate DR network, use its interface). [portal] NearSync needs AOS and PC 7.5.1, and a VIP on the remote Prism Element. [portal] Ask the user to confirm these; they are outside the cluster.

## R1. Network between the clusters

- Each cluster has `ndk-intercom-service` (`LoadBalancer`, TCP 2021). [live 2.19.0] The firewall must let each cluster reach the intercom IP of the other on TCP 2021. [field]
- UNKNOWN (D-01): whether the NDK UI remote-site connection also needs TCP 347 (the NDK UI guide names 347; the 2.19.0 chart has only 2021). Find out with: `source ~/nkp-<cluster>.env 2>/dev/null && kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get svc -A | grep -E '2021|347'`.

On the **replication** cluster, read its intercom IP and its TLS name (READ-ONLY). Use the env file of the replication cluster:

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n ntnx-system get svc ndk-intercom-service -o jsonpath='{.status.loadBalancer.ingress[0].ip}{"\n"}'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n ntnx-system get configmap ndk-manager-config -o yaml | grep -E 'enableTLS|enableMTLS|clusterName'
```

Done when: you have the IP and the TLS mode of the replication cluster. Tell the user both, and ask them to confirm.

## R2. Remote (on the primary)

A `Remote` is cluster-scoped. It holds the address and the trust of the peer. [live 2.19.0 CRD] Set the values from R1 and from the user:

- `name`: a name for the peer (for example the peer cluster name).
- `peer_name`: `clusterName` of the peer. It must equal the DNS name in the peer certificate (`SELF_SIGNED`, `ISSUER`), or its SAN (`SECRET`). [portal] With TLS off, use the peer cluster name.
- `peer_ip`: the intercom IP from R1.
- `tls`: `off` (the peer has TLS off), `skip` (TLS, no CA check; for `SELF_SIGNED`), or `ca` (CA check; set `ca_file` to a PEM file of the CA that signed the peer certificate).
- `mtls_secret`: only for mTLS: a TLS Secret in `ntnx-system` with `tls.crt`, `tls.key`, `ca.crt`. [portal]

Show the plan, stop for "yes":

```bash
# CHANGES  (writes the Remote file on the operator host; changes no cluster)
source ~/nkp-<cluster>.env 2>/dev/null
name=''; peer_name=''; peer_ip=''; tls=''; ca_file=''; mtls_secret=''
: "${name:?}" "${peer_name:?}" "${peer_ip:?}" "${tls:?off, skip, or ca}"
case "$tls" in off|skip) ;; ca) : "${ca_file:?}"; [ -s "$ca_file" ] || { echo "no CA file: $ca_file"; exit 1; } ;; *) echo "bad tls: off, skip, or ca"; exit 1 ;; esac
if [ -n "$mtls_secret" ] && [ "$tls" = off ]; then echo "mTLS needs TLS"; exit 1; fi
f="$HOME/$CLUSTER_NAME-ndk-remote-$name.yaml"
{ printf 'apiVersion: dataservices.nutanix.com/v1alpha1\nkind: Remote\nmetadata:\n  name: %s\nspec:\n  clusterName: %s\n  ndkServiceIp: "%s"\n  ndkServicePort: 2021\n' "$name" "$peer_name" "$peer_ip"
  case "$tls" in
    off) ;;
    skip) printf '  tlsConfig:\n    skipTLSVerify: true\n' ;;
    ca) printf '  tlsConfig:\n    skipTLSVerify: false\n    caBundle: %s\n' "$(base64 < "$ca_file" | tr -d '\n')" ;;
  esac
  if [ -n "$mtls_secret" ]; then printf '    enableMTLS: true\n    mTLSClientConfig:\n      secretName: %s\n      secretNamespace: ntnx-system\n' "$mtls_secret"; fi
} > "$f" && cat "$f"
```

The CA bundle is a public certificate, not a secret. Then SKILL.md step 5. Check (READ-ONLY): `kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get remotes` shows AVAILABLE `True`. Not `True`: read the REASON column and operations.md X5. The `Remote` spec cannot change: to fix it, delete the `Remote` and make it again (CHANGES, plan, "yes").

For failback later, make the same `Remote` on the replication cluster, to the primary (R8).

## R3. ReplicationTarget (on the primary)

A `ReplicationTarget` is in the **source** namespace of the app. `namespaceName` is the namespace on the replication cluster. [live 2.19.0 CRD][portal] That namespace must exist on the replication cluster. [portal] One guide page uses `targetNamespace`; the CRD field is `namespaceName`. [live 2.19.0 CRD] Show the plan, stop for "yes":

```bash
# CHANGES  (writes the ReplicationTarget file on the operator host; changes no cluster)
source ~/nkp-<cluster>.env 2>/dev/null
ns=''; target=''; remote=''; dst_ns=''
: "${ns:?}" "${target:?}" "${remote:?}" "${dst_ns:?}"
f="$HOME/$CLUSTER_NAME-ndk-rt-$ns-$target.yaml"
printf 'apiVersion: dataservices.nutanix.com/v1alpha1\nkind: ReplicationTarget\nmetadata:\n  name: %s\n  namespace: %s\nspec:\n  remoteName: %s\n  namespaceName: %s\n' "$target" "$ns" "$remote" "$dst_ns" > "$f" && cat "$f"
```

Then SKILL.md step 5. Check: `kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" get replicationtargets` shows AVAILABLE `True`. [live 2.19.0 CRD] Not `True`: the spec cannot change, so delete the object and make it again (CHANGES, plan, "yes").

## R4. Replicate one snapshot now

Make a snapshot first (protect.md P2). Then show the plan, stop for "yes":

```bash
# CHANGES  (writes the ApplicationSnapshotReplication file on the operator host; changes no cluster)
source ~/nkp-<cluster>.env 2>/dev/null
ns=''; snap=''; target=''
: "${ns:?}" "${snap:?}" "${target:?}"
f="$HOME/$CLUSTER_NAME-ndk-rep-$ns-$snap.yaml"
printf 'apiVersion: dataservices.nutanix.com/v1alpha1\nkind: ApplicationSnapshotReplication\nmetadata:\n  name: %s-to-%s\n  namespace: %s\nspec:\n  applicationSnapshotName: %s\n  replicationTargetName: %s\n' "$snap" "$target" "$ns" "$snap" "$target" > "$f" && cat "$f"
```

Then SKILL.md step 5. Check on the primary: `kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" get applicationsnapshotreplications` shows AVAILABLE `True` and PROGRESS `100`. [live 2.19.0 CRD] On the replication cluster (its env file), protect.md P2 check in `dst_ns` lists the snapshot. A restore there is protect.md P3.

## R5. Protection plan with replication (async, sync, NearSync)

Write the `ProtectionPlan` and the `AppProtectionPlan` on the primary. `type` is `async`, `sync`, or `nearSyncDR`. `targets` is one or more ReplicationTarget names, separated by spaces (more than one only for async).

- async: also `JobScheduler` (protect.md P5 values `interval_min` (60 or more), `tz`) and `keep` (1-15). The replication cluster keeps at most 15 copies. [portal]
- sync: no schedule, no retention, one target. NDK makes `HAApplication` (`haa`). [portal]
- nearSyncDR: `rpo` from `10m` to `15m`, one target. NDK makes `AppNearSyncProtection` (`nsp`). [portal]

Show the plan, stop for "yes":

```bash
# CHANGES  (writes the replication plan file on the operator host; changes no cluster)
source ~/nkp-<cluster>.env 2>/dev/null
ns=''; app=''; plan=''; type=''; targets=''; interval_min=''; tz=''; keep=''; rpo=''
: "${ns:?}" "${app:?}" "${plan:?}" "${type:?async, sync, or nearSyncDR}" "${targets:?}"
f="$HOME/$CLUSTER_NAME-ndk-plan-$ns-$plan.yaml"
{ if [ "$type" = async ]; then printf 'apiVersion: scheduler.nutanix.com/v1alpha1\nkind: JobScheduler\nmetadata:\n  name: %s\n  namespace: %s\nspec:\n  interval:\n    minutes: %s\n  timeZoneName: "%s"\n---\n' "$plan" "$ns" "${interval_min:?}" "${tz:?}"; fi
  printf 'apiVersion: dataservices.nutanix.com/v1alpha1\nkind: ProtectionPlan\nmetadata:\n  name: %s\n  namespace: %s\nspec:\n  protectionType: %s\n' "$plan" "$ns" "$type"
  case "$type" in
    async) printf '  scheduleName: %s\n  retentionPolicy:\n    retentionCount: %s\n' "$plan" "${keep:?}" ;;
    nearSyncDR) printf '  rpo: %s\n' "${rpo:?}" ;;
  esac
  printf '  replicationConfigs:\n'; for t in $targets; do printf '  - replicationTargetName: %s\n' "$t"; done
  printf -- '---\napiVersion: dataservices.nutanix.com/v1alpha1\nkind: AppProtectionPlan\nmetadata:\n  name: %s-%s\n  namespace: %s\nspec:\n  applicationName: %s\n  protectionPlanNames:\n  - %s\n' "$app" "$plan" "$ns" "$app" "$plan"
} > "$f" && cat "$f"
```

Then SKILL.md step 5. For 3DC, add the second plan name to `protectionPlanNames` of the same `AppProtectionPlan` (edit the file, show it, step 5).

Check (READ-ONLY) on the primary, and for sync and NearSync also on the replication cluster:

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
ns=''; : "${ns:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" get protectionplans,appprotectionplans,applicationsnapshotreplications
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" get haa,nsp
```

Done when:
- async: a new `applicationsnapshotreplications` line reaches PROGRESS `100` after one interval.
- sync: `haa` on the primary shows SERVING `True`, SYNCHRONIZED `True`, INDEPENDENT `False`; on the replication cluster SERVING `False`, SYNCHRONIZED `True`, INDEPENDENT `False`. [portal]
- NearSync: `nsp` shows PROTECTED `True` on both clusters (reason `RPOMet`). `AppConfigRPONotMet` or `VolumeRPONotMet`: wait. [portal]

## R6. Failover for sync and NearSync

Do R5 "Done when" first, on both clusters. Then ask the user: planned (both sites run) or unplanned (the primary is down).

- Planned failover (PFO): make an `AppPlannedFailover` on the **replication** (not serving) cluster, in the app namespace there. [portal] NDK first takes a snapshot on the primary (NDK 2.2 and later). [portal]
- Unplanned failover (UPFO): make an `AppUnplannedFailover` on the replication cluster. NearSync allows it only when `nsp` shows a failure. The annotation `dataservices.nutanix.com/near-sync-force-allow-upfo: "true"` forces it. [portal] Use it only when the user asks for it.

Show the plan, stop for "yes":

```bash
# CHANGES  (writes the failover file on the operator host; changes no cluster)
source ~/nkp-<cluster>.env 2>/dev/null
ns=''; app=''; kind=''; force=''
: "${ns:?}" "${app:?}" "${kind:?AppPlannedFailover or AppUnplannedFailover}"
f="$HOME/$CLUSTER_NAME-ndk-failover-$ns-$app.yaml"
{ printf 'apiVersion: dataservices.nutanix.com/v1alpha1\nkind: %s\nmetadata:\n  name: %s-failover\n  namespace: %s\n' "$kind" "$app" "$ns"
  if [ "$force" = true ]; then printf '  annotations:\n    dataservices.nutanix.com/near-sync-force-allow-upfo: "true"\n'; fi
  printf 'spec:\n  applicationName: %s\n' "$app"
} > "$f" && cat "$f"
```

The plan must say: the app stops on the primary (PFO), the replication cluster serves it, and clients must use the new site. Then SKILL.md step 5 on the replication cluster. Check: `kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" get appplannedfailovers,appunplannedfailovers` shows COMPLETED `True`. [live 2.19.0 CRD]

- After a sync UPFO: SERVING `True`, SYNCHRONIZED `False` (`PeerNotAvailable`), INDEPENDENT `True` is normal. The state stays until the peer is back. [portal]
- PFO waits at the snapshot: operations.md X5.

## R7. Failover for async

Async uses no failover objects. Two ways:

1. **Restore on the replication cluster.** Restore the newest replicated snapshot there (protect.md P3, on the replication cluster, in `dst_ns`). [field] This brings the app up on the replication cluster. It does not stop the app on the primary and does not change the replication direction.
2. **NDK recipes** (the guide way). Jobs from `ndk-2.3.0-recipes.tar` in the NDK bundle (skill `nkp-airgap`, its file `prestage.md`, P7): `migrate` (PFO), `failover` (UPFO), `reset-replication`, `upfo_async_cleanup`. [portal] They run in their own namespace (not the app namespace), with Secrets that hold the kubeconfig of both clusters, and they need the image `ndk/recipes:2.3.0` in the registry. [portal] Their config files are not in the skills. UNKNOWN (D-52): the async recipe steps, config keys, and image path on NKP 2.19 (only the guide, no lab run). Find out with: `ls ndk-2.3.0-recipes/` in the extracted NDK bundle (the user's path), then read its files with the user.

## R8. Failback

- Sync: when the primary is back, NDK makes the pair again. Wait for R5 "Done when" on both sites. Then do R6 (PFO) on the old primary. [portal]
- NearSync after a UPFO: the old primary has a split brain. The guide steps: on the old primary, annotate the Application `dataservices.nutanix.com/cleanup-volumes: "true"`, set `spec.start: false`, wait for `Active`/`Terminated`, delete the Application; on the active site annotate `dataservices.nutanix.com/application-conflict-resolved: "true"`; then protect again in the other direction. [portal] Each item is a CHANGES step with a plan and "yes". The volume clean-up deletes data on the old primary.
- Async: on the replication cluster make R2 (to the old primary), R3, the Application (protect.md P1), and R5. Then fail back with R7. [portal]

## R9. Delete a protected application

Delete the `Application` on the **primary**, never on the replication cluster. NDK 2.2 and later then removes the protection on both sites. [portal] Show the plan, stop for "yes":

```bash
# CHANGES  (deletes the NDK Application object; NDK removes its protection objects on both sites)
source ~/nkp-<cluster>.env 2>/dev/null
ns=''; app=''; : "${ns:?}" "${app:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" delete applications.dataservices.nutanix.com "$app"
```

UNKNOWN (D-53): whether the delete of the `Application` keeps the PVCs and the workloads of the app. Find out with: `source ~/nkp-<cluster>.env 2>/dev/null && ns='' && : "${ns:?}" && kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" get pvc,deploy,sts` before and after the delete on a test app (set `ns` to its namespace).

An `haa` left on the replication cluster after a network break keeps the finalizer `dataservices.nutanix.com/haac-owned-haa`. The guide removes that finalizer, then deletes the `haa`. [portal] That is a last resort: tell the user, and use operations.md X5.
