# Batch 2 review 1: nkp-upgrade, nkp-troubleshooting

Reviewer: Opus, fresh read-only session, 2026-11-02. Scope: commits 6cb9659..f26e184. I changed no repo file except this one. Scratch files are in `/tmp/rvb2`.

What I did:
- `python3 scripts/check_skills.py --self-test && python3 scripts/check_skills.py`: both pass (`6 skills checked, 0 errors`).
- `bash -n` on all 70 command blocks in scope: no syntax errors. Every block has a mark on line 1 and the correct `source … 2>/dev/null` on line 2 (script `/tmp/rvb2/blocks.py`).
- Every `nkp` flag: compared with `nkp-help-upgrade.txt`, `nkp-help-ops.txt`, `nkp-help-lifecycle.txt`, `nkp-help.txt`.
- Every `[pdf p.N]` tag in both skills: I printed the page (`/tmp/rvb2/pg.sh N`) and found the claim.
- I tested the jsonpath, awk, and jq filters with sample objects (`kubectl --local`, `jq 1.7`).
- Lab, read-only (`get`, `explain`, `--help`) to settle facts: label selectors, HelmRelease source kinds, CRD versions, and `--disable-appdeployments`. Commands and results are in the findings. I read no Secret.

**Verdict: go-with-changes.** 0 BLOCKER, 6 MAJOR, 15 MINOR.

The upgrade order, the version path, and the gates match the guide. `--workspace` (not `--namespace`) on `nkp upgrade platform-apps` is correct and has good live evidence. `nkp diagnose` is CHANGES. The finalizer removal (D5) is well gated: 4 written conditions, a warning, "yes" plus the object name, one index with a `test` op, and bottom-up order. The main defects are three check commands that hide the failure that they look for (M1, M2, M3), and one Done-when that cannot become true on a dark site (M4).

## 1. BLOCKER

None.

## 2. MAJOR

**M1. Rung 1 hides the CAPI conditions that are `False`, which are the failures.**
- File: `skills/nkp-troubleshooting/SKILL.md:86`, and the text at `:89-90`.
- Problem: the filter `.status.capiCluster.conditions[?(@.status!="False")]` prints only `True` and `Unknown`. A failed positive condition (`Available=False`, `TopologyReconciled=False`, `InfrastructureReady=False`) is not printed. Line 90 tells the agent to read the `TopologyReconciled` message, but the block never shows it.
- Evidence: test object with `Available=False`, `TopologyReconciled=False`, `RollingOut=False`, `WorkersAvailable=True`. The block printed only `CAPI WorkersAvailable=True`.
- Fix: print each condition that is not in its healthy state. Positive types must be `True`. The negative types (`RollingOut`, `ScalingUp`, `ScalingDown`, `Remediating`, `Paused`, `Deleting`) must be `False`. Tested:
  ```bash
  # READ-ONLY
  source ~/nkp-<cluster>.env 2>/dev/null
  kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get nkpcluster "$CLUSTER_NAME" -o jsonpath='phase={.status.phase}{"\n"}{range .status.conditions[*]}NKP {.type}={.status} {.reason}: {.message}{"\n"}{end}{range .status.capiCluster.conditions[*]}CAPI {.type}={.status} {.reason}: {.message}{"\n"}{end}' | awk -F'[= ]' 'NR==1 || (($2 ~ /^(RollingOut|ScalingUp|ScalingDown|Remediating|Paused|Deleting)$/) ? $3!="False" : $3!="True")'
  ```
  Then "Healthy: only the `phase=Reconciled` line". This also makes the long healthy list at `:89` unnecessary (it saves about 3 lines).

