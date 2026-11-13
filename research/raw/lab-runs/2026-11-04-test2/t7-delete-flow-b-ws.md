# T7 — `t7-delete-flow-b-ws`: delete workload cluster `skilltest-flow-b`, then delete workspace `skilltest-flow` through the NKP web UI

Executor `lt2-build-5`. Date 2026-11-04/05. NKP 2.19.0. Task `t7-delete-flow-b-ws`.
Site user's words: "1. Delete the workload cluster `skilltest-flow-b` (Flow CNI, in workspace `skilltest-flow`, on `nkp-mgmt-01`) completely: the cluster and everything it leaves behind on the management cluster, in Prism Central, and on the operator host. Tell us what stayed after the delete before you clean it up. 2. Then delete the workspace `skilltest-flow` itself. We want it deleted the way the NKP documentation says, through the NKP web UI. You do the clicks with your browser tool; take screenshots before, of the confirm dialog, and after, as proof. Then check that the workspace and its namespace are really gone. If something keeps them, tell us what and stop; do not force it. Keep `nkp-mgmt-01`, the site file, and the Flow CNI images in Harbor. I am offline tonight: I approve your plans, go on without waiting for my yes, but write each plan in your log before you run it. Stop only for something outside this request."

Skills used, in order: router `skills/nkp/SKILL.md` → `nkp-cluster-lifecycle` `references/delete.md` (D1, D2, D3, D5, D5.1–D5.4) → `nkp-flow-cni` ("What changes on a Flow CNI cluster", delete item, N-36) → `nkp-identity-security` `references/rbac.md` R5 ("Delete a workspace") → `nkp-install` "Give the user the UI access" (`nkp get dashboard`) → `ntnx-skills` `nutanix-nkp` RECIPES "Leftover audit for a cluster".

Earlier notes on this site: `t1-preflight.md`, `t2-mgmt.md`, `t3-flow-a.md`, `t5-delete-flow-a.md`, `t6-flow-b.md`.

Hard rules applied: `timeout` + keepalive flags on every ssh; `--request-timeout=30s` on every kubectl read; `sleep` as its own call (≤120 s); the delete runs in tmux with a log; no secret printed; no finalizer removed; no skill file edited; nothing committed.

## Block 01 — `01-preflight.sh` (D1 + D2)

READ-ONLY. All six variables set. Findings:

```
nkpclusters -A: kommander/nkp-mgmt-01 Reconciled (158m)
                skilltest-flow-dw97w/skilltest-flow-b v2.19.0 v1.36.2 Reconciled (21m)
D1: MGMT <none> -> workload cluster -> D2
workspaces: default-workspace, kommander-workspace (-> kommander), skilltest-flow -> skilltest-flow-dw97w
nodes 7 Ready (3 control-plane + 4 workers md-0)
pvcs 6 Bound, all nutanix-volume: flow-cni-system/flow-cni-nats-js-flow-cni-nats-{0,1,2} (1Gi),
      skilltest-flow-dw97w/db-prometheus-kube-prometheus-stack-prometheus-0 (100Gi),
      kube-prometheus-stack-grafana (10Gi), opencost-pvc (10Gi)
pvs 6, HANDLE NutanixVolumes-<uuid> for each (kept in block 02 as extIds)
LB services: 1 -> skilltest-flow-dw97w/kommander-traefik EXTERNAL-IP <net>.71
child clusters: `error: the server doesn't have a resource type "nkpclusters"` -> pass case
HCPs in the workspace ns: 9, all Ready True, including the CAREN-made flow-cni-<uid> (path B)
Secrets/cm with the cluster name in the namespace: 24 (the 5 pc-credentials*, image-registry-mirror-credentials,
      nkp-oci-proxy-ca, static-credential-provider-response, ca/etcd/sa/proxy/kubeconfig/encryption-config,
      7 per-machine, oci-cert, oci-creds) + 3 ConfigMaps
operator host files: 8 (nkp-skilltest-flow-b-create.sh, nkp-skilltest-flow-b-delete.log,
      nkp-skilltest-flow-b-nswatch.log, nkp-skilltest-flow-b-nswatch.sh, nkp-skilltest-flow-b.env,
      skilltest-flow-b-dryrun.yaml, skilltest-flow-b-dryrun.yaml.orig, skilltest-flow-b.conf)
