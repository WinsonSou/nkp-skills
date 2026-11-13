# Lab test 1 fix pass review

Reviewer: Opus, fresh standalone read-only session, 2026-11-04. Scope: `git diff 89c35be..HEAD` (F0, the merges of F1–F7, the parent fixes, the Part C eval-run fixes, OPEN-ITEMS and LEARNINGS). I changed no repo file except this one. Scratch files are in `/tmp/rvlt1`. I did not use the lab or the web. I only read `../ntnx-skills` (commit `464d7b8`). Same-family reviewer: this review is context-isolated. It is not a cross-family independent review.

What I did:
- `python3 scripts/check_skills.py --self-test && python3 scripts/check_skills.py`: both pass (`self-test passed`, `16 skills checked, 0 errors`).
- `bash -n` on every bash block in the 24 changed skill files (`/tmp/rvlt1/blocks.py`): 0 syntax errors. Every block has a mark on line 1. Every block that is not USER-TERMINAL and uses a variable has the correct line 2. The blocks with no line 2 use no site variable (`nkp version`, `nkp delete bootstrap`, the two L8 MTU blocks).
- Approval gates: I listed each new or changed CHANGES block and the text before it (`/tmp/rvlt1/gates.py`). Each one has a plan and a stop for "yes", or the approved create plan covers it (decision Q8: the kubeconfig blocks; C12 step 3: the step 2 plan names the apply). One block has the wrong mark (minor 6).
- Rule 4: every new shell value is `''` with a `:?` guard (`ws`, `display`, `wsns`, `ns`, `web_img`, `init_img`, `repo`). No append block has a guessed value. No `<...>` text is in a block value.
- Secrets: both License `patch` blocks pipe `2>&1 | sed -E 's/Invalid value: "[^"]*"/Invalid value: "[masked]"/'` (`nkp-identity-security/SKILL.md:144`, `:152`). The PC and mirror login checks use `--netrc-file <(printf …)` with the builtin `printf` (`nutanix.md:105`, `:121`). The mirror `tags/list` check uses a here-string (`nodes.md:47`). No password goes into argv. No new block reads Secret data: `delete.md` D5.1 `get secret` prints only NAME/TYPE/DATA/AGE. The P-07 `awk` prints only the length of a CA value.
- Part A: I compared each row I1–I12, N1–N17, S1–S11, D1–D15, V1–V10, K1–K4, R1–R5 with the diff and the Decisions Q1–Q10. All of them are done. Two rows are done only in part (major 1 for the cross-file fact; minor 9 for D12).
- Facts: I compared each new `[live 2.19.0]` claim with `research/raw/lab-runs/2026-11-03-test1/*.md`. Examples: A-05 `$PWD/<cluster>.conf` mode 600, 17 min early (t3:92); workload ends at `✓ Waiting for machines to be ready` (t4:193); dry run 3 min / 7 Secrets vs < 20 s / 5 Secrets (LOG:22-23, t4:55-60); `--timeout` `30m0s` (LOG:17); `pc 302` (LOG:15); PC v4 login `200` (LOG:16); `--insecure` and the mirror CA (t3:184); `.62` for traefik (t4:172); 19 HR / 16 AppDeployments / 122 pods (t4:202); `Reconciled` at 38 min (t4:163); license 15 s, 11 min, 24 → 48, CPU requests 67–98 % (t3:120-160); trial status fields (t3:125); `7kr7h` suffix (t4:29); 33 finalizer objects (t6:117-120); D3 output, 57 s / 28 s, 82 s NotFound (t6:56-62, t7:19, t7:122); D4 output, 5 min 06 s / 7 min 04 s, move 87 s (t2:69, t8:19, t8:168-186); oci Secrets (t6:86, t7:128); `-dryrun.err` (t6:156); `externalIps` (t5:20); `dsr-dispatch: geneve` (t5:231); `/_oauth_kommander` 307 (t5:236); `CP_VIP` 000 / FIP 200 (t5:219, t5:338); 404 for `library/nginx`, `library/alpine`; the two bundle images (t4:201, `bundle-images.txt:107,214`); `%252F` (t4:201). All match. I found no wrong `[live]` claim.
- `[pdf p.N]` tags on new lines: p.26-28 (Starter, Rocky), p.29 and p.31-32 (license, Update License), p.318-319 (the UI workspace delete steps), p.496 (`Error` state), p.715 (Rocky only), p.719 (`--insecure`, Base64), p.724 (NTP), p.814 (LB and CRS lines), p.833 (AWS PVs). All match except one (minor 5).
- `nkp` flags: `--timeout`, `--insecure`, `--dry-run`, `--output`, `--bootstrap-cluster-image`, `--delete-kubernetes-resources`, `--control-plane-external-endpoint`, `--cluster-hostname`, `--additional-trust-bundle` are in `nkp-help*.txt`. `nkp create workspace --dry-run -o yaml` is not (minor 6).
- Companion anchors: each RECIPES/REFERENCE heading in a new pointer is in `../ntnx-skills` exactly: "Free IP check for a VIP or an LB range", "Floating IPs" (with the bold labels "Create and associate in one call", "Virtual IP", "Delete a floating IP"), "Subnets", "VPCs", "What an NKP cluster leaves behind", "Delete a volume group", "List and find volume groups", "Full inventory", "Read-only credential check", "Site preflight", "Leftover audit for a cluster", REFERENCE.md "PC certificate check".
- Stale-text greps: no "Starter: Rocky only" rule is left (`nkp-flow-cni` needs Rocky for its own reason). There is no P-11, A-05, N-41, N-44, or N-05 UNKNOWN line, and no joined `CLAIM:` column. The only `CLAIM:` text is the warning in `csi.md:242`. The `-n kommander` grep on `CLUSTER_KUBECONFIG` found 4 files outside the pass (major 1).
- Sizes: `nkp-identity-security/SKILL.md` 250 and `nkp-ndk/SKILL.md` 250 (at the limit), `nkp-install/SKILL.md` 249, `nutanix.md` 399, `csi.md` 390, `delete.md` 277. All are within the limits. The fixes below for these files must replace text, not add text.
- OPEN-ITEMS: A-30, A-31, P-56, D-60, N-50 are added. N-44 and N-05 are closed with the evidence and the date. P-07 and N-02 are updated. The header line names each one. The skills use the same IDs and the same scope. One more item can close (minor 4).
- Eval run: I read `grading.md`, `grading-r2.md`, and the r2 answers. The 3 skill fixes from the run are in `7fe0e6a` and do what the grading says.

