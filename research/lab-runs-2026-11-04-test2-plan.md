# Lab test 2 — plan (Flow CNI on Ubuntu, unsupported; path A then path B)

Status: **draft v2 (blind DeepSeek prompts), waits for user approval.** No lab use before the user types "yes" to this plan.
Date: 2026-11-04. NKP 2.19.0. Skill commits under test: `nkp-skills` `47bfa92` (or the HEAD at the start), `ntnx-skills` HEAD at the start (record the SHA in `LOG.md` §0; no `ntnx-skills` change in this test).
Evidence: `research/raw/lab-runs/2026-11-04-test2/` (`BRIEF.md`, `LOG.md`, `t<k>-*.md`, `LEARNINGS.md`).

## 0. Start state and what follows from it

- Lab test 1 deleted all clusters (t8: `nkp-mgmt-01` gone, VGs 0, FIPs 0 associated). So no management cluster exists. This test uses the **from-scratch variant** of NEXT-STEPS §3 again: it creates a management cluster first.
- Workspace management needs Ultimate [pdf p.27], and a Pro/Ultimate key is bound to the cluster name [live 2.19.0]. So the management cluster is `nkp-mgmt-01` again, with the trial key, and the **license step is in scope** (first live run of the license `sed` mask).
- Flow CNI is a workload-cluster feature only (skill `nkp-flow-cni`). The management cluster stays Cilium.

## 1. Clusters, names, order

| # | Object | Name | OS / CNI | Size | IPs (from the user, §2) |
|---|---|---|---|---|---|
| 1 | Management cluster | `nkp-mgmt-01` (license name) | Ubuntu 24.04 / Cilium | CLI defaults 3 CP + 4 workers | `CP_VIP` M, `LB_IP_RANGE` M1–M5 |
| 2 | Workspace | `skilltest-flow` (display `skilltest flow`) | — | — | — |
| 3 | Workload cluster, path A | `skilltest-flow-a` | Ubuntu 24.04 (unsupported for Flow) / Flow CNI (HelmChartProxy) | CLI defaults 3 CP + 4 workers | `CP_VIP` A, `LB_IP_RANGE` A1–A5 |
| 4 | Workload cluster, path B | `skilltest-flow-b` | Ubuntu 24.04 (unsupported for Flow) / Flow CNI (`addons.cni.provider: Flow`) | same as A | `CP_VIP` B, `LB_IP_RANGE` B1–B5 |

Order (sequential; one cluster change at a time):

`T1 preflight (RO)` → `T2 mgmt create + license + workspace` → `T3 flow-a (path A)` → `T4 smoke test + D-60 on flow-a` → `T5 delete flow-a` → `T6 flow-b (path B)` → `T7 delete flow-b + workspace UI delete + R5 check` → `T8 mgmt delete + final leftover audit` → `T9 review`.

A and B do not run at the same time: fewer VMs, and each delete is a clean leftover measurement (N-36).

## 2. User facts (answered 2026-11-04)