**M2. The pod checks miss `CrashLoopBackOff`. The step 7 post-check can pass on a broken cluster.**
- Files: `skills/nkp-upgrade/SKILL.md:222` with Done-when `:230`; `skills/nkp-troubleshooting/SKILL.md:134` and the text at `:138`.
- Problem: `--field-selector=status.phase!=Running,status.phase!=Succeeded` does not list a pod in `CrashLoopBackOff`, because its phase is `Running`. Also not listed: a `Running` pod with READY `0/1`. Step 7 says "No CNI, CSI, or platform pod is in `CrashLoopBackOff`", but no command shows it. The guide's check (pdf p.1046, step 5) names `CrashLoopBackOff` explicitly. A small model reads "No resources found" and reports the upgrade done.
- Second problem: an old pod in phase `Failed` (for example a failed Job) keeps the list non-empty after a good upgrade. So the "No resources found" Done-when can stay false.
- Fix (tested with sample output): use the STATUS and READY columns:
  ```bash
  kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get pods -A | awk 'NR==1 || ($4!="Completed" && ($4!="Running" || substr($3,1,index($3,"/")-1)!=substr($3,index($3,"/")+1)))'
  ```
  Done-when: "only the header line, or only old `Error` pods of a Job that the user accepts".

**M3. On a 2.18 source cluster, the ClusterClass field can be empty. Then gate G3 passes with no output, and the path choice is wrong.**
- Files: `skills/nkp-upgrade/SKILL.md:53-54` (CLASS columns), `:118` (block B filter `classRef.name … startswith("nkp-nutanix")`), `references/clusterclass.md:14`.
- Problem: the skill reads `.spec.capiCluster.topology.classRef.name` and `.spec.topology.classRef.name`. These are CAPI `v1beta2` names. Steps 1 and 2 run **before** the upgrade, on 2.18. The evidence comes only from a 2.19 cluster.
- Evidence (lab, read-only):
  - `clusters.cluster.x-k8s.io` serves `v1beta1` and `v1beta2` (storage `v1beta2`).
  - `kubectl get clusters.v1beta1.cluster.x-k8s.io -o custom-columns=C:.spec.topology.class,R:.spec.topology.classRef.name` prints `nkp-nutanix-v2.19.0  <none>`. In `v1beta1` the field is `topology.class`.
  - Field notes for older clusters also use `class: nkp-nutanix-v2.16.0`.
  - The CAPI API version and the NKPCluster schema of NKP 2.18 are not in the evidence.
- Effect: if 2.18 has the `v1beta1` shape, block B prints nothing. The G3 Done-when ("one project for each cluster") then passes with no output on the exact version that the gate is for. Step 1 also sends every AHV cluster to the non-ClusterClass path.
- Fix:
  - Block B: select AHV clusters by the label `cluster.x-k8s.io/provider=nutanix` (live on the NKPCluster, `live-lifecycle.txt:361`), not by the class name.
  - Step 1: use the CRD printer column (`kubectl get clusters -A` already prints CLUSTERCLASS on each version), or print `(.classRef.name // .class)`.
  - Add to block B: "No line for an AHV cluster: stop."
  - Add a row to OPEN-ITEMS (P-27): the 2.18 NKPCluster topology field name.

**M4. Step 1 Done-when needs the target CLI, but the dark-site path installs it only in step 3.**
- File: `skills/nkp-upgrade/SKILL.md:58` (`nkp version` must show the target), `:72` (Done-when), and `:162` (step 3 installs the target CLI from the bundle).
- Problem: on an air-gapped site, the target CLI comes from the bundle (skill `nkp-airgap`, steps 1-2). That happens in step 3. So the step 1 Done-when cannot become true, and "Start a step only after the Done-when of the step before passes" (`:41`) stops the agent. Eval U3 is this exact case.
- Fix: in step 1, "If `nkp version` does not show the target version, install the target CLI first. Air-gapped: skill `nkp-airgap`, steps 1 and 2. Connected: the user downloads it [pdf p.1018]. Then run step 1 again." In step 3.1, keep only the push (skill `nkp-airgap`, step 4).

**M5. The general eval FAIL rule fails correct answers.**
- File: `evals/nkp-upgrade.md:7`: "an upgrade command without `--kubeconfig "$MGMT_KUBECONFIG"` or without the namespace".
- Evidence:
  - `nkp upgrade kommander` has no `--namespace` (`nkp-help-ops.txt:27-43`).
  - `nkp upgrade platform-apps` must use `--workspace` and has no `--namespace` (`nkp-help-upgrade.txt:85-104`).
  - `nkp update cluster nutanix-registry-credentials --all-namespaces` is correct without it.
- Effect: a literal grader fails the correct step 4 command in U1, U3, and U7, and the correct N2 command in U6. This is the same class of defect as batch 1 M8.
- Fix: "an `nkp upgrade cluster`, `nkp upgrade addons`, `nkp update controlplane`, `nkp update nodepool`, or `nkp get nodepools` command without `--namespace`".