**Verdict: go-with-changes.** 0 BLOCKER, 1 MAJOR, 13 MINOR.

The pass is thorough. It is well tied to the evidence, and the security items are correct. The one major item is the cross-file fact "workload platform apps are in `$WORKSPACE_NS`". The pass applied it in `nkp-install` and `nkp-vpc`, but four other owner files still use `kommander` on the target cluster.

## 1. BLOCKER

None.

## 2. MAJOR

**M1. Four owner files outside the pass still read workload platform apps in `-n kommander` on `CLUSTER_KUBECONFIG`.**
- Files:
  - `skills/nkp-networking/references/ingress-certs.md:14` (I1 fact "Service `kommander/kommander-traefik` … on every cluster") and `:31` (the I1 state block);
  - `skills/nkp-identity-security/references/gatekeeper.md:137` (G4 `-n kommander logs deploy/gatekeeper-controller-manager`);
  - `skills/nkp-networking/references/proxy.md:253` and `:258` (X6 line 3 `-n kommander run proxy-check`, "the labeled namespace `kommander`");
  - `skills/nkp-storage-backup/references/object-storage.md:13` ("On the target cluster, Rook Ceph runs in `kommander`" [pdf p.652]), and its 14 blocks.
- Evidence: a workload cluster has no `kommander` namespace. `get ns kommander` gave NotFound at 8 min and at 38 min. All 19 HelmReleases, also `traefik`, `gatekeeper`, and `gatekeeper-proxy-mutations`, are in the workspace namespace [live] (t4:145-149). Part B in the fixes file makes this a cross-file fact: "never `kommander`". The pass now teaches it in `nkp-install/SKILL.md:196`, `nutanix.md:375`, and `nkp-vpc/SKILL.md:159`.
- Effect: on a workload cluster, the agent follows the owner skill and gets `namespaces "kommander" not found`. This is the same failure as t4-5 and t5-3. The proxy X6 check then reports that the mutation is off. The I1 text contradicts the new install text.
- Fix:
  - In the three blocks, use `-n "$WORKSPACE_NS"`. It is `kommander` on the management cluster, so the management case does not change.
  - Change I1 to: "Service `kommander-traefik` in `WORKSPACE_NS` (`kommander` on the management cluster) [live 2.19.0]".
  - In proxy X6 text: "the namespace `WORKSPACE_NS`".
  - object-storage.md: the pdf line conflicts with the live fact. No workload cluster with Rook Ceph was seen. Keep the pdf tag and add `UNKNOWN (D-61): the namespace of Rook Ceph on a workload cluster (pdf p.652 says kommander; a workload cluster has no kommander namespace [live 2.19.0]). Find out with: source ~/nkp-<cluster>.env 2>/dev/null && kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get cephclusters -A`. Add the D-61 row to OPEN-ITEMS.

