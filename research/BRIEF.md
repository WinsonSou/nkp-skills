# Shared research brief (all research subagents)

Project: build a component map of Nutanix Kubernetes Platform (NKP) 2.19. It is the input for SKILL.md files for an AIR-GAPPED agent.
Working dir: ~/Documents/projects/nkp-skills. Read AGENTS.md first.

Sources and priority: PDF text in research/raw/pdf/2.19/ (INDEX.tsv lists sections + page ranges) > web (portal.nutanix.com, github.com upstream repos, nutanix.dev) > field notes. Use codex-research / codex-search for web.
Mark every fact with a source: `[pdf p.123]`, `[web: <url>]`, or `[field: <note filename>]`. If you cannot find a fact, write `UNKNOWN` — never guess.

Scrub private data: no IPs, hostnames, passwords, tokens, license keys, customer/project names. Keep techniques.

## Output format (write ONLY your assigned file)

1. `## Components` — one `###` entry per component, with these fields:
   - **What**: one-sentence purpose
   - **Upstream**: project + repo URL
   - **NKP role / name**: how NKP names/ships it (e.g. platform app name, CAPI provider, CAREN addon)
   - **Runs on**: bootstrap (kind) | management cluster | workload cluster | node OS
   - **Deployed by**: CAPI / CAREN cluster class addon / Kommander platform app (Flux HelmRelease) / catalog app / manual
   - **Default**: enabled | optional | disabled; and which license tier (Starter/Pro/Ultimate) if stated
   - **Version in 2.19**: if stated
   - **Depends on / talks to**
   - **Air-gap notes**: bundles, images, registry mirror, special steps
   - **Key CRDs / namespaces / CLI commands** (short)
   - **Sources**
2. `## Relationships` — bullet list of "A -> B: why".
3. `## Version deltas` — what changed across 2.16 / 2.17 / 2.18 / 2.19 if found.
4. `## Gaps / open questions`.

Be complete but terse. Tables are fine. Do not write outside your assigned file.
