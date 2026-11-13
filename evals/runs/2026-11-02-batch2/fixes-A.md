# Batch 2 fix pass A (upgrade, troubleshooting, rules, install)

Date 2026-11-02. Scope: `review-1.md`, `grading-1.md`, `grading-2.md` fixes 1 and 2 (fix 2 only for `nkp-install/references/nutanix.md`). `skills/nkp-networking/**` is for pass B. Only the rules block sync changed it.
Checks: `check_skills.py --self-test` and `check_skills.py` pass. `bash -n` passes on all 245 command blocks. I tested each shell fix with `bash -c` on scratch files in `/tmp/b2fixA`. `nkp-upgrade/SKILL.md` went from 250 to 226 lines.
Lab (read-only and server dry runs, webhook check first) is logged in `research/raw/live/2.19/live-lifecycle.txt`, section "Fix pass A".

## review-1.md

- M1 fixed (skills/nkp-troubleshooting/SKILL.md:87). Rung 1 prints all conditions. awk keeps each one that is not in its healthy state. Tested.
- M2 fixed (skills/nkp-upgrade/SKILL.md:199, Done-when :207; skills/nkp-troubleshooting/SKILL.md:135). The awk reads the STATUS and READY columns. Tested with CrashLoopBackOff, 0/1 Running, Completed, and Error.
- M3 fixed (skills/nkp-upgrade/SKILL.md:114-119, :62; references/clusterclass.md:14-24). Block B selects by `-l cluster.x-k8s.io/provider=nutanix` and says "No line for an AHV cluster: stop". Step 1 and C1 use the CLUSTERCLASS printer column. Lab: one line, one project. The 2.18 schema stays open in P-04 (research/OPEN-ITEMS.md:23). The review proposed P-27 for it, but P-27 is now the registry CA item (grading-1 fix 1), so I added the 2.18 field check to P-04.
- M4 fixed (skills/nkp-upgrade/SKILL.md:61). If the CLI is not the target, install it first (air-gapped: nkp-airgap steps 1-2). Step 3.1 now does only the push (:140).
- M5 fixed (evals/nkp-upgrade.md:8). `--namespace` is required only on the commands that have the flag.
- M6 fixed (skills/nkp-troubleshooting/references/flux.md:9-12, :21, :31, :44-49). Chain: chartRef → OCIRepository, or HelmChart → GitRepository. Lab: 20 OCIRepository and 6 GitRepository chart sources. All Flux kinds now use `"$CLUSTER_KUBECONFIG"`. The default is `where='cluster'`, and `mgmt` is only for AppDeployment. Not confirmed on a workload cluster (the lab has none). No new row: no ID was free in this pass, and the fix is correct on both layouts.
- minor 1 fixed (skills/nkp-upgrade/SKILL.md:155; research/OPEN-ITEMS.md:120). P-20 is closed with the lab evidence.
- minor 2 fixed (skills/nkp-upgrade/SKILL.md:119). jq precedence: each select now has `| (… // "_internal")`. Tested with extra variables.
- minor 3 fixed (references/clusterclass.md:24, :55, :85; references/non-clusterclass.md:103, :129; references/gitops.md:70). `${VAR:?}` guards are on each image variable. The per-pool branch no longer needs `VM_IMAGE`. Text added: "Ask again at each upgrade". Tested.
- minor 4 fixed (references/non-clusterclass.md:88-94). An `extra=()` array takes the Azure `--plan-*` flags. The AWS lookup flags point to `--help`. Tested with a value that has a space.
- minor 5 fixed (references/non-clusterclass.md:114). The check uses `-n "$capins" -l cluster.x-k8s.io/cluster-name=$capi`.
- minor 6 fixed (skills/nkp-upgrade/SKILL.md:91-108). Block A2 runs on the cluster env file: nodes, pdb, and helmreleases.
- minor 7 fixed (skills/nkp-upgrade/SKILL.md:79, :87). G5: 2.18 can have more GitRepositories. The Kommander upgrade does the real check.
- minor 8 fixed (skills/nkp-upgrade/SKILL.md:112). A `Failed` UpgradePlan goes to stopped.md S1.
- minor 9 fixed (skills/nkp-upgrade/SKILL.md:144). This is now a rule (the target Kubernetes version), plus the guide conflict. P-23 stays open.
- minor 10 fixed (references/clusterclass.md:23). Pre-provisioned or `nkp-aws-*`: stop, UNKNOWN (P-06).
- minor 11 fixed (references/gitops.md:57-65). Added a `command -v yq` check, the Python `yq -y` note, and the per-pool images.
- minor 12 fixed (references/gitops.md:37-44). Added a full READ-ONLY Done-when block.
- minor 13 fixed (references/rollouts.md:7, :105, :118; nkp-cluster-lifecycle/SKILL.md:136 lists the `deletion` field; references/diagnose.md:25 points to prestage P5 and A-08 is no longer repeated).
- minor 14 fixed (references/controllers.md:80 READ-ONLY; references/deletes.md:110 "Never remove all finalizers"; references/diagnose.md:25, :87 run without the node collector, and D3 accepts it).
- minor 15 partly fixed. Tool time limit note (skills/nkp-upgrade/SKILL.md:154). Docker Hub process-list warning (references/dockerhub.md:26). Tags (SKILL.md:224 `[field]`; non-clusterclass.md:14 AKS has no p.1035 tag). Block B split into two lines. Not fixed: split of the rung 1 jsonpath and the step 7 history jsonpath (a split adds lines and risk, and the rung 1 awk now makes it readable). Not fixed: the long sentence at clusterclass.md:3 (it is split now) and the time-limit note in nkp-install (outside the scope of this pass).
- Gate G2 (Docker Hub) moved to `skills/nkp-upgrade/references/dockerhub.md` to keep SKILL.md in the budget. stopped.md:28 points to it.

