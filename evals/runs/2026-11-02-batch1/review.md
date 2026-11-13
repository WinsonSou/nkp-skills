# Batch 1 review: nkp-airgap, nkp-cluster-lifecycle, nkp-install (metal, preprovisioned, cloud)

Reviewer: Opus, fresh read-only session, 2026-11-02. Scope: commits a1d2ce7..HEAD (b78b8a6). I changed no files in the repo except this file. Scratch files are in `/tmp/rvb1`.

What I did:
- `python3 scripts/check_skills.py --self-test && python3 scripts/check_skills.py`: both pass (`4 skills checked, 0 errors`).
- `bash -n` on all 97 bash blocks in scope: no syntax errors.
- Every cloud flag: I opened the PDF page text for each `[pdf p.N]` tag (helper `/tmp/rvb1/pg.sh N`) and looked for the flag with the same spelling. Section 4 has the list.
- Every metal, preprovisioned, lifecycle, and airgap flag: compared with `research/raw/live/2.19/nkp-help*.txt`.
- I checked the asset SHA-256 headers (all 5 `OK`), the scrub (no IP, host name, lab name, or secret), the budgets, the UNKNOWN IDs, and the evals.

**Verdict: go-with-changes.** 0 BLOCKER, 8 MAJOR, 16 MINOR. The cloud flags are good: almost all flags are on the tagged page with the same spelling. 4 kinds of flags are not confirmed (section 4). The C1 `--help` gate catches them.

## 1. BLOCKER

None.

## 2. MAJOR

**M1. `kubectl logs -A` does not exist. The M1 "Done when" check can never pass.**
- File: `skills/nkp-cluster-lifecycle/references/maintenance.md:52`.
- Evidence: `kubectl logs -A -l x=y` gives `error: unknown shorthand flag: 'A' in -A` (kubectl v1.37.0). `kubectl logs --help` has no `--all-namespaces`.
- Live: the autoscaler Deployment is in the cluster namespace on the management cluster (`live-lifecycle.txt:316-318`, namespace `kommander` for the management cluster).
- Fix: use the cluster env file and the namespace:
  ```bash
  # READ-ONLY
  source ~/nkp-<cluster>.env 2>/dev/null
  kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" logs -l app.kubernetes.io/name=clusterapi-cluster-autoscaler --tail 50
  ```
  Remove the line ":55 If this prints 'No resources found' ...", or keep it as a fallback with `-n kube-system` on `"$CLUSTER_KUBECONFIG"`. Also scope the `get deploy -A` lines at :21-22 to `-n "$WORKSPACE_NS"`. With many clusters, `-A` lists every autoscaler, and the model cannot tell which one belongs to this cluster.

**M2. The `MGMT` column reads a label that the live evidence does not show on the NKPCluster metadata.**
- Files: `skills/nkp-cluster-lifecycle/SKILL.md:60,63`, `references/delete.md:12,16`.
- Evidence: the only live hit for `kommander.d2iq.io/host` is `nkpcluster.txt:275-277`. It is under `spec.kommanderCluster.labels`, not `.metadata.labels`. The NKPCluster metadata labels were not collected.
- Effect: the column can print `<none>` for the management cluster. Then delete.md D1 sends the management cluster to the workload path (D2/D3, without `--self-managed`). The D2 check (`get nkpclusters -A` on the cluster lists itself) stops it, but only by chance. The skill says "this cluster manages other clusters", which is the wrong reason.
- Fix: use `MGMT:.spec.kommanderCluster.labels.kommander\.d2iq\.io/host`, which has live evidence. Or do a `lab-ro` check of `.metadata.labels` and record it in `live-lifecycle.txt`. Also add a second test to D1: "namespace `kommander` = the management cluster" `[live 2.19.0]` (`nkpcluster.txt:1-3`).