**M6. flux.md checks the sources and HelmCharts of a workload cluster on the management cluster.**
- Files: `skills/nkp-troubleshooting/references/flux.md:7`, `:28`, `:40` ("Keep `mgmt` for a source, a HelmChart").
- Problem 1: Flux's helm-controller makes the `HelmChart` on the cluster where the HelmRelease is. The skill itself puts the HelmReleases of a workload cluster on that cluster (`:17`, [pdf p.1047]). Its HelmCharts and sources are there too. Then F1 line 28 on `"$MGMT_KUBECONFIG"` shows "all Ready" for a workload cluster whose source fails, and F2 with `where='mgmt'` gives NotFound.
- Problem 2: on 2.19, most HelmReleases use `spec.chartRef` to an `OCIRepository` directly. They have no HelmChart.
  - Lab evidence: 20 HelmReleases have `chartRef.kind=OCIRepository`, 6 have a `GitRepository` chart source, and there are 6 HelmCharts in total.
  - So the chain "HelmRelease → HelmChart ← source" (`:7`) and the order "source → HelmChart → HelmRelease" (`:34`) are wrong for most apps.
- Fix:
  - F1 line 28: run on `"$CLUSTER_KUBECONFIG"`. Add the management line only for the management cluster.
  - F2: `where='cluster'` for every Flux kind. Keep `mgmt` only for AppDeployment.
  - Chain: "HelmRelease → `OCIRepository` (`spec.chartRef`), or HelmRelease → HelmChart → `GitRepository`" [live 2.19.0].
  - The lab has no workload cluster. Confirm with a `lab-ro` check when one exists (OPEN-ITEMS row).

## 3. MINOR

1. **P-20 can close.**
   - Lab: `nkp upgrade kommander --disable-appdeployments x --help` prints `ERR unknown flag: --disable-appdeployments`. The flag is removed, not hidden.
   - `SKILL.md:173`: replace the UNKNOWN line with "The guide names `--disable-appdeployments` [pdf p.1018]. The 2.19.0 CLI rejects it (unknown flag) [live 2.19.0]. Do not use it."
   - Move P-20 to Closed.
2. **jq precedence in block B** (`SKILL.md:118`).
   - `X[]? | select(...).value…name // "_internal"` parses as `X[]? | (select(...)… // "_internal")`. So each variable that is not `clusterConfig` (or override that is not `workerConfig`) adds `_internal`.
   - Tested: one extra variable gives `_internal,projA` for a single-project cluster (a false "two projects").
   - The guide's jq (p.1015) has the same defect. Live clusters have only `clusterConfig` and `workerConfig`, so the risk is low.
   - Fix: `(… | select(.name=="clusterConfig") | (.value.controlPlane.nutanix.machineDetails.project.name // "_internal"))`, and do the same for `workerConfig`.
3. **Empty image flags.**
   - `clusterclass.md:51,81`: when `WORKER_VM_IMAGES` is set, the block passes `--control-plane-vm-image ""` if `CP_VM_IMAGE` is empty (tested).
   - `non-clusterclass.md:101,124`: the block passes `--ami ""` or `--vm-template ""` when the variable is empty.
   - Add `: "${CP_VM_IMAGE:?}"` in the per-pool branch, and one guard for each infra in the `case`.
   - A stale `WORKER_VM_IMAGES` from the previous upgrade silently overrides the new `VM_IMAGE`. Add to C1: "Ask again for the per-pool images at each upgrade."
