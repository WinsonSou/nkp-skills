# T5 — `t5-delete-flow-a`: delete workload cluster `skilltest-flow-a` and all its leftovers

Executor `lt2-build-3`. Date 2026-11-04. NKP 2.19.0. Task `t5-delete-flow-a`.
Site user's request: "We are done with the workload cluster `skilltest-flow-a` (Flow CNI, in workspace `skilltest-flow`, on management cluster `nkp-mgmt-01`). Please delete it completely: the cluster and everything it leaves behind on the management cluster, in Prism Central, and on the operator host. Keep `nkp-mgmt-01`, the workspace `skilltest-flow`, the site file, and the Flow CNI images in Harbor. Tell us exactly what stayed after the delete before you clean it up."

Skills used, in order: router `skills/nkp/SKILL.md` → `nkp-cluster-lifecycle` (step 1, step 2) → `references/delete.md` (D1, D2, D3, D5, D5.1–D5.4) → `nkp-flow-cni` SKILL "What changes on a Flow CNI cluster" (delete item, N-36) → `ntnx-skills` `nutanix-nkp` RECIPES "Leftover audit for a cluster" (D5.2 step 4).
Earlier notes of this site: `t1-preflight.md`, `t2-mgmt.md`, `t3-flow-a.md`.

Standing order from the user (offline tonight): the plans are approved; write each plan in this log **before** the block runs; stop only for something outside this request.

Hard rules applied: `timeout` + keepalive flags on every ssh; `--request-timeout=30s` on every kubectl read; `sleep` as its own call (≤120 s); the delete runs in tmux with a log; no secret printed; no finalizer removed.

## Block 01 — `01-state.sh` (D1 + D2 + the objects of the workspace namespace)

READ-ONLY. Findings:

```
vars: all six set (CLUSTER_NAME WORKSPACE_NS CP_VIP LB_IP_RANGE CLUSTER_KUBECONFIG MGMT_KUBECONFIG)
nkpclusters -A: kommander/nkp-mgmt-01 Reconciled  (92m)
                skilltest-flow-dw97w/skilltest-flow-a v2.19.0 v1.36.2 Reconciled  (32m)
D1: MGMT=<none> -> workload cluster -> D2
nodes 7 Ready (3 control-plane + 4 workers md-0)
pvcs 6 Bound, all nutanix-volume: 3 x flow-cni-system/flow-cni-nats-js-* (1Gi),
      skilltest-flow-dw97w/db-prometheus-...-0 (100Gi), kube-prometheus-stack-grafana (10Gi), opencost-pvc (10Gi)
pvs 6, HANDLE NutanixVolumes-<uuid> for each
LB services:1 -> skilltest-flow-dw97w/kommander-traefik EXTERNAL-IP <net>.61
child clusters: `error: the server doesn't have a resource type "nkpclusters"` -> pass case
HCPs in the workspace ns: skilltest-flow-a-flow-cni (the path A user HCP) + 7 CAAPH addon HCPs (cosi-controller-*,
      konnector-agent-*, metallb-*, node-feature-discovery-*, nutanix-ccm-*, nutanix-csi-*, snapshot-controller-*)
HRPs: 8, all Ready True, cluster skilltest-flow-a
Secrets in the workspace ns for this cluster: skilltest-flow-a-{8ng86-kcvfr,8ng86-p479v,8ng86-vkp4f,md-0-q5pjg-264ln-*}
      (CAPI per-machine), -ca, -etcd, -kubeconfig, -proxy, -sa, -encryption-config, -pc-credentials,
      -pc-credentials-for-ccm, -pc-credentials-for-csi, -pc-credentials-for-konnector-agent,
      -image-registry-mirror-credentials, -nkp-oci-proxy-ca, -static-credential-provider-response,
      -oci-cert, -oci-creds
operator host files: nkp-skilltest-flow-a-create.sh, skilltest-flow-a-dryrun.yaml,
      skilltest-flow-a-dryrun.yaml.orig, skilltest-flow-a-flow-cni-hcp.yaml, skilltest-flow-a-smoke.yaml,
      skilltest-flow-a.conf, nkp-skilltest-flow-a.env   (7 files, all in $HOME = $PWD = /home/ubuntu)
