# nkp-skills — agent instructions

This folder builds a set of `SKILL.md` files for an agent that knows Nutanix Kubernetes Platform (NKP) and Kubernetes well.
These instructions are for agents that **build** the skills. Do not copy them into the skills.

## Goal and constraints

- Target agent runs **air-gapped**: no internet, probably a smaller local LLM. Skills must be self-contained, compact, and give exact commands and bundled references. Never tell the target agent to "search the web" or "check the docs online".
- Skills must also teach air-gapped NKP operations (bundles, registry seeding, mirrors).
- Version: NKP **2.19** is the reference. Record deltas from 2.16–2.18 when sources show them.
- Source priority when sources disagree: live read-only cluster facts (`research/raw/live/<version>/`) > official Nutanix docs (PDF, and portal.nutanix.com pages read with a browser because they render with JavaScript) (`research/raw/pdf/<version>/`) > public web docs > field notes (vault, `everything-nkp`). Mark claims `[live]`, `[pdf p.N]`, `[web]`, or `[field]`.
- Scrub all private data from outputs: IPs, hostnames, secrets, license keys, tokens, customer and project names. Keep the technique, drop the identity.

## Model routing for subagents

| Work | Model | Thinking |
|---|---|---|
| Research (PDF reading, web search, note mining) | DeepSeek-V4.1-Flash (exact model id in `.local/lab.md`) | medium |
| Review of research and skills | `claude-code/claude-opus-5-5` (fresh standalone session) | high |
| Authoring the actual skills | `claude-code/claude-opus-5-5` | high |

Research subagents can use the `codex-research` / `codex-search` tools for web search.

- DeepSeek-V4.1-Flash (wskn-flare) can fail with "Request timed out" before any tool call. Retry it. After 3 failures in a row, stop and tell the user. There is no fallback executor model (lab test 1 retro, Q6).
- Evals and lab executors get both skill sets: `skills/` here and `../ntnx-skills/skills/` (ADR 0004).

## Layout

```
Nutanix-Kubernetes-Platform-v2_19.pdf   source PDF (git-ignored)
scripts/split_pdf.py                    splits a PDF into per-section text files
research/raw/pdf/<version>/             PDF text per TOC section + INDEX.tsv
research/raw/*.md                       raw research notes per area
research/raw/live/<version>/            read-only facts from a live lab cluster + bundle (SUMMARY.md = index)
research/nkp-component-map.md           the component map (input for skills)
research/OPEN-ITEMS.md                  open questions with IDs; revisit before each update
research/NEXT-STEPS.md                  phase status, refresh plan draft, lab-test proposal
skills/<skill-name>/SKILL.md            the skills (phase 2)
```

## Sources

- PDF: `Nutanix-Kubernetes-Platform-v2_19.pdf` → `python3 scripts/split_pdf.py <pdf> research/raw/pdf/<version>`
- Obsidian vault: `~/Documents/<vault>` (NKP, Kubernetes, Flux, NAI notes)
- Repo: `~/Documents/everything-nkp`
- Web: portal.nutanix.com NKP docs and release notes, upstream projects (Cluster API, CAPX, CAREN, Cilium, Flux, Kommander apps).

## Live lab (read-only)

- The connection facts (bastion, kubeconfig, cluster name) are in `.local/lab.md`. That file is git-ignored. Read it before you use the lab. Never copy its values into a tracked file.
- Allowed commands: `get`, `describe`, `explain`, `--help`, `ls`, `tar -t`, `sha256sum -c`, read-only `tar -xO` of bundle files to stdout (write nothing on the bastion), and client-only `helm template` on a local copy of a bundle chart (no cluster). On the bastion also: `curl -sk -o /dev/null -w '%{http_code}'`, `openssl s_client | openssl x509 -noout -ext subjectAltName` of a public certificate, `ip -o link` / `ip route get`, and `docker … inspect`. Server-side dry runs (`kubectl ... --dry-run=server`, `nkp ... --dry-run`) are allowed only after you check that every webhook that matches the object has `sideEffects: None`. Log each dry run in the live file that you write.
- Never read secret values. Scrub IPs, hostnames, and the cluster name (write `<mgmt-cluster>`) before you save output to the repo.
- Lab setup: the agent runs on a laptop and the operator host is the bastion. Send each block over SSH: `timeout <sec> ssh -o BatchMode=yes -o ConnectTimeout=10 -o ServerAliveInterval=15 -o ServerAliveCountMax=4 <bastion> 'bash -s' < block.sh`. This is the lab only. The skills assume that the target agent runs on the operator host (rules block rule 3, ADR 0003); do not write the SSH form into a skill.
- Rules for lab child agents (lab test 1 retro, Q7): put `timeout` around every `ssh`, and `--request-timeout=30s` on every kubectl read. Run `sleep` as its own call, never more than 120 s, and never in the same call as `ssh`. Run a create or a delete in `tmux` on the bastion and read its log. If a child hangs: `subagent_interrupt`, then `subagent_cancel`, then `subagent_resume` with a short "continue from here" message.
- Lab brief template: `research/raw/lab-runs/2026-11-03-test1/BRIEF.md`. Copy it into the folder of the next lab test, and change the task scope, the hard limits, and the scrub names.

## Skill design

Read `GLOSSARY.md`, `docs/adr/`, and `research/NEXT-STEPS.md` §1 before you author or review a skill. Use their terms.

## Freshness and history

- One git tag per NKP version that the skills cover (for example `nkp-2.19`). History stays in git.
- New NKP version: add `research/raw/pdf/<new-version>/`, diff it against the previous version, update the map and the affected skills, record the deltas, tag.
- New field discovery: add or update a skill in a normal commit; note the NKP version it applies to.