4. **Azure `--plan-*` and AWS lookup flags** (`non-clusterclass.md:88-89`): the table says "give them again", but the N4 and N5 blocks cannot take them. Add an `extra=()` array that the agent fills, or remove the instruction and point to `--help`.
5. **The N4 check matches by name prefix** (`non-clusterclass.md:110`): `grep -E "NAME|$CLUSTER_NAME"` also matches `dev-01x` for `dev-01`, and uses the NKPCluster name, not `capi`. Use `-n "$capins" get machines -l "cluster.x-k8s.io/cluster-name=$capi" -o wide`. The label is confirmed on the lab (5 machines).
6. **G1 health does not check the HelmReleases of the workload clusters** (`SKILL.md:93`). "Also run the last two lines with `"$CLUSTER_KUBECONFIG"`" also makes the small model rewrite a block. Give one second READ-ONLY block on the cluster env file with `get nodes`, `get pdb`, and `get helmreleases -A`.
7. **G5 expected value is from 2.19, but the gate runs on 2.18** (`SKILL.md:83`, "only `kommander-flux/management` [live 2.19.0]"). A 2.18 source can have more NKP-owned GitRepositories. Then the gate stops a healthy site. Say: "Other GitRepositories: the Kommander upgrade checks them first (`--allow-gitrepository-catalog-apps`)". Treat the CLI message as the gate.
8. **A failed UpgradePlan can block everything.** Block A note (`SKILL.md:103`): "not `Upgraded` = in progress, do not start another". A `Failed` plan from an earlier try then blocks for ever, and stopped.md forbids its delete. Add: "`Failed`: go to stopped.md S1."
9. **P-23 is a decision, not an UNKNOWN** (`SKILL.md:166-167`). The check (`--help | head -1`) does not answer the guide conflict. Write the rule: "The image must have the target Kubernetes version (the line that the target CLI prints). [live 2.19.0] The guide also says 'current' (p.1019, p.1039); P-23." Keep P-23 open in OPEN-ITEMS.
10. **ClusterClass name → infra map is incomplete** (`clusterclass.md:19`).
    - SUMMARY row 22 says pre-provisioned clusters also use `nkp-host-agent`. Then a pre-provisioned cluster goes to `nkp upgrade cluster metal`.
    - A cluster with class `nkp-aws-*` has no `infra` value (`nkp upgrade cluster` has no `aws`).
    - Add: "Provider pre-provisioned, or class `nkp-aws-*`: stop. UNKNOWN (P-06)."
11. **`yq` is not checked** (`gitops.md:54`). The bundle has no `yq` (`bundle-layout.txt`), and the Python `yq` needs `-y`. Add `command -v yq` to F3. Also say that pools with different images need `--control-plane-vm-image` and `--worker-vm-images` there too.
12. **The F1 Done-when has `kubectl ...`** (`gitops.md:37`). The small model must invent the elided part. Give the full READ-ONLY block.
13. **Duplicate facts (ADR 0001)**, all from skill `nkp-cluster-lifecycle`:
    - `rollouts.md:7` (`maxSurge: 1`, `maxUnavailable: 0`) copies lifecycle `variables.md:29`.
    - `rollouts.md:118-119` (40%, 300 s, 600 s) copies lifecycle `maintenance.md:60-62`.
    - Point to lifecycle V2 and M2.
    - The drain-timeout field `workers/machineDeployments/<i>/deletion` (`rollouts.md:105`) is an NKPCluster field. Its owner is lifecycle, but the lifecycle topology block (`SKILL.md:136`) does not list it. Ask lifecycle to add it (with the `troubleshooting.txt:70` evidence). Then troubleshooting only points to it.
    - `diagnose.md:25-27` and `prestage.md:93,103` both state the v0.14.0/v0.12.0 fact and the A-08 line. Keep one copy (prestage P5 owns the air-gap step), and point to it.
14. **Mark and wording:**
    - `controllers.md:83`: `docker logs --tail 100` is USER-TERMINAL "because the log can be long". It shows no secret and runs on the operator host. Rule 1 says READ-ONLY. It already has `--tail`.
    - `deletes.md:110` points to "the NKPCluster case of skill `nkp-cluster-lifecycle`" for the remove-all patch. Lifecycle `delete.md:77` has no such block and points back. Replace it with: "Never remove all finalizers. Use D5 for each one."
    - `diagnose.md:25`: "run without node data (D1, block B)" has no config file for that. Give the D5 change: "remove the `execCopyFromHost` collector". In D3, accept "no `node-diagnostics`" for that run.
