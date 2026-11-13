# t2-delete-mgmt — delete the self-managed management cluster `skilltest-mgmt-01`

Operator host `<bastion>`; Prism Central `<pc>`. Skills followed: `nkp-cluster-lifecycle` `references/delete.md` D1, D4, D5.
Env file on `<bastion>`: `~/nkp-skilltest-mgmt-01.env` (WORKSPACE_NS=kommander, CLUSTER_KUBECONFIG = MGMT_KUBECONFIG = `~/skilltest-mgmt-01.conf`). Bundle `~/nkp-v2.19.0/` = BUNDLE_DIR (air-gapped site with a Harbor mirror).

## 1. D1 — identify the cluster (READ-ONLY)

Block: `~/nkp-skilltest-mgmt-01.env` sourced, `get nkpcluster $CLUSTER_NAME`, `get nkpclusters -A`.

```text
NAMESPACE   NAME                NKP VERSION   KUBERNETES VERSION   PHASE        AGE
kommander   skilltest-mgmt-01   v2.19.0       v1.36.2              Reconciled   14h
```

`MGMT` true / NAMESPACE `kommander` → management cluster → D4. All four env names `set:`.

## 2. Before the delete — P-11 evidence, LB services, PC objects

### PV list (D5 UNKNOWN P-11 command)

```text
NAME                                       HANDLE
pvc-6cb22f4e-8cb9-4cb5-96b2-8e4bf64c8a57   NutanixVolumes-c4558e71-7e94-4159-79de-100936587a6d
pvc-a7053e3c-a1cc-456e-98e8-5bd0695b0a84   NutanixVolumes-597261aa-3180-441e-46ee-af4001673aa1
pvc-f8f09787-82cc-4526-a059-9a315f4e86b6   NutanixVolumes-da28b5cd-8cab-438c-550f-bf6a0f2541fa
```

PVCs: `caren-system/helm-charts-pvc` 2Gi, `git-operator-system/git-operator-admin-volume` 2Gi, `git-operator-system/git-operator-git-volume` 10Gi, all StorageClass `nutanix-volume` (files).

### LoadBalancer services

```text
NAMESPACE   NAME                EXTERNAL-IP   PORT(S)
kommander   kommander-traefik   <net>.51    8085,5000,80,443
```

Only one. MetalLB pool is `<net>.51-<net>.55`.

### Prism Central, before (client `ntnx.py`, `/Users/.../ntnx-skills/skills/nutanix-api/scripts`)

- VMs with prefix `skilltest-mgmt-01`: **7** (3 CP `…-gmb76-*`, 4 workers `…-md-0-d9cf5-gzj7j-*`), all `powerState=ON`. Total VMs in PC: 10.
- Volume groups whose `description` contains `skilltest-mgmt-01`: **3**, and their `extId` equals the `volumeHandle` of the 3 PVs:

| VG name | extId | description (key fields) |
|---|---|---|
| `pvc-6cb22f4e-8cb9-4cb5-96b2-8e4bf64c8a57` | `c4558e71-7e94-4159-79de-100936587a6d` | `FS:ext4, K8sClusterID:c374ed8a-…, CSIVersion:v3.9.0, DeploymentType:non-bare-metal, CSI StorageClass nutanix-volume for skilltest-mgmt-01, PVC:git-operator-git-volume, NS:git-operator-system, POD:git-operator-git-0, SA:default` |
| `pvc-a7053e3c-a1cc-456e-98e8-5bd0695b0a84` | `597261aa-3180-441e-46ee-af4001673aa1` | same prefix, `PVC:git-operator-admin-volume` |
| `pvc-f8f09787-82cc-4526-a059-9a315f4e86b6` | `da28b5cd-8cab-438c-550f-bf6a0f2541fa` | same prefix, `PVC:helm-charts-pvc, NS:caren-system` |

Total VGs in PC: 17 (10 belong to Prism Central itself, CSIVersion v3.7.0; 3 more with `K8sClusterID:a6b09225-…` = the deleted `<old-mgmt-cluster>`).

- Floating IPs in PC: **50** (all named `fip-dummy-name`; 1 `ASSOCIATED_TO_PRIVATE_IP` <net>.137, 49 `NOT_ASSOCIATED`). This is earlier leftover, not from this cluster.
- `PRIMARY-IPAM` subnet (`extId=26224f58-5ce3-494e-8ee3-eadac78aac35`), `reserved-ips`: **0**.

