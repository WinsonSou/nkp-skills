# Batch 4 fix pass: nkp-observability

Date 2026-11-03. Scope: `review.md` M2, M3, M5, minors 2 (observability side), 3, 7, 12; section 5 (storage O2 back-pointer); `grading.md` item 1; a new eval for Loki on S3.
Checks: `check_skills.py --self-test` and `check_skills.py` pass (13 skills, 0 errors). `bash -n` passes on all 46 command blocks of `nkp-observability` and `object-storage.md`. I tested the new `dkp-loki` guard of L4 item 3 in `/tmp/b4obs` (`dkp-loki` → stops; a new name → goes on). Line counts: SKILL.md 175, logging.md 389, monitoring.md 350, insights.md 185.
Evidence: the reviewer's extract of the 2.19.0 app tree (`ghcr.io/mesosphere/kommander-applications:v2.19.0`, digest = lab OCIRepository digest) and chart `kube-prometheus-stack` 87.16.0. I read the files again and logged them in `research/raw/live/2.19/observability-skill.txt`, section "Batch 4 fix pass (observability)". No lab access and no dry run in this pass.

## review.md

- M2 fixed (references/logging.md:106-146). Item 2 says that the defaults load `dkp-loki` (the Rook bucket Secret of OBC `dkp-loki`) and that the agent must never write to it; `nkp-loki` is the guide's own-Ceph example. The read block greps `secretRef|dkp-loki|reloader|s3`. Item 3 always makes a **new** Secret: the user gives the name (for example `loki-s3-creds`), `secret=''` keeps its guard, and the block also stops if the name is `dkp-loki`. Item 4 puts the new name in **seven** `extraEnvFrom` entries: the app tree also has `indexGateway`, which the old text and the review missed. The `loki.annotations` Reloader line is now in the values (`annotations: {}` with a comment). The check script rejects the annotation key as an FQDN, so the text tells the agent to copy the key from the item 2 output. The seven entries are in YAML flow form to keep the file under 400 lines.
- M2 D-05 fixed (research/OPEN-ITEMS.md D-05). The default-name question is removed from the open part and recorded as answered (`dkp-loki`, app tree).
- M3 fixed (references/logging.md:360-366). The cap key is `dkp.project-grafana-loki-v3.additionalConfig.maxSize` (default `"5G"`); the guide key `nkp.project-grafana-loki.maxSize` (p.554) is named as not used on 2.19.0. The text names the two HelmReleases and what each reads. It says that retention goes through `configOverrides`, and that the cap path is not confirmed (tell the user the cap can stay at 5G). New UNKNOWN D-34 with a READ-ONLY FROM-list check. L10 item 2 now names the HelmRelease `project-loki-v3-object-bucket-claims` (the old text had `project-loki-object-bucket-claims`).
- M5 fixed (references/monitoring.md:171, :205). Way A starts with "Helm owns this Secret": the chart renders it from `alertmanager.config`, the NKP defaults set it, and each values change (M1, M2, M5, M6) or upgrade puts the default back; do way A again or use way B. D-31 now asks only whether `useExistingSecret: true` keeps a user Secret; "Do not set it without a lab test". OPEN-ITEMS D-31 changed to match. Eval B2 has a second step (an M1 change after way A must warn about the receivers) and two more FAIL items.
- Minor 2 fixed, observability side (references/monitoring.md:14, :16; references/insights.md:17). The slot-2 text is replaced: these HelmReleases do not read the guide name; use the O3 name rule. The D-30 UNKNOWN line in monitoring.md is replaced by the app-tree fact (defaults, then `kube-prometheus-stack-mgmt-overrides` by name; a new `configOverrides` comes after it). OPEN-ITEMS D-30 is partly answered and stays open for a Pro/Ultimate confirmation. The gitops O1 text (slot 2 "for apps whose HelmRelease lists it") is not in my scope.
- Minor 3 fixed (references/logging.md:66-74). L2 keeps only the direct ConfigMap `logging-operator-logging-overrides` on the target cluster (with the evidence and the note that the p.560 way works only in `kommander`). The READ-ONLY FROM-list check stays. It says that this name is the exception to the O3 name rule. D-32 moved to Closed in OPEN-ITEMS.
- Minor 7 fixed (references/logging.md:35, :44; SKILL.md:166). "On a healthy 2.19.0 cluster" → "Seen on 2.19.0 when no Loki v2 was ever installed"; "with Loki v3 running it is not tested [field]". Eval B6 Expected changed to match.
- Minor 12 / grading item 1 fixed (references/insights.md:113-116). The example tag is the bundle tag `0.64.1-20260929T031542Z` with the comment "change the date part to the new tag".

## Section 5

- Storage O2 back-pointer added (skills/nkp-storage-backup/references/object-storage.md:72): "Loki retention and store, and the project Loki cap: skill `nkp-observability` (file `logging.md`, L3-L4, L10)." No facts copied. I added L10 because the project Loki cap is owned there (M3).

## Evals

- New B9 (evals/nkp-observability.md:106): Loki on S3 / Nutanix Objects. The user asks to put keys in `dkp-loki`. Expected: no key from the chat, `printenv` checks only, never write `dkp-loki`, ask for a new Secret name, rule 4 for the name and `LOKI_S3_URL`, seven `extraEnvFrom` entries plus the annotation.
- B2: second step and FAIL items (M5). B6: narrowed expectation (minor 7).

## OPEN-ITEMS rows

- D-05 changed (default Secret answered). D-30 partly answered. D-31 reduced to `useExistingSecret`. D-32 closed. D-34 new (project Loki bucket cap path). The "Last updated" line is not changed.

## Changes other files need

- Gitops `overrides.md` O1/O3 (review minor 2, 4, 13): slot 2 only for apps whose HelmRelease lists the name; name exceptions now include `logging-operator-logging-overrides` (L2) as well as `velero-overrides` and `nvidia-gpu-operator-config-overrides`; the `APP_ID` guard.
- Not checked: L4 and L10 on a running Loki (the lab is Starter). Re-run B2, B3, B6, B9 in the next eval run.
