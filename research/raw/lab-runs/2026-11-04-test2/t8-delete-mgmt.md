# T8 — `t8-delete-mgmt`: delete the management cluster `nkp-mgmt-01` completely, then audit

Executor `lt2-build-6` (main agent). Date 2026-11-04/05. NKP 2.19.0. Task `t8-delete-mgmt`.
Site user's words: "delete the management cluster nkp-mgmt-01 completely: the cluster and everything it leaves behind in Prism Central and on the operator host. Tell us what stayed after the delete before you clean it up. At the end, give us one audit that proves that nothing is left in Prism Central and on the operator host from nkp-mgmt-01, skilltest-flow-a, and skilltest-flow-b, and that their IPs are free again. Keep the site file ~/nkp-site.env (but tell us what in it is no longer valid), the NKP bundle, the Flow CNI bundle file, the Flow CNI images in Harbor, and the Ubuntu image in Prism Central. Two old Prism Central categories from an earlier test (KubernetesClusterName=skilltest-mgmt-01 and the one of an older cluster) are not yours: list them, do not delete them. I am offline tonight: I approve your plans, go on without waiting for my yes, but write each plan in your log before you run it. Stop only for something outside this request."

Skills used, in order: router `skills/nkp/SKILL.md` → `nkp-cluster-lifecycle` `references/delete.md` (D1, D4, D5, D5.2, D5.4, D5.5) → `ntnx-skills` `nutanix-nkp` RECIPES "Leftover audit for a cluster" → `nutanix-storage` (volume-group delete) → `nutanix-networking` ("Free IP check for a VIP or an LB range") → `nutanix-prism` (categories). `nkp-flow-cni` delete item (N-36) not needed: the Flow CNI clusters are already gone (`t5`, `t7`).

Earlier notes on this site: `t1-preflight.md`, `t2-mgmt.md`, `t3-flow-a.md`, `t5-delete-flow-a.md`, `t6-flow-b.md`, `t7-delete-flow-b-ws.md`.

Hard rules applied: `timeout` + keepalive flags on every ssh; `--request-timeout=30s` on every kubectl read; `sleep` as its own call (≤120 s); the delete runs in tmux with a log; no secret printed; no finalizer removed; no skill file edited; nothing committed.

## Block 01 — `01-preflight.sh` (D1 + D4 gate)

READ-ONLY. Findings:

```
nkp 2.19.0, catalog v0.11.1, diagnose v0.14.0, imagebuilder v2.19.0
~/nkp-site.env 1045 B (15:17), ~/nkp-nkp-mgmt-01.env 228 B (14:39)
MGMT_KUBECONFIG export lines: 3 (16 skilltest-mgmt-01.conf from lab test 1, 17 and 18 nkp-mgmt-01.conf) -> last line wins
MGMT_KUBECONFIG: file found
CLUSTER_NAME=nkp-mgmt-01 CP_VIP=<net>.50 LB=<net>.51-<net>.55 WS_NS=kommander
D4 gate: nkpclusters -A -> kommander/nkp-mgmt-01 v2.19.0 v1.36.2 Reconciled 170m   (only one: pass)
workspaces: default-workspace, kommander-workspace   (skilltest-flow was deleted in t7)
nodes: 7 Ready
PVCs: 20 Bound  (caren-system 1, git-operator-system 2, kommander 17)
PVs: 20, every one with HANDLE NutanixVolumes-<uuid>   (the volume-group extIds of D5.2)
LoadBalancer: kommander/kommander-traefik -> <net>.51 (the first IP of the LB range)
docker ps -a: the site Harbor stack only, no bootstrap container; tmux: no session
operator host files with the cluster name: 6
   nkp-mgmt-01-dryrun.err 1114 | nkp-mgmt-01-dryrun.yaml 11831 | nkp-mgmt-01.conf 5562
   nkp-nkp-mgmt-01-create.log 7660 | nkp-nkp-mgmt-01-create.sh 1146 | nkp-nkp-mgmt-01.env 228
kept files present: $BUNDLE_DIR/konvoy-bootstrap-image-v2.19.0.tar (3.4 GB), ~/flow-cni-1.1.0.tar (914 MB)
disk: 848 GB free on /
```

D4 gate passes: the only NKPCluster is the management cluster, and the user named it. No workload cluster exists, so nothing can be orphaned by the delete.

## Block 02 — `02-pc-audit.py` (ntnx `nutanix-nkp` "Leftover audit", baseline)

READ-ONLY, runs on this laptop with the `ntnx` client.