**M3. The D5 file delete can delete the files of another cluster.**
- File: `skills/nkp-cluster-lifecycle/references/delete.md:122,130`.
- Evidence: I tested `"$HOME/nkp-$CLUSTER_NAME-"*` with `CLUSTER_NAME=dev`. It matches `nkp-dev-01-create.sh` **and `nkp-dev-01.env`**, the cluster env file of a different cluster (`/tmp` test, section 3).
- The approval gate shows the `ls` list first, but a small model will not see the extra names.
- D5 also does not list the files in `$PWD`: `$CLUSTER_NAME-dryrun.yaml` (holds Secrets), `$CLUSTER_NAME-metallb-conf.yaml`.
- Fix: list the exact names. Never use a glob after the cluster name:
  ```bash
  # READ-ONLY
  source ~/nkp-<cluster>.env 2>/dev/null
  for f in "$HOME/nkp-$CLUSTER_NAME.env" "$HOME/nkp-$CLUSTER_NAME-create.sh" "$HOME/nkp-$CLUSTER_NAME-patch.json" "$HOME/nkp-$CLUSTER_NAME-nodepool.sh" "$HOME/nkp-$CLUSTER_NAME-nodepool-dryrun.yaml" "$HOME/nkp-$CLUSTER_NAME-inventory.yaml" "$PWD/$CLUSTER_NAME-dryrun.yaml" "$PWD/$CLUSTER_NAME-metallb-conf.yaml" "$CLUSTER_KUBECONFIG"; do [ -e "$f" ] && ls -l "$f"; done
  ```
  The `rm` block uses the same list.

