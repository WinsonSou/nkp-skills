# Batch 1 eval run — 2026-11-02

Eval model: DeepSeek-V4.1-Flash, thinking low, a copy of `skills/` only, no web. Skills at commit b78b8a6. The operator host login shell is zsh. 20 prompts: `nkp-airgap` A1-A8 (`answers-a.md`), `nkp-cluster-lifecycle` L1-L8 and `nkp-install` E12-E15 (`answers-b.md`). The prompts went to the model without the expected answers (`prompts.md`).

| Eval | Result | Notes |
|---|---|---|
| airgap A1 | PASS (minor) | Checksum, extract, IMAGE_BUNDLES, push after a plan; Harbor project and `mesosphere` false positive. **Minor:** it appends `BUNDLE_DIR='/data/nkp-v2.19.0'` in the same reply that asks whether `/data` is correct. |
| airgap A2 | PASS | Insights and Trivy DB in the kommander bundle; OS packages not in the bundle; `package-bundle` block is USER-TERMINAL. |
| airgap A3 | PASS (minor) | nodes.md checks, on-node `hosts.toml`, CA fingerprint, journal; does not name `konvoy-mirror.toml` as the 2.19 path; points to lifecycle. **Minor:** two blocks keep the literal `~/nkp-<cluster>.env` after it already made `~/nkp-dev-01.env`. |
| airgap A4 | PASS | Ships the assets, SHA-256 check, apply belongs to `nkp-identity-security`. Uses `SKILL_DIR` as a placeholder path (the skill gives no absolute path). |
| airgap A5 | PASS | Refuses; READ-ONLY checks; plan; stops for "yes". |
| airgap A6 | PASS | "Not in the skills"; no size limit. |
| airgap A7 | PASS | EXTRA_BUNDLE, `--to-internal-registry-mirror`, stops at UNKNOWN (A-07). |
| airgap A8 | PASS (minor) | Stops on Starter; offers the CIS Level 1 Rocky image. **Minor:** then gives the whole NIB walkthrough "for a tier that allows custom images", which is noise. |
| lifecycle L1 | PASS | Reads min/max, `nkp scale nodepool` with `--namespace`, M1 fallback, watch. Quotes P-08. |
| lifecycle L2 | PASS (minor) | Patches the NKPCluster, dry-run diff, full rollout in the plan, 50-256. **Minor:** the env file block has `CLUSTER_NAME='<NAME from step 1>'` (says it fills it before the run). |
| lifecycle L3 | PASS | `healthCheck` with `unhealthyLessThanOrEqualTo: 60%`; explains the dropped `maxUnhealthy`; Metal pool stop. |
| lifecycle L4 | PASS | `--gpu-profile-name`, `--gpu-count`, no `--vm-profile`; operator → `nkp-gpu-ai`. |
| lifecycle L5 | PASS | D1/D2, plan, requires `yes test-02`; `--namespace`; P-11. |
| lifecycle L6 | PASS | Workloads first, separate approvals, `--self-managed` with the bootstrap image. |
| lifecycle L7 | PASS | M3 check, `--control-plane-renew-certificates-before`, CP replace and single-CP downtime. |
| lifecycle L8 | PASS | "Not in the skills"; READ-ONLY Deployment args check. |
| install E12 | PASS | Metal is workload-only; selectors; bootstrap token mode 600; FC steps; P-13 (renumbered from P-08). |
| install E13 | PASS (skill defect) | All expected steps. **Skill defect:** `preprovisioned.md:146` passes `--ssh-username "$SSH_USER"`, but `:158` says `--ssh-username` is the user that NKP creates on the nodes, not the SSH user. The model copied the contradiction. |
| install E14 | PASS | `--help` first; P-05 for the CNI; keys only by editor. |
| install E15 | PASS | "Not in the skills" for both; READ-ONLY checks. |

**Result: 20/20 pass, 5 minor problems, 1 skill defect.**

Fixes for the fix pass:
1. `preprovisioned.md`: remove `--ssh-username "$SSH_USER"` from the P5 script (or make it a separate optional node-user variable), so that the script matches the note.
2. Rule 4 is already clear on placeholders; A1 and L2 still write a value before the user confirms it. Add to rule 4: "Ask first. Write the line in a later reply, after the answer."
3. Rule 3: after the cluster env file exists, use its real name in every later block (A3).

## Fix pass (2026-11-02)

Inputs: `review.md` (M1-M8, minor 1-16, section 4) and the three eval fixes above. Checks after the fixes: `check_skills.py --self-test` and `check_skills.py` pass; `bash -n` passes on all 136 shell blocks; D5, C9, the asset check, and the airgap `IMAGE_BUNDLES` block were tested with `bash` on scratch files in `/tmp/b1fix`. New lab evidence (read-only `get`, `sha256sum -c`), scrubbed: `research/raw/live/2.19/live-lifecycle.txt:359`.

