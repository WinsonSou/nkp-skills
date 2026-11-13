I reviewed the pilot at commit 8edeb77 and changed no files. Both runs of the check script pass, but they do not check the main rule: a command block with no mark passes. One fix for the main install path cannot wait (B1). The format verdict is **go-with-changes**: nine format changes must go in first (list at the end).

**How I checked:**
- Both script runs exit 0 (`--self-test` and the full check). I also gave the script test inputs to find the edge cases in §6.
- I checked each flag against `research/raw/live/2.19/nkp-help-*.txt`.
- I checked each page tag against `research/raw/pdf/2.19/` by page.
- I compared every live tag with the live files (`nkpcluster.txt`, `bundle-layout.txt`, `versions.txt`, `namespaces.txt`, `kommander.txt`, `clusterapps.txt`).

**Not checked:**
- I did not run anything on the lab cluster.
- I did not re-run the evals. I read the uncommitted `evals/runs/2026-11-01-pilot/grading.md` and use its results where they apply.
- Some answers need a lab test (B1, M5, M6). Until someone does that test, those items are open.

## Findings (ranked)

### BLOCKER

**B1. You cannot follow the main path to a management kubeconfig.** Files: `nkp-install/SKILL.md:114-118, 142-150` and `references/nutanix.md:171-180`.
- **Problem 1, wrong order:** `nutanix.md` "After the create" sends the agent to SKILL.md step 5. Step 5 runs `kubectl --kubeconfig <MGMT_KUBECONFIG>`. But the bullet that gets the kubeconfig comes after it.
- **Problem 2, unknown source:** after `--self-managed`, the bootstrap cluster is deleted. `nkp get kubeconfig --cluster-name … --namespace kommander` has no `--kubeconfig`, so it uses default discovery. On a new bastion, nothing gives it a kubeconfig. None of the evidence says how the operator first gets the management kubeconfig.
- **Problem 3, write or read:** `nkp --help` says `get kubeconfig` will "Retrieve cluster kubeconfig and modify local kubeconfig file" (`nkp-help.txt:126`). That means the READ-ONLY mark may be wrong.
- **Problem 4, two names for one file:** step 6 uses `<MGMT_KUBECONFIG>` and `<CLUSTER_NAME>.conf` for the same management cluster. It never says that they are the same file.
- **Fix:**
  - Move "Get the kubeconfig" before the pointer to step 5.
  - Add `UNKNOWN (<new ID>): where the management kubeconfig comes from after a --self-managed create. Find out with: ls *.conf; read the create output` and close it with a lab test.
  - After that, say "`<MGMT_KUBECONFIG>` = `<CLUSTER_NAME>.conf`".

**B2. Two problems with credentials, and both will copy into the 14 new skills.**
- **The `read` block is wrong.** At `nutanix.md:26-30`, the `read -r -p` / `read -s` block is marked `READ-ONLY`, so the agent can run it. An agent cannot type into an interactive `read`, so the command hangs. Also, `read` is not a read-only command: it sets the shell environment.
- **No execution model.** Rule 4 says "The user exports them in the shell". It does not say whose shell. If the user exports the values in their own terminal, the agent's shell does not have them. Then `nkp create cluster` runs with an empty `$NUTANIX_PASSWORD`, or the agent asks for the password in the chat.
- **Missing export steps.** `$NUTANIX_REGISTRY_USERNAME`, `$NUTANIX_REGISTRY_TOKEN`, `$REGISTRY_MIRROR_USERNAME` and `$REGISTRY_MIRROR_PASSWORD` (lines 117-118 and 163-164) have no export step.
- **Fix (format):**
  - Add a third mark, `# USER-RUNS` ("the user runs this in their own terminal; you do not see the output"). Use it for commands that need secrets or typed input, or that print secrets (`nkp get dashboard` too).
  - Say in rule 4 that a CHANGES command which needs credentials also runs in the user's terminal, unless the user confirms that the variables are set in the agent's shell (`test -n "$VAR" && echo set`).
  - Add one export step for each credential set.

### MAJOR

