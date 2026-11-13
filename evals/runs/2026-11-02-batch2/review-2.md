# Batch 2 review 2: nkp-networking

Reviewer: Opus, fresh read-only session, 2026-11-02. Scope: `git diff f26e184..HEAD` (2467c2d..8476f18): `skills/nkp-networking/**`, `evals/nkp-networking.md`, the `RULES.md` site variables, OPEN-ITEMS N-20..N-26, `research/raw/live/2.19/networking-skill.txt`, `assets/no-proxy-base.txt`. I changed no repo file except this one. Scratch files are in `/tmp/rvb2n`.

What I did:
- `python3 scripts/check_skills.py --self-test && python3 scripts/check_skills.py`: both pass (`7 skills checked, 0 errors`).
- `bash -n` on all 34 bash blocks in the skill: no syntax errors. I ran the X2 no-proxy block and the X5 `jq` block with `bash -c` and test values (RFC 5737).
- I read the PDF pages for the proxy (p.666-672, p.787, p.830, p.879, p.918, p.979-983), MetalLB (p.672-673), CIDR (p.497-498), and a sample of the other tags (section 5).
- Read-only lab checks (`.local/lab.md`). The lab log is in section 6.

**Verdict: go-with-changes.** 0 BLOCKER, 6 MAJOR, 16 MINOR.

The two hard claims are correct:
- **Proxy flags: confirmed.** On vSphere, AWS, Azure, GCP, and pre-provisioned, `--http-proxy`, `--https-proxy`, and `--no-proxy` are "for CAPI controllers". The nodes need `--control-plane-*-proxy` and `--worker-*-proxy`. Evidence: live help (`nkp-help-cluster.txt:159-202` for pre-provisioned; I ran `nkp create cluster vsphere|aws|azure|gcp --help` on the lab), and PDF Table 64 (p.668), p.669, p.787, p.879, p.918. On Nutanix and Metal, the same three flags are "for all nodes in the cluster" (`nkp-help-cluster.txt:42-54, 113-122`). The skill does not cover AKS and EKS (M2).
- **MetalLB BGP: confirmed.** I ran the server dry run again on the lab. It gives the same two errors on `spec.myASN` and `spec.peerASN`. The CRD v1beta2 `myASN` is `{"format":"int32","maximum":4294967295,"type":"integer"}`, and the CRD is `Established`. The cause is the CRD schema: the `maximum` is larger than the int32 range, and the 1.36.2 API server rejects it. The skill quotes the message and does not guess more. That is correct. N-20 is a good item.

## 1. BLOCKER

None.

## 2. MAJOR

**M1. A proxy URL that holds a user and a password goes into the model context, the chat, and files.**
- proxy.md:9 correctly says that such a URL is a secret (rule 5). But the variables are in the non-secret row of the rules table, so the check script does not protect them. These blocks print the value:
  - `SKILL.md:69`: step 1 prints `proxy={.value.proxy}` (the `http` and `https` URLs).
  - `proxy.md:116`: prints the `gatekeeper-overrides` values. Line 120 also tells the agent to "show its values to the user".
  - `proxy.md:178`: `jq -nc …` prints the JSON with both URLs. Line 181 then tells the agent to paste that JSON as `value` into the lifecycle "Cluster field" block. The secret goes into the chat and the command text.
  - `nkp-cluster-lifecycle` step 3b (the server dry-run diff) prints the full NKPCluster YAML, including `proxy.http`.
  - `proxy.md:190` (X6 line 1) and `proxy.md:100` (the N-23 `grep` with `^ +(http|https|additionalNo):`) print the URLs.
  - `proxy.md:129-130` writes the URLs to `$PWD/$CLUSTER_NAME-gatekeeper-proxy.yaml` with the default umask, so the file is world-readable.