```

- D2 safety gate: no child NKPCluster, no PVC that the user wants to keep (the site user asked for a complete delete), and the user named this exact cluster. Pass.
- `.orig` (the `yq` edit copy) and `-smoke.yaml` (the day-1 smoke test manifest) are **not** in the D5.4 file list; the D5.4 "grep the name" fallback found them.

## Block 02 + 03 — `02-pc-audit.py`, `03-pc-categories.py` (D5.2 step 1 + nutanix-nkp "Leftover audit")

READ-ONLY, runs on this laptop with the `ntnx` client (brief: the client runs here).

```
VMs in PC: 17, 7 with the `skilltest-flow-a` prefix, all powerState ON, all on PE cluster 00065ef1-...
volume groups in PC: 37, 6 with `for skilltest-flow-a,` and K8sClusterID 6e694f3b-... , each with 1 vm-attachment
     (the 6 are the D2 PV list; 37 - 6 = 31 must stay)
VPCs: 1 (<lab-vpc> — a lab object, not NKP), nothing named after the cluster
floating IPs: 48 x fip-dummy-name, all NOT_ASSOCIATED -> none belongs to this cluster
IP reservations: none with the cluster name in clientContext
categories: KubernetesClusterName=skilltest-flow-a (7 VMs) and KubernetesClusterUUID=k8s-6e694f3b-...
     (0 VMs); both made by NKP for this cluster.
     Also present (older lab tests, NOT mine): KubernetesClusterName=skilltest-mgmt-01, =<mgmt-cluster>,
     and 5 other KubernetesClusterUUID values.
```

**N-36 is answered for the Prism Central side: the Flow CNI cluster leaves no VPC and no floating IP in Prism Central.** The only PC objects are the 6 volume groups and the 2 categories.

## Plan (written before the run, per the user's standing order)

1. **Delete the cluster** — `nkp delete cluster --cluster-name skilltest-flow-a --namespace skilltest-flow-dw97w --kubeconfig "$MGMT_KUBECONFIG" --timeout 30m`, in tmux, log `~/nkp-skilltest-flow-a-delete.log`. Target: the workload cluster on management cluster `nkp-mgmt-01`. Result: 7 VMs and their disks gone, all pods and the LB service `<net>.61` gone.
2. **Verify**: no NKPCluster/CAPI Cluster/Machine, `<net>.60` and `<net>.61` answer nothing.
3. **Report what stayed** (the user's explicit request) — read-only inventory of the management cluster, Prism Central and the operator host. No cleanup before this report.
4. **Clean up**, in the D5 order that the skill gives:
   - D5 / `nkp-flow-cni`: the path A HelmChartProxy `skilltest-flow-a-flow-cni` (N-36).
   - D5.1: the mirror Secrets `skilltest-flow-a-oci-cert` and `skilltest-flow-a-oci-creds`.
   - D5.1 extended by this run: every other `skilltest-flow-a*` Secret that stays in the workspace namespace (report first, then delete only the ones that belong to this cluster; never a workspace-level Secret).
   - D5.2: the 6 volume groups of the D2 PV list, by extId (the PVC data goes).
   - PC categories of this cluster: `KubernetesClusterName=skilltest-flow-a`, `KubernetesClusterUUID=k8s-6e694f3b-...` — only after the VMs are gone (report first).
   - D5.4: the 7 operator-host files (the 4 that D5.4 names plus `.orig`, `-smoke.yaml`, and `-flow-cni-hcp.yaml`).
5. **Keep** (told to stay): `nkp-mgmt-01`, workspace `skilltest-flow` + its namespace `skilltest-flow-dw97w`, `~/nkp-site.env`, the Flow CNI images and chart in the site mirror, the `nkp-mgmt-01` env file, the VM image, the older lab leftovers (`skilltest-mgmt-01`, `<mgmt-cluster>` categories, `<lab-vpc>`).

## Block 04 + 05 — `04-delete-cluster.sh`, `05-delete-log.sh` (D3)

```
15:58:16 start, tmux nkp-skilltest-flow-a-delete
15:58:17 INF  • Deleting cluster resources for Cluster skilltest-flow-dw97w/skilltest-flow-a...
          ✓ Deleting cluster resources for Cluster skilltest-flow-dw97w/skilltest-flow-a