```
nkp-mgmt-01:    VMs 7 (all power ON), volume_groups 0, floating_ips 0, reservations 0, categories 1
                CAT KubernetesClusterName=nkp-mgmt-01 extId 8a0db695-… inUse True
skilltest-flow-a: all counts 0
skilltest-flow-b: all counts 0
skilltest-flow:   all counts 0
PC totals: 10 VMs (7 = the management nodes; BASTION, <ad-vm>, PC VM), 31 volume groups,
           48 floating IPs (all bulk-named, none of a test cluster), 1 VPC (<lab-vpc>, lab object),
           3 subnets (PRIMARY-IPAM, SECONDARY-IPAM-VPC-EXT, <lab-vpc>-sn1), 57 categories
categories that mention a KubernetesCluster* key:
   KubernetesClusterName nkp-mgmt-01        inUse True    <- mine
   KubernetesClusterName skilltest-mgmt-01  inUse False   <- the user's "old category" #1
   KubernetesClusterName <mgmt-cluster>     inUse False   <- the user's "old category" #2 (lab test 1)
   KubernetesClusterUUID k8s-cf97f500-…     inUse False   <- the management cluster (block 03b)
   KubernetesClusterUUID k8s-6e694f3b-…     inUse False   <- skilltest-flow-a (t5 recorded this id)
   KubernetesClusterUUID k8s-adc70254-…     inUse False   <- skilltest-flow-b (t7)
   KubernetesClusterUUID k8s-cd478812-…     inUse False   <- the earlier skilltest-flow-b attempt (t7)
   KubernetesClusterUUID k8s-1648d403-…, -719aa38b-…, -8f2c41e0-…, -a6b09225-…, -c374ed8a-… inUse False
                                                          <- 5 ids I cannot attribute: older lab objects
```

The volume-group count of the audit is 0 because it keeps only groups with no VM attachment; the 20 groups of the management cluster are attached to the live nodes. They are found by the PV handles of block 01 instead.

## Block 03 — `03-mgmt-uuid.py`, `03b-mgmt-ids.py`, `03c-cat-times.py` (attribution)

READ-ONLY:

```
the 7 management VMs hold exactly one category each: KubernetesClusterName=nkp-mgmt-01 (extId 8a0db695-…)
the VM `categories` list is extId references in vmm/v4.1 (no key/value pair) -> resolve with the CAT list
K8sClusterID of the management volume groups: cf97f500-4355-4336-9222-3e29da7b1e73, 20 groups
   (e.g. pvc-2901c987-…, helm-charts-pvc)  -> KubernetesClusterUUID=k8s-cf97f500-… is this cluster's
category objects carry no createTime, so an unattributed id cannot be dated
```

The management VMs do **not** carry a `KubernetesClusterUUID` category, so its `inUse` is `False` although the cluster is alive. `inUse: False` alone is therefore not proof that a category is a leftover.

## Plan — delete `nkp-mgmt-01` (written before the block runs)

1. Block 04 (`04-delete.sh`, CHANGES): `nkp delete cluster --self-managed --cluster-name nkp-mgmt-01 --namespace kommander --kubeconfig "$MGMT_KUBECONFIG" --timeout 60m --bootstrap-cluster-image "$(ls "$BUNDLE_DIR"/konvoy-bootstrap-image-*.tar)"` in tmux session `nkp-nkp-mgmt-01-delete-t8`, log `~/nkp-nkp-mgmt-01-delete.log` (the exact D4 block, with its own log name, so the D5.4 file list matches).
   - Target: the management cluster `nkp-mgmt-01` on the AHV cluster `<ahv-cluster>`, CP VIP `<net>.50`, LB `<net>.51-<net>.55`.
   - Result: the 7 node VMs and their 7 disks go, all 20 PVCs' volume groups stay unattached in Prism Central with their data (D5: 20 for an Ultimate management cluster), Kommander, the NKP UI, the Ultimate platform apps, the license Secret and the workspace objects go with the cluster. The IPs `<net>.50`–`<net>.55` become free.
   - The run makes a kind bootstrap cluster on the operator host (needs 4 CPU / 4 GB free: 16 CPU, 848 GB, at 96 % idle CPU), moves the CAPI resources into it, deletes the cluster, then deletes the bootstrap cluster.
   - Air-gap: `--bootstrap-cluster-image` with the bundle's `konvoy-bootstrap-image-v2.19.0.tar` (present).
   - Keep: `~/nkp-site.env`, the NKP bundle, `~/flow-cni-1.1.0.tar`, the Harbor Flow CNI images, the Prism Central Ubuntu image, the `<lab-vpc>` and the older lab objects.
2. Block 05 (READ-ONLY, after `RC=0`): the D4 check for a bootstrap cluster and a `-bootstrap.conf` file, and the D3 IP check (`ping` of `CP_VIP`, `curl` of the first LB IP).
3. Block 06 (READ-ONLY): the full leftover report — management side (not applicable after the delete: the cluster is gone, so the check is "the API server does not answer"), Prism Central (the audit again + the 21 groups by extId), operator host (the 6 files + the name grep + any `-bootstrap.conf`).
4. Report it in this log **before** the cleanup, then the cleanup plan, then the cleanup (the 20 volume groups, the leftover categories of my clusters, the operator-host files), then the final audit of all three clusters.