- Evidence: `bash -c` with `NKP_HTTP_PROXY='http://u:p@proxy.example.com:3128'`. The `jq` line prints `"http":"http://u:p@proxy.example.com:3128"`.
- Fix (keep the variables in the site row, because most proxies have no password):
  1. In proxy.md, before X2, add one READ-ONLY check:
     ```bash
     # READ-ONLY
     source ~/nkp-site.env 2>/dev/null
     case "$NKP_HTTP_PROXY $NKP_HTTPS_PROXY" in *@*) echo "proxy URL has a user or password";; *) echo "no credentials in the proxy URL";; esac
     ```
     (I tested it with `bash -c`.) Add this text: "If it prints `has a user or password`, these blocks are USER-TERMINAL: step 1, X4 step 1, X5 C, X6 line 1, the N-23 check, and the lifecycle 3b dry run. Tell the user that NKP keeps the URL in plain text in the NKPCluster and in the ConfigMap `gatekeeper-overrides`."
  2. X5 C: do not print the JSON. Tell the agent to set `value="$(jq -nc --arg h "$NKP_HTTP_PROXY" --arg s "$NKP_HTTPS_PROXY" --arg n "$NO_PROXY_LIST" '{http:$h,https:$s,additionalNo:($n|split(","))}')"` in the lifecycle block. The shell expands it, and the agent never sees the URL.
  3. `SKILL.md:69`: print only `proxyNo={.value.proxy.additionalNo}`. Add a second line that prints only the length of `http`, in the same way as X6.
  4. `proxy.md:129`: write the file in `(umask 077 && printf … > "$f")`.

**M2. X3 has no rule for AKS and EKS. With the nine flags, the create fails.**
- File: `proxy.md:83` names "Pre-provisioned, vSphere, AWS, Azure, GCP". It says nothing about the two managed providers.
- Evidence (lab, `--help`):
  - `nkp create cluster aks` has only `--worker-http-proxy`, `--worker-https-proxy`, and `--worker-no-proxy`.
  - `nkp create cluster eks` has no proxy flag.
  - The skill-set convention is that EKS → AWS. So a small model will use the nine AWS flags on EKS.
- Also on Metal: `nkp-help-cluster.txt:113` says "for all nodes in the cluster", the same as Nutanix. N-23 asks only about Nutanix, but the same question is open for Metal.
- Fix: add two lines to X3. "AKS: only the three `--worker-*` lines [live 2.19.0]. EKS: `nkp create cluster eks` has no proxy flag [live 2.19.0]. Proxy on EKS: not in the skills." Add Metal to N-23 (the text and the OPEN-ITEMS row). Record the AKS and EKS help lines in `networking-skill.txt` (section 6 below has them).

**M3. nkp-install has copies of the proxy flags, and the cloud copy is wrong for the nodes (ADR 0001).**
- `nkp-install/references/cloud.md:66` says: "Proxy: add `--http-proxy`, `--https-proxy`, and `--no-proxy` before `"$@"`. [pdf p.830]".
  - On AWS, Azure, GCP, and vSphere, those flags set only the CAPI controllers (see the verdict).
  - A model that follows nkp-install makes nodes with no proxy, and the image pulls fail.
  - Page 830 gives the flags, but it points to the page-668 section, where Table 64 lists the node flags.
- `nutanix.md:131`, `metal.md:105`, and `preprovisioned.md:135` list the proxy flags among the "other flags". `preprovisioned.md:135` names only the `--control-plane-*` and `--worker-*` flags. It does not give the three CAPI flags that a `--self-managed` create needs.
- Fix: the exact nkp-install changes are in section 4. The proxy flags stay only in `proxy.md` X3.

**M4. The X4 "Done when" and the X6 Flux check can pass when Gatekeeper did nothing.**
- Files: `proxy.md:152`, `:192`, `:197`.
- Evidence (lab, no proxy on the site):
  - `flux-oci-mirror` in `kommander-flux` already has `HTTP_PROXY=16 chars HTTPS_PROXY=17 chars NO_PROXY=14 chars`. The values are unexpanded `${…}` text.
  - The other Flux controllers have the three names with no value. They come from the Helm chart `flux2-2.18.3`, not from Gatekeeper.
  - So the rule "with the proxy, the length is more than 0" passes with no proxy at all.
  - X6 reads old pods, and X4 itself says that only new pods get the values.
- Fix: use a server dry run of a new pod in a labeled namespace. The Gatekeeper mutating webhook has `sideEffects: None` [lab]. The command prints only the names:
  ```bash
  # READ-ONLY  (server dry run: creates no pod)
  source ~/nkp-<cluster>.env 2>/dev/null
  kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n kommander run proxy-check --image=busybox --restart=Never --dry-run=server -o json | jq -c '[.spec.containers[0].env[]?.name]'
  ```
  Today it prints `[]` on the lab (mutation off). Done when it prints `["HTTP_PROXY","HTTPS_PROXY","NO_PROXY"]`. Remove the Flux-length line, or limit it to `helm-controller` and say "after the Flux pods restart".

