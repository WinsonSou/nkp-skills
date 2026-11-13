# Lab test 1 — retro and fix plan

Status: plan approved by the user 2026-11-04. Next: Part B (F0 first).

Source: `LEARNINGS.md` (numbers `L<n>`, not in numeric order in the file) and the executor logs `research/raw/lab-runs/2026-11-03-test1/t<k>-*.md` (`t<k>-<item>`). Evidence quotes are scrubbed.
Priority: **P1** security/blocker · **P2** wrong fact · **P3** missing step · **P4** polish.

## Part A — merged learnings, by target file

### A1. `nkp-install/SKILL.md`

| # | Section | Evidence | Fix | Pri | Refs |
|---|---|---|---|---|---|
| I1 | Step 1 (questions) | `License key is not valid for this cluster` on `skilltest-mgmt-01`; cluster rebuilt as `nkp-mgmt-01` | Pro/Ultimate: ask for the licensed cluster name before the create; the name must match the license | P1 | L31 |
| I2 | Step 1 | Kommander installs as Starter; license applied after the create | Tier answer feeds the N1 size flags; pointer to identity "License" after Verify | P3 | L14 |
| I3 | Set the kubeconfig variables | `kubeconfig was written to ... ~/<cluster>.conf` (600), ~17 min before the end | Close A-05: `$PWD/<cluster>.conf` `[live 2.19.0]`; `ls` only as a confirmation | P2 | L26, t3-8 |
| I4 | Set the kubeconfig variables | workload create ends at `✓ Waiting for machines to be ready`, no `.conf` | Workload: `nkp get kubeconfig` is mandatory, no success line is normal | P2 | L50, t4-3, t5-8 |
| I5 | Set the kubeconfig variables | old `MGMT_KUBECONFIG` line pointed to a deleted file | Done-when adds `test -f "$MGMT_KUBECONFIG"` | P3 | t3-9 |
| I6 | Set the kubeconfig variables | extra approval round between create and verify | (decision Q8) append the kubeconfig line as part of the approved create plan | P4 | L27 |
| I7 | Verify | wl-01: `Reconciled` after up to 38 min; `-n kommander wait helmreleases` reads the mgmt cluster | Workload branch: `wait helmreleases -A --all` on `CLUSTER_KUBECONFIG`, `get kommanderclusters -n "$WORKSPACE_NS"` on mgmt; 30–40 min is normal | P2 | L51, t4-4 |
| I8 | Verify | `No resources found` goes to stderr | "Expect no output" | P4 | t3-12 |
| I9 | Verify | mgmt Ultimate 48 HR; workload 19 HR / 16 AppDeployments / 122 pods; 2 arrive late | Expected counts; never treat the first count as final | P4 | L54, t4-12 |
| I10 | Create the cluster | create 22–24 min; SSH drop kills the bootstrap | Run the create in `tmux` on the operator host | P3 | L10 |
| I11 | Check the operator host | agent on a laptop, blocks over `ssh 'bash -s'` | (decision Q4) remote operator host | P3 | L12 |
| I12 | Check the operator host | 2 FIPs + 3 VGs of the old cluster still in PC | Before a fresh create: leftover check (VG description, FIPs) via ntnx recipes | P3 | L5 |

### A2. `nkp-install/references/nutanix.md`

