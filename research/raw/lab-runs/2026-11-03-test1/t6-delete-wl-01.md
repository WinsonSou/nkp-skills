# t6-delete-wl-01 — delete workload cluster `skilltest-wl-01` + its workspace `skilltest-ws`, then the PC leftovers

Operator host `<bastion>`; Prism Central `<pc>`. Management cluster `nkp-mgmt-01` (NKP 2.19.0).
Skills followed: `nkp-cluster-lifecycle` `references/delete.md` **D1, D2, D3, D5**; the workspace delete came from
`nkp-identity-security` `references/rbac.md` R5 (it says a workspace can be deleted only when it has no clusters,
but gives no command — see Learnings 1). PC part: `ntnx-skills` `nutanix-api` (GET + ETag DELETE), the same flow as t1.
Standing approval from the task brief for every CHANGES block in scope (the D2 "yes + cluster name" was given for
`skilltest-wl-01`). `~/nkp-site.env` untouched. `skilltest-wl-01` objects only: `skilltest-wl-02` (parallel agent) and
`nkp-mgmt-01` were never changed.

**Status: done.** Delete RC=0 in **57 s** (05:56:01 → 05:56:58 UTC). NKPCluster **gone, not stuck in `Error`**.
VMs 7 → 0. **The 4 volume groups stayed** (P-11 answered: they survive with the VM attachment dropped) and were
deleted in step 6. Workspace `skilltest-ws` + namespace `skilltest-ws-7kr7h` deleted, but **only after clearing
finalizers by hand** — the plain delete hung for 5 min and did not finish.

## 1. Before: D1 + D2 (READ-ONLY)

Block = D1 block + all five D2 blocks, plus the P-11 `pv` list (with `NS`/`PVC` columns) and the IP checks.

```text
set: CLUSTER_NAME WORKSPACE_NS CLUSTER_KUBECONFIG MGMT_KUBECONFIG
D1: skilltest-ws-7kr7h/skilltest-wl-01  MGMT=<none>  PHASE=Reconciled  CP=3          -> workload cluster, go to D2
nkpclusters -A: kommander/nkp-mgmt-01 Reconciled | skilltest-ws-7kr7h/skilltest-wl-01 Reconciled | kommander-default-workspace/skilltest-wl-02 Reconciled
nodes: 7 Ready v1.36.2 (3 control-plane + 4 md-0)
ns: 15 (13 platform + skilltest-app + skilltest-ws-7kr7h)
pvc: skilltest-app/pvc-data 1Gi Bound pvc-2f512541-... ; skilltest-ws-7kr7h/{db-prometheus-...-0 100Gi, kube-prometheus-stack-grafana 10Gi, opencost-pvc 10Gi}
svc type=LoadBalancer: skilltest-app/app-lb <net>.61 ; skilltest-ws-7kr7h/kommander-traefik <net>.62
get nkpclusters -A (workload kubeconfig): error: the server doesn't have a resource type "nkpclusters"   -> cluster manages no other cluster
pv (P-11): 4 PVs
  pvc-2f512541-e0f6-461a-ad4e-4d4aebd0c015  NutanixVolumes-3d09625b-1941-432e-45a1-d7ca8aa355a5  skilltest-app      pvc-data
  pvc-336f770d-b8ef-4f50-a16e-9420580e07a4  NutanixVolumes-660c374f-9c63-441f-4449-9d6edd22eb56  skilltest-ws-7kr7h db-prometheus-kube-prometheus-stack-prometheus-0
  pvc-51214615-89ea-4dce-845c-4b04b4c8ded8  NutanixVolumes-51216478-c2c3-4376-5c03-ffea42951aa4  skilltest-ws-7kr7h opencost-pvc
  pvc-666b963b-ab22-49cf-8763-2273606f3002  NutanixVolumes-f1360829-df93-4f92-6a90-7ac067bb3076  skilltest-ws-7kr7h kube-prometheus-stack-grafana
before: curl <net>.61 http=200 ; ping <net>.60 rc=0 ; ping <net>.61 rc=1
```