**M4. `nkp upload image-artifacts` has no `--ssh-username`.**
- File: `skills/nkp-install/references/preprovisioned.md:100-104`.
- Evidence: in live `nkp-help-airgap.txt:79`, `--ssh-username` is "The username to connect to the remote host" and has no default. The guide passes `--ssh-username ${SSH_USER}` (pdf p.802).
- Effect: without it, the CLI connects as the local user, or with no user. On the dark-site path, the upload fails.
- Fix: add `--ssh-username "$SSH_USER" \` to the P3 block. Add it to eval E13 Expected.

**M5. The P5 create script uses `--ssh-username "$SSH_USER"`, but the note under it says that this flag is a different user.**
- File: `preprovisioned.md:146` against `:158`.
- Evidence: in live `nkp-help-cluster.txt:193`, `--ssh-username` is "Name of the user to create on the instance (default 'konvoy')". The guide's create command on p.82 does not pass it. The eval run found the same defect (`grading.md`, E13).
- Effect: NKP tries to create the SSH login user (for example `root` or `nkpadmin`) as the node user.
- Fix: remove line 146. The note at :158 can stay.

**M6. The C9 grep can print secret values.**
- File: `skills/nkp-install/references/cloud.md:273`.
- Problem: the patterns `image`, `ami`, `region`, `instanceType`, `vmSize` are not anchored and have no `:`. The dry-run file holds Secrets (C9 says so), for example the GCP Base64 credentials and the CA data.
- A Base64 value can contain the text `ami` (base64 uses the lower-case letters). Then `grep -n` prints the full Secret line.
- The other provider files are safe, because every pattern ends in `:`, and Base64 has no `:`.
- Fix: `grep -n -E '^kind:|^  name:|^  namespace:|^\s+(image|ami|amiID|id|region|instanceType|vmSize|url):' ...`. Never use a pattern without a `:` on a file that holds Secrets. Add this to the authoring notes in `RULES.md`.

**M7. The IMAGE_BUNDLES duplicate (confirmed). The two copies are already different.**
- Files: `skills/nkp-install/references/nutanix.md:186-189` and `skills/nkp-airgap/SKILL.md:156-160`.
- ADR 0001 makes nkp-airgap the owner of "Bundle, registry, and seeding".
- The airgap copy is better: it checks each file with `test -f`. The nutanix.md copy appends even when `ls` fails, and then writes `IMAGE_BUNDLES=',,'`. It also appends two paths on one line when the folder has two bundle versions.
- Fix: in `nutanix.md` step 2, replace the block with one line: "Set `IMAGE_BUNDLES` with skill `nkp-airgap`, step 4 (the first block). Done when: `printenv IMAGE_BUNDLES | tr ',' '\n'` shows three paths."
- Keep `IMAGE_BUNDLES` in the rules table, because nkp-install, nkp-airgap, and nkp-upgrade use it.

**M8. Evals E12 and E13 use the old open-item IDs.**
- File: `evals/nkp-install.md:166` ("May quote UNKNOWN (P-08)") and `:181` ("without the P-09 check").
- The renumber in 3f0cfa2 changed these items: the Metal CSI item is now **P-13**, and the pre-provisioned namespace item is now **P-14**. P-08 and P-09 now mean lifecycle facts (scale annotations, rollout trigger).
- Effect: a grader who reads the eval literally fails a correct answer and passes a wrong ID. The grader did correct this by hand ("P-13 (renumbered from P-08)").
- Fix: E12 → `P-13`, E13 → `P-14`. Add a check: the script fails when an eval names an ID whose owner skill in OPEN-ITEMS is a different skill (or at least when the ID is not in OPEN-ITEMS).

## 3. MINOR

1. **Wrong tag pages (cloud.md):**
   - AKS license `[pdf p.28]` (:20). The "LCM of AKS Cluster" row is on **p.27**.
   - Azure VM `Standard_D4s_v3` `[pdf p.197, p.697]` (:170). The text is on **p.194 and p.872**. p.697 is the Nutanix chapter.
   - GCP `--network` `[pdf p.219]` (:222). The text is on **p.218** (and p.922).
   - vSphere "vSphere 7.0.3 or later" (:230). p.835 says "**vSphere Client** version 7.0.3 or later".
2. **The bootstrap token has a different mark in two skills.**
   - `nkp-cluster-lifecycle/references/metal.md:12` calls `nkp create bootstrap-token` "a USER-TERMINAL command".
   - `nkp-install/references/metal.md:75-79` runs it as CHANGES with the output sent to a mode 600 file. That is correct, because the token is never on the screen.
   - It is also a duplicate fact (ADR 0001). Fix: in lifecycle MT1, write only "For the token, use skill `nkp-install`, section M3."
3. **Old statement.** `nkp-airgap/references/os-images.md:103` says "The pre-provisioned install steps are not written yet (skill `nkp-install`)". `preprovisioned.md` now exists. Point to its P3.
4. **Commands in prose, with no block, no mark, and no `source` line:**
   - `nkp-cluster-lifecycle/SKILL.md:74` (a CHANGES `test -e … || …`).
   - lifecycle `metal.md:64,66-67` (drain, get, and uncordon use `"$node"`, which is never set in a block).
   - `cloud.md:258` (`get ipaddresspools`).
   - Fix: move each one into a marked block. The small model copies prose commands as they are.
5. **A placeholder that is not allowed.** `prestage.md:43-47` uses `SKILL_DIR`. ADR 0003 allows only `<cluster>` in a block. The eval answer (A4) left it as a literal.
   - Fix: let the block find the path. The agent knows where it loaded the skill, so tell it: "Replace `SKILL_DIR` with the folder of this file's `SKILL.md`". Or allow a second placeholder in ADR 0003 and make the check script accept it.
6. **The first SSH connection fails in BatchMode.** `preprovisioned.md:74`: `ssh -o BatchMode=yes` fails with "Host key verification failed" on a host that is not in `known_hosts`. The skill gives no cause.
   - Fix: add a line: "If it prints `Host key verification failed`, ask the user to accept the host keys (`ssh-keyscan` adds them to `known_hosts`, CHANGES)."
7. **The ISO checksum format is not confirmed.** `nkp-airgap/SKILL.md:102,134`: the Done-when needs `sha256sum -c` to print `OK`. The live evidence shows only that the `.sha256` file exists (4.0K). Its content (a hash only, or a hash and a file name) is not recorded.
   - Fix: record its content in the next `lab-ro` pass (`cat` is safe, because it is not a secret). Until then, give a fallback: compare `sha256sum <iso>` with the file.
8. **The on-node block in `nodes.md:20-26` has the mark READ-ONLY, but the agent cannot run it.** The user runs it over SSH. The mark says nothing about where to run it. The model can run `sudo cat` on the operator host.
   - Fix: `# USER-TERMINAL  (on a node; the user runs it over SSH)`, the same pattern as the connected-host blocks.
