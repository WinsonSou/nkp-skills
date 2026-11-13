# Batch 5 review: nkp-flow-cni, nkp-vpc, nkp-ndk

Reviewer: Opus, fresh read-only session, 2026-11-03. Scope: `git diff fde8b02..a4b7c2a` (3 skills, 3 eval files, OPEN-ITEMS rows, live files `flow-cni.txt`, `vpc.txt`, `ndk-chart.txt`). I changed no repo file except this one. Scratch files are in `/tmp/rvb5`.

What I did:
- `python3 scripts/check_skills.py --self-test && python3 scripts/check_skills.py`: both pass (`16 skills checked, 0 errors`).
- `bash -n` on all 56 command blocks in scope: no syntax errors. Every block has a mark on line 1. Every block that uses a variable has the correct line 2 (`/tmp/rvb5/b2.py`, with the vpc cluster variables added). One block sources the cluster file but uses no cluster variable (minor 14).
- Rule 4: almost every shell value in a block is `''` with a `:?` guard, or a `case` guard (`mode`). The constants are `hostprefix='24'` (flow I4, the guide value, "change it only when the user asks") and `pod_cidr`, `svc_cidr` (vpc step 2, the NKP defaults, with a "set the new CIDRs" line). I accept them as constants, as the batch 4 review accepted `repo='nvidia/driver'`. No append block shows a guessed value. No `<...>` text is in a block value.
- Secrets: no block prints a secret. `NDK_PULL_*` goes through `printenv` → builtin `printf` → `base64` → `--from-file=.dockerconfigjson=/dev/stdin` → `apply`. So the token is never in an argument list or on the screen. `FLOW_CNI_PULL_*` goes the same way into a mode-600 file. The skill shows the file only without the `auth:` line and warns that the HCP spec holds the token. Gaps: minor 9 (HCP `-o yaml`) and minor 13 (`daemon.json` proxies).
- Approval gates: I listed each CHANGES block and the text before it. Flow and vpc have a plan and a stop before each block (two small wording gaps, minor 12). NDK has no plan or stop text before 10 file-write blocks (M4).
- `nkp` flags: all of them are in `nkp-help-cluster.txt` (`--control-plane-external-endpoint` :23, `--cluster-hostname` :17, `--extra-sans` :39, `--onboard-to-prism-central` :58, `--kubernetes-pod-network-cidr` :49, `--kubernetes-service-cidr` :50). `nkp create catalog-bundle --airgapped --apps` is only named as the guide way that the skill does not use (pdf p.340). `nkp create cluster` has no CNI flag: `grep -ci cni nkp-help*.txt` gives 0. That confirms flow `SKILL.md:124`.
- `[pdf p.N]` tags: I compared each tag with the page text (`/tmp/rvb5/tags.py`, then I read pages 321, 337-343, 645, 709-712, 720-721, 724). All tags are correct except one (minor 1).
- Upstream checks (for evidence, not used in the skills):
  - The chart `oci://ghcr.io/mesosphere/charts/ndk:2.3.0` has digest `sha256:639d90f8…8167`, the same digest as the chart in the lab bundle (`tar -t`). I read its `values.yaml`, its templates, and its 19 CRDs with yq.
  - mikefarah yq v4.47.1, built locally, to test the flow I3/I4 expressions on a synthetic NKPCluster + Cluster + Secret file.
  - The MetalLB v0.15.3 source (`controller/service.go`).
  - The kind source (`pkg/cluster/internal/providers/docker/network.go`).
  - The product catalog `collection:2.19` on ghcr.io (crane).
- Lab, read-only:
  - `kubectl get`: ClusterClasses by namespace, workspaces, the CAREN `helm-repository` Service port, the HelmChartProxy owners, the OCIRepositories, the webhook configurations, and the KommanderCluster owner kind;
  - `kubectl explain helmreleaseproxy.spec`;
  - `tar -t` on the product catalog bundle;
  - `ls`.

  Outside the AGENTS.md list, I ran `kubectl api-resources` (license kind) and `command -v jq yq python3`. Both are harmless, and I report them here. I did no dry run, and I read no Secret value.

**Verdict: go-with-changes.** 0 BLOCKER, 4 MAJOR, 19 MINOR.