**M1. The check script does not check the main design rule.** File: `scripts/check_skills.py`.
- I gave it a skill with a bash block `kubectl delete ns kommander` that has no mark, the placeholder `<FOO_BAR>`, the IP `10.1.2.3`, and the pointer "use skill `nkp-airgapp`". The result was `[]` (it passed).
- **Fix:** add these checks:
  - The first line of each ` ```bash ` block is `# READ-ONLY` or `# CHANGES` (or `# USER-RUNS`).
  - Each `<UPPER_CASE>` token is in the list.
  - IPv4, FQDN and token patterns, with an allowlist (`192.168.0.0/16`, `10.96.0.0/12`).
  - Each `nkp-*` name in the text is in the router table.
  - The UNKNOWN form is correct, and its ID exists in `research/OPEN-ITEMS.md`.
  - The description has a word limit.
  - Add a self-test case for each new check.

**M2. Commands with `...` in place of flags, and the dry run is not the same command.** File: `nutanix.md:108, 116, 148, 159, 202`.
- The CHANGES blocks have `...` and "(common flags from section 4)" in place of real flags. A small model must merge them. The eval already showed that its dry run dropped `--airgapped --bundle` (grading.md item 3).
- **Fix (format):** each CHANGES block holds one complete command that the agent can copy. Write 4A, 4B, 4C and 5 out in full (about 60 more lines; `nutanix.md` stays under 400). Make the dry run "the same command plus `--dry-run --output yaml > <CLUSTER_NAME>.yaml`".

**M3. Two different choices in one block.** File: `nkp-install/SKILL.md:123-127`.
- The air-gapped `--init` and the connected `--init` are in one READ-ONLY block, and both write `> kommander.yaml`. If the agent runs the block, the second line overwrites the first.
- The manual-flow block (`SKILL.md:88-95`) puts five CHANGES commands, including `nkp delete bootstrap`, under one approval with no check between them.
- **Fix (format):** one choice per block, with a label. One CHANGES command per block, and each block ends with a "Done when:" check.

**M4. Steps have no completion criteria, and step numbers are the same in two files.**
- Steps 1 to 4 in `nkp-install/SKILL.md` have no "done when" line. Step 3 is reference content, not a step.
- `SKILL.md` "Step 5/Step 6" and `nutanix.md` "§5 workload / §6 verify" use the same numbers. The text "Go to step 6" can send the agent to the wrong file.
- **Fix (format):** every step ends with `Done when: <command> → <expected output>`. Use different labels in the provider file (for example `N1`…`N7`), or refer to a step by its name.

**M5. Cilium on EKS is written as a fact, but the open items list it as open.**
- `components.md:54` says "default CNI on AHV and EKS".
- `OPEN-ITEMS P-05` says this is open, and live evidence shows only the enum.
- `components.md:55-56`: Calico (`calico-system`) and Flow CNI (`flow-cni-system`) sit under the `[live 2.19.0]` table tag, but neither was seen live.
- **Fix:** EKS → `UNKNOWN (P-05)`. Give the Calico and Flow rows their own `[pdf p.N]` or `[field]` tags.

**M6. A fact is in two owner skills.**
- The router owns "license tiers" (`nkp/SKILL.md:37`, description line 6), and `nkp-identity-security` owns "licenses" (`:45`).
- FIPS is in nkp-install (`SKILL.md:108`, `nutanix.md:104`) and `nkp-identity-security`.
- The bundle file names and versions (`nutanix.md:135`) are a fact that nkp-airgap owns (ADR 0001), and they will be wrong at the next release.
- **Fix:**
  - Licenses: the tier matrix → `nkp`. Applying or changing a license → identity-security. Write that split in the table.
  - FIPS: keep only "`--fips` needs a FIPS image; set at create time", with a pointer.
  - Bundle names: keep only `ls` plus the `--bundle` rule from `--help` ("konvoy + kommander mandatory").