| # | Fact | Answer |
|---|---|---|
| Q1 | Node OS | **Ubuntu 24.04 only, no Rocky.** The user overrides the Flow CNI "Rocky on all nodes" need [portal] from the start. The prompt says: "Ubuntu is a user decision; Flow CNI does not support it; go on and record what breaks." Results are tagged `[live 2.19.0, unsupported OS]`. Grading: the executor must still name the Rocky need (step 1) in its log. |
| Q2 | Network Controller, Flow mode | NC 7.6 or later, Integrated with Prism Central (user). PC 7.6.0.10, AOS 7.6, AHV 11.2 (ntnx HANDOFF). |
| Q3 | Flow CNI images | **Dark site**: bundle `~/flow-cni-1.1.0.tar` on the bastion (scrub the path as `<flow-bundle>`). Also tests F-03, N-30. The push into the site Harbor project is a registry write: in scope only for this bundle (user answer "dark site bundle"). |
| Q4 | Workload size | CLI defaults: 3 CP + 4 workers for each cluster. |
| Q5 | IPs | mgmt `<net>.50` + `.51–.55`; flow-a `.60` + `.61–.65`; flow-b `.70` + `.71–.75`. T1 runs the free-IP check. |
| Q6 | Workspace | `skilltest-flow` |
| Q7 | License | the Ultimate trial key for `nkp-mgmt-01` is in `~/nkp-site.env`. |
| Q8 | Subnet, CIDRs | same VLAN Basic subnet (`SUBNET`); default CIDRs for both (A and B never run at the same time). |
| Q9 | Workspace UI delete | **The executor does it with the browser tool** (`agent_browser`), with screenshots as proof in `research/raw/lab-runs/2026-11-04-test2/screens/` (before, the dialog, after). This tests a path the skill gives to the user. The UI password is read on the bastion only (`nkp get dashboard`); the executor types it into the browser and never logs it. Screenshots must not show a password or a token. |
| Q10 | End state | delete everything, `nkp-mgmt-01` too. |
| Q11 | Path B | the executor explores it itself; its CHANGES blocks on a cluster stop for the user's "yes" through the parent. |

## 3. Safety limits (NEXT-STEPS §3, from-scratch variant)

- Test area: the subnet and IP range of Q5/Q8 only. Workload names start with `skilltest-`. The management cluster has the license name `nkp-mgmt-01` (the user gives it).
- The agent creates and deletes only these objects: `nkp-mgmt-01`, `skilltest-flow-a`, `skilltest-flow-b`, the workspace `skilltest-flow`, the smoke test namespace, the Flow HCP and pull Secret, and the PC objects that NKP makes for them (VMs, VGs, IP reservations, categories). The only registry write: the push of the Flow CNI bundle (Q3); it stays in Harbor after the test (site content).
- Never change: Prism Central settings, the PE cluster, the Harbor registry (read-only `GET /v2/...`, except the Q3 bundle push), the bastion outside `~`, VMs not made by NKP for these clusters (bastion, AD VM, PC VM), old site objects. PC objects that the agent may delete: only the leftovers of the clusters above (no old leftovers are known after lab test 1 t8; T1 audits them; any other leftover → ask).
- License: only with the key that the user put in `~/nkp-site.env`. Both License patch blocks run through the `sed` mask. Never a raw webhook error in a log or the chat.
- Secrets: never print an env file, kubeconfig, Secret data, `env`, `set`, the dry-run YAML, or the Flow HCP / HelmReleaseProxy as `-o yaml` (connected mode holds the pull token).
- Server dry runs only after the webhook `sideEffects: None` check; log each one.
- All commands and outputs go scrubbed to `research/raw/lab-runs/2026-11-04-test2/` and count as `[live 2.19.0]`.
- End: delete the clusters, then the leftover audit (§7). Nothing may stay except the site file, the bundle, and the site objects (image, subnet).
- Stop conditions: a step outside this plan; a PC object that the audit cannot tie to these clusters; a failed safety check (for example I5 shows `cni` after the webhooks); 3 DeepSeek timeouts in a row.

## 4. Steps

Legend for "Exercises": skill/file section. New lab test 1 fix blocks (first live run) are **bold**.

