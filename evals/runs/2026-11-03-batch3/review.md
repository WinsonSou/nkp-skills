# Batch 3 review: nkp-platform-apps-gitops, nkp-identity-security, nkp-storage-backup

Reviewer: Opus, fresh read-only session, 2026-11-03. Scope: commits 08ccd3c..4e5dccc. I changed no repo file except this one. Scratch files are in `/tmp/rvb3`.

What I did:
- `python3 scripts/check_skills.py --self-test && python3 scripts/check_skills.py`: both pass (`10 skills checked, 0 errors`).
- `bash -n` on all 126 command blocks in scope: no syntax errors. Every block has a mark on line 1. Every block that uses a site or cluster variable has the correct `source … 2>/dev/null` on line 2 (script `/tmp/rvb3/b2.py`). Three blocks have no line 2 because they use only `$HOME` (`gatekeeper.md:108`, `rbac.md:46`, the K6 blocks). The check script accepts them.
- `nkp` flags: compared with `nkp-help*.txt` and the help text in `platform-apps-gitops.txt` and `identity-security.txt`. All the flags are there (table in section 4).
- `[pdf p.N]` tags: I checked every tag with a script that compares the tag text with the page text, and then read each tag that the script flagged. Section 5 lists the wrong tags.
- Lab, read-only (`get`, `explain`, `api-resources`, one server dry run of the suspend patch, and `curl` of two UI paths). I read no Secret value. For the ConfigMaps that hold a secret key, I printed only the key name and the length of the value.

**Verdict: go-with-changes.** 0 BLOCKER, 6 MAJOR, 16 MINOR.

The three skills are correct, careful, and well gated. They use live evidence and log their dry runs. Examples of good work:
- The suspend reset was dry-run on the lab.
- The JSON patches for `clusterConfigOverrides` were tested.
- The B8 webhook patch has `test` ops, and a dry run with a wrong index proved that the `test` op stops it.
- The Gatekeeper `dryrun`-first flow and the PSA label dry-run loop are good.
- The secrets go to the env file, and the kubeseal seal and key backup are USER-TERMINAL.

The main defects:
- Two places can put a secret into the chat (M1, M2).
- One URL is wrong on the live cluster (M3).
- One failure pointer goes to a destructive restore section (M4).
- One override change can cut UI access without a warning (M5).
- The Dex override steps do not agree with the override model of the owner skill (M6).

## 1. BLOCKER

None.

## 2. MAJOR

**M1. The O2 READ-ONLY block can print a secret from an NKP override ConfigMap.**
- File: `skills/nkp-platform-apps-gitops/references/overrides.md:41-49`.
- Problem: the block prints the full `values.yaml` of any ConfigMap in `valuesFrom`. Some NKP ConfigMaps hold secrets. The text says "ask the user", but the user and the small model cannot know which ConfigMap has a secret. A READ-ONLY block must print no secret (GLOSSARY).
- Evidence (lab, key names and lengths only):
  - `kommander/dex-k8s-authenticator-cluster-overrides` and `dex-k8s-authenticator-kommander-overrides` have `client_secret:` with a 64-character value.
  - `traefik-forward-auth-mgmt-*` has a `clientSecret:` key.
  - Eval G2 tells the agent to read `traefik-overrides` with O2, so this path runs in an eval.
- Fix: hide the values of keys that look like secrets in the block itself, and keep the "ask" note for other keys:
  ```bash
  kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" get configmap "$cm" -o jsonpath='{.data.values\.yaml}' | sed -E 's/^([[:space:]-]*[A-Za-z0-9_]*([Ss]ecret|[Pp]assword|[Tt]oken|[Kk]ey|[Hh]ash)[A-Za-z0-9_]*:).*/\1 <hidden>/'
  ```
  Then add one line: "`dex-*`, `dex-k8s-authenticator-*`, `traefik-forward-auth-*`, and `kube-oidc-proxy-*` ConfigMaps hold client secrets [live 2.19.0]."