The three skills are careful. They mark the gaps honestly with UNKNOWN lines, and they use the live lab well. Examples of good work:
- The flow I3 `yq` step is right (details in "Commands, flags, and facts checked").
- The flow HCP uses the CAREN chart server (live `tags/list` shows `1.1.0`), so a dark site needs no chart push.
- The vpc 2-floating-IP decision (N-06) is right and is well argued from live evidence.
- The NDK chart traps (SECRET + `clusterName`, top-level `serviceMonitor`, `ndk-image-pull-secret`) are all correct in the chart source.
- N-04 is consistent in all three skills (`flow SKILL.md:79`, `egress-vpc.md:16`, `layouts.md` L5): do not combine nodes on a VPC overlay subnet with Flow CNI.

The main defects:
- The flow server dry run does not show whether a webhook adds `addons.cni` back. A missed Cilium means a cluster delete (M1).
- vpc step 2 writes `SUBNET` to the site file. That changes the node subnet of every other cluster (M2).
- The vpc Docker MTU step can replace `/etc/docker/daemon.json` with `{"mtu":…}`, as root and with no backup (M3).
- The NDK file-write CHANGES blocks have no plan and no stop text (M4).

## 1. BLOCKER

None.

## 2. MAJOR

**M1. Flow path A: the server dry run does not check that `addons.cni` stays removed after the defaulting webhooks.**
- Files: `skills/nkp-flow-cni/references/install.md:157-167` (I5), `:68` (N-31).
- Evidence: the management cluster has mutating webhooks on `clusters` (`addons-defaulter.caren.nutanix.com`, `cluster-defaulter.caren.nutanix.com`) and `nkp-cluster-defaulting` [live, `get mutatingwebhookconfigurations`]. The ClusterClass schema has no default for `addons` or `addons.cni` [live, `status.variables` jsonpath]. But a webhook default is not visible in the schema. I5 prints only `-o name`. So it cannot show a `cni` that a webhook adds.
- Effect: if a webhook adds Cilium back, the create installs Cilium and Flow CNI together. The CNI cannot change on a running cluster, so the user must delete the cluster and create it again (`SKILL.md:165`).
- Fix: in I5, print the defaulted addon keys. The output then holds only key names, not Secret data:

  ```bash
  # READ-ONLY  (server dry run: changes nothing; prints only the addon names)
  source ~/nkp-<cluster>.env 2>/dev/null
  kubectl --kubeconfig "$MGMT_KUBECONFIG" apply --server-side --dry-run=server -f "$PWD/$CLUSTER_NAME-dryrun.yaml" -f "$PWD/$CLUSTER_NAME-flow-cni-hcp.yaml" -o yaml | yq 'select(.kind == "NKPCluster" or .kind == "Cluster") | (.spec.capiCluster.topology // .spec.topology).variables[] | select(.name == "clusterConfig") | "addons: " + (.value.addons | keys | join(","))'
  ```

  Done when: no `addons:` line has `cni`. A `cni` there answers N-31: stop and tell the user. Also run the `-o name` form first. A list of objects with `-o yaml` can come back as a `List`; then add `.items[]` to the expression, and check this once on the lab.

**M2. vpc step 2 tells the agent to append `SUBNET` to `~/nkp-site.env`. For a workload cluster, that changes the node subnet of the management cluster and of all other clusters.**
- Files: `skills/nkp-vpc/SKILL.md:39`, `:88`; `references/layouts.md` L1 (mixed, shared, per-tenant layouts); `evals/nkp-vpc.md` V7.
- Evidence:
  - ADR 0003 (amendment 2026-11-02) moved cluster values to the cluster env file because "the last line wins" replaced the management values.
  - `nkp-install` `nutanix.md` N5 step 2 says "Do not change `~/nkp-site.env`: the management cluster values stay there."
  - `SUBNET` is a site variable. `nkp-cluster-lifecycle` uses `"$SUBNET"` for new node pools (`SKILL.md:212`).
- Effect: in the layouts that L1 teaches (a VLAN management cluster with a workload cluster in a VPC, or one VPC for each tenant), the second cluster replaces `SUBNET` for all. A later node pool on the management cluster then goes to the overlay subnet of the tenant.
- Fix: in `:39` and `:88`, write: "For the management cluster, append `SUBNET` to `~/nkp-site.env`. For a workload cluster, append `SUBNET` (the overlay subnet) to its cluster env file. That file sources the site file first, so its line wins for this cluster only." Do the same for `PE_CLUSTER` and `STORAGE_CONTAINER` when they differ. Add the expectation to V7.
- `nkp-install` N5 has the same gap for any workload cluster on another subnet. Tell the owner (section 5).