15:58:17 INF  • Waiting for cluster to be fully deleted...
16:00:20        ✓ Waiting for cluster to be fully deleted
16:00:20 INF Deleted skilltest-flow-dw97w/skilltest-flow-a cluster     RC=0
```

**2 min 4 s** for 7 nodes with 6 PVCs. The skill says 57 s for 7 nodes with PVCs; the Flow CNI cluster is twice that, and the whole time sits in "Waiting for cluster to be fully deleted" (the VMs are deleted one by one). `nkp delete cluster` printed neither "Deleting Services with type LoadBalancer" nor "Deleting ClusterResourceSets" (D3 says not to wait for them).

## Block 06 — `06-after.sh` (D3 check blocks + what stays)

```
D3 check: "No resources found in skilltest-flow-dw97w namespace" (nkpclusters,clusters.x-k8s.io,machines with the cluster label)
          nkpcluster skilltest-flow-a -> NotFound
CP VIP: ping 2/2 lost, cp_vip_https=000
LB first IP <net>.61: lb_first_ip=000
workspace ns HCP: skilltest-flow-a-flow-cni   True   InfoReported        <- STAYS
workspace ns HRPs: "No resources found"                              <- all 8 gone
workspace ns Secrets with the name: skilltest-flow-a-oci-cert, skilltest-flow-a-oci-creds   <- STAY
all-ns grep for the name: configmap/kube-oidc-proxy-skilltest-flow-a (10m),
                          configmap/traefik-forward-auth-kommander-skilltest-flow-a (10m)  <- STAY
operator host files: 8 (the 7 of block 01 + nkp-skilltest-flow-a-delete.log)
kept as told: nkp-mgmt-01 Reconciled, workspaces (default, kommander, skilltest-flow), ns skilltest-flow-dw97w Active
```

## Block 07 + 08 — `07-configmaps.sh`, PC audit again

```
the two configmaps: ownerReferences <none>, no kustomize.toolkit.fluxcd.io/name label, created 15:51:53Z
kustomizations in the workspace ns: only workspace-tls-root-ca (79m) — it does not render these two
```

Prism Central after the delete (the `02-pc-audit.py` run again):

```
VMs: 10 in PC (was 17), 0 with the cluster prefix           -> the 7 node VMs are gone
volume groups: 37 (unchanged), 6 of the cluster, attachments 0  -> the 6 stay, unattached (D5.2 as documented)
VPC: 1 (<lab-vpc>, not this cluster); floating IPs: 0 for the cluster; IP reservations: 0
categories: KubernetesClusterName=skilltest-flow-a and KubernetesClusterUUID=k8s-6e694f3b-... are GONE
            (Prism Central dropped both when the 7 VMs went; nothing to delete)
