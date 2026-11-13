# Next steps (after the research phase)

Status on 2026-11-01: the research phase is done. The inputs for phase 2 are:
- `research/nkp-component-map.md`: the map. §8 lists 16 candidate skills.
- `research/OPEN-ITEMS.md`: the open questions, with IDs.
- `research/raw/01..08-*.md`, `research/raw/live/2.19/`, `research/raw/pdf/2.19/`, `research/raw/portal/`.

Decisions so far (see also `AGENTS.md`):
- The target agent runs air-gapped on a small local LLM. The skills must be self-contained, with exact commands.
- NKP 2.19 is the reference version. Record the changes from 2.16–2.18.
- Source priority: live > official Nutanix docs (PDF, portal) > web > field. Scrub all private data.
- Research subagents use DeepSeek-V4.1-Flash. Reviews and skill authoring use Claude Opus.

## 1. Phase 2: skill design — done (2026-11-01)

Terms: `GLOSSARY.md`. Hard-to-reverse choices: `docs/adr/0001`, `docs/adr/0002`.

**Format**
- Agent Skills format: `skills/<name>/SKILL.md` (front matter `name`, `description`, `metadata:` with `nkp_versions`, `last_verified`, `sources`), `references/`, `assets/`.
- Budget for a 32k-token model: SKILL.md ≤ ~250 lines, each reference file ≤ ~400 lines.
- Write in ASD-STE100. Commands, flags, and names stay as they are.
- Rules block at the top of every SKILL.md (master: `skills/_shared/RULES.md`, a check script keeps the copies the same). It contains:
  - mark each command block `READ-ONLY` or `CHANGES`. For a CHANGES command, show the plan and wait for user approval.
  - UNKNOWN lines: `UNKNOWN (<ID>): <what>. Find out with: <read-only command>`. Leave out open items that have no check command.
  - site values and secrets: the site env file `~/nkp-site.env` and a fixed variable list (ADR 0003).
  - source tags only on facts that can change: `[live 2.19.0]`, `[pdf p.N]`, `[portal]`, `[field]`.
- Assets: only small pinned text files (≤ ~50 KB, upstream version and SHA in a header). Big or binary files get "download on a connected host" steps in nkp-airgap.

**Skill list (16)** — see ADR 0001 for the owners.
`nkp` (router), `nkp-install` (references: nutanix, metal, preprovisioned, cloud), `nkp-airgap`, `nkp-cluster-lifecycle`, `nkp-upgrade`, `nkp-troubleshooting`, `nkp-networking`, `nkp-platform-apps-gitops`, `nkp-identity-security`, `nkp-storage-backup`, `nkp-observability`, `nkp-gpu-ai`, `nkp-flow-cni`, `nkp-vpc`, `nkp-ndk`, `kubernetes-core`.

**Authoring plan** (brief for each author: `docs/AUTHORING.md`)
1. Pilot — done 2026-11-02, git tag `format-v1` (3 eval runs: 10/10, 16/16, 6/6; 2 Opus reviews; results in `evals/runs/`). Pilot: `skills/_shared/RULES.md` + check script, `nkp`, `nkp-install` (Nutanix reference only). Opus review (fresh session) + evals. Fix the format.
2. Then, in parallel batches of 3-4 (one Opus author per skill, each in its own worktree, owner skills first), in this order: airgap → cluster-lifecycle → upgrade → troubleshooting → networking → platform-apps-gitops → identity-security → storage-backup → observability → gpu-ai → flow-cni → vpc → ndk → kubernetes-core. The remaining `nkp-install` reference files go with the first batch.
3. Each skill: Opus author (high) → evals → Opus review in a fresh session (high) → fix → commit.

**Evals**: 3-5 prompts for each skill in `evals/<skill>.md` (task + expected commands or answer). Eval model: DeepSeek-V4.1-Flash, thinking low, only the skills, no web.

## Carry-over (sessions of 2026-11-01 to 2026-11-03) — read this first in a new session