**M5. `assets/no-proxy-base.txt` is not an asset. Put the list inline.**
- GLOSSARY defines an asset as "a small pinned **third-party** text file … that the bundle does not include". AUTHORING requires "the upstream version and SHA in a header".
- This file is a list that the author compiled from PDF text (p.669, p.979-980). It has no upstream file and no SHA. So it fails both rules.
- It also adds a failure point for a small model. The agent must set `dir` to the skill folder. Batch 1 minor 5 (`SKILL_DIR`) found the same weak point. The `awk | paste` step does the work of one literal string.
- Fix: delete the asset. In both X2 blocks, replace the `dir` and `awk` lines with a literal, and add the source tag above the block. I tested this with `bash -c` (`/tmp/rvb2n/fix-x2.sh`):
  ```bash
  extra=''; aws=''; pods='192.168.0.0/16'; svcs='10.96.0.0/12'
  : "${CP_VIP:?}" "${LB_IP_RANGE:?}"
  base='localhost,127.0.0.1,kubernetes,kubernetes.default,kubernetes.default.svc,kubernetes.default.svc.cluster,kubernetes.default.svc.cluster.local,.svc,.svc.cluster,.svc.cluster.local,svc.,.svc.cluster.,.svc.cluster.local.,169.254.169.254,169.254.0.0/24'
  echo "$base${aws:+,10.0.0.0/16,.elb.amazonaws.com},$pods,$svcs,$CP_VIP,${LB_IP_RANGE%%-*}${extra:+,$extra}"
  ```
  Change "Set `aws` to `yes`" to "Set `aws` to `yes` (any text) only for AWS". The entries match the PDF.

**M6. X4 step 2 replaces an existing `gatekeeper-overrides` in the same block that writes it. The other values are lost.**
- File: `proxy.md:120`, `:126-132`. The text says "Keep the other values that the user wants by adding them to the file before the apply". But one CHANGES block writes the file and applies it, so the agent has no step where it can add the values.
- Fix: split the block into two. (a) CHANGES: write the file only (with umask 077). (b) CHANGES: apply. Between (a) and (b), add: "If step 1 printed old values, merge them into the file and show the user the merged file." Also add `kubectl … apply --dry-run=server` before (b). The webhooks that match ConfigMaps have `sideEffects: None` or `NoneOnDryRun` [lab].

## 3. MINOR

1. **SKILL.md:38** says "Calico on the other providers [pdf p.20]". p.20 says that the Nutanix **and EKS** providers use Cilium. `cni.md:10` has it correctly. Fix: "Cilium on AHV (default) [live] and EKS [pdf p.20] (P-05). Calico on the others."
2. **proxy.md:58** puts `~/nkp-<cluster>.env` in the command body. ADR 0003 allows `<cluster>` only on line 2. Fix: `>> "$HOME/nkp-$CLUSTER_NAME.env"` (the same form as `delete.md`).
3. **proxy.md:5-7.** The local `Site variables` table repeats `NO_PROXY_LIST`, which is already in the rules table. Remove the table.
   - About the rules-table change: keep `NKP_HTTP_PROXY`, `NKP_HTTPS_PROXY`, and `NO_PROXY_LIST` in the core table. At run time, the nkp-install create script and the nkp-upgrade CAPI step use them. The cost is about 15 tokens.
