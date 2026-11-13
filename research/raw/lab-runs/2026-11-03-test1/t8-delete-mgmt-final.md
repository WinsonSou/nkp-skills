# t8-delete-mgmt-final — delete the Ultimate management cluster `nkp-mgmt-01`, clean Prism Central and the bastion

Operator host `<bastion>`; Prism Central `<pc>`. Skills followed: `nkp-cluster-lifecycle` `references/delete.md`
**D1, D4, D5**; PC objects via the ntnx-skills client (`python3 -I`, `ntnx.py` from the laptop). Standing approval
from the brief; the user (asleep) gave D4 "yes + `nkp-mgmt-01`" in the task text. `<old-mgmt-cluster>`, the Harbor
registry, `~/cluster.yaml`, `~/certificates`, the bundle and the PC VM were never touched.

**Status: done.** D4 delete RC=0 in 7 min 04 s. VMs 0, VGs 20 → 0, FIPs 48/0 associated, PRISM-IPAM reserved 0,
VIP/LB IPs dead, bastion clean, no bootstrap container.

Time base: UTC, 2026-11-04.

## 0. Timing summary

| Phase | UTC | Duration |
|---|---|---|
| Before: gate, orphan Secrets, P-11 PV list, PVC list, docker, `ls ~` | 06:07:12 → 06:07:40 | ~30 s |
| Before: PC (VMs, 20 VGs, FIPs, VPC, subnets, reserved IPs) | 06:07:40 → 06:08:10 | ~30 s |
| **D4 `nkp delete cluster --self-managed`** (RC=0) | 06:08:30 → 06:15:34 | **7 min 04 s** |
| After: docker, kubeconfig, `ls ~` | 06:17:15 → 06:17:20 | 5 s |
| After: PC (0 VMs, 20 VGs unattached) + ping/curl | 06:17:15 → 06:17:30 | 15 s |
| Step 4: 20 VG deletes (GET + ETag DELETE) | 06:18:10 → 06:18:50 | 40 s |
| Step 5: D5 timing harvest + `rm` | 06:19:10 → 06:20:00 | 50 s |
| Final PC snapshot | 06:21:00 | 10 s |

Total 06:07:12 → 06:21:00 (about 14 min, of which 7 min is the delete).

## 1. Before (READ-ONLY)

Block `/tmp/t8-delete-mgmt-final/before.sh`, env `~/nkp-nkp-mgmt-01.env`. All 7 names `set:` (CLUSTER_NAME
WORKSPACE_NS CLUSTER_KUBECONFIG MGMT_KUBECONFIG BUNDLE_DIR PC_ENDPOINT SUBNET).

### D1 identity

```text
NAMESPACE   NAME          MGMT   PHASE        CP
kommander   nkp-mgmt-01   true   Reconciled   3
```

`MGMT=true`, namespace `kommander` → management cluster → **D4**. Correct for an Ultimate (licensed) cluster too.

### D4 gate — `get nkpclusters -A`

```text
NAMESPACE   NAME          NKP VERSION   KUBERNETES VERSION   PHASE        AGE
kommander   nkp-mgmt-01   v2.19.0       v1.36.2              Reconciled   92m
```

Only the management cluster → gate passed. Bootstrap image:
`/home/ubuntu/nkp-v2.19.0/konvoy-bootstrap-image-v2.19.0.tar` (3380931584 bytes). Docker up with 9 Harbor
containers, no tmux session, 16 CPU / 29 GB free.

### Orphan Secrets — **not** in `kommander`

The task named `skilltest-wl-02-oci-cert` and `skilltest-wl-02-oci-creds` in namespace
`kommander-default-workspace`. A lookup with `-n "$WORKSPACE_NS"` returns **NotFound** for both, because on the
management cluster `WORKSPACE_NS='kommander'`. They do exist in `kommander-default-workspace`:

```text
NAME                      TYPE
skilltest-wl-02-oci-cert  Opaque
skilltest-wl-02-oci-creds kubernetes.io/dockerconfigjson
```

(7 Secrets in that namespace: those 2 + 2 `kommander-*-tls` + 2 `sh.helm.release.*` + `tls-root-ca`.) They go
away with the management cluster and its namespace, so D4 removed them implicitly. **After the delete the
namespace is gone with the cluster — nothing to clean.**