| # | Section | Evidence | Fix | Pri | Refs |
|---|---|---|---|---|---|
| N1 | Node OS image + N7 row | Starter + Ubuntu 24.04: create OK, `tier=Starter valid=true` | (decision Q1) "not supported", not "fails" | P2 | L4, L29 |
| N2 | N1 IP plan | basic VLAN has no `learnedIpAddresses`; ARP used | Point to the ntnx free-IP recipe | P3 | L1, L6 |
| N3 | N1 IP plan | wl-01: user Service took `.61`, traefik `.62` | "UI gets the first **free** IP"; pin it with MetalLB annotation (nkp-networking) | P2 | L53, t4-6 |
| N4 | N1 IP plan | node IPs `.60 .61 .70 .78 .160` | Do not assume sequential node IPs | P4 | t5-14 |
| N5 | N1 NTP | PE, PC, bastion use 3 NTP servers | Source: PE `network.ntpServerIpList` | P4 | L9 |
| N6 | N1 / N7 PC cert | default PC cert, no SAN; `--insecure` worked, mirror CA unaffected | When `--insecure` vs `PC_CA_FILE` | P3 | L8, t3-14 |
| N7 | N3 checks | wrong password fails only at preflight | READ-ONLY credential checks (PC v4 `200`, mirror `/v2/` with CA) with `--netrc-file <(...)` | P3 | L16 |
| N8 | N3 checks | `curl $PC_ENDPOINT` → `302` | "302 is normal" | P4 | L17 |
| N9 | N3 checks | only `CP_VIP` pinged | Ping each `LB_IP_RANGE` IP | P3 | L18 |
| N10 | N3 checks | no mirror test | `curl .../v2/` (401 = answers) | P3 | L7, t3-13 |
| N11 | N4 | `--timeout` default `30m0s`; create 22–24 min | Mgmt: add `--timeout 60m`; workload: default OK (3–13 min) | P3 | L19, L25, t3-11, t4-3 |
| N12 | N4D | dry run with `--self-managed` makes kind, CAPI, preflight, ~3 min | Reword: it is the preflight test; needs 4 CPU/4 GB; `nkp delete bootstrap` if cut off | P2 | L20, t3-10 |
| N13 | N4D | workload dry run < 20 s, 5 Secrets, no kind | Workload branch of N4D | P2 | t4-7, t5-7 |
| N14 | N4D grep | sizes not shown | Add `replicas:\|vcpuSockets\|memorySize\|systemDiskSize\|servers:\|insecure` (anchored `:`) | P4 | L21 |
| N15 | N4D | autoscaler min=max=`--worker-replicas` | One fact line | P4 | L22 |
| N16 | N4D P-07 check | `grep -c additionalTrustBundle` = 1 with empty value | Check the value length; close P-07 only with a real CA file | P2 | L23 |
| N17 | N5 | workspace assumed to exist | Pointer to identity rbac R5; read `WORKSPACE_NS` back | P3 | L48, t4-1 |

### A3. `nkp-identity-security/SKILL.md` "License" + `references/rbac.md` R5

| # | Section | Evidence | Fix | Pri | Refs |
|---|---|---|---|---|---|
| S1 | License (dry run + patch) | `Invalid value: "<full key>"` in the webhook error | Pipe both through the `sed` mask; never paste the raw error | **P1** | L30, t3-5 |
| S2 | License symptoms | `License key is not valid for this cluster` | Symptom row: key bound to the cluster name | P2 | L31 |
| S3 | License | `nutanix-license-secret` stays with a bad key | After a denial: delete the Secret (or validate first) | P3 | L32 |
| S4 | License UNKNOWN P-40 | trial: only `dkpLevel`, `endDate` | Close P-40 (trial); paid key may differ | P2 | L33, L45, t3-1, t3-2 |
| S5 | License Done-when | tier in 15 s, apps 11 min, 4 HR late | `get helmreleases -A` until no non-Ready twice, ≥ 15 min apart; Starter 24 → Ultimate 48 | P3 | L46, t3-3 |
| S6 | License pre-check | CPU requests 67–98 % on 4 × 8 vCPU | `describe nodes \| grep -A6 'Allocated resources'`; 4 × 8 vCPU is near the limit | P3 | L47, t3-4 |
| S7 | License | no tier app list | Ultimate app table; Rook Ceph is on AHV too (do not delete) | P4 | t3-6 |
| S8 | Step 1 | `endDate` not read | jsonpath adds `end={.status.endDate}` | P4 | t3-7 |
| S9 | rbac R5 | `skilltest-ws` → ns `skilltest-ws-7kr7h` | Suffix fact; read `WORKSPACE_NS` from `get workspaces` | P2 | L49, t4-2 |
| S10 | rbac R5 | `--dry-run -o yaml` exists | Show the plan as YAML | P4 | t4-14 |
| S11 | rbac R5 delete | `kubectl delete workspace` → ns `Terminating` on 33 finalizers; UI path pdf p.318-319 | (decision Q2) | P3 | L74, t6-1, t6-7 |

### A4. `nkp-cluster-lifecycle/references/delete.md`