## 3. D4 — gate and delete (CHANGES)

Gate (READ-ONLY): `get nkpclusters -A` lists only `kommander/skilltest-mgmt-01` → pass. `ls "$BUNDLE_DIR"/konvoy-bootstrap-image-*.tar` → `/home/ubuntu/nkp-v2.19.0/konvoy-bootstrap-image-v2.19.0.tar`. Bootstrap host: 16 CPU, 29 GB available, docker up (Harbor containers), no tmux server. Plan: delete the management cluster self-managed — Kommander, the NKP UI, all platform apps, 7 VMs, 3 VGs (maybe), CPU/MetalLB IPs; keeps `~/nkp-site.env`, all `<old-mgmt-cluster>` files, `~/cluster.yaml`, the Harbor registry, and PC images. Standing approval from the session brief.

Delete command (tmux session `del`, log `~/skilltest-mgmt-01-delete.log`), started `2026-11-04T04:14:13Z`:

```bash
nkp delete cluster --self-managed --cluster-name "$CLUSTER_NAME" --namespace "$WORKSPACE_NS" \
  --kubeconfig "$MGMT_KUBECONFIG" --timeout 60m \
  ${BUNDLE_DIR:+--bootstrap-cluster-image "$(ls "$BUNDLE_DIR"/konvoy-bootstrap-image-*.tar)"}
```

stdout+stderr pass through `sed` masks (`Invalid value: "…"` → `<masked>`, `key: …` → `<masked>`).

**Result: RC=0, finished 04:19:19Z. Total 5 min 06 s** (not 60 min; the `--timeout 60m` was never near). The log carries no license error, so the masks were not needed.

Timeline from `~/skilltest-mgmt-01-delete.log`:

| Phase | Start | Duration |
|---|---|---|
| Load bootstrap image from archive | 04:14:14 | 12 s |
| Create a bootstrap cluster | 04:14:26 | 29 s |
| Install CAPI Stack operators | 04:14:55 | 51 s |
| Create CAPI components | 04:15:46 | 60 s |
| Create ClusterClass resources | 04:16:46 | 0 s |
| Create NKPCluster resources | 04:16:46 | 20 s |
| Create ClusterClass resources (again) | 04:17:06 | 0 s |
| Move cluster resources (pivot) | 04:17:06 | 83 s |
| Wait infra/CP/machines ready, delete cluster resources, wait for full delete | 04:18:29 | 50 s |
| `Deleted kommander/skilltest-mgmt-01 cluster`, deleting bootstrap cluster | 04:19:19 | < 35 s (tmux gone at 04:19:54) |

The pivot printed `kubectl --kubeconfig="skilltest-mgmt-01-bootstrap.conf" get nodes`. That file **did not stay** (`ls` → No such file).

## 4. After the delete

### D4 bootstrap check (READ-ONLY)

```text
docker ps             → only Harbor containers (harbor-jobservice, nginx, harbor-core, harbor-portal, redis,
                        harbor-db, registry, registryctl, harbor-log). No bootstrap/kind name.
docker ps -a | grep bootstrap|kind → none
kind get clusters     → no kind binary on this host
```

No `nkp delete bootstrap` needed.

### Prism Central, after

- VMs with prefix `skilltest-mgmt-01`: **0** (total VMs in PC: 3 = PC VM, BASTION, <ad-vm>). All 7 node VMs and their disks are gone.
- Volume groups whose `description` contains `skilltest-mgmt-01`: **3 — they stay.** Same names, same `extId`, unchanged description:

| VG name | extId (= former PV `volumeHandle`) | description |
|---|---|---|
| `pvc-f8f09787-82cc-4526-a059-9a315f4e86b6` | `da28b5cd-8cab-438c-550f-bf6a0f2541fa` | `FS:ext4, K8sClusterID:c374ed8a-f3bc-48b8-9fac-914cc76e5d1e, CSIVersion:v3.9.0, DeploymentType:non-bare-metal, CSI StorageClass nutanix-volume for skilltest-mgmt-01, PVC:helm-charts-pvc, NS:caren-system, POD:helm-repository-664b9d4664-nq2tt, SA:default` |
| `pvc-a7053e3c-a1cc-456e-98e8-5bd0695b0a84` | `597261aa-3180-441e-46ee-af4001673aa1` | `… CSI StorageClass nutanix-volume for skilltest-mgmt-01, PVC:git-operator-admin-volume, NS:git-operator-system, POD:git-operator-git-0, SA:default` |
| `pvc-6cb22f4e-8cb9-4cb5-96b2-8e4bf64c8a57` | `c4558e71-7e94-4159-79de-100936587a6d` | `… CSI StorageClass nutanix-volume for skilltest-mgmt-01, PVC:git-operator-git-volume, NS:git-operator-system, POD:git-operator-git-0, SA:default` |

  **P-11 answered for AHV: `nkp delete cluster` leaves the Nutanix CSI volume groups.** The 3 `<old-mgmt-cluster>` VGs that were present in the "before" snapshot disappeared during this window (17 → 14 VGs) and 2 floating IPs also went (50 → 48) — that is the other task of this session, not this delete. Not deleted by me.
- Floating IPs: **48** (all `fip-dummy-name`; earlier leftover). No FIP belongs to this cluster.
- `PRIMARY-IPAM` subnet `reserved-ips`: **0** (unchanged).
- VIPs released: `ping` → no reply for `<net>.50` (CP_VIP), `.51`, `.52` (MetalLB).
- `kubectl --kubeconfig ~/skilltest-mgmt-01.conf get nodes` → `Unable to connect to the server: context deadline exceeded` (kubeconfig dead, as expected).

## 5. D5 — operator host files

READ-ONLY list block (from `$HOME`), exact names only:

```text
-rw-------  nkp-skilltest-mgmt-01-create.sh       1146 B  Nov  3 13:24
-rw-------  skilltest-mgmt-01-dryrun.yaml        11951 B  Nov  3 13:27   (holds Secrets)
-rw-------  skilltest-mgmt-01.conf                5606 B  Nov  3 13:34
-rw-------  nkp-skilltest-mgmt-01.env              240 B  Nov  3 15:11
```

Not in the D5 list but of this cluster: `skilltest-mgmt-01-create.log` (6558 B), `skilltest-mgmt-01-delete.log` (1870 B). The patch, nodepool, nodepool-dryrun, inventory, and metallb-conf files never existed.

D5 CHANGES block (approved by the brief, step 5) → **RC=0**. After:

```text
~/nkp-bundle_v2.19.0_linux_amd64.tar.gz   (bundle, kept)
~/nkp-site.env        (kept, not touched)
~/nkp-v2.19.0/        (BUNDLE_DIR, kept)
~/cluster.yaml        (kept, not touched)
~/skilltest-mgmt-01-create.log
~/skilltest-mgmt-01-delete.log
```

No `<old-mgmt-cluster>` file was touched (its `.conf`/`.env` were already gone before this task).

**`~/nkp-site.env` now holds `MGMT_KUBECONFIG=/home/ubuntu/skilltest-mgmt-01.conf`, a deleted file.** Every later block that sources the site env fails with `context deadline exceeded` until a new management cluster is created and the line is updated. Not edited here (outside the task scope).

## Learnings

