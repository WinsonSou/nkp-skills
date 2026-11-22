# Self-managed create on a site mirror — 2026-11-16 (NKP 2.19.1)

One self-managed cluster, created from scratch on a site registry mirror, with the default counts. Purpose: a deployment the user asked for, and a source of live facts for the skills. Scrubbed: `<net>`, `<registry-host>`, `<pc>`, `<ahv-cluster>`, `<poc-cluster>`.

Site values: `PE_CLUSTER=<ahv-cluster>`, `SUBNET=PRIMARY-IPAM`, `STORAGE_CONTAINER=SelfServiceContainer`, `VM_IMAGE=nkp-ubuntu-24.04-release-cis-1.36.2-20261026153223.qcow2`, `CP_VIP=<net>.30`, `LB_IP_RANGE=<net>.31-<net>.34`, NTP 2 servers, no `PC_PROJECT`, no proxy, no license, `--insecure`, 60m timeout. Flags of the create: `--self-managed` and a site mirror (case 4C), no `--airgapped`, no `--bundle`.

## Result

| Item | Value |
|---|---|
| NKP | 2.19.1 (`nkp version`: imagebuilder/kommander/konvoy all 2.19.1) |
| Kubernetes | 1.36.2, ClusterClass `nkp-nutanix-v2.19.1` |
| Nodes | 3 control plane + 4 workers, all `Ready` |
| Wall clock | 08:37:21 → 09:11:59 = **34 min 38 s**, `RC=0` |
| HelmReleases at the end | **26 / 26** Ready |
| Pods not `Running` or `Completed` | none |
| License | none (Starter) |
| Timeout used | `--timeout 60m`. 30m would have failed. |

## Phase durations [live 2.19.1]

Read from the create log. The bootstrap image is 3.4 GB.

| Phase | Duration |
|---|---|
| Load the bootstrap image from the archive | 49 s |
| Create the bootstrap kind cluster | 45 s |
| Install CAPI stack operators (bootstrap) | 61 s |
| Create CAPI components + preflight checks | ~2 min 33 s |
| Cluster infrastructure (7 VMs) | 1 min 50 s |
| Control planes ready | 4 min |
| CAPI stack operators + components on the new cluster, pivot | 3 min 32 s |
| Kommander install (Flux, 14 core apps) | 18 min 46 s |

The bootstrap kind cluster was on the operator host for 15 min of the 35.

## Learnings

1. **[fact] A registry host can answer `/v2/` while the project in `REGISTRY_URL` is empty.** The `mirror:` checks of N3 gave `200` and `mirror login: 200`. But `REGISTRY_URL` was `https://<registry-host>/<empty-project>`, and that Harbor project had **0 repositories** while `<seeded-project>` on the same host had **457**, public. The create would have failed at the first image pull. `GET /api/v2.0/projects?page_size=50` with the pull account gave `{"name": ..., "repo_count": ...}` for both projects. The seeded project had `mesosphere/kommander-*`, `cluster-api/*`, `cilium/*`, `calico/*`, `pause`. It had **no** repository with `konvoy` in the name, so `konvoy` is not a safe anchor for this check. [live 2.19.1] → `nkp-install` N3, `nkp-airgap` `references/nodes.md`.

2. **[fact] `nkp create cluster nutanix --self-managed --dry-run` is not a dry run.** It loaded the 3.4 GB bootstrap image (51 s), made a real kind bootstrap cluster (44 s), installed the CAPI stack operators (46 s), and was still in "Creating CAPI components" when a 240 s `timeout` killed it. Elapsed 4 min, not finished. Measured phases of the killed run: 08:32:51 image → 08:33:42 kind → 08:34:26 CAPI operators → 08:36:17 CAPI components → killed 08:36:51. The kill left `konvoy-capi-bootstrapper-control-plane` running in Docker and the `kind` network behind. [live 2.19.1] → `nkp-install` N4D. The skill said "about 3 min" and warned only about a dry run that *stops before the end*, not about a short `timeout` around it.

