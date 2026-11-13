# t3-mgmt-nkp-mgmt-01 — create the NKP 2.19.0 management cluster `nkp-mgmt-01` and license it (Pro/Ultimate)

Operator host `<bastion>`; Prism Central `<pc>`. Skills followed: `nkp-install` (`SKILL.md` + `references/nutanix.md`), case **N4C** (site registry mirror); then `nkp-identity-security` section **License**, method B (`kubectl`).
Starter granted by the session brief: standing approval for every CHANGES block in this task. `<old-mgmt-cluster>` files, the Harbor registry, PC and PE settings untouched. `nkp get dashboard` not run (USER-TERMINAL, task says not to).

**Status: done.** Create RC=0 in 22 min 39 s. Verify and N6 pass. License: tier `Ultimate`, `valid=true`.

## 1. Operator host + env files

- `~/nkp-site.env` (600) has all site values and secrets, incl. `NKP_LICENSE_KEY`. Its `MGMT_KUBECONFIG` line pointed to the **deleted** `/home/ubuntu/skilltest-mgmt-01.conf` (known before the run; rule 4 "last line wins" fixes it after the create).
- CHANGES block 1 (SKILL.md "Prepare the env files" steps 2 and 3): made `~/nkp-nkp-mgmt-01.env` (600) with `source ~/nkp-site.env`, `CLUSTER_NAME='nkp-mgmt-01'`, `CP_VIP='<net>.50'`, `LB_IP_RANGE='<net>.51-<net>.55'`, `WORKSPACE_NS='kommander'`.
- SKILL.md "Check the operator host": `nkp v2.19.0`, docker 29.9.2, kubectl client v1.37.2, `cgroup2fs`, 16 CPU, 29 GB available, 849 G free on `/`. All checks pass.

## 2. N2 — env file check (READ-ONLY)

```text
set: syntax
set: CLUSTER_NAME CP_VIP LB_IP_RANGE WORKSPACE_NS PC_ENDPOINT PE_CLUSTER SUBNET STORAGE_CONTAINER VM_IMAGE SSH_PUBKEY_FILE NUTANIX_USER NUTANIX_PASSWORD   (all 12)
case 4C block: set: NTP_SERVERS BUNDLE_DIR REGISTRY_URL REGISTRY_CA_FILE
mirror credentials block: set: REGISTRY_MIRROR_USERNAME REGISTRY_MIRROR_PASSWORD
NKP_LICENSE_KEY: set:
```

## 3. N3 — infrastructure check (READ-ONLY)

```text
nkp: v2.19.0   (catalog v0.11.1, diagnose v0.14.0, kommander/konvoy v2.19.0)
pc_http=302
ping <net>.50 → 100% packet loss (VIP free)
ssh key file found
/home/ubuntu/nkp-v2.19.0/konvoy-bootstrap-image-v2.19.0.tar
registry CA file found
```

## 4. Create script — N4C + `--insecure` + `--timeout 60m` (CHANGES)

`~/nkp-nkp-mgmt-01-create.sh` (1146 bytes, 700) = the N4C block verbatim, with `--insecure` and `--timeout 60m` as lines before `"$@"`. Reason for `--insecure`: the PC certificate is self-signed with no SAN and `PC_CA_FILE` is not set, so the `${PC_CA_FILE:+--additional-trust-bundle ...}` line adds nothing (confirmed: no `additionalTrustBundle` in the dry run).

## 5. N4D — dry run (CHANGES, writes `~/nkp-mgmt-01-dryrun.yaml`)

rc 0 in **3 min 09 s** (04:23:03 → 04:26:12). It creates a kind bootstrap cluster, installs CAPI, runs the preflight checks (passed), prints the objects, and deletes the bootstrap cluster. [live 2.19.0]

`grep -n -E '^kind:|^  name:|image:|host:|addressRanges:|start:|end:|url:'` — the lines N4D asks to show:

```text
4:kind: Secret
10:  name: nkp-mgmt-01-pc-credentials
17:kind: Secret
23:  name: nkp-mgmt-01-pc-credentials-for-ccm
30:kind: Secret
36:  name: nkp-mgmt-01-pc-credentials-for-csi
44:kind: Secret
50:  name: nkp-mgmt-01-pc-credentials-for-konnector-agent
59:kind: Secret
64:  name: nkp-mgmt-01-image-registry-mirror-credentials
75:kind: Secret
80:  name: global-nutanix-credentials
85:kind: NKPCluster
89:    kommander.d2iq.io/host: "true"
92:  name: nkp-mgmt-01
157:                addressRanges:
158:                - end: <net>.55
159:                  start: <net>.51
173:                image:
192:            url: https://<registry-host>/nutanix
200:              host: <net>.50
209:              url: https://<pc>:9440
238:                    image:
256:kind: ConfigMap
263:  name: kommander-bootstrap-configuration
270:kind: Secret
275:  name: prism-central-metadata
```