**State at the commit that adds this section (after 3f0cfa2).** 5 skills exist: `nkp`, `nkp-install` (references: nutanix, kommander, metal, preprovisioned, cloud), `nkp-airgap`, `nkp-cluster-lifecycle`. `python3 scripts/check_skills.py` passes. The format is fixed at tag `format-v1`, plus ADR 0003 amendments (cluster env file, `USER-TERMINAL`, `source ... 2>/dev/null`, local `Site variables` tables).

**Batch 1 is finished (2026-11-02).** Eval run 20/20 (`evals/runs/2026-11-02-batch1/`), Opus review (go-with-changes, 0 blockers, 8 major), fix pass `44943ed`. The worktrees are removed (the branches stay). The fix pass added three checks to `scripts/check_skills.py` (`rm-glob`, `grep-secret`, `eval-id`). Re-run E13 and L1 with the next eval run.

**Batch 2 is finished (2026-11-02).** `nkp-upgrade`, `nkp-troubleshooting`, `nkp-networking` (10 skills total with the router). Results in `evals/runs/2026-11-02-batch2/`: two Opus reviews (go-with-changes, 0 blockers), eval runs 17/18 and 7/8, fix passes A, B, C (`3768953`, `7309a80`, `856f953`), re-run 12/15, final check 3/3 (`9dcf5b1`). Worktrees removed, branches kept. New open items: P-20 (closed), P-21..P-27, A-20..A-22, N-20..N-26.

**Batch 3 is finished (2026-11-03).** `nkp-platform-apps-gitops`, `nkp-identity-security`, `nkp-storage-backup` (10 skills with the router; 6 to go). Results in `evals/runs/2026-11-03-batch3/`: Opus review (go-with-changes, 0 blockers, 6 major), eval run 22/23, parent pointer pass `cfc4589`, fix passes per skill (`fixes-gitops.md`, `fixes-identity.md`, `fixes-storage.md`), re-run 9/9 (`d09eecc`). Worktrees removed, branches kept (`skill/*`, `fix/b3-*`). New open items: P-30..P-33, P-40..P-46, D-20..D-25.

**Batch 4 is finished (2026-11-03).** `nkp-observability`, `nkp-gpu-ai`, `kubernetes-core` (13 skills with the router; 3 to go). Results in `evals/runs/2026-11-03-batch4/`: eval run 24/24, Opus review (go-with-changes, 0 blockers, 5 major), fix passes (`fixes-gpu.md`, `fixes-obs.md`, `fixes-core.md`), re-run 7/7 after one parent fix (`2d26f62`). `check_skills.py` now allows `nvidia.com` and `nvcr.io`. Worktrees removed, branches kept (`skill/*`, `fix/b4-*`). New open items: Q-10, D-30..D-34 (D-32 closed), D-40..D-46.

**Batch 5 is finished (2026-11-03). All 16 skills exist.** `nkp-flow-cni`, `nkp-vpc`, `nkp-ndk`. Results in `evals/runs/2026-11-03-batch5/`: eval run 21/21, Opus review (go-with-changes, 0 blockers, 4 major, 19 minor), fix passes (`fixes-flow.md`, `fixes-vpc.md`, `fixes-ndk.md`), re-run 10/11, one parent fix (ndk TLS `SECRET` row), K1 re-run 1/1 (`d72722c`). Worktrees removed, branches kept (`skill/*`, `fix/b5-*`; `fix/b5-flow` is an empty hung run). New open items: N-30..N-36 (N-35 closed), N-40..N-46 (N-06 closed), D-50..D-56. AGENTS.md lab list extended: read-only `tar -xO`, client-only `helm template`, `curl` status code, public cert SANs, `ip`, `docker … inspect`.