**M7. Placeholders that are not in the list.**
- Tokens not in the list: `<provider>`, `<provider flags>`, `<case flags>`, `<dir with free space>` (a site value, in a command at `SKILL.md:63`), `<host>`, `<registry-host>`, `<project>`, `<name>`, `<node>`, `<infra>`, `<nkp-version>`, `<addon>`, `<cluster-uid>`. Also `<CLUSTER_KUBECONFIG>` is missing, so the model made it up (grading.md item 2).
- **Fix (format):** `<UPPER_CASE>` = a site value from the list; ask the user for it. `<lower-case>` = a name pattern in prose only, never in a command block. Add `<CLUSTER_KUBECONFIG>` and `<TMPDIR_PATH>`. Rule: for a site value that is not in the list, make an `<UPPER_CASE>` name and ask the user for it.

**M8. The UNKNOWN format is not tested.**
- The pilot has 0 UNKNOWN lines. Unknowns are written as prose instead:
  - `nutanix.md:206` (a workload cluster when the management cluster used 4B)
  - `nutanix.md:101` (`--additional-trust-bundle` encoding: help says "CA trust bundle", the pdf at p.719 says Base64)
  - `SKILL.md:33-35` ("Not written yet")
  - B1
- The eval model made up IDs (`E1-A`, `I-E3-A`).
- **Fix:**
  - Rule 2: "Only skills contain UNKNOWN lines. Use only the IDs written there. If a fact is not in the skills, say 'not in the skills' and give a read-only check or ask."
  - Make each prose unknown above a correct UNKNOWN line. Open the IDs in OPEN-ITEMS.

**M9. No rule for local changes on the operator host.**
- `docker load` and `nkp create bootstrap` are CHANGES.
- `--init > file` and `get kubeconfig > file` are READ-ONLY.
- `nkp rotate dashboard-credentials` (`SKILL.md:167`) and "Delete and create the cluster again" (`nutanix.md:243`) are inline text with no block, so no gate applies.
- The glossary defines CHANGES only for the cluster, the infrastructure and the registry.
- **Fix:** define in rule 1: "CHANGES = changes a cluster, infrastructure, registry, or the operator host's container engine; writing a new file in the working folder is READ-ONLY". Put every command in a block. No inline commands that change state.

**M10. The router fallback lets the model make up steps.**
- `nkp/SKILL.md:30` says "answer only from this map and from read-only commands".
- The model then wrote long MetalLB debug steps (grading.md items 4 and 5).
- `SKILL.md:33-35` tells the agent to work from `--help` for Metal, pre-provisioned and cloud. That invites CHANGES commands taken from `--help`.
- **Fix:** "Give only READ-ONLY checks. Label them `(not from a skill)`. Give no CHANGES command."

### MINOR

Facts and tags:

| Where | Problem | Correct value / source |
|---|---|---|
| `nkp-install/SKILL.md:48` | "kubectl 1.36.x. The bundle has a `kubectl` binary" suggests the bundle kubectl is 1.36 | The bundle kubectl is **v1.37.2** [live `versions.txt`, `nodes.txt`]. pdf p.50 asks for 1.36.x. Say both. |
| `SKILL.md:108` FIPS `[pdf p.724]`; `nutanix.md:104` `[pdf p.722]` | Wrong pages: neither says FIPS cannot change | pdf p.987 ("cannot change the FIPS status") |
| `nkp/SKILL.md:81` | Workload NKPCluster in a workspace namespace is tagged `[live]`, but the live cluster has no workload cluster | `[pdf]` (`nkp get kubeconfig -n <WORKSPACE_NAMESPACE>`, 0690/0843 sections) |
| `nkp/SKILL.md:89` | "ClusterClass for AHV, Metal, EKS" `[pdf p.1016]` | pdf p.1018-1025: ClusterClass = AHV and EKS. The pdf does not name Metal. Live has `nkp-aws-v2.19.0` and `nkp-host-agent-v2.19.0` classes, so "AWS does not use ClusterClass" needs a qualifier. Add an UNKNOWN for Metal/AWS. |
| `components.md:26` | "deprecated in 2.18" sits under the `[live]` tag | Live cannot show a deprecation. Use the map or pdf tag. |
| `nutanix.md:22` | PC project row leaves out "you cannot change the project later" | pdf p.1016 |
| `nutanix.md:241` | konnector-agent `Init` fix leaves out "on PC 7.3, upgrade karbon-core to 2.10.2" | pdf p.724 |
| `nutanix.md:137-141` | `docker load` works, but it is an extra CHANGES step | `--bootstrap-cluster-image <BUNDLE_DIR>/konvoy-bootstrap-image-v2.19.0.tar` accepts a file path [live help]. That removes one CHANGES step. |
| `nutanix.md:108` | "That is READ-ONLY" for `--dry-run` together with `--self-managed --bundle` | Help says "Only print the objects…" [live]. Tag it, and note pdf p.729 (a self-managed dry run needs manual pivot steps). |
| `nkp/SKILL.md:56` `[pdf p.20]`, `SKILL.md:105` `[pdf p.718]` | Tags on facts that do not change: noise | Remove them |
| `SKILL.md:132` | Source tag inside a code block | Move it to the prose |