## 3. MINOR

1. **The License rollout check: "wait 60 s" conflicts with "15 min apart".** `nkp-identity-security/SKILL.md:165` says "Run this block, wait 60 s, and run it again". `:174` says "two runs at least 15 min apart". A small model runs it twice, 60 s apart, and stops. Evidence: four HelmReleases arrived 5–8 min after a first "all Ready" view (t3:143). Fix `:165`: "Run this block now, and again 15 min later." The line count does not change.

2. **The workload HelmRelease wait times out before the measured time.** `nkp-install/SKILL.md:201` uses `--timeout 30m`, but `:209` says `Reconciled` "can come 30–40 min after the create ends" (t4: 38 min). Done-when needs "condition met". Fix: `--timeout 45m`, or add to `:211`: "If the wait times out, run the block again. That is not a failure before 45 min."

3. **The management kubeconfig append prints nothing, both on success and on failure.** `nkp-install/SKILL.md:136`: `test -f … && echo … >> … && echo … >> …`. The next line says "If `test -f` fails …", but the agent cannot see that it failed. Fix: add `|| echo "no file: $PWD/$CLUSTER_NAME.conf"` at the end of the line.

4. **N-26 has an answer, but `ingress-certs.md:34` still has it as UNKNOWN.** The new install step uses `get kommanderclusters "$CLUSTER_NAME"` in `$WORKSPACE_NS` (`SKILL.md:200`) as a fact. t4:95 and t4:154 show KommanderCluster `skilltest-wl-01` (the same name as the NKPCluster) in the workspace namespace, `Joined`. Fix: close N-26 in OPEN-ITEMS with `[live 2.19.0]` t4 and the date. Replace the UNKNOWN line in `ingress-certs.md` with the fact.

5. **Wrong page tag.** `nkp-identity-security/references/rbac.md:178`: "You cannot delete `kommander-workspace` (the management cluster is in it). [pdf p.496]". The text ("the Management Cluster Workspace cannot be deleted from the GUI") is on p.497 (`0408-cluster-management.txt:4219`). Fix: `[pdf p.497]`.

6. **The workspace dry run has the wrong mark, and its flags are not in the help files.** `rbac.md:156` is `# CHANGES (dry run only: prints the Workspace object; creates nothing)`. It changes nothing, so the mark is READ-ONLY. The CHANGES mark adds an approval round, and L27 asked to remove extra rounds. The flags `--display-name`, `--dry-run`, and `-o yaml` of `nkp create workspace` are not in `research/raw/live/2.19/nkp-help*.txt`. The only evidence is t4:23 and `identity-security.txt:108` (no `-o`). Fix:
   - Mark it `# READ-ONLY (dry run: prints the Workspace object; creates nothing)`.
   - Change "After "yes" to "dry run of workspace <ws>"" to "Show the YAML in the plan".
   - At the next lab use, append the output of `nkp create workspace --help` to `nkp-help-ops.txt`.

7. **The mirror netrc line in N3 fails for a registry with a port.** `nutanix.md:119-121`: `reg=${reg%%/*}` keeps `host:port`. curl matches a netrc `machine` by the host name only, so `mirror login:` gives `401` when the password is correct. `nodes.md:45-47` does this correctly (`${host%%:*}`). Fix `:121`: `… 'machine %s login %s password %s\n' "${reg%%:*}" …`. The URL keeps `$reg`.

