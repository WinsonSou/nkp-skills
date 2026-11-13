# t7-delete-wl-02-vpc — delete workload cluster `skilltest-wl-02` (Flow VPC `<vpc>`) + VPC step 7

Operator host `<bastion>`; Prism Central `<pc>`. Skills followed: `nkp-cluster-lifecycle` `references/delete.md`
D1, D2, D3, D5, and `nkp-vpc` `SKILL.md` step 7. Standing approval from the brief; the user (asleep) gave D2
"yes + name" for `skilltest-wl-02`. Another agent deletes `skilltest-wl-01` in parallel — its objects are never
touched here.

Env file `<bastion>`: `~/nkp-skilltest-wl-02.env` (CLUSTER_NAME=skilltest-wl-02, CP_VIP=<vpc-net>.21,
LB_IP_RANGE=<vpc-net>.22-<vpc-net>.26, WORKSPACE_NS=kommander-default-workspace, SUBNET=<vpc>-sn1,
VPC_NAME=<vpc>, FIP_API=<net>.135, FIP_UI=<net>.136, CLUSTER_KUBECONFIG=~/skilltest-wl-02.conf).
Time base: UTC, 2026-11-04.

## 0. Timing summary

| Phase | UTC | Duration |
|---|---|---|
| D2 reads + P-11 PV list + nkp-vpc step 7 record | 05:55:13 → 05:55:28 | 15 s |
| D3 plan, launcher, tmux start | 05:56:11 → 05:56:13 | 2 s |
| **D3 `nkp delete cluster`** (RC=0) | 05:56:14 → 05:56:42 | **28 s** |
| D3 checks (NKPCluster/machines gone) | 05:58:08 → 05:58:26 | 18 s |
| PC after (VMs, VGs, FIPs) | 05:58:30 | 5 s |
| nkp-vpc step 7: 2 FIPs disassociate + delete | 05:58:38 → 05:58:54 | 16 s |
| VG leftover check + VPC/subnet/route verify | 05:58:59 → 05:59:05 | 6 s |
| D5 list + remove | 05:59:10 → 05:59:40 | 30 s |

Total 05:55:13 → 05:59:40 (4 min 27 s).

## 1. D2 — safety gate, before (READ-ONLY)

Block `/tmp/t7/d2-before.sh`, run 05:55:13 → 05:55:16 UTC. All 9 env names `set:`.

```text
nodes       5 Ready, all overlay IPs .60 .61 .70 .78 .160
ns          14 (cis/metrics-server absent; ntnx-system, kommander-default-workspace, kommander-flux, ...)
pvc -A      (empty)
lb svc      kommander-default-workspace/kommander-traefik <vpc-net>.22 8085,5000,80,443
nkpclusters inside the workload cluster -> error: the server doesn't have a resource type "nkpclusters"  (= none)
pv (P-11)   NAME HANDLE — EMPTY, the cluster has no PV
sc          nutanix-volume (default), csi.nutanix.com, Delete, WaitForFirstConsumer
mgmt view   kommander-default-workspace/skilltest-wl-02  MGMT=<none>  PHASE=Reconciled  CP=1   -> workload cluster
get nkpclusters -A: kommander/nkp-mgmt-01, kommander-default-workspace/skilltest-wl-02, skilltest-ws-7kr7h/skilltest-wl-01
```

Gate result: workload cluster (MGMT `<none>`), the workload cluster manages no other cluster, **no PVC and no
PV** (nothing to lose), one `LoadBalancer` Service. The user named this exact cluster. Proceed.

### nkp-vpc step 7 item 1 — "record before"

Block `/tmp/t7/step7-record.sh`:

```text
cluster=skilltest-wl-02 vpc=<vpc> subnet=<vpc>-sn1 fip_api=<net>.135 fip_ui=<net>.136 vip=<vpc-net>.21 lb=<vpc-net>.22-<vpc-net>.26
node/... 5 (as above)
+ the one LoadBalancer Service of D2: kommander-default-workspace/kommander-traefik -> <vpc-net>.22 (= first LB IP)
```