**Lab test 1 and its fix pass are finished (2026-11-03/04).** NKP 2.19.0 from scratch with only the skills (`nkp-skills` + `ntnx-skills`): a licensed Ultimate management cluster, a workload cluster in a new workspace, an exposed workload cluster in a Flow VPC, then all deleted (`research/raw/lab-runs/2026-11-03-test1/`, `LEARNINGS.md`). Retro and plan: `research/lab-runs-2026-11-03-fixes.md`. Fix pass: F0 `09135a0` (ADR 0004 companion `ntnx-skills`, check script accepts the nine `nutanix-*` names, rule 2 "ask them to type yes", AGENTS.md lab SSH and child timeout rules), F1–F7 merged (install, identity, delete, vpc, storage, airgap, core), eval run 22/25 → 25/25 after 3 skill fixes (`7fe0e6a`), Opus review go-with-changes (0 blocker, 1 major, 13 minor) and fix pass `8d5ceeb` (`evals/runs/2026-11-04-labtest1/`). Worktrees `fix-lt1-*` stay for cleanup (branches `fix/lt1-*` kept). Open items: closed A-05, P-11, N-41, N-44, N-05, N-26; P-40 narrowed to a paid key; new A-30, A-31, P-56, D-60, D-61, N-50; still open P-07, N-43, A-06, P-55.

Facts and rules from lab test 1 that later authors must respect:
- Times [live 2.19.0]: management create 22–24 min (3 CP + 4 workers on a site mirror; machines 6, pivot 8, Kommander 15), its dry run ~3 min (kind + CAPI + preflight); Ultimate tier apps +11 min after the license patch; workload create 3–13 min, its dry run < 20 s, apps `Reconciled` up to 38 min later; workload delete 28–57 s; management delete 5–7 min. Two workload deletes in parallel on one management cluster worked.
- A workload cluster has no `kommander` namespace: its platform apps are in `$WORKSPACE_NS` on the workload cluster (Ultimate: 19 HelmReleases, 16 AppDeployments, ~122 pods). Never write `-n kommander` with `CLUSTER_KUBECONFIG` for a workload cluster.
- A workload create writes no kubeconfig file and prints no success line. `--self-managed` writes `$PWD/<cluster>.conf`.
- A Pro/Ultimate key is bound to the management cluster name; the webhook error prints the full key (mask `[masked]`). An NKP delete keeps one CSI volume group per PV (cleanup with skill `nutanix-storage`); NKP FIPs stay `ASSOCIATED_TO_PRIVATE_IP` and answer `000`.
- The only site additions that the end-to-end install needed: `--insecure` (default PC certificate, no SAN) and `--timeout 60m`.
- Companion skills (ADR 0004): name the skill and the RECIPES heading, add the fallback "the user does it in Prism Central", and run a recipe in a marked bash block with `python3 - <<'PY'`. A release of the NKP skills names the `ntnx-skills` commit it was tested with (this pass: `464d7b8`).
- A skill that asks a question must say "stop after the questions" when a value block would follow (E18 lesson, rule 4).

Process lessons from lab test 1 (also in AGENTS.md "Live lab"):
- The lab agent runs on a laptop; the operator host is the bastion over SSH. The skills assume the agent runs on the operator host; keep the SSH form out of the skills.
- Child agents: `timeout` + `ServerAliveInterval=15 -o ServerAliveCountMax=4` on every ssh, `sleep` ≤ 120 s as its own call, creates and deletes in tmux. Recovery: interrupt → cancel → resume.
- DeepSeek-V4.1-Flash provider timeouts: retry, stop after 3. Claude Code relay errors (all 7 authors failed in 3 s, 2026-11-04): start one probe child again first, then the rest.
- The old `cluster.yaml` on the bastion is a fast cross-check of old values; a from-scratch agent does not know it exists.

Gaps found for `../ntnx-skills` (not changed in this session; decide in a ntnx-skills session): the free-IP ARP probe cannot prove an overlay IP free from a host outside the VPC (one gotcha sentence for VPC overlays); no recipe lists the VPC gateway `externalIps` as an exclusion list for a FIP address.