| # | Section | Evidence | Fix | Pri | Refs |
|---|---|---|---|---|---|
| D1 | D2 gate | `no resource type "nkpclusters"` on a workload cluster | "This error = not a mgmt cluster; continue" (or run on mgmt) | P2 | L68, t7-3 |
| D2 | D3 output | 3 lines, not 5 | Fix the expected output; LB/CRS lines are optional | P2 | L67, t6-2, t7-1 |
| D3 | D3 | NKPCluster `NotFound` 82 s after RC=0 | Check first; Error/finalizer path only if it stays | P2 | L66, t6-3, t7-2 |
| D4 | D3 | 28–57 s | Duration; poll every 30 s | P4 | L73, t6-2, t7-11 |
| D5 | D3 Done-when | VIP/LB stop answering | `ping` VIP + `curl` LB IP must fail | P3 | L76, t6-9 |
| D6 | D4 | no expected output, 5–7 min, phases | Output lines + "5–10 min, most at the end" | P3 | L40, t2-1, t2-2, t8-4 |
| D7 | D4 | stopped container hides | `docker ps -a`; `<cluster>-bootstrap.conf` goes away; no NKPCluster stays | P2 | L41, t2-3, t2-4, t8-5 |
| D8 | D4 | 20/20 VG attachments cleared by PC | Delete the cluster first, then the VGs | P3 | t8-3 |
| D9 | D5 P-11 | 3 VGs (Starter mgmt), 20 VGs/340 Gi (Ultimate), 4 (wl with PVCs), 0 (no PVC) | Close P-11: PVC VGs stay; agent cleanup via the ntnx VG recipe (Q5); conditional on PVCs | P2 | L39, L43, L71, L72, t2-5, t6-4, t7-12, t8-2 |
| D10 | D5 P-11 block | `CLAIM:.../...` prints `<none>` | `NS:...,PVC:...,HANDLE:...` columns + `get pvc -A` | P2 | t8-1 |
| D11 | D5 Secrets | `<cluster>-oci-cert`, `<cluster>-oci-creds` stay (mirror creds) | List + delete step in the **workload's** workspace ns | P3 | L69, t6-5, t7-5, t8-6, t8-11 |
| D12 | D5 files | `-dryrun.err`, create/delete/verify logs, `-delete.sh`, manifests missed; `$PWD` | Add names; `ls ~ \| grep -F -- "$CLUSTER_NAME"`; "run from the create folder" | P3 | L42, L75, t2-7, t2-8, t6-8, t7-4, t8-7 |
| D13 | D5 rm chain | `... && rm -f -- "$HOME/nkp-$CLUSTER_NAME.env"` | Use `;` for the env-file step | P2 | t2-9 |
| D14 | D5 site file | dangling `MGMT_KUBECONFIG` → `context deadline exceeded` | Symptom + `grep -n MGMT_KUBECONFIG` check + fix after next create | P3 | L42, t2-10, t8-8 |
| D15 | D5 VPC | FIPs answer `000` until step 7 | One sentence | P4 | t7-9 |

### A5. `nkp-vpc/SKILL.md`

| # | Section | Evidence | Fix | Pri | Refs |
|---|---|---|---|---|---|
| V1 | Facts + Step 1 layout | `--cluster-hostname` in 0 objects on workload | Workload row: 1 FIP (API); `FIP_UI`/`UI_HOSTNAME` mgmt only | P2 | L61, t5-1, t5-2, t5-14 |
| V2 | Facts | N-41 yes; API cert has the FIP, not the VIP | Close N-41 | P2 | L60, t5-11 |
| V3 | Facts | `/_oauth_kommander` 307 to private LB IP | Reason to set the UI hostname for outside users | P4 | L61, t5-13 |
| V4 | Step 2 | written as PC UI actions | Agent path: ntnx-networking recipes; FIP status `ASSOCIATED_TO_PRIVATE_IP` | P3 | L65, t5-9 |
| V5 | Step 2 item 4 | 48 dummy FIPs, gateway `externalIps` | FIP address choice rule; record address + extId | P3 | t5-10 |
| V6 | Step 3 | stops when Harbor runs although MTUs match | Stop only when MTUs differ; 1442 only inside the VPC; workload = no kind | P2 | L63, t5-6, t5-7 |
| V7 | Step 4 | workload dry run has no ingress | Say so | P4 | t5-5 |
| V8 | Step 5 | `namespaces "kommander" not found` on workload | `-n "$WORKSPACE_NS"`; split Done-when mgmt/workload | P2 | L62, t5-3, t5-4 |
| V9 | Step 7 | no API path; extIds not recorded; subnet/VPC are site objects | Point to ntnx FIP disassociate+delete; record extIds; ask before a site-object delete; VG part only with PVCs | P2 | L70, t7-6, t7-7, t7-8, t7-12 |
| V10 | Facts N-01 | DSR geneve; FIP → LB works | Update N-01 note | P4 | L64, t5-13 |

