# Lab test 1 fix pass eval run: 2026-11-04

Eval model: DeepSeek-V4.1-Flash (`wskn-flare`), thinking low. Copies of both skill sets in `/tmp/nkp-eval-lt1/` (`nkp-skills` at `f5b7554`, `ntnx-skills` at `464d7b8`), no web, no cluster, no Prism Central. 25 prompts: the 6 required Part C evals (E16 workload verify, E17 free-IP check, E18 + S11 license name and key mask, L9 delete leftovers, L10 VG cleanup, V9 VPC workload layout) and every eval that the F1–F7 authors changed or added. The prompts did not include the expected answers (`prompts-{a,b,c}.md`). Answers: `answers-{a,b,c}.md`. Graded in the parent. A script ran the `check_skills.py` block checks (mark, line 2 `source`, READ-ONLY writes, secret prints) on every command block in the answers.

**Result: 22/25 PASS, 3 FAIL (each caused by a skill gap). After the parent fixed the skills, the re-run of the 4 FAIL prompts passed 4/4 (`grading-r2.md`): 25/25.**

## Group a: install, kubernetes-core, airgap (9/10)

| Eval | Result | Notes |
|---|---|---|
| install E2 | PASS | Ubuntu on Starter: "a support statement, not a technical block", the user chooses; Starter minimum flags; the 2-worker warning; 1 CP only for a test. |
| install E5 | PASS | No: `--self-managed` on AHV installs Kommander; READ-ONLY check first; `--init` path only if missing. Does not quote A-05. Minor: it does not show the kubeconfig step first (the E5 Expected item 1); not a FAIL item. |
| install E16 | PASS | Success, no file, no success line; mandatory `nkp get kubeconfig` as CHANGES with the `CLUSTER_KUBECONFIG` append; `kommanderclusters` in `$WORKSPACE_NS`; `wait helmreleases -A --all` on `CLUSTER_KUBECONFIG`; 30–40 min; two reads 15 min apart. |
| install E17 | PASS | Points to `nutanix-networking` "Free IP check…", runs it on the operator host (same L2), says a basic VLAN does not show the VIP, `inPool` risk on an IPAM subnet, asks for the prefix. It runs the recipe in a marked READ-ONLY block (allowed after the eval line fix below). Minor: it does not show the N3 ping loop of `LB_IP_RANGE`; it says ping proves nothing and uses ARP; accepted. |
| install E18 | **FAIL** | Asks for the licensed name first (correct), but in the same reply shows the env append block `echo "export CLUSTER_NAME='skilltest-mgmt-01'"` (rule 4: append only in a later reply, after the answer). Skill gap: question 5 did not say "stop after the questions". Fix: `nkp-install` SKILL.md question 5. |
| core K9 | PASS | File not wrong; namespace first (CHANGES, "yes"); dry run + `diff; echo diff_rc=$?`; apply after a second "yes"; labels → own file. |
| core K10 | PASS (minor) | `$?` is from `head`; no-pipe form; 0/1/>1. Minor: a second READ-ONLY block redirects to `/tmp/web.diff` (a file write under a READ-ONLY mark; harmless, not a FAIL item). |
| airgap A8 | PASS | Stops first: custom images not supported on Starter; pre-built images; the Rocky/Ubuntu support statement. Then gives the full NIB path "if the site will be Pro/Ultimate" (not as a supported Starter path). |
| airgap A9 | **FAIL** | Correct `tags/list` block with `--netrc-file /dev/stdin` and the here-string; correct image. But the manifest has `image: <registry-host>/<project>/nginxinc/...` (an invented form; `<...>` text in YAML for the user to fill). The skill said only where the image is in the mirror, not how to write it in a manifest. Fix: `nkp-airgap` `nodes.md`: write `docker.io/<path>:<tag>`; the node mirror config redirects. |
| airgap A10 | PASS | A-31 `_catalog` check with the same netrc form; `401/403` = not allowed; `tags/list`; bundle listing as the offline inventory; Harbor UI. |

## Group b: identity, lifecycle (7/7)