7 Secrets, NKPCluster `kommander/nkp-mgmt-01` with `kommander.d2iq.io/host: "true"`, MetalLB `<net>.51-<net>.55`, KubeVIP `<net>.50`, mirror URL, PC endpoint, `insecure: true` (both in the PC credentials Secret, base64 `dHJ1ZQ==`, and in the worker config).

## 6. Create (CHANGES) — RC=0

tmux `mk`, from `$HOME`, log `~/nkp-mgmt-01-create.log` (600). **04:26:23 → 04:49:02 = 22 min 39 s** (the previous run of the same script took 24 min).

| Phase | Time | Note |
|---|---|---|
| bootstrap image + kind + CAPI + ClusterClass + NKPCluster | 04:26:23 → 04:29:18 | preflight passed |
| create cluster / wait infra (04:30:08) / wait CP | → 04:31 | |
| kubeconfig written | 04:32 | `$HOME/nkp-mgmt-01.conf`, 5558 bytes, 600 |
| ManagementPlane + KommanderCore + Gatekeeper + AppManagement | 04:36 → 04:39:35 | moved (pivot) before 04:36 |
| 14 core apps: 0 → 7 (04:44:34) → 11 (04:45:07) → 13 → 14 | → 04:49:02 | last app `traefik-forward-auth-mgmt` |
| last line | 04:49:02 | `Cluster was created successfully! ... nkp get dashboard --kubeconfig="/home/ubuntu/nkp-mgmt-01.conf"` |

## 7. Kubeconfig variables (SKILL.md step)

`ls -l ./nkp-mgmt-01.conf` → present (written at 04:32, i.e. 17 min before the create ended). CHANGES: appended `MGMT_KUBECONFIG='/home/ubuntu/nkp-mgmt-01.conf'` to `~/nkp-site.env` (line 2 for that name; the stale `skilltest-mgmt-01.conf` line stays above it) and `CLUSTER_KUBECONFIG` to `~/nkp-nkp-mgmt-01.env`. `test -f "$MGMT_KUBECONFIG"` → exists, blocks resolve to the new path.

## 8. Kommander check + Verify (READ-ONLY)

- `kommander-flux` namespace Active; 24 HelmReleases in `kommander`, all `True` → Kommander OK, `references/kommander.md` not needed.
- 7 nodes Ready (`v1.36.2`): 3 CP + 4 workers.
- `nkp describe cluster`: every `Machine/` READY `True`; `Cluster/` and `ControlPlane` READY column empty (as the skill says).
- NKPCluster `nkp-mgmt-01` PHASE `Reconciled`, NKP v2.19.0, k8s v1.36.2.
- HelmRelease wait: all `condition met`. Pod wait: `condition met` (145+ pods).
- `get pods --field-selector=status.phase!=Running,status.phase!=Succeeded` → nothing (the "No resources found" line arrives on stderr, out of order over ssh; the block still passes).

## 9. N6 — Nutanix checks (READ-ONLY)

```text
nutanix-volume (default)   csi.nutanix.com   Delete   WaitForFirstConsumer   true   22m
IPAddressPool metallb  ["<net>.51-<net>.55"]  autoAssign true
ntnx-system: konnector-agent 1/1, 2× nutanix-csi-controller 8/8, 7× nutanix-csi-node 3/3 — all Running (2 restarts on 2 nodes early)
cilium: 7 pods 1/1 Running
kommander-traefik  LoadBalancer  <net>.51  (first IP of LB_IP_RANGE)
```

## 10. License — method B (kubectl)

Before: `tier=Starter valid=true`, `spec={}`, `status={"clusterCapacity":0,"coreCapacity":0,"customerId":"","dkpLevel":"Starter","licenseId":"","productName":"NKP","productSKU":"","valid":true,"version":""}`. Workers 4 × 8 CPU / 32 GiB.

- Webhook gate (AGENTS.md rule): every validating/mutating webhook on the cluster has `sideEffects: None` or `NoneOnDryRun`, so the server dry run is allowed. `kommander-licensing-validating` → `None`.
- CHANGES: `create secret generic nutanix-license-secret --from-file=nutanix-license-key=<(...)` → `secret/nutanix-license-secret`.
- READ-ONLY server dry run of the patch, masked: **passes** → `{"nutanixLicenseRef":{"name":"nutanix-license-secret"}}`. No webhook denial, so the key matches this cluster name (the previous run proved a wrong-name key is denied by `webhook.licensing.kommander.mesosphere.io` and **echoes the whole key** in the error).
- CHANGES patch at 04:53:15 → `license.kommander.mesosphere.io/nutanix-license patched`. 15 s later: **`tier=Ultimate valid=true`**.