8. **"Fix the UI IP with the MetalLB annotation" points to a step that does not cover the platform Service.** `nutanix.md:13` sends the agent to `metallb.md` for the annotation. `metallb.md:83` gives `metallb.io/loadBalancerIPs` for a Service that the user owns `[field]`. A HelmRelease owns `kommander-traefik`, and the skills do not say how to set an annotation on it. Fix: change the pointer to "Create other `LoadBalancer` Services only after the platform apps are ready (skill `nkp-storage-backup`, `csi.md` C12 "When"). An annotation on `kommander-traefik` is not in the skills." That uses the live fact and gives no unverified step.

9. **D12 is done only in part: the management delete is not in tmux, and it has no log name.** `delete.md:138-141` runs `nkp delete cluster --self-managed` in the foreground. It takes 5–10 min and has a move step that uses a kind bootstrap cluster on the operator host. A lost terminal in the move is the same risk that I10 fixed for the create. In the lab, every delete ran in tmux with `~/<cluster>-delete.log` (t2:59, t8:153). The D5.4 list now names the create log but not a delete log. Fix:
   - Run D4 (and optionally D3) like N4D: `tmux new-session -d -s "nkp-$CLUSTER_NAME-del" -c "$PWD" "bash -c 'umask 077; source …; nkp delete … > ~/nkp-$CLUSTER_NAME-delete.log 2>&1; echo RC=\$? >> ~/nkp-$CLUSTER_NAME-delete.log'"`.
   - Add `"$HOME/nkp-$CLUSTER_NAME-delete.log"` to both D5.4 lists.
   - `"$PWD/$CLUSTER_NAME-dryrun.err"` is in the list, but no skill block writes that file: the N4D dry run writes only stdout. It does no harm (`[ -e ]`, `rm -f`). Keep it or remove it, but do not let a reader think that N4D makes it.

10. **The router step 5 does not give the import line of the companion client.** `nkp/SKILL.md:40` says "`python3 - <<'PY'` with the recipe code". Every recipe needs `import sys; sys.path.insert(0, '<this skill dir>/scripts'); from ntnx import *` (`nutanix-api/SKILL.md:12`). A small model can copy `<this skill dir>` into the block (rule 4). The r2 eval model put in the real path, but nothing in the skills tells it to. Fix: add "The first Python line is the import line of skill `nutanix-api` step 2, with the real folder of that skill."

11. **The mask text is different in the lab brief template.** `research/raw/lab-runs/2026-11-03-test1/BRIEF.md:26` uses `"<masked>"`. The skills and evals use `"[masked]"`. The brief is now the template for later lab tests (AGENTS.md). Fix: `[masked]`.

12. **Pointers to Prism Central with no companion recipe, in files outside the pass** (ADR 0004 asks for a companion pointer and a fallback):
    - `csi.md:202` ("The user checks there which VM holds it") → skill `nutanix-storage`, RECIPES.md "Read entries in the description and the attachment sub-resource";
    - `nkp-troubleshooting/references/deletes.md:93` (VM UUID check) → skill `nutanix-nkp`, "Leftover audit for a cluster";
    - `rollouts.md:59` (subnet pool full) → skill `nutanix-networking`, "Pool capacity: free IPs in a subnet pool";
    - `diagnose.md:95` (node IPs) → skill `nutanix-vm`, "NKP VM audit: the VMs of one cluster".

    Add each pointer with the fallback sentence.

13. **Housekeeping and STE style.**
    - `scripts/__pycache__/check_skills.cpython-312.pyc` is tracked and changed in this diff. Run `git rm --cached` on it and add `__pycache__/` to `.gitignore`.
    - `LEARNINGS.md:20-30` still has the "Top fixes" list of the retro, and this pass resolved most of it. Replace the list with one line that points to `research/lab-runs-2026-11-03-fixes.md` (Part D, R6).
    - `nkp-vpc/SKILL.md:88` (step 2 item 4) is one paragraph of about 150 words with seven instructions. Split it into sub-bullets: choose the address, select by address, create with the association, before the create, done when, record. Also `:117`: "run the block only for the `pc` and `registry` lines" asks the agent to run part of a block. Write "run the block; for a workload cluster, read only the `pc` and `registry` lines".
    - `nkp-identity-security/SKILL.md:183`: put `nkp-insights-management` in backticks, like the other names.

## 4. Part A status