**M2. I7 shows the `dex-overrides` file as the plan. The file has the bcrypt hash of a local user.**
- File: `skills/nkp-identity-security/references/identity.md:302` ("The plan: the file").
- Problem: `DEX_USER_HASH` is in the secrets table of this file (`:8`), and rule 5 keeps secrets out of the chat. Commit `3aed177` fixed the same leak for node users in cluster-security.md, but I7 still has it.
- Fix: "The plan: the file without the hash line. Show it with `sed -E "s/(hash: ).*/\1<set>/" "$HOME/nkp-dex-overrides.yaml"` (READ-ONLY)." Also change the USER-TERMINAL hash block at `:265`. `htpasswd -bnBC 10 "" 'the-password'` puts the password in the shell history. Use `htpasswd -nBC 10 ""`, which asks for the password.

**M3. The UI address in identity step 1 is wrong on 2.19.0: `/nkp/kommander/dashboard` gives 404.**
- File: `skills/nkp-identity-security/SKILL.md:80` (and the `[live 2.19.0]` tag at `:83`).
- Evidence (lab, `curl -sk -o /dev/null -w %{http_code}`):
  - `https://<host>/nkp/kommander/dashboard/` gives `404`.
  - `https://<host>/dkp/kommander/dashboard/` gives `302` to `/dex/auth`.
  - The only IngressRoute paths are `/dkp/kommander/dashboard` and `/dkp/kommander/git`.
  - The skill's own `auth can-i get /dkp/kommander/dashboard` (rbac.md) and the live `dkp-*` ClusterRoles also use `/dkp`. The guide text at pdf p.580 (`/nkp/…`) is old.
- Fix: use `/dkp/kommander/dashboard` in the jsonpath. Write: "[live 2.19.0]. The guide (p.580) says `/nkp/…`. That path gives 404." The Done-when of step 1 depends on this address.

**M4. The BSL failure pointer goes to B8, the restore section. B8 deletes a ResourceQuota and patches the Kommander webhook.**
- Files: `skills/nkp-storage-backup/SKILL.md:168` (Common failures: "Velero BSL not `Available`; `velero-pre-install` job waits → B8"), and `references/velero.md:53` ("If not, B8").
- Problem: the failure table is B9 (`velero.md:307`). B8 is "Restore into the same cluster". Its first steps delete `one-kommandercluster-per-kommander-workspace` and remove `CREATE` from `kommander-validating`. A small model that follows the pointer starts a restore plan for a BSL problem. The approval gate stops it, but the agent gives the user a wrong and dangerous plan.
- Fix: change `B8` to `B9` in both places.

**M5. O8 (Traefik `service.type: NodePort`) does not warn that the Traefik LoadBalancer IP goes away.**
- File: `skills/nkp-platform-apps-gitops/references/overrides.md:175`. The eval `evals/nkp-platform-apps-gitops.md` G2 has the same gap.
- Problem: after the change, the Traefik Service has no LoadBalancer IP.
  - On the management cluster, the UI, `/dex`, and `/token` then work only through the external load balancer and `clusterHostname`.
  - The KommanderCluster gets its address from the Traefik Service. The skill's own step 4 table says that `IngressAddressReady` becomes `False` when Traefik has no LoadBalancer address.
  - The guide sets NodePort together with `clusterHostname` (pdf p.978, steps 2-4).
  - O8 has no step order and no plan text for this, and eval G2 does not test it.
- Evidence: the live `kommander-traefik` Service is `LoadBalancer`, and `kommandercluster.spec.ingress.hostname` is the MetalLB IP. `IngressAddressReady=True IngressServiceAddressFound` [live].
- Fix: in the O8 row, add these rules:
  - "First set up the external load balancer and `clusterHostname` (skill `nkp-networking`, I7)."
  - "The plan must say that the Traefik LoadBalancer IP goes away. The UI and the login then work only through the external load balancer."
  - "Do the management cluster last."
  Add the same item to the G2 Expected list.