4. **ingress-certs.md:17**: "`kommander-ca` has a 10-year lifetime from 2.18 [field]". Live: the Certificate `cert-manager/kommander-ca` has `duration: 87600h` (10 years). Fix: tag it `[live 2.19.0]`. Add a fact that is useful: `kommander-traefik-tls` has `2160h` (90 days) and cert-manager renews it.
5. **SKILL.md:114.** The claim "The API accepts the change [live 2.19.0]" for a pod CIDR change has no row in `networking-skill.txt`. The dry runs there are for the proxy, kubeProxy, CNI, LB ranges, and ingress. I confirmed it now: a JSON patch `replace /spec/capiCluster/clusterNetwork/pods/cidrBlocks/0` gives `["172.20.0.0/16"]` in a server dry run. Add it to the live file as dry run 15.
6. **Commands in prose, with no block, no mark, and no `source` line** (the same as batch 1 minor 4):
   - `SKILL.md:103` (the Hubble per-node steps with `<node>`, `<agent-pod>`).
   - `ingress-certs.md:90` (renew: delete and create the Secret).
   - `ingress-certs.md:139` (write, dry-run, and apply the ACME issuer).
   - `ingress-certs.md:147` (`get certificates,orders,challenges`).
   - `metallb.md:81` (the Done-when has `kubectl` with no `--kubeconfig`).

   Put each one in a marked block.
7. **metallb.md:87-101, M3 order.** The text says "Stop first", but then asks for 4 values, writes a file, and runs a dry run that will fail. Fix: run the N-20 check (READ-ONLY) first. If it prints `"format":"int32"` with `"maximum":4294967295`, stop there and offer M2. Run the write and the dry run only when the schema is different.
8. **proxy.md:165, X5 A.** The lab also has `cluster-api-provider-host-agent-system/capi-host-agent-controller-manager` (the Metal and pre-provisioned provider) and `azureserviceoperator`. The guide list (p.671) does not have them. Fix: add one line, "The guide list does not have `capi-host-agent-controller-manager`. Not in the skills whether it needs the proxy." Add this question to N-22.
9. **proxy.md:156-166, X5 A on the management cluster.**
   - Say that `<cluster>` is the management cluster in part A.
   - The management `NO_PROXY_LIST` must name the API VIP of every workload cluster (p.979). So each new workload cluster needs a new list, and with it a node roll of the management cluster (X5 C). Tell the user this in X2.
10. **X2.** The skill knows `PC_ENDPOINT` and `REGISTRY_URL`. Add their host names to the list automatically, or name them in the prompt to the user. Add a 128-item check before X5 C: `printenv NO_PROXY_LIST | tr ',' '\n' | wc -l`.
11. **proxy.md:97.** "The guide also asks for the same proxy in an override file [pdf p.787]". The skill does not give the file content. p.787 also says that since DKP 2.6 the flags fill a Secret automatically. Fix: "p.787 also says that the flags fill the override Secret themselves. The override file format: not in the skills."
12. **N-23 check (proxy.md:100).** A dry-run YAML holds the cluster objects. It can show `clusterConfig.proxy`, but not the CAPI controller environment. Fix: say that the check answers only the node part. The controller part needs `kubectl … -n capx-system get deploy capx-controller-manager -o jsonpath='{…env[*].name}'` after a real create.
13. **Evals:**
    - W3: also accept an answer that runs the N-20 check and stops before it asks for the values (see minor 7).
    - Add **W9**, a proxy eval for vSphere or pre-provisioned. Expected: the nine lines. FAIL if it gives only `--http-proxy`, `--https-proxy`, and `--no-proxy`. This is the riskiest fact in the skill, and no eval covers it (carry-over: "the proxy eval that the pilot skipped").
    - Add **W10**, a proxy URL with a user and a password. Expected: the user writes it with an editor, and the print blocks are USER-TERMINAL (M1).
    - Do the AKS line of M2 together with W9.
14. **ASD-STE100.**
    - `cni.md:108` uses the passive "can be dropped", in a 30-word sentence. Change it to "a node that does not own the Service IP can send the reply, and the network can drop it."
    - `proxy.md:39` puts six instructions in one paragraph. Use a list.
    - `SKILL.md:114`, `:117`: split the two-clause cells.
15. **metallb.md:16-17.** On pre-provisioned hosts, nkp-install P7 makes the first pool with the name `default`, not `metallb`. Name both pools in the "Do not edit the default pool" rule. Also say that the p.672 rule is about the pool that NKP made.
16. **proxy.md:15** repeats "The operator host must be in the same network and proxy domain [pdf p.666]". The owner of this fact is nkp-install (`SKILL.md:66`, a create prerequisite). Keep the X1 row, but make the cell "see skill `nkp-install`, prerequisites".

## 4. Changes that nkp-install needs (pointers only)

Note: nkp-install `SKILL.md` has 241 lines of its 250. Each change below removes text or keeps the line count.