```

D2 safety gate: no child NKPCluster (pass case), no PVC that the user wants to keep (the user asked for a complete delete), and the user named this exact cluster. Pass.

## Block 02 — `02-pc-audit.py` (D5.2 step 1 + `nutanix-nkp` "Leftover audit")

READ-ONLY, runs on this laptop with the `ntnx` client. Findings:

```
VMs in PC: 17, 7 with the `skilltest-flow-b` prefix, all powerState ON
volume groups in PC: 40, 9 with `skilltest-flow` in the description, in two groups:
   6 live  (K8sClusterID adc70254-…, vm-attachments 1): pvc-02758de2… 8263956e-…, pvc-ca8d3166… 7b059105-…,
           pvc-9590fba4… 29ab864d-…, pvc-805675eb… 2f303155-…, pvc-190fc462… 94bb6eff-…, pvc-2dd5c308… 240704b8-…
   3 ORPHANS (K8sClusterID cd478812-…, vm-attachments 0): f53ea499-…, 7c89558e-…, 86a88e6d-…
           -> the two earlier flow-b attempts that `t6-flow-b` deleted left their Flow CNI NATS volume groups.
              They are leftovers of `skilltest-flow-b`, so they are in this task's scope.
VPCs: 1 (<lab-vpc> — a lab object, not NKP), nothing named after the cluster
floating IPs: 48, 0 with the cluster name; IP reservations: 0
categories: 58 in PC, 1 with the cluster name: KubernetesClusterName=skilltest-flow-b
     (no KubernetesClusterUUID this time, unlike `t5-delete-flow-a` where both existed)
```

Note for the skills: the PC description of a workload-cluster volume group is
`…, CSI StorageClass nutanix-volume for skilltest-flow-b, PVC:<pvc>, NS:<ns>, POD:<pod>, SA:<sa>`. My print cut it at 160 characters, which made the tail read `for skilltest-flow`; block 10a prints the full string, and the `nutanix-nkp` filter `for <cluster>,` is right as written.

## Block 03 — `03-ownerrefs.sh` (what should go by itself)

READ-ONLY:

```
9 HCPs: every one has ownerReference kind=Cluster name=skilltest-flow-b  -> GC removes them with the CAPI Cluster
9 HRPs: all READY True, owner HelmChartProxy
objects with the cluster name in the management cluster (cm/deploy/svc/ds, all ns): only the 3 ConfigMaps
      of the workspace namespace (kube-oidc-proxy-skilltest-flow-b, traefik-forward-auth-kommander-skilltest-flow-b,
      skilltest-flow-b-flow-values)  <- the first 2 are the `t5` L-01 leftover type, the third is mine (path B)
the resolver DS kube-system/registry-hosts-fix: 7/7 (goes with the cluster)
```

## Plan — delete `skilltest-flow-b` (written before the block runs)

1. Block 04 (`04-delete.sh`, CHANGES): `nkp delete cluster --cluster-name skilltest-flow-b --namespace skilltest-flow-dw97w --kubeconfig "$MGMT_KUBECONFIG" --timeout 30m` in tmux session `nkp-skilltest-flow-b-delete-t7`, log `~/nkp-skilltest-flow-b-delete-t7.log`. Target: workload cluster `skilltest-flow-b` on management cluster `nkp-mgmt-01`. Result: the 7 VMs, their disks and all pods go; the CP VIP and the LB IP stop answering.
2. Block 05 (READ-ONLY): the D3 check blocks + `ping`/`curl` of `CP_VIP` and the first LB IP.
3. Block 06 (READ-ONLY): what stayed — management cluster, Prism Central (audit again), operator host. **Report it to the user before any cleanup.**
4. Then the cleanup plan (written after the report): the 3 ConfigMaps, the 2 mirror Secrets, the 9 volume groups (6 live + 3 orphaned), the operator-host files. Keep `nkp-mgmt-01`, the workspace and its namespace, `~/nkp-site.env`, `~/nkp-nkp-mgmt-01.env`, `~/nkp-mgmt-01.conf`, the site mirror, the VM image, the older lab leftovers.

Then the second job (the workspace delete through the UI) gets its own plan, written before the clicks.

## Block 04 — `04-delete.sh` (D3)

```
17:03:40 tmux session created
17:03:41 INF  • Deleting cluster resources for Cluster skilltest-flow-dw97w/skilltest-flow-b...
          ✓ Deleting cluster resources for Cluster skilltest-flow-dw97w/skilltest-flow-b
