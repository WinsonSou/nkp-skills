# Pilot re-review: fix pass 820da6b (with ADR 0003)

I changed no files in the repo. Both script runs exit 0 (`--self-test` and the full check). I tested the script with temporary files in `/tmp/rv2`. I tested the shell behaviour with bash, zsh and sh. I compared each flag in N4A, N4B, N4C and N5 with `nkp-help-cluster.txt`. **Verdict: go-with-changes.** One blocker is new: a bad quote in the site env file prints the secret.

## 1. Status of the findings from the first review

| ID | Status | Evidence |
|---|---|---|
| B1 | Closed (needs a lab test) | `nkp-install/SKILL.md:134-172`: the kubeconfig step now comes before Kommander and Verify. A-05 is at :136. `get kubeconfig` is CHANGES (:156-164). `nutanix.md:286` points to the step. Each kubeconfig has one variable. |
| B2 | Partly closed | ADR 0003 replaces `read`. N1 lists the secrets for each case (`nutanix.md:28-34`). But N2 does not check the mirror credentials (new M2). |
| M1 | Partly closed | Script :35-50 adds many checks. Section 3 lists the false passes. |
| M2 | Partly closed | N4A, N4B, N4C and N5 are complete commands with correct flags. The dry run is still only prose (`nutanix.md:144`), so the model must build a 20-line command. |
| M3 | Closed | `kommander.md:11-21` has two labelled blocks. The manual-flow block is gone. |
| M4 | Closed | Each step has "Done when". The provider file uses N1-N7 labels. |
| M5 | Closed | `components.md:56-58`: P-05 is an UNKNOWN line. Calico and Flow have their own tags. |
| M6 | Closed | `nkp/SKILL.md:30,38` splits licenses and FIPS. `nutanix.md:215` gives bundle names only as patterns, with no versions. |
| M7 | Closed | Site variables replace the placeholders. `<lower>` names are only in prose. |
| M8 | Closed | There are 5 UNKNOWN lines, and each ID is in OPEN-ITEMS. |
| M9 | Closed | Rule 1 includes local files. The rotate command is in a block (`SKILL.md:228-232`). `nutanix.md:383` points to nkp-cluster-lifecycle. |
| M10 | Closed | `nkp/SKILL.md:21`, `nkp-install/SKILL.md:71`. |

**Minor items:**
- **Closed:**
  - kubectl 1.37.2 (`SKILL.md:81`).
  - FIPS page p.988 (`:130`).
  - Workload NKPCluster tag (`nkp:75`).
  - PC project cannot change (`nutanix.md:26`).
  - karbon-core 2.10.2 (`:381`).
  - `--bootstrap-cluster-image` takes the tar file (`:234`).
  - No tags in code blocks.
  - No repeated tables in the router.
  - The script checks the rules position.
  - Rule 3 is now a table.
  - The router says "skill list".
  - N1 has a Req column. NTP is required only on an air-gapped site.
  - The ping and pod-ready checks.
  - Lead with the fix, not with `--skip-preflight-checks` (`SKILL.md:129`).
  - BOM, YAML block lists, metadata strings, name and description checks.
  - Quiet self-test, tests for missing markers, exact sets of error codes.
  - Eval FAIL conditions for E1, E2 and E4. New evals E6-E10 and nkp E6. `nkp.md:28` is fixed.
- **Partly closed:**
  - `nkp/SKILL.md:83` still says that AWS uses the non-ClusterClass path as a fact. P-06 on the next line says that AWS is unknown, and live shows `nkp-aws-v2.19.0`.
  - The dry run has its `[live]` tag, but the pdf p.729 note is not there.
  - The `nkp-install` description still names Metal, pre-provisioned and cloud. The skill has no steps for them (`SKILL.md:6` and `:71`).
  - ASD-STE100: `nutanix.md:383` is passive ("must be deleted"). `kommander.md:35` is vague ("large air-gapped sites").
  - Scrub: `<lab-provider>` is still in `GLOSSARY.md:63` and `grading.md:3`.
  - Password on the command line: the note is only on N4A (`:200`), not on the mirror password in N4C and N5.
- **Open:**
  - The script does not check links to other skills (`../nkp-x/`).
  - There is no proxy eval.

**The 9 format changes:**