Facts and rules from batch 5 that later authors must respect:
- Flow CNI: the management cluster serves chart `nutanix-flow-cni` 1.1.0 from the CAREN chart server; the images are not in the NKP bundle (portal dark-site bundle, prestage P8). The guide `yq` step empties the file; the skill `yq -i` handles `NKPCluster` and `Cluster`. The I5 dry run must show that no webhook adds `addons.cni` back (N-31 open).
- MetalLB v0.15.3 reads only `metallb.io/address-pool`; a pool annotation change gives the Service a new IP.
- VPC: the lab management cluster is in a Flow VPC (exposed layout, 2 floating IPs). The external endpoint is in the API SANs; `CP_VIP` is not. Patch the NKPCluster, not the KommanderCluster. DSR worked 6/6 in the VPC (N-01 partly answered).
- Env files (M2): a workload cluster on another subnet puts `SUBNET` (and `PE_CLUSTER`, `STORAGE_CONTAINER` when they differ) in its cluster env file; the site file keeps the management values. ADR 0003 amendment 2026-11-03 records this.
- NDK: the 2.19.0 bundle has the NDK 2.3.0 chart, catalog, and all six images, so the guide `nkp create catalog-bundle` is not needed. Intercom port is TCP 2021 only. `SECRET` TLS mode with `clusterName` fails. Many NDK specs are immutable (delete and make again). The NDK alert rules need an event exporter that NKP does not ship (D-54).
- A skill row that names a value (Secret name, path) must also say "ask the user, never propose" — the small model fills in a name otherwise (K1 lesson).

Facts and rules from batch 4 that later authors must respect:
- NKP NFD labels by PCI class and vendor: NVIDIA nodes have `feature.node.kubernetes.io/pci-0302_10de.present` or `pci-0300_10de.present`, never `pci-10de.present`.
- GPU pool taint key is `nvidia.com/gpu` (`NoSchedule`); the operator and DRA driver tolerate only this key.
- Name exceptions to the gitops slot-2 rule: `velero-overrides`, `nvidia-gpu-operator-config-overrides` (read by `nvidia-dra-driver`), `logging-operator-logging-overrides` (target cluster). Slot 2 applies only when the HelmRelease lists `<app-id>-overrides` (check with O2).
- Never write the Secret `dkp-loki` (Rook bucket Secret). Helm owns the Alertmanager Secret: each `kube-prometheus-stack` values change or upgrade undoes a replaced Secret.
- `nkp-deletion-protection` (ValidatingAdmissionPolicy) is owned by identity `gatekeeper.md` G5.
- Guide app versions are often not ClusterApps on 2.19.0: read `get clusterapps` first.
- A YAML example with a proposed name invites a rule 4 break: give a values-file block with empty guarded variables instead (B9 lesson).
- Open: NAI and AMD bundles for 2.19 (D-44, D-45); no lab run of GPU, Loki, or Alertmanager steps yet (Starter lab, no GPU).

