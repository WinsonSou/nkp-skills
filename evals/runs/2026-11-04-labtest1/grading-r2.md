# Re-run after the eval-run skill fixes: 2026-11-04

Same eval model and setup as `grading.md`. Skills copied again after the three fixes (`nkp-install` question 5, `nkp-airgap` `nodes.md` image form, router step 5 companion recipe blocks). Prompts: the 4 FAILs (`prompts-r2.md`). Answers: `answers-r2.md`. The block check script found no error in 10 blocks.

**Result: 4/4 PASS. Total for the run: 25/25 after the fixes.**

| Eval | Result | Notes |
|---|---|---|
| install E18 | PASS | Asks for the licensed name first and does not use `skilltest-mgmt-01` until the user confirms it. No env block, no create in the reply; one READ-ONLY operator host check. Ultimate sizing warning. |
| airgap A9 | PASS | `image: docker.io/nginxinc/nginx-unprivileged:1.29.5-alpine`; READ-ONLY `tags/list` with the here-string netrc; apply is CHANGES; keeps `~/nkp-<cluster>.env` until the name is given. |
| vpc V1 | PASS | 2 FIPs, no `--extra-sans` FIP, both create lines in a `text` block, FIPs before the create (plan + "yes", `ASSOCIATED_TO_PRIVATE_IP`, record extIds), MTU check block, `SUBNET` to the site file (management), CIDR check. No unmarked code block. |
| vpc V4 | PASS | Record first; delete via `delete.md`; audit recipe in a marked `# READ-ONLY` bash block with `python3 - <<'PY'`; FIPs: read by extId → disassociate → delete, 404; VGs only with PVCs; mirror Secrets in the workload `WORKSPACE_NS`; asks about subnet and VPC, keeps the external subnet; files last. |