## Block 04 — `04-delete.sh` (D4, the self-managed delete)

```
start: 17:17:17 UTC, tmux session nkp-nkp-mgmt-01-delete
17:17:17 Loading bootstrap image from archive          (13 s)
17:17:30 Creating a bootstrap cluster                 (29 s)
17:17:59 Installing CAPI Stack operators              (51 s)
17:18:50 Creating CAPI components
         Creating ClusterClass resources / Creating NKPCluster resources (as in the D4 output list)
17:20:44 Moving cluster resources -> "nkp-mgmt-01-bootstrap.conf"
17:20:44 Waiting for cluster in kommander/nkp-mgmt-01             (immediate)
17:20:44 Waiting for cluster infrastructure to be ready          (immediate)
17:20:44 Waiting for cluster control-planes to be ready          (immediate)
17:20:44 Waiting for machines to be ready                        (immediate)
17:20:44 Deleting cluster resources for Cluster kommander/nkp-mgmt-01
17:23:39 Waiting for cluster to be fully deleted      (2 min 55 s — the longest step, 20 PVCs)
17:23:39 Deleted kommander/nkp-mgmt-01 cluster
17:23:39 Deleting bootstrap cluster
RC=0
```

**6 min 25 s** in total. The D4 text says 5–10 min for 3 control-plane and 4 worker nodes (Starter 5 min 6 s, Ultimate 7 min 4 s); this Ultimate cluster with 20 PVCs took 6 min 25 s, so the text holds. The move ("Moving cluster resources") is 106 s of it.

## Block 05 + 06 — `05-log-tail.sh`, `06-after.sh` (the D4 and D3 checks)

```
log ends with RC=0
docker ps -a | grep -i bootstrap: no container with bootstrap in its name
ls ~/nkp-mgmt-01-bootstrap.conf: No such file or directory   (as D4 says: it goes with the bootstrap cluster)
no bootstrap file in HOME; tmux: no session
CP_VIP no reply;  lb_first_ip=000;  cp_vip_https=000        (D3: the IPs stopped answering)
kubectl --kubeconfig "$MGMT_KUBECONFIG" get nodes: "Unable to connect to the server: dial tcp <net>.50:6443: connect: no route to host"
operator host files with the cluster name: 7
   1114  nkp-mgmt-01-dryrun.err        11831  nkp-mgmt-01-dryrun.yaml      5562  nkp-mgmt-01.conf
   7660  nkp-nkp-mgmt-01-create.log    1146   nkp-nkp-mgmt-01-create.sh    1840  nkp-nkp-mgmt-01-delete.log
   228   nkp-nkp-mgmt-01.env
kept: ~/nkp-site.env (1045 B, 15:17 — unchanged), ~/flow-cni-1.1.0.tar (914 MB),
      $BUNDLE_DIR/konvoy-bootstrap-image-v2.19.0.tar (3.4 GB); disk still 848 GB free
```

## Block 07 — `07-pc-after.py` (Prism Central after the delete)

```
VMs: 3   (BASTION, <pc-vm>, <ad-vm>) — the 7 management node VMs are gone, 0 with a test name
volume groups: 31 in PC, and all 20 extIds of the D2 PV list are still there, vm-attachments 0,
   K8sClusterID cf97f500-…  (D5: the PVC data stays until D5.2)
floating IPs: 48 (all bulk-named, none of a test cluster); reservations with a test name: none
VPCs: 1 (<lab-vpc>, the lab object); categories: 57
images: 1 — nkp-ubuntu-24.04-release-cis-1.36.2-… DISK_IMAGE   (kept, as the user asked)
categories that mention a KubernetesCluster* key after the delete:
   KubernetesClusterName nkp-mgmt-01        inUse=False   <- mine, PC did NOT remove it
   KubernetesClusterName skilltest-mgmt-01  inUse=False   <- the user's old category #1
   KubernetesClusterName <mgmt-cluster>     inUse=False   <- the user's old category #2
   KubernetesClusterUUID k8s-cf97f500-…     inUse=False   <- mine (nkp-mgmt-01)
   KubernetesClusterUUID k8s-6e694f3b-…     inUse=False   <- mine (skilltest-flow-a, t5)
   KubernetesClusterUUID k8s-adc70254-…     inUse=False   <- mine (skilltest-flow-b, t7)
   KubernetesClusterUUID k8s-cd478812-…     inUse=False   <- mine (the earlier skilltest-flow-b attempt, t7)
   KubernetesClusterUUID k8s-1648d403-…, -719aa38b-…, -8f2c41e0-…, -a6b09225-…, -c374ed8a-… inUse=False
                                             <- 5 ids from before this test, not attributable to my clusters
```