15. **Small-model fitness and ASD-STE100:**
    - Long one-liners: block B jq (≈400 characters), rung 1 jsonpath, step 7 history jsonpath. Split each into two lines where possible.
    - Long sentences: `clusterclass.md:3` (two facts), troubleshooting `SKILL.md:89` (≈70 words). Split them.
    - Long-running CHANGES (`nkp upgrade kommander` up to 1 h+, `nkp upgrade cluster` up to `--timeout`) can pass the tool time limit of the agent shell. Tell the agent to give the block no time limit. If its tool cannot do that, the user runs it in their own terminal and the agent watches with C5. This is a cross-skill note: nkp-install has the same gap on `create cluster`.
    - The Docker Hub CHANGES block (`SKILL.md:153`) passes the token as a flag. Add the process-list warning that `nkp-install` uses ("Other users on the host can see it").

## 4. Commands and flags

All flags are in the live help or have a correct pdf tag. Exceptions: `--disable-appdeployments` (minor 1, now confirmed as removed) and `nkp diagnose <file>` (A-22, correctly UNKNOWN).

| Command | Flags in the skills | Evidence |
|---|---|---|
| `nkp upgrade kommander` | `--kubeconfig`, `--core-app-timeout`, `--platform-apps-timeout`, `--allow-gitrepository-catalog-apps`, `-v` | `nkp-help-ops.txt:27-43` |
| `nkp upgrade cluster nutanix` | `--cluster-name`, `--namespace`, `--vm-image`, `--control-plane-vm-image`, `--worker-vm-images`, `--kubeconfig`, `--dry-run`, `-o`, `--timeout` (40m), `--skip-preflight-checks` | `nkp-help-ops.txt:45-67` |
| `nkp upgrade cluster eks` / `metal` | `--timeout` 40m / 1h, `--kubernetes-image-uri` (metal) | `nkp-help-upgrade.txt:43-83` |
| `nkp upgrade platform-apps` | `--cluster-name` (NKPCluster), `--workspace` (required, name), `--version`, `--dry-run`, `--kubeconfig` | `nkp-help-upgrade.txt:85-104`; `live-upgrade.txt:57-64` |
| `nkp upgrade addons <infra>` | `-c`, `-n`, `--kubeconfig`, `--dry-run`, `-o yaml` | `nkp-help-upgrade.txt:129-165` |
| `nkp update controlplane/nodepool <infra>` | `--kubernetes-version`, `--ami`, `--ami-owner/-base-os/-format`, `--compute-gallery-id`, `--plan-*`, `--image`, `--vm-template`, `-n`, `--kubeconfig`; positional pool | help `:167-395`; positional pool from pdf p.1030 |
| `nkp update cluster nutanix-registry-credentials` | `--all-namespaces`, `--nutanix-registry-username/-password`, `--kubeconfig` | `nkp-help-lifecycle.txt:337-358` |
| `nkp diagnose` | `--kubeconfig`, `--bootstrap-kubeconfig`, `--bundle-name-prefix`, `--since`; `default-config`; `ssh <inventory>` with `--timeout` | `nkp-help-ops.txt:109-148`; `troubleshooting.txt:47-48` |
| `nkp describe cluster`, `nkp get nodepools` | `-c`, `-n`, `--kubeconfig` | `nkp-help.txt:139`; `nkp-help-lifecycle.txt:138` |

Lab checks of selectors (management cluster): `cluster.x-k8s.io/cluster-name=<mgmt-cluster>` returns 5 Machines, 5 NutanixMachines, 5 KCP/MD/MHC/MachineSet objects, 10 HelmReleaseProxies, and 1 Cluster. The D2 awk (`$3 != $4`) prints nothing on the healthy lab. The column positions in block A (`$4` of `helmreleases -A`, `$3` of `-n kommander get helmreleases`, `$(NF-1)` of `pdb -A`) match the live headers.

## 5. Other axes

**Upgrade path and order.** These are correct:
- 2.18.0 is the only source for 2.19.0 (pdf p.1011-1012). Minor versions go in order, and patch versions can be skipped.
- The order is gates → Kommander → management cluster → workload clusters.
- From 2.18, steps 4 and 5 use the CLI (pdf p.1019).
- GitOps: turn off pruning before Kommander (pdf p.1037-1038).
- Non-ClusterClass management cluster: N3 → N4 → N5. Workload cluster: N2 → N3 → N4 → N5 (pdf p.1025, p.1031-1033).
- The capiClusterRef lookup for the management cluster matches pdf p.1020.
- `--workspace` takes the workspace **name**. The guide (p.1032) says `--namespace` and "the NAMESPACE column". Live help and the logged dry runs (`live-upgrade.txt:57-64`) win, and the skill records the conflict.