**M6. The Dex override steps (identity I7) do not agree with the override model of the owner skill (gitops O1/O3). The Dex issuer is at risk (P-33).**
- Files: `skills/nkp-identity-security/references/identity.md:253, 289-301`; `skills/nkp-platform-apps-gitops/references/overrides.md:15-23, 78`.
- Problem:
  - Live facts:
    - The Dex HelmRelease reads `dex-overrides` **directly** (slot 2, optional, `valuesFrom`).
    - It reads `dex-cluster-overrides` in slot 3. Kommander makes that ConfigMap from the cluster override `dex-kommander-overrides`, which holds `config.issuer` (`platform-apps-gitops.txt:656-659, 818`; `identity-security.txt:66`).
  - I7 tells the agent to put `dex-overrides` in `spec.configOverrides` too (the guide way, p.578, p.587). Gitops O1 row 3 says that Kommander copies a `configOverrides` ConfigMap into `<app-id>-cluster-overrides`. That is the ConfigMap that holds the issuer. P-33 says that the result of a workspace override plus a cluster override is not known.
  - Effect: the same values come in from two slots, and the issuer ConfigMap can change. If `config.issuer` goes, every login and `kube-oidc-proxy` stop.
  - Gitops O3 also tells a reader to name a new override `$APP_ID-overrides-ws`, but I7 uses `dex-overrides`. The two skills give different answers to "which ConfigMap name".
- Fix:
  - Gitops O1, slot 2: "A ConfigMap with the exact name `<app-id>-overrides` in the HelmRelease namespace is read directly, also without `configOverrides` [live 2.19.0]. Do not name an O3 override ConfigMap `<app-id>-overrides`."
  - Identity I7: keep the guide steps. After the apply, add a READ-ONLY check of key names only: `kubectl -n kommander get cm dex-cluster-overrides -o go-template='{{index .data "values.yaml"}}' | grep -c '^ *issuer:'` must print `1`. If it prints `0`, stop, and remove `configOverrides` (gitops O5 item 5).
  - Note this result on P-33. Add one eval for the Dex token lifetime (identity) that checks the order: dry run, plan without the hash (M2), apply, and the issuer check.

## 3. MINOR

1. **The secrets are in the process list.** `--from-literal` puts the secret in the arguments of `kubectl`:
   - `identity.md:71` (LDAP bind password), `:131` (OIDC client secret);
   - `SKILL.md:129` (license key).
   
   Batch 2 (minor 15) asked for the same fix. Use `--from-file=password=<(printf %s "$IDP_LDAP_BIND_PASSWORD")`, and the same form for the other two. Or add the warning "Other users on the host can see it".
2. **The B4 credential Secret block has no guards** (`velero.md:100-114`). If `VELERO_NS` is empty, the Secret goes to the default namespace, with empty keys. Add `: "${VELERO_NS:?}" "${BSL_NAME:?}" "${OBJECTS_ACCESS_KEY:?}" "${OBJECTS_SECRET_KEY:?}"`. Do the same for the `backup-location create` block (`"${OBJECTS_BUCKET:?}" "${OBJECTS_URL:?}"`).
3. **The velero CLI pointer goes to nothing.** `velero.md:22` says "skill `nkp-airgap`, prestage", but prestage.md and `download-urls.txt` have no velero row. Two fixes are possible:
   - Ask nkp-airgap to add a P-row: the velero v1.18 tarball with its SHA-256.
   - Or write "not in the skills; the user gets it on a connected host and checks the SHA-256 with the release page".
4. **The O4 `replace` patch has no `test` op** (`overrides.md:118-128`). A wrong `i` replaces the override of another cluster. The other skills use a `test` op for each index patch. Add `{"op":"test","path":"/spec/clusterConfigOverrides/$i/clusterSelector/matchExpressions/0/values/0","value":"$target"}`.
5. **The pointer to `KommanderClusterReady` lands on the wrong block** (`SKILL.md:206` of gitops → troubleshooting flux.md F4). F4 prints `.status.kommanderCluster.conditions`, not the NKPCluster `.status.conditions` where `KommanderClusterReady` is. Give the jsonpath in place: `-o jsonpath='{.status.conditions[?(@.type=="KommanderClusterReady")]}'`. Or point to nkp-upgrade `stopped.md:67`.
6. **The project-cd pointer promises facts that the owner skill does not have.** `project-cd.md:3` sends "the project, its roles, and its secrets in the UI" to skill `nkp-identity-security`. Identity has the project and its roles (R6), but nothing on project secrets. P3 item 1 already describes the UI secret. Change the pointer to "the project and its roles".
7. **File paths with `$PWD`.**
   - `overrides.md:59,73,83,97` and `project-cd.md:55,66,76,141,160` write and read files in `$PWD`. A new tool call can start in another folder. The other skills use `$HOME`.
   - `project-cd.md:160`: the USER-TERMINAL seal block reads `$PWD/…sealed-secrets.pem`, but the agent wrote that file in its own `$PWD`, not in the user's folder.
   - Fix: use `$HOME` everywhere.