# What stayed after the delete (the report the user asked for, written before the cleanup)

**1. Prism Central — 20 volume groups of the management cluster's PVCs, with their data, unattached.** They are "normal" leftovers (D5): the delete removes the node VMs and their disks, not the PVCs. Total 340 GiB of PVC data (100 GiB Prometheus, 4 × 40 GiB Rook Ceph OSD, 10 × 10 GiB, 2 × 2 GiB). Their `K8sClusterID` is `cf97f500-…` (this cluster). Nothing in the cluster can read them any more: the cluster is gone.

**2. Prism Central — 5 category objects that belong to my three clusters.** PC removed nothing by itself:

| Category | Value | Belongs to |
|---|---|---|
| `KubernetesClusterName` | `nkp-mgmt-01` | nkp-mgmt-01 |
| `KubernetesClusterUUID` | `k8s-cf97f500-…` | nkp-mgmt-01 (the `K8sClusterID` of its volume groups) |
| `KubernetesClusterUUID` | `k8s-6e694f3b-…` | skilltest-flow-a (`t5` recorded this id) |
| `KubernetesClusterUUID` | `k8s-adc70254-…` | skilltest-flow-b (`t7`) |
| `KubernetesClusterUUID` | `k8s-cd478812-…` | the earlier skilltest-flow-b attempt (`t7`) |

`inUse: False` is not a leftover test: the management VMs carried only the name category, never the UUID one. Each of my four cluster instances has exactly one UUID, and all four are named above, so the 5 remaining UUID categories (and the 2 old name categories) cannot be mine. They are listed, not deleted, as the user asked.

**3. Operator host — 7 files in `$HOME`:** `nkp-mgmt-01-dryrun.err`, `nkp-mgmt-01-dryrun.yaml`, `nkp-mgmt-01.conf` (the kubeconfig), `nkp-nkp-mgmt-01-create.log`, `nkp-nkp-mgmt-01-create.sh`, `nkp-nkp-mgmt-01-delete.log`, `nkp-nkp-mgmt-01.env`. All 7 are in the D5.4 list; the name grep found nothing else. No bootstrap container, no kind cluster, no `-bootstrap.conf`.

**4. Site file — 3 `MGMT_KUBECONFIG` lines in `~/nkp-site.env`, none valid any more:** line 16 (`skilltest-mgmt-01.conf`, dangling since lab test 1), lines 17 and 18 (`nkp-mgmt-01.conf`, the deleted cluster). Every block that uses `MGMT_KUBECONFIG` now fails with `no route to host` (block 06 shows it). `~/nkp-nkp-mgmt-01.env` and `~/nkp-mgmt-01.conf` stay until the D5.4 cleanup removes them. Nothing else in the site file is invalid: `PC_*`, `SUBNET`, `PE_CLUSTER`, `STORAGE_CONTAINER`, `VM_IMAGE`, `BUNDLE_DIR`, `REGISTRY_*`, `NTP_SERVERS`, `SSH_PUBKEY_FILE` and the secrets are site values, not cluster values.

**Gone with the delete, as D4 says:** the 7 node VMs, their 7 OS disks, all 21 node disks' data plus the 20 PVC volume groups' attachments, the NKPCluster, the CAPI Cluster, Kommander, the NKP UI, Dex, the 48 Ultimate HelmReleases, the license Secret, the workspace objects, the LoadBalancer IP `<net>.51`, the CP VIP `<net>.50`, and the kind bootstrap cluster.

## Cleanup plan (standing approval; written before the run)

1. Block 09 (`09-vg-delete.py`, CHANGES, Prism Central): delete the 20 volume groups by extId, after re-proving for each one that the description names `K8sClusterID:cf97f500-…` and that `vm-attachments` is 0. The PVC data goes (the cluster that held it is deleted). No other PC object is touched. `nutanix-storage` RECIPES "Delete a volume group".
2. Block 10 (`10-cat-delete.py`, CHANGES, Prism Central): delete the 5 category objects of the table above (`nutanix-prism` RECIPES "Categories", `delete(CAT/<extId>, etag)`). The 2 old name categories and the 5 unattributed UUID categories stay.
3. Block 11 (`11-host-files.sh`, CHANGES, operator host): remove the 7 files, cluster env file last (`;`, not `&&`). Keep `~/nkp-site.env`, the bundle, `~/flow-cni-1.1.0.tar`.
4. Block 12 + 13 + 14 (READ-ONLY): the final audit — management side (no API, no kubeconfig), Prism Central (audit + VMs + groups + categories + images), operator host (name grep), the IPs (`<net>.50`–`<net>.55` via the API and an ARP probe on the L2 host), and the mirror images that must stay.
5. Never touched: `~/nkp-site.env`, the NKP bundle, `~/flow-cni-1.1.0.tar`, the Harbor Flow CNI images, the Prism Central Ubuntu image, `<lab-vpc>`, the two old categories, the 5 unattributed UUID categories, the 3 non-NKP VMs.