### Prism Central before (laptop client, ntnx.py, GET only)

```text
VMs, name prefix skilltest-wl-02: 5 (all powerState ON, all one NIC on overlay subnet <vpc>-sn1 056c6a90)
  0fed7e79-1b06-4af2-5501-b755c700a41f skilltest-wl-02-zwc6z-pz28g
  0e732ab5-87ac-47a4-7f73-f028141ced04 skilltest-wl-02-md-0-lgf8m-4dlxl-4594p
  93b3796f-eb4e-486d-781d-9a05a508573f skilltest-wl-02-md-0-lgf8m-4dlxl-95rpn
  699c69e0-5d00-48ef-55c9-c26e78a41614 skilltest-wl-02-md-0-lgf8m-4dlxl-wm2mc
  6aca5a3b-85f9-4cc6-52eb-f8907a6e97ef skilltest-wl-02-md-0-lgf8m-4dlxl-krjm7
  (22 VMs in PC total: 3 platform VMs, 7 nkp-mgmt-01, 7 skilltest-wl-01, 5 skilltest-wl-02)
VMs on the overlay subnet 056c6a90: exactly those 5 (no other VM, no bastion)
Volume groups whose description contains skilltest-wl-02: 0  (35 VGs in PC) — matches "no PVC, no PV"
Floating IPs: 50 total = 48 fip-dummy-name + the 2 of this cluster:
  67b38bb0-d149-4888-8daa-f494de3af8a3  skilltest-wl-02-api  <net>.135 -> <vpc-net>.21  ASSOCIATED_TO_PRIVATE_IP
  d9ed43a7-8fc4-4b77-9bbc-317cb738965e  skilltest-wl-02-ui   <net>.136 -> <vpc-net>.22  ASSOCIATED_TO_PRIVATE_IP
  (both GET by extId first: name and Association checked, association.vpcReference = <vpc>)
VPC <vpc> eddfb515-9a8c-44ec-bbb6-6421a53a057b, vpcType REGULAR, external subnet SECONDARY-IPAM-VPC-EXT
  7238c8d9 (SNAT externalIps <net>.183, .184)
Subnet <vpc>-sn1 056c6a90 OVERLAY <vpc-net>.0/24 gw .1 pool <vpc-net>.50-.249, vpc <vpc>
Route table ae55acb0 (vpc <vpc>): 2 routes, both isActive
  0.0.0.0/0      -> EXTERNAL_SUBNET SECONDARY-IPAM-VPC-EXT (<net>.129)
  <vpc-net>.0/24  -> LOCAL_SUBNET <vpc>-sn1
```

## 2. D3 plan and CHANGES block