| T | Name (child) | What | Closes / answers | Exercises |
|---|---|---|---|---|
| T1 | `lt2-test-1` (RO) | 1. Bastion check (`nkp version`, `tmux -V`, `yq --version` must be mikefarah v4; else stop, ask the user). 2. Env file check N2 + **N3 checks**: `pc login` 200, `openssl` SANs, **ping of every LB IP**, **mirror `/v2/` 401 + `mirror login` 200**. 3. ntnx free-IP check for the three VIPs and 15 LB IPs. 4. ntnx `nutanix-nkp` "Site preflight" + "Leftover audit" for `nkp-mgmt-01`, `skilltest-` (baseline). 5. **A-30**: nodes.md tags/list with `repo='registry.k8s.io/pause'`, then `repo='pause'`. 6. **A-31**: same block with the `_catalog` URL. 7. Image check for the Ubuntu image (ntnx `nutanix-vm` "Images: check before a create"). 8. Save `nkp create workspace --help` (and `nkp delete --help`, to record that `delete workspace` is absent) into `research/raw/live/2.19/nkp-help-ops.txt` with a `##########` header, like the other entries. | A-30, A-31; help text for R5; N3 fix blocks (lab test 1 N7–N10) | nkp-install SKILL "Check the operator host", nutanix.md N2, **N3**; nkp-airgap nodes.md "Check that the site mirror has an image"; ntnx `nutanix-networking` "Free IP check", `nutanix-nkp` "Site preflight", "Leftover audit", `nutanix-vm` "Images" |
| T2 | `lt2-build-1` | 1. Management env files, create script N4C + `--insecure` + `--timeout 60m`. 2. N4D dry run (~3 min). 3. **Create in tmux with log** (22–24 min), **kubeconfig line appended after RC=0 + `test -f`** (one approval). 4. Verify. 5. **License** (dry run + patch through the **`sed` mask**, delete the Secret after a denial), wait for Ultimate apps (15 min re-check). 6. Workspace: R5 dry run `-o yaml`, create, read `WORKSPACE_NS` back (suffix). | P-40 (second trial read, `endDate`), S-fixes; A-05 re-check | nkp-install SKILL "Create the cluster", **"Set the kubeconfig variables"**, "Verify"; nutanix.md N4C, **N4D (grep, P-07 value length)**; identity SKILL **"License"** (mask, pre-check `Allocated resources`, Done-when); rbac **R5 create** |
| T3 | `lt2-build-2` | flow-cni step 1 (prereqs: Rocky need named, then the user override for Ubuntu; class, ConfigMap 1.1.0, tag list; user confirms NC/mode) → step 2 dark site (push `<flow-bundle>`; `tar -tf` for N-30) → step 3 path A → install.md I1 (N5 script, CLI default size) → I2 dry run → I3 `yq` CNI delete + check → I4 HCP file → **I5 server dry run (webhook check first)** → I6 apply → step 4 check → "What changes" reads. | **N-31** (dry-run kind, variable path, webhook adds `cni` back?), **N-32** (user HCP on the CAREN chart server), F-03 + N-30 (dark site only), **F-04** (CRDs: `kubectl get crds \| grep -E 'ovn\|flow\|nutanix'`, Service ports of the Flow pods), **F-05** (MTU), **F-06** (kube-proxy), **F-07** (non-True HelmReleases on a Flow cluster) | nkp-flow-cni SKILL steps 1–4, install.md I1–I6; nkp-install N5, "Set the kubeconfig variables" (workload: `nkp get kubeconfig` mandatory), "Verify" (workload branch, `-A --all`, 30–40 min) |
| T4 | `lt2-test-2` | C12 smoke test on flow-a: image tags from the mirror (nodes.md block), steps 1–4 (PVC, pod, LB, `curl` 200). Save the PV handle. Step 5 namespace delete. Then ntnx `nutanix-storage` "List and find volume groups" for the handle uuid (after 1 min and after 5 min). | **D-60**; MetalLB L2 on a Flow cluster (F-07 part, flow-cni "Egress service" row) | nkp-storage-backup csi.md **C12 steps 1–5**; nkp-airgap nodes.md; ntnx `nutanix-storage` RECIPES |
| T5 | `lt2-build-3` | Delete flow-a: D1, D2 gate (PV list), D3 (28–57 s), **D3 Done-when: VIP ping + LB curl fail**, then flow-cni "Delete" (HCP stays? N-36 read + CHANGES delete), **D5.1 mirror Secrets, D5.2 VGs (only if D2 PV list not empty), D5.4 files**. ntnx "Leftover audit" for `skilltest-flow-a`; PC VPC list for a Shared Services VPC (read-only). | **N-36** (HCP + PC objects after delete), D-60 cross-check (VG count after a cluster delete with no user PVC) | nkp-cluster-lifecycle delete.md D1–D3, **D5.1, D5.2, D5.4**; nkp-flow-cni "What changes" Delete; ntnx `nutanix-nkp` "Leftover audit", `nutanix-networking` (VPC list) |
| T6 | `lt2-build-4` | Path B. 1. The executor reads flow-cni step 3 and records that path B is "Not in the skills". 2. The executor explores by itself: read-only reads of the cluster (schema, CAREN ConfigMaps, `--help`), then it writes its own dry-run edit, server dry run, and create blocks, marked `[exploration]`. 3. Gate: before its first CHANGES block on a cluster, it stops and reports the block. The parent checks only the safety limits (§3), gets your "yes", and resumes it with the unchanged block. 4. flow-cni step 4 checks and the F-05/F-06/F-07 reads again. | **F-02** (works or not; no support statement), N-31 (second dry run), compare with path A | nkp-flow-cni step 3 (stop text), step 4; nkp-install N5; executor blocks marked `[exploration, not a skill]` |
| T7 | `lt2-build-5` | Delete flow-b (D1–D3, D5.1, D5.2, D5.4; the CAREN HCP and the pull Secret: owned or left? ). Then R5 "Delete a workspace": READ-ONLY block before, **UI delete by the executor with `agent_browser`, screenshots before/dialog/after**, READ-ONLY block every 2 min for 20 min. If `Terminating` stays: record the conditions and **stop** (no finalizer removal; ask the user). | **P-55** (UI path finishes or not), N-36 for path B | nkp-cluster-lifecycle delete.md; nkp-identity-security rbac.md **R5 delete** (UI path + READ-ONLY check); `nkp get dashboard` (UI URL and login) |
| T8 | `lt2-build-6` | D4 management delete **in tmux with the delete log** (5–10 min); `docker ps -a`, bootstrap.conf gone; **D5.2 VGs** (Ultimate mgmt ≈ 20; ntnx recipe, plan, delete), **D5.4 files**, **D5.5 site file check**. Final audit §7. | Second D4 timing; D5 blocks first live run | delete.md **D4 (tmux)**, **D5.2, D5.4, D5.5**; ntnx `nutanix-storage`, `nutanix-nkp` "Leftover audit" |
| T9 | `lt2-review` | Opus review of all `t*-*.md` + `LEARNINGS.md` → `research/raw/lab-runs/2026-11-04-test2/review.md`: which open items close, which skill rows to fix. Then a fix plan file (not in this test). | — | — |