## Block 09 — `09-vg-delete.py` (D5.2, the 20 volume groups)

```
volume groups in PC before: 31
each of the 20: kid=cf97f500-… attachments=0 hidden=False -> DELETE -> get 404
   (pvc-2901c987, -e5cb828d, -444ce524, -c445b163, -189b8a87, -127caf4d, -9c5057dc, -1b6d1e85,
    -ac2d92a8, -5bd28131, -303b82b2, -f1069fb3, -6a5dced3, -cfd8c9ac, -b2066bbb, -a1c2a98d,
    -d902124e, -12761c44, -56655288, -7a9d9115)
volume groups in PC after: 11
```

31 was the count `t5-delete-flow-a` left, so the 20 that went are exactly this cluster's. Every target was re-proved before the delete: `K8sClusterID:cf97f500-…` in the description, `vm-attachments: 0`, `isHidden: False`, `usageType != INTERNAL`. No detach was needed. About 3 s per group.

The 11 that stay are the older lab volume groups (from before lab test 2), not mine.

## Block 10 — `10-cat-delete.py` (Prism Central categories)

```
categories in PC before: 57
  KubernetesClusterName=nkp-mgmt-01        inUse=False -> DELETE -> gone (404)
  KubernetesClusterName=skilltest-mgmt-01  inUse=False -> KEEP   (the user's old category #1)
  KubernetesClusterName=<mgmt-cluster>     inUse=False -> KEEP   (the user's old category #2)
  KubernetesClusterUUID=k8s-cf97f500-…     inUse=False -> DELETE -> gone (404)   (nkp-mgmt-01)
  KubernetesClusterUUID=k8s-6e694f3b-…     inUse=False -> DELETE -> gone (404)   (skilltest-flow-a)
  KubernetesClusterUUID=k8s-adc70254-…     inUse=False -> DELETE -> gone (404)   (skilltest-flow-b)
  KubernetesClusterUUID=k8s-cd478812-…     inUse=False -> DELETE -> gone (404)   (earlier flow-b attempt)
  KubernetesClusterUUID=k8s-1648d403-…, -719aa38b-…, -8f2c41e0-…, -a6b09225-…, -c374ed8a-… -> KEEP
                                           (5 ids that belong to no cluster of this test)
categories in PC after: 52
```

The block refuses a category that is still in use (`inUse=True` skips it), so the order of the two cleanups does not matter.

## Block 11 — `11-host-files.sh` (D5.4, the 7 operator-host files)

```
after: no file with the cluster name   (`ls -a ~ ~/` grep: no line)
$HOME/*.conf: no .conf file            (the management kubeconfig is gone)
kept: ~/nkp-site.env 1045 B 21 lines (unchanged), ~/flow-cni-1.1.0.tar 914 MB
cluster env file gone
```

The block removed all 7: `nkp-mgmt-01-dryrun.err`, `-dryrun.yaml`, `nkp-mgmt-01.conf` (via `$CLUSTER_KUBECONFIG`), `nkp-nkp-mgmt-01-create.log`, `-create.sh`, `-delete.log`, `nkp-nkp-mgmt-01.env` (last, after `;`). The name grep found no file outside the list — the D5.4 list is complete for a management cluster.

## Block 12 + 13 — `12-final-host.sh` (mis-parsed registry check), `13-mirror-check.sh` (walked: host state, kept files, mirror)

```
files of the three test clusters in $HOME: none
containers: 9 (the site Harbor stack), no bootstrap or kind container; no tmux session
kubeconfigs in $HOME: none
~/nkp-site.env: 21 lines, the 3 MGMT_KUBECONFIG lines (16, 17, 18) -> "MGMT_KUBECONFIG: no file"
kept: ~/nkp-bundle_v2.19.0_linux_amd64.tar.gz (35 GB), ~/nkp-v2.19.0/konvoy-bootstrap-image-v2.19.0.tar (3.4 GB),
      ~/flow-cni-1.1.0.tar (914 MB)
mirror (read-only, pull account, `tags/list` over https):
  nutanix/nutanix/flow-cni -> 200 | nutanix/nutanix/flow-container-security -> 200
  nutanix/nutanix/flow-ovn-kubernetes -> 200 | nutanix/nutanix-flow-cni (chart) -> 200
  nutanix/nats -> 200 | nutanix/k8snetworkplumbingwg/multus-cni -> 200 | /v2/_catalog -> 200
```