### A6. Other NKP skills

| # | Target | Evidence | Fix | Pri | Refs |
|---|---|---|---|---|---|
| K1 | `kubernetes-core` Step 4 | `namespaces "skilltest-app" not found` in dry run/diff; `diff \| head` → rc 0 | Namespace first; read `diff` `$?` without a pipe | P2 | L55, t4-8 |
| K2 | `nkp-storage-backup` `csi.md` + Step 1 | `CLAIM:.spec.claimRef.namespace/...` → `<none>` | Two columns | P2 | L56, t4-9 |
| K3 | `nkp-storage-backup` (new section) + link from `nkp-networking` | PVC Bound, LB `.61`, HTTP 200 | Day-1 smoke test (PVC + pod + LB + curl), images from the bundle | P3 | L56, t4-10 |
| K4 | `nkp-airgap` | `library/nginx` 404; `nginxinc/nginx-unprivileged` exists | List mirror content: `GET /v2/<project>/<repo>/tags/list` | P3 | L57, t4-11 |

### A7. `../ntnx-skills`

| # | Target | Evidence | Fix | Pri | Refs |
|---|---|---|---|---|---|
| X1 | (Q5) VG skill/recipe + `nutanix-api` version map | `/volumes/v4.0/config/volume-groups` works; `vm-attachments` `data: null`; `external-attachments` 404; ETag `NA==`; `attachments[].attachment.extId`; description `... for <cluster>, PVC:..., NS:...`; PC groups `isHidden: true, INTERNAL` | List / attachments / delete recipe; match `for <cluster>,`; require `K8sClusterID`; never touch INTERNAL | P3 | L36, t1-2..6, t6-6, t8-9, t8-10 |
| X2 | `nutanix-api` REFERENCE Lists | `req(...)[2]['data']` → `None` | Empty sub-list = `data: null` | P4 | t1-5 |
| X3 | `nutanix-api` (projects) | `/multidomain/v4.0/config/projects` non-JSON | Live probe, then recipe or error row | P3 | L3 |
| X4 | `nutanix-networking` FIP | 50 × `fip-dummy-name` → `by_name` raises | Select by address; gotcha row | P3 | L35, t1-1, t1-8 |
| X5 | `nutanix-networking` FIP | disassociate only in a code comment | Gotcha row + prose; create + `PrivateIpAssociation` in one POST verified | P3 | L37, t1-7, t7-10, t5-10 |
| X6 | `nutanix-networking` (new recipe) | ARP: `ping` + `ip neigh` → `FAILED` | Free-IP check: pool + VM NICs + PE/PC/CVM/host IPs (`clustermgmt`) + ARP probe on the same L2 | P3 | L1, L2 |

### A8. Process: `AGENTS.md`, `_shared/RULES.md`, ADR 0003, NEXT-STEPS §3

| # | Target | Evidence | Fix | Pri | Refs |
|---|---|---|---|---|---|
| R1 | RULES rule 2 | user typed "proceed", agent asked again | (decision Q3) | P4 | L24 |
| R2 | RULES rule 3 / ADR 0003 | laptop agent, bastion operator host | (decision Q4) | P3 | L12 |
| R3 | AGENTS.md model routing | DeepSeek "Request timed out" 3× after ~57 s | (decision Q6) executor fallback | P3 | L34 |
| R4 | AGENTS.md | `sleep 240; ssh` hung 27–30 min | (decision Q7) child rules: `sleep` ≤ 120 s alone, `timeout` + `ServerAliveInterval=15 -o ServerAliveCountMax=4`; interrupt → cancel → resume | P3 | L58, t4-13, t5-15 |
| R5 | NEXT-STEPS §3 safety limits | mgmt cluster gone; test made a mgmt cluster | From-scratch variant of the limits | P4 | L13 |
| R6 | NEXT-STEPS Carry-over | facts only | Record: create/delete timings, parallel deletes OK, old `cluster.yaml` cross-check | P4 | L11, L25, L44, L59, L77 |