### P-11 PV list (20 PVs), before

```text
NAME                                       CLAIM    HANDLE
pvc-0868811f-1b64-4683-9938-53625abef96d   <none>   NutanixVolumes-abc1adbc-b90c-45eb-50fa-702d62662621
pvc-23e18a60-ddb9-44c4-8dbb-c4d2fb8e5866   <none>   NutanixVolumes-3f5fc0be-c77d-4087-4c8b-11f3597a7f90
pvc-41a9ddb7-364c-4bb7-bc04-10a55a03da87   <none>   NutanixVolumes-0079e805-088e-4fce-60ef-8d21827e9ba8
pvc-4c6be583-5b86-459b-be7a-3cef90af0325   <none>   NutanixVolumes-a1b2c992-023f-438d-79c2-57638ca04554
pvc-4eb9be25-b772-4625-bad9-e9d6521d8727   <none>   NutanixVolumes-27eb8965-58d5-46f6-49a6-5bf82714287c
pvc-56699046-3210-4df5-92a9-0d27690422f5   <none>   NutanixVolumes-8f034853-f54c-4d92-404e-f5bba270576b
pvc-60f7dbe4-f8a7-4c28-812d-33b667ec63b2   <none>   NutanixVolumes-e8c12652-9c0e-4f1d-76c1-80ba801ee6f8
pvc-646e4ccb-1d68-4fa4-9382-09add56c0c70   <none>   NutanixVolumes-01019852-c7da-4e89-6570-075664129180
pvc-6f15328a-bf29-4d9b-9996-0c711c568a16   <none>   NutanixVolumes-450986c9-cc13-4616-653f-1e0f67e2817f
pvc-77d28a0a-b8e9-4f16-b95e-ca4a25f3bfe2   <none>   NutanixVolumes-7110f511-a579-4b3f-7b47-1fc1a685f47c
pvc-8e69940b-64cd-4b34-9b58-541d21f0b80d   <none>   NutanixVolumes-8c8e84b9-3c31-4cc5-6073-c8d6e6dfb99b
pvc-afbb14e8-cb64-4489-8cd9-c7d4c08c898b   <none>   NutanixVolumes-63ddb698-3f03-4e68-6c3d-ab38526a48c4
pvc-b1a20154-8fe8-4c67-889d-45f8c2bc6426   <none>   NutanixVolumes-63b1f657-341d-40f4-76c6-9fbdcc1f6a1a
pvc-c4ce1dd3-d86d-48df-8d73-e9b886044356   <none>   NutanixVolumes-653c9ffd-bd80-489e-44fa-6a38fa09e8a4
pvc-d371ae4b-68bd-402e-976e-09d7129c20d8   <none>   NutanixVolumes-672397c8-85ba-4978-7acf-a02d2a649b89
pvc-d3a50e75-88c2-453f-89a9-2b8fd0352bb3   <none>   NutanixVolumes-4844b279-a2c6-478e-4d4e-3de5cc97247f
pvc-df703924-56de-43c5-ac41-6ab698faf20c   <none>   NutanixVolumes-6e57c369-bf49-494d-7bcd-04b714c3fa07
pvc-e32fd392-2ad2-4956-ab11-c7d452124931   <none>   NutanixVolumes-9b8e8ff8-4315-4a88-5909-3fc2cc36000a
pvc-f7735bef-e0e4-4bf3-be89-acd46bef0f7f   <none>   NutanixVolumes-262b2e96-9005-4e89-5fd8-c3a18a5b723d
pvc-fe78e635-ee97-422d-afd9-c6a51aa4f4db   <none>   NutanixVolumes-dc379df7-8b39-492c-4d88-180500c9ecfc
```

(The `CLAIM` column is `<none>` because `custom-columns` splits `.spec.claimRef.namespace/.spec.claimRef.name`
on the `/` — see Learnings 1.)