8. **`path=''` in project-cd P3** (`project-cd.md:53`). In zsh, `path` is tied to `PATH`. The rules say bash, but one zsh run makes every later command fail. Rename it to `gpath`.
9. **The fqdn check is worked around in a way that is hard to read.** `printf %s ceph.rook .io/DeviceSet` (`object-storage.md:22`) and `key='backup.velero''.io/backup-volumes'` (`velero.md:178`) get past the check script, but a small model or a user cannot easily read them. Ask the parent to add `rook.io` and `velero.io` to `ALLOWED_DOMAIN_SUFFIXES` in `scripts/check_skills.py`, then write the labels plainly.
10. **The R3 UI rule and eval S3 are too strict.** The live `cluster-admin` ClusterRole has `nonResourceURLs: ["*"]`, so it also gives `/dkp/*`. In S3 the real cause is the missing `oidc:` prefix. A correct answer ("re-bind `cluster-admin` to `oidc:nkp-admins`") gets "it only adds `cluster-admin`" as FAIL.
    - `rbac.md:258`: write "unless the subject has `cluster-admin`".
    - The eval FAIL rule: "it keeps `nkp-admins` without `oidc:`".
11. **Facts that do not match the lab or the guide.**
    - `gatekeeper.md:7`: `gatekeeper-proxy-mutations` is a HelmRelease (chart `gatekeeper-proxy-mutations@v0.3.0`), not a pod or Deployment. Only `gatekeeper-audit` and `gatekeeper-controller-manager` are Deployments [live].
    - `velero.md:142`: `caCert: <base64 of the PEM CA file>` gives no command to make the value. Add a READ-ONLY `base64 -w0 "$OBJECTS_CA_FILE"` (not secret). Or write the values file with a CHANGES heredoc as gitops O3 item 1 does.
12. **Wrong pdf tags.**
    - `catalogs.md:101` `[pdf p.295-296]`: these pages have only the cluster-type table. The dependency table (Insights → `kube-prometheus-stack`, `cloudnative-pg`; AI Navigator → `cloudnative-pg`) is on **p.307**. Harbor → `cloudnative-pg` is on **p.308**, not p.283.
    - `catalogs.md:45` `[pdf p.358]`: p.358 has only the Flux log commands. The meanings of `not found`, `unauthorized`, and `x509` are not there. Tag them `[field]`, or point to troubleshooting flux.md F3, which owns the message → owner table.
    - `SKILL.md:83` of identity: see M3.
13. **Duplicate facts (ADR 0001).**
    - Gitops `SKILL.md:225` ("no `HelmRepository` objects; `chartRef` → `OCIRepository`") repeats troubleshooting `flux.md:7-9,23`, which batch 2 made the owner. Keep only the pointer.
    - The `*-must-have-sa` constraint facts are in gitops `SKILL.md:227`, `project-cd.md:29`, and identity `gatekeeper.md` G1. Keep G1, and let the two gitops places point to it.
    - Traefik NodePort range and "the load balancer must not end TLS" are in gitops O8 and networking `ingress-certs.md:211-212`. Keep them in one place: O8 owns the values, and networking owns the load balancer.
14. **The installer-file pointers go in a loop.**
    - nkp-install `kommander.md:27` sends app settings to gitops.
    - Gitops `overrides.md:28` sends the installer file back to nkp-install (`kommander.md`).
    - For values before the first Kommander install, neither skill has the steps.
    - Fix: in O1, say "Before Kommander exists, put `apps.<app>.values` in `kommander.yaml` (skill `nkp-install`, K1-K2). After the install, use O3."
