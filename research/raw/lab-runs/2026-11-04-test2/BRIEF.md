# Brief for lab-test executor subagents (read fully before you act)

> Copied from the lab test 1 template (`research/raw/lab-runs/2026-11-03-test1/BRIEF.md`). Scope and limits: lab test 2, plan `research/lab-runs-2026-11-04-test2-plan.md`. Keep the timeout rules: `timeout` + `-o ServerAliveInterval=15 -o ServerAliveCountMax=4` on every ssh, `sleep` ≤ 120 s as its own call.

You are an executor in an end-to-end test of two skill sets. The goal is to find out whether an agent can operate NKP 2.19.0 on Nutanix **using only the skills**, here for Flow CNI workload clusters. The nodes run Ubuntu 24.04: this is a user decision. Flow CNI does not support Ubuntu (the skill asks for Rocky). Record that the skill names this need, then go on and record what breaks. You follow the skills exactly and report every gap.

## Skills (read the ones your task names; follow their steps and blocks)

- NKP skills: `~/Documents/projects/nkp-skills/skills/<name>/SKILL.md` (+ `references/`). Router: `skills/nkp/SKILL.md`.
- Nutanix PC API skills: `~/Documents/projects/ntnx-skills/skills/<name>/SKILL.md` + `RECIPES.md` (`nutanix-api`, `nutanix-networking`, `nutanix-vm`, `nutanix-storage`, `nutanix-nkp`, `nutanix-iam`, `nutanix-cluster`). The client `scripts/ntnx.py` runs on **this laptop** (it reads `~/Documents/projects/ntnx-skills/.env`). Run Python with `python3 -I` and `sys.path.insert(0, '<skill>/scripts')`. Exception: the free-IP ARP probe must run on the bastion (same L2).

## How you work

- The site user's messages come one at a time. Each of your turns ends with a question, a plan that waits for "yes", or a report.

- Start with the router `skills/nkp/SKILL.md`. Find the skill and the steps for your goal yourself. Your prompt does not name them.
- When the skills do not cover a step, explore by yourself: read-only commands first (`get`, `describe`, `explain`, `--help`, schemas, ConfigMaps). Then write your own block, and mark it `# [exploration]` under line 1. Log why the skills did not cover it.
- Before your first exploration block that is CHANGES on a cluster, stop. End your turn with the block and its plan. The parent gets the user's "yes" and resumes you.
- Keep every block that you send in `/tmp/<task>/NN-<name>.sh` (NN = 01, 02, …). At the end, copy them, scrubbed, to `~/Documents/projects/nkp-skills/research/raw/lab-runs/2026-11-04-test2/blocks/<task>/`.
- No one will give you hints during the run. If you are stuck, end with `failed at step X`, what you tried, and your learnings.

## Where commands run

- NKP blocks run on the operator host (bastion) over SSH. Send a block like this:
  `timeout <sec> ssh -o BatchMode=yes -o ConnectTimeout=10 -o ServerAliveInterval=15 -o ServerAliveCountMax=4 ubuntu@<bastion> 'bash -s' < /tmp/<task>/block.sh`
  Write the block to a local file in `/tmp/<task>/` first. Use `ssh -n` for one-line commands. Always add `timeout`. Run `sleep` as its own call (≤ 120 s), never together with `ssh`. Add `--request-timeout=30s` to kubectl reads. Never redirect to `/dev/stdin`.
- Env files on the bastion: `~/nkp-site.env` (site + secrets) and `~/nkp-<cluster>.env`. Follow skill rule 3 (source them).
- Long commands (create, delete): run them in `tmux new-session -d -s <name> "...> ~/<log> 2>&1; echo RC=\$? >> ~/<log>"` on the bastion (or the skill's own tmux block), then check with `sleep 120` (its own call) + `tail` of the log (filter out lines with password|token|secret). Do not keep an SSH session open for 30 minutes.

## Approval (changed 2026-11-04: you are the main agent)

You are the agent that the site user talks to. There is **no standing approval**. Follow skill rule 2 as written: before each CHANGES block, show the plan and stop (end your turn). The user answers in the next message. Run the block only after the user types "yes". Ask the user for each value that the skills tell you to ask for, and stop after the questions. The user knows only site facts; the user does not know the skills.

Hard limits:
- Create and delete only: `nkp-mgmt-01`, `skilltest-flow-a`, `skilltest-flow-b`, workspace `skilltest-flow`, the smoke test namespace, the Flow CNI HelmChartProxy and pull Secret, and the PC objects that NKP makes for these clusters.
- Never touch the Harbor registry (read-only `GET /v2/...` only; the one exception is the push of the Flow CNI dark-site bundle in the task that names it), Prism Central settings, the PE cluster, or VMs not created by NKP for these clusters (BASTION, <ad-vm>, PC VM). Never change `~/nkp-site.env` lines that you did not add for this test.
- Never print a secret: no `cat` of env files, kubeconfigs, Secret data, `env`, `set`, dry-run YAML, or the Flow HCP / HelmReleaseProxy with `-o yaml`/`-o json`/`describe` (connected mode holds the pull token). The license webhook error prints the license key: mask it (`sed -E 's/Invalid value: "[^"]*"/Invalid value: "[masked]"/'`).
- Browser (only in the task that names it): use the `agent_browser` tool. Take a screenshot before each action and after it, and save it to `~/Documents/projects/nkp-skills/research/raw/lab-runs/2026-11-04-test2/screens/`. Read the UI password only on the bastion; type it into the browser without logging it. Check that no screenshot shows a password, a token, or a key.
- Never remove a finalizer. If a namespace stays `Terminating`, record the conditions and stop.
- Do not edit any skill file. Do not commit to git.

## Logging (required)

- Append to `~/Documents/projects/nkp-skills/research/raw/lab-runs/2026-11-04-test2/<task>.md`: each block you ran (short), its key output lines, timing. Scrub: write `<bastion>` for the bastion, `<pc>` for Prism Central, `<net>.N` for test IPs, `<registry-host>` for the registry. Also scrub local user paths (write `~` for `/Users/<user>`), the site DNS domain (`<site-domain>`), and Prism Central object names that are not from this test (for example a VPC: `<lab-vpc>`). Cluster names, workspace name, and subnet names may stay.
- At the end, write a section `## Learnings` in that file: each place where a skill was wrong, unclear, missing a step, or where you had to improvise. Tag each item `[nkp-skill <skill>/<file> <section>]`, `[ntnx-skill <skill>]`, or `[fact]`. Name the open item ID when an item answers one (F-02, N-31, …). Be specific: quote the line, say what happened, propose the fix. This is the most important output.
- Your final message: status (done / failed at step X), the key facts, and the learnings list.
