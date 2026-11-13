# Batch 5 fix pass: nkp-ndk (and its cross-skill rows)

Date 2026-11-03. Scope: `review.md` M4, minors 2, 3, 4, 5, 6, 11 (`replication.md` part), 17 (ndk parts), 19, and `grading.md` minor 2. Eval IDs are kept.
Checks: `check_skills.py --self-test` and `check_skills.py` pass (16 skills, 0 errors). `bash -n` passes on all 44 command blocks of `nkp-ndk` (SKILL.md, protect.md, replication.md, operations.md) and of `nkp-airgap` `prestage.md` and `catalogs.md`. Line counts: SKILL.md 250, protect.md 264, replication.md 201, operations.md 130, prestage.md 134, catalogs.md 82, observability SKILL.md 175, storage-backup `csi.md` 252.
Lab: not used. The CRD facts of minors 4 and 5 come from the NDK 2.3.0 chart CRDs that the reviewer extracted (`/tmp/rvb5/ndk/x/ndk/crds`). That chart has the same digest as the bundle chart (review section 4).

## review.md

- **M4 fixed.** The gate sentence ("Each write block is CHANGES. Before you run it, show the values and the file path, and stop for "yes" (rule 2). Then do the dry run, show the plan again, and stop for "yes" before the apply.") is now at the top of SKILL.md step 5, at the top of `protect.md`, and at the top of `replication.md`. Each of the 10 write blocks has "Show the plan, stop for "yes"" directly before it: SKILL.md step 4 (StorageCluster), protect.md P1, P2, P4, and P5 (and P3 and P7), replication.md R2, R3, R4, R5, and R6, and operations.md X1 and X3. A script checked that the line before every CHANGES block in the skill has `"yes"`. The only CHANGES block with no such line is the step 5 apply block, and the sentence at the top of step 5 covers it.
- **Minor 2 fixed** (SKILL.md step 3, item 1). The connected URL is now `[field]`, with "This public tag can change and can list more apps than NDK: enable only `ndk`." I also moved the `kommander-workspace` bullet into the item 1 lead-in to get back lines.
- **Minor 3 fixed** (replication.md R2). Before the brace: `case "$tls" in off|skip) ;; ca) : "${ca_file:?}"; [ -s "$ca_file" ] || exit 1 ;; *) exit 1 ;; esac`, plus `mTLS needs TLS`. The `*)` branch inside the brace is removed, and the `ca` branch reads `"$ca_file"`. I tested this in `/tmp/ndkfix`. The four bad cases exit 1 and write no file: `tls=ca` with an empty `ca_file`, `tls=ca` with a missing file, `tls=bogus`, and `tls=off` with `mtls_secret`. The good cases give valid YAML (I parsed them with PyYAML): `off`, `skip`, `ca`+file, `ca`+mTLS, and `skip`+mTLS.
- **Minor 4 fixed** (SKILL.md step 5, operations.md X5, replication.md R2 and R3). The immutable list now has: the spec of `StorageCluster`, `Remote`, `ReplicationTarget`, `ProtectionPlan`, and `ApplicationSnapshotRestore`; all of `ApplicationSnapshotReplication`; `AppProtectionPlan.spec.applicationName`; `expiresAfter` and `rpo`. All are `[live 2.19.0 CRD]`. I confirmed each with `grep 'message:.*mmutable'` in the chart CRDs. The X5 row now matches `is immutable` and points to the step 5 list. R2 and R3 "Not `True`" now say: delete the object and make it again (CHANGES, plan, "yes").
- **Minor 5 fixed** (protect.md P5, replication.md R5). `interval_min` is 60 or more `[live 2.19.0 CRD]` (from the `jobschedulers` CRD description). P5 says that the dry run can accept a lower value, because the limit is only in the description.
- **Minor 6 fixed** (operations.md X3). Item 3 writes into the one file `$HOME/$CLUSTER_NAME-ndk-values.yaml` with `>>` (mode 600). If the file already has a `ui:`, `config:`, or `deployment:` key, the block stops, so a second run cannot add the keys twice. The text says that the SKILL.md step 3 block replaces the file, so do items 3 and 4 again after it. Item 4 opens the same file. Item 2 uses `htpasswd -nBC 10 ""`, which asks for the password. I tested this in `/tmp/ndkfix`: with an existing TLS file the block appends and the YAML is valid; a second run stops with rc 1; with no file it makes a mode-600 file. The CSI "(2.19.0 has 3.9.0)" copy in X3 is removed too (minor 19).
- **Minor 11, replication.md:190 part, fixed** (now R9, D-53). The inline check sets `ns=''` with `: "${ns:?}"` and says "set `ns` to its namespace". The flow `egress-vpc.md` parts are not in my scope.
- **Minor 17, ndk parts, fixed** (evals/nkp-ndk.md, SKILL.md step 2).
  - K6: SKILL.md step 2 now has the line "The Kubernetes versions that NDK supports and the NDK scale limits … are not in the skills (open item D-03, no check command)". This is the same form as flow F-09. So K6 can quote D-03.
  - The general FAIL now also allows the alert `PrometheusRule` (operations.md X1) in `ntnx-system`.
  - The eval ID rename (K → another letter) is optional in the review, and the task says to keep the IDs. Not done.