3. **[fact] Cleanup of a killed dry run:** `nkp delete bootstrap --kind-cluster-name konvoy-capi-bootstrapper --timeout 2m` removed the container in ~5 s. `konvoy-capi-bootstrapper` is the default name of the flag. The Docker network `kind` stays; it did no harm to the next create. `nkp get bootstrap` is not a command (`nkp get` has no `bootstrap`). [live 2.19.1]

4. **[fact] A `HelmRelease` that fails and then succeeds during a create is normal.** 13 of 14 core apps were Ready at 09:06:54; `traefik-forward-auth-mgmt` was the last one. Its conditions: `Ready=False InstallFailed`, message `Helm install failed for release kommander/traefik-forward-auth-mgmt with chart traefik-forward-auth@0.3.10: timeout waiting for: [Deployment/kommander/traefik-forward-auth-mgmt status: 'InProgress']`, then `Remediated=True UninstallSucceeded`. Flux installed it again and the Deployment was `1/1` in 2 min 28 s; the create ended `RC=0` with 26/26 Ready. The pod was `ContainerCreating` the whole time, with event `Pulling image "mesosphere/traefik-forward-auth:v3.3.1"`, on a fast mirror. After the remediation the Deployment does not exist, so `kubectl get deploy traefik-forward-auth-mgmt` prints **NotFound** — that is not a second fault. [live 2.19.1] → `nkp-troubleshooting` `references/flux.md` F3.

5. **[fact] The create does not reserve `CP_VIP` or `LB_IP_RANGE` in IPAM, and it does not warn about the pool size.** The 7 nodes took `<net>.92`, `<net>.144`, `<net>.168`, `<net>.173`, `<net>.188`, `<net>.208`, `<net>.215` from `PRIMARY-IPAM` — far outside the `.81`–`.120` pool recorded on 2026-11-04, so the pool is much wider than that note says. `CP_VIP` `<net>.30` is in the same `/24` and is not reserved. A later cluster can take it, and the API endpoint of this cluster then stops. Before the create: ping no reply, `ip neigh` `INCOMPLETE` for `<net>.30` and `<net>.31`. [live 2.19.1] → `nkp-install` N1 "IP plan", open item N-51.

6. **[fact] Default counts and their footprint.** 3 control plane (4 vCPU, 16 GiB, 80 GiB disk) + 4 workers (8 vCPU, 32 GiB, 80 GiB disk) = **44 vCPU, 176 GiB RAM, 560 GiB disk**. The PE had 3 hosts × 40 cores and 2643 GiB RAM, with 46 powered-on VMs already holding 406 vCPU and 1284 GiB. The create made no capacity message. After it: 450 vCPU and 1460 GiB (55 % of the RAM). A default create on a full PE has no documented pre-check. [live 2.19.1] → `nkp-install` N1 "Node size" and N3, open item P-57.

7. **[fact] Prism v3 API traps that cost time in the read-only preflight** (companion `nutanix-*` skills):
   - `POST /api/nutanix/v3/vms/list` ignores a `filter` of `power_state==ON`. All 46 entities come back and each one has to be filtered in code on `spec.resources.power_state`. [live 2.19.1]
   - `hosts/list` returns one entity whose `status.resources` has **no** `num_cpu_cores` (it holds `serial_number`, `controller_vm`, `block`) — a loop over `entities[].status.resources` crashes on it. Skip the entities without `num_cpu_cores`. Host memory is `memory_capacity_mib` (not `memory_capacity_in_bytes`), cores are `num_cpu_cores`; `cpu_capacity_hz` was `None` on this PC. [live 2.19.1]
   - `clusters/list` on PC 7.5.2 gives no `stats` for either cluster, so it cannot be used for a capacity read. [live 2.19.1]
   - The images list of a 30 GiB disk image is one entity; the name match has to be exact, `.qcow2` included.