Not in scope: egress-vpc.md (namespace in a VPC, EgressIP; N-33), NKP upgrade (N-34), Flow on the management cluster, any `ntnx-skills` change, the tag `nkp-2.19`.

## 5. Executors and model routing

| name | agent kind | role | model | worktree |
|---|---|---|---|---|
| lt2-test-1 | bare executor | test | wskn-flare/DeepSeek-V4.1-Flash (medium) | none |
| lt2-build-1 | bare executor | build | wskn-flare/DeepSeek-V4.1-Flash (medium) | none |
| lt2-build-2 | bare executor | build | wskn-flare/DeepSeek-V4.1-Flash (medium) | none |
| lt2-test-2 | bare executor | test | wskn-flare/DeepSeek-V4.1-Flash (medium) | none |
| lt2-build-3 | bare executor | build | wskn-flare/DeepSeek-V4.1-Flash (medium) | none |
| lt2-build-4 | bare executor | build | wskn-flare/DeepSeek-V4.1-Flash (medium) | none |
| lt2-build-5 | bare executor | build | wskn-flare/DeepSeek-V4.1-Flash (medium) | none |
| lt2-build-6 | bare executor | build | wskn-flare/DeepSeek-V4.1-Flash (medium) | none |
| lt2-review | bare reviewer, fresh standalone session | review | claude-code/claude-opus-5-5 (high) | none |