```

# What stayed after the delete (the report the user asked for, written before any cleanup)

**Management cluster `nkp-mgmt-01`, namespace `skilltest-flow-dw97w` — 5 objects:**

| # | Object | In the skill? |
|---|---|---|
| 1 | `helmchartproxy/skilltest-flow-a-flow-cni` (the path A Flow CNI HCP) | yes, `nkp-flow-cni` "Delete", N-36; `delete.md` D5 |
| 2 | `secret/skilltest-flow-a-oci-cert` | yes, D5.1 |
| 3 | `secret/skilltest-flow-a-oci-creds` | yes, D5.1 |
| 4 | `configmap/kube-oidc-proxy-skilltest-flow-a` | **no** — not in D5 |
| 5 | `configmap/traefik-forward-auth-kommander-skilltest-flow-a` | **no** — not in D5 |

**Prism Central — 6 objects:** the 6 CSI volume groups of the PVCs (`pvc-f7289742…`, `pvc-80ea7f7f…`, `pvc-43b46210…`, `pvc-6cf30696…`, `pvc-015a25e1…`, `pvc-45aefe76…`, extIds in block 02), 3 × 1 GiB (Flow CNI NATS), 100 GiB prometheus, 10 GiB grafana, 10 GiB opencost. All with `vm-attachments: 0`. The PVC data goes with them. Documented in D5/D5.2.
No VPC, no floating IP, no IP reservation, no category, no image: **nothing else stays in Prism Central.**

**Operator host (all in `/home/ubuntu`) — 8 files:** `nkp-skilltest-flow-a-create.sh`, `nkp-skilltest-flow-a.env`, `skilltest-flow-a.conf`, `skilltest-flow-a-dryrun.yaml`, `skilltest-flow-a-dryrun.yaml.orig`, `skilltest-flow-a-flow-cni-hcp.yaml`, `skilltest-flow-a-smoke.yaml`, `nkp-skilltest-flow-a-delete.log`. D5.4 names 4 of them; `.orig`, `-flow-cni-hcp.yaml` and `-smoke.yaml` are found only by the D5.4 name-grep fallback.

**Gone, as the skills say:** the NKPCluster, the CAPI Cluster, all Machines and MachineDeployments, the 7 node VMs and their disks, all per-machine and bootstrap Secrets, the 5 `-pc-credentials*` Secrets, `-image-registry-mirror-credentials`, `-nkp-oci-proxy-ca`, `-static-credential-provider-response`, the 8 HelmReleaseProxies, the 7 CAAPH addon HCPs, the LoadBalancer service (`<net>.61`), the kubeconfig Secret. The CP VIP `<net>.60` and the LB IP `<net>.61` answer nothing.

## Cleanup plan (approved standing order; written before the run)

1. Block 09 (CHANGES, management cluster): delete, in the workspace namespace `skilltest-flow-dw97w`: the HCP `skilltest-flow-a-flow-cni`, the Secrets `skilltest-flow-a-oci-cert` and `skilltest-flow-a-oci-creds`, the ConfigMaps `kube-oidc-proxy-skilltest-flow-a` and `traefik-forward-auth-kommander-skilltest-flow-a`. Undeleteable, per-cluster, no data: the ConfigMaps hold one kube-oidc-proxy / traefik-forward-auth TLS settings key each and no Secret.
2. Block 10 (CHANGES, Prism Central): delete the 6 volume groups by extId, with a fresh ETag and after re-proving `vm-attachments: 0`; the PVC data goes. No other PC object is touched (no category remains, and `<lab-vpc>`, the 48 `fip-dummy-name` FIPs and the older `skilltest-mgmt-01`/`<mgmt-cluster>` categories are not this cluster's).
3. Block 11 (CHANGES, operator host): remove the 8 files of the cluster; the env file goes last (`;`, not `&&`).
4. Block 12 (READ-ONLY): prove the end state on all three sides.
5. Never touched: `nkp-mgmt-01`, the workspace `skilltest-flow` and its namespace, `~/nkp-site.env`, `~/nkp-nkp-mgmt-01.env`, the site mirror (the 4 Flow CNI repositories and the chart stay), the VM image, `<lab-vpc>`.

## Cleanup blocks and results

### Block 09 — `09-mgmt-cleanup.sh` (management cluster objects)

```
helmchartproxy.addons.cluster.x-k8s.io "skilltest-flow-a-flow-cni" deleted from skilltest-flow-dw97w namespace
secret "skilltest-flow-a-oci-cert" deleted from skilltest-flow-dw97w namespace
secret "skilltest-flow-a-oci-creds" deleted from skilltest-flow-dw97w namespace
configmap "kube-oidc-proxy-skilltest-flow-a" deleted from skilltest-flow-dw97w namespace
configmap "traefik-forward-auth-kommander-skilltest-flow-a" deleted from skilltest-flow-dw97w namespace
after: "No resources found in skilltest-flow-dw97w namespace."
```

(My own `kubectl get helmchartproxy X secret Y …` display line in that block is wrong — kubectl reads only the first word as a type; use `type/name` for a mixed list. The deletes themselves worked.)

The two ConfigMaps had **no owner reference, no Flux label** (block 07) and hold one settings key each, no Secret. They were created at 15:51:53Z by the workspace AppDeployments (kube-oidc-proxy and traefik-forward-auth were deployed 8 min before the delete) and they were not removed by the cluster delete.

### Block 10 — `10-vg-delete.py` (D5.2, the 6 volume groups)

```
before: 37 volume groups in PC
each target: `for skilltest-flow-a,` True, attachments 0  -> delete -> get 404
pvc-f7289742…, pvc-80ea7f7f…, pvc-43b46210…, pvc-6cf30696…, pvc-015a25e1…, pvc-45aefe76…
after: 31 volume groups in PC
```

Every target was re-proved before the delete: `for skilltest-flow-a,` in the description and `vm-attachments: 0`. Nothing else was touched.

### Block 11 — `11-host-files.sh` (D5.4, the 8 operator-host files)

```
removed: nkp-skilltest-flow-a-create.sh (1109 B), skilltest-flow-a-dryrun.yaml (11188 B),
         skilltest-flow-a-dryrun.yaml.orig (10924 B), skilltest-flow-a-flow-cni-hcp.yaml (749 B),
         skilltest-flow-a-smoke.yaml (892 B), skilltest-flow-a.conf (5602 B),
         nkp-skilltest-flow-a-delete.log (391 B), nkp-skilltest-flow-a.env (249 B)