Plan (the skill's D2 item list): command `nkp delete cluster --cluster-name skilltest-wl-02 --namespace
kommander-default-workspace --kubeconfig <MGMT_KUBECONFIG> --timeout 30m`; cluster `skilltest-wl-02`; management
cluster `nkp-mgmt-01`. Goes: 5 node VMs + their disks, all pods, the `kommander-traefik` `LoadBalancer` Service
(no PVC data exists). Stays: the VPC, its overlay subnet, the route table, the 2 floating IPs (until nkp-vpc
step 7 deletes them), the PC images, `~/nkp-site.env`. Approval: standing approval of the brief (the user is
asleep and gave D2 "yes + name" for `skilltest-wl-02` in the task text).

Launcher `/tmp/t7/d3-launch.sh`: writes `~/skilltest-wl-02-delete.sh` (sources the cluster env, runs the D3
command, masks `Invalid value: "…"`), then `tmux new-session -d -s wl02del` → `~/skilltest-wl-02-delete.log`,
`echo RC=$?` appended. Started **05:56:13 UTC**. The parallel agent's `wl1del` session was visible in `tmux ls`.

## 3. D3 result — RC=0 in 28 s

The whole log (`cat ~/skilltest-wl-02-delete.log`):

```text
2026-11-04 05:56:14 INF  • Deleting cluster resources for Cluster kommander-default-workspace/skilltest-wl-02...
 ✓ Deleting cluster resources for Cluster kommander-default-workspace/skilltest-wl-02
2026-11-04 05:56:14 INF  • Waiting for cluster to be fully deleted...
 ✓ Waiting for cluster to be fully deleted
2026-11-04 05:56:42 INF Deleted kommander-default-workspace/skilltest-wl-02 cluster
RC=0
```

**05:56:14 → 05:56:42 = 28 s.** `tmux ls` at 05:58:02: `no server running` (the session was gone). No license
error, so the mask did nothing.

## 4. D3 checks (READ-ONLY, block `/tmp/t7/d3-check.sh`, 05:58:08 → 05:58:26)

```text
get nkpclusters,clusters,machines -l cluster.x-k8s.io/cluster-name=skilltest-wl-02
   -> No resources found in kommander-default-workspace namespace.
get nkpcluster skilltest-wl-02
   -> Error from server (NotFound): nkpclusters.clusters.nkp.nutanix.com "skilltest-wl-02" not found
clusters.cluster.x-k8s.io  -> No resources found
machines.cluster.x-k8s.io  -> No resources found
get nkpclusters -A -> kommander/nkp-mgmt-01 (Reconciled, 83m) only
```

**Done-when met.** The NKPCluster did **not** stay in an `Error` state: 82 s after the delete it is `NotFound`, so
the "delete the NKPCluster object / remove the finalizers" CHANGES block of D3 was **not needed** and not run.

The cluster API, UI and VIP stop answering (before the FIP delete): `api-fip 000`, `ui-fip 000`, `vip 000`.

Leftover on the management cluster: **2 Secrets** in the workspace namespace keep the cluster name —
`skilltest-wl-02-oci-cert` (Opaque) and `skilltest-wl-02-oci-creds` (kubernetes.io/dockerconfigjson). The
`-kubeconfig` Secret is gone. Not deleted here (not in the task scope or in `delete.md` D3/D5).

## 5. Prism Central after the delete (READ-ONLY, 05:58:30)

```text
VMs, prefix skilltest-wl-02: 0        (PC total 10 = 3 platform + 7 nkp-mgmt-01; the 7 skilltest-wl-01 VMs
                                       went in the parallel task)
VMs on overlay subnet 056c6a90: 0
VGs whose description contains skilltest-wl-02: 0   (PC total 35, same as before)
FIPs: 50, both of this cluster still there and still ASSOCIATED_TO_PRIVATE_IP:
  67b38bb0-… skilltest-wl-02-api <net>.135 -> <vpc-net>.21
  d9ed43a7-… skilltest-wl-02-ui  <net>.136 -> <vpc-net>.22
```

So `nkp delete cluster` removes the VMs and nothing else in Prism Central (P-11: with no PVC there is no VG to
leave behind, so this run says nothing new about VGs; the FIP leftovers are the new fact).

## 6. nkp-vpc step 7

Step 7 tells the agent: (3) VMs — no VM with the cluster prefix stays; **floating IPs** — disassociate and delete
`FIP_API`, `FIP_UI` and each Service FIP unless another cluster uses them; overlay subnet — delete it only if no
other VM (the bastion, other clusters) uses it; VPC — delete it only if it has no subnet and no VM left and the
user wants it gone; external subnet — keep; `CP_VIP` and `LB_IP_RANGE` free again.

Scope decision (task + user): **keep the VPC `<vpc>`, the overlay subnet `<vpc>-sn1`, the route table
and the external subnet.** Under the skill's own rule the VPC would stay anyway (it still has a subnet), but its
overlay-subnet rule would have deleted `<vpc>-sn1` once it had no VM — the user wants it kept for the next
cluster in this VPC. The 48 `fip-dummy-name` FIPs are lab leftovers, not this cluster's, so they are untouched.

### FIP delete (CHANGES, 05:58:38 → 05:58:54, client on the laptop, recipe `nutanix-networking` RECIPES
"Floating IPs": `GET` → `pop association` → `PUT` → `delete` with the fresh ETag)

```text
GET 67b38bb0-…: name=skilltest-wl-02-api ext=<net>.135 priv=<vpc-net>.21 status=ASSOCIATED_TO_PRIVATE_IP vpc=<vpc> etag=…:0
  after disassociate: status=NOT_ASSOCIATED association=None
  after delete: GET -> 404 NETWORKING-10060 "Floating IP 67b38bb0-… not found"
GET d9ed43a7-…: name=skilltest-wl-02-ui  ext=<net>.136 priv=<vpc-net>.22 status=ASSOCIATED_TO_PRIVATE_IP vpc=<vpc> etag=…:0
  after disassociate: status=NOT_ASSOCIATED association=None
  after delete: GET -> 404 NETWORKING-10060 "Floating IP d9ed43a7-… not found"
fresh list: 48 FIPs, all fip-dummy-name, all NOT_ASSOCIATED, no other non-dummy FIP
```

Both extIds and both names were checked with a `GET` before the first mutation, as the task requires.

## 7. Volume group leftovers (step 5) — none

Block `/tmp/t7/vg-cleanup.py` (GET + `attachedVms` check + ETag DELETE for each `for skilltest-wl-02,` match):

```text
VGs total: 35 ; desc contains "skilltest-wl-02": 0 ; re-list after: 35 / 0
NOTHING TO DELETE (the cluster had no PVC, so the CSI made no volume group)
```

The script's delete path was not exercised; no orphan VG existed.

VPC state after step 7 (unchanged, as scoped):

```text
VPC <vpc> eddfb515-… externalSubnets SECONDARY-IPAM-VPC-EXT 7238c8d9 (externalIps <net>.183,.184)
SUBNET PRIMARY-IPAM 26224f58 VLAN | SECONDARY-IPAM-VPC-EXT 7238c8d9 VLAN | <vpc>-sn1 056c6a90 OVERLAY vpc=<vpc>
ROUTE 91d0aa4e 0.0.0.0/0 active -> EXTERNAL_SUBNET SECONDARY-IPAM-VPC-EXT
ROUTE 221e01cb <vpc-net>.0/24 active -> LOCAL_SUBNET <vpc>-sn1
```

## 8. D5 — operator host files (READ-ONLY list, then CHANGES rm)

D5 list block found 4 files:

```text
1259  ~/nkp-skilltest-wl-02-create.sh
11054 ~/skilltest-wl-02-dryrun.yaml
5595  ~/skilltest-wl-02.conf          (= CLUSTER_KUBECONFIG)
450   ~/nkp-skilltest-wl-02.env
```

`ls -la ~ | grep skilltest-wl-02` found 5 more files that the D5 list does not name (from the create/verify
session): `skilltest-wl-02-create.log` 1098, `skilltest-wl-02-verify.log` 3184, `skilltest-wl-02-dryrun.err` 241,
`skilltest-wl-02-delete.log` 409, `skilltest-wl-02-delete.sh` 275.

CHANGES block: the D5 `rm` block verbatim (RC=0), then `rm -f` of those five exact files. After:

```text
no skilltest-wl-02 file in ~
~/nkp-site.env 820 bytes, 04:52  (kept, never touched)
```

No `nkp-skilltest-wl-02-patch.json`, `-nodepool.sh`, `-nodepool-dryrun.yaml`, `-inventory.yaml`,
`skilltest-wl-02-metallb-conf.yaml` existed (the t5 create did not make them).

## 9. Final state

```text
VMs in PC: 10 — BASTION, PCVM, <ad-vm>, 7 nkp-mgmt-01. No skilltest-wl-02 VM.
FIPs: 48, all fip-dummy-name, all NOT_ASSOCIATED (the 48 that existed before this session + task; baseline kept)
VGs: 35 (unchanged)
VPC <vpc>, overlay subnet <vpc>-sn1, route table ae55acb0, external subnet: untouched, by user scope
management cluster nkp-mgmt-01: Reconciled, untouched apart from the delete command
Leftovers: 2 Secrets on the management cluster (skilltest-wl-02-oci-cert, -oci-creds)
Wall clock: 05:55:13 → 06:00 (~5 min), of which the delete itself is 28 s
```

## Learnings

1. **[nkp-skill nkp-cluster-lifecycle/references/delete.md D3, "Output"] "Output: 'Deleting Services with type
   LoadBalancer', 'Deleting ClusterResourceSets', 'Deleting cluster resources', 'Waiting for the cluster to be
   fully deleted', 'Deleted ... cluster'."** Live on a workload cluster in a VPC, the log has **3 of the 5
   lines**: `Deleting cluster resources for Cluster …` / `Waiting for the cluster to be fully deleted` /
   `Deleted … cluster`. There is no `Deleting Services with type LoadBalancer` line and no
   `Deleting ClusterResourceSets` line, although the cluster had one `LoadBalancer` Service
   (`kommander-traefik` <vpc-net>.22) and did delete it. **Fix:** say which lines a workload cluster prints and
   note that the two missing lines are quiet in this case — otherwise an agent waits for output that never
   comes.

2. **[nkp-skill delete.md D3, "The cluster stays in the UI in an `Error` state after the delete" + the finalizer
   paragraph] Not true here.** 82 s after `nkp delete cluster` returned RC=0, `get nkpcluster skilltest-wl-02`
   was `NotFound`, with `clusters.cluster.x-k8s.io` and `machines.cluster.x-k8s.io` empty. So the extra CHANGES
   block (delete the NKPCluster, then remove the `capicluster-cleanup` / `kommandercluster-cleanup` finalizers)
   must not be run as a matter of course. **Fix:** "Check first — if the command already removed the NKPCluster
   (the normal 2.19.0 workload case), skip the rest of this section."

3. **[nkp-skill delete.md D2, block] `kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get nkpclusters -A` fails on a
   workload cluster: `error: the server doesn't have a resource type "nkpclusters"`.** The gate text says "The
   last command lists an NKPCluster" — an error is not "lists nothing", and an agent can read it as a broken
   cluster. **Fix:** run that one line against the management cluster
   (`--kubeconfig "$MGMT_KUBECONFIG"`), or add "on a workload cluster this command errors (no NKP CRDs) — that
   is the pass case".

4. **[nkp-skill delete.md D5, "Operator host files"] The list does not cover the files the run itself
   creates.** `~/skilltest-wl-02-create.log`, `~/skilltest-wl-02-verify.log`, `~/skilltest-wl-02-dryrun.err` came
   from the create session (skill `nkp-install` N4D/N5 redirect their output), and this task added
   `~/skilltest-wl-02-delete.log` and `~/skilltest-wl-02-delete.sh`. `ls ~ | grep skilltest-wl-02` found 9 files
   where the block lists 4. **Fix:** add those names to the D5 list and `rm` blocks, and keep the sentence "run
   `ls ~ | grep <cluster>` as a last check".

5. **[nkp-skill delete.md D5, "What stays after a delete"] The delete leaves 2 Secrets on the management
   cluster in the workspace namespace: `<cluster>-oci-cert` (Opaque) and `<cluster>-oci-creds`
   (kubernetes.io/dockerconfigjson).** The `-kubeconfig` Secret is removed, these two are not, so nothing in D3,
   D5 or `nkp-vpc` step 7 lists them and they accumulate. **Fix:** add to D5: "Secrets of the cluster:
   `kubectl -n $WORKSPACE_NS get secrets | grep $CLUSTER_NAME` — 2 stay (`-oci-cert`, `-oci-creds`); delete them
   when you want the workspace clean." (They hold registry mirror credentials, so say so.)

6. **[nkp-skill nkp-vpc/SKILL.md step 7 item 3, "the user does these steps in Prism Central"] No API path is
   given, and the floating-IP item needs two calls, not one.** A DELETE of an associated FIP is not the operation
   the PRD wants: live, the working sequence was `GET /networking/v4.4/config/floating-ips/{extId}` (check the
   name) → remove `association` → `PUT` with the ETag (`associationStatus` becomes `NOT_ASSOCIATED`) → `DELETE`
   with the fresh ETag → `GET` returns 404 `NETWORKING-10060`. The skill says only "disassociate and delete".
   **Fix:** add the 3-call recipe (or a pointer to `ntnx-skills` `nutanix-networking` RECIPES "Floating IPs") and
   say "a direct DELETE of an `ASSOCIATED_TO_PRIVATE_IP` FIP is not the operation to use — disassociate first".

7. **[nkp-skill nkp-vpc/SKILL.md step 7, overlay subnet and VPC items] The rules are cluster-scoped but the objects
   are site-scoped, and there is no line that says who decides.** Live: after the delete, `<vpc>-sn1` had 0
   VMs, so "delete it only if no other VM (the bastion, other clusters) uses it" would delete the subnet the user
   keeps for the next cluster in the same VPC. The VPC item is conjunctive ("no subnet **and** no VM"), so it
   survives by luck, not by scope. **Fix:** "Step 7 changes site objects. Ask first whether the VPC, its subnet and
   the route table belong to this cluster only, or to the site. Delete a subnet or a VPC only when the user says
   the site does not need it; a cluster delete by itself never implies it."

8. **[nkp-skill nkp-vpc/SKILL.md step 7 item 1, "record before"] The block records names and IPs but not the
   extIds, and the FIP delete needs the extId.** The evidence in this log came from a `GET …/floating-ips` list
   filtered by name, which works only when the name is unique. **Fix:** record the extId next to each object
   (`floating-ips/<extId>`, subnet, VPC, route table, the LoadBalancer Service IP) — the run log then has what the
   delete needs.

9. **[nkp-skill delete.md D5, "Cluster in a VPC" bullet] It points at `nkp-vpc` step 7 correctly but does not say
   that the FIPs answer `000` between the two steps.** Live: for ~2 min after the delete, `https://<net>.135:6443`
   and `https://<net>.136/` returned `000` while both FIPs were still `ASSOCIATED_TO_PRIVATE_IP` on a private IP
   that no VM held — a NAT FIP to a dead VM, not an error state. Minor; one sentence would stop an agent from
   calling the FIPs broken.

10. **[ntnx-skill nutanix-networking RECIPES "Floating IPs"] The recipe's disassociate + delete snippet worked
    unmodified for both FIPs (verified 2026-11-04): `f.pop('association', None)` → `put(F, f, etag)` →
    `delete(F, get(F)[1])`, `associationStatus` `ASSOCIATED_TO_PRIVATE_IP` → `NOT_ASSOCIATED` → 404, no task
    polling needed.** The comment `# disassociate first` is the load-bearing line and the only one the NKP skills
    would have to borrow.

11. **[fact] A 5-node workload cluster delete in a VPC takes about 30 s, not minutes.** `--timeout 30m` was never
    near: 05:56:14 → 05:56:42, RC=0, 3 log lines, no bootstrap cluster, no pivot (both are `--self-managed` only).
    Compare a create of the same cluster: 12 min 53 s. For the skill: "a workload delete is fast; poll every 30 s,
    not every 5 min".

12. **[fact] P-11, this run: no PVC in the cluster → no PV, and after the delete no volume group.** The D5 P-11
    command returned an empty `NAME HANDLE` list, and both the before and the after list had 35 VGs with 0
    matching `skilltest-wl-02`. So the AHV CSI leaves a VG only when a PVC existed; the step-5 VG cleanup is a
    no-op for a cluster without persistent storage. `nkp-vpc` step 7 and `delete.md` D5 should say the VG part is
    conditional on PVCs, so an agent does not hunt for VGs that cannot exist.