PVCs (20, all `Bound`, StorageClass `nutanix-volume`): `caren-system/helm-charts-pvc` 2Gi,
`git-operator-system/git-operator-admin-volume` 2Gi, `git-operator-system/git-operator-git-volume` 10Gi,
`kommander/centralized-opencost-pvc` 10Gi, `kommander/data-grafana-loki-v3-compactor-0` 10Gi,
`kommander/data-grafana-loki-v3-index-gateway-0` 10Gi, `kommander/data-grafana-loki-v3-ingester-zone-a|b|c-0`
3 × 10Gi, `kommander/db-prometheus-kube-prometheus-stack-prometheus-0` **100Gi**,
`kommander/kube-prometheus-stack-grafana` 10Gi,
`kommander/logging-operator-logging-fluentd-buffer-logging-operator-logging-fluentd-0` 10Gi,
`kommander/opencost-pvc` 10Gi, `kommander/rook-ceph-mon-a|b|c` 3 × 10Gi,
`kommander/rook-ceph-osd-set1-data-0sm6h5|17v2kn|2mssmm|346c6h` 4 × 40Gi. Total **340 Gi**.

One `LoadBalancer` Service: `kommander/kommander-traefik` `<net>.51` (8085, 5000, 80, 443).
7 nodes (3 CP `nkp-mgmt-01-k9sjq-*`, 4 workers `nkp-mgmt-01-md-0-tvx4w-p2jq4-*`), all Ready.

### Prism Central, before

```text
VMs with prefix nkp-mgmt-01: 7   (PC total 10: BASTION, NTNX-<net>-39-PCVM-…, <ad-vm>, + the 7)
  83add9b5 nkp-mgmt-01-k9sjq-7fsfr            ON
  aafe6d56 nkp-mgmt-01-k9sjq-fdpvl            ON
  ce2c2eb7 nkp-mgmt-01-k9sjq-t2q25            ON
  5840909d nkp-mgmt-01-md-0-tvx4w-p2jq4-gjznp ON
  baff46b8 nkp-mgmt-01-md-0-tvx4w-p2jq4-h4g6m ON
  9ac79921 nkp-mgmt-01-md-0-tvx4w-p2jq4-hc7wq ON
  5929d948 nkp-mgmt-01-md-0-tvx4w-p2jq4-xwq8h ON

Volume groups: 31 total ; description contains "for nkp-mgmt-01,": 20  (= the 20 PVs, extId = volumeHandle)
  all 20 have exactly 1 vm-attachment (the node that runs the pod)

Floating IPs: 48, all fip-dummy-name, all NOT_ASSOCIATED
PRIMARY-IPAM (26224f58) reserved-ips: 0
VPC: <vpc> eddfb515 (vpcType REGULAR)
Subnets: PRIMARY-IPAM 26224f58 VLAN | SECONDARY-IPAM-VPC-EXT 7238c8d9 VLAN | <vpc>-sn1 056c6a90 OVERLAY (vpc <vpc>)
Route table: ae55acb0 (vpc <vpc>)
```

The 20 VGs by PVC name: `helm-charts-pvc`, `git-operator-admin-volume`, `git-operator-git-volume`,
`centralized-opencost-pvc`, `opencost-pvc`, `kube-prometheus-stack-grafana`,
`db-prometheus-kube-prometheus-stack-prometheus-0`, `logging-operator-logging-fluentd-buffer-…-0`,
`rook-ceph-mon-a|b|c`, `rook-ceph-osd-set1-data-0sm6h5|17v2kn|2mssmm|346c6h`,
`data-grafana-loki-v3-compactor-0`, `-index-gateway-0`, `-ingester-zone-a|b|c-0`.
The other 11 VGs are the Prism Central VM's own (no `K8sClusterID` in the description) — never touched.

## 2. D4 — plan and CHANGES block

Plan (delete.md D2 items): command `nkp delete cluster --self-managed --cluster-name nkp-mgmt-01 --namespace
kommander --kubeconfig <MGMT_KUBECONFIG> --timeout 60m --bootstrap-cluster-image
<nkp-v2.19.0/konvoy-bootstrap-image-v2.19.0.tar>`; cluster `nkp-mgmt-01`, management (self-managed) cluster.
Goes: 7 node VMs and their disks, all pods, all PVC data (340 Gi), Kommander + every platform app + the NKP UI,
the `kommander-traefik` VIP `<net>.51`, the MetalLB pool `<net>.51–.55`, the 2 orphan Secrets of the deleted
`skilltest-wl-02` workspace. Stays: `~/nkp-site.env`, `~/cluster.yaml`, `~/certificates`, the Harbor registry,
the bundle, the PC images, the VPC `<vpc>` / its subnets / route table, the 48 dummy FIPs.
Approval: standing approval of the brief (the user is asleep; "yes + nkp-mgmt-01" is in the task text).