15. **Small-model fitness.**
    - These blocks need the agent to rewrite a block:
      - `rbac.md:242`: "Run it first with `--dry-run=server` added after `create`".
      - `velero.md:212-213`: `kc="$MGMT_KUBECONFIG"` must be changed to `"$DR_KUBECONFIG"` for row 10.
      - The B7 restore rows 2-9: only row 1 has a block.
      
      Give a `dry=''` toggle (`${dry:+--dry-run=server}`). Make `kc` an empty value with a guard. Give one parameterized restore block with `rname`, `sel` (array), and a note on each row.
    - `IDP_*` are site variables. A second connector of the same type replaces the values of the first (the last line wins). Add: "One connector at a time; append the new values before each connector."
16. **The evals miss risky branches.** No eval covers:
    - B7 (pause all CAPI clusters, and resume also after a failure);
    - B8 (quota delete and webhook patch);
    - O4 Ceph disable (data loss);
    - O2 on a ConfigMap with a secret (M1);
    - the I7 Dex flow (M2, M6).
    
    Add at least one eval for B7 or B8 and one for I7.

## 4. Commands and flags

All `nkp` flags are in the live help.

| Command | Flags in the skills | Evidence |
|---|---|---|
| `nkp create appdeployment` | `--app`, `--workspace`, `--project`, `--clusters`, `--config-overrides`, `--add-cluster-config-overrides`, `--dry-run`, `--kubeconfig` | `platform-apps-gitops.txt:8-36`; DR6, DR7 |
| `nkp get appdeployments` | `-w` | `platform-apps-gitops.txt:53-56` |
| `nkp attach cluster` | `--name`, `--attached-kubeconfig`, `--workspace`, `--kubeconfig` | `platform-apps-gitops.txt:205-215` |
| `nkp create catalog-app` | `--url`, `--tag`, `--workspace`, `--project`, `--secret-ref`, `--cert-ref`, `--proxy-secret-ref`, `--service-account`, `--insecure`, `--interval`, `--dry-run` | `nkp-help-airgap.txt:137-156`; DR8 |
| `nkp upgrade catalog-app` | `--to-version`, `--workspace`, `--project`, `--allow-gitrepository-catalog-apps`, `--kubeconfig` | `nkp-help-upgrade.txt:106-127` |
| `nkp generate` / `validate catalog-repository` | `--apps`, `--repo-dir`, `--config` | `platform-apps-gitops.txt:296-322` |
| `nkp create workspace` / `project` | `--display-name`, `--namespace`, `--workspace`, `--dry-run` | `identity-security.txt:108-109`; `platform-apps-gitops.txt:133-154` |
| `nkp create metadata nutanix` | `--endpoint`, `--kubeconfig` | `identity-security.txt:153` |
| `nkp check cluster fips` | `--kubeconfig` (the text also lists `-n`, `--signature-*`, `--timeout`, `--output-configmap`) | `identity-security.txt:154-155` |
| `nkp create cluster nutanix --fips` | `--fips` | `nkp-help-cluster.txt:40` |
| `nkp get clusters -A` | `-A` | `nkp-help-lifecycle.txt:165` |

`kubectl` and the lab:
- The resource names in the blocks exist on 2.19.0: `virtualgroup*`, `projects.workspaces…`, `connectors.dex.mesosphere.io`, `licenses…`, `pushsecrets`, `gitopsrepositories` (v1alpha2 served, v1alpha3 storage).
- The Dex connector fields match `kubectl explain`: ldap `bindSecretRef` key `password`, `rootCASecretRef` and `caSecretRef` key `tls.crt`, oidc `clientSecretRef` keys `client-id` and `client-secret`, userSearch `username`, `idAttr`, `emailAttr`, `nameAttr`.
- `deploy/dex-dex-controller -c manager`, `kommander-licensing-cm`, and `kommander-cm` exist.
- The suspend `replace` patch works on a HelmRelease without `spec.suspend` (server dry run on `dex`, `reloader`, and `traefik` printed `true`).
- I tested the gatekeeper awk/sed copy on the asset. It gives `enforcementAction: dryrun` and the three excluded namespaces.
- I tested the O3 YAML check. A good file gives `apiVersion not set, kind not set`. A tab gives `error converting YAML to JSON`.
- The workspace lookup jsonpath in gitops step 2 gives `kommander-workspace` for `kommander`.
- The cluster-security jq prints the users with `hashedPassword:false` and no hash.