No action (fact logged, skill already right): L15 (user decision), L28 (USER-TERMINAL kept), L38 (old leftovers removed).

## Open items

- Answered: A-05 (I3), P-11 (D9), P-40 trial part (S4), N-41 (V2), N-01 partly (V10).
- Still open: P-07 (N16), N-43 (t5-12: FIP associated after the create not run), A-06 (mgmt used a site mirror).

## Decisions (retro, 2026-11-04)

| Q | Decision |
|---|---|
| Q1 Starter + Ubuntu (L4, L29) | Drop the "Starter: Rocky only" rule and its N7 row. The site always gets a license (skill or UI). |
| Q2 Workspace delete (L74) | R5: the UI delete path [pdf p.318-319] + a READ-ONLY check of `Terminating` objects + UNKNOWN (P-55, added by the parent). No finalizer removal in a skill. Retest in lab test 2. |
| Q3 Rule 2 (L24) | Keep the strict "yes". Add: "If the user answers with another word, ask them to type yes." |
| Q4 Remote operator host (L12, L13) | The target agent runs on the operator host. Bastion-over-ssh is the lab setup only: AGENTS.md "Live lab", not rule 3 or ADR 0003. |
| Q5 VG recipe (L36) | Already in `../ntnx-skills` `nutanix-storage` (HANDOFF.md §2). No ntnx change. |
| Q6 Executor fallback (L34) | None. Retry DeepSeek; stop and tell the user after 3 failures (AGENTS.md process lesson). |
| Q7 Child timeouts (L58) | AGENTS.md "Live lab" + the lab BRIEF template. |
| Q8 Kubeconfig line (L27) | The create script appends `MGMT_KUBECONFIG`/`CLUSTER_KUBECONFIG` after RC=0 + `test -f`; part of the create plan (one approval). |
| Q9 Repos | Two repos. ADR 0004: `ntnx-skills` is a companion set. Pointers name the skill + RECIPES anchor (HANDOFF.md §4) and a fallback "not installed: the user does it in Prism Central". |
| Q10 Evals | The eval model gets both skill sets. |

## Part B — fix tasks

Base: a parent commit with F0. Each author: `claude-code/claude-opus-5-5`, thinking high, own worktree, own files only, commit after each file. Authors do not edit `research/OPEN-ITEMS.md` or `LEARNINGS.md`: they report new open items (with IDs from their range) and the parent adds them. Authors read `GLOSSARY.md`, `docs/adr/`, `docs/AUTHORING.md`, the item rows in Part A, the evidence files, and `../ntnx-skills/HANDOFF.md` §4 for the anchors. No lab access.

| Task | Owner | Files | Items | New-ID range | Parallel |
|---|---|---|---|---|---|
| F0 | parent | `docs/adr/0004-*` (new), `scripts/check_skills.py` (accept `nutanix-api` `nutanix-cluster` `nutanix-iam` `nutanix-networking` `nutanix-nkp` `nutanix-prism` `nutanix-storage` `nutanix-vm` `nutanix-volumes`; check them against `../ntnx-skills/skills` when it exists; self-test), `skills/nkp/SKILL.md` (companion line), `skills/_shared/RULES.md` (Q3) + `--sync`, `AGENTS.md` (Q4, Q6, Q7), `research/raw/lab-runs/2026-11-03-test1/BRIEF.md` → lab brief template note, `research/OPEN-ITEMS.md` | R1–R5 | — | first, committed before F1–F7 |
| F1 | Opus author | `skills/nkp-install/SKILL.md`, `references/nutanix.md`, `evals/nkp-install.md` | I1–I12, N1–N17 | P-50..P-54 | yes |
| F2 | Opus author | `skills/nkp-identity-security/SKILL.md`, `references/rbac.md`, `evals/nkp-identity-security.md` | S1–S11 (S11 uses P-55) | P-56..P-59 | yes |
| F3 | Opus author | `skills/nkp-cluster-lifecycle/references/delete.md` (+ SKILL.md only for a pointer), `evals/nkp-cluster-lifecycle.md` | D1–D15 | P-60..P-64 | yes |
| F4 | Opus author | `skills/nkp-vpc/SKILL.md`, `references/layouts.md`, `evals/nkp-vpc.md` | V1–V10 | N-50..N-54 | yes |
| F5 | Opus author | `skills/nkp-storage-backup/SKILL.md`, `references/csi.md`, `evals/nkp-storage-backup.md`; one pointer line in `skills/nkp-networking/references/metallb.md` | K2, K3 | D-60..D-64 | yes |
| F6 | Opus author | `skills/nkp-airgap/SKILL.md` (or a reference file), `evals/nkp-airgap.md` | K4 | A-30..A-34 | yes |
| F7 | Opus author | `skills/kubernetes-core/SKILL.md`, `evals/kubernetes-core.md` | K1 | Q-20..Q-24 | yes |
| F8 | — | `../ntnx-skills` | X1–X6 | — | no change (done in HANDOFF.md); authors list any gap they find, the parent decides |