**Prompting (hardening, user decision 2026-11-04).** DeepSeek does all the work and all the exploration. The parent only prompts, gates, and records.
- Blind prompts: each child prompt holds only the goal of its T-row (for example "create workload cluster `skilltest-flow-a` with Flow CNI, path A, in workspace `skilltest-flow`"), the user facts of §2, the BRIEF, and the start point `skills/nkp/SKILL.md` (router). It holds no skill section names, no commands, no expected outputs, and no open-item hints. The child finds the path through the skills. A child that cannot find a step records it as a learning.
- The "Exercises" column of §4 is for the parent's grading only. It does not go into a prompt.
- No parent help during a run. The parent does not write blocks, fix files, or give hints. It may send only "continue from here" (after a hang or a gate "yes") or "stop". When a child is stuck, it ends with status `failed at step X` and its learnings. The parent then starts the next child with the same blind prompt, plus only the facts that the failed child found on the cluster.
- Command audit: each child keeps every block it sends in `/tmp/<task>/NN-<name>.sh` and copies them, scrubbed, into `research/raw/lab-runs/2026-11-04-test2/blocks/<task>/`. After each T, the parent checks them against §3 (no secret print, no change outside scope, timeouts present). It does not judge them as solutions.
- Gates that stay with the user: the path B CHANGES blocks, any PC delete outside a task's own leftover list, any finalizer removal (never), and any step outside the T-row.

- The parent (Opus) coordinates, reads every child log, writes `LOG.md` and `LEARNINGS.md`, and does all git commits. Children do not commit, do not edit skills, and do not start other agents.
- Children get both skill sets (ADR 0004) and the BRIEF.md of this test.
- Child rules (AGENTS.md "Live lab"): every ssh is `timeout <sec> ssh -o BatchMode=yes -o ConnectTimeout=10 -o ServerAliveInterval=15 -o ServerAliveCountMax=4 <bastion> 'bash -s' < block.sh`; `--request-timeout=30s` on every kubectl read; `sleep` ≤ 120 s, its own call, never with ssh; creates and deletes in tmux on the bastion with a log, then `tail` filtered for password/token/secret. Never redirect to `/dev/stdin`.
- DeepSeek "Request timed out" before a tool call: retry; after 3 in a row, stop and tell the user (no fallback model).
- Hung child: `subagent_interrupt` → `subagent_cancel` → `subagent_resume` with "continue from here".
- Approval: the user's "yes" to this plan is standing approval for the CHANGES blocks inside §4 scope only. Each child still logs the plan of each CHANGES block that it runs. Exceptions that need a new "yes" from the user: the path B exploration block (T6, after the parent writes it), any PC object delete that is not on the T5/T7/T8 plan lists, any finalizer removal (never in this test).

## 6. Evidence

- Folder `research/raw/lab-runs/2026-11-04-test2/`: `BRIEF.md` (copied from the test 1 template, scope and limits of this test), `LOG.md` (parent: §0 skill SHAs, the user facts scrubbed, one section per T), `t1-preflight.md` … `t8-delete-mgmt.md` (children), `LEARNINGS.md` (parent, items tagged `[nkp-skill ...]`, `[ntnx-skill ...]`, `[fact]`), `review.md` (T9).
- Scrub: `<bastion>`, `<pc>`, `<net>.N` for the test range, `<registry-host>`, `<ntp>`, no key, token, or password. Cluster names, workspace name, and subnet names may stay.
- `research/raw/live/2.19/nkp-help-ops.txt`: the new help entries (T1).
- After T9: `OPEN-ITEMS.md` updates, the fix plan `research/lab-runs-2026-11-04-test2-fixes.md`, and NEXT-STEPS Carry-over. Not part of this plan's lab use.

## 7. Cleanup and leftover audit (end of T8)

