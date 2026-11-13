# Batch 4 fix pass: kubernetes-core and cross-skill owners

Date 2026-11-03. Scope: `review.md` minors 2 (gitops part), 4 (gitops part), 5, 6, 11, 13, section 5 (identity owns `nkp-deletion-protection`, troubleshooting row, networking pointer), and `grading.md` fix 3.
Checks: `check_skills.py --self-test` and `check_skills.py` pass (13 skills, 0 errors). `bash -n` passes on all command blocks of the changed files (overrides.md 9, kubernetes-core SKILL.md 8, gatekeeper.md 9). The `: "${APP_ID:?}"` guard stops a block with an empty value (tested). `RULES.md` is not changed, so no `--sync`.
Lab (read-only: `get`, `--help`) is logged in `research/raw/live/2.19/kubernetes-core.txt`, section "Batch 4 fix pass (core)".

## review.md

- minor 5 and section 5 fixed. New section G5 in `skills/nkp-identity-security/references/gatekeeper.md:144-170` (title now "Gatekeeper and NKP admission policies"). It has the full rule set from the lab VAP: CREATE/UPDATE/DELETE of all kinds, objectSelector on the label, `failurePolicy: Fail`, binding actions `Deny` and `Audit`; delete only from `revoked`; `strict` cannot change or be removed (so never deleted); `standard` cannot be removed; only a non-`system:` user can change `standard` to `revoked`; "no object had the label on the 2.19.0 lab". It has the three deny messages, a READ-ONLY block (policy, binding, the label of the object with `-L`), and the actions (strict: stop; standard: ask the owner skill, change to `revoked` is CHANGES with a plan by a user). Identity `SKILL.md:7` (description trigger), `:63` (Job → section), `:201` (Common failures) point to G5. `skills/kubernetes-core/SKILL.md:214` is now a one-line pointer.
- section 5: `skills/nkp-troubleshooting/references/deletes.md:64` has the row "delete denied by `validatingadmissionpolicy/nkp-deletion-protection`" → skill `nkp-identity-security` (G5).
- minor 6 fixed. `skills/kubernetes-core/references/networking.md:29` keeps only "`externalIPs` is rejected: use a `LoadBalancer` Service" and points to identity `cluster-security.md` C5 for the admission plugins. Optional pointer added: `skills/nkp-networking/SKILL.md:144` (Common failures row → MetalLB, `metallb.md`).
- minor 11 fixed. The `kubectl api-resources --help` lines for `--api-group` are in `research/raw/live/2.19/kubernetes-core.txt:974+`.
- minor 13 and grading fix 3 fixed. `skills/nkp-platform-apps-gitops/references/overrides.md`: every block that uses `$APP_ID` has `: "${APP_ID:?}"` (O2 :38, O3 :72, :87, :98, :109, O4 :134, O5 :163, O6 :174). Where the block already had a `:?` line, the guard is added to it.
- minor 2 (gitops part) fixed. `overrides.md:18` (O1 table, slot 2) and `:21`: slot 2 applies only to apps whose HelmRelease lists `<app-id>-overrides`; check with O2.
- minor 4 (gitops part) fixed. `overrides.md:21` names `nvidia-gpu-operator-config-overrides` as the second name exception next to `velero-overrides`: the `nvidia-dra-driver` HelmRelease reads it by name; on the management cluster it is in `kommander` (also the HelmRelease namespace), so O5 item 5 does not remove the DRA values; only a ConfigMap delete does. O3 item 3 (`:93`) lists both exceptions.

## Notes

- The check script reads a backtick `nkp-*` word on a line with "skill" as a skill name. So the prose names the policy as `validatingadmissionpolicy/nkp-deletion-protection`. In gatekeeper.md G5 the title and the facts keep the short name (no "skill" on those lines).
- The rule "only a non-`system:` user can revoke" and the deny messages are from the live VAP expressions. A real deny was not tested: no object has the label, and a label change is not allowed on the read-only lab.

## Changes other files need

- gpu-ai `SKILL.md:119` can add one line: only a ConfigMap delete removes `nvidia-gpu-operator-config-overrides` values on the management cluster (gitops O1). Not in my allowed files.
- No eval changed. An eval for G5 ("delete denied by nkp-deletion-protection") can go in `evals/nkp-identity-security.md` in the next run.