- **Minor 19 fixed** (SKILL.md "The NDK parts" row, step 1 "How to read it", the step 2 table; evals K1). "(1.20.3 on 2.19.0)", "(3.9.0 on 2.19.0)", "2.19.0 has 3.9.0", and "Gateway API v1.3.0" are removed. The minimums cert-manager ≥ 1.13 and CSI ≥ 3.7.1 stay (chart precheck, `ndk-chart.txt:19`). Step 1 "How to read it" now says that the `cert-manager` HelmRelease line shows its version. K1 now expects "the CSI version from step 1 is 3.7.1 or later" in place of "CSI 3.9.0".

## grading.md

- **Minor 2 fixed** (SKILL.md step 3, item 1). I added a READ-ONLY block for a site registry. It sends `curl -K - -s -I` (HEAD) with `--cacert "$REGISTRY_CA_FILE"` and the OCI `Accept` headers to `https://<host>/v2/<path>/nutanix-cloud-native/nkp-nutanix-product-catalog/collection/manifests/2.19`, and it prints only the HTTP code. It splits `REGISTRY_URL` the same way as the nkp-airgap step 4A access check. The pull account (`REGISTRY_MIRROR_USERNAME`, `REGISTRY_MIRROR_PASSWORD`) goes to curl as a config line on stdin (with `"` and `\` escaped), so it is not in an argument list or on the screen. With no user set, curl sends no login. The text explains each code: `200` the artifact is there; `404` not pushed or another path (A-07); `401` a wrong account, or a registry that wants a token login, so the user checks the registry UI; `000` no connection or a CA error. No `nkp` flag reads a registry. I tested it with a stub `curl` (URLs for `https://host/project`, `https://host:5000`, no scheme with two path parts, and an empty `REGISTRY_URL`, which the guard stops), and with real curl against a local HTTP server (a password with `"`, `\`, and a space arrives unchanged in the basic auth header; with no user there is no header and the code is `401`). K1 now expects this check.

## Cross-skill (my files only)

- `nkp-airgap/references/prestage.md`: the NDK row of "In the bundle" says that the recipes image `ndk/recipes`, `ndkcli`, and the recipe job files come only from the portal NDK bundle (P7). The P8 row says that the Flow CNI dark-site bundle has only images, because the chart `nutanix-flow-cni` comes from the CAREN chart server on the management cluster, and that the bundle version must be the same as that chart version.
- `nkp-airgap/references/catalogs.md` C1: the product catalog row names the same repository and tag `2.19` on `ghcr.io` for a connected site, tagged `[field]`, with a pointer to `nkp-ndk` step 3.
- `nkp-observability/SKILL.md:54`: the NDK pointer adds "they need an event exporter that NKP 2.19 does not ship: D-54".
- `nkp-storage-backup/references/csi.md` C2: one line after the schema table: "The table has no `usePEFallback` key. NDK sync failover needs CSI `usePEFallback: false` (D-56, skill `nkp-ndk`)."

## OPEN-ITEMS

- D-02: the skill now checks the pushed catalog artifact with a READ-ONLY `curl` HEAD.
- D-03: the skill names D-03 as an open item with no check command (step 2).
- D-45: new evidence from review minor 2. The public `collection:2.19` can change. It now lists `nutanix-ai` 2.8.0 and 2.8.1, `kserve` 0.19.0, `envoy-gateway-nai` 1.8.2, `opentelemetry-operator` 0.114.1, `leaderworkerset` 0.8.0, and `ndk` 2.3.0, and its digest is not the digest of the bundle copy (`[field]`, crane).
- D-54: `nkp-observability` points here.
- D-56: the `csi.md` C2 schema has no such key; C2 points here.
- D-01, D-04, D-50 to D-53, D-55: no change. The "Last updated" line is not changed.

## Not done, and changes other files need

- Run evals K1, K4, K5, and K6 again. I did not run them in this pass.
- The flow parts of minor 11 (`egress-vpc.md:3, 47, 81, 82`) and minor 17 (the L/K eval ID collisions) belong to other owners or are optional.
- The registry check of the catalog artifact was not run against a real Harbor. For a private project, Harbor wants a bearer token, and curl sends only basic auth, so the check can give `401` even with a correct account. The `401` text then sends the user to the registry UI, and that is the old K1 behavior.