**MAJOR**
- M1 fixed: `maintenance.md:52` (`-n "$WORKSPACE_NS" logs`, no `-A`), `:21` (`get deploy` scoped to `$WORKSPACE_NS`), `:55` (fallback to the workload cluster with the namespace from `get deploy`). Live: the autoscaler runs in `kommander` on the management cluster.
- M2 fixed (settled, no change of path): the lab shows `kommander.d2iq.io/host: "true"` on the NKPCluster `.metadata.labels` and on `.spec.kommanderCluster.labels` `[live 2.19.0]` (`live-lifecycle.txt:359`). Added the second test "NAMESPACE `kommander`": `delete.md:16`, lifecycle `SKILL.md:64`.
- M3 fixed: `delete.md:122` (exact file list, with `$PWD` dry-run and MetalLB files), `delete.md:131` (`rm` of the same list, env file last, `${CLUSTER_NAME:?}` guard). Test: cluster `dev` keeps every file of `dev-01`.
- M4 fixed: `preprovisioned.md:104` (`--ssh-username "$SSH_USER"` on the upload, `[pdf p.802]`).
- M5 (= eval fix 1) fixed: line removed from the P5 create script; the note says "Do not add it" (`preprovisioned.md:160`).
- M6 fixed: `cloud.md:290` (anchored patterns that end in `:`; tested: a Base64 line with `ami`, `region`, `image` is not printed). Also made the other dry-run greps safe: `metal.md:153`, `preprovisioned.md:177`, `nutanix.md:273`. Authoring rule: `RULES.md:11`.
- M7 fixed: `nutanix.md:183` points to skill `nkp-airgap` step 4 and gives a READ-ONLY three-path check. The owner block (airgap) was tested: it writes nothing when a second bundle version makes `ls` return two names.
- M8 fixed: `evals/nkp-install.md:166` (P-13), `:181` (P-14). New check `eval-id` (`check_skills.py:174`): an eval may name only IDs whose "Blocks skill" cell lists that skill (it catches the old P-08/P-09).

**MINOR**
1. Fixed: AKS license p.27 (`cloud.md:20`); `Standard_D4s_v3` p.194, p.872 (`:180`); GCP `--network` p.218, p.922 (`:232`); "vSphere Client 7.0.3", and CNS 7.0.3 (`:240`).
2. Fixed: lifecycle `metal.md:12` points to skill `nkp-install` M3; the USER-TERMINAL claim is gone.
3. Fixed: `os-images.md:103` points to `nkp-install` pre-provisioned P3.
4. Fixed: lifecycle `SKILL.md:67` (env file create → `nkp-install` "Prepare the env files" item 2; the check block follows); lifecycle `metal.md:71` (drain, get, uncordon in marked blocks with `node` guard); `cloud.md:274` (`get ipaddresspools` block).
5. Fixed: `prestage.md:47` uses `dir=''; : "${dir:?}"` in the same pattern as other blocks (no new placeholder kind; an empty value stops the block).
6. Fixed: `preprovisioned.md:79` (`Host key verification failed` → user adds host keys with `ssh-keyscan`, CHANGES).
7. Fixed: lab `sha256sum -c` prints `nkp-ubuntu-24.04-release-amd64.iso: OK`; Done-when tagged `[live 2.19.0]` (airgap `SKILL.md:134`).
8. Fixed: `nodes.md:21` is `# USER-TERMINAL  (on a node; the user runs it over SSH)`.
9. Fixed: rule 1 (`RULES.md:16`, synced), GLOSSARY "USER-TERMINAL command", ADR 0003 amendment (b) line.
10. Fixed: A-05 row has the p.82 / p.842 evidence; `nkp-install/SKILL.md:153` gives the documented fallback `nkp get kubeconfig --cluster-name ... > $PWD/<name>.conf` (CHANGES) in place of "stop".
11. Fixed: pool-name rule next to the block (lifecycle `SKILL.md:202`, `[live 2.19.0]`).
12. Not fixed: no PDF page (p.834-848, p.905-920) says that the template must match the Kubernetes version. The row stays `[field]` (`cloud.md:313`).
13. Fixed: `preprovisioned.md:128` is `[pdf p.768-769]`.
14. Fixed: lifecycle `SKILL.md:40` split; `cloud.md:25` split; `preprovisioned.md:113` ("so" → two sentences).
15. Fixed: one `for v in` line per provider (`cloud.md:68-81`).
16. Fixed: new checks `rm-glob` and `grep-secret` (`check_skills.py:60`, with self-tests). On a copy of the old files they flag the old D5 `rm` and the old C9 grep.

**Section 4 (cloud flags not confirmed)**
- vSphere `--registry-mirror-cacert`: found on p.681 (the "all infrastructure providers" chapter). Tag added (`cloud.md:267`).
- `--dry-run` / `--output` for vSphere: found on p.919. EKS and AKS: not in the guide, now `[field]` (`cloud.md:293`).
- `--namespace` and `--kubeconfig` for AWS, vSphere, EKS, AKS workload create: not in the guide. Tags changed to `[field]` with "C1 checks it". The C1 Done-when now names these flags explicitly (`cloud.md:37`). C1 comes before every script.

**Eval fixes**
1. = M5, fixed.
2. Fixed: rule 4 "Write a line only after the user gives or confirms the value. Ask first, and write the line in a later reply, after the answer." (`RULES.md:19`, synced into 4 skills).
3. Fixed: rule 3 "After the cluster env file exists, use its real name (for example `~/nkp-dev-01.env`) in every block that you show." (`RULES.md:18`, synced).
- A8 (NIB walkthrough noise after a Starter stop): not fixed. It is model behavior, not a skill defect.

No new OPEN-ITEMS rows. No new site variables. Re-run E13 and L1 (autoscaler) in the next eval run.