17:03:41 INF  • Waiting for cluster to be fully deleted...
17:05:42        ✓ Waiting for cluster to be fully deleted
17:05:42 INF Deleted skilltest-flow-dw97w/skilltest-flow-b cluster     RC=0
```

**2 min 1 s** for 7 nodes with 6 PVCs (a path A cluster of the same shape in `t5-delete-flow-a` took 2 min 4 s). No "Deleting Services with type LoadBalancer", no "Deleting ClusterResourceSets" lines, as in D3. The D3 note says 28–57 s; the real time is about twice that, all of it inside "Waiting for cluster to be fully deleted".

## Block 05 — `05-delete-log.sh`

The log above (filtered for password|token|secret; nothing was filtered).

## Block 06 — `06-after.sh` (D3 check blocks + what stayed)

```
D3 check: "No resources found in skilltest-flow-dw97w namespace." (nkpclusters,clusters.x-k8s.io,machines with the label)
          nkpcluster skilltest-flow-b -> NotFound
CP VIP: no answer, cp_vip_https=000 ; LB first IP <net>.71: lb_first_ip=000
workspace ns HCPs:    "No resources found"   <- all 9 went, including the path B flow-cni-<uid>
workspace ns HRPs:    "No resources found"   <- all 9 went
workspace ns cm,secret with the name: kube-oidc-proxy-skilltest-flow-b,
          traefik-forward-auth-kommander-skilltest-flow-b,
          secret/skilltest-flow-b-oci-cert, secret/skilltest-flow-b-oci-creds   <- STAY (4 objects)