D2 gate: no nested NKPCluster; PVC data can go (approval given); the exact cluster was named. Plan shown as the
D2 four items (command D3 + name + namespace + management cluster · what goes · D5 what stays · approval).

### PC before (laptop, `ntnx.py`)

```text
VMs with prefix skilltest-wl-01: 7   (3 CP + 4 md-0, all power ON)
VGs total 35; description contains "for skilltest-wl-01": 4, each attached (vm-attachments = 1 VM):
  pvc-2f512541-e0f6-461a-ad4e-4d4aebd0c015  extId 3d09625b-1941-432e-45a1-d7ca8aa355a5  PVC:pvc-data                    att -> bbb98ad0 (worker)
  pvc-666b963b-ab22-49cf-8763-2273606f3002  extId f1360829-df93-4f92-6a90-7ac067bb3076  PVC:kube-prometheus-stack-grafana att -> c904071c (worker)
  pvc-336f770d-b8ef-4f50-a16e-9420580e07a4  extId 660c374f-9c63-441f-4449-9d6edd22eb56  PVC:db-prometheus-...-0           att -> bbb98ad0
  pvc-51214615-89ea-4dce-845c-4b04b4c8ded8  extId 51216478-c2c3-4376-5c03-ffea42951aa4  PVC:opencost-pvc                  att -> 1343e1f2 (worker)
  K8sClusterID of all four: 719aa38b-0043-4e48-a499-071e7961588d
```

## 2. D3 delete (CHANGES) — tmux `wl1del`, log `~/skilltest-wl-01-delete.log`

`nkp delete cluster --cluster-name "$CLUSTER_NAME" --namespace "$WORKSPACE_NS" --kubeconfig "$MGMT_KUBECONFIG" --timeout 30m`

Real log, complete (7 lines, RC=0):

```text
2026-11-04 05:56:02 INF  • Deleting cluster resources for Cluster skilltest-ws-7kr7h/skilltest-wl-01...
 ✓ Deleting cluster resources for Cluster skilltest-ws-7kr7h/skilltest-wl-01
2026-11-04 05:56:02 INF  • Waiting for cluster to be fully deleted...
 ✓ Waiting for cluster to be fully deleted
2026-11-04 05:56:58 INF Deleted skilltest-ws-7kr7h/skilltest-wl-01 cluster
RC=0
END 2026-11-04T05:56:58Z
```

**57 s.** D3 lists two output lines that did **not** appear: `Deleting Services with type LoadBalancer` and
`Deleting ClusterResourceSets` (Learnings 2).

## 3. After: D3 checks (READ-ONLY, 05:58:17)

```text
get nkpclusters,clusters...,machines -l cluster.x-k8s.io/cluster-name=skilltest-wl-01  -> No resources found in skilltest-ws-7kr7h namespace.
get nkpcluster skilltest-wl-01  -> Error from server (NotFound): nkpclusters.clusters.nkp.nutanix.com "skilltest-wl-01" not found
```

**The NKPCluster is gone. It is not stuck in `Error`** — no D3 cleanup delete was needed.

```text
workload kubeconfig: dial tcp <net>.60:6443: connect: no route to host   (VIP dead)
nutanixmachines -A: only the 7 nkp-mgmt-01 entries remain
ping <net>.60 rc=1 | ping <net>.61 rc=1 | curl <net>.60 http=000 | curl <net>.61 http=000
leftover in the workspace namespace: 7 Secrets (kommander-karma-server-tls, kommander-thanos-server-tls,
  sh.helm.release.v1.karma-traefik-certs.v1, sh.helm.release.v1.prometheus-traefik-certs.v1,
  skilltest-wl-01-oci-cert, skilltest-wl-01-oci-creds, tls-root-ca)
```

### PC after (laptop)

```text
VMs with prefix skilltest-wl-01: 0     (VMs total 22 -> 10)
VGs total 35, description "for skilltest-wl-01": 4   -- ALL STILL THERE, vm-attachments -> null
```