1. **`references/cloud.md:66`.** Replace the line with: "- Proxy: add the lines from skill `nkp-networking`, `references/proxy.md`, sections X2 and X3. The three flags `--http-proxy`, `--https-proxy`, and `--no-proxy` alone do not set the nodes on these providers." Remove `[pdf p.830]`. (This fixes a wrong fact. It is not only a pointer.)
2. **`references/nutanix.md:131`.** Remove `--http-proxy`, `--https-proxy`, `--no-proxy` from the "Other flags" list. End the line with: "For a proxy, add the lines from skill `nkp-networking`, `references/proxy.md`, X3."
3. **`references/metal.md:105`.** Remove `--http-proxy`, `--https-proxy`, `--no-proxy` from the list. Add: "Proxy: skill `nkp-networking`, `references/proxy.md`, X3."
4. **`references/preprovisioned.md:135`.** Remove "the `--control-plane-*-proxy` and `--worker-*-proxy` flags" from the list. Add the same pointer. (X3 gives all nine flags. Today the text leaves out the three CAPI flags.)
5. **`references/nutanix.md` near line 131 (add one line).** "Custom domain and ingress certificate at create time (`--cluster-hostname`, `--ingress-certificate`, `--ingress-private-key`, `--ingress-ca`): skill `nkp-networking`, `references/ingress-certs.md`, I1." Now nkp-install has no route to these flags.
6. **Optional, `references/cloud.md` C1 Done-when.** Name the proxy flags in the `--help` check: "`--control-plane-http-proxy` and `--worker-http-proxy` are in the output (except EKS and AKS)."

Keep these in nkp-install, because they are create-time facts: `SKILL.md:66` (proxy domain prerequisite), `nutanix.md:367` (CIDR overlap preflight), and the P7 first MetalLB pool. nkp-networking points to them (minors 15 and 16).

## 5. Other axes

**Source tags.** These tags are on the correct page:
- p.20, p.309, p.491, p.493-495, p.497-498, p.593-596, p.666-673, p.678-679, p.711, p.721, p.727-729, p.783-787, p.964-971, p.977-983.
- p.492 for "DNS01 required behind a proxy": the page says "network-restricted cluster … restricted to DNS". This is close enough.
- p.968 "cert-manager does not renew": correct.

Wrong or weak tags: minors 1, 4, and 5.

The `[live 2.19.0]` claims that I checked on the lab are correct:
- the Traefik image v3.6.12;
- the BGPPeer rejection;
- the `clusterConfig.proxy` keys in all 4 ClusterClasses;
- the HelmRelease `gatekeeper` reads `gatekeeper-overrides` in `kommander`;
- the server dry run of the FederatedNamespace merge patch. It adds the label and keeps the other labels, so `proxy.md:142-148` is correct.

**Rules block.**
- Every block has a mark on line 1 and the correct `source … 2>/dev/null` on line 2. Blocks that use only `MGMT_KUBECONFIG` use the site file (proxy.md:146).
- No block prints an env file or Secret data.
- The proxy password case is the one gap (M1).
- The file writes are CHANGES. Only `proxy.md:129` has no `umask 077`.

**"Done when".** All of them can be true, except X4 and X6 (M4). The Step 3 "user agrees" is a judgment, and that is acceptable.

**UNKNOWN lines.**
- N-20..N-26, N-01, N-03, and P-02 are all in OPEN-ITEMS, and each has a READ-ONLY command.
- N-22 and N-25 need a change before the check can answer. OPEN-ITEMS marks them `lab`. Good.
- N-23 needs a note (minor 12).

**One owner per fact.** See M3 and section 4. I found no copies from nkp-cluster-lifecycle: X5 C points to step 3, and lifecycle `variables.md:35,104,107` points back. I found no copies from nkp-airgap.

**Budget.** SKILL.md has 140 lines. The reference files have 122-198 lines. The evals have 104 lines. All are well inside the limits.

**Scrub.** Every IP in the diff is RFC 5737, a Kubernetes default CIDR, link-local, loopback, or the AWS default VPC (10.0.0.0/16, from the PDF). The eval prompt `172.20.0.0/16` is an RFC 1918 example, not a site CIDR. The live file uses `<ip>` and `<mgmt-cluster>`. The diff has no host name or lab name. "bastion" is only a word.