**P-40 answered** — a Pro/Ultimate (trial) key fills exactly two status fields; everything else stays empty:

```json
{"clusterCapacity":0,"coreCapacity":0,"customerId":"","dkpLevel":"Ultimate","endDate":"2028-10-31T00:00:00Z","licenseId":"","productName":"NKP","productSKU":"","valid":true,"version":""}
```

- new fields vs Starter: `dkpLevel` Starter→Ultimate and a new `endDate` (ISO timestamp, here 2028-10-31 = the trial end).
- **`coreCapacity` and `clusterCapacity` stay `0`**, `customerId`, `licenseId`, `productSKU`, `version` stay empty, `productName` stays `NKP`. No status field holds the key or any license secret.
- `spec` = `{"nutanixLicenseRef":{"name":"nutanix-license-secret"}}`, generation 2.
- The Full Stack note: `secret/prism-central-metadata` already exists on the cluster (made by `nkp create cluster`, seen in the dry run) — that step was not needed.

## 11. Apps of the new tier (READ-ONLY)

Counts, before → after:

| Object | before | after |
|---|---|---|
| HelmReleases in `kommander` | 24 | **48** |
| HelmReleases `-A` | 26 | **50** |
| AppDeployments `kommander` | 22 (all ns) | **36** (45 `-A`, 9 are `kommander-default-workspace` copies) |

Rollout timing: first wave Ready 04:57:59 (4 min 44 s after the patch); a "stable" 46 HRs at 04:57:59, then `cosi-driver-ceph-dkp-object-store` + `object-bucket-claims` appeared and `velero` + `grafana-loki-v3` reinstalled → **all 50 Ready at 05:04:17 (11 min after the patch)**. Recommend waiting ≥ 15 min and rechecking, not "tier is set, done".

**24 new HelmReleases (the Ultimate set on an AHV management cluster):**

```text
observability/logging:  kube-prometheus-stack  prometheus-adapter  thanos  centralized-grafana  centralized-opencost
                        opencost  karma  karma-traefik  prometheus-thanos-traefik  grafana-logging
                        grafana-loki-v3  logging-operator  logging-operator-logging
object storage (Ceph):  rook-ceph  rook-ceph-cluster  cosi-driver-ceph-dkp-object-store  object-bucket-claims
data/backup:            cloudnative-pg  cloudnative-pg-plugin-barman-cloud  velero
UI/insights/network:    headlamp  nkp-insights-management  kubetunnel  cilium-hubble-relay-traefik
```

(`cert-manager`, `dex`, `gatekeeper`, `traefik*`, `kommander*`, `kubefed`, `kube-oidc-proxy`, `external-secrets`, `reloader`, `cluster-*` were already there.)

Worker pressure after the tier install (no pressure conditions, no Pending pods, all 45 PVCs Bound):

| worker | CPU requests | CPU limits | memory requests |
|---|---|---|---|
| md-0-…-gjznp | 5437m (**67%**) | 15200m (190%) | 8970644736 (26%) |
| md-0-…-h4g6m | 6875m (**85%**) | 8750m (109%) | 10759Mi (33%) |
| md-0-…-hc7wq | 7210m (**90%**) | 15400m (192%) | 12378Mi (38%) |
| md-0-…-xwq8h | 7865m (**98%**) | 16450m (205%) | 15740Mi (49%) |

`kubectl top nodes` works (metrics-server came with the tier): CP 8–16% CPU, workers 4–18% CPU, ~12–14% memory.

## Learnings