**P-11 answer (workload cluster, AHV, NKP 2.19.0):** the delete removes the VMs (and the disks of the nodes) but
**keeps every CSI volume group**, the user PVC's group and the platform PVC groups alike. The VM attachment is
dropped (`vm-attachments` → `data: null`, `attachments` gone), the group and its volume stay.

## 4. Delete the workspace `skilltest-ws`

Gap: **no skill has a workspace delete command.** `rbac.md` R5 says only "A workspace can be deleted only when it
has no clusters. [pdf p.318]". `nkp delete --help` lists only `bootstrap | capi-components | cluster | nodepool`
— there is **no `nkp delete workspace`**. So the delete had to go through the CRD.

CHANGES: `kubectl --kubeconfig "$MGMT_KUBECONFIG" delete workspace skilltest-ws --wait=true --timeout=300s`
(05:59:07 → 06:04:07, rc=1)

```text
workspace.workspaces.kommander.mesosphere.io "skilltest-ws" deleted
error: timed out waiting for the condition on workspaces/skilltest-ws
```

The namespace went to `Terminating` and stayed there. Namespace conditions:

```text
NamespaceContentRemaining=True  Some resources are remaining: federatedconfigmaps 3, federatednamespaces 1,
  federatedsecrets 3, helmchartproxies 1, helmreleaseproxies 1, workspaceroles 27
NamespaceFinalizersRemaining=True  helmchartproxy in 1, helmreleaseproxy in 1, kubefed.io/sync-controller in 7,
  workspaces.kommander.mesosphere.io/workspacerole in 27
```

Why: the Workspace delete (correctly) removes the controllers that own those finalizers — the workspace-role
controller and the workload cluster that ran the kubefed sync controller are both gone, so nothing clears them.

CHANGES (improvised, scope = that namespace only): clear the finalizers of the stuck objects, then the namespace
and the workspace went away on their own:

```text
for each of federatedconfigmaps.types.kubefed.io federatednamespaces.types.kubefed.io
federatedsecrets.types.kubefed.io helmchartproxies.addons.cluster.x-k8s.io
helmreleaseproxies.addons.cluster.x-k8s.io workspaceroles.workspaces.kommander.mesosphere.io in -n skilltest-ws-7kr7h:
  kubectl -n skilltest-ws-7kr7h patch <res> <name> --type=merge -p '{"metadata":{"finalizers":null}}'
  -> 33 objects patched (3 federatedconfigmaps, 1 federatednamespace, 1 helmchartproxy konnector-agent-01a1a4f8-...,
     1 helmreleaseproxy konnector-agent-skilltest-wl-01-rw8r8, 27 workspaceroles), no errors
```

Within ~30 s after the patch:

```text
ns skilltest-ws-7kr7h      -> Error from server (NotFound)
workspace skilltest-ws     -> NotFound; get workspaces shows only default-workspace and kommander-workspace
nkpclusters -A             -> only kommander/nkp-mgmt-01 Reconciled        (skilltest-wl-02 also gone: the parallel agent)
```

The Workspace object's own finalizer list went from `[workspace, workspacekustomization]` to `[workspace]` after the
delete call, i.e. the Kommander controller did its part and was waiting on the namespace.

## 5. D5 local files

READ-ONLY list (the D5 block) found 4 files; `ls ~ | grep skilltest-wl-01` found 7:

```text
-rw------- nkp-skilltest-wl-01-create.sh  1127
-rw------- skilltest-wl-01-dryrun.yaml   10894
-rw------- skilltest-wl-01-dryrun.err      236      <- NOT in the D5 block
-rw------- skilltest-wl-01.conf           5590
-rw------- nkp-skilltest-wl-01.env         245
-rw-rw-r-- skilltest-wl-01-create.log     1046      <- run log, kept
-rw-rw-r-- skilltest-wl-01-delete.log      407      <- this delete's log, kept
```

CHANGES: the D5 `rm` block plus `$HOME/$CLUSTER_NAME-dryrun.err`:

```text
removed nkp-skilltest-wl-01-create.sh, skilltest-wl-01-dryrun.yaml, skilltest-wl-01-dryrun.err,
        skilltest-wl-01.conf, nkp-skilltest-wl-01.env
left: skilltest-wl-01-create.log, skilltest-wl-01-delete.log   (run logs, no cluster state)
~/nkp-site.env still there (820 bytes, 600)   -- untouched
```