| Group | Status |
|---|---|
| I1–I12 | Done. I6 and Q8: the create plan includes the kubeconfig block (`nutanix.md:298`). I12: `SKILL.md:82`. |
| N1–N17 | Done. N3 needs minor 8; N7/N10 need minor 7. |
| S1–S11 | Done. S5 needs minor 1; S10 needs minor 6; S11 needs minor 5. |
| D1–D15 | Done. D12 is in part (minor 9). |
| V1–V10 | Done. N-41 removed; N-44 and N-05 closed; L8 moved to `layouts.md`. |
| K1–K4 | Done. K4 includes the image form fix of the eval run. |
| R1–R5 | Done. R6 belongs to Part D. |
| Part B cross-file facts | Workload/management facts: consistent. `$WORKSPACE_NS` for workload apps: see M1. Anchors: all exist. |

## 5. Good

- The two License blocks mask the key in all output, and the text says why. The Secret delete after a denial applies only when `ref=` was empty. This is a safe rule.
- The netrc and here-string forms keep every password out of argv, and the text says the limit (a space or a `"` in the password).
- The N4D split (management dry run = preflight with kind; workload dry run < 20 s) and the tmux create with an `RC=` line are exact and easy to follow.
- `delete.md` D5 has a clear order: mirror Secrets, then the volume groups after the cluster, then the VPC, then the files, with the env file last after `;`. Each step has a READ-ONLY check and a Done-when.
- The VPC workload layout (1 FIP, no `--cluster-hostname`, `ui 404` normal) and N-50 are honest about what the live run shows and what it does not show.
- The C12 smoke test makes the namespace first, uses only mirror images in the `docker.io/<path>:<tag>` form, says when to run it (after the platform apps), and has a remove step with D-60.
- The eval run found 3 skill gaps, and each fix is small and is in the right owner file.

Not checked: I did not run the evals again after `7fe0e6a`. I did not run a block on a cluster. The `[portal]` facts and `../ntnx-skills` recipe behavior are not checked here (they were verified live in HANDOFF.md §2).

## Fix pass (parent, 2026-11-04)

| Finding | Fix |
|---|---|
| M1 | `ingress-certs.md` I1 fact + state block, `gatekeeper.md` G4, `proxy.md` X6 (block + text): `-n "$WORKSPACE_NS"`. `object-storage.md`: fact line + UNKNOWN (D-61) with the `get cephclusters -A` check; D-61 row added. |
| 1 | identity License: "Run this block now, and again 15 min later". |
| 2 | install workload wait `--timeout 45m`. |
| 3 | install mgmt kubeconfig append ends with `\|\| echo "no file: …"`. |
| 4 | N-26 closed (t4); the UNKNOWN line in `ingress-certs.md` replaced by the fact. |
| 5 | rbac.md `[pdf p.497]`. |
| 6 | Partly. The mark stays `# CHANGES`: `check_skills.py` counts every `nkp create` as a change (`readonly-writes`), and the batch 3 gitops dry runs use the same mark. The text now says that the flags are not in the saved help text. Next lab use: save `nkp create workspace --help` to `nkp-help-ops.txt`. |
| 7 | N3 netrc `machine` uses `${reg%%:*}`. |
| 8 | `nutanix.md` N1 `LB_IP_RANGE` row: "create other `LoadBalancer` Services only after the platform apps are ready (C12 When); an annotation on `kommander-traefik` is not in the skills". |
| 9 | D4 runs in tmux (`nkp-<cluster>-delete`) with `~/nkp-<cluster>-delete.log` and `RC=`; the log is in both D5.4 lists. Quoting tested locally with `echo` in place of `nkp`. `-dryrun.err` kept (harmless). |
| 10 | Router step 5: the first Python line is the `nutanix-api` step 2 import line with the real folder. |
| 11 | BRIEF.md already used `[masked]` at HEAD (no change). |
| 12 | Companion pointers + fallback in `csi.md`, `deletes.md`, `rollouts.md`, `diagnose.md`. |
| 13 | `__pycache__` untracked and in `.gitignore`; LEARNINGS "Top fixes" replaced by a pointer; `nkp-vpc` step 2 item 4 split into sub-bullets; step 3 "Run the block. For a workload cluster, read only …". The `nkp-insights-management` backticks were not added: the check script reads a backticked `nkp-*` name in a SKILL.md as a skill name. |
