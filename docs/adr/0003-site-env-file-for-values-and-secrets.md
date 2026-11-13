# Site values and secrets live in one site env file

The agent cannot type into an interactive prompt, and a variable that the user exports in their own terminal is not in the agent's shell. If the user gives a password in the chat, the password goes into the model context and the session log. So all site values and secrets go in one file, `~/nkp-site.env` (mode 600). The agent writes the non-secret values with the user's answers. The user adds the secrets with an editor. Every command block starts with `source ~/nkp-site.env`, and every command uses the variables (`"$CLUSTER_NAME"`) from the fixed variable list. The agent never prints the file and checks a secret only with `test -n "$VAR"`. A command that prints a secret (for example `nkp get dashboard`) is run by the user in their own terminal.

This replaces the `<UPPER_CASE>` placeholders that design round 3 (Q11) chose. The risk from Q11 (a command that runs with an empty value) is controlled by a check step that fails when a required variable is empty.

## Considered options

- The agent sets `VAR=value` inline: simplest, but the secret goes into the chat and the log.
- A third command mark, `USER-RUNS`, for every command that needs a credential: the user must run most install commands, and the agent cannot read their output.

## Amendment 2026-11-02

- **Two files.** `~/nkp-site.env` holds the shared values and the secrets (Prism Central, registry, `MGMT_KUBECONFIG`). `~/nkp-<cluster>.env` (mode 600) holds the values of one cluster (`CLUSTER_NAME`, `CP_VIP`, `LB_IP_RANGE`, `WORKSPACE_NS`, `CLUSTER_KUBECONFIG`). Its first line is `source ~/nkp-site.env`. A block that works on one cluster sources the cluster file. Reason: with one file, a workload cluster create replaced the management cluster values ("the last line wins").
- **Third mark, `# USER-TERMINAL`, only for commands that print a secret** (for example `nkp get dashboard`, `kubectl get secret … -o`, `base64 -d`). The agent gives the command to the user and does not run it. Commands that only use a secret still run in the agent's shell through the env file. This is narrower than the rejected `USER-RUNS` option.
- **Errors from `source` are hidden** (`source <file> 2>/dev/null`), because a bad quote in the file makes bash print the line, and the line can hold a secret. A `bash -n` syntax check replaces the error output.
- **Pilot fix pass 2 (2026-11-02).** In a skill, line 2 of a block has the literal path `~/nkp-<cluster>.env`, and the agent replaces `<cluster>` with the cluster name before it runs the block. That is the only `<lower-case>` text allowed in a command block. Secrets are checked with `printenv VAR >/dev/null` (declared) or `[ -n "$(printenv VAR)" ]` (not empty), because `${!v}` fails in zsh. The agent appends only known values (no `export X=''` templates).

## Amendment 2026-11-02 (b)

- **`USER-TERMINAL` also marks a block that runs on another host** (a connected host, or a node over SSH). The text after the mark names the host. Reason: the agent can run only on the operator host, and a node block such as `sudo cat` must not run there (batch 1 fix pass).
- **Core variables only in the rules table.** The rules block is copied into every SKILL.md (ADR 0002), so its table holds only the variables that many skills use. A variable that only one skill or reference file uses goes in a `| File | Site variables |` table in that file, next to its commands. The check script accepts such a variable only inside the same skill. Reason: batch 1 added 34 provider variables (AWS, Azure, GCP, vSphere, hosts). In every skill they cost about 400 tokens that the small model must read past.

## Amendment 2026-11-03

- **A cluster env file can override a site value for that cluster only.** A workload cluster on another subnet appends `SUBNET` (and `PE_CLUSTER`, `STORAGE_CONTAINER` when they differ) to `~/nkp-<cluster>.env`, not to `~/nkp-site.env`. The cluster file sources the site file on its first line, so its own line wins for that cluster, and the site file keeps the management cluster values. Owners: `nkp-install` (`nutanix.md` N5 step 2) and `nkp-vpc` (step 2). Reason: batch 5 review M2. A `SUBNET` line in the site file for a workload cluster moved later node pools of the management cluster and of all other clusters to the new subnet.