Launcher `/tmp/t8-delete-mgmt-final/d4-launch.sh` writes `/tmp/nkp-mgmt-01-delete.sh` (masks
`Invalid value: "…"` and `key: …`), then `cd $HOME` and `tmux new-session -d -s mgmtdel` → log
`~/nkp-mgmt-01-delete.log` with `RC=` and `END=` appended. Started **06:08:29Z**.

## 3. D4 result — RC=0 in 7 min 04 s

Whole log (`~/nkp-mgmt-01-delete.log`, 1865 bytes):

```text
2026-11-04 06:08:30 INF  • Loading bootstrap image from archive...
 ✓ Loading bootstrap image from archive
2026-11-04 06:08:42 INF  • Creating a bootstrap cluster...
 ✓ Creating a bootstrap cluster
2026-11-04 06:09:09 INF  • Installing CAPI Stack operators...
 ✓ Installing CAPI Stack operators
2026-11-04 06:10:00 INF  • Creating CAPI components...
 ✓ Creating CAPI components
2026-11-04 06:11:00 INF  • Creating ClusterClass resources...
 ✓ Creating ClusterClass resources
2026-11-04 06:11:00 INF  • Creating NKPCluster resources...
 ✓ Creating NKPCluster resources
2026-11-04 06:11:10 INF  • Creating ClusterClass resources...
 ✓ Creating ClusterClass resources
2026-11-04 06:11:11 INF  • Moving cluster resources...
 ✓ Moving cluster resources
2026-11-04 06:12:38 INF
You can now view resources in the moved cluster by using the --kubeconfig flag with kubectl.
For example: kubectl --kubeconfig="nkp-mgmt-01-bootstrap.conf" get nodes

2026-11-04 06:12:38 INF Waiting for cluster in kommander/nkp-mgmt-01
2026-11-04 06:12:38 INF  • Waiting for cluster infrastructure to be ready...
 ✓ Waiting for cluster infrastructure to be ready
2026-11-04 06:12:38 INF  • Waiting for cluster control-planes to be ready...
 ✓ Waiting for cluster control-planes to be ready
2026-11-04 06:12:38 INF  • Waiting for machines to be ready...
 ✓ Waiting for machines to be ready
2026-11-04 06:12:38 INF  • Deleting cluster resources for Cluster kommander/nkp-mgmt-01...
 ✓ Deleting cluster resources for Cluster kommander/nkp-mgmt-01
2026-11-04 06:12:38 INF  • Waiting for cluster to be fully deleted...
 ✓ Waiting for cluster to be fully deleted
2026-11-04 06:15:33 INF Deleted kommander/nkp-mgmt-01 cluster
2026-11-04 06:15:33 INF  • Deleting bootstrap cluster...
 ✓ Deleting bootstrap cluster
RC=0
END=2026-11-04T06:15:34Z
```

Phases: image load 12 s, bootstrap cluster 27 s, CAPI operators 51 s, CAPI components 60 s, ClusterClass +
NKPCluster 11 s, **pivot 87 s**, delete + wait 2 min 55 s, bootstrap cluster removal ~1 s.

Comparison: the Starter management cluster (`skilltest-mgmt-01`, 3 CP + 4 workers, 3 PVCs) took **5 min 06 s**.
This Ultimate cluster (same node count, 20 PVCs, rook-ceph + Loki + Prometheus) took **7 min 04 s**: +2 min,
almost all of it in the final "delete + wait for full delete" step (50 s → 2 min 55 s, because 20 CSI volumes go
with it). Still 8× inside `--timeout 60m`.

**Operational trap (not a skill bug):** the log stayed **0 bytes for the whole 7 minutes**. The command pipes
through `sed` (masks), so stdout is block-buffered; `tail` shows nothing until the process exits. `tmux
capture-pane` was also empty. Progress is only visible in `docker ps` (`konvoy-capi-bootstrapper-control-plane`
building → gone). Use `stdbuf -oL` before `nkp` when a live log is needed.

## 4. After the delete

### Bastion (READ-ONLY)

