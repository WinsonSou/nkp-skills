# nkp-skills

A set of Agent Skills that teach an air-gapped agent on a small local model to operate Nutanix Kubernetes Platform (NKP).

## Skill set

**Skill**:
One folder `skills/<name>/` with a `SKILL.md` and optional `references/` and `assets/`, in the Agent Skills format.
_Avoid_: prompt, playbook

**Router skill**:
The `nkp` skill. It holds the compact architecture map and tells the agent which skill to use for which job.
_Avoid_: index skill, architecture skill

**Owner skill**:
The one skill that holds a given fact. Other skills point to it and do not copy the fact.
_Avoid_: primary skill, home skill

**Reference file**:
A file in `skills/<name>/references/` that the agent loads only when the SKILL.md points to it for its branch (for example one provider).
_Avoid_: appendix, sub-skill

**Asset**:
A small pinned third-party text file in `skills/<name>/assets/` that the bundle does not include.

**Rules block**:
The same short block of shared rules at the top of every SKILL.md. The master copy is `skills/_shared/RULES.md`.

## Content conventions

**CHANGES command**:
A command that changes a cluster, the infrastructure, a registry, the container engine on the operator host, or a file on the operator host. The agent shows the plan and waits for user approval before it runs it.
_Avoid_: write command, mutating command

**READ-ONLY command**:
A command that only reads state and prints no secret.

**USER-TERMINAL command**:
A command that prints a secret, or that runs on another host (a connected host or a node). The agent gives it to the user, who runs it in their own terminal.

**Connected host**:
A machine with internet access outside the air gap. The user runs its command blocks; they are marked `# USER-TERMINAL  (connected host ...)`, so the agent never runs them.
_Avoid_: internet box, staging machine

**UNKNOWN line**:
A line that states a fact is not known, gives its open-item ID, and gives a read-only command to find it.
_Avoid_: TODO, TBD, gap

**Site env file**:
The file `~/nkp-site.env` (mode 600) on the operator host. It holds the shared site values and the secrets.
_Avoid_: config file, vars file

**Cluster env file**:
The file `~/nkp-<cluster>.env` (mode 600) on the operator host. It holds the values of one cluster and sources the site env file.
_Avoid_: cluster config

**Site variable**:
A shell variable from the fixed list in the rules block (for example `CLUSTER_NAME`). It is set in the site env file, and commands use it as `"$CLUSTER_NAME"`.
_Avoid_: placeholder, parameter

**Source tag**:
A short tag on a fact that can change: `[live 2.19.0]`, `[pdf p.N]`, `[portal]`, `[field]`.
_Avoid_: citation, ref

**Open item**:
A question in `research/OPEN-ITEMS.md` with an ID (for example F-02).

## Testing

**Eval**:
A task prompt with the expected commands or answer, in `evals/<skill>.md`, run by the eval model with only the skills.

**Eval model**:
The model that plays the small air-gapped target in evals: DeepSeek-V4.1-Flash, thinking low.

**Pilot**:
The first skills written (`nkp`, `nkp-install` with the Nutanix reference file, the rules block, and the check script) to test the format before the rest.