8. **[fact] `nkp get clusters` fails on a self-managed cluster without a workspace:** `ERR err="failed to determine target namespace: please provide the name of the targeted Workspace"`. `kubectl get clusters -A` works. [live 2.19.1] → `nkp-platform-apps-gitops`.

9. **[fact] `nkp version` is the version source, not the bundle file name.** The site notes said a 2.19.0 bundle; `nkp version` reported 2.19.1 for imagebuilder, kommander, and konvoy, and the ClusterClass was `nkp-nutanix-v2.19.1`. [live 2.19.1]

10. **[fact] Small things:** the dashboard URL is the first IP of `LB_IP_RANGE` (`https://<net>.31/dkp/kommander/dashboard`) and gives `302` when it is healthy; `nkp get dashboard --kubeconfig` prints the generated admin user and password. `kubectl version -o short` is invalid (only `yaml` or `json`). The create printed `EXIT=` once, into the log file.

## Not tested

- A create on a PE with no free memory, to see the failure and whether a pre-check exists (P-57).
- Whether `--skip-preflight-checks` names a capacity check.
- A second cluster that takes a VIP while the first one holds it (the IPAM collision of item 5).

## Delete run (same day, 2026-11-16)

The user asked for the delete after the create. Command, in tmux on the operator host:

```bash
nkp delete cluster --self-managed --cluster-name "$CLUSTER_NAME" --namespace kommander \
  --kubeconfig "$HOME/$CLUSTER_NAME.conf" \
  --bootstrap-cluster-image "$HOME/konvoy-bootstrap-image-v2.19.1.tar" --timeout 60m
```

| Item | Value |
|---|---|
| Wall clock | 13:56:08 → 14:05:12 = **9 min 4 s**, `RC=0` |
| Phases | image 50 s, kind 45 s, CAPI stack operators 61 s, CAPI components ~2 min 44 s, CAPI move to bootstrap + delete resources, "fully deleted" 3 min 35 s, bootstrap delete |
| VMs in Prism Central | 53 → 46 (the 7 of the cluster, no more) |
| Volume groups | 114 → 114 (none left) |
| `CP_VIP` / `LB_IP_RANGE` | no `ping` reply, `curl` `000` on both |
| Other clusters | `wskn-nkp-mgmt` and its workload cluster not touched: both `Provisioned`, 7 of 7 nodes `Ready` |

## Delete learnings

11. **[fact] A self-managed delete takes the kubeconfig of the cluster itself.** `~/nkp-site.env` had `MGMT_KUBECONFIG` pointing at the **other** management cluster of the site. `--kubeconfig` must be the cluster's own file (`~/<poc-cluster>.conf`) and the namespace is `kommander` on that same cluster. A block that sources `~/nkp-site.env` and then uses `$MGMT_KUBECONFIG` targets the wrong cluster. `delete.md` line 141 does exactly that, so it needs a self-managed variant. [live 2.19.1]

12. **[fact] 0 volume groups stayed, but this does not test the D5 note.** The cluster had 21 PVCs at delete time and the total count of volume groups was 114 before and 114 after. The CSI never bound the PVCs (the `nutanix-csi-node` pods were erroring during the pivot), so there was no PV. The "Starter management cluster leaves 3 volume groups" line of `delete.md` D5 is neither confirmed nor contradicted. [live 2.19.1]

13. **[fact] The ARP cache lies about a freed VIP.** Immediately after `RC=0`, `ping` of `<net>.30` and `<net>.31` got no reply, but `ip neigh` showed a `lladdr` for both (two different Nutanix MACs) in state `DELAY`. No VM in Prism Central held either MAC. After `ip neigh del <ip> dev <nic>` and a new `ping`, both entries were `INCOMPLETE`. A free-IP check that reads `ip neigh` without the flush before it can report a freed VIP as taken. Same false positive as lab run 1 (L-01, `lab-runs-2026-11-03-fixes.md`). [live 2.19.1]

14. **[fact] No leftovers:** no CAPI `Cluster`, no `NKPCluster`, no VM, no bootstrap container, no tmux session. [live 2.19.1]