```text
docker ps / docker ps -a → 9 Harbor containers only (harbor-jobservice nginx harbor-core harbor-portal redis
                            harbor-db registry registryctl harbor-log). No bootstrap/kind container.
docker ps -a | grep -iE 'bootstrap|kind' → none
~/.kube/... none; kubectl --kubeconfig ~/nkp-mgmt-01.conf get nodes → "connect: no route to host" <net>.50:6443
~/nkp-mgmt-01-bootstrap.conf → No such file or directory
```

No `nkp delete bootstrap` needed. The pivot kubeconfig file printed by the command does not stay.

### Prism Central (READ-ONLY)

```text
VMs in PC: 3 → BASTION, <pc-vm>, <ad-vm>.  prefix nkp-mgmt-01: 0
VGs: 31 total ; "for nkp-mgmt-01,": 20 — THEY STAY, and all 20 now have 0 vm-attachments
     (each VG keeps name, extId and description; the disks stay)
FIPs: 48, all fip-dummy-name, all NOT_ASSOCIATED
PRIMARY-IPAM reserved-ips: 0
ping <net>.50 → 100% packet loss
curl https://<net>.51 → 000 ; https://<net>.52 → 000
```

**P-11 answered again, now at scale:** `nkp delete cluster` on AHV leaves **every** Nutanix CSI volume group
behind as an orphan naming the deleted cluster. The node VMs go and the attachments are cleared by PC itself;
the VG objects and their storage are not removed. The count is exactly the PVC count (20 of 20 here, 3 of 3 in
the Starter run).

## 5. Step 4 — delete the 20 orphan volume groups (CHANGES)

Script `/tmp/t8-delete-mgmt-final/vg-delete.py` = ntnx-skills recipe (GET → check `name` + `for nkp-mgmt-01,` in
description → check `vm-attachments` is empty → DELETE with the fresh ETag → verify by re-list):

```text
VGs total: 31 ; targets: 20
 DELETE pvc-df703924-… (PVC helm-charts-pvc)          -> VolumeGroupDelete
 DELETE pvc-8e69940b-… (PVC git-operator-admin-volume) -> VolumeGroupDelete
 DELETE pvc-d3a50e75-… (PVC git-operator-git-volume)   -> VolumeGroupDelete
 DELETE pvc-d371ae4b-… (PVC …fluentd-buffer…)          -> VolumeGroupDelete
 DELETE pvc-e32fd392-… (PVC kube-prometheus-stack-grafana) -> VolumeGroupDelete
 DELETE pvc-56699046-… (PVC db-prometheus-…-prometheus-0) -> VolumeGroupDelete
 DELETE pvc-4c6be583-… (PVC rook-ceph-mon-a)          -> VolumeGroupDelete
 DELETE pvc-afbb14e8-… (PVC rook-ceph-mon-b)          -> VolumeGroupDelete
 DELETE pvc-77d28a0a-… (PVC rook-ceph-mon-c)          -> VolumeGroupDelete
 DELETE pvc-fe78e635-… (PVC centralized-opencost-pvc) -> VolumeGroupDelete
 DELETE pvc-6f15328a-… (PVC opencost-pvc)             -> VolumeGroupDelete
 DELETE pvc-41a9ddb7-… (PVC rook-ceph-osd-set1-data-0sm6h5) -> VolumeGroupDelete
 DELETE pvc-4eb9be25-… (PVC rook-ceph-osd-set1-data-17v2kn) -> VolumeGroupDelete
 DELETE pvc-b1a20154-… (PVC rook-ceph-osd-set1-data-2mssmm) -> VolumeGroupDelete
 DELETE pvc-f7735bef-… (PVC rook-ceph-osd-set1-data-346c6h) -> VolumeGroupDelete
 DELETE pvc-0868811f-… (PVC data-grafana-loki-v3-index-gateway-0) -> VolumeGroupDelete
 DELETE pvc-646e4ccb-… (PVC data-grafana-loki-v3-ingester-zone-c-0) -> VolumeGroupDelete
 DELETE pvc-c4ce1dd3-… (PVC data-grafana-loki-v3-ingester-zone-b-0) -> VolumeGroupDelete
 DELETE pvc-23e18a60-… (PVC data-grafana-loki-v3-compactor-0) -> VolumeGroupDelete
 DELETE pvc-60f7dbe4-… (PVC data-grafana-loki-v3-ingester-zone-a-0) -> VolumeGroupDelete
deleted ok=20 fail=0
== re-list: VGs total 11 ; "for nkp-mgmt-01," 0 ==
== ALL VGs mentioning skilltest or nkp-mgmt or <old>: 0 ==
```