## grading-1.md

- Fix 1 fixed. Owner: nkp-cluster-lifecycle `references/variables.md` V8 (:129-155), with the row at :108; lifecycle SKILL.md:248 points to it. nkp-airgap points to V8 (references/nodes.md:5, SKILL.md:230). R9 matches (nkp-troubleshooting/references/rollouts.md:133): a URL change rolls the nodes [pdf p.287], and R9 is only for a CA change in the Secret only. Lab: the webhook pings each registry URL (the dry run rejects a URL that it cannot reach). The node CA comes from the Secret key `ca.crt` (contentFrom). The CA-only roll is UNKNOWN (P-27, research/OPEN-ITEMS.md:37).
- Fix 2 fixed (nkp-install/references/preprovisioned.md:86; nkp-airgap/SKILL.md:146). The flag is only on `create cluster nutanix` and `install kommander` [live 2.19.0].
- Fix 3 fixed (nkp-install/references/preprovisioned.md:26). There is no `--ntp-servers`. Do not collect `NTP_SERVERS`.
- Fix 4 fixed (evals/nkp-troubleshooting.md:23 T1 "skips rung 2 or rung 3"; :11 general "says that an installed skill is not installed").
- Fix 5 (model behavior: T1 WORKSPACE_NS early, U7 unset vars, U8 2.18 rebuild, T4 copies blocks) not fixed: the grading says no fix. The new rule 4 sentence also covers T1.
- E13 FAIL: covered by fix 2. L1 minor (p.935 claim) not fixed: model behavior, and the skill text is correct.
- U1, U5, T2, T3, T5 minors: not fixed. They are model behavior, and the skills already say these things. T6 and T7 skill defects are covered by fix 1.

## grading-2.md

- Fix 1 fixed (skills/_shared/RULES.md:19, synced to all 7 SKILL.md files; evals/nkp-install.md:13).
- Fix 2 fixed only for nkp-install (skills/nkp-install/references/nutanix.md:262). The metallb.md M2 and M3 part is for pass B.
- Fixes 3 and 4: not in pass A (networking, pass B).
