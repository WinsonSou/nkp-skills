# Brief for lab-test executor subagents (read fully before you act)

> Template for later lab tests (AGENTS.md "Live lab"). Copy this file into the new test folder. Change the task scope, the hard limits, and the scrub names. Keep the timeout rules: `timeout` + `-o ServerAliveInterval=15 -o ServerAliveCountMax=4` on every ssh, `sleep` ≤ 120 s as its own call.

You are an executor in an end-to-end test of two skill sets. The goal is to find out whether an agent can operate NKP 2.19.0 on Nutanix **using only the skills**. You follow the skills exactly and report every gap.

## Skills (read the ones your task names; follow their steps and blocks)

- NKP skills: `~/Documents/projects/nkp-skills/skills/<name>/SKILL.md` (+ `references/`). Router: `skills/nkp/SKILL.md`.
- Nutanix PC API skills: `~/Documents/projects/ntnx-skills/skills/{nutanix-api,nutanix-networking,nutanix-vm}/SKILL.md`. The client `scripts/ntnx.py` runs on **this laptop** (it reads `~/Documents/projects/ntnx-skills/.env`). Run Python with `python3 -I` and `sys.path.insert(0, '<skill>/scripts')`.

## Where commands run

- NKP blocks run on the operator host (bastion) over SSH. Send a block like this:
  `timeout <sec> ssh -o BatchMode=yes -o ConnectTimeout=10 ubuntu@<bastion> 'bash -s' < /tmp/<task>/block.sh`
  Write the block to a local file in `/tmp/<task>/` first. Use `ssh -n` for one-line commands. Always add `timeout` and `-o ServerAliveInterval=15 -o ServerAliveCountMax=4`. Run `sleep` as its own call (≤ 120 s), never together with `ssh`. Add `--request-timeout=30s` to kubectl reads. Never redirect to `/dev/stdin`.
- Env files on the bastion: `~/nkp-site.env` (site + secrets) and `~/nkp-<cluster>.env`. They exist. Follow skill rule 3 (source them).
- Long commands (create, delete): run them in `tmux new-session -d -s <name> "...> ~/<log> 2>&1; echo RC=\$? >> ~/<log>"` on the bastion, then check with `sleep 120` (its own call) + `tail` of the log (filter out lines with password|token|secret). Do not keep an SSH session open for 30 minutes.

## Approval

The user gave **standing approval** for this session for the task you get. You do not need to stop for "yes" at CHANGES blocks that are inside your task scope. Still: write in your log which CHANGES block you ran and why (the plan the skill asks for). Anything outside your task scope: stop and report.

Hard limits:
- Never touch the cluster `<old-mgmt-cluster>` objects except where the task says (it is already deleted), the Harbor registry, Prism Central settings, the PE cluster, or VMs not created by NKP for your cluster (BASTION, <ad-vm>, PC VM).
- Never print a secret: no `cat` of env files, kubeconfigs, Secret data, `env`, `set`. The license webhook error prints the license key: mask it (`sed -E 's/Invalid value: "[^"]*"/Invalid value: "[masked]"/'`).
- Do not edit any skill file. Do not commit to git.

## Logging (required)

- Append to `~/Documents/projects/nkp-skills/research/raw/lab-runs/2026-11-03-test1/<task>.md`: each block you ran (short), its key output lines, timing. Scrub: write `<bastion>` for <bastion>, `<pc>` for <pc>. Cluster names, VIPs from the <net>.40–.80 test range, and subnet names may stay.
- At the end, write a section `## Learnings` in that file: each place where a skill was wrong, unclear, missing a step, or where you had to improvise. Tag each item `[nkp-skill <skill>/<file> <section>]`, `[ntnx-skill <skill>]`, or `[fact]`. Be specific: quote the line, say what happened, propose the fix. This is the most important output.
- Your final message: status (done / failed at step X), the key facts, and the learnings list.