1. `[fact]` **P-40 is answered** — a Pro/Ultimate key fills only `.status.dkpLevel` and adds `.status.endDate`. `clusterCapacity`, `coreCapacity`, `customerId`, `licenseId`, `productSKU`, `version` all stay empty/0, even at `valid=true` with 4 workers. Close P-40 and put this JSON in the skill.
2. `[nkp-skill nkp-identity-security/SKILL.md License, UNKNOWN (P-40)]` The text says the lab is Starter so "all other fields are empty". Replace the UNKNOWN with the measured answer above, and say plainly that `licenseId`/`coreCapacity`/`clusterCapacity` stay empty with a **trial** key (a paid key may differ — keep that as the residual unknown).
3. `[nkp-skill nkp-identity-security/SKILL.md License]` "Done when: `valid=true` and the new tier" is too weak. Measured: the tier flips in **15 s**, but the tier's apps keep landing for **11 min**, and four more HelmReleases (`cosi-driver-ceph-dkp-object-store`, `object-bucket-claims`, `velero`, `grafana-loki-v3`) appeared 5–8 min *after* a first "every HelmRelease Ready" snapshot. Add: after the tier change, `kubectl get helmreleases -A` every 60 s until no object is non-Ready **twice in a row, ≥15 min apart**, and expect ~11 min. Quote the Starter 24 → Ultimate 48 HelmRelease counts as the expected end state.
4. `[nkp-skill nkp-identity-security/SKILL.md License]` The skill's pre-check block lists node **allocatable** CPU/memory, which does not show how full the workers are. Add `kubectl --kubeconfig "$MGMT_KUBECONFIG" describe nodes | grep -A6 'Allocated resources'` to the plan block, and give the measured numbers: on the CLI default 4 × 8 vCPU the Ultimate set takes CPU **requests** to 67–98% (and limits to 205%). That is the real meaning of "make sure that the workers have free CPU and memory first" — the current text has no number and no command.
5. `[nkp-skill nkp-identity-security/SKILL.md License]` **Missing security warning.** The licensing webhook echoes the **whole license key** in `data.nutanix-license-key: Invalid value: "<key>"` when it rejects a key (proved in the previous run). The skill shows the patch block with no mask instruction. Add one line after the two patch blocks: pipe the dry run and the patch through `2>&1 | sed -E 's/Invalid value: "[^"]*"/Invalid value: "<masked>"/'`, and say never to paste that error into a chat or a log.
6. `[nkp-skill nkp-identity-security/SKILL.md License]` No list of what a tier installs, so an agent cannot tell "the tier worked" from "the tier half-worked". Add the measured table: Ultimate on AHV = 24 new HelmReleases (observability/logging 13, Ceph object storage 4: `rook-ceph`, `rook-ceph-cluster`, `cosi-driver-ceph-dkp-object-store`, `object-bucket-claims`; data/backup 3: `cloudnative-pg`, `cloudnative-pg-plugin-barman-cloud`, `velero`; 4 others). Also say that **Rook Ceph is installed on an AHV site** (its monitors sit on `nutanix-volume` PVCs) so nobody deletes it.
7. `[nkp-skill nkp-identity-security/SKILL.md Step 1]` The one-line state read shows `dkpLevel` and `valid` only. After any license change `endDate` is the useful field. Change the jsonpath to `tier={.status.dkpLevel} valid={.status.valid} end={.status.endDate}`.
8. `[nkp-skill nkp-install/SKILL.md Set the kubeconfig variables, UNKNOWN (A-05)]` Answer it. `--self-managed` writes `$PWD/<cluster>.conf` (observed again: `~/nkp-mgmt-01.conf`, 600) and the create's last line prints the path: `nkp get dashboard --kubeconfig="<path>"`. Mark it `[live 2.19.0]` and keep the `ls` block only as a confirmation. Also worth one line: the file appears **~17 min before** the create ends and is already final.
9. `[nkp-skill nkp-install/SKILL.md Set the kubeconfig variables]` The append block's "Done when" is only that the block ran. Add `test -f "$MGMT_KUBECONFIG" && echo ok`: a stale `MGMT_KUBECONFIG` line from an earlier cluster stays in `~/nkp-site.env` (this run had one pointing at a deleted file), so "the variable is set" and "the file exists" are different facts.
10. `[nkp-skill nkp-install/references/nutanix.md N4D]` "Run the dry run first. It only prints objects [live 2.19.0]" is wrong in an operational sense: the dry run **creates a kind bootstrap cluster, installs CAPI, runs the real preflight checks against Prism Central, then deletes the bootstrap cluster** (3 min 09 s here, 3 min in the previous run). Reword to: "the dry run needs the 4 CPU / 4 GB bootstrap cluster, reaches Prism Central and the mirror, and runs the preflight checks; it does not create VMs."
11. `[nkp-skill nkp-install/references/nutanix.md N4]` `--timeout` is never mentioned. Measured: the Nutanix management create takes **22–24 min** against the CLI default of **30 m** — almost no margin. Add a line to N4: "for a Nutanix management cluster, add `--timeout 60m`; the observed run time is 22–24 min and the default 30 m is close."
12. `[nkp-skill nkp-install/SKILL.md Step: Verify]` `kubectl get pods -A --field-selector=status.phase!=Running,status.phase!=Succeeded` exits 0 with an empty stdout and puts "No resources found" on **stderr**, which arrives out of order over ssh. Say "expect no output (the message is on stderr)" so the executor does not think the check failed.
13. `[nkp-skill nkp-install/references/nutanix.md N3]` The check list has no test that the **site mirror** answers. For N4C the operator host and every node subnet need it [pdf p.713]. Add `curl -sk -o /dev/null -w '%{http_code}\n' "$REGISTRY_URL/v2/"` (and a note that a `401` still proves the registry answers).
14. `[fact]` The create worked with `--insecure` only (no `PC_CA_FILE`) and the mirror CA present: `pc_http=302`, preflight passed, no TLS error. `--insecure` does **not** affect the mirror CA check.