all-ns cm,deploy,svc,ds with the name: the same 2 ConfigMaps and nothing else
kept as told: nkp-mgmt-01 Reconciled, workspaces (default, kommander, skilltest-flow), ns skilltest-flow-dw97w Active
operator host files: 9 (the 8 of block 01 + nkp-skilltest-flow-b-delete-t7.log)
```

## Block 07 — `07-flow-values.sh` (why the path B ConfigMap is not in the list)

```
configmaps "skilltest-flow-b-flow-values" not found        <- it went WITH the delete, by itself
kube-oidc-proxy-skilltest-flow-b              owner: []  labels: {}  keys: ["values.yaml"]
traefik-forward-auth-kommander-skilltest-flow-b  owner: []  labels: {}  keys: ["values.yaml"]
kommanderclusters/appdeployments/clusterapps with the name: none
nkpclusters,clusters,machines,machinedeployments,kommanderclusters,HCPs,HRPs in the namespace: "No resources found"
```

So the `addons.cni.values.sourceRef` ConfigMap that path B needs is removed by the cluster delete (the 4 objects D5 does not list do not include it). The 2 ConfigMaps of the workspace apps stay, exactly as `t5-delete-flow-a` L-01 found; they hold one `values.yaml` key each and no Secret.

## Block 08 — `08-pc-after.py` (Prism Central after the delete)

```
VMs: 10 in PC (was 17), 0 with the cluster prefix                -> the 7 node VMs are gone
volume groups: 40 (unchanged), 9 of `skilltest-flow-b`, all vm-attachments 0
VPC: 1 (<lab-vpc>, not this cluster); floating IPs: 0 for the cluster; IP reservations: 0
categories: 57 in PC (was 58); KubernetesClusterName=skilltest-flow-b is GONE (PC dropped it with the VMs)
```

# What stayed after the delete (the report the user asked for, written before any cleanup)

**Management cluster `nkp-mgmt-01`, namespace `skilltest-flow-dw97w` — 4 objects:**

| # | Object | In the skill? |
|---|---|---|
| 1 | `configmap/kube-oidc-proxy-skilltest-flow-b` | **no** — not in D5 (the `t5` L-01 type) |
| 2 | `configmap/traefik-forward-auth-kommander-skilltest-flow-b` | **no** — not in D5 (the `t5` L-01 type) |
| 3 | `secret/skilltest-flow-b-oci-cert` | yes, D5.1 |
| 4 | `secret/skilltest-flow-b-oci-creds` | yes, D5.1 |

**Prism Central — 9 volume groups, all with `vm-attachments: 0`:**

| Group | extId | PVC | K8sClusterID | Size |
|---|---|---|---|---|
| pvc-02758de2… | `8263956e-9a2a-4c46-496c-f3b11aaf3b34` | flow-cni-system/flow-cni-nats-js-flow-cni-nats-0 | adc70254-… (this cluster) | 1 GiB |
| pvc-ca8d3166… | `7b059105-9c47-43aa-5896-3a3dc369298d` | flow-cni-system/…-nats-1 | adc70254-… | 1 GiB |
| pvc-9590fba4… | `29ab864d-6869-4c06-61ae-1b80aa0f8370` | flow-cni-system/…-nats-2 | adc70254-… | 1 GiB |
| pvc-805675eb… | `2f303155-4239-4833-406c-468cc07f43df` | skilltest-flow-dw97w/db-prometheus-…-0 | adc70254-… | 100 GiB |
| pvc-190fc462… | `94bb6eff-20fe-4bd7-4016-962400ab2c99` | skilltest-flow-dw97w/kube-prometheus-stack-grafana | adc70254-… | 10 GiB |
| pvc-2dd5c308… | `240704b8-89c1-4b14-6b42-9d994e1717d2` | skilltest-flow-dw97w/opencost-pvc | adc70254-… | 10 GiB |
| pvc-a3bc8171… | `f53ea499-bf69-4f23-7b0c-d774ca293b69` | (none — **orphan**) | cd478812-… (an earlier flow-b attempt) | 1 GiB |
| pvc-192b16d6… | `7c89558e-6f39-49d7-718e-f5cf8e8eb119` | (none — **orphan**) | cd478812-… | 1 GiB |
| pvc-dc0059d7… | `86a88e6d-e01b-45d9-4ee0-2f663ca7b0ad` | (none — **orphan**) | cd478812-… | 1 GiB |

The last three are the Flow CNI NATS volume groups of the two earlier `skilltest-flow-b` attempts that `t6-flow-b` deleted (their `K8sClusterID` is the older cluster, their PVCs are gone, nothing references them). The delete leaves them and nothing in the skill would ever name them, because their PVC list belongs to a cluster that no longer exists.

No VPC, no floating IP, no IP reservation, no category, no image: **nothing else stays in Prism Central.**

**Operator host (all in `$HOME` = `/home/ubuntu`) — 9 files:**

```
nkp-skilltest-flow-b-create.sh   1109   nkp-skilltest-flow-b-nswatch.sh   859   skilltest-flow-b-dryrun.yaml       11418
nkp-skilltest-flow-b-delete.log   391   nkp-skilltest-flow-b-nswatch.log  139   skilltest-flow-b-dryrun.yaml.orig  10924
nkp-skilltest-flow-b-delete-t7.log 391  nkp-skilltest-flow-b.env          249   skilltest-flow-b.conf               5602
```

D5.4 names `-create.sh`, `-delete.log`, the dry-run `.yaml`, the kubeconfig and the env file (5 of the 9). The name-grep fallback finds the other 4: `-nswatch.sh`, `-nswatch.log` (the path B namespace watcher of `t6-flow-b`), `-dryrun.yaml.orig` and `-delete-t7.log`.

**Gone, as the skills say:** the NKPCluster, the CAPI Cluster, all 7 Machines and 4 MachineDeployments, the 7 node VMs and their disks, the 22 Secrets of the cluster (including all 5 `-pc-credentials*`, `-image-registry-mirror-credentials`, `-nkp-oci-proxy-ca`, `-static-credential-provider-response`, the kubeconfig and the 7 per-machine Secrets), the 9 HelmChartProxies (the CAREN Flow CNI one included) and the 9 HelmReleaseProxies, the LoadBalancer service (`<net>.71`), the `kube-system/registry-hosts-fix` DaemonSet, and the `skilltest-flow-b-flow-values` ConfigMap of path B. The CP VIP `<net>.70` and the LB IP `<net>.71` answer nothing.

## Cleanup plan (approved standing order; written before the run)

1. Block 09 (`09-mgmt-cleanup.sh`, CHANGES, management cluster): in `skilltest-flow-dw97w`, delete the 2 ConfigMaps `kube-oidc-proxy-skilltest-flow-b` and `traefik-forward-auth-kommander-skilltest-flow-b`, and the 2 Secrets `skilltest-flow-b-oci-cert` / `-oci-creds` (D5.1). Nothing else, no workspace-level object.
2. Block 10 (`10-vg-delete.py`, CHANGES, Prism Central): delete the 9 volume groups by extId, after re-proving for each one that the description names `skilltest-flow` and `vm-attachments` is 0. The PVC data goes. No other PC object is touched.
3. Block 11 (`11-host-files.sh`, CHANGES, operator host): remove the 9 files; the env file goes last (`;`, not `&&`). `MGMT_KUBECONFIG` / `~/nkp-mgmt-01.conf` is not among them.
4. Block 12 + 13 (READ-ONLY): prove the end state on all three sides (management cluster, Prism Central, operator host), plus the mirror's 4 Flow CNI repositories (read-only `tags/list`) which must stay.
5. Never touched: `nkp-mgmt-01`, the workspace `skilltest-flow` and its namespace (job 2 does that through the UI), `~/nkp-site.env`, `~/nkp-nkp-mgmt-01.env`, `~/nkp-mgmt-01.conf`, the site mirror, the VM image, `<lab-vpc>`, the older lab leftovers.

## Block 09 — `09-mgmt-cleanup.sh` (the 4 objects of the management cluster)

```
configmap "kube-oidc-proxy-skilltest-flow-b" deleted from skilltest-flow-dw97w namespace
configmap "traefik-forward-auth-kommander-skilltest-flow-b" deleted from skilltest-flow-dw97w namespace
secret "skilltest-flow-b-oci-cert" deleted from skilltest-flow-dw97w namespace
secret "skilltest-flow-b-oci-creds" deleted from skilltest-flow-dw97w namespace
after: no object with the cluster name
```

## Block 10 — `10a-vg-desc.py`, `10-vg-delete.py` (D5.2, the 9 volume groups)

`10a` printed the **full** description of the 9 groups, which corrected my block 02 note: the description does carry `for skilltest-flow-b,` (the block 02 print cut it at 160 characters, and the fragment read `for skilltest-flow`). The `nutanix-nkp` filter is right as written. The 3 orphans have `K8sClusterID:cd478812-…`, the 6 live ones `adc70254-…`.

```
volume groups in PC before: 40
target pvc-02758de2… desc names the cluster: True | attachments: 0 | hidden: False -> deleted, get 404
target pvc-ca8d3166… … -> deleted, get 404
target pvc-9590fba4… … -> deleted, get 404
target pvc-805675eb… … -> deleted, get 404
target pvc-190fc462… … -> deleted, get 404
target pvc-2dd5c308… … -> deleted, get 404
target pvc-a3bc8171… (orphan) -> deleted, get 404
target pvc-192b16d6… (orphan) -> deleted, get 404
target pvc-dc0059d7… (orphan) -> deleted, get 404
volume groups in PC after: 31
```

Every target was re-proved before the delete (`for skilltest-flow-b,` in the description, `vm-attachments: 0`, `isHidden: False`). 31 is the count that `t5-delete-flow-a` left, so nothing of either flow cluster is left.

## Block 11 — `11-host-files.sh` (D5.4 + the name-grep fallback, 9 files)

```
removed: nkp-skilltest-flow-b-create.sh, nkp-skilltest-flow-b-delete.log, nkp-skilltest-flow-b-delete-t7.log,
         nkp-skilltest-flow-b-nswatch.sh, nkp-skilltest-flow-b-nswatch.log, skilltest-flow-b-dryrun.yaml,
         skilltest-flow-b-dryrun.yaml.orig, skilltest-flow-b.conf, nkp-skilltest-flow-b.env (last)