| # | Status | Note |
|---|---|---|
| 1 | Changed by ADR 0003 | — |
| 2 | Closed | — |
| 3 | Partly closed | Dry run (M2) |
| 4 | Closed | — |
| 5 | Closed | — |
| 6 | Closed | — |
| 7 | Mostly closed | `components.md:26`: the map's deprecation note sits under a `[live]` table header |
| 8 | Closed | — |
| 9 | Partly closed | Section 3 |

## 2. Findings

### BLOCKER

**X1. A bad quote in the site env file prints the secret in every block.** File: rule 3 (`RULES.md:12`), and line 2 of each block.
- **Test:** I wrote the line `export NUTANIX_PASSWORD='example-P@ssw0rd`. Then `source` printed `line 2: \`export NUTANIX_PASSWORD='example-P@ssw0rd'` on stderr. That puts the secret in the model context and in the log.
- **Second test:** an unquoted `Secret&Pass` printed `Pass: command not found`.
- **Effect on later lines:** bash stops reading the file at the error. All lines after it are empty, and the block continues with them. In my test, `B=` was empty after the bad line. That also breaks "the last line wins".
- **Fix:**
  - Line 2 of each block becomes `source ~/nkp-site.env 2>/dev/null`. Change `SOURCE_LINE` in the script to match.
  - Add this line to N2: `bash -n ~/nkp-site.env 2>/dev/null && echo "set: syntax" || echo "MISSING: syntax"`.

### MAJOR

**M1. The N2 check can pass when it did not run.** File: `nutanix.md:85-114`.
- **Problem 1:** `${!v}` works in bash and sh. zsh prints `bad substitution` and no `MISSING` line. The Done-when is "no line starts with MISSING", so it passes. zsh is the default shell on macOS, and `SKILL.md:79` allows a macOS operator host.
- **Problem 2:** the Done-when is negative, so any error makes it pass.
- **Safety:** the check does not print a value, so it is safe.
- **Fix:**
  - Use `if [ -n "$(printenv "$v")" ]` (works in bash, zsh and sh).
  - Change the Done-when to: "each name in the list prints `set:`".

**M2. The N2 cases do not match the create commands.**
- **Mirror credentials:** case 4C (`:105`) and case 5 (`:111`) do not check `REGISTRY_MIRROR_USERNAME` or `REGISTRY_MIRROR_PASSWORD`. `test -n` cannot check them, because `''` is allowed for anonymous pulls (`:34`). Eval E4 expects this check, so the eval and the skill disagree.
- **NTP:** case 5 does not check `NTP_SERVERS`, but N5 always passes `--ntp-servers "$NTP_SERVERS"` (`:340`). After a connected N4A management cluster, the value is empty.
- **Connected workload cluster:** case 5 requires `REGISTRY_URL` and `REGISTRY_CA_FILE`, but a workload cluster under N4A uses no mirror (`:343`). The check prints MISSING and blocks the flow.
- **Fix:**
  - For the mirror credentials, check that the variable is declared: `printenv REGISTRY_MIRROR_USERNAME >/dev/null && echo "set: …"`. I tested that `printenv` tells "declared and empty" from "not declared".
  - Split case 5 into "5 mirror" and "5 connected".
  - Add `NTP_SERVERS` to "5 mirror". Tell the agent to remove the `--ntp-servers` line when the value is empty.

**M3. `\|` in table cells breaks commands.** The model reads the raw Markdown, not the rendered table.
- **`nutanix.md:165`:** `base64 < "$PC_CA_FILE" \| tr -d '\n'` fails with `base64: invalid argument |`. This is a flag in the create command.
- **`components.md:56`:** `grep -E 'cilium\|calico'` does not match `cilium`. This is the P-05 check, so it gives a wrong answer.
- **Fix:**
  - Move both commands out of the tables into fenced blocks.
  - Add a script check: a backtick span with `\|` is an error.

**M4. A Verify "Done when" contradicts the live output.** File: `SKILL.md:207`.
- The skill says: "`nkp describe cluster` shows `True` for the cluster, the control plane, and every machine".
- In `nkp-describe-cluster.txt` [live], the `Cluster/` and `ControlPlane` rows have an empty READY column. Only the `Machine/` rows show `True`.
- A small model will wait or retry for no reason.
- **Fix:** "Every `Machine/` row shows READY `True`. [live 2.19.0]"

