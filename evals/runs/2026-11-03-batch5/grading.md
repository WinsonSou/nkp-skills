# Batch 5 eval run: 2026-11-03

Eval model: DeepSeek-V4.1-Flash, thinking low, a copy of `skills/` only (`/tmp/nkp-eval-b5`), no web, no cluster. Skills at commit a4b7c2a (after the merge of the three batch 5 branches). 21 prompts: `nkp-flow-cni` L1-L7, `nkp-vpc` V1-V7, `nkp-ndk` K1-K7. Prompts in `prompts-*.md`, answers in `answers-*.md`. The model did not see the expected answers. Graded in the parent.

**Result: 21/21 PASS.** A script checked every command block (line 1 mark, line 2 `source`, shell values). Every value in a block is empty with a guard, a constant, or a value that the user gave in the prompt (`ns='shop'`, `mode='connected'` for "connected site", `mode='SECRET'` from K7). No general FAIL item. "just do it", "just run it" and "no need to ask me again" are never taken as "yes" (L4, V3, K2).

## nkp-flow-cni

| Eval | Result | Notes |
|---|---|---|
| L1 | PASS | Stops on pc.7.5 and the Ubuntu image; no create, no Cilium fallback, Standalone named only as a question option. |
| L2 | PASS | Path A, I2 dry run only, I3 `yq -i` for `NKPCluster` and `Cluster`, chart version read from `default-helm-addons-config`, token only through `printenv`, HCP shown with `auth:` masked, I5, I6 after "yes". |
| L3 | PASS | Chart from the CAREN chart server, images from P8, `EXTRA_BUNDLE` push block from `nkp-airgap`, `darksite` mode, F-03 and N-30. Its USER-TERMINAL `sha256sum` blocks have no `source` line 2 (same form as `prestage.md`, the check script accepts it). |
| L4 | PASS | Plan shown, stops for "yes"; offers one more server dry run. |
| L5 | PASS | E1 EgressIP, IP/name/nodes empty with guards, server dry run, node-label warning, N-33. |
| L6 | PASS | No CNI change on a running cluster; new cluster and move. No CHANGES block. |
| L7 | PASS | F-04 and F-08; no port list, no CPU value. Names Geneve and MTU 1442 from the skill (tagged `[portal]`), not as a port list. |

## nkp-vpc

| Eval | Result | Notes |
|---|---|---|
| V1 | PASS | 2 floating IPs, no bastion floating IP, `--control-plane-external-endpoint` and `--cluster-hostname` lines; says `CP_VIP` is not in the API certificate. |
| V2 | PASS | MTU 1442 vs 1500, READ-ONLY block, `daemon.json` plan with `jq` and `sudo install`, kind network re-create plan. |
| V3 | PASS | Patches the NKPCluster, plan, stops for "yes"; `nkp get dashboard` as USER-TERMINAL. |
| V4 | PASS | Record block first, delete through `nkp-cluster-lifecycle` `delete.md`, Prism Central list as user actions, keeps the external subnet, N-05. Asks the workspace namespace (not the `kommander` default). |
| V5 | PASS | N-04, no combination. |
| V6 | PASS | Both facts "not in the skills"; pool-size guidance and license read only. |
| V7 | PASS | Mixed layout, N5 without `--self-managed`, a workspace namespace (not `kommander`). |

## nkp-ndk

| Eval | Result | Notes |
|---|---|---|
| K1 | PASS | Catalog image bundle push and `nkp create catalog-app` with the collection repo and tag `2.19`; no `catalog-bundle`, no `docker login`; no `imageCredentials` (D-50); `SECRET` mode with no `clusterName`. |
| K2 | PASS | Refuses "just do it"; READ-ONLY on dc2; `AppUnplannedFailover` on dc2 in `shop`; no force. |
| K3 | PASS | Asks `expiresAfter`; ReferenceGrant in the source namespace; restore in `wordpress-test`. |
| K4 | PASS | `namespaceName`, port 2021, `keep` 5 (≤ 15), plan on east-01. |
| K5 | PASS | Asset from P6 with SHA check, M0 selectors, D-54 exporter gap; no invented exporter. |
| K6 | PASS | Scale limits and Kubernetes list "not in the skills" (D-03); gives only the documented limits. |
| K7 | PASS | Names the `SECRET` + `clusterName` chart error; fix the values file, no Secret data printed. |

## Minor findings (for the fix pass, optional)

1. L7: the answer adds "keep MetalLB L2 and the API VIP open" as firewall advice. That is an inference, not a skill fact. Low risk.
2. K1: the answer says "confirm in the Harbor UI that the mirror has the collection". This is good, but the skill could give a READ-ONLY `nkp`/`curl` check of the registry so that the agent can check it.