Design and usability:
- **Repeated content in `nkp`:** the namespace table (`nkp/SKILL.md:128-136`) repeats `components.md:5-30`. The Pro and Ultimate app lists (`SKILL.md:103-104`) repeat `components.md:82-83`. Keep one copy of each.
- **Rules block position:** `RULES.md:3` says "directly after its front matter". Both skills put an H1 between the front matter and the block. Change the text, or have the script check the position.
- **Rule 3** is one 74-word line. Make it a 2-column list. The rules block uses about 10 lines of the 250-line budget.
- **`nkp-install` description:** "connected or air-gapped" and "Provider files: …" are padding, and "air-gapped" competes with nkp-airgap. Cut both.
- **Router phrasing (`nkp/SKILL.md:30`):** "If the skill folder does not exist" assumes the agent can see folders. Write "If the skill is not in your skill list".
- **`nutanix.md` §1 table** mixes required and optional values ("Do not continue until you have all values for the chosen case"). Add a Required column for each case. NTP is required only on an air-gapped site, but `--ntp-servers` is in the common flags for every case.
- **Weak pass checks:**
  - `ping -c 2 <CP_VIP>` "no reply = free" is weak when ICMP is blocked. Say that.
  - `SKILL.md:149`: `grep -v 'Running|Completed'` passes pods that are Running but not Ready.
- **Ambiguous workload checks:** step 6 for a workload cluster ("use `<WORKSPACE_NS>`") does not say which commands change.
- **Negation as guidance:**
  - `SKILL.md:107` names `--skip-preflight-checks` before the positive action. Lead with "fix the value from the `Flag:` line and run the create again".
  - "Never reuse", "Never both" and "Do not rename" are acceptable guardrails, but put the positive target first.

ASD-STE100:
- **Passive voice:** "The tier is licensed by core" (`nkp:98`), "the bundle must be extracted" (`SKILL.md:64`), "Kommander is installed for you" (`SKILL.md:112`, `nutanix.md:174`), "More LB IPs are needed" (`nutanix.md:37`), "is not trusted" (`nutanix.md:13`).
- **Long sentences:** `nkp:56` has 31 words; `nutanix.md:206` has 24.
- **More than one instruction in a sentence:** rule 1 ("show the plan … and wait"), `nutanix.md:101` (three instructions in one bullet), `nkp:30`.
- **Vague words:** "slow site" (`SKILL.md:137`), "a known bug" (`:107`), "key values" (`nutanix.md:108`), "If `/tmp` is small" (`SKILL.md:63`; give the check, for example `df -h` shows less than N GB).

Safety and scrub:
- **Skills are clean.** No IPs, hostnames, cluster names or secrets in `skills/`.
- **Passwords on the command line:** `--nutanix-registry-password "$…"` puts the secret in the process list. The CLI has no env-only option for it in `--help`. Note the risk.
- **Files that hold credentials:** rule 4 covers Kubernetes Secrets only. Add "never print a kubeconfig file". `nutanix.md:178` correctly says the file holds credentials.
- **Destructive fix with no gate:** "Delete and create the cluster again" (`nutanix.md:243`) has no block, no gate, and no pointer to nkp-cluster-lifecycle.
- **Scrub in evals:** `evals/*.md:3` has `<lab-provider>/...`, and the lab prefix is the prefix of the lab cluster name. These are repo-internal files, but AGENTS.md says to scrub the cluster name.