9. **Rule 1 does not cover the connected-host use of USER-TERMINAL.** GLOSSARY adds "Connected host … marked `# USER-TERMINAL (connected host …)`". But rule 1 and ADR 0003 define USER-TERMINAL only as "shows a secret on the screen".
   - Fix: change rule 1 to "USER-TERMINAL: it shows a secret on the screen, or it runs on another host. Give it to the user …". Add one line to ADR 0003. Then sync.
10. **More evidence for A-05.** The guide runs `nkp get kubeconfig -c ${CLUSTER_NAME} > ${CLUSTER_NAME}.conf` directly after a `--self-managed` create on vSphere (pdf p.842 step 5) and on pre-provisioned hosts (pdf p.82).
    - Add this to A-05 in OPEN-ITEMS.
    - In nkp-install SKILL.md:148 ("If the file is not there, stop"), give this command as the documented fallback for those providers. Do not only stop.
11. **The cluster name in a heredoc.** `nkp-cluster-lifecycle/SKILL.md:211` writes `'$pool'` into a single-quoted heredoc string. A pool name is limited to `[a-z0-9.-]` (live help), so this is safe. Add the rule "pool: a-z, 0-9, `.`, `-`, max 63" next to the block, so that the model does not add a quote.
12. **The vSphere "Common failures" row "template does not match the Kubernetes version" is `[field]`.** p.835-841 say that the template must match. Find the page, or keep `[field]`. This is low priority.
13. **Inventory namespace `[pdf p.90][field]`** (`preprovisioned.md:125`). p.768-769 put the inventory and the Secret in the same namespace as the cluster (`default`). Use `[pdf p.768-769]` and remove `[field]`.
14. **ASD-STE100.** Generally good. Some long sentences:
    - lifecycle SKILL.md:40 ("The CLI default namespaces are wrong for most clusters." is good. The sentence before it has 3 clauses.)
    - cloud.md:24 (two facts in one sentence).
    - preprovisioned.md:110 (3 sentences joined with "so").
    - Split them when you edit these files.
15. **The provider tables in `cloud.md:42-49` hold 6 columns of variable names.** This is correct for the check script, but it is dense for a small model. Optional fix: give one `for v in …` check line for each provider in place of the one AWS example at :70. Then the model does not build the list from the table.
16. **The check script did not catch M1-M3 or M6.** That is expected (it checks the format, not the semantics). Two small checks are possible:
    - a glob directly after `$CLUSTER_NAME-` in an `rm` line (M3);
    - a `grep` pattern with no `:` on a `*dryrun.yaml` file (M6).

## 4. Cloud flags against the PDF

**Method.** For each tag, I printed the page text and searched for the flag with the same spelling. The guide writes `--flag=value`. The skill writes `--flag value`. Cobra accepts both.

**Confirmed on the tagged page:**