The 11 remaining VGs are the Prism Central VM's own volume groups (FS ext4, no `K8sClusterID`). Untouched.
No VG was skipped for attachments: the safety check ran on all 20 and all were already at 0 attachments.

## 6. Step 5 — D5 operator-host files

Timings harvested from the logs before deletion (no secrets, timings only):

| Log | First line | Last line |
|---|---|---|
| `skilltest-mgmt-01-create.log` (Starter mgmt) | 2026-11-03 13:28:27 | 13:52:25 → **24 min** |
| `skilltest-mgmt-01-delete.log` | 2026-11-04 04:14:14 | 04:19:19 → **5 min 06 s** |
| `nkp-mgmt-01-create.log` (Ultimate mgmt) | 2026-11-04 04:26:23 | 04:49:02 → **22 min 39 s** |
| `skilltest-wl-01-create.log` | 2026-11-04 05:11:35 | 05:14:55 → **3 min 20 s** |
| `skilltest-wl-01-delete.log` | 2026-11-04 05:56:02 | 05:56:58 → **56 s** |
| `nkp-mgmt-01-delete.log` (this task) | 2026-11-04 06:08:30 | 06:15:33 → **7 min 04 s** |

D5 list block (exact names, `$HOME`): 4 of the 9 candidates exist —
`nkp-nkp-mgmt-01-create.sh` 1146, `nkp-mgmt-01-dryrun.yaml` 11831, `nkp-mgmt-01.conf` 5558 (=
`CLUSTER_KUBECONFIG` = `MGMT_KUBECONFIG`), `nkp-nkp-mgmt-01.env` 228. No `-patch.json`, `-nodepool.sh`,
`-nodepool-dryrun.yaml`, `-inventory.yaml`, `-metallb-conf.yaml`.

CHANGES (`rm -f`, RC=0) removed exactly the 11 files of the task:

```text
nkp-nkp-mgmt-01-create.sh  nkp-mgmt-01-dryrun.yaml  nkp-mgmt-01.conf  nkp-nkp-mgmt-01.env
nkp-mgmt-01-create.log     nkp-mgmt-01-delete.log   skilltest-app.yaml
skilltest-mgmt-01-create.log  skilltest-mgmt-01-delete.log
skilltest-wl-01-create.log    skilltest-wl-01-delete.log
```

After: `ls ~/nkp-nkp-mgmt-01* ~/nkp-mgmt-01* ~/skilltest*` → all three globs "No such file or directory".
Kept, as required: `~/nkp-site.env` 820, `~/cluster.yaml` 15388, `~/nkp-v2.19.0/` (bundle, incl.
`konvoy-bootstrap-image-v2.19.0.tar`), `~/harbor/`, `~/certificates/`, `~/nkp-bundle_v2.19.0_linux_amd64.tar.gz`,
`~/get-docker.sh`, `~/dry1.rc`, `~/harbor-*-installer-v2.14.6.tgz`, `~/verify-wl02.sh`.

### `~/nkp-site.env` — dangling kubeconfig (report only, not edited)

```text
16:export MGMT_KUBECONFIG='/home/ubuntu/skilltest-mgmt-01.conf'   <- deleted earlier in the session
17:export MGMT_KUBECONFIG='/home/ubuntu/nkp-mgmt-01.conf'         <- deleted by this task
```

Both lines point to files that no longer exist ("last line wins" → the second one). The next `nkp`/`kubectl`
block that sources the site file and uses `MGMT_KUBECONFIG` now fails with "no such file". Nothing was appended
or changed (as the task says). The user must set `MGMT_KUBECONFIG` to the next cluster's kubeconfig (or run
`nkp create` again, which rewrites it).

## 7. Final state

