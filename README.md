# nkp-skills

Agent skills for Nutanix Kubernetes Platform (NKP) and Kubernetes. Reference version: **NKP 2.19**.

The skills are for an agent that runs **air-gapped** on the NKP operator host (bastion), possibly with a small local model. They are self-contained: exact commands, bundled reference files, and no web lookups.

## Contents

| Skill | Use it for |
|---|---|
| `nkp` | Router. Load first. Architecture map, and which skill does a job. |
| `nkp-install` | Create a management or workload cluster, bootstrap, pivot, Kommander. |
| `nkp-airgap` | Bundles, `nkp push bundle`, registry mirror, seeding, offline catalogs. |
| `nkp-cluster-lifecycle` | Day 2: node pools, scale, ClusterClass variables, certificates, delete. |
| `nkp-upgrade` | Upgrade order, gates, and steps. |
| `nkp-troubleshooting` | Debug ladder, `nkp diagnose`, symptom → skill index. |
| `nkp-networking` | Cilium, MetalLB, kube-vip, Traefik, cert-manager, proxy, MTU. |
| `nkp-platform-apps-gitops` | Platform apps, overrides, catalogs, Flux, project CD. |
| `nkp-identity-security` | Dex, RBAC, workspaces, Gatekeeper, licenses. |
| `nkp-storage-backup` | Nutanix CSI, Rook Ceph, COSI, Velero. |
| `nkp-observability` | Prometheus, Grafana, Thanos, logging. |
| `nkp-gpu-ai` | GPU operators, MIG, time-slicing, AI Catalog, NAI. |
| `nkp-flow-cni` | Nutanix Flow CNI (AHV only). |
| `nkp-vpc` | Clusters on Nutanix VPC networks. |
| `nkp-ndk` | Nutanix Data Services for Kubernetes (NDK). |
| `kubernetes-core` | Generic Kubernetes: pods, workloads, scheduling, networking. |

Each skill is a folder `skills/<name>/` with a `SKILL.md`, and optional `references/` and `assets/` folders. The format is the [Agent Skills](https://agentskills.io) format, so any host that reads that format can load them.

## Requirements

- An agent host that supports Agent Skills (for example pi, Claude Code, or another compatible host).
- The agent runs **on the operator host**, with `bash`, `kubectl`, `nkp`, and a container engine. All command blocks run there.
- Recommended: the companion set [`ntnx-skills`](https://github.com/WinsonSou/ntnx-skills) for Prism Central actions (free IP check, floating IPs, volume groups). Without it, the skills tell the user to do these steps in Prism Central (ADR 0004).

## Install

Install the skill folders into the skills folder of your agent host. Do not install the repo root. Install only the folders below `skills/` (the `_shared` folder has no `SKILL.md`, and the host ignores it).

### Connected host

```bash
git clone https://github.com/WinsonSou/nkp-skills.git
git clone https://github.com/WinsonSou/ntnx-skills.git   # companion set, recommended

SKILLS_DIR=~/.agents/skills        # pi: ~/.pi/agent/skills  ·  Claude Code: ~/.claude/skills
mkdir -p "$SKILLS_DIR"
cp -R nkp-skills/skills/*  "$SKILLS_DIR"/
cp -R ntnx-skills/skills/* "$SKILLS_DIR"/
```

To get updates with `git pull`, use symlinks in place of copies:

```bash
for d in nkp-skills/skills/*/ ntnx-skills/skills/*/; do ln -sfn "$PWD/$d" "$SKILLS_DIR/$(basename "$d")"; done
```

### Air-gapped operator host

On a connected host, make one archive:

```bash
tar -czf nkp-skills.tgz -C nkp-skills skills
tar -czf ntnx-skills.tgz -C ntnx-skills skills
```

Move the archives to the operator host with your approved transfer method. Then, on the operator host:

```bash
SKILLS_DIR=~/.agents/skills
mkdir -p "$SKILLS_DIR"
tar -xzf nkp-skills.tgz  --strip-components=1 -C "$SKILLS_DIR"
tar -xzf ntnx-skills.tgz --strip-components=1 -C "$SKILLS_DIR"
```

### Check the install

```bash
ls "$SKILLS_DIR"            # nkp, nkp-install, ..., nutanix-api, ...
```

Start the agent. In pi, the startup output lists the skills, and `/skill:nkp` loads the router. Run `/reload` after you change a skill during a session.

## First use

1. Ask the agent an NKP question or give it a job (for example "Create an NKP management cluster on AHV"). The agent loads `nkp`, then the skill for the job.
2. The agent makes the **site env file** `~/nkp-site.env` (mode 600) and writes the non-secret values that you give it. Each cluster gets its own file `~/nkp-<cluster>.env` (ADR 0003).
3. **You** add the secrets (Prism Central password, registry credentials) to `~/nkp-site.env` with an editor. Do not type secrets in the chat.

How the agent works with you:

- Each command block starts with a mark: `# READ-ONLY`, `# CHANGES`, or `# USER-TERMINAL`.
- The agent runs `READ-ONLY` blocks.
- The agent shows each `CHANGES` block with its target and result, and stops. It runs the block only after you type `yes`.
- You run `USER-TERMINAL` blocks yourself. They show a secret, or they run on a different host.

The full rules are in [`skills/_shared/RULES.md`](skills/_shared/RULES.md). Each `SKILL.md` has a copy.

## Versions

- Each skill has `metadata.nkp_versions` and `metadata.last_verified` in its front matter.
- Each NKP version that the skills cover gets one git tag (for example `nkp-2.19`). Install from the tag that agrees with your NKP version.
- Facts have source tags: `[live 2.19.0]` > `[pdf p.N]` > `[portal]` > `[field]`.

## Contribute

Read [`AGENTS.md`](AGENTS.md), [`GLOSSARY.md`](GLOSSARY.md), [`docs/AUTHORING.md`](docs/AUTHORING.md), and [`docs/adr/`](docs/adr/) before you change a skill. Before each commit:

```bash
python3 scripts/check_skills.py --self-test && python3 scripts/check_skills.py
```

To change the rules block, edit `skills/_shared/RULES.md` only, then run `python3 scripts/check_skills.py --sync`.
