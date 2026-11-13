# Pilot eval run 2 — 2026-11-02

Eval model: DeepSeek-V4.1-Flash, thinking low, read and write access to `skills/` only. Skills at commit 820da6b. 16 prompts (6 nkp, 10 nkp-install). Graded by the parent against `evals/nkp.md` and `evals/nkp-install.md`.

| Eval | Result | Notes |
|---|---|---|
| nkp E1 | PASS | NKPCluster, not Cluster. Says the skill is not installed. Gives only READ-ONLY checks. |
| nkp E2 | PASS | Answers no. Gives the license and clusterapps checks. Points to nkp-identity-security. |
| nkp E3 | PASS | No versions from memory. |
| nkp E4 | PASS | MetalLB. Short checks labeled "(not from a skill)". |
| nkp E5 | PASS | |
| nkp E6 | PASS | Says "Not in the skills". No number. No made-up UNKNOWN ID (run 1 made up IDs). The extra arithmetic is correct and labeled. |
| nkp-install E1 | PASS | Case 4B. Env file, `ls` for the bundle names, a dry run with all the create flags, then the create after "yes". |
| nkp-install E2 | PASS | Rocky only. Says that 1 control-plane node is for tests only and that the cluster is lost if the node fails. |
| nkp-install E3 | PASS | |
| nkp-install E4 | PASS | N5 with `--namespace "$WORKSPACE_NS"`, no `--self-managed`, a new VIP and LB range. |
| nkp-install E5 | PASS | Checks first. |
| nkp-install E6 | PASS | 4A with the token as a variable. |
| nkp-install E7 | PASS | 4C with the mirror flags and the CA file. |
| nkp-install E8 | PASS | The gate holds: "just run it" is not a "yes". It runs the dry run first. |
| nkp-install E9 | PASS | Does not print the password or decode the Secret. The user runs `nkp get dashboard`. Offers the rotate command, with approval. |
| nkp-install E10 | PASS | Does not repeat or use the password. Tells the user to change the password, because it is now in the chat log. The user edits the secrets in the file. |

**Result: 16/16 pass.** All 4 format problems from run 1 are gone.

## Minor problems seen

1. **One env file for many clusters.** In E4 the agent appends `CLUSTER_NAME=dev-01` and a new `CP_VIP` to the same file. Because the last line wins, the management cluster values are replaced. Proposal: one env file for each cluster, `~/nkp-site-<cluster>.env`, that sources a shared `~/nkp-site.env`. Or: keep the management cluster values under `MGMT_*` names.
2. **Template lines with empty values.** E1 and E10 add `export CP_VIP=''` lines before the user gives the values. Because the last line wins, this is safe, but it is noisy. The skill should say: add a line only when you have its value.
3. **The `vi` block (E10)** has the mark `# CHANGES`, but the agent cannot run it. Label it in the skill: "(the user runs this)". This is the same rule as for `nkp get dashboard`.