| Item | Before | After |
|---|---|---|
| PC VMs | 10 (3 platform + 7 `nkp-mgmt-01`) | **3**: `BASTION`, `<pc-vm>`, `<ad-vm>` |
| PC volume groups | 31 (11 PC + 20 orphan `nkp-mgmt-01`) | **11** (PC only); 0 description contains `skilltest`/`nkp-mgmt`/`<old>` |
| Floating IPs | 48, all `fip-dummy-name`, 0 associated | **48**, all `fip-dummy-name`, **0 associated** |
| `PRIMARY-IPAM` reserved IPs | 0 | **0** |
| CP_VIP `<net>.50` | answered 6443 | **no reply** (ping 100% loss) |
| LB `<net>.51–.55` | `.51` served the NKP UI | **no reply** (curl `.51`, `.52` → 000) |
| VPCs | `<vpc>` | **`<vpc>` only** (`eddfb515`, REGULAR) |
| Subnets | `PRIMARY-IPAM`, `SECONDARY-IPAM-VPC-EXT`, `<vpc>-sn1` | unchanged (3) |
| Route tables | `ae55acb0` (vpc `<vpc>`) | unchanged |
| Bastion `~/` | cluster files + 6 logs + `verify-wl02.sh` | `nkp-site.env`, `cluster.yaml`, `nkp-v2.19.0/`, `harbor/`, `certificates/`, `nkp-bundle….tar.gz`, `get-docker.sh`, `dry1.rc`, 2 `harbor-*-installer` tgz, `verify-wl02.sh` |
| `docker ps -a` on bastion | Harbor 9 + (during the delete) 1 bootstrap | **9 Harbor containers only**, no bootstrap/kind |
| Orphan Secrets `skilltest-wl-02-oci-*` | 2, in `kommander-default-workspace` | gone with the management cluster's workspace |

### One leftover I did not delete (outside the task's file list)

`~/verify-wl02.sh` (1004 bytes, mode 664, 2026-11-04 05:52) — written by the `skilltest-wl-02` delete task
(t7) to verify the VPC; not in the D5 list and not in this task's list. It holds no secret (a few `kubectl`/`ping`
lines). Left in place and reported here. Say the word and it goes.

## Learnings

1. `[nkp-skill nkp-cluster-lifecycle/references/delete.md D5 (P-11)]` — the P-11 command
   `kubectl ... get pv -o custom-columns=NAME:.metadata.name,HANDLE:.spec.csi.volumeHandle` gives no PVC name,
   so the agent cannot tell which volume group holds what. My attempt
   `-o custom-columns=NAME:.metadata.name,CLAIM:.spec.claimRef.namespace/.spec.claimRef.name` returns `<none>`
   for every row, because kubectl splits a `custom-columns` header path on `/`. **Fix:** add the working form to
   the block: `-o custom-columns='NAME:.metadata.name,NS:.spec.claimRef.namespace,PVC:.spec.claimRef.name,HANDLE:.spec.csi.volumeHandle'`
   plus `kubectl ... get pvc -A` — the PVC list is what the user needs before the delete (size and owner).
2. `[nkp-skill nkp-cluster-lifecycle/references/delete.md D5]` — **the biggest gap.** D5 says "the user looks
   for those volume groups in Prism Central" and stops. Nothing tells the agent to *delete* them, which is the
   last thing standing between the site and a clean Prism Central. On an Ultimate management cluster this is 20
   volume groups / 340 Gi, not 3. **Fix:** add a D5 subsection "Delete the leftover volume groups (AHV)" with:
   (a) list `/volumes/v4.0/config/volume-groups` and match `for <cluster>,` in the description;
   (b) check `GET /volume-groups/{extId}/vm-attachments` is empty — **not** any field of the VG object;
   (c) `DELETE /volume-groups/{extId}` with the ETag from a fresh GET;
   (d) re-list and expect 0; (e) never touch a VG with no `K8sClusterID` in the description (they belong to
   Prism Central itself).
3. `[nkp-skill nkp-cluster-lifecycle/references/delete.md D4/D5]` — nothing says the delete leaves volume groups
   whose `attachments` still point at the (now deleted) node VMs for a short time, nor that PC clears them by
   itself. In this run, 20/20 VGs had 1 attachment before the delete and 0 after, with no action from me. Without
   that fact an agent that checks attachments first would stop for nothing, or delete in the wrong order.
   **Fix:** one line in D4: "delete the cluster first, then the volume groups; PC removes the VG attachments when
   it deletes the node VMs."