| Section | Flags | Page |
|---|---|---|
| C2 | `--registry-mirror-url`, `--registry-mirror-username`, `--registry-mirror-password`, `--registry-mirror-cacert` | p.829-830 (AWS) |
| C2 | `--http-proxy`, `--https-proxy`, `--no-proxy` | p.830 |
| C2 | `docker load -i …konvoy-bootstrap-image…` | p.828 |
| C3 AWS | `--self-managed`, `--cluster-name`, `--with-aws-bootstrap-credentials=true`, `--vpc-id`, `--subnet-ids`, `--ami`, `--additional-security-group-ids`, `--internal-load-balancer=true`, `--os-hint flatcar` | p.830 |
| C3 AWS | FIPS `--kubernetes-version`, `--etcd-version`, `--kubernetes-image-repository`, `--etcd-image-repository` | p.829 |
| C4 EKS | `nkp update bootstrap credentials aws`, `--cluster-name`, `--kubeconfig`, the ECR mirror form `--registry-mirror-username=AWS` | p.855 |
| C4 EKS | the 1.34 limit, `nkp legacy create cluster eks`, cannot be self-managed | p.856 |
| C5 Azure | `--cluster-name`, `--self-managed` | p.197 |
| C5 Azure | `*_B64` variables | p.196-197, p.885 |
| C5 Azure | `--compute-gallery-id` and its format | p.885 |
| C5 Azure | `--plan-offer`, `--plan-publisher`, `--plan-sku` | p.880, p.885 |
| C5 Azure | `--registry-mirror-cacert` | p.886 |
| C6 AKS | `--cluster-name`, `--kubernetes-version`, `az aks get-versions -o table --location` | p.902 |
| C6 AKS | `KUBECONFIG` env | p.901 |
| C7 GCP | `--with-gcp-bootstrap-credentials=true`, `--project`, `--image`, `--dry-run`, `--output=yaml`, `--registry-mirror-cacert` | p.923 |
| C7 GCP | `GCP_B64ENCODED_CREDENTIALS` | p.913 |
| C7 GCP | `--network` | p.218 (the tag says p.219, see minor 1) |
| C8 vSphere | `--server`, `--data-center`, `--resource-pool`, `--data-store`, `--folder`, `--network`, `--control-plane-endpoint-host`, `--vm-template`, `--ssh-public-key-file`, `--self-managed`, `--registry-mirror-url`, `--registry-mirror-username`, `--registry-mirror-password` | p.842 |
| C9 | `--dry-run`, `--output yaml` | AWS p.830 (text), Azure p.880, GCP p.923 |

**Not confirmed (the flag is not on the tagged page or on any page for that provider):**
1. **vSphere `--registry-mirror-cacert`** (`cloud.md:249`). p.842 and the vSphere chapter (p.834-842) give only url, username, and password.
2. **`--namespace` on `nkp create cluster` for AWS (`:101`), EKS (`:128`), AKS (`:186`), and vSphere (`:257`).**
   - The tags `[pdf p.202, p.224]` are the Azure and GCP workload pages.
   - EKS p.859/p.866 show `--namespace` only on node pool and kubeconfig commands.
   - The skill says "Check it in `--help`" for EKS and AKS, but not for AWS and vSphere.
3. **`--kubeconfig` on `nkp create cluster` for an AWS or vSphere workload cluster.** Same cross-provider tags. EKS (p.855) and Azure (p.202) do confirm `--kubeconfig`.
4. **`--dry-run` and `--output yaml` for vSphere, EKS, and AKS create.** No page shows it. EKS p.870 shows it for node pools only.

All 4 are likely correct, because the Nutanix, Metal, and pre-provisioned live help have these flags on every create. The C1 `--help` gate (":36 If a flag is not there, stop") catches a wrong one.

Fix:
- Change the 4 tags to `[field]`, or to "same as Azure p.202, not confirmed for <provider>".
- Make the C1 Done-when name these flags explicitly: "`--namespace`, `--kubeconfig`, `--dry-run`, `--output`, `--registry-mirror-cacert` are in the `--help` output".

## 5. Other axes

**Rules block:**
- Every block in scope has a mark on line 1.
- Every block that uses a variable has the correct `source … 2>/dev/null` line 2. The check script and my read agree.
- Local `| File | Site variables |` tables are used as ADR 0003 (b) says.
- No block prints a secret, except the M6 risk.
- The connected-host blocks are USER-TERMINAL (see minor 9 for the rule text).

**"Done when":** all can be true, except M1 (`logs -A`) and possibly the ISO check (minor 7).

**UNKNOWN lines:**
- P-05, P-06, P-08 … P-14, A-07, A-08: each has an ID in OPEN-ITEMS and a READ-ONLY check command.
- P-12 (`get assignedhosts -w`) and P-09 (`get machines -w`) need a change to run. The lines say this, and OPEN-ITEMS marks them `lab`.
- A-08's check (`nkp diagnose default-config | grep`) is READ-ONLY.

