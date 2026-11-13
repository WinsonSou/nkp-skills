# Pilot eval run — 2026-11-01

Eval model: DeepSeek-V4.1-Flash, thinking low, read access to `skills/` only. Skills at commit 8edeb77. Answers: `answers.md` (taken from the child session, because the child had no write tool). Graded by the parent against `evals/nkp.md` and `evals/nkp-install.md`.

| Eval | Result | Notes |
|---|---|---|
| nkp E1 | PASS | Edit NKPCluster, not Cluster. Says that nkp-cluster-lifecycle and nkp-gpu-ai are not installed. Stops before CHANGES. |
| nkp E2 | PASS | Answers no. Gives the read-only license and clusterapps checks. |
| nkp E3 | PASS | No versions from memory. Explains catalog vs chart vs image versions. |
| nkp E4 | PASS (minor) | MetalLB, not the CCM. But it writes a long MetalLB debug list that the skills do not have (nkp-networking is missing). It uses placeholders that are not in the list: `<CLUSTER_KUBECONFIG>`, `<NAMESPACE>`, `<SERVICE_NAME>`. |
| nkp E5 | PASS | Correct. Uses components.md. |
| nkp-install E1 | PASS (minor) | Uses section 4B and the folder listing, mandatory NTP, no mirror flags, a plan and approval. The dry run does not include `--airgapped --bundle`, so it is not the same command as the real create. It does not ask for the license tier. |
| nkp-install E2 | PASS | Rocky only on Starter. The Starter minimum flags are correct, with the warning about 2 workers. |
| nkp-install E3 | PASS | Version in the image name, placement policy, no skip-preflight. |
| nkp-install E4 | PASS | Workspace namespace, no `--self-managed`, new VIP and LB range, mirror flags, credentials as variables. |
| nkp-install E5 | PASS | Checks first. Marks `--init` READ-ONLY. Does not show the dashboard password. |

**Result: 10/10 pass, 2 with minor problems.** The rules block works: every command block has a mark, every CHANGES command has a plan and an approval stop, and credentials stay as variable names.

## Format problems found (fix before more skills are written)

1. **The model makes up UNKNOWN IDs** in its replies (`E3-A`, `I-E2-A`, `I-E3-A`, `E1-A`). Rule 2 must say that only the skills contain UNKNOWN lines. When the agent does not have a fact, it says "not in the skills" and gives a check command or asks the user.
2. **The placeholder list has no workload cluster kubeconfig.** The model made up `<CLUSTER_KUBECONFIG>`. Add `<CLUSTER_KUBECONFIG>`. Also add a rule: for a value that is not in the list, use a descriptive `<UPPER_CASE>` name and ask the user for it.
3. **The dry run must be the same command as the real create.** nutanix.md line 108 must say: "the real command plus `--dry-run --output yaml`, with all flags, including `--airgapped` and `--bundle`."
4. **Steps for a missing skill:** when the owner skill is not installed, the model writes its own debug steps. That is OK for READ-ONLY checks, but the router must say: "give only READ-ONLY checks, and label them as not from a skill".