after: no file with the cluster name
kept: nkp-site.env (1045 B, 15:17), nkp-nkp-mgmt-01.env (228 B), nkp-mgmt-01.conf (5562 B)
```

## Block 12 + 13 — `12-final.sh`, `13-pc-final.py` (the end state of job 1)

```
nkpclusters: kommander/nkp-mgmt-01 v2.19.0 v1.36.2 Reconciled (165m) ; mgmt nodes Ready: 7
workspaces: default-workspace, kommander-workspace, skilltest-flow -> skilltest-flow-dw97w (Active)
skilltest-flow-dw97w objects left: the 2 workspace-level cert-federation Deployments/pods
     (karma-traefik-certs-…, prometheus-traefik-certs-…, 145m — workspace level, not the cluster's)
all-ns grep for `skilltest-flow-b` on the management cluster: no line
Prism Central: 10 VMs (0 with the prefix), 31 volume groups (0 of the cluster), 1 VPC (<lab-vpc>),
     0 floating IPs, 0 IP reservations, 0 categories, 57 categories in PC
mirror (read-only token + tags/list): nutanix/nutanix/flow-cni 200, nutanix/nutanix/flow-container-security 200,
     nutanix/nutanix/flow-ovn-kubernetes 200, nutanix/nutanix-flow-cni (chart) 200
```

**Job 1 is done.** `skilltest-flow-b` is deleted on all three sides.

# Job 2 — delete the workspace `skilltest-flow` through the NKP web UI

The skill text (`nkp-identity-security` `references/rbac.md` R5, "Delete a workspace") gives three things: the precondition ("no cluster in the workspace", "you cannot delete `kommander-workspace`"), the click path ("Global → Workspaces → the three-dot button of the workspace → Delete → confirm in the Delete Workspace dialog" [pdf p.318-319]), and the check blocks. It says "the user does this"; the site user asked me to do the clicks with the browser tool.

Baseline (block 12 + the checks in block 14): workspace `skilltest-flow` -> namespace `skilltest-flow-dw97w` `Active`; no NKPCluster and no KommanderCluster in that namespace (`No resources found`); the only objects in the namespace are the 2 workspace-level cert-federation Deployments.

UI access: `nkp get dashboard` read on the bastion (rule 1 mark USER-TERMINAL, but the site user told me to do the clicks; the password was read on the bastion only and is **not** written in this log, in a block file, or in a screenshot). URL `https://<mgmt-vip>/dkp/kommander/dashboard`, user `<ui-admin-user>`. The UI answers from this laptop (`302` on the dashboard path).

## Plan — job 2 (written before the clicks)

1. Block 14 (`14-ws-before.sh`, READ-ONLY): the baseline again, with the finalizers and the namespace conditions, so the "after" comparison has a recorded start.
2. Browser, screenshots `screens/t7-01-workspaces-before.png` … `t7-05-…`:
   - open the UI, log in (password typed, never logged, never shown on a screenshot);
   - Global → Workspaces; screenshot **before** (`t7-01-workspaces-before.png`);
   - the three-dot button of `skilltest-flow` → Delete; screenshot of the **confirm dialog** (`t7-02-delete-dialog.png`);
   - confirm; screenshot **after** the delete (`t7-03-workspaces-after.png`);
   - if the UI shows the deletion progress or a workspace list without the row, screenshot that too.
3. Block 15 (`15-ws-after.sh`, READ-ONLY): `get workspace skilltest-flow`, `get ns skilltest-flow-dw97w`, the namespace `status.conditions`, and `get workspaces`. Done when both give `NotFound`.
4. If the namespace is `Terminating`: record the `NamespaceContentRemaining` / `NamespaceFinalizersRemaining` messages, show them, and **stop** (no finalizer removal, as the user said "do not force it").
5. Nothing else is touched: `nkp-mgmt-01`, `kommander-workspace` (holds the management cluster), `default-workspace`, `~/nkp-site.env`, the mirror.

## Block 14 — `14-ws-before.sh` (the recorded baseline before the clicks)

```
workspaces: default-workspace, kommander-workspace, skilltest-flow -> skilltest-flow-dw97w (146m)
workspace skilltest-flow: deletionTimestamp= (none) finalizers=["kommander.mesosphere.io/workspacekustomization",
     "workspaces.kommander.mesosphere.io/workspace"]
clusters in the namespace: No resources found (nkpclusters, kommanderclusters)
namespace skilltest-flow-dw97w: Active
objects: 27 `workspacerole.workspaces.kommander.mesosphere.io/workspace-*` + 2 Deployments (the 2
     cert-federation ones), configmaps and secrets of the workspace itself
```

## Job 2 — the clicks (browser on this laptop) and the screenshots

The UI login is the Dex local login page (`https://<mgmt-vip>/dex/auth/local/login`), reached from the dashboard URL. Dark site: the certificate has no SAN, so the browser session was started with `--ignore-certificate-errors`. The admin password was read on the bastion only (`nkp get dashboard`, rule 1 USER-TERMINAL — the site user asked me to do the clicks), typed into the login form, and is not in this log, in a block file, or on any screenshot.

Click path, exactly the R5 path: **Global → Workspaces → the three-dot button of the `skilltest flow` row → Delete → the Delete Workspace dialog**.

| step | screenshot |
|---|---|
| Workspaces page, before (Viewing 3 Workspaces; row `skilltest flow`, namespace `skilltest-flow-dw97w`, 0 clusters) | `screens/t7-01-workspaces-before.png` |
| the same page scrolled sideways, so the row's three-dot button is in view | `screens/t7-01b-workspaces-row-menu.png` |
| the row menu open: `Edit` / `Delete` | `screens/t7-02-row-menu-delete.png` |
| **the confirm dialog**: "Delete Workspace — This action CANNOT be undone. This will permanently delete skilltest flow." + an empty "Type \"skilltest flow\" to confirm" box + Cancel / Delete Workspace (disabled) | `screens/t7-03-delete-workspace-dialog.png` |
| the dialog with the display name typed, Delete Workspace enabled | `screens/t7-04-dialog-typed-confirmation.png` |
| the page right after the delete: "Viewing 2 Workspaces" | `screens/t7-05-workspaces-after.png` |
| the page reloaded: still 2 workspaces | `screens/t7-06-workspaces-after-reload.png` |

Two things the skill does not say and the agent needs:
- the three-dot button of the row is **outside the default viewport** (it is the last column); the table must be scrolled sideways before the button can be clicked.
- the dialog is not confirmed by a button alone: **you must type the display name** (`skilltest flow`, with the space — not the workspace name `skilltest-flow`) and then the `Delete Workspace` button becomes enabled.

No screenshot shows a password, a token or a key (checked: the only credentials in the UI are the user chip `<ui-admin-user>`).

## Block 15 — `15-ws-after.sh` (the check the skill gives, run twice)

First read, 7 s after the click:

```
17:11:33 workspaces: skilltest-flow still listed
         workspace skilltest-flow deletionTimestamp=2026-11-04T17:11:26Z finalizers=["workspaces.kommander.mesosphere.io/workspace"]
              (it had 2 finalizers before the delete: the workspacekustomization one is already gone)
         namespace skilltest-flow-dw97w: Terminating
              NamespaceDeletionDiscoveryFailure=False / GroupVersionParsingFailure=False /
              ContentFailure=False / ContentRemaining=False / FinalizersRemaining=False
         namespaces in Terminating: skilltest-flow-dw97w
         nkp-mgmt-01 Reconciled, 7 nodes Ready
```

Second read, 75 s after the click:

```
17:12:41 workspaces: default-workspace, kommander-workspace only
         workspace skilltest-flow -> NotFound
         namespace skilltest-flow-dw97w -> NotFound
         namespaces in Terminating: "No resources found"
         nkp-mgmt-01 Reconciled, 7 nodes Ready
```

**Done:** the workspace and its namespace are gone, ~75 s after the confirm click. Nothing kept them: no finalizer removal, no forced delete, no blocking object.

## Block 16 — `16-leftover-scan.sh` (the completeness check)

```
namespaces with the name: none
workspaces: default-workspace, kommander-workspace
clusterroles/clusterrolebindings with the name: none
all/cm/secrets/workspaces/appdeployments/projects in every namespace with the name: none
kubefed federatednamespaces/federatedroles/federatedrolebindings with the name: none
nkp-mgmt-01: Reconciled
```

So the UI delete of an empty workspace leaves **nothing** behind on the management cluster — in contrast with lab test 1, where `kubectl delete workspace` on a workspace with clusters left 27 `workspaceroles`, 7 kubefed objects and 2 helm proxies with finalizers.

## Learnings

### L-01 `[nkp-skill nkp-identity-security/references/rbac.md R5, "Delete a workspace"]` — the UI path needs 3 more lines before an agent can follow it

R5 says only: "the user does this: Global → Workspaces → the three-dot button of the workspace → Delete → confirm in the Delete Workspace dialog." Measured on 2.19.0, an agent that does the clicks (the site user asked for that) hits three things the skill does not say:

1. the three-dot button is the **last column of the row and sits outside the default viewport** (1280 px wide window); scroll the table sideways first;
2. the dialog is "Delete Workspace — This action CANNOT be undone. This will permanently delete <display name>." and it has **"Type \"<display name>\" to confirm"**: the `Delete Workspace` button stays disabled until the **display name** is typed; the display name is not the workspace name (`skilltest flow` against `skilltest-flow`);
3. the delete is asynchronous in the UI but short: `deletionTimestamp` immediately, workspace and namespace `NotFound` **~75 s** later.

Proposed text after the "After yes, the user does this" sentence:

> The click path, exactly: **Global → Workspaces → the three-dot button of the row (the last column; scroll the table sideways to reach it) → Edit / Delete → Delete.** The `Delete Workspace` dialog says "This action CANNOT be undone. This will permanently delete <display name>." and asks you to **type the display name** (the DISPLAY NAME column, for example `skilltest flow`, not the NAME column `skilltest-flow`); the Delete button is disabled until it matches. Measured 2.19.0: the workspace and its namespace are `NotFound` about **75 s** after the click, and an empty workspace leaves nothing behind (`workspaces`, `clusterroles`, `clusterrolebindings`, kubefed objects, appdeployments: no object with the name).

### L-02 `[fact]` — P-55, answered for the UI path with an empty workspace

The UI delete of `skilltest-flow` (0 clusters, 0 projects) finished by itself in ~75 s. During the delete the namespace was `Terminating` with all four conditions `False`, and the workspace's finalizer list went from 2 (`kommander.mesosphere.io/workspacekustomization`, `workspaces.kommander.mesosphere.io/workspace`) to 1 without any action of mine. So the "namespace stays `Terminating`, show the conditions and stop" branch was **not** needed. Lab test 1's leftovers (27 `workspaceroles`, 7 kubefed objects, 2 helm proxies) came from a workspace that still had clusters — the skill's precondition ("no clusters in the workspace") is the thing that makes the UI delete clean.

### L-03 `[fact]` — a workload cluster deleted more than once leaves one volume-group generation per attempt, and only the description finds them

`t6-flow-b` created and deleted `skilltest-flow-b` twice before the final create. After this delete there were **9** volume groups: 6 with the live cluster's `K8sClusterID` and 3 with an older one, whose PVC names (`flow-cni-nats-js-flow-cni-nats-0/1/2`) exist only in the description of the group. `kubectl get pv` can never list them, because their cluster is gone. Rule for D5.2: run the `nutanix-nkp` "Leftover audit" **after** the delete and match on the description (`for <cluster>,`), never on the PV list alone; when the cluster was rebuilt, expect more groups than the last PV list.

### L-04 `[nkp-skill nkp-cluster-lifecycle/references/delete.md D5.4]` — the file list, third report

The names this run added to the list of "found only by the name grep": `nkp-<cluster>-nswatch.sh`, `nkp-<cluster>-nswatch.log` (any helper script and its log), `<cluster>-dryrun.yaml.orig`, and the second delete log. And the rule "Remove such a file only when the user names it" cannot be followed when the user says "everything it leaves behind": the user cannot know these names. Proposed: "Remove a file that the name grep finds when the full cluster name is in its name and it is this cluster's (show it in the plan)."

### L-05 `[nkp-skill nkp-flow-cni/SKILL.md, "What changes on a Flow CNI cluster", delete item]` — path B leaves no Flow object at all

For a **path B** cluster (`addons.cni.provider: Flow`), the CAREN-made `helmchartproxy flow-cni-<uid>` has `ownerReferences: kind=Cluster, name=<cluster>`, so it goes with the CAPI Cluster: after the delete there was **no** HCP, **no** HRP and **no** Flow left over (all 9 HCPs, all 9 HRPs "No resources found"). The "the user HelmChartProxy of Flow CNI stays" line is true only for **path A** (the HCP the operator applies by hand). Also: the `addons.cni.values.sourceRef` ConfigMap of path B (`<cluster>-flow-values`) is removed by the delete by itself, while the per-cluster ConfigMaps of the workspace apps (`kube-oidc-proxy-<cluster>`, `traefik-forward-auth-kommander-<cluster>`) stay. Proposed addition: "Path B: nothing of Flow CNI stays (CAREN owns the HCP and the HRP, and it removes them with the cluster). Path A: the user HelmChartProxy stays (N-36)."

### L-06 `[nkp-skill nkp-install/SKILL.md, "Give the user the UI access"]` — how to reach the UI from outside, for an agent that must click

`nkp get dashboard` prints `Username:`, the password and `URL: https://<vip>/dkp/kommander/dashboard`. Measured here: the URL redirects to `https://<vip>/dex/auth/local/login`, and the certificate has no SAN, so a browser needs the certificate exception before the login page (native Chrome: `--ignore-certificate-errors`; a user sees "your connection is not private"). One line in the skill saves an agent from concluding that "the UI is unreachable".

### L-07 `[fact]` — timings of this task

- `nkp delete cluster` (7 nodes, 6 PVCs, Flow CNI path B): **2 min 1 s** (`t5`: 2 min 4 s for path A).
- management-cluster object cleanup: 5 deletes, < 1 s.
- Prism Central: 9 volume groups, 9 GET + 9 DELETE, ~10 s.
- UI workspace delete: ~75 s from the confirm click to `NotFound` for both the workspace and the namespace.
- Total task: 17:03:40 (delete started) → 17:12:41 (workspace gone) — under 10 minutes.

## Status

`done`, both jobs.

1. **`skilltest-flow-b` is deleted on all three sides.** Management cluster: no NKPCluster, CAPI Cluster, Machine, HelmChartProxy, HelmReleaseProxy, Secret or ConfigMap with its name in any namespace (the 2 per-cluster ConfigMaps and the 2 mirror Secrets were removed by the cleanup; the path B values ConfigMap went with the cluster). Prism Central: 0 VMs, 0 of its 9 volume groups (6 live + 3 from the two earlier attempts; PVC data gone), 0 floating IPs, 0 IP reservations, 0 categories, no VPC. Operator host: 0 files. `nkp-mgmt-01` (Reconciled, 7 nodes Ready), `~/nkp-site.env` (unchanged), `~/nkp-nkp-mgmt-01.env`, `~/nkp-mgmt-01.conf` and the 4 Flow CNI repositories in the site mirror (all 200) stay.
2. **The workspace `skilltest-flow` is deleted through the NKP web UI** (Global → Workspaces → three-dot → Delete → typed `skilltest flow` in the confirm dialog), with 7 screenshots as proof. `get workspace skilltest-flow` and `get namespace skilltest-flow-dw97w` both give `NotFound`; no namespace is `Terminating`; no cluster-scoped or kubefed object with the name remains. Nothing had to be forced and no finalizer was removed.

`nkp-mgmt-01`, the site file, the management kubeconfig and the Harbor Flow CNI images are untouched. No secret printed, no skill file edited, nothing committed.