**M3. The vpc Docker MTU block can replace `/etc/docker/daemon.json` with only `{"mtu":…}`, as root, with no backup.**
- File: `skills/nkp-vpc/SKILL.md:122-127`.
- Evidence: `{ [ -s "$f" ] && cat "$f" || echo '{}'; } | jq … | sudo install …` reads the file as the user. When the file is not readable by the user (mode 600 or 640), `cat` fails, `|| echo '{}'` runs, and the new file has only `mtu`. I tested this with a mode-000 file that held `data-root`: the output was `{"mtu":1442}`.
- Effect: the change silently removes these keys: `data-root` (Docker then starts with an empty image store), registry mirrors, `insecure-registries`, log options, and proxies. It removes them with sudo and leaves no copy. Also, the restart stops all containers. The text checks only for a bootstrap cluster. A site registry container on the bastion (common on dark sites) also stops.
- Fix:

  ```bash
  # CHANGES  (sets the Docker MTU to the NIC MTU in /etc/docker/daemon.json and restarts Docker)
  dev=$(ip route show default | awk '{print $5; exit}'); mtu=$(cat "/sys/class/net/$dev/mtu"); : "${mtu:?}"
  f=/etc/docker/daemon.json; t=$(mktemp)
  if sudo test -e "$f"; then sudo cp -p "$f" "$f.bak" && sudo cat "$f" | jq --argjson m "$mtu" '.mtu = $m' > "$t"; else echo '{}' | jq --argjson m "$mtu" '.mtu = $m' > "$t"; fi && sudo install -m 644 "$t" "$f" && rm -f "$t" && sudo systemctl restart docker
  ```

  In the text before the block, write: "First run `docker ps`. If any container runs (a bootstrap cluster, a registry), stop and ask the user. The restart stops all containers." Add `jq` to the needs. The file is at 250 lines: make room with minor 14 (move the step 6 "Change `FIP_API`" paragraph to `layouts.md`).

**M4. NDK: 10 CHANGES blocks that write a file have no plan and no stop for "yes".**
- Files:
  - `skills/nkp-ndk/SKILL.md:194` (StorageCluster);
  - `references/protect.md:27` (Application), `:59` (snapshot), `:130` (ReferenceGrant + restore), `:239` (ndkcli);
  - `references/replication.md:50` (Remote), `:75` (ReplicationTarget), `:90` (replication);
  - `references/operations.md:22` (alert copy), `:65` (UI values).
- Evidence: rule 2 is for every CHANGES block. The other blocks in the same files say "Show the file and the plan, stop for "yes"" (for example `SKILL.md:154`, `replication.md:181`), and so do flow and vpc. Step 5 (`SKILL.md:206`) gates only the apply, not the write. The general FAIL list of the evals counts a CHANGES block that runs without "yes".
- Effect: a small model sees a pattern (gate on some blocks, no gate on others) and runs the write blocks with no "yes". The eval then fails.
- Fix: one sentence at the top of step 5, and the same sentence in the first line of `protect.md` and `replication.md`: "Each write block is CHANGES. Before you run it, show the values and the file path, and stop for "yes" (rule 2). Then do the dry run, show the plan again, and stop for "yes" before the apply." Add "Show the plan, stop for "yes":" before each of the 10 blocks.

## 3. MINOR

1. **Wrong tag** (`vpc SKILL.md:83`). "Associate `FIP_API` with the private IP `CP_VIP` and `FIP_UI` with the first IP of `LB_IP_RANGE` [pdf p.720-721]": p.720-721 tells you to associate only the floating IP of the API (with the control-plane IP). The UI floating IP there is "one IP for the UI", with no target. Fix: `… with the private IP CP_VIP [pdf p.720-721] and FIP_UI with the first IP of LB_IP_RANGE [portal][live 2.19.0]`.
2. **The connected NDK catalog URL has a `[live 2.19.0]` tag that it does not have** (`ndk SKILL.md:129`).
   - The lab has no product catalog OCIRepository [live, `get ocirepositories -A`]. The URL comes from the bundle repository path.
   - The public `collection:2.19` is mutable. On 2026-11-03 its digest is `da5d4ff4…`, but the bundle copy is `885192b6…` (`tar -t`). The public copy now lists `nutanix-ai` 2.8.0 and 2.8.1, `kserve` 0.19.0, `envoy-gateway-nai` 1.8.2, `opentelemetry-operator` 0.114.1, `leaderworkerset` 0.8.0, and `ndk` 2.3.0 [field, crane].
   - Fix: tag the URL `[field]`. Add "a connected catalog can list more apps than NDK; enable only `ndk`".
   - Cross-skill: this is new evidence for D-45 (NAI source) in gpu-ai.