**M5. A command that prints a secret has the mark READ-ONLY.** File: `SKILL.md:219-223` (`nkp get dashboard`).
- Rule 2 lets the agent run READ-ONLY blocks with no approval. Only a comment in parentheses stops it.
- `nkp-identity-security` will have many such commands (Dex secrets, `base64 -d`).
- ADR 0003 rejected a third mark for every credential command, not for this smaller set.
- **Fix:**
  - Add a third mark, `# USER-TERMINAL`, only for commands that print a secret. Add one sentence to ADR 0003 for it.
  - Add a script check: `nkp get dashboard`, `get secret … -o`, `base64 -d`, `cat ~/nkp-site.env`, and `echo "$<secret var>"` are errors unless the mark is `USER-TERMINAL`.

**M6. Only nkp-install says how to make the site env file.**
- The router blocks use `source ~/nkp-site.env` and `"$MGMT_KUBECONFIG"` (`nkp/SKILL.md:53-58, 104-109, 115-123`).
- On a host with no file, `source` fails, and `kubectl --kubeconfig ""` runs. All 14 new day-2 skills will have the same problem.
- **Fix:** add this to rule 3: "If `~/nkp-site.env` does not exist, make it with `touch ~/nkp-site.env && chmod 600 ~/nkp-site.env` (CHANGES). Then ask for `MGMT_KUBECONFIG`."

**M7. The check script lets these errors pass.** I tested each case in `/tmp/rv2/t.py` and `t2.py`.

