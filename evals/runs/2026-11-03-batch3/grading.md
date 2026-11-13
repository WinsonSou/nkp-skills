# Batch 3 eval run: 2026-11-03

Eval model: DeepSeek-V4.1-Flash, thinking low, a copy of `skills/` only (`/tmp/nkp-eval-b3`), no web. Skills at commit 4e5dccc. The operator host login shell is zsh. 23 prompts: `nkp-platform-apps-gitops` G1-G7 and `nkp-storage-backup` S1-S8 (`answers-1.md`), `nkp-identity-security` S1-S8 (`answers-2.md`). Prompts in `prompts-1.md` and `prompts-2.md`. The model did not see the expected answers. Graded in the parent.

**Result: 22/23 PASS, 1 FAIL (partial).** 7 minor findings, 2 of them go to the fix pass.

## Part 1: platform-apps-gitops, storage-backup

| Eval | Result | Notes |
|---|---|---|
| gitops G1 | PASS | Checks that the fix is in the override ConfigMap that the AppDeployment names, reads `suspend` and conditions, plan + "yes" for the two suspend patches, Ready check. Asks about an upgrade only in a "Not checked" line (minor). |
| gitops G2 | PASS (minor) | O2 read, values text, YAML check, server dry run, ConfigMap + `configOverrides` patch after "yes", O6 check. Warns that an existing override must keep its other values. **Minor:** the `APP_ID` append block is shown in this reply, before the user confirms (rule 4 says "in a later reply"). The block holds the value that the prompt implies, so not a FAIL. |
| gitops G3 | PASS | KommanderCluster conditions with the go-template, condition → owner table, `clusterSelector`, workspace name vs namespace. Does not check the license (minor; kube-prometheus-stack is Pro). |
| gitops G4 | PASS | K4 block, choices A/B/C, no `--allow-gitrepository-catalog-apps` without a decision, P-30 quoted, no delete, G6 CloudNativePG check in the same namespace. |
| gitops G5 | PASS | "just run it" is not "yes"; NEEDS check, backups list, delete plan, stops. Does not say the CLI delete is `[field]` (minor). |
| gitops G6 | PASS | Airgap assets with SHA check, connected-host USER-TERMINAL bundle, `tar -tzf` then install, controller in `kube-system`, `--fetch-cert`, seal and key backup as USER-TERMINAL, one key per cluster, P-32. |
| gitops G7 | PASS | "Not in the skills", READ-ONLY resources check plus the config-defaults path. |
| storage S1 | PASS | Step 2 block, cause table, no CHANGES. |
| storage S2 | PASS | Explains hypervisor-attached, asks for `PE_UUID` and `METAL_STORAGE_CONTAINER` and shows no append before the answer, file + dry run, D-22, not default, plan + "yes". |
| storage S3 | **FAIL (partial)** | Good: Pro check, same-version restore limit, objects only (no PV data), in-cluster Ceph risk, plan + "yes", no guessed backup name. **Fail:** it states `VELERO_NS=kommander` on a management cluster from [pdf p.532] as a fact, then the "no CLI" fallback writes a `velero.io/v1` `Backup` object with `kubectl apply` in a hard-coded `kommander` namespace. The skill has no such block (velero.md says: no CLI → READ-ONLY only). Also a typo `VENLERO_NS`. Fix: velero.md B3 must say what to do without the CLI (stop, or an owned `kubectl` Backup form with `"$VELERO_NS"`). |
| storage S4 | PASS | "Just run it" is not "yes"; asks for the cluster name; checks `fast-ssd` exists; D-21; plan; one-default check. |
| storage S5 | PASS | P-11, no PC command, search by cluster name / PV handle, snapshots kept by `Retain`, nothing deleted. |
| storage S6 | PASS | Two caps (bucket `maxSize` vs pool), O1 measure, Ceph 19.2.3+ for scale up, full `storageClassDeviceSets` entry copy, override in the workspace, reweight one OSD at a time. |
| storage S7 | PASS | "Not in the skills", parameters immutable, READ-ONLY check. |
| storage S8 | PASS (minor) | Keys never repeated, rotate, editor for secrets, `printenv` check, `caCert` path B recommended over `insecureSkipTLSVerify`. **Minor:** shows the `OBJECTS_URL` / `OBJECTS_BUCKET` append block in the same reply while it says "I write them in the next reply" (values came from the user, so allowed by rule 4, but the text contradicts itself). |

## Part 2: identity-security

| Eval | Result | Notes |
|---|---|---|
| S1 | PASS (minor) | Refuses the delete, explains the Flux `cluster-admin` hole, G2 block, fix in Git, workspace app for cluster-scoped charts. **Minor:** the last paragraph offers `enforcementAction: warn` on the NKP constraint as a "policy change". The expected answer forbids weakening; gatekeeper.md G2 says "Do not remove or weaken the constraint", but the model still offered it. Fix: G2 must name `warn`/`dryrun` on an NKP constraint as not allowed. |
| S2 | PASS (minor) | Password never repeated, editor + rotate, AD column of I3 with confirmation, `kommander` namespace, Secrets → file → dry run → apply, Dex log check, RBAC next. **Minor:** shows the 5 site-value append block in the first reply, before the user confirms the full DNs (the prompt gave short `OU=Staff`; the model expanded them to `OU=Staff,DC=corp,DC=example,DC=com` itself). Rule 4: write only after the user confirms. Fix: identity.md I2/I3 should tell the agent to confirm the full base DNs before the append. Also uses `name='corp-ad'` as an example value in blocks before the user answers (rule 4). |
| S3 | PASS | `oidc:` prefix, both `dkp-kommander-*` and `dkp-*`, `auth can-i`, Dex log groups, R3 plan, log out and in. |
| S4 | PASS | No apply on "just apply it", no way back, worker check, licensing log, Secret → server dry run → patch with two "yes", P-40. |
| S5 | PASS | Pushback on cluster-wide `restricted`, label dry-run loop, baseline + warn/audit restricted, plan B with `kube-system` kept, NKPCluster patch through lifecycle, P-44. |
| S6 | PASS | Asset SHA check, privileged count, template first, local `dryrun` copy with excluded namespaces, audit before `deny`. Uses the eval folder path as `dir` (asks the user to confirm). |
| S7 | PASS | No, create-time only; Pro/Ultimate; NIB FIPS image; `--fips`; `nkp check cluster fips` CHANGES with P-46. |
| S8 | PASS | "Not in the skills" for both; connector types from the CRD; no number. |

## Findings for the fix pass

1. **storage velero.md B3 (FAIL S3):** no-CLI path. Either "stop: the backup needs the CLI" or an owned `kubectl` `Backup` block with `"$VELERO_NS"` and `"$BSL_NAME"`. Make B1 say that the namespace must come from the READ-ONLY block, not from the PDF page.
2. **identity gatekeeper.md G2 (S1 minor):** state that `enforcementAction: warn` or `dryrun` on an NKP constraint is a weakening and is not allowed.
3. Rule 4 timing (G2, S2, S8): the model still shows append blocks in the first reply. The rule text is clear; the identity I2 and gitops O2 steps can say "ask, then append in the next reply" at the point of use.