`~/skilltest-app.yaml` (the day-1 test manifest) is not matched by any D5 name and was left.

## 6. PC leftovers: delete the 4 volume groups (laptop, `nutanix.py`)

Flow per `nutanix-api` + the t1 precedent: fresh `GET` (object + ETag), assert the description still contains
`for skilltest-wl-01,`, assert `GET .../vm-attachments` is empty, `DELETE` with `If-Match`, then `GET` → 404.

```text
DELETE pvc-2f512541-e0f6-461a-ad4e-4d4aebd0c015  extId 3d09625b-1941-432e-45a1-d7ca8aa355a5  etag :NA==  PVC pvc-data                          task ok, GET 404
DELETE pvc-666b963b-ab22-49cf-8763-2273606f3002  extId f1360829-df93-4f92-6a90-7ac067bb3076  etag :NA==  PVC kube-prometheus-stack-grafana     task ok, GET 404
DELETE pvc-336f770d-b8ef-4f50-a16e-9420580e07a4  extId 660c374f-9c63-441f-4449-9d6edd22eb56  etag :NQ==  PVC db-prometheus-...-0               task ok, GET 404
DELETE pvc-51214615-89ea-4dce-845c-4b04b4c8ded8  extId 51216478-c2c3-4376-5c03-ffea42951aa4  etag :NA==  PVC opencost-pvc                      task ok, GET 404
```

Final sweep (06:05:5x UTC): `VMs total 10, prefix skilltest-wl-01: 0`; `VGs total 31 (was 35), desc
skilltest-wl-01: 0`. The 31 remaining are the 11 internal PC groups and the 20 groups of my repaired mgmt cluster
+ others.

## Timings

| Step | Time |
|---|---|
| D1 + D2 reads, PC before list | ~1 min |
| D3 delete (`nkp delete cluster`) | **57 s** (05:56:01 → 05:56:58, RC=0) |
| D3 checks + PC after list | ~1 min |
| workspace delete attempt | 5 min, **failed** (timeout, namespace Terminating) |
| finalizer patch (33 objects) + namespace/workspace gone | ~1 min |
| D5 list + remove | ~10 s |
| 4 volume groups deleted (+ verify) | ~15 s |
| **total** | ~11 min |

## Learnings

1. `[nkp-skill nkp-identity-security/references/rbac.md R5]` **No workspace delete step exists anywhere, and the CLI
   has none.** R5 says "A workspace can be deleted only when it has no clusters. [pdf p.318]" and stops. `nkp delete
   --help` = `bootstrap | capi-components | cluster | nodepool`; `nkp delete workspace --help` prints that same list,
   so a reader concludes the CLI has no such verb. Fix: add an R5 sub-block —
   `kubectl --kubeconfig "$MGMT_KUBECONFIG" delete workspace "$ws"` (CHANGES), plus the fact that this deletes the
   namespace too and that the object stays `Terminating` until the namespace is gone.

2. `[nkp-skill nkp-cluster-lifecycle/references/delete.md D3]` **The D3 output list does not match the real output of
   a workload-cluster delete.** D3 predicts "Deleting Services with type LoadBalancer", "Deleting ClusterResourceSets",
   "Deleting cluster resources", "Waiting for the cluster to be fully deleted", "Deleted ... cluster". Measured, the
   whole log is 3 lines + RC: `Deleting cluster resources` / `Waiting for the cluster to be fully deleted` /
   `Deleted skilltest-ws-7kr7h/skilltest-wl-01 cluster`. No `LoadBalancer` line, no `ClusterResourceSets` line — and
   the LB Services did go away (<net>.61 and .62 dead afterwards). Fix: say "the `LoadBalancer`/`ClusterResourceSets`
   lines appear on some deletes only; do not wait for them", and add the measured duration (57 s for a 7-node workload
   cluster) so a 30 m timeout looks generous.