## 5. Other axes

**Safety.**
- Every CHANGES block is gated. Step 2 of gitops also gates the client dry run. That is conservative but correct, because the same command without `--dry-run` creates the app.
- USER-TERMINAL blocks:
  - the kubeseal seal;
  - the sealing-key backup;
  - the Ceph dashboard password;
  - `htpasswd`.
- The secrets are checked with `printenv`.
- No append block has a secret. No block has a `<...>` value.
- Every shell value is `''` with a `:?` guard. Two blocks have no guard (minor 2).
- Exceptions: M1, M2, and minor 1.

**Ownership.**
- Every pointer TO the three skills from other skills lands on a section that answers it. I checked 33 pointers in networking, troubleshooting, upgrade, install, lifecycle, airgap, and the router. The exception is minor 14 (installer file).
- Pointers between the new skills:
  - Storage velero B4 and object-storage O2 → gitops O3/O4 agree. B4 uses `clusterConfigOverrides` for one bucket for each cluster, which is the same as the Ultimate rule in O4.
  - Gitops → identity (Gatekeeper, projects) lands, except for project secrets (minor 6).
  - Identity I7 against gitops O1/O3: they do not agree (M6).

**Facts.** I checked these against the lab, and they are correct:
- the ClusterApp names and versions;
- the license tiers of `cloudnative-pg` and `kube-prometheus-stack`;
- the KommanderCluster conditions;
- the PushSecret names;
- the Gatekeeper constraints;
- the Rook Ceph 1.19.5 note against the guide's 1.19.6;
- the CSI containers and images;
- the CAREN `storageClassConfigs` model;
- the `kommander-validating` rule 3 index.

The exceptions are M3 and minor 11.

**Scrub.** I found no IP, host name, lab cluster name, UUID, or secret in the skills, the evals, or the three new live files. The only domain names are Azure API groups (`cache.azure.com`) in webhook names, and they are not site data.

**Budget and style.** All files are in the limits:
- gitops SKILL.md: 231 lines;
- identity SKILL.md: 210 lines;
- storage SKILL.md: 176 lines;
- the largest reference file: `identity.md`, 343 lines.

The text is ASD-STE100. The long one-liners are the identity step 1 jsonpath and the O4 `case` block. Both are readable.

**UNKNOWN lines.** All IDs exist in OPEN-ITEMS with an owner:
- P-30 … P-33;
- P-40 … P-46;
- D-20 … D-25;
- P-03 and P-11, which were there before.

Each UNKNOWN line has a read-only check. Some checks need a later event (P-44, D-21, D-24), and the text says so.

**Evals.**
- Each skill has an approval-gate eval (G5, S4 of identity, S4 of storage) and a "not in the skills" eval (G7, S8, S7).
- The secret-in-chat prompts (identity S2, storage S8) test rule 5.
- The expected answers are correct, except identity S3 (minor 10) and gitops G2 (M5).
- Missing evals: minor 16.

## 6. Top fixes, in order

1. **M1 + M2**: mask the secret-like keys in the O2 read, and remove the hash from the I7 plan. Also change `htpasswd` to the prompt form.
2. **M4**: change `B8` to `B9` in storage `SKILL.md:168` and `velero.md:53`.
3. **M3**: use the `/dkp/kommander/dashboard` UI path.
4. **M5**: add the step order and the plan warning for Traefik NodePort to O8 and eval G2.
5. **M6**: write the slot-2 rule in gitops O1, and add the `issuer` check after the I7 apply. Add an eval.
6. Then the minor items, in this order: minor 1, 2, 4, 7, 8 (safety), then 3, 5, 6, 14 (pointers), then the rest.

Then run the check script and the evals again: G2, S2 (identity), S8 (storage), and the new I7 and B7/B8 evals.

Not checked:
- I did not run the evals.
- The lab is Starter with no workload cluster. So I could not test the Velero labels and namespaces (P-03), Rook Ceph, the P-33 merge, a project, or a GitopsRepository.
- I did not test the TFA effect of a NodePort change (M5) on the lab, because that is a change. M5 depends on the guide and the condition logic.