Facts and rules from batch 3 that later authors must respect:
- App values: before Kommander exists → `kommander.yaml` `apps.<app>.values` (skill `nkp-install`); after → AppDeployment overrides (gitops `overrides.md` O3/O4). A ConfigMap named exactly `<app-id>-overrides` in the HelmRelease namespace is read directly (slot 2); a new override must not use that name (exception: `velero-overrides`, the guide name). Slot 3 (`<app-id>-cluster-overrides`) can hold NKP values, for example the Dex issuer (P-33). Observability and gpu-ai overrides point to O3/O4; do not copy the merge model.
- Override ConfigMaps can hold client secrets (`dex-*`, `dex-k8s-authenticator-*`, `traefik-forward-auth-*`, `kube-oidc-proxy-*`). Read override values only with the gitops O2 `awk` mask.
- Secrets into a Secret object: `--from-file=key=<(printf %s "$(printenv VAR)")`, not `--from-literal` (process list).
- The UI path on 2.19.0 is `/dkp/kommander/dashboard` (the guide's `/nkp/...` gives 404). `cluster-admin` has `nonResourceURLs: ["*"]`.
- NKP Gatekeeper constraints: never delete them or set `warn`/`dryrun` (identity `gatekeeper.md` G1/G2).
- Velero, Rook Ceph, COSI: not installed on the Starter lab; their steps are `[pdf]`. The `velero` CLI is not in the bundle; without it, stop (storage `velero.md`).
- Optional follow-up for `nkp-airgap`: a prestage row for the velero v1.18 CLI tarball with its SHA-256 (then storage `velero.md` Facts can point to it).

Lab facts found in batch 2 that later authors must respect:
- `nkp diagnose` is CHANGES (privileged pods on every node). Its 2.19.0 defaults: collector `v0.14.0`, `pause-busybox:3.6`, 600 s.
- `spec.rolloutAfter` is dropped in 2.19; the field is `spec.rollout.after` (last resort, A-20).
- `nkp upgrade platform-apps` takes `--workspace <name>` (not `--namespace`); `--disable-appdeployments` does not exist.
- MetalLB BGP is blocked on 2.19.0: the API rejects every `BGPPeer` (N-20).
- Proxy: on vSphere, AWS, Azure, GCP and pre-provisioned, `--http-proxy/--https-proxy/--no-proxy` set only the CAPI controllers; nodes need `--control-plane-*-proxy` and `--worker-*-proxy`. AKS has only `--worker-*`, EKS none. A proxy URL can hold a password (`proxy.md` X0).
- Most 2.19 HelmReleases use `chartRef` to an `OCIRepository`; Flux sources of a workload cluster are on that cluster.
- Registry mirror or CA change on a running cluster: owner `nkp-cluster-lifecycle` V8. The webhook pings each registry URL (P-27 open).

Rules changed in batch 2 (synced): rule 3 (ask for the cluster name; never take it from another conversation), rule 4 (no append block and no `<...>` block value before the user gives the value). Router step 3: check the skill list, do not guess "not installed".

**Cross-skill items that later authors must cover** (the batch 1 authors asked for them; put each in the author task of the owner skill):
- `nkp-identity-security` (Gatekeeper library files), `nkp-platform-apps-gitops` (Sealed Secrets, `kubeseal`), `nkp-observability` (Trivy DB), `nkp-ndk` (alert YAML): each points to `nkp-airgap` `references/prestage.md` and uses the shipped assets there.
- `nkp-storage-backup`: the `nutanix-volume-metal` StorageClass, and volumes left after a delete (P-11). `nkp-vpc`: VPC leftovers (N-05). `nkp-gpu-ai`: the GPU operator (lifecycle owns only the GPU node pool).
- A-05 (management kubeconfig path) is now assumed for every `--self-managed` provider, not only AHV. It stays open until a lab create.

**Process lessons (apply in every batch):**
- Give each parallel author an open-item ID range (for example P-20..P-29). Two batch 1 authors both used P-08 and P-09, and the parent renumbered them to P-13 and P-14.
- A subagent report can be cut short. Read the full last assistant message from its session `.jsonl` file, and save reviews to `evals/runs/<run>/review.md`.
- A reviewer can hang on a tool call (zsh `${!v}`). After a 15-minute stall advisory, read the session tail, then `subagent_interrupt`.
- Eval prompts go to the eval model without the expected answers. Grade in the parent.
- After a merge, run `python3 scripts/check_skills.py --sync`, because the rules block in a branch can be older.
- Lab facts are in the git-ignored `.local/lab.md`. Server-side dry runs are allowed with the webhook check (AGENTS.md).
- Give children a timeout on every remote command: `timeout 120 ssh -n -o BatchMode=yes -o ConnectTimeout=10 …` and `kubectl --request-timeout=30s`. Never redirect to `/dev/stdin`. A batch 5 fixer hung 64 minutes on one ssh call, and `subagent_cancel` could not stop it (no process identity); start a replacement on a new branch.

**Next batches** (after batch 1 is finished), 3 authors each, owners first: batch 2 = `nkp-upgrade`, `nkp-troubleshooting`, `nkp-networking`. Batch 3 = `nkp-platform-apps-gitops`, `nkp-identity-security`, `nkp-storage-backup`. Batch 4 = `nkp-observability`, `nkp-gpu-ai`, `kubernetes-core`. Batch 5 = `nkp-flow-cni`, `nkp-vpc`, `nkp-ndk` (after lab tests if possible; NEXT-STEPS §3). Each batch: author tasks from `docs/AUTHORING.md` + the cross-skill items above + an ID range → merge → Opus review → evals → fix → commit. Use `/clear` between batches; this section and the repo carry the state.

**Next work (all skills exist, lab test 1 done):** lab test 2 (Flow CNI on Rocky, path A then B; also P-55 workspace delete through the UI, A-30/A-31 mirror checks, D-60 PVC delete, `nkp create workspace --help` into `nkp-help-ops.txt`) and lab test 3 (cluster in a VPC: N-43, N-50, N-02 management create in a VPC); the refresh scripts in §2 step 5; the tag `nkp-2.19` after lab tests 2 and 3 (user decision 2026-11-04).

**Prompt for the next session:** "Read AGENTS.md and research/NEXT-STEPS.md (Carry-over). Plan lab test 2 (§3)."

Batch 5 author notes: `nkp-flow-cni` (raw `06-flow-cni.md`; Cilium vs Flow CNI choice at create time is owned by `nkp-install`/`nkp-networking` — point there), `nkp-vpc` (raw `08-nkp-in-vpc.md`; VPC leftovers N-05 and N-01 Cilium DSR), `nkp-ndk` (raw `07-ndk.md`; D-01..D-04; NDK alert YAML from `nkp-airgap` prestage; the product catalog bundle has NDK 2.3.0 only [live]). All three are best after the lab tests in §3; without them, mark field facts `[field]` and keep UNKNOWN lines. ID ranges: flow-cni N-30..N-39, vpc N-40..N-49, ndk D-50..D-59. Tell authors to commit after each file and to give values-file blocks with guarded variables (rule 4).

## 2. Refresh plan — confirmed 2026-11-01 (scripts in step 5 are built after the skills)

1. Each skill has `nkp_versions: [...]` and `last_verified: <date>` in its front matter. Each fact that can change has a source tag (`[live 2.19.0]`, `[pdf 2.19 p.N]`, `[portal: <title>]`).
2. History is kept in git: one tag for each NKP version (`nkp-2.19`) and version folders for the sources (`raw/pdf/<v>/`, `raw/live/<v>/`). An air-gapped site checks out the tag that matches its version.
3. When a new NKP version comes out:
   1. split the PDF into `raw/pdf/<v>/`
   2. run the read-only collection script into `raw/live/<v>/`
   3. compare with the previous version (PDF sections, `nkp --help`, ClusterClass variables, ClusterApps, bundle layout, CRDs)
   4. grep the skills for every fact the comparison touches
   5. update those skills, add a "Changes in <v>" section, and get an Opus review
   6. go through `OPEN-ITEMS.md`, then tag the repo
4. New discoveries between releases go in a normal commit with a source tag. Unconfirmed claims stay `[field]`.
5. To build: `scripts/collect-live.sh` (read-only, scrubs its output) and `scripts/diff-versions.sh`.

## 3. Agent-run lab tests — approved in principle 2026-11-01 (each test still needs a written plan and approval; write the test 1 plan after the pilot)

Reason: about half of the open items can be closed only with a real cluster (F-02, F-03, F-05, F-06, F-07, N-01, N-02, N-05, D-01, D-04, P-04). The tests also check whether the skills work.

Safety limits:
- a separate test area (its own PC project or subnet, a fixed IP range), with the cluster name prefix `skilltest-`
- the agent may only create and delete `skilltest-*` workload clusters, using the existing management cluster. It must never change the lab management cluster, Prism Central settings, or the registry.
- the user approves a written plan for each test
- all commands and outputs are logged to `research/raw/lab-runs/<date>-<test>/` (scrubbed), and they count as `[live]` evidence
- at the end, the agent deletes the cluster and checks that nothing is left (including the Prism Central objects in the VPC)

From-scratch variant (lab test 1, 2026-11-03; use it when no management cluster exists):
- the agent may also create and delete a management cluster, with the name the user gives (a Pro or Ultimate key is bound to the cluster name, so `skilltest-` is not always possible)
- the user names the PC objects that the agent may delete (old leftovers); all other limits above stay
- the agent applies a license only with the key that the user put in the site env file, and masks the webhook error (it prints the key)

Facts needed from the user: free IP ranges (control-plane VIP, MetalLB), the allowed subnets and PC project, whether a Rocky 9.8 image is in PC, whether Network Controller 7.6 runs, and whether a Pro or Ultimate trial license is possible.

First tests:
1. a plain workload cluster with Cilium (baseline, using the draft skill)
2. a Flow CNI cluster on Rocky: path A, then path B
3. a cluster inside a VPC (TN-2207), which also answers N-01 (Cilium DSR)
