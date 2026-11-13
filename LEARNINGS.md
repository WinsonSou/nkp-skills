# Lab test 1 — learnings (for the retro)

Session 2026-11-03/04. Goal: deploy NKP 2.19.0 from scratch with only the skills (`nkp-skills` + `ntnx-skills`), and record each gap. Scrubbed: `<bastion>`, `<pc>`, `<registry-host>`, `<mgmt-subnet>`.

Tags: **[nkp-skill]** fix in this repo · **[ntnx-skill]** fix in `../ntnx-skills` · **[process]** test method · **[fact]** new live fact.

## Retro summary (read first)

**Outcome.** The skills took an agent from an empty site to a licensed Ultimate management cluster plus two workload clusters (one in a new workspace, one in a Flow VPC), and then deleted all of them. Executors: DeepSeek-V4.1-Flash, with Opus as the orchestrator. Every create and delete ended with RC=0. At the end PC had no NKP objects left (3 VMs, 11 PC-owned VGs, 48 old FIPs, `<vpc>` kept), and the bastion had only the site files.

| Cluster | Create | Delete | Notes |
|---|---|---|---|
| skilltest-mgmt-01 (Starter→key rejected) | 24 min | 5 min | license is bound to the cluster name |
| nkp-mgmt-01 (Ultimate trial) | 22.6 min (+11 min tier apps) | 7 min | 20 VGs / 340 Gi left behind |
| skilltest-wl-01 (new workspace) | 3.3 min (+ up to 38 min apps) | 57 s | 4 VGs left; workspace delete hung |
| skilltest-wl-02 (VPC, exposed) | 12.9 min | 28 s | N-41 = yes |

**Open items answered:** A-05 (item 26), P-11 (39, 71, 72), P-40 (45), N-41 (60), N-01 partly (64). **Still open:** P-07 (23), N-43 (64), A-06 (not tested: the mgmt cluster used a site mirror).

**Top fixes:** done in the lab test 1 fix pass (2026-11-04): `research/lab-runs-2026-11-03-fixes.md`, eval run and review in `evals/runs/2026-11-04-labtest1/`. The items below are the facts and process notes that stay for the NEXT-STEPS Carry-over (R6).

Per-task executor logs with more learnings: `research/raw/lab-runs/2026-11-03-test1/t1..t8-*.md` (each has a `## Learnings` section).

## Phase 0 — gather (read-only)

## Phase 1 — env files and checks

## Phase 2 — dry run


## Phase 3 — create

25. **[fact]** Create of 3 CP + 4 workers on a site mirror: 24 min (machines 6 min, pivot 8 min, Kommander 15 min). The 60m timeout was more than needed; 30m default would have passed, barely for the CAPI part only (the timeout covers which phase? not checked).
## Phase 4 — license

## Phase 5 — PC leftovers of the old cluster (lt1-api-3, details in `t1-pc-leftovers.md`)

## Phase 6 — delete the self-managed management cluster (lt1-test-3, details in `t2-delete-mgmt.md`)

## Phase 7 — management cluster nkp-mgmt-01 + license (lt1-build-1, details in `t3-mgmt-nkp-mgmt-01.md`)

44. **[fact]** Second create from scratch: dry run 3 min, create 22.6 min, RC=0. Verify + N6 all pass. The flow in `nkp-install` + `nutanix.md` N4C works end to end with only these site additions: `--insecure`, `--timeout 60m`.
## Phase 8 — workload cluster skilltest-wl-01 in a new workspace (lt1-build-2, details in `t4-wl-01.md`)

54. **[fact]** Ultimate workload cluster: 19 HelmReleases in the workspace namespace (no `kommander` ns), 16 AppDeployments (2 arrive late), 122 pods.
## Phase 9 — workload cluster skilltest-wl-02 in Flow VPC <vpc> (lt1-build-3, details in `t5-wl-02-vpc.md`)

59. **[fact]** Exposed workload cluster in a VPC, built from the bastion outside the VPC: create RC=0 in 12 min 53 s (1 CP + 4 workers). FIPs made with the ntnx-skills recipe (create + `PrivateIpAssociation` in one POST works).
## Phase 10 — delete workload cluster skilltest-wl-02 in the VPC (lt1-test-5, details in `t7-delete-wl-02-vpc.md`)

## Phase 11 — delete workload cluster skilltest-wl-01 + workspace (lt1-test-4, details in `t6-delete-wl-01.md`)

77. **[process]** Two workload deletes ran in parallel on one mgmt cluster without a conflict.
11. **[process]** The bastion keeps the old `cluster.yaml` (dry-run output of the earlier install). It was a fast source of the old values (VIP layout, image, mirror URL). A "from scratch" agent would not know it exists; I did not use it as the source for the new plan, only to cross-check.