3. **The Remote write block makes a wrong file and does not stop** (`replication.md:52-63`). I tested it:
   - `tls=ca` with an empty `ca_file`: the `${ca_file:?}` inside `$(…)` exits only the subshell, and the file gets `caBundle:` empty. The return code is 0.
   - `tls=bogus`: the block prints "bad tls", still writes a file with no TLS, and returns 0.
   - `tls=off` with `mtls_secret`: the YAML is not valid.

   A Remote spec cannot change (see minor 4), so a wrong Remote must be deleted. Fix: before the brace, add `case "$tls" in off|skip) ;; ca) : "${ca_file:?}" ;; *) echo "bad tls"; exit 1;; esac; [ -n "$mtls_secret" ] && [ "$tls" = off ] && { echo "mTLS needs TLS"; exit 1; }`.
4. **The immutable list is not complete** (`ndk SKILL.md:222`, `operations.md` X5 row "Spec is immutable"). The chart CRDs also make these immutable:
   - the spec of `Remote`, `ReplicationTarget`, and `StorageCluster` ("Spec is required and immutable");
   - all of `ApplicationSnapshotReplication` ("Resource is immutable");
   - `AppProtectionPlan.spec.applicationName`.

   Add them. R2/R3 "Not `True`": the fix is to delete the object and make it again (CHANGES).
5. **JobScheduler minimum** (`protect.md` P5, `replication.md` R5). The CRD says that `interval.minutes` "Should be an integer value greater than 60. Interval schedules lower than 60 minutes are not allowed." Add "`interval_min` is 60 or more [live 2.19.0 CRD]". The dry run probably does not reject a lower value (it is a description, not a schema minimum).
6. **The NDK UI values do not reach the override** (`operations.md:62-89`). X3 writes `$HOME/$CLUSTER_NAME-ndk-ui-values.yaml`, but O3 items 2-4 read `$HOME/$CLUSTER_NAME-$APP_ID-values.yaml` = `…-ndk-values.yaml`. So item 5 applies the TLS file without the UI, or finds no file. Fix:
   - Set `f="$HOME/$CLUSTER_NAME-ndk-values.yaml"`. When the file exists, append with `>>` (one app, one override file).
   - In item 2, use `htpasswd -nBC 10 ""`. It prompts for the password, so the password is not in the shell history (the guide uses `-b` with the password in the command).
7. **The flow E2 text about an existing Service IP is wrong, and N-35 has an answer** (`egress-vpc.md:82, 92, 96`).
   - MetalLB v0.15.3 reads only `metallb.io/address-pool` (and the old `metallb.universe.tf/address-pool`) (`controller/service.go:34,41,137`).
   - When the requested pool is not the current pool, MetalLB clears the IP and gives a new one (`:134-141`). So "A Service that already has an IP from another pool keeps it" is wrong: the annotation changes the IP of the Service.
   - Fix: remove `metallb.io/ipaddresspool=…` from the block. Close N-35 (`[field: MetalLB v0.15.3 source]`). In the step 5 plan, say "the Service gets a new IP from the pool; clients of the old IP stop working".