Cross-file facts the authors must use the same way (parent gives this list to all):
- The VG cleanup pointer: skill `nutanix-storage`, RECIPES.md "What an NKP cluster leaves behind" + "Delete a volume group". Leftover audit: skill `nutanix-nkp` "Leftover audit for a cluster". Free IP: skill `nutanix-networking` "Free IP check for a VIP or an LB range". FIP delete: `nutanix-networking` "Floating IPs" → "Delete a floating IP".
- Workload vs management: workload create = no kind cluster, no kubeconfig file, no success line, 3–13 min; dry run < 20 s, 5 Secrets. Management create = kind + CAPI + preflight in the dry run (~3 min), 22–24 min, `$PWD/<cluster>.conf`.
- Workload platform apps are in `$WORKSPACE_NS` on the workload cluster, never `kommander`.

Merge order: F0 → F1..F7 (any order; each merge then `python3 scripts/check_skills.py --sync` and `python3 scripts/check_skills.py`). After each merge, the parent removes the resolved items from `LEARNINGS.md` (the `t*-*.md` logs stay as evidence).

## Part C — evals (step 4)

Each author adds or refreshes prompts in its `evals/<skill>.md`. Required prompts:

| Eval | Skill | Checks |
|---|---|---|
| license name + key mask | identity (F2) + install I1 | asks for the licensed cluster name before the create; both License blocks pipe through the `sed` mask; deletes the Secret after a denial |
| workload verify branch | install (F1) | `wait helmreleases -A --all` on `CLUSTER_KUBECONFIG`; `kommanderclusters -n "$WORKSPACE_NS"`; `nkp get kubeconfig` mandatory; 30–40 min is normal |
| delete leftovers | lifecycle (F3) | D5 file list incl. `-dryrun.err` and logs; `-oci-cert`/`-oci-creds` in the workload's workspace ns; dangling `MGMT_KUBECONFIG` |
| VG cleanup | lifecycle (F3) → `nutanix-storage` | cluster first, then VGs; filter `for <cluster>,` + `K8sClusterID` + empty `vm-attachments`; plan + "yes" before the delete; only when PVCs existed |
| free-IP check | install N1/N3 (F1) → `nutanix-networking` | runs the recipe on the operator host (ARP on the same L2); pings each LB IP |
| VPC workload layout | vpc (F4) | 1 FIP; no `--cluster-hostname`; Step 5 with `$WORKSPACE_NS` |

Run: DeepSeek-V4.1-Flash (`wskn-flare/DeepSeek-V4.1-Flash`), thinking low, both skill sets, no web, no lab. Prompts without the expected answers. Grade in the parent. Results: `evals/runs/2026-11-04-labtest1/`.

## Part D — review, close (steps 5–6)

- Opus (high) review of the full diff since the F0 base, fresh standalone session → `evals/runs/2026-11-04-labtest1/review.md`. Fix pass, commit.
- NEXT-STEPS Carry-over: state, new facts, process lessons (R6). Then the tag question.

## Lab use

None in this plan. No ntnx recipe changes, so no `skilltest-*` PC objects.