3. `[fact]` **A workload-cluster delete leaves no `Error`-state NKPCluster.** D3's "The cluster stays in the UI in an
   `Error` state after the delete [pdf p.496]" did not happen: `get nkpcluster` → NotFound right after RC=0. Keep the
   paragraph as a fallback but mark it "not observed on 2.19.0 / AHV workload clusters".

4. `[nkp-skill nkp-cluster-lifecycle/references/delete.md D5]` **P-11 is answered for a workload cluster on AHV: the
   volume groups stay and keep their data.** Measured: 4 CSI groups (1 user PVC + 3 platform PVCs) survived, each with
   `vm-attachments` → `data: null` (attachment dropped, group + volume kept). Replace the UNKNOWN with:
   "`nkp delete cluster` on AHV deletes the VMs and the node disks, drops every CSI volume-group VM attachment, and
   **keeps the volume groups of the PVCs** (user and platform alike). They are unattached and cost storage until the
   user deletes them; the owning text is in `description` (`... for <cluster>, PVC:<name>, NS:<ns>`) and
   `K8sClusterID:<id>`." Point at the skill that removes them (see 6).

5. `[nkp-skill nkp-cluster-lifecycle/references/delete.md D3 check]` **The D3 "Done when" is too narrow: it leaves
   Secrets in the workspace namespace.** After the delete, `-n skilltest-ws-7kr7h get secrets` still shows 7 objects,
   including two named after the cluster (`skilltest-wl-01-oci-cert`, `skilltest-wl-01-oci-creds`) that hold a
   registry credential. Add a check + cleanup line: the workspace namespace keeps `*-oci-cert`, `*-oci-creds`,
   `kommander-*-tls` and `sh.helm.release.v1.*` Secrets after the cluster delete; they go away only with the workspace
   (or with an explicit delete).

6. `[ntnx-skill nutanix-api]` **Still no volume-group recipe** (t1 raised this): the NKP delete path always leaves
   `volumes/v4.0/config/volume-groups` objects behind, so the skill needs the "after an NKP cluster delete" block:
   select by `'for <cluster>,'` in `description` (the client's `$filter` does not search that text — `list_all` + a
   Python substring test worked), require `vm-attachments` → `data: null`, `DELETE` with the ETag. Confirmed again
   that a group ETag can be the literal `NA==`/`NQ==` and the delete accepts it.

7. `[fact]` **Deleting a Workspace in 2.19.0 does not complete by itself.** `kubectl delete workspace` (or any UI
   delete) hangs: the namespace stays `Terminating` because 33 objects carry finalizers whose controllers the
   workspace delete removes: 27 `workspaceroles` (`workspaces.kommander.mesosphere.io/workspacerole`), 7
   `federated{configmaps,secrets,namespaces}` (`kubefed.io/sync-controller`, the sync controller ran on the deleted
   workload cluster) and 2 `helm{chart,release}proxies` (`konnector-agent-*`). Clearing `metadata.finalizers` on those
   33 objects is enough. This is worth a `nkp-identity-security` block (it is the normal case right after a cluster
   delete, not an edge case).

8. `[nkp-skill nkp-cluster-lifecycle/references/delete.md D5]` **The D5 `rm` block misses `<cluster>-dryrun.err`.**
   `ls ~ | grep skilltest-wl-01` found `skilltest-wl-01-dryrun.err` (the N4D run writes stdout to the `.yaml` and
   stderr to the `.err`), which no D5 name covers. It also has no entry for the create/delete run logs
   (`<cluster>-create.log`, `<cluster>-delete.log`) or for the day-1 test manifests (`skilltest-app.yaml` here).
   Fix: add `"$HOME/$CLUSTER_NAME-dryrun.err"` to the list and the `rm`, and say in one line that run logs and test
   manifests are kept (the user decides).

9. `[fact]` `curl`/`ping` before and after are the fastest proof of a cluster delete: `http=200` on <net>.61 before,
   `ping` rc=1 and `http=000` on `.60`/`.61` after. Worth putting in D3's check block (one line), because the
   kubectl checks alone do not prove the MetalLB IPs came back to the pool.