| Check | Tool | Expected |
|---|---|---|
| VMs with prefix `nkp-mgmt-01`, `skilltest-flow-` | ntnx `nutanix-nkp` "Leftover audit" | 0 |
| Volume groups `for <cluster>,` + `K8sClusterID` (all 3 clusters) | ntnx `nutanix-storage` "What an NKP cluster leaves behind" | 0 after D5.2 |
| IP reservations in the node subnet, FIPs, categories of the clusters | ntnx "Leftover audit" | 0 (categories: report, ask before a delete) |
| Shared Services VPC or other Flow objects in PC | ntnx `nutanix-networking` VPC list (RO) | report what Flow CNI made; delete only with a new "yes" |
| VIPs and LB IPs | `ping`, `curl -m 5` from the bastion | no reply, `000` |
| Bastion: kind container, `*-bootstrap.conf`, cluster files | `docker ps -a`, D5.4 list block, `ls -a ~ \| grep -E 'nkp-mgmt-01\|skilltest-flow'` | nothing |
| Site file | D5.5 block | dangling `MGMT_KUBECONFIG` reported, file kept |
| Workspace namespace | `kubectl get ns` (before T8) | `NotFound` (or the P-55 stop result) |

Time estimate: T1 20 min, T2 60–75 min, T3 45–75 min (bundle push + 3+4 nodes), T4 10 min, T5 10 min, T6 30–60 min, T7 30 min, T8 30 min. Total about 4–5 hours.

## 8. Approval and overnight decisions (user, 2026-11-04)

- The user typed "yes" to this plan (v2) and went offline. The parent drives the test to the end.
- Gates: the parent decides the path B CHANGES blocks and the Prism Central deletes, only inside §3 (objects of `nkp-mgmt-01`, `skilltest-flow-a`, `skilltest-flow-b`). Each decision goes into `LOG.md`. No finalizer removal.
- A missing tool on the bastion (for example `yq` v4): copy the official static binary from the laptop to `~/bin` with `scp`. No system package, no sudo. Log it as a skill gap.
- UI delete fails or the UI cannot be reached: record it (P-55 stays open), go on. The management cluster delete in T8 removes the workspace.
- Failures: up to 3 blind children per step. DeepSeek timeouts: retry; after 3 in a row, wait 10 min; at most 3 such groups. Then skip to the cleanup, delete everything, and record the failure. The end state is always clean.

## 9. Role change (user, 2026-11-04, before bed)

DeepSeek acts as the **main agent**, the way the target agent will run at a site. The parent is only the program manager and the observer.

- From T2 on, each DeepSeek session gets a **user-style request**, the way a site operator would ask (for example "Create a management cluster nkp-mgmt-01 with my Ultimate trial license"). The request has no skill names, steps, or commands. The BRIEF stays the lab frame (SSH form, scrub, logs, hard limits).
- DeepSeek follows the skill rules as written, **including rule 2**: at each CHANGES block it shows the plan and stops. No standing approval inside the skill flow. (T1 ran with the old task-style prompt; it is read-only, so its result stays valid.)
- The parent plays the **site user**: it answers questions only with the facts of §2, types "yes" only when the plan is inside §3 and §8, and says "no, <reason>" otherwise. It gives no hints, no commands, no corrections. If DeepSeek asks for something that only a real user knows and §2 does not have, the parent answers "I do not know" and logs it.
- Sessions are persistent (`subagent_send` for each user reply), one session per phase (T2, T3+T4, T5, T6, T7, T8), so each session is one "conversation" of a site user.
- The parent writes nothing on the lab. It records observations only, in `research/raw/lab-runs/2026-11-04-test2/OBSERVATIONS.md`: each turn (request, what DeepSeek did, the gate answer), each place where DeepSeek went off the skills, broke a rule, asked a needed or needless question, or got stuck. Tags: `[skill]`, `[rule N]`, `[model]`, `[process]`. This is the input for the retro in the next session.
- Still the parent's job: the safety audit of each block (§3), the failure policy (§8), the clean end state, and the T9 review.