8. **The I4 guards miss `null`** (`install.md:97-98`). `yq` prints `null` for a missing path, and `: "${pod:?}"` accepts it. I tested it: `podNetwork` then becomes `null/24`. `CP_VIP` has no guard. Fix: `[ "$pod" != null ] && [ "$svc" != null ] || { echo "no CIDRs in the dry-run file"; exit 1; }; : "${CP_VIP:?}" "${CLUSTER_NAME:?}" "${WORKSPACE_NS:?}"`.
9. **The HCP and the HelmReleaseProxy hold the pull token** (connected mode). Step 4 reads them safely (conditions, custom columns). Add one line after `install.md:147`: "Never read the HCP or its HelmReleaseProxy with `-o yaml` or `describe`: the values hold the token (rule 5)."
10. **The token row of Common failures applies too much** (`flow SKILL.md:167`). "write the HCP again (I4), then apply it": I6 applies the dry-run file and the HCP file, and I7 can delete the dry-run file. Write: "then apply only the HCP file: `kubectl --kubeconfig "$MGMT_KUBECONFIG" apply --server-side -f "$PWD/$CLUSTER_NAME-flow-cni-hcp.yaml"` (CHANGES, plan, "yes")".
11. **Broken references and inline commands with unset values** (flow `egress-vpc.md`).
    - `:3` says "step 5": SKILL.md has no step 5. Point to the Job → section table.
    - The inline commands at `:47`, `:81`, `:82` use `$name`, `$ns`, `$svc`, which a new bash does not have. Write "put the name in place of `$name`", as `protect.md:230` does, or make them blocks.
    - The same applies to `replication.md:190` (`$ns`).
12. **Two flow CHANGES lines have weak gate text.** `install.md:183` "ask the user if they want to keep them … or delete them" is a question, not a plan and a stop. Write "Show the plan (the three files), stop for "yes"". `SKILL.md:158` has an inline `kubectl … delete helmchartproxy` with no `source` line. Make it a block with line 1 `# CHANGES` and line 2 `source …`.
13. **The vpc READ-ONLY block can print a proxy password** (`vpc SKILL.md:115`). `cat /etc/docker/daemon.json` prints all keys. Docker allows `proxies.http-proxy`, and a proxy URL can hold a password (batch 2 fact, `proxy.md` X0). Use `jq -r '"daemon.json mtu: " + ((.mtu // "none")|tostring)' /etc/docker/daemon.json 2>/dev/null || echo "no daemon.json"`.
14. **Format.**
    - `vpc SKILL.md:91-92`: the block sources the cluster file but uses no cluster variable. Rule 3 then asks for `source ~/nkp-site.env 2>/dev/null`.
    - The file is at exactly 250 lines. To stay in the limit, the author removed the blank lines before `## Step 2` (:76), `## Step 3` (:101), `## Step 4` (:140), `## Common failures` (:234), and `## Related skills` (:248).
    - At `:198-199`, `**Another LoadBalancer Service…**` joins the previous paragraph. Put a blank line back there. To gain lines, move the step 6 "Change `FIP_API`" paragraph to `layouts.md`.
15. **vpc copies facts from networking** (ADR 0001).
    - `:47` (`--extra-sans` adds API certificate names) and `:48` (the NKPCluster ingress field) restate networking `SKILL.md` step 3 and `ingress-certs.md` I1.
    - Step 6 copies the I3 patch pattern (hostname only).
    - Keep the VPC-specific live facts (the external endpoint is in the SANs, `CP_VIP` is not). Point to networking for the field and the flag.
    - Better: networking gets a "hostname only" variant in I3, and vpc points to it.
    - Cross-skill: networking `cni.md` C5 also states the VPC MTU 1442/1392. Keep only its pointer to `nkp-vpc`.
16. **N-40 has partial evidence.** The upstream kind (`network.go:66-70,163-175`) makes the `kind` network with the MTU of the Docker default `bridge` network. If `nkp create bootstrap` uses kind's network code, the `daemon.json` fix is enough for a new `kind` network. Add this as `[field: kind source]` to N-40. The re-create block stays for an old network.
17. **Evals.**
    - `nkp-ndk.md` K6 expects the model to "quote D-03". D-03 is in no skill (grep), so rule 6 does not let the model quote it. Expect "not in the skills" with a READ-ONLY check, or add D-03 as an "open item, no check command" line, as F-09 in flow.
    - The general FAIL of `nkp-ndk.md:5` ("an NDK object in `ntnx-system` other than the pull Secret and the TLS Secrets") fails K5: the alert `PrometheusRule` is in `ntnx-system`. Add it to the exceptions.
    - The eval ID prefixes are used twice: flow `L1-L7` and lifecycle `L1-L8`; ndk `K1-K7` and kubernetes-core `K1-K8`. NEXT-STEPS already names "L1" for a re-run. Use `F` (flow) and `D` (data) or similar. The rename is optional, because G and S are already used twice.
    - V7 must check the `SUBNET` place after M2.