`12` first read the registry as `http://` from a wrong URL parse and got `000`/`308`; `13` uses the A-30 host/project split and `https`. The Harbor answers `308` on plain http, so a read-only registry check must use `https` (see Learnings).

## Block 14 + 17 + 18 — the final audit

`14-final-pc.py` (PC), `17-all-ips-api.py` (the API half of the free-IP check), `18-all-ips-arp.sh` (the ARP half, on the L2 host).

```
A. leftover audit (nutanix-nkp "Leftover audit for a cluster"), counts only:
   nkp-mgmt-01      {VMs 0, volume_groups 0, floating_ips 0, ip_reservations 0, categories 0}
   skilltest-flow-a {VMs 0, volume_groups 0, floating_ips 0, ip_reservations 0, categories 0}
   skilltest-flow-b {VMs 0, volume_groups 0, floating_ips 0, ip_reservations 0, categories 0}
   skilltest-flow   {VMs 0, volume_groups 0, floating_ips 0, ip_reservations 0, categories 0}

B. Prism Central totals:
   VMs 3: BASTION, <pc-vm>, <ad-vm>          (was 10 before the delete, 17 before flow-b)
   volume groups 11                          (31 before this cleanup; the 11 are pre-test lab groups)
   floating IPs 48, none with a test name; IP reservations with a test name: none
   VPCs 1 (<lab-vpc>); subnets 3 (PRIMARY-IPAM, SECONDARY-IPAM-VPC-EXT, <lab-vpc>-sn1)
   categories 52 (57 before), of which 7 mention a cluster and stay as told:
       KubernetesClusterName=skilltest-mgmt-01, KubernetesClusterName=<mgmt-cluster>,
       KubernetesClusterUUID=k8s-1648d403-…, -719aa38b-…, -8f2c41e0-…, -a6b09225-…, -c374ed8a-…
   images 1: nkp-ubuntu-24.04-release-cis-1.36.2-… DISK_IMAGE   (kept)
   storage containers 4 (the 3 user containers + NutanixManagementShare)

C. the 18 IPs of the three clusters, API half (pool, reservations, VM NICs, floating IPs):
   <net>.50, .51-.55, .60, .61-.65, .70, .71-.75 -> in_pool=False holder=None  (all 18)

D. the same 18 IPs, ARP half on the L2 host: all 18 -> FREE (FAILED/INCOMPLETE, no lladdr);
   control: <net>.37 and <net>.39 -> lladdr present, REACHABLE  (the probe can see a live host)
```

# The final audit

| Side | What was checked | Result |
|---|---|---|
| Prism Central | `nkp-mgmt-01`, `skilltest-flow-a`, `skilltest-flow-b`, `skilltest-flow`: VMs, volume groups (description + attachments), floating IPs, IP reservations, categories | **0 of every kind, all four names** |
| Prism Central | VM list | 3 VMs, none of a test cluster (BASTION, <pc-vm>, <ad-vm>) |
| Prism Central | volume groups | 11, all pre-test lab groups (was 31 before this cleanup) |
| Prism Central | categories | 52; the 5 objects of my clusters are deleted; the 7 older ones listed above stay on the user's order |
| Prism Central | images, VPCs, containers | the Ubuntu image, `<lab-vpc>`, 4 containers — all as before the test |
| Operator host | any file with `nkp-mgmt-01`, `skilltest-flow`, `skilltest-mgmt-01` in its name | none (the grep prints no line) |
| Operator host | kubeconfigs, bootstrap/kind container, tmux sessions | none |
| Operator host | kept: `~/nkp-site.env` (21 lines, unchanged), the NKP bundle (35 GB + the extracted folder), `~/flow-cni-1.1.0.tar` | present |
| Operator host | Harbor Flow CNI images (read-only `tags/list`): flow-cni, flow-container-security, flow-ovn-kubernetes, the chart, nats, multus-cni | `200` for every one |
| Network | `<net>.50`–`.55`, `.60`–`.65`, `.70`–`.75`: PC pool, PC reservations, VM NICs, floating IPs, ARP, ICMP | **all 18 free** |

## The site file after the delete (D5.5)

`~/nkp-site.env` is kept and unchanged (21 lines). What is no longer valid:

- line 16 `MGMT_KUBECONFIG='/home/ubuntu/skilltest-mgmt-01.conf'` — dangling since lab test 1.
- lines 17 and 18 `MGMT_KUBECONFIG='/home/ubuntu/nkp-mgmt-01.conf'` — the deleted cluster; the file is removed.
- Consequence: the last line wins and points to a file that does not exist, so every block that uses `MGMT_KUBECONFIG` fails with `no route to host` / `no such file or directory` until a new management cluster exists and its create appends a new line (skill `nkp-install`, "Set the kubeconfig variables").
- Nothing else in the file is invalid: the `PC_*`, `PE_CLUSTER`, `SUBNET`, `STORAGE_CONTAINER`, `VM_IMAGE`, `BUNDLE_DIR`, `IMAGE_BUNDLES`, `REGISTRY_*`, `NTP_SERVERS`, `SSH_PUBKEY_FILE` values and the secrets are site values, not cluster values. The two `MGMT_KUBECONFIG` appends by `t2` are duplicates of each other (lines 17 and 18 have the same value); harmless, the last line wins.

## Learnings

### L-01 `[nkp-skill nkp-cluster-lifecycle/references/delete.md D5]` — the leftover list has no Prism Central categories, and Prism Central does not remove them

After `nkp delete cluster --self-managed` on 2.19.0, Prism Central still held **5 category objects of my clusters**: `KubernetesClusterName=nkp-mgmt-01` (this cluster) and the four `KubernetesClusterUUID=k8s-…` objects of `nkp-mgmt-01`, `skilltest-flow-a`, `skilltest-flow-b` and the earlier `skilltest-flow-b` attempt. D5 "What stays" lists the volume groups, the mirror Secrets, the VPC objects, the Flow CNI HCP, the Metal hosts and the operator-host files, and says nothing about categories. Lab test 2 recorded three different behaviours (`t5`: both categories of flow-a gone; `t7`: no `KubernetesClusterUUID` at all; `t8`: the name category and all four UUIDs stay), so "Prism Central removes the categories with the VMs" is not a fact an executor can rely on. `inUse: False` is also not a leftover test: the live management VMs carried only the name category, so its UUID category was `inUse: False` while the cluster ran.

Proposed fix, in D5 after the Metal hosts bullet:

> - **Prism Central categories.** NKP tags the VMs with `KubernetesClusterName=<cluster>` and records `KubernetesClusterUUID=k8s-<uuid>`. Measured 2.19.0: the delete does not remove them reliably (a management cluster: both stay; a workload cluster: the name goes, the UUID stays). `inUse: False` is **not** proof that a category is free: the management nodes carry only the name category, so their UUID category always shows `False`. Find the cluster's UUID in the `K8sClusterID:` field of any of its volume-group descriptions (do this **before** the D5.2 delete), then delete `KubernetesClusterName=<cluster>` and `KubernetesClusterUUID=k8s-<uuid>` with skill `nutanix-prism`, RECIPES "Categories". Delete a category only when `inUse` is `False`.

### L-02 `[ntnx-skill nutanix-nkp]` "Leftover audit for a cluster" — a `KubernetesClusterUUID` category of a deleted cluster is invisible to it

The recipe matches `cluster in (c.get('key') or '') or cluster in (c.get('value') or '')`. A `KubernetesClusterUUID=k8s-cf97f500-…` object has neither the cluster name in its key nor in its value, so `audit('nkp-mgmt-01')` returned `categories: 0` while that object was still in Prism Central (this run: block 14 A vs B). The same run also shows that the audit's `volume_groups` count is 0 for a live cluster (the groups are attached) — that is documented, but the category case is not.

Proposed fix: give the recipe a second argument, `uuid=None`, and add `val in ({'k8s-' + uuid} if uuid else set())` to the category filter; document the source of the UUID: "the `K8sClusterID:` field of a volume-group description, read **before** the D5.2 delete; after the delete the id is only in the category itself". Also add a row to the "Reading the result" table: `categories` — "`KubernetesClusterUUID` rows survive both a workload and a management delete; the name row survives a management delete".

### L-03 `[ntnx-skill nutanix-prism]` "Categories" — a category object has no `createTime`, so an unattached one cannot be dated or attributed

I had 5 `KubernetesClusterUUID` categories that I could not attribute to a cluster. `createTime` is `None` for every category object (block 03c), and the `prism` task list has no category tasks at all (block 08: 0 of 1200 tasks). So the only attribution path is an external record (a volume-group description, a note from the previous delete). That is enough here, but the skill should say it.

Proposed fix, one line in the "Categories" section: "A category object has no `createTime`, and Prism Central writes no task when a category is assigned, so you cannot date one. To attribute an unattached `KubernetesClusterUUID`, use the `K8sClusterID:` of a volume group of that cluster, read before you delete the groups."

### L-04 `[nkp-skill nkp-cluster-lifecycle/references/delete.md D4]` — "run the first D2 block" needs `$MGMT_KUBECONFIG` on a management cluster