Check script (`--self-test` and the full check both exit 0):
- **CRLF is not a problem.** `read_text` uses universal newlines, so CRLF passes.
- **BOM:** a file that starts with a byte-order mark gives a false "front matter missing".
- **YAML block lists:** `nkp_versions:\n    - '2.19'` gives a false "metadata.nkp_versions missing". The list line is appended to `top["metadata"]`. Support block lists, or forbid them and give a clear error.
- **Metadata types:** metadata values are lists (`["2.19"]`). Some Agent Skills loaders expect string values. Use strings.
- **No name format check:** the script does not check the name format (lowercase-hyphen, ≤64 characters) or the description length (≤1024 characters).
- **Link check is narrow:** `LINK_RE` checks only `references/` and `assets/`. Links to other skills (`../nkp-x/`) are not checked.
- **Self-test is too weak:**
  - `self_test` prints "6 errors" and "synced …" while it passes, which is confusing. Capture or silence that output.
  - It does not test a missing marker, a missing front matter in `check_skill`, or `sync` on a file with no markers.
  - `assert check(root) == 1` passes for any reason. Assert the exact set of errors.

Evals:
- **Expected answers match the skills and the evidence.** Velero is Pro/Ultimate (pdf p.27). The Starter minimums match p.695-696. The `--bundle` names, the mirror jsonpath and the default namespace `kommander` match the live help.
- **Missing FAIL conditions:**
  - install E1: the dry run differs from the real create; `--registry-url` used as a mirror; the product-catalog bundle added without NDK; the agent runs `read` itself.
  - install E2: `--control-plane-replicas 1` with no warning about cluster loss.
  - install E4: no step to export the mirror credentials.
- **Missing evals:**
  - 4A connected with a Docker Hub token.
  - 4C on an air-gapped site.
  - The user says "just run it" (the gate must hold).
  - The user asks for the dashboard password or a decoded Secret.
  - A fact that the skills do not have (UNKNOWN behaviour, the made-up-ID failure).
  - A proxied site.
- **Wrong eval text:** `evals/nkp.md:28` ("only relevant if asked") is not a testable expected answer. Remove it.

## Format verdict: **go-with-changes**

The shape works: front matter, the copied rules block with sync, the router plus owner skills, provider reference files, command blocks with marks, and evals with the general FAIL line. The eval result was 10/10 with 2 minor problems, and no gate was broken. Change these format items before you copy the format into 14 more skills:

1. **Execution model:** add a `# USER-RUNS` mark. Rule 4 says whose shell holds the credentials. Add one export step for each credential set (B2).
2. **Mark taxonomy:** define CHANGES for operator-host changes and local files. Put every command in a block, with no inline commands that change state (M9).
3. **Block grammar:** one complete command per CHANGES block, no `...`, one choice per block, and the dry run is the same command plus flags (M2, M3).
4. **Step template:** every step ends with `Done when: <command> → <expected>`. Labels are different between SKILL.md and the reference files (M4).
5. **Placeholders:** add `<CLUSTER_KUBECONFIG>`. Use `<lower-case>` only for name patterns in prose. Add a rule for site values that are not in the list (M7).
6. **UNKNOWN:** only the skills contain UNKNOWN lines, and each ID must exist in OPEN-ITEMS. Change prose like "not tested" to UNKNOWN lines. Add a router fallback that allows READ-ONLY checks only (M8, M10).
7. **Source tags:** a table-header tag must be true for every row. No tags in code blocks. No tags on facts that do not change.
8. **Ownership:** write the split for licenses and FIPS in the router table. Bundle file names live only in nkp-airgap (M6).
9. **Check script:** add the mark, placeholder, scrub, skill-name, UNKNOWN-ID and description-length checks, each with a self-test case. Fix the BOM and YAML-list parsing (M1).

Then fix B1, re-run the 10 evals plus the missing ones above, and only after that start batch 1.