- `[nkp-skill nkp-cluster-lifecycle/references/delete.md D4]` **No expected output for D4.** D3 lists the workload-cluster output lines, but D4 says nothing about what the delete prints. Add the real D4 output, because a reader cannot tell a healthy run from a broken one: `Loading bootstrap image from archive…`, `Creating a bootstrap cluster…`, `Installing CAPI Stack operators…`, `Creating CAPI components…`, `Creating ClusterClass resources…`, `Creating NKPCluster resources…`, `Moving cluster resources…`, `Waiting for cluster in kommander/<name>`, `Deleting cluster resources for Cluster kommander/<name>`, `Deleted kommander/<name> cluster`, `Deleting bootstrap cluster…`, then `RC=0`.
- `[nkp-skill nkp-cluster-lifecycle/references/delete.md D4]` **Add the real duration.** Text says `--timeout 60m`, so a user waits an hour for a 5-minute delete (5 min 06 s here, 7 nodes, air-gapped with the bundle image). One line: "about 5–10 min on a 7-node AHV cluster; the phases with the longest time are the CAPI stack install (~1 min) and the pivot (~1.5 min)."
- `[nkp-skill nkp-cluster-lifecycle/references/delete.md D4]` The pivot writes `<cluster>-bootstrap.conf` in `$PWD` and prints its name. The file is removed with the bootstrap cluster, so the operator host is clean. The skill does not say this. Add: "the bootstrap kubeconfig and the bootstrap cluster both go away; if `$PWD/<cluster>-bootstrap.conf` stays, remove it."
- `[nkp-skill nkp-cluster-lifecycle/references/delete.md D4]` The bootstrap check says `docker ps` only. Change to `docker ps -a` (a stopped bootstrap container would be invisible to `docker ps`), and note that this lab host has no `kind` binary, so `kind get clusters` is not a usable check.
- `[nkp-skill nkp-cluster-lifecycle/references/delete.md D5]` **P-11 is answered — close it.** On AHV the cluster delete removes the VMs and their disks, and **leaves the Nutanix CSI volume groups**. Replace the "the user looks for those volume groups in Prism Central" text with a check the agent can run, and with the join key: the PV `spec.csi.volumeHandle` `NutanixVolumes-<uuid>` matches the VG `extId`, and the description holds `CSI StorageClass nutanix-volume for <cluster>`. A v4 API command for a PC skill: `list_all('/volumes/v4.0/config/volume-groups')`, then keep the entries whose `description` contains the cluster name. The same applies to D3's "leftovers after the delete: file `csi.md` C10".
- `[ntnx-skill nutanix-api]` No skill in `ntnx-skills` has a volume-group recipe or even the `/volumes/v4.0/config/volume-groups` path in its version map. I got the path from the task, not from a skill. A cluster delete or VM delete leaves volume groups behind, so add `volumes` (list, get, delete) to `nutanix-api` REFERENCE.md and one recipe.
- `[nkp-skill nkp-cluster-lifecycle/references/delete.md D5]` **The D5 file list misses the log files.** The delete is run in tmux with `>/tmp/<cluster>-delete.log` (the brief and skill `nkp-install` both tell you to log), and the create log is there too. Both stay in `$HOME` after D5. Add `"$HOME/$CLUSTER_NAME-create.log"` and `"$HOME/$CLUSTER_NAME-delete.log"` to the list and to the `rm`, or say "keep the delete log as evidence".
- `[nkp-skill nkp-cluster-lifecycle/references/delete.md D5]` The list block uses `"$PWD/$CLUSTER_NAME-dryrun.yaml"`. `PWD` is not fixed: the create wrote the file into the directory where the operator ran the create (`$HOME` in this run), and my `ssh 'bash -s'` happened to start in `$HOME`. If the operator runs the D5 block from another directory, the dry-run file with the Secrets is neither shown nor removed. Fix: list both `"$HOME/$CLUSTER_NAME-dryrun.yaml"` and `"$PWD/$CLUSTER_NAME-dryrun.yaml"`, and say "run this block from the directory where you ran the create".
- `[nkp-skill nkp-cluster-lifecycle/references/delete.md D5]` The final `rm` chain uses `... ${CLUSTER_KUBECONFIG:+"$CLUSTER_KUBECONFIG"} && rm -f -- "$HOME/nkp-$CLUSTER_NAME.env"`. With `&&`, a non-zero first `rm` leaves the env file (`rm -f` returns 0, so it is hidden, not harmless). Use `;` for the env-file step so the delete of the file that holds the names is not conditional on the earlier one.
- `[nkp-skill nkp-cluster-lifecycle/references/delete.md D5]` The last paragraph says to tell the user that `MGMT_KUBECONFIG` "points to a deleted cluster". Make it concrete and actionable: (1) the value in this run was `/home/ubuntu/skilltest-mgmt-01.conf`, which D5 had just removed, so every block that sources `~/nkp-site.env` fails with `Unable to connect to the server: context deadline exceeded`; (2) give the follow-up CHANGES line to write the new value after the next create, and say that no `kubectl` block works until then.
- `[fact]` The delete also frees `CP_VIP` and the MetalLB range: `ping` no reply for `<net>.50`, `.51`, `.52` after the delete. The D5 claim "The IPs `CP_VIP` and `LB_IP_RANGE` are free again" is correct.
- `[fact]` The management-cluster delete left no `NKPCluster` behind and no `Error` state object (there is no management cluster left to hold it), so D3's "delete the NKPCluster object" step does not apply to D4. D4 does not say that. One line would help.