**Fitness for a small model.**
- Good:
  - the `: "${x:?}"` guards;
  - the server dry run before each apply;
  - the "do not edit the default pool" rule;
  - the clear "No" rows in step 3.
- Risks:
  - the step 1 `jsonpath` (~420 characters);
  - the X5 A one-line loop (~900 characters, but the model copies it as one unit);
  - the `dir` variable (M5).

**Evals.** W1-W8 are fair and match the skill. W5 tests the approval gate. W8 tests a fact that is not in the skills. Gaps: minor 13.

## 6. Lab log (read-only; nothing changed)

Bastion with the lab kubeconfig, NKP 2.19.0, k8s v1.36.2:
- `nkp create cluster vsphere|aws|azure|gcp --help`: the `--control-plane-*-proxy` and `--worker-*-proxy` flags ("for nodes") and `--http-proxy`, `--https-proxy`, `--no-proxy` ("HTTP proxy for CAPI controllers").
- `nkp create cluster aks --help`: only `--worker-http-proxy`, `--worker-https-proxy`, `--worker-no-proxy`. `nkp create cluster eks --help`: no proxy flag.
- Webhooks: every webhook is `None` or `NoneOnDryRun`. The `NoneOnDryRun` webhooks are only on dex connectors, appdeployments, kommander federation objects, and secrets. The MetalLB (6), Gatekeeper, nkp-cluster, CAPI, and CAREN webhooks are `None`. I printed the MetalLB `sideEffects` values after dry run 1, but the earlier all-webhook query had already shown only `None` and `NoneOnDryRun`.
- Dry run 1: BGPPeer v1beta2 (myASN 64500, peerASN 64501, peer 198.51.100.1), `apply --dry-run=server`. Rejected with the int32 error on myASN and peerASN. Then `get bgppeers`: none.
- `get crd bgppeers.metallb.io`: myASN `{"format":"int32","maximum":4294967295,"minimum":0,"type":"integer"}`. Established=True.
- Dry run 2: `patch fns -n kommander kommander --type merge` (template label `gatekeeper.d2iq.com/mutate: pod-proxy`): accepted. The other labels stay.
- Dry run 3: NKPCluster JSON patch `replace /spec/capiCluster/clusterNetwork/pods/cidrBlocks/0` → `172.20.0.0/16`: accepted.
- Dry run 4: `kubectl -n kommander run proxy-check --image=busybox --restart=Never --dry-run=server`: env names `[]` (mutation off). Then `get pod proxy-check`: NotFound.
- `kommander-flux` pods: `flux-oci-mirror` has PROXY values of 14-17 characters (they start with `${`). `helm-controller` and the other controllers have the names with no value. Deployment labels: `managed-by Helm`, chart `flux2-2.18.3`.
- Certificates: `cert-manager/kommander-ca` 87600h (issuer `selfsigned-issuer`). `kommander/kommander-traefik-tls` 2160h.
- ClusterClass status: `clusterConfig.proxy` keys `additionalNo`, `http`, `https` on nutanix, aws, eks, and host-agent.
- `capi-host-agent-controller-manager` is in `cluster-api-provider-host-agent-system`.

## 7. Top fixes, in order

1. M1: the proxy credential check, the USER-TERMINAL rule for the blocks that print the URL, the `value="$(jq …)"` in X5 C, and `umask 077` on the Gatekeeper file.
2. M3 + section 4: correct `nkp-install/references/cloud.md:66` (the nodes have no proxy today), and change the other proxy flag lists into pointers to X3.
3. M2: X3 lines for AKS (worker only) and EKS (no flag). Add Metal to N-23. Add eval W9 (vSphere/pre-provisioned, nine flags).
4. M4 + M6: the server dry-run pod as the X4 and X6 proof; split X4 step 2 into write, merge, dry run, and apply.
5. M5: delete `assets/no-proxy-base.txt`, and put the tested literal list into both X2 blocks.

Then do the minor items. All fixes are text edits. Then run the check script, and run W1, W2, W3, the new W9, and the new W10.

I did not run the evals. I did not open every PDF tag in `cni.md` and `ingress-certs.md`. Section 5 lists the sample that I checked, and all of it matched.