**Rules block.**
- The rules block is identical in both skills (the check passes).
- `nkp diagnose` (D1, D2, D4) is CHANGES. The finalizer patch is CHANGES.
- Server dry runs (R9) are READ-ONLY, with the webhook check logged in `troubleshooting.txt:63-65`.
- No block prints a secret. The Docker Hub token is only checked with `printenv`.
- The node and SSH blocks are USER-TERMINAL with the host named. One mark is wrong (minor 14).

**Finalizer removal (D5).** It is gated and a last resort: D1-D4 first, 4 conditions with evidence, the VM UUID check in Prism Central, a written warning, "yes" plus the exact object name, one finalizer by index with a `test` op, bottom-up order, and never the namespace `kubernetes` finalizer. Eval T3 tests this gate. Good.

**Done-when checks.** All can become true, except these: M2 (the pod list), M4 (the dark-site CLI), G3 passing with no output (M3), and the D3 "no node data" run (minor 14).

**UNKNOWN lines.**
- P-04, P-06, P-14, P-20 … P-26, A-08, A-20, A-21, A-22 are all in OPEN-ITEMS. Each has a command and the correct owner skill listed.
- P-20 can close (minor 1). P-23's check does not answer its question (minor 9). P-21's and P-26's checks show only the current state. That is acceptable, because the skill gives a safe default ("set them on every connected site").

**Source tags.** I checked every pdf tag in both skills on its page. All match, except:
- `SKILL.md:247` `[pdf p.1035]` for "2.18: the NKPCluster object came": p.1035 describes NKPCluster but names no version. The 2.18 date is in `research/raw/05-*.md:495`. Use `[field]` or cite that line's source.
- `non-clusterclass.md:14` AKS `[pdf p.1035]`: the page says "attached clusters … their cloud providers" and does not name AKS.

**One owner per fact.** See minor 13. I found no copy of nkp-airgap push steps or nkp-install create flags. The Docker Hub gate is in nkp-upgrade (the carry-over says nkp-upgrade owns it). nkp-airgap step 3 points to it.

**Budget.** nkp-upgrade SKILL.md has 250 lines, which is the limit. The M4 fix must move text, not add it (for example, remove the long CLI bullet in step 1 and keep it in step 3). nkp-troubleshooting SKILL.md has 176 lines. The largest reference file has 161 lines.

**Scrub.** I found no IP, host name, lab cluster name, UUID, or secret in the skills, the evals, or the 3 new live files. `/home/runner/.kommander/config` in the help text is the build default of the CLI, not site data.

**Evals.**
- U1-U8 and T1-T8 match the skills.
- Each skill has an approval-gate eval (U4, T3, T7) and a "not in the skills" eval (U8, T8).
- Every ID that an eval names exists in OPEN-ITEMS.
- Fix M5. After M6, T1's flux expectation is unchanged.

## 6. Top fixes, in order

1. **M1 + M2**: fix the two filters that hide failures: the rung 1 CAPI condition filter (awk on positive and negative types), and the pod checks in step 7 and rung 5 (STATUS and READY columns, not the phase).
2. **M3**: block B selects AHV clusters by the `cluster.x-k8s.io/provider=nutanix` label. Step 1 reads the class with `(.classRef.name // .class)` or the CLUSTERCLASS printer column. Add "no line → stop" and OPEN-ITEMS P-27.
3. **M4**: install the target CLI before step 1's Done-when (dark site: nkp-airgap steps 1-2). Step 3 keeps only the push.
4. **M6**: flux.md reads the Flux sources and HelmCharts of a workload cluster on that cluster. Describe `chartRef` → `OCIRepository` as the main 2.19 chain.
5. **M5 + minor 1**: narrow the eval "namespace" FAIL rule to the commands that have `--namespace`. Close P-20 with the lab result and drop its UNKNOWN line.

Then the minor items. All fixes are text edits. Run the check script after them, then run evals U1, U3, U6, T1, and T4 again.

Not checked: I did not run the evals. I could not test the 2.18 schema (M3) or the workload-cluster Flux layout (M6), because the lab has only one 2.19 management cluster. Both fixes are safe on either schema or layout.