18. **Lab method outside AGENTS.md.**
    - The ndk author used `tar -xOf` on bundle blobs and copied the chart tgz to the laptop (`ndk-chart.txt:3`). AGENTS.md allows only `tar -t`.
    - The vpc author used `openssl s_client`, `curl -sk`, `ip`, and `docker network inspect` on the bastion (`vpc.txt:4-5`).

    All of these are read-only and print no secret, and I judge only the findings. The ndk findings are valid: the bundle chart has the same digest as `ghcr.io/mesosphere/charts/ndk:2.3.0`, and I read that chart and found the same values, templates, CRDs, and precheck messages. The vpc findings agree with each other (SANs, `cluster-info`, Cilium env, curl codes). Fix: extend the AGENTS.md list (`tar -xO` to stdout, `curl -sk -o /dev/null -w '%{http_code}'`, `openssl x509` of a public certificate, `ip`, `docker … inspect`), or tell authors to stop at the list.
19. **Small version facts copied in NDK** (`SKILL.md:39`, `:95`, `:106`): cert-manager 1.20.3, CSI 3.9.0, Gateway API v1.3.0 and `gateway-api-crds`. The airgap `prestage.md` "In the bundle" table also has the ReferenceGrant fact. These drift at each release. Keep the NDK minimums (cert-manager ≥ 1.13, CSI ≥ 3.7.1) and the step 1 read. Remove "(1.20.3 on 2.19.0)" and "(3.9.0 on 2.19.0)", or keep them and accept the refresh cost.

## 4. Commands, flags, and facts checked

| Claim | Result | Evidence |
|---|---|---|
| Flow I3 `yq` deletes `addons.cni` for `NKPCluster` and `Cluster` | correct | yq v4.47.1 on a synthetic file with a Secret, an NKPCluster (`clusterConfig` at index 1), and a Cluster: `cni` removed in both, other addons and the Secret unchanged, mode 600 kept |
| Flow I3 check and I4 CIDR reads | correct; `null` not guarded | the same test (minor 8) |
| Flow chart `nutanix-flow-cni` 1.1.0 on the CAREN chart server, port 443 | correct | `flow-cni.txt:56-59`; Service `helm-repository` port 443 [live] |
| ClusterClass in each workspace namespace | correct | lab: `nkp-nutanix-v2.19.0` in `default`, `kommander`, `kommander-default-workspace` |
| Only the AHV class allows `Flow` | correct | `clusterclass-cni-enum.txt` |
| CAREN addon HCPs are owned by the Cluster; a user HCP has no owner | correct | lab: all 10 HCPs `ownerReferences[0].kind=Cluster` |
| HelmReleaseProxy columns (`clusterRef`, `chartName`, `version`) | correct | lab `explain helmreleaseproxy.spec` |
| `konnector-agent` in `ntnx-system` | correct | lab |
| vpc 2 floating IPs (N-06) | correct | `vpc.txt:9-28`: the API cert SANs have the floating IP, `extraAPIServerCertSANs` empty, `kommander-traefik-tls` `ipAddresses` = the UI floating IP; p.721 asks for 3 (bastion, `--extra-sans`, UI) |
| vpc: patch the NKPCluster, not the KommanderCluster | correct | lab: KommanderCluster `ownerReferences` kind `NKPCluster`; `vpc.txt:53-56` dry runs; same as networking I3 |
| vpc: nodes and Cilium use the external endpoint | correct (inferred) | `vpc.txt:44-49`: CAPI `controlPlaneEndpoint`, `cluster-info`, Cilium `KUBERNETES_SERVICE_HOST` |
| vpc: `api 200`, `ui 302` | correct | `vpc.txt:33-34` |
| vpc Docker MTU block | data-loss path | M3 (tested) |
| NDK bundle: chart, catalog, all six images, so the `catalog-bundle` build is not needed | correct | `bundle-images.txt:409-418`: `mesosphere/charts/ndk:2.3.0`, `collection:2.19`, `ndk:2.3.0`, and the six image repositories that the chart `values.yaml` names (`ndk-manager`, `ndk-infra-manager`, `ndk-job-scheduler`, `ndk-ui`, `kube-rbac-proxy`, `kubectl`); chart digest in the bundle = upstream |
| `ndk-image-pull-secret` always in `imagePullSecrets`; Secret made only with `credentials.username` | correct | chart `deployment.yaml:44-47`, `image-pull-secret.yaml:1` |
| SECRET + `clusterName` fails; `clusterName` required for `SELF_SIGNED`/`ISSUER` | correct | `manager-config.yaml:36-38`, `cert-manager.yaml:54` |
| top-level `serviceMonitor.customLabels` | correct | `controller-manager-metrics-monitor.yaml` reads `.Values.serviceMonitor`; `values.yaml` puts it under `prometheus` |
| NDK webhooks `sideEffects: None` | correct | `webhook-certificate.yaml` (10×) |
| No port 347 | correct | grep of the chart |
| CRD printer columns that the "Done when" lines use | correct | the 19 CRDs (shortnames `as`, `asr`, `appsnaprep`, `pplan`, `appplan`, `haa`, `nsp`, `pfo`, `upfo`) |
| Immutable specs | incomplete | minor 4 |
| JobScheduler interval | minimum not stated | minor 5 |
| NDK alert asset: 12 rules, labels `prometheus: k8s`, `role: alert-rules`, group `ndk-snapshot-failure-rules` | correct | `nkp-airgap/assets/ndk-alert-config.yaml` |
| MetalLB pool annotation | `metallb.io/address-pool` | minor 7 |