D2's PV block uses `$CLUSTER_KUBECONFIG`. D4 says "Run the first D2 block (the facts, with the PV list)". The management env file that `nkp-install` writes (`~/nkp-nkp-mgmt-01.env`) has `CLUSTER_NAME`, `CP_VIP`, `LB_IP_RANGE`, `WORKSPACE_NS` and the site source line — **no `CLUSTER_KUBECONFIG`**. Here the site file happens to carry it (the create appends both), so the block worked; a site that only appended `MGMT_KUBECONFIG` would run the PV block against an empty kubeconfig.

Proposed fix, in D4 after "Run the first D2 block": "On a management cluster, read `$MGMT_KUBECONFIG` where D2 says `$CLUSTER_KUBECONFIG`; the cluster env file has no `CLUSTER_KUBECONFIG`."

### L-05 `[fact]` — the D4 block, the counts and the timings are right; one cosmetic detail

- Total **6 min 25 s** (17:17:17 → 17:23:42), RC=0, inside the D4 "5–10 min" range: bootstrap 42 s, CAPI 2 min 45 s, move 106 s, delete resources 2 min 55 s, bootstrap delete 3 s. The 20 PVCs are what make "Waiting for cluster to be fully deleted" 2 min 55 s (D4 says 1–3 min).
- The D4 tmux line names the session and the log `nkp-$CLUSTER_NAME-delete`, so for `nkp-mgmt-01` they read `nkp-nkp-mgmt-01-delete`, and D5.4's `$HOME/nkp-$CLUSTER_NAME-delete.log` matches. Correct but easy to mis-read; one example line in D4 would remove the doubt.
- The D4 check ("no container with `bootstrap` in its name, no `<cluster>-bootstrap.conf`") passed: the file goes with the bootstrap cluster, as D4 says.
- The operator host had **exactly** the 6 predicted files plus the delete log. Unlike the Flow CNI workload clusters (`t5` L-02: 3 extra files), the D5.4 list is complete for a management cluster.
- Volume groups: 20, 340 GiB, `K8sClusterID cf97f500-…` — exactly D5's "Ultimate management cluster 20 (340 Gi)". D5.2 took ~60 s (20 × GET + DELETE).
- The 18 IPs of the three clusters are free by all four PC sources, ARP and ICMP.

### L-06 `[fact]` — a read-only Harbor check must use `https`, and the A-30 split is the only correct URL parse

The site Harbor answers **308** on `http://<registry-host>/v2/...`, so a plain-http `tags/list` reads `308` (or `000` with `-o /dev/null`) and looks like "the images are gone". `REGISTRY_URL` carries a scheme (`https://<host>/nutanix`); `cut -d/ -f1` on it gives `https:` and every URL breaks. The A-30 block of `nkp-airgap/references/nodes.md` (`h="${REGISTRY_URL#*://}"; host="${h%%/*}"; p=…`) is the correct parse; the free-IP and mirror recipes should use it, and the check should use `https`.

### L-07 `[fact]` — what the delete leaves, measured end to end (for the D5 text)

| Object | Before | After the delete | After the cleanup |
|---|---|---|---|
| Prism Central VMs | 10 | 3 (BASTION, <pc-vm>, <ad-vm>) | 3 |
| Volume groups | 31 | 31 (20 of them this cluster, unattached) | 11 |
| Categories (a KubernetesCluster* one) | 12 | 12 (5 of mine) | 7 (older ones) |
| Operator host files | 7 | 7 | 0 |
| CP VIP / LB IP / node IPs | in use | free (ARP, ICMP, PC) | free |

## Status

`done`. `nkp-mgmt-01` is deleted completely on all three sides and the audit of all three clusters is clean: 0 VMs, 0 volume groups, 0 floating IPs, 0 IP reservations and 0 categories for `nkp-mgmt-01`, `skilltest-flow-a` and `skilltest-flow-b`; no operator-host file with any of their names; the 18 IPs of the three clusters are free by the four Prism Central sources, ARP and ICMP. Kept as the user asked: `~/nkp-site.env` (with the 3 invalid `MGMT_KUBECONFIG` lines reported), the NKP bundle, `~/flow-cni-1.1.0.tar`, the Harbor Flow CNI images (all `200`), the Prism Central Ubuntu image, and the 7 older categories (2 named ones + 5 unattributed UUID ones), listed and not deleted. No secret printed, no finalizer removed, no skill file edited, nothing committed.

## Block 19 — `19-hidden-state.sh` (the last operator-host check)

READ-ONLY:

```
~/.kube/config: 28 B, no match for the cluster name;  ~/.kube/cache exists (kubectl's own, not NKP's)
~/.konvoy, ~/.nkp, ~/.kind, ~/.cache/nkp, ~/.config/nkp: none of them exist
the only file in $HOME whose content mentions nkp-mgmt-01: ~/nkp-site.env   (kept, lines 16-18 reported)
docker volumes: 9, all of the site Harbor stack (the kind bootstrap cluster made none that stays)
```