**One owner per fact:** see M7 (IMAGE_BUNDLES) and minor 2 (bootstrap token). I found no other duplicates:
- Registry modes are only in airgap.
- NKPCluster patching is only in lifecycle.
- Install metal points to lifecycle for pools, and lifecycle metal points to install for imaging.

**Budget:**
- SKILL.md: airgap 247, lifecycle 249, install 241. All are ≤ 250, but there is no room for more text. The install M7 fix and the other fixes must remove as many lines as they add.
- References: all are ≤ 300 lines. The biggest is `cloud.md` with 298. `nutanix.md` has 378 and is not in scope.

**Scrub:**
- No IPs (only the CIDR defaults `192.168.0.0/16` and `10.96.0.0/12`).
- No lab name, no bastion user, no FQDN (only `example.local` in old evals).
- The live files use `<mgmt-cluster>`, `<registry-fqdn>`, `<ip>`, `<uuid>`.
- The asset SHA-256 values are upstream hashes, not secrets.

**Assets:**
- Each of the 5 headers matches its body SHA-256. I tested with `shasum -a 256`, and all 5 print `OK`.
- `download-urls.txt` pins commits and gives SHA-256 values.
- No asset is larger than ~50 KB.

**Fitness for a small model:**
- Good:
  - one create script for each cluster;
  - `${VAR:+--flag "$VAR"}` optional flags (I tested them in bash);
  - `: "${x:?}"` guards on the blocks that the agent edits;
  - the server dry-run diff before each NKPCluster patch;
  - the "yes + cluster name" gate for a delete.
- Risk: the lifecycle step 2 go-template line (`SKILL.md:83`) is about 600 characters. It works, but a small model will copy it with errors. Consider a short `jsonpath` line, and a second line for the annotations.

**Evals:**
- A1-A8, L1-L8, E12, E14, and E15 are fair, and they match the skills.
- They include an approval-gate eval (A5, L5) and a "not in the skills" eval (A6, L8, E15) for each skill.
- E13 must expect `--ssh-username "$SSH_USER"` on the upload (M4), and must not expect it on the create (M5).
- Stale IDs: M8.

**Shared changes:**
- `check_skills.py` `local_site_vars()` and its self-test are correct. Local variables do not leak to other skills (the self-test asserts `var` for `wordy`).
- The `RULES.md` note and rule 4 text are synced in all 4 skills.
- The GLOSSARY "Connected host" entry: see minor 9.
- OPEN-ITEMS: A-01, A-03, and A-04 are closed as C-11, C-12, and C-13 with evidence. The new rows are complete.
- One small problem: the "Last updated" line says "P-08 to P-12 added by the nkp-cluster-lifecycle skill", but it does not name P-13 and P-14.

## 6. Top fixes, in order

1. M4 + M5: `preprovisioned.md`: add `--ssh-username "$SSH_USER"` to the upload, and remove it from the create script.
2. M1: `maintenance.md`: `kubectl -n "$WORKSPACE_NS" logs -l …` in place of `logs -A`, and scope the `get deploy` lines.
3. M3: `delete.md` D5: use exact file names. No glob after `$CLUSTER_NAME-`. Add the `$PWD` files.
4. M6: `cloud.md` C9: anchor every grep pattern with `:`. Add the rule to the `RULES.md` authoring notes.
5. M2 + M7 + M8: the MGMT label path (from the live evidence, or a lab-ro check); `nutanix.md` points to the nkp-airgap IMAGE_BUNDLES block; E12/E13 use the IDs P-13/P-14.

Then: the cloud tags in section 4 and the minor items. All fixes are text edits. Run the check script after them, then run E13 and L-M1 (autoscaler) again.

I did not run anything on the lab, and I did not run the evals again. I did not check the pdf tags in nkp-airgap and lifecycle one by one. I checked a sample (p.57, 59-61, 497, 614, 745-746, 756-757, 761, 802, 934, 1015, 1120), and all of them matched. M2 needs a lab-ro check to close.