| Input | Result | Expected |
|---|---|---|
| An indented fence in a list (`   ```bash` / `   kubectl delete ns kommander`) | pass | `mark` error. `FENCE_RE` finds only fences at column 0. |
| A `~~~bash` fence, and ` ```zsh ` / ` ```console ` fences with no mark | pass | `mark` error |
| `# READ-ONLY` on `kubectl delete`, on `> file`, or on `cat ~/nkp-site.env` | pass | error |
| `https://reg.customer.corp/nkp`, `harbor.acme.ch`, `nkp.lab.cloud`, `REG.CUSTOMER.CORP` | pass | `fqdn` error. The lookbehind skips hosts after `/`. The TLD list is short. The pattern is case-sensitive. |
| `http://10.1.2.3/ui` | pass | `ipv4` error. The lookahead `(?!…/)` skips it. |
| `export NUTANIX_PASSWORD='example-P@ssw0rd'` in a heredoc | pass | error (a literal secret value in a block) |
| A bare `` `nkp-airgapp` `` (the style of "Related skills", `SKILL.md:250`) | pass | `skill-name` error. Only `skill \`x\`` is checked. |
| `UNKNOWN (A-06): … Find out with: ask the user.` | pass | form error (no check command) |
| Front matter that closes with `--- ` (trailing space) | **crash**: `ValueError` at :197 | a clear error |
| The prose text "rule 6 for UNKNOWN lines" | `unknown-form` | pass (false fail) |
| An output example in a plain ` ``` ` fence | `mark` | pass, or document "use ` ```text ` for output" |

- **Fix:**
  - Allow indented fences and `~~~` fences: `^\s*(```|~~~)`.
  - Treat every block that is not `text`, `yaml` or `json` as a shell block.
  - In READ-ONLY blocks, add a list of verbs that change state: `(kubectl|nkp) (delete|apply|create|patch|edit|scale|rotate|install|upgrade|push|move)`, `>`, `>>`, `chmod`, `tee`.
  - Hostnames: match any `label.label.tld` with any case, also inside URLs, and use an allowlist.
  - IPv4: remove `/` from the negative lookahead.
  - Check every backtick `nkp-[a-z0-9-]+` token that does not end in a file extension.
  - Require "Find out with:" plus a backtick command.
  - Use `strip()` in the position check.
  - Add one self-test case for each fix.

### MINOR

1. **The N1 and N5 templates can delete good values.**
   - **Where:** the heredoc templates `nutanix.md:38-55, 305-313`.
   - **Problem:** they append `export X=''` lines. A model that runs the template again to fix one value sets the other values back to empty, because the last line wins.
   - **Fix:** "To change one value, append only that line." Give a one-line `echo "export VAR='…'" >> ~/nkp-site.env` pattern.
2. **The A-05 tag is too weak.**
   - **Where:** `SKILL.md:136` (A-05 `[field]`).
   - **Evidence:** pdf p.729-730 runs `nkp get dashboard --kubeconfig=${CLUSTER_NAME}.conf` directly after the self-managed create.
   - **Fix:** change the tag to `[pdf p.729]`. Keep A-05 open until the lab test.
3. **Bad first line in A-06.**
   - **Where:** `nutanix.md:345` (A-06).
   - **Problem:** "Find out with" is not a command.
   - **Fix:** use `` `kubectl --kubeconfig "$MGMT_KUBECONFIG" -n kommander get nkpclusters -o jsonpath='{..ociRegistry}'` ``, then ask the user.
4. **Inline UNKNOWN checks have no `source`.**
   - **Where:** the P-05 and P-06 inline checks (`components.md:56`, `nkp/SKILL.md:84`).
   - **Problem:** they use variables, but they are not in a block, so there is no `source` line.
   - **Fix:** put `source ~/nkp-site.env &&` before each command.
5. **The kubeconfig block writes the path even when the command fails.**
   - **Where:** `SKILL.md:161-163`.
   - **Problem:** when `nkp get kubeconfig` fails, the block still makes an empty file and appends `CLUSTER_KUBECONFIG`.
   - **Fix:** join the three lines with `&&`.
6. **The dry run has two approval gates.**
   - **Where:** `nutanix.md:144-150`. The dry run and the `chmod` are two CHANGES steps.
   - **Fix:** start the dry-run line with `umask 077;`. Then remove the `chmod` block.
7. **The IMAGE_BUNDLES check comes after the write.**
   - **Where:** `nutanix.md:224`.
   - **Problem:** the "Done when" about `ls` comes after the CHANGES block that uses the `ls` result.
   - **Fix:** move it before that block.
8. **`--yes` has no source tag.**
   - **Where:** `SKILL.md:231`.
   - **Problem:** `--yes` is not in the live help. It comes from pdf p.729.
   - **Fix:** add the tag `[pdf p.729]`.
9. **Some host checks work only on Linux.**
   - **Where:** `SKILL.md:91-92`.
   - **Problem:** `stat -fc` and `free -g` work only on Linux, and the skill allows macOS. `source` also fails in dash (`/bin/sh` on Ubuntu).
   - **Fix:** label the two lines "(Linux)". Add "run the blocks with bash" to rule 3.
10. **The eval FAIL line conflicts with the env file write.**
    - **Where:** the general FAIL line "a site value inline instead of `"$VAR"`" (`evals/nkp-install.md:10`).
    - **Problem:** the site env file write block must contain inline values.
    - **Fix:** add "except in the block that writes the site env file".
11. **E10 expects advice that is not in the skills.**
    - **Where:** eval E10.
    - **Problem:** it expects the agent to tell the user to change a password that was pasted in the chat. No skill says this.
    - **Fix:** add it to rule 5, or remove it from the eval.
12. **P-05 names a skill that does not exist.**
    - **Where:** OPEN-ITEMS P-05.
    - **Problem:** its owner is `nkp-install-cloud`, which is not one of the 16 skills.
    - **Fix:** change the owner to `nkp-install`.
13. **The new rows have enough evidence:**
    - **P-06:** the PDF names AHV and EKS. Live has the aws and host-agent classes.
    - **P-07:** the help says "CA trust bundle". pdf p.719 says Base64. The pdf update steps show plain PEM in `NutanixCluster`.
    - **A-06:** p.675 covers only the Docker Hub credentials. No source covers the internal mirror.
14. **No space is left for more text.**
    - **Where:** `nkp-install/SKILL.md` has 250 lines, which is the limit. `nutanix.md` has 386 of 400 lines.
    - **Fix:** use the shorter rules block in section 4. It frees about 20 lines.
15. **The flags are correct.** Every flag in N4A, N4B, N4C and N5 is in `nkp-help-cluster.txt` and has the same spelling. The `--kubeconfig` flag is not used with `--self-managed`, which is correct because the help says that flag is then ignored. Line `:281` writes `--registry-mirror-user*` as a pattern in prose. Write the two flag names in full.

## 3. Check script runs

- `--self-test`: passes. Full check: `2 skills checked, 0 errors`.
- **False passes:** see M7.
- **False fails:**
  - The prose word "UNKNOWN" when it is not an UNKNOWN line.
  - Plain fences for output.
  - Metadata written as a flow map (`metadata: {…}`): forbid it, or document it.
- **Crash:** front matter that closes with `--- ` (trailing space).

## 4. A shorter rules block (38 lines → 19 lines, no loss)

What I changed:
- Rules 3 and 4 are now one rule.
- I removed the description column. The provider files (N1) already give the format of each value.
- The table groups the variables in rows. `site_vars()` must then find every backtick UPPER token in the table rows, not only in column 1.
- The block includes the fixes for X1, M5 and M6.

```markdown
## Rules for every NKP skill