4. `[nkp-skill nkp-cluster-lifecycle/references/delete.md D4]` — the block gives no expected duration, so the
   agent cannot tell a slow delete from a hung one. Measured: Starter self-managed 5 min 06 s, Ultimate (same 3+4
   nodes, 20 PVCs) **7 min 04 s**, of which 2 min 55 s is the final "delete + wait for full delete". **Fix:** add
   "expect 5–10 min; most of it is at the end" and "the log stays empty until the end when it is piped through a
   mask (`stdbuf -oL` fixes it)".
5. `[nkp-skill nkp-cluster-lifecycle/references/delete.md D4]` — the skill says to check `docker ps --format
   '{{.Names}}'` after the delete but not that the delete itself prints
   `kubectl --kubeconfig="<cluster>-bootstrap.conf" get nodes` and that this file never stays. An agent that
   looks for `~/<cluster>-bootstrap.conf` wastes a step. **Fix:** add "(the bootstrap kubeconfig it prints is
   removed again)".
6. `[nkp-skill nkp-cluster-lifecycle/references/delete.md D5]` — "What stays" does not list the Cluster Secrets
   that a deleted **workload** cluster leaves in its workspace (`<cluster>-oci-cert`,
   `<cluster>-oci-creds`; seen in t7). Here they vanished only because the whole management cluster went. Worse,
   `WORKSPACE_NS` on a management cluster is `kommander`, so `kubectl -n "$WORKSPACE_NS" get secret
   <wl>-oci-cert` says **NotFound** and the agent concludes there is nothing to clean. **Fix:** in D5 add "the
   workload-cluster workspace Secrets `<cluster>-oci-cert` and `<cluster>-oci-creds` stay; delete them with
   `-n <workspace of the deleted cluster>` (not `$WORKSPACE_NS`, which is `kommander` on the management
   cluster)."
7. `[nkp-skill nkp-cluster-lifecycle/references/delete.md D5]` — the file-cleanup block has no line for the
   **run logs** (`<cluster>-create.log`, `<cluster>-delete.log`), which the skills themselves tell the agent to
   write. They name the cluster and stay forever. **Fix:** add `"$HOME/nkp-$CLUSTER_NAME-create.log"
   "$HOME/nkp-$CLUSTER_NAME-delete.log"` (and the `<cluster>-*.log` family) to the list block and the `rm`.
8. `[nkp-skill nkp-cluster-lifecycle/references/delete.md D5]` — the site-env warning ("MGMT_KUBECONFIG points
   to a deleted cluster") is right, but the file can hold **several** `MGMT_KUBECONFIG=` lines from earlier
   clusters (this one had two, both dangling). The skill says "tell the user" and does not say what to check.
   **Fix:** "`grep -n MGMT_KUBECONFIG ~/nkp-site.env`: every line that points to a file that does not exist is
   dangling; the last one wins."
9. `[ntnx-skill nutanix-api]` — the nutanix-skills never mention volume groups at all (`grep -r
   'volume-group|VolumeGroup' skills/` → nothing), yet every NKP CSI PVC is a volume group and cleaning them up
   is the last step of a Nutanix cluster delete. **Fix:** add a `nutanix-api` RECIPES entry "Volume groups":
   `GET /volumes/v4.0/config/volume-groups`, `GET …/{extId}`, `GET …/{extId}/vm-attachments`,
   `DELETE …/{extId}` with ETag, and the note that the task name is `VolumeGroupDelete`.
10. `[fact]` v4 `VolumeGroup` object shape (needed to write the cleanup): the VM references are
    `attachments[].attachment.extId` — there is **no** `attachedVms` key and no `vmExtId` key. The t7/t1 recipe
    style `a.get('vmExtId')` prints `None` and would make the agent think a VG is unattached when it is not.
    Reliable check: the `…/vm-attachments` subresource. Description format:
    `FS:ext4|none, K8sClusterID:<uuid>, CSIVersion:v3.9.0, DeploymentType:non-bare-metal, CSI StorageClass
    nutanix-volume for <cluster>, PVC:<name>, NS:<ns>, POD:<pod>, SA:<sa>` — the cluster match must include the
    trailing comma (`for <cluster>,`) to avoid matching `nkp-mgmt-01` inside a longer name.
11. `[fact]` `<- wl-02` leftovers: the two `skilltest-wl-02-oci-*` Secrets were the last trace of that deleted
    workload cluster and were removed only because the management cluster itself went away. On a site that keeps
    its management cluster, nothing in the skills removes them.