name grep on $HOME afterwards: no line
kept: nkp-site.env (1045 B, 21 lines, mtime 15:17 — unchanged), nkp-nkp-mgmt-01.env (228 B), nkp-mgmt-01.conf (5562 B)
```

The env file went last (`;`, per D5.4), and `CLUSTER_KUBECONFIG` (`~/skilltest-flow-a.conf`) is not `MGMT_KUBECONFIG`, so the management kubeconfig was not touched.

### Block 12 + 13 — `12-final.sh`, `13-pc-final.py` (prove the end state)

```
nkpclusters: kommander/nkp-mgmt-01 v2.19.0 v1.36.2 Reconciled      (100m)
mgmt nodes Ready: 7
workspaces: default-workspace, kommander-workspace, skilltest-flow -> skilltest-flow-dw97w
skilltest-flow-dw97w objects left: karma-traefik-certs-skilltest-flow-dw97w-cert-federation,
     prometheus-traefik-certs-skilltest-flow-dw97w-cert-federation (Deployments, 81m — workspace level),
     kommander-karma-server-tls, kommander-thanos-server-tls, tls-root-ca, 2 helm release Secrets,
     kube-root-ca.crt
all-ns grep for `skilltest-flow-a` on the management cluster: no line
Prism Central: 10 VMs (0 with the prefix), 31 volume groups, 1 VPC (<lab-vpc>, not this cluster),
     0 floating IPs, 0 IP reservations, 0 categories
mirror (read-only token + tags/list): nutanix/nutanix/flow-cni 200, nutanix/nutanix/flow-container-security 200,
     nutanix/nutanix/flow-ovn-kubernetes 200, nutanix/nutanix-flow-cni (chart) 200