Scrub: the diff has no IP except documentation and default ranges (`192.168.0.0/16`, `10.96.0.0/12`, `192.0.2.x`). It has no lab host name, cluster name, UUID, user, or token. The live files use `<mgmt-cluster>`, `<ovl-ip-N>`, `<ext-ip-N>`, `<ip>`. `grep -ci` for the lab names in the diff gives 0.

Line limits: flow 175, vpc 250 (at the limit), ndk 242; reference files 76-260. All are in the limits.

Evals: all three files use the `nkp-install` format (prompt, expected, "FAIL if"), and each has 7 evals. Approval gate: flow L4, vpc V3, ndk K2. Fact not in the skills: flow L7, vpc V6, ndk K6 (K6 needs the fix in minor 17).

## 5. Cross-skill changes

| Change | Owner | Note |
|---|---|---|
| A workload cluster on another subnet: put `SUBNET` (and `PE_CLUSTER`, `STORAGE_CONTAINER` if they differ) in the cluster env file | nkp-install (`nutanix.md` N5 step 2) | M2; the same gap as vpc |
| Hostname-only ingress patch variant | nkp-networking (`ingress-certs.md` I3) | minor 15; then vpc step 6 points to it |
| `cni.md` C5: keep only the pointer for the VPC MTU | nkp-networking | minor 15 |
| `metallb.md`: confirm `metallb.io/address-pool`, and that a pool annotation change gives the Service a new IP | nkp-networking | minor 7 (MetalLB v0.15.3 source) |
| D-45: the public `nkp-nutanix-product-catalog/collection:2.19` now lists `nutanix-ai` 2.8.0/2.8.1 and its dependencies; the 2.19.0 bundle copy has another digest | nkp-gpu-ai, OPEN-ITEMS | minor 2 |
| AGENTS.md lab command list | parent | minor 18 |

## 6. Top fixes, in order

1. M3: the Docker `daemon.json` block (a root file, no backup).
2. M2: the `SUBNET` place for workload clusters (vpc and nkp-install).
3. M1: the addon check after the defaulting webhooks in the flow dry run.
4. M4: the gate text on the NDK write blocks.
5. Then the minor items, in this order: 3, 4 (the Remote is immutable), 7, 8, 9, 13 (secrets and wrong facts), 6, 10, 12, 17, then the rest.

Then run the check script. Run evals V1, V2, V7, L2, K4, and K5 again, plus a new eval for a second workload cluster in another VPC (M2).

Not checked:
- I did not run the evals.
- No Flow CNI, VPC create, or NDK install exists on the lab. So M1, N-31, N-32, F-03, D-50, D-02, and the whole replication path depend on the guide, the chart, and the CAREN schema, not on a running cluster.
- I could not read the CAREN v0.62.7 webhook source (the public repository ends at v0.50.0). So M1 is a risk, not a seen fault.
- I did not read the portal pages (TN-2207, Flow guide 7.6, NDK 2.3 guide), so the `[portal]` facts are not checked.