1. **Marks.** Line 1 of each command block is `# READ-ONLY`, `# CHANGES`, or `# USER-TERMINAL`. CHANGES: it changes a cluster, the infrastructure, a registry, the container engine, or a file on the operator host. USER-TERMINAL: it prints a secret. Give it to the user. Do not run it.
2. **Approval.** Before a CHANGES block, show the command, the target, and the result. Stop. Run it only after the user types "yes" to that plan. "Just run it" is not "yes".
3. **Site env file.** Run blocks with bash. Line 2 of each block is `source ~/nkp-site.env 2>/dev/null`. Commands use site variables as `"$VAR"`. Each file line is `export VAR='value'`. To change one value, append only that line (the last line wins). For a value with no variable, make an UPPER_SNAKE name, ask the user, and append it. If the file does not exist, make it with `touch ~/nkp-site.env && chmod 600 ~/nkp-site.env` (CHANGES).
4. **Secrets.** The user types the secret variables into the file with an editor. Do not repeat or use a secret from the chat. Tell the user to put it in the file and to change it. Check a secret only with `printenv VAR >/dev/null` or `[ -n "$(printenv VAR)" ]`. Never print the file, `env`, `set`, a kubeconfig, or Secret data.
5. **Unknowns.** Use only the UNKNOWN lines in the skills: `UNKNOWN (<id>): <what>. Find out with: <command>`. Run the check or ask the user. For a fact that is not in the skills, say "not in the skills" and give a READ-ONLY check. Never make up an ID or a fact.
6. **Offline.** Use only these skills, the bundle, `--help`, and the cluster. Read versions from the cluster or from `nkp version`.
7. **Tags.** `[live 2.19.0]` live cluster · `[pdf p.N]` NKP 2.19 guide · `[portal]` Nutanix portal · `[field]` not confirmed. Trust them in this order.

| Site variables | |
|---|---|
| Clusters | `CLUSTER_NAME` `MGMT_KUBECONFIG` `CLUSTER_KUBECONFIG` `WORKSPACE_NS` |
| Air gap | `BUNDLE_DIR` `IMAGE_BUNDLES` `REGISTRY_URL` `REGISTRY_CA_FILE` |
| Nutanix | `PC_ENDPOINT` `PC_CA_FILE` `PC_PROJECT` `PE_CLUSTER` `SUBNET` `STORAGE_CONTAINER` `VM_IMAGE` `CP_VIP` `LB_IP_RANGE` `SSH_PUBKEY_FILE` `NTP_SERVERS` |
| Secrets | `NUTANIX_USER` `NUTANIX_PASSWORD` `REGISTRY_MIRROR_USERNAME` `REGISTRY_MIRROR_PASSWORD` `NUTANIX_REGISTRY_USERNAME` `NUTANIX_REGISTRY_TOKEN` |
```

## 5. Format verdict: go-with-changes

Do these before you write the 14 new skills:

1. **Source line:** line 2 becomes `source ~/nkp-site.env 2>/dev/null`. Add the `bash -n` syntax line to N2 (X1).
2. **Check pattern:** use the `printenv` form, which works in bash, zsh and sh. Each Done-when must name the expected output, not "no MISSING". Check declared-but-empty secrets with `printenv VAR >/dev/null` (M1, M2).
3. **New mark:** add `# USER-TERMINAL` for commands that print a secret, with one sentence in ADR 0003 (M5).
4. **Missing env file:** add the rule for a host with no site env file to the rules block (M6).
5. **Tables:** no commands in table cells (M3).
6. **Live evidence:** test each Done-when against the live output (M4).
7. **Check script:** fix the gaps in M7, each with a self-test case.
8. **Rules block:** use the shorter block in section 4, and change `site_vars()` to match.
9. **Pilot fixes:** fix M2 (N2 cases 4C and 5), M4, and the minor items 1, 3 and 5.

Then run E1, E4, E7 and E10 again with the eval model, and run one eval in a zsh shell.

I did not run anything on the lab, and I did not run the evals again. I did not check the pdf pages for each tag again, only the pages that the findings use. A-05 and P-07 stay open until someone runs a create in the lab. The temporary test files are in `/tmp/rv2`, outside the repo.