```

## Learnings

### L-01 `[nkp-skill nkp-cluster-lifecycle/references/delete.md D5]` — the leftover list misses the per-cluster ConfigMaps of the workspace apps

D5 lists the HCP (via `nkp-flow-cni`), the 2 mirror Secrets, the volume groups, the VPC objects, the Metal hosts and the operator-host files. After this delete **two more objects stayed** in the workspace namespace:

```
configmap/kube-oidc-proxy-skilltest-flow-a
configmap/traefik-forward-auth-kommander-skilltest-flow-a
```

Both are rendered by the workspace AppDeployments for each cluster of the workspace, both have **no owner reference** (so no garbage collection) and no Flux label, and they hold one settings key each and no Secret. `kubectl get cm,secret -A | grep <cluster>` is what finds them. An executor who follows D5 alone reports "done" and leaves them.

Proposed fix, in D5 "What stays" after the mirror Secrets:

> - **Per-cluster ConfigMaps and Secrets of the workspace apps.** In the workspace namespace, `<app>-<cluster>` (seen on 2.19.0: `kube-oidc-proxy-<cluster>`, `traefik-forward-auth-kommander-<cluster>`). They have no owner reference, so the delete does not remove them. Find them with `kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get cm,secret | grep -F -- "$CLUSTER_NAME"`; the rows of the workspace itself (`tls-root-ca`, `kommander-*-tls`, `sh.helm.release.*`) stay. Delete the rest in D5.1.

### L-02 `[nkp-skill nkp-cluster-lifecycle/references/delete.md D5.4]` — 3 of the 8 files of a Flow CNI cluster are not in the file list, and the rule says not to remove them

D5.4 names `-create.sh`, `-patch.json`, `-nodepool.sh`, `-nodepool-dryrun.yaml`, `-inventory.yaml`, `-dryrun.yaml`, `-dryrun.err`, `-metallb-conf.yaml`, `-bootstrap.conf`, `-create.log`, `-delete.log`, the kubeconfig and the env file. This flow also left:

```
skilltest-flow-a-dryrun.yaml.orig        (the copy that nkp-flow-cni install.md I3 makes before the yq edit)
skilltest-flow-a-flow-cni-hcp.yaml       (the path A HelmChartProxy file, install.md I4)
skilltest-flow-a-smoke.yaml              (any test manifest the user asked for)
```

The second command (the name grep) finds them, but the rule under it is "Remove such a file only when the user names it", so a complete delete needs the user to name files the user cannot know about.

Proposed fix: add the three names to the D5.4 list and to the `rm` block, and change the rule to: "the name grep finds the files that this list does not name. Remove one when it is of this cluster (the full cluster name is in the file name) and show it in the plan; keep it when the name of another cluster is in it (`dev-01` / `dev-010`)."

### L-03 `[nkp-skill nkp-flow-cni/SKILL.md "What changes on a Flow CNI cluster", delete item]` — N-36 is answered: no Prism Central object stays

The skill asks "whether the HCP and the Prism Central objects of the cluster (the Shared Services VPC) stay". Measured on 2.19.0 with Flow CNI 1.1.0:

- the HCP stays (as the skill says) and is removed with one `kubectl delete helmchartproxy`;
- **no VPC, no subnet, no floating IP, no IP reservation and no category stays** in Prism Central. The VPC list before and after holds the same single lab VPC that existed before the create; the audit found 0 floating IPs and 0 reservations with the cluster name; PC removed both categories (`KubernetesClusterName=skilltest-flow-a`, `KubernetesClusterUUID=k8s-6e694f3b-…`) when the 7 VMs went.

Proposed fix: replace the UNKNOWN with "Measured 2.19.0: the delete leaves the HCP only. It leaves no VPC, subnet, floating IP, IP reservation or category in Prism Central. Check the VPC list anyway when the user says the cluster was in a VPC (skill `nkp-vpc`)."

### L-04 `[fact]` — the categories of the deleted cluster go by themselves; older leftovers do not

After the 7 VMs were deleted, both `KubernetesClusterName=skilltest-flow-a` and `KubernetesClusterUUID=k8s-6e694f3b-…` were gone with no command of mine. Two older lab leftovers persist with 0 VMs (`KubernetesClusterName=skilltest-mgmt-01`, `=<mgmt-cluster>`), so this is **not** a simple Prism Central garbage collection of unused values, and the cause is not proven. Practical rule for the delete: do not plan a category delete; run the `nutanix-nkp` "Leftover audit" **after** the delete and clean only the rows it still shows.

### L-05 `[fact]` — timings, and the counts a delete recipe should expect

- `nkp delete cluster` on this cluster: **2 min 4 s** (15:58:16 → 16:00:20), 7 nodes, 6 PVCs, Flow CNI. The skill says 57 s for 7 nodes with PVCs; the whole extra time is "Waiting for cluster to be fully deleted". Both guide print lines (LoadBalancer, ClusterResourceSets) were absent again, and the LoadBalancer IP `<net>.61` and the VIP `<net>.60` answered nothing afterwards (`curl` 000).
- What the delete removed by itself on the management cluster: the NKPCluster, the CAPI Cluster, 7 Machines, 4 MachineDeployments, 8 HelmReleaseProxies, the 7 CAAPH addon HCPs, and **14 of the 19 Secrets** of the cluster — including the 5 `-pc-credentials*`, `-image-registry-mirror-credentials`, `-nkp-oci-proxy-ca` and `-static-credential-provider-response`. Only `-oci-cert` and `-oci-creds` stayed, exactly as D5.1 says. So the later worry of `t3-flow-a` L-… ("do the 5 pc-credentials Secrets stay?") is answered: no.
- Prism Central: 17 → 10 VMs, 37 → 37 volume groups (the 6 of the cluster stay, unattached, as D5 says), then 37 → 31 after D5.2.
- The Flow CNI cluster had removed the L-07 workaround: `kube-system/registry-hosts-fix` went with the cluster, no separate delete was needed.

## Status

`done`. `skilltest-flow-a` is deleted on all three sides and nothing of it remains:

- management cluster: no NKPCluster, CAPI Cluster, Machine, HelmChartProxy, HelmReleaseProxy, Secret or ConfigMap with its name in any namespace. The HCP, the 2 mirror Secrets and the 2 per-cluster ConfigMaps are removed. `nkp-mgmt-01` (Reconciled, 7 nodes Ready) and the workspace `skilltest-flow` (`skilltest-flow-dw97w`) stay, with only their own objects.
- Prism Central: 0 VMs, 0 of its 6 volume groups (PVC data gone), 0 floating IPs, 0 IP reservations, 0 categories, no VPC.
- operator host: 0 files. `~/nkp-site.env` (unchanged), `~/nkp-nkp-mgmt-01.env` and `~/nkp-mgmt-01.conf` stay.
- site mirror: the 4 Flow CNI repositories answer 200; nothing was pushed or removed (this task did no `docker`, `curl` write, or registry change).

No secret printed, no finalizer removed, no skill file edited, nothing committed.