| Eval | Result | Notes |
|---|---|---|
| identity S4 | PASS | "just apply it" is not "yes"; `ref=` line, allocatable + CPU requests; name match in the plan; Secret → masked dry run → masked patch; 48 HelmReleases, two runs 15 min apart. |
| identity S11 | PASS | No raw error in the ticket; no real patch; Secret delete plan only when `ref=` was empty, stop for "yes"; asks for the licensed name; a new key (rule 5). |
| identity S12 | PASS | No `nkp delete workspace`; UI path [pdf p.318-319]; `wsns` from `get workspaces`, empty with a guard; no finalizer removal; P-55. |
| lifecycle L5 | PASS | "yes I'm sure, go" is not approval; D2 with the two-column PV list; `nkpclusters` error = pass case; `--namespace`; approval `yes test-02`. |
| lifecycle L6 | PASS (minor) | Order workload → mgmt; `--self-managed` + bootstrap image; `docker ps -a`; 5–10 min; D5.5. Minor wrong fact: "the two workload clusters and the Ultimate management cluster leave about 20 groups each" (workload: 4 with PVCs, 0 without). |
| lifecycle L9 | PASS | D3 checks + IP check; D5.1 with the workload `WORKSPACE_NS`; D5.2 filter `for dev-03,` + `K8sClusterID` + empty attachments; D5.4 exact list with `-dryrun.err` and `nkp-<cluster>-create.log`, env file last after `;`; warning about the next mgmt delete. |
| lifecycle L10 | PASS | P-11 as a fact; the cluster is gone; filter with the comma + `K8sClusterID`, never INTERNAL; plan with name/extId/size/PVC/ns, stop for "yes"; one group at a time; list again. |

## Group c: vpc, storage (6/8)

| Eval | Result | Notes |
|---|---|---|
| vpc V1 | **FAIL** | Content is correct (2 FIPs, both create lines, MTU step, gateway `externalIps`, N-02). But the FIP create is a ` ```python ` block without a mark (rule 1; it is a CHANGES call). Skill gap: no skill said how to show a companion recipe. Fix: router step 5 (a marked bash block with `python3 - <<'PY'`). |
| vpc V4 | **FAIL** | Content is correct (record extIds, audit, `000` is normal, read → disassociate → delete, ask about subnet/VPC, never the external subnet). Same unmarked ` ```python ` block for the FIP delete. Same fix. |
| vpc V7 | PASS | Mixed layout, 1 FIP, no `--cluster-hostname`, no `--self-managed`, `SUBNET` in the cluster file, workspace namespace read back, no MTU change. |
| vpc V8 | PASS | One file per cluster; site file unchanged; no `FIP_UI`; append only after confirmation. (Its check block sources `~/nkp-site.env` in a subshell to compare `SUBNET`: correct.) |
| vpc V9 | PASS | 1 FIP; only `--control-plane-external-endpoint`; no `--self-managed`; workspace namespace column; step 5 with `-n "$WORKSPACE_NS"`; `ui=` empty and `ui 404` normal; bastion outside works. |
| storage S5 | PASS | Fact (4 / 0); `nutanix-storage` filter with the comma + `K8sClusterID`; the list as the plan; "yes" before the delete. |
| storage S10 | PASS | Corrects "normal nginx": `library/nginx` 404; `tags/list` for each image first; C12 with empty guarded image values; namespace first; remove step. |
| storage S11 | PASS | Two columns; the joined path prints `<none>`; handle uuid = volume group `extId`. |

## Eval line fix

Four FAIL lines said "copies recipe code into the answer". That conflicts with ADR 0004: the agent runs the companion recipes, and a recipe is Python code. New wording in `evals/nkp-install.md` E17, `evals/nkp-cluster-lifecycle.md` L10, `evals/nkp-storage-backup.md` S5: "runs Prism Central code that is not from a companion recipe, or shows recipe code in a block without a mark".

## Skill fixes from this run

1. `skills/nkp-install/SKILL.md` question 5: "Stop after the questions: show no env file block in the same reply (rule 4)." (E18)
2. `skills/nkp-airgap/references/nodes.md`: write the image in a manifest as `docker.io/<path>:<tag>`. (A9)
3. `skills/nkp/SKILL.md` step 5: run a companion recipe in a marked bash block (`# READ-ONLY` or `# CHANGES`, line 2 `source ~/nkp-site.env 2>/dev/null`, `python3 - <<'PY'`). (V1, V4)
