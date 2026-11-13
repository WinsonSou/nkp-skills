# T3 — `t3-flow-a`: workload cluster `skilltest-flow-a` with Flow CNI (path A)

Executor `lt2-build-2`. Date 2026-11-04. NKP 2.19.0. Task `t3-flow-a`.
Goal (site user's words): create workload cluster `skilltest-flow-a` in workspace `skilltest-flow` with Nutanix Flow CNI in place of Cilium, Ubuntu 24.04 (unsupported, user decision), dark-site Flow CNI bundle `<flow-bundle>` on the operator host, CP VIP `<net>.60`, LB `<net>.61-<net>.65`, default node sizes, same subnet and default pod/service CIDRs as the management cluster, Network Controller 7.6+ Integrated with Prism Central.

Skills used, in order: router `skills/nkp/SKILL.md` → `nkp-flow-cni` (step 1, step 2, step 3), then `nkp-flow-cni/references/install.md` (I1–I6), `nkp-install` (N5 step 1, SKILL "Set the kubeconfig variables" workload, "Verify" workload), `nkp-airgap` (step 4A extra bundle). Earlier notes of this site: `t1-preflight.md`, `t2-mgmt.md`.

Hard rules applied: `timeout` + `-o ServerAliveInterval=15 -o ServerAliveCountMax=4` on every ssh; `--request-timeout=30s` on every kubectl read; `sleep` alone (≤120 s); creates in tmux with a log; no secret printed.

## Blocks and key output

Blocks are in `blocks/t3-flow-a/` (scrubbed).

### 01 — `01-step1-prereq.sh` (`nkp-flow-cni` step 1 + `nkp-install` N5 step 1)

```
nkp version: catalog v0.11.1 / diagnose v0.14.0 / imagebuilder v2.19.0  (rest printed as 3 lines)
yq mikefarah v4.54.1
workspaces: default-workspace (kommander-default-workspace), kommander-workspace (kommander),
            skilltest-flow  skilltest flow  ->  skilltest-flow-dw97w
mgmt mirror URL: https://<registry-host>/nutanix      (N5 step 1 works, as t2 said)
VM_IMAGE=nkp-ubuntu-24.04-release-cis-1.36.2-20261014170313
clusterclass in skiltest-flow-dw97w: nkp-aws-v2.19.0 nkp-eks-v2.19.0 nkp-host-agent-v2.19.0 nkp-nutanix-v2.19.0
caren default-helm-addons-config nutanix-flow-cni: ChartName nutanix-flow-cni / ChartVersion 1.1.0 /
            RepositoryURL oci://helm-repository.caren-system.svc/charts
caren chart server tag list: {"name":"charts/nutanix-flow-cni","tags":["1.1.0"]}
nkpclusters: nkp-mgmt-01 v2.19.0 v1.36.2 Reconciled
license: Ultimate
<flow-bundle> present, 914087424 bytes
```

- The step 1 block's `get clusterclass` ran in `kommander` first because the workspace namespace derivation (`.status.namespace`) printed nothing (see L-02). Re-run in `skilltest-flow-dw97w` in block 02: same four classes, `nkp-nutanix-v2.19.0` present.
- Step 1 Done-when: class ✓, ConfigMap 1.1.0 ✓, tag list 1.1.0 ✓, **image name has `rocky` → FAILS** (Ubuntu image only). Per the user's decision the run continues; every result is tagged `[unsupported OS]`.

Read-only facts for the step 1 user items (ntnx client on the laptop, `nutanix-cluster` "Full inventory" shapes): PE cluster AOS **7.6**, one host **AHV 11.2**, Prism Central **7.6.0.10**. Node subnet `PRIMARY-IPAM` is `VLAN`; VPC overlay subnet `<lab-vpc>-sn1` is `<vpc-net>.0/24`. Default pod `192.168.0.0/16` and service `10.96.0.0/12` overlap no subnet and no VPC CIDR.

### 02 — `02-step2-dark-site.sh` (`nkp-flow-cni` step 2, `nkp-airgap` 4A)

```
clusterclass in skilltest-flow-dw97w: ... nkp-nutanix-v2.19.0
catalog: 200 ; flow/ovn/multus/nats repos: 20
  present: nutanix/k8snetworkplumbingwg/multus-cni, nutanix/library/nats, nutanix/natsio/nats-box,
           nutanix/natsio/nats-server-config-reloader
  absent:  nutanix/flow-cni, nutanix/flow-ovn-kubernetes, nutanix/flow-container-security
MISSING: REGISTRY_PUSH_USERNAME, REGISTRY_PUSH_PASSWORD, EXTRA_BUNDLE
images.yaml: docker.io -> nats:2.10-alpine, natsio/nats-box:0.14.1, natsio/nats-server-config-reloader:0.13.0,
             nutanix/flow-cni:1.1.0, nutanix/flow-container-security:1.1.0, nutanix/flow-ovn-kubernetes:1.1.1
             ghcr.io  -> k8snetworkplumbingwg/multus-cni:v4.1.3
charts.yaml: local/nutanix-flow-cni 1.1.0
skill tag command output: (empty)
```

### 03 — `03-bundle-layout.sh` (N-30, read-only)

The skill's command `tar -tf "$EXTRA_BUNDLE" | grep '/_manifests/tags/[^/]*/$'` prints **nothing** on this bundle (see L-01). The layout:

```
repository paths in the tar: charts/nutanix-flow-cni:1.1.0, k8snetworkplumbingwg/multus-cni:v4.1.3,
                             nats:2.10-alpine, ... (685 entries, top level: charts.yaml docker images.yaml)
```

The repository paths in the tar carry **no registry host** (`k8snetworkplumbingwg/multus-cni`, not `ghcr.io/...`), which matches the site mirror (A-30 answered in t1: mirror path = path without registry host).

### 04 + 05 — `04-push-right-probe.sh`, `05-push-right-probe2.sh` (read-only probe of the pull account's push right)

```
granted access: [{"type": "repository", "name": "/<registry-host>/nutanix/nats", "actions": []}]
scope pull   -> actions []      scope pull,push -> actions []      anonymous -> token issued
```

Inconclusive: Harbor 2.14 returns an empty `actions` list even for repositories that the account pulls, so the token probe cannot prove or disprove push rights (L-03). The push account must come from the user.

## Learnings

### L-01 `[nkp-skill nkp-flow-cni/references/install.md I2/I4 step 2]` and `[nkp-skill nkp-flow-cni/SKILL.md step 2]` — the N-30 discovery command prints nothing

SKILL.md step 2 gives `tar -tf "$EXTRA_BUNDLE" | grep '/_manifests/tags/[^/]*/$'`. On the real 1.1.0 dark-site bundle this prints **no line** (block 03): `tar -tf` lists the tag directories without a trailing slash:

```
docker/registry/v2/repositories/nats/_manifests/tags/2.10-alpine
docker/registry/v2/repositories/nats/_manifests/tags/2.10-alpine/current/link
```

So the `/$` anchor never matches and an executor that trusts the block believes the bundle holds no images. Proposed fix: drop the trailing `/` from the pattern and read the tag from the last path part:

```bash
tar -tf "$EXTRA_BUNDLE" | sed -n 's#^.*/_manifests/tags/\([^/]*\)$#\1#p' | sort -u
tar -xOf "$EXTRA_BUNDLE" images.yaml
```

`images.yaml` is the only place that names the source registry (t1 L-05); on this bundle it also proves that the tar's repository paths already drop the registry host.

### L-02 `[nkp-skill nkp-flow-cni/SKILL.md step 1]` — the workspace namespace is used before any block shows how to get it

The step 1 check block starts `source ~/nkp-<cluster>.env` and uses `$WORKSPACE_NS` and `$MGMT_KUBECONFIG`, but at step 1 the cluster env file does not exist yet (it is made in `nkp-install` N5 step 2, i.e. install.md I1, which comes **after** step 1). I ran the block with `ns=` chosen from `kubectl get workspaces -A`. `.status.namespace` on the Workspace object is empty, so a block that derives the namespace from that field gets nothing; the WORKSPACE NAMESPACE column of `get workspaces -A` is the only source (as `nkp-install` N5 step 1 says). Proposed fix: in step 1, put the `get workspaces -A` line first in the same block and take the namespace from its column, or state "run step 1 after N5 step 1 and use its `WORKSPACE_NS`".

### L-03 `[fact]` — a Harbor 2.14 token probe cannot show push rights

`GET /service/token?service=harbor-registry&scope=repository:<project>/<repo>:pull,push` with the pull robot account returns a token whose `access[].actions` is `[]` **also for `pull` on a repository that the account does pull** (blocks 04, 05). So this read-only probe cannot decide whether an account can push; do not add it to `nkp-airgap` as a check. The push account must come from the user (4A step 1), which is what the skill says.

### 06 — `06-env-push-lines.sh` (`nkp-airgap` 4A step 1: values)

User answered "the pull account can also push", so the block appended
`EXTRA_BUNDLE='<flow-bundle>'` plus `REGISTRY_PUSH_USERNAME="$REGISTRY_MIRROR_USERNAME"` and
`REGISTRY_PUSH_PASSWORD="$REGISTRY_MIRROR_PASSWORD"` (no value printed, no secret duplicated in the file).

```
set: EXTRA_BUNDLE ; set: REGISTRY_PUSH_USERNAME ; set: REGISTRY_PUSH_PASSWORD
```

### 07 — `07-push-flow-bundle.sh` (`nkp-airgap` 4A extra bundle, in tmux)

```
15:17:59 push starts  (temporary directory, extract bundle configs, parse image bundle config)
15:18:00 [4/7] nutanix/flow-cni:1.1.0        15:18:00 [5/7] nutanix/flow-container-security:1.1.0
15:18:01 [6/7] nutanix/flow-ovn-kubernetes:1.1.1   15:18:01 [7/7] k8snetworkplumbingwg/multus-cni:v4.1.3
15:18:01 Copying nutanix-flow-cni:1.1.0 (from bundle) to <registry-host>/nutanix/nutanix-flow-cni:1.1.0
RC=0
```

**1 min 40 s** for 914 MB (fast local Harbor). Step 2 Done-when (push ends without an error) passes.

### 08 + 09 + 10 + 11 — verify the mirror

`08` tailed the log (tmux session already gone, RC=0). `09` used `--netrc-file` for `tags/list` and got
`401 UNAUTHORIZED: authorize header needed` for every repo, also for ones that exist (Harbor needs the token
flow, not basic auth). `10`/`11` use the `_catalog` (200) and the token flow.

```
catalog 200, 421 repositories (was 416 before the push)
pushed: nutanix/nutanix/flow-cni, nutanix/nutanix/flow-container-security, nutanix/nutanix/flow-ovn-kubernetes,
        nutanix/nutanix-flow-cni (the chart), nutanix/nats (new), nutanix/k8snetworkplumbingwg/multus-cni (rewritten)
repos with the doubled prefix nutanix/nutanix/: 14  (the others: konnector-agent, kube-rbac-proxy, kubectl,
        kubernetes-os-ubuntu-24.04-nkp-v2.19.0, ndk-infra-manager, ntnx-csi-authagent, ntnx-csi-precheck, ...)
```

**N-30 answered for this bundle:** the mirror path is `<project>/<repo path without registry host>`, so
`docker.io/nutanix/flow-cni` lands at `nutanix/nutanix/flow-cni` — the same doubled prefix that NKP's own
`docker.io/nutanix/<image>` images already use in this mirror (14 repos), so the layout is consistent with the
rest of the mirror. `docker.io/k8snetworkplumbingwg/multus-cni` lands at `nutanix/k8snetworkplumbingwg/multus-cni`
(there was no `ghcr.io` prefix in the pushed path, see L-04).

## Step 3 (path A) and install.md I1–I6

The site user went to bed and gave a standing instruction ("go do what you need to do to push the frontier till it is no longer possible"), so the CHANGES blocks below ran without a per-block "yes". Each plan is in the block header; the hard limits of the BRIEF were kept (no secret printed, no finalizer, only this cluster's objects).

### 12 — `12-cluster-env.sh` (`nkp-install` N5 step 2, rule 4)

`~/nkp-skilltest-flow-a.env`: `CLUSTER_NAME=skilltest-flow-a`, `CP_VIP=<net>.60`, `LB_IP_RANGE=<net>.61-<net>.65`, `WORKSPACE_NS=skilltest-flow-dw97w`. `<net>` is read from `~/nkp-nkp-mgmt-01.env`, so no site IP sits in a tracked file. Namespace `skilltest-flow-dw97w` Active.

### 13 — `13-create-script.sh` (N5 step 3, workload body) — one deviation

The N5 body as written, plus **`--insecure`** (the PC certificate has no SAN; same gap as t2 M-01, now in N5 as well as N4A/B/C). Defaults kept: 3 control planes (4 vCPU / 16 GiB / 80 GiB) and 4 workers (8 vCPU / 32 GiB / 80 GiB) — the user asked for default node sizes. `bash -n` ok, 22 flag lines.

### 14 + 15 — `14-dryrun.sh`, `15-dryrun-lines.sh` (N4D dry run)

```
✓ Running preflight checks   RC=0  bytes=10924     (under 10 s; the skill says "less than 20 s, 5 Secrets")
kind: Secret x5 (pc-credentials, -for-ccm, -for-csi, -for-konnector-agent, image-registry-mirror-credentials)
kind: NKPCluster skilltest-flow-a   replicas: 3   vcpuSockets 4 / memorySize 16Gi / systemDiskSize 80Gi
  worker: 8 vcpuSockets / 32Gi / 80Gi, autoscaler min=max=4
  addressRanges end <net>.65, control-plane host <net>.60, insecure: true, url <registry-host>/nutanix, NTP servers
```

- The workload dry run prints **one `NKPCluster` and no `kind: Cluster`** (N-31: the `select(.kind == "Cluster")` half of the I3 `yq` is a no-op here).
- The create script has no pod/service CIDR flags, so the CIDR lines only appear after the webhooks (block 17).

### 16 + 17 — `16-cni-remove.sh`, `17-cni-check.sh` (I3)

```
yq RC=0
NKPCluster skilltest-flow-a  addons: ccm,clusterAutoscaler,cosi,csi,konnectorAgent,nfd,serviceLoadBalancer  kubeProxy: disabled
pods: 192.168.0.0/16  services: 10.96.0.0/12
```

I3 Done-when passes: an `addons:` line shows, no `cni` in it, the other 7 addons stay, the CIDRs are the management cluster's defaults. **`kubeProxy: disabled` stays** — the Cilium default (F-06); after the create there is no `kube-proxy` DaemonSet either, and the cluster works, so OVN provides service handling (F-06 answered).

### 18 — `18-hcp-file.sh` (I4, `darksite` mode)

`~/skilltest-flow-a-flow-cni-hcp.yaml`, mode 600, no pull secret: name `skilltest-flow-a-flow-cni`, namespace `skilltest-flow-dw97w`, selector `cluster.x-k8s.io/cluster-name=skilltest-flow-a`, `repoURL oci://helm-repository.caren-system.svc/charts`, `tlsConfig.caSecret caren-system/helm-repository-tls`, `chartName nutanix-flow-cni`, `version "1.1.0"`, chart namespace `flow-cni-system`, `valuesTemplate.nutanix-core-flow-ovn-kubernetes`: `k8sAPIServer https://<net>.60:6443`, `podNetwork 192.168.0.0/16/24`, `serviceNetwork 10.96.0.0/12`.

### 19 — `19-webhooks.sh` (webhook `sideEffects` gate, lab rule)

Every mutating webhook that matches `clusters`, `nkpclusters`, `helmchartproxies` or `secrets` has `sideEffects: None` (azureserviceoperator, caaph, capi, CAREN nutanix runtime extensions, cnpg, gatekeeper, `nkp-cluster-defaulting`). Server dry runs allowed.

### 20 — `20-server-dryrun.sh` (I5 block 1) — **it cannot work as the skill says**

```
secret/skilltest-flow-a-pc-credentials ... x5
helmchartproxy.addons.cluster.x-k8s.io/skilltest-flow-a-flow-cni
Error from server: admission webhook "webhook.nkpcluster.kommander.mesosphere.io" denied the request:
  admission webhook "cluster-defaulter.caren.nutanix.com" denied the request: cluster project policy defaulting:
  failed to resolve Prism Central version for project policy annotation:
  prism credentials secret "skilltest-flow-a-pc-credentials" not found
RC1=1
```

A `--dry-run=server` apply does not persist anything, so the CAREN `cluster-defaulter` webhook cannot read the PC credentials Secret that the same file creates. See L-05 and L-06.

### 21 (not used), 22 + 23 + 24 + 25 — the gate that does work

```
22  helmchartproxy.addons.cluster.x-k8s.io/skilltest-flow-a-flow-cni   RC=0
23  (apply the 5 Secrets only) secret/... x5                            RC=0
24  nkpcluster.clusters.nkp.nutanix.com/skilltest-flow-a                RC=0
25  NKPCluster skilltest-flow-a  addons: ccm,clusterAutoscaler,cosi,csi,konnectorAgent,nfd,serviceLoadBalancer
                                kubeProxy: disabled                      RC=0
```

So: dry run the HCP, create the 5 Secrets (inert, needed by the create anyway), then dry run the NKPCluster. **N-31 answered:** no webhook adds `addons.cni` back; the addon list after the webhooks has no `cni`.

### 26 — `26-create-cluster.sh` (I6)

```
secret/... x5 ; nkpcluster.clusters.nkp.nutanix.com/skilltest-flow-a ; helmchartproxy.../skilltest-flow-a-flow-cni
RC_create=0
```

Timeline (bastion time, 2026-11-04): apply 15:23:50 → NKPCluster `Reconciled` and the CAPI cluster `Provisioned` with 1/3 control planes at 15:24:32 → all 7 nodes `Ready` at 15:26:58 (3 min) → cluster kubeconfig written 15:26.

### 28 + 29 + 30 + 31 — kubeconfig, nodes, VIP, pods

```
~/skilltest-flow-a.conf 600, server https://<net>.60:6443, CLUSTER_KUBECONFIG appended
7/7 nodes Ready, v1.36.2, Ubuntu 24.04.5 LTS, containerd 2.3.1-d2iq.1, node IPs from the pool
VIP <net>.60: ping reply, https :6443/version = 200 from the operator host
flow-cni-system: nats-0/1/2 (2/2), nats-box, nutanix-flow-cni-*-… (Running), conntrack-collector DS 7/7
flow-cns-system: nutanix-flow-cni-*-flow-processor 0/1 ImagePullBackOff
ovn-kubernetes: ovnkube-node 7/7, ovs-node 7/7
kube-system: kube-multus-ds 7/7, no cilium DaemonSet, no kube-proxy DaemonSet
```

### 34 + 36 — what the Flow CNI install made

```
CRDs: egressips.k8s.ovn.org, egressservices.k8s.ovn.org, clusteruserdefinednetworks.k8s.ovn.org,
      userdefinednetworks.k8s.ovn.org, ovninterconnects.networking.nutanix.com, vpcs.networking.nutanix.com,
      vpcfederations.networking.nutanix.com, addressgroups/applicationpolicies/isolationpolicies.networking.nutanix.com,
      entitygroups.flow-container-security.nutanix.com
ovn-config ConfigMap: mtu = 1400, net_cidr 192.168.0.0/16/24, svc_cidr 10.96.0.0/12,
      k8s_apiserver https://<net>.60:6443, host_network_namespace = ovn-host-network
ovs-node mounts: /lib/modules, /var/run/dbus, /run/openvswitch, /var/lib/openvswitch, /sys, ...
```

**F-05 answered:** the chart sets `mtu = 1400` itself (not the portal's 1442). Nothing to set in the HCP values.
**F-04 answered:** the CRDs above exist. `egressips`/`egressservices` (`k8s.ovn.org/v1`) are installed and the API answers.

### 33 + 35 + 37 + 38 + 40 + 41 — the break: node DNS for the CRI

The mirror has all three Flow images with the right tags (`nutanix/nutanix/flow-cni:1.1.0`, `flow-container-security:1.1.0`, `flow-ovn-kubernetes:1.1.1`, 200 with the token flow). The pull failure is **not** a missing image:

```
flow-cns-system flow-processor: Failed to pull image "nutanix/flow-container-security:1.1.0":
  failed to pull and unpack image "docker.io/nutanix/flow-container-security:1.1.0":
  Head "https://<registry-host>/v2/nutanix/nutanix/flow-container-security/manifests/1.1.0?ns=…":
  dial tcp: lookup <registry-host> on 127.0.0.53:53: server misbehaving
```

- The rewrite in that URL is **correct** (`nutanix/nutanix/flow-container-security` = project + repository path), so N-30 is right for the nodes too.
- The failure is cluster-wide and starts **after** the Flow CNI pods come up: the whole `kommander-flux` namespace (`helm-controller`, `kustomize-controller`, `source-controller`, `flux-oci-mirror`, `prereq-wait-*`) is `ImagePullBackOff` with the same error. The management cluster has **no** pull failure at the same time.
- Probe 1 (`37`, hostNetwork pod, `dnsPolicy: Default`): the node's copied resolv.conf is `search <site-domain>` + `nameserver <dns>`; `getent hosts <registry-host>` **works**; the node's links are `lo ens3 ovs-system br-int genev_sys_6081 brens3 ovn-k8s-mp0` and the default route is `via <gw> dev brens3` — **Flow CNI renamed the uplink `ens3` to `brens3` and took it into OVS**.
- Probe 2 (`40`/`41`, hostNetwork pod with `dnsPolicy: None` + `nameservers: [127.0.0.53]`, run on **both** clusters):

```
flow cluster :  getent hosts <registry-host>  ->  stub-failed        nslookup <registry-host> <dns> -> <registry-ip>
mgmt cluster :  getent hosts <registry-host>  ->  <registry-ip>      nslookup <registry-host> <dns> -> <registry-ip>
```

So on a Flow CNI node the **systemd-resolved stub 127.0.0.53** no longer answers, while the upstream DNS server answers fine (and the same stub answers on the management cluster's nodes). containerd resolves through `/etc/resolv.conf` → 127.0.0.53, so **every image that is not already on the node cannot be pulled**. Result:

```
pods not Running on skilltest-flow-a (15:34): kommander-flux 9 x ImagePullBackOff + 2 x ContainerCreating,
                                              flow-cns-system 1 x ImagePullBackOff
helmreleases on the workload cluster: 0
nkpclusters: skilltest-flow-a  Reconciling Platform Applications
HRPs deployed and True: cosi, konnector-agent, metallb, nkp-cloud-provider-nutanix, node-feature-discovery,
                        nutanix-csi-storage, snapshot-controller  (all pulled before the CNI came up)
HRP nutanix-flow-cni: False, on the flow-processor image pull
```

The registry certificate has **DNS SANs only** (`*.<site-domain>`, no IP), so the obvious workaround "use the registry IP as the mirror URL" needs a certificate with an IP SAN (block 44). The remaining fixes are site changes: an `/etc/hosts` line for the registry on the nodes, or the DNS/search-domain config in the AHV subnet (Prism Central) — both outside this task's hard limits. **I stop here.**

Probe pods were deleted (`39`, `42`); nothing else was left behind by the probes.

### 42 + 43 — `nkp-install` "Verify" (workload branch)

```
7/7 Machine rows READY True; NKPCluster Reconciling Platform Applications
kommanderclusters skilltest-flow-a: status <none> (never Joined: Flux is not installed on it)
ntnx-system 10 pods Running (incl. konnector-agent), metallb-system 8 Running, 26 kube-system Running
helmreleases on the workload cluster: 0  (the skill's Done-when needs them all Ready; they never appear)
```

### L-04 `[nkp-skill nkp-airgap step 4A]` + `[fact]` — where the push puts the images, and the `ghcr.io` label

`nkp push bundle` pushed `k8snetworkplumbingwg/multus-cni:v4.1.3` as **`docker.io/…`** although `images.yaml` says `ghcr.io`. The landing path is the same either way (`<project>/k8snetworkplumbingwg/multus-cni`), so nothing breaks, but the log reads wrong. The chart lands at `<project>/nutanix-flow-cni` — **not** `<project>/charts/nutanix-flow-cni` (the repository path in the tar is `charts/nutanix-flow-cni`, the push drops the first part). Proposed fix: one line in 4A after the push: "the chart of an extra bundle lands at `<project>/<chart name>` (the `charts/` path part is dropped); the flow images land at `<project>/<repo path>`, and a `docker.io/nutanix/<image>` therefore lands at `<project>/nutanix/<image>` — the doubled prefix is normal, 14 repositories of this mirror use it." That single line would have saved the disk-vs-mirror doubt of step 2.

### L-05 `[nkp-skill nkp-flow-cni/references/install.md I5]` — the server dry run cannot pass for a Nutanix workload cluster, as written

I5 says to dry-run both files with `--dry-run=server` and "Done when: every object prints its name and no error shows". On this site that is **impossible**, and not because of a wrong file:

```
admission webhook "webhook.nkpcluster.kommander.mesosphere.io" denied the request:
  admission webhook "cluster-defaulter.caren.nutanix.com" denied the request:
  cluster project policy defaulting: failed to resolve Prism Central version for project policy annotation:
  prism credentials secret "skilltest-flow-a-pc-credentials" not found
```

The CAREN `cluster-defaulter` webhook resolves the Prism Central version through the **persisted** PC credentials Secret. A server dry run persists nothing, so the Secret that the same file creates is invisible to the webhook. The skill's own claim ("a webhook default is not in the schema, so block 2 reads the addon names after the webhooks") is right, but the gate as ordered cannot run.

Proposed fix, in I5: three steps in this order, each with its Done-when —
1. dry run the HCP file alone (`apply --server-side --dry-run=server -f …-hcp.yaml -o name`);
2. create the 5 Secrets alone, from the dry-run file, writing no second file on disk: `yq 'select(.kind == "Secret")' "$f" | kubectl … apply --server-side -f -`;
3. dry run the NKPCluster alone (`yq 'select(.kind == "NKPCluster")' "$f" | kubectl … --dry-run=server -f - -o name`), then the addon check of block 2.

Add one sentence of why: "the CAREN cluster-defaulter webhook reads the PC credentials Secret, so a dry-run of the whole file set fails with `prism credentials secret … not found`. The Secrets are inert and the create needs them anyway."

### L-06 `[nkp-skill nkp-flow-cni/SKILL.md step 4, "Common failures"]` — the `ImagePullBackOff` row sends the executor to the wrong place

The row says: "Flow CNI pods in `ImagePullBackOff` | Connected: wrong or old pull token. Dark site: images not in the mirror (step 2)." My failure was neither: the images were in the mirror at the exact rewritten path, and the real cause was the node resolver. An executor who follows the row re-pushes a 914 MB bundle for nothing.

Proposed fix, add one row above it:

| Symptom | Cause | Fix |
|---|---|---|
| `ImagePullBackOff`, the event says `lookup <registry-host> on 127.0.0.53:53: server misbehaving` (or the same on any other name) | The node's systemd-resolved stub is broken, not the mirror or the token | Read the event of the pod (`kubectl describe pod`), do not re-push. Prove it with a `hostNetwork` pod that has `dnsPolicy: None` and `nameservers: [127.0.0.53]`, then compare with `nslookup <registry-host> <upstream dns ip>`. See `[fact]` below. |

### L-07 `[fact]` — what actually breaks with Flow CNI on Ubuntu 24.04 on this site (the answer the user asked for)

Flow CNI itself installs and runs: `ovnkube-node` 7/7, `ovs-node` 7/7, `flow-cni-system` 12 pods Running, pods get overlay IPs (`192.168.4.x`), the chart's own `conntrack-collector` DS is 7/7, no Cilium and no kube-proxy DaemonSet exists, and the chart sets `mtu = 1400` by itself.

The break is one step later, at the node network layer:

1. Flow CNI renames the node uplink `ens3` → **`brens3`** and takes it into OVS (`ovs-system`, `br-int`, `genev_sys_6081`, `ovn-k8s-mp0` are the new links; default route `via <gw> dev brens3`; `ovn-config` has `host_network_namespace = ovn-host-network`).
2. After that, the node's **systemd-resolved stub `127.0.0.53` stops answering** for the site domain, while the upstream DNS server answers normally. Proof on both clusters with the same probe pod:

```
flow cluster node : getent hosts <registry-host>            -> stub-failed
                    nslookup <registry-host> <dns ip>       -> <registry-ip>
management node   : getent hosts <registry-host>            -> <registry-ip>      (same stub, works)
```

3. containerd resolves through `/etc/resolv.conf` → `127.0.0.53`, so **every image that is not already cached on the node fails to pull**:

```
lookup <registry-host> on 127.0.0.53:53: server misbehaving
```

4. Consequence on `skilltest-flow-a`: `flow-cns-system/flow-processor` and the **whole `kommander-flux` namespace** (9 pods) are `ImagePullBackOff`, so `helmreleases` on the workload cluster stays `0`, the NKPCluster stays `Reconciling Platform Applications`, and the KommanderCluster never joins. The 7 addon HelmChartProxies that did install are exactly the ones whose images were pulled before the CNI came up.

Notes for the operator (none of these was run): the registry certificate has **DNS SANs only** (`*.<site-domain>`, no IP SAN), so "use the registry IP as the mirror URL" needs a new certificate. The other two candidates are a node-level `/etc/hosts` entry for the registry and the subnet's DNS/search-domain config in Prism Central — both outside this task's limits. Whether this is Ubuntu-specific is not known from this test: on Rocky the same OVS takeover happens, but Rocky's resolver is NetworkManager/`systemd-resolved` too, so the skill should not claim "Ubuntu only".

Proposed skill change (`nkp-flow-cni` SKILL step 4, "What changes on a Flow CNI cluster"): one bullet — "Flow CNI takes the node uplink into OVS and renames it. Check that the node still resolves the registry through the CRI: `kubectl get events -A | grep -i 'server misbehaving'`. If it does not, the cluster cannot pull any new image, and image pulls are what installs Flux and every platform app."

### L-08 `[nkp-skill nkp-flow-cni/SKILL.md step 4 item 1]` — "The nodes stay `NotReady` until the Flow CNI pods run" is not true on 2.19.0

All 7 nodes were `Ready` (and the 3 control planes formed the cluster, `etcd`/`kube-apiserver` up) about 2 minutes after the apply, while the Flow CNI chart was still installing: `ntnx-system`, `metallb-system`, `ntnx-csi-node`, `node-feature-discovery` and CoreDNS pods were already Running with overlay IPs before `flow-processor` ever started. Proposed fix: "the nodes may go `Ready` before the CNI pods run (seen on 2.19.0); the pods of the platform apps are what fails while the CNI is missing, not the node status."

### L-09 `[nkp-skill nkp-flow-cni/references/install.md I4]` — N-32 answered: a user HCP on the CAREN chart server does install the chart

`HelmReleaseProxy nutanix-flow-cni-skilltest-flow-a-v8zbc` was created from the HCP, `HelmReleaseProxySpecsUpToDate=True`, and the chart's pods run on the new cluster. So the answer to N-32 is **yes**, with two facts worth writing into I4:
- the first conditions are false for a while with `Kubernetes cluster unreachable: … dial tcp <vip>:6443: connect: no route to host` because the HCP is created together with the cluster and the control-plane VIP is not up yet; it recovers by itself (the chart installed 1–2 min later). Do not read the first `Ready=False` as a failure.
- in `darksite` mode the pods pull through the registry mirror with **no** pull secret (F-03 answered for the first 5 images; the later ones failed for the DNS reason of L-07, not for auth).

### L-10 `[nkp-skill nkp-install/references/nutanix.md N5]` — `--insecure` is missing there too

The N5 workload create script has the same gap as N4A/N4B/N4C (t2 M-01): this site's PC certificate has no SAN, so the script as written fails on a certificate error and the executor must add `--insecure` by itself. Proposed fix: the same one-line note in N5, and `--insecure` in the N5 body when `PC_CA_FILE` is unset.

### L-11 `[fact]` — timings for the record

- workload dry run: under 10 s, 10 924 bytes, 5 Secrets, preflight passed with no `--skip-preflight-checks`.
- apply → all 7 nodes Ready: **3 min 8 s** (15:23:50 → 15:26:58). The skill says a workload create takes 3–13 min; this was at the low end, and the cluster kubeconfig existed after 2 min.
- Flow CNI chart installed and its pods up 1–2 min after the control-plane VIP answered.
- `.marker` for T4/T5: `kubectl get events -A | grep 'server misbehaving'` is the fastest proof of the L-07 break.

## Status

`blocked at install.md step 4 (SKILL.md step 4 Done-when)`: **the cluster is created and Flow CNI is installed and running on Ubuntu 24.04, but the cluster cannot pull any image that is not already on the nodes**, so `kommander-flux` never starts, `helmreleases` stays 0 and the NKPCluster stays `Reconciling Platform Applications`.

Done: step 1 (Rocky need named, only this item fails), step 2 (dark-site bundle pushed, N-30 answered), step 3 path A (I1–I6, N-31/N-32 answered), step 4 partly (F-03, F-04, F-05, F-06 answered; F-07 cannot be answered while Flux is not installed).
Not done, on purpose: I7 cleanup of the three local files (they hold Secrets; the user decides keep or delete), and every fix that needs a site change (node `/etc/hosts`, subnet DNS, a new registry certificate) — outside this task's hard limits.
Left behind: `skilltest-flow-a` (7 VMs), its 5 Secrets, the Flow CNI HCP, the created kubeconfig and dry-run/HCP files on the operator host, and the 4 pushed Flow CNI repositories in the site mirror. No probe pod was left (deleted in blocks 39 and 42). No secret was printed; the two probe blocks print no credential.

## Round 2 — user's answers (2026-11-04, after the report)

The site user answered: (1) keep the cluster and the local files; (2) I may fix name resolution **on the nodes of `skilltest-flow-a` only** — not Prism Central, not the subnet, not the registry, not the nodes of `nkp-mgmt-01`; the plan goes into this log first, and the fix must be removed by a delete of the cluster; then check which platform apps do and do not work with Flow CNI; (3) then the day-1 smoke test on `skilltest-flow-a`, and answer D-60 (does the Prism Central volume group go when the PVC goes); (4) if the fix fails, run the smoke test on `nkp-mgmt-01` in a `skilltest-` namespace.

### Plan of the name-resolution fix (written before the block ran)

- **Object:** one DaemonSet `registry-hosts-fix` in namespace `kube-system` **on `skilltest-flow-a` only**. Nothing else changes.
- **What it does:** it adds one line, `<registry-ip> <registry-host>`, to the node's `/etc/hosts` if that line is not there yet, then it sleeps. It mounts the node file `hostPath /etc/hosts` and runs `privileged` so it can write it.
- **Image:** `natsio/nats-box:0.14.1` — already on all 7 nodes (the Flow CNI chart pulled it), so the DaemonSet does not need a working pull to start.
- **Why this fix:** the evidence in L-07 is that the provider stub is the broken part, not the network: `getent hosts <registry-host>` fails through `127.0.0.53` on a Flow node and works through the upstream DNS, and the same stub works on a management node. Both glibc and the Go resolver of containerd and kubelet read `/etc/hosts` **before** DNS, so the CRI finds the registry without the stub.
- **Why not the alternatives:** a resolved/`resolvectl` change touches systemd state on the node (harder to undo by a cluster delete, and a second moving part); a mirror URL by IP fails the certificate check (no IP SAN, L-07); a Prism Central, subnet or registry change is forbidden by the user.
- **What a cluster delete removes:** the DaemonSet and its pods go with the cluster namespace objects; the only residue is one line in the `/etc/hosts` of a node VM, and that VM is itself deleted by the cluster delete. Nothing outside the cluster changes.
- **At the end of the test:** delete the DaemonSet with the plan shown (`delete ds -n kube-system registry-hosts-fix`), so the state of the cluster is what the skills produce.
- **Measured by:** node resolution through the stub (`getent hosts` in a `dnsPolicy: None` + `127.0.0.53` hostNetwork pod), then the pull retries of `kommander-flux`, then the workload cluster's HelmReleases and the KommanderCluster status.

## Round 2 — blocks and results

### 45 + 46 + 47 — the two smoke-test images from the mirror (C12 step 2)

```
catalog search: nutanix/nginxinc/nginx-unprivileged, nutanix/library/busybox (and .../containerd/busybox)
tags: nutanix/nginxinc/nginx-unprivileged -> 200 {"tags":["1.29.5-alpine"]}
      nutanix/library/busybox             -> 200 {"tags":["1"]}
```

So the C12 names hold on this mirror: `docker.io/nginxinc/nginx-unprivileged:1.29.5-alpine`, `docker.io/library/busybox:1`.
Block 45 first failed with `project <registry-host> not found` because of a bug in **my** block (`proj="${REGISTRY_URL#*/}"` keeps `/host/nutanix`; the correct one is `${REGISTRY_URL##*/}`). The C12/nodes.md tag-list recipes build the scope themselves and do not have this bug; recorded here so the next executor does not repeat it: **the token scope needs `<project>/<repo path>`, and the project is the LAST path part of `REGISTRY_URL`, not the whole path.**

### 48 — `48-hosts-fix-ds.sh` (first attempt) — the fix's own bug

DaemonSet `registry-hosts-fix` (kube-system, `hostPath /etc/hosts`, privileged, image `natsio/nats-box:0.14.1`, already on every node), which appends `<registry-ip> <registry-host>` when the line is missing. 7/7 pods ready, log `added: <registry-host>`.

**It made it worse:** the node's `/etc/hosts` has **no trailing newline**, so `echo … >> /etc/hosts` glued the new entry onto the last line:

```
127.0.0.1  localhost localhost<registry-ip> <registry-host>
```

and containerd then resolved the registry to `127.0.0.1` (`dial tcp 127.0.0.1:443: connect: connection refused`). This is still useful evidence: **containerd did read the hosts file**, so `/etc/hosts` is the right lever.

### 53 — `53-hosts-fix-v2.sh` (the fix that works)

Delete + re-apply of the same DaemonSet with a safe command: strip any `<ip> <host>` fragment with `awk`, print (which adds the missing newline), append the line only if it is not there, write back with `cat > /etc/hosts` (a redirection, not `sed -i`, which would break the bind mount).

```
/etc/hosts now:  <registry-ip> <registry-host>          (7/7 nodes)
```

Then `50-force-retry.sh` deleted the stuck pods so their controllers retried at once:

```
15:41  flow-cns-system/flow-processor          1/1 Running
15:41  kommander-flux (9 pods)                 all 1/1 Running
15:45  HelmChartProxy skilltest-flow-a-flow-cni  Ready=True
15:55  HelmReleases on the workload cluster     19, all READY True
15:55  KommanderCluster  PlatformAppDeploymentsReady=True  "All platform AppDeployments are ready"
       IngressAddressReady=True, IngressCertificateReady=True
15:55  NKPCluster skilltest-flow-a               Reconciled   (31 min after the apply)
       nodes 7/7 Ready, pods 138, namespaces flow-cni-system / flow-cns-system / skilltest-flow-dw97w
```

**So on this site, with Ubuntu 24.04 and the node resolver worked around, the whole Flow CNI path A result is green.** The workaround stays in the cluster (one DaemonSet, dies with the cluster); without it the cluster cannot pull any new image (L-07).

### F-07 — which platform apps work on a Flow CNI cluster

All 14 AppDeployments of the workspace, and all 19 HelmReleases on the cluster, are `READY True`:

```
cert-manager, cert-manager-crds, cilium-hubble-relay-traefik, external-secrets, gatekeeper,
gatekeeper-proxy-mutations, gateway-api-crds, headlamp, karma-traefik, kommander-flux, kube-oidc-proxy,
kube-prometheus-stack, opencost, prometheus-adapter, prometheus-thanos-traefik, reloader, traefik,
traefik-crds, traefik-forward-auth-kommander
```

One app is a **hollow install**: `cilium-hubble-relay-traefik` installs an IngressRoute, but the cluster has **no Cilium workload, no `hubble-relay` Service and no Cilium CRDs**, so it points at nothing and can never work on a Flow CNI cluster. Everything else is independent of the CNI. Answer to F-07: nothing fails to install; the Cilium-only app installs and stays unusable.

### C12 smoke test on `skilltest-flow-a` (blocks 57–61) and D-60

```
57  storageclass: nutanix-volume (default) Delete WaitForFirstConsumer ; pool metallb ["<net>.61-<net>.65"] ; no LB svc yet
58  file $PWD/skilltest-flow-a-smoke.yaml (PVC 1Gi + pod + LoadBalancer, ns skilltest-smoke)
59  namespace + server dry run + apply            RC=0
60  PVC Bound 1Gi, PV pvc-23ccee7a… handle NutanixVolumes-af01db1d-945f-4982-67f1-104b570226f8
    Service EXTERNAL-IP <net>.61 (ClusterIP <cluster-ip> — inside the service CIDR)
    http=200 and the body "smoke test skilltest-flow-a"
61  delete namespace: <net>.61 freed, PV gone, 15 s
```

- The test proves the Nutanix CSI, MetalLB in L2 and **Service handling without Cilium and without kube-proxy** on the Flow CNI cluster (the ClusterIP and the LB IP both answered).
- **D-60 answered: yes, the volume group goes.** Before the delete: 35 volume groups in Prism Central, the handle found, `attachments: 1`, description `FS:ext4, K8sClusterID:…, CSIVersion:v3.9.0, … CSI StorageClass nutanix-volume for skilltest-flow-a, …`. About 1 min after the namespace delete: **34 groups and the handle is gone** (checked twice, 1 min apart). So with `reclaimPolicy: Delete` the CSI deletes the Prism Central volume group when the **PVC** is deleted — this is the opposite of the cluster-delete behaviour that C10 documents (a cluster delete keeps the groups of the PVCs it still has).
- After the test, `kommander-traefik` took the freed first IP `<net>.61` (the C12 "When" note in action).

## Round 2 — learnings

### L-12 `[nkp-skill nkp-storage-backup/references/csi.md C12]` — D-60 is answered; write it in C10 and C12

D-60 ("does the CSI delete the Prism Central volume group when a PVC of `nutanix-volume` is deleted") → **yes, in about 1 minute**, measured with the handle uuid: 35 → 34 groups and no match after the namespace delete. Proposed fix: replace the UNKNOWN in C12 step 5 with "Yes, measured on 2.19.0 (CSI v3.9.0): the volume group disappears about 1 min after the namespace delete." and add to C10 the contrast: "a **PVC** delete removes its volume group; a **cluster** delete keeps the groups of the PVCs that still exist" — the two sentences together are what an operator needs.

### L-13 `[nkp-skill nkp-flow-cni/SKILL.md step 4, "What changes on a Flow CNI cluster"]` — F-07 is answered, and the answer is not "an app fails"

All 19 HelmReleases are Ready. The Cilium-only app `cilium-hubble-relay-traefik` **installs successfully and points at nothing** (no Cilium workload, no `hubble-relay` Service, no Cilium CRDs on the cluster), so a "not ready HelmRelease" check does not find it — which is what the skill's F-07 command looks for. Proposed fix: replace the F-07 UNKNOWN with: "Measured 2.19.0 + Flow CNI 1.1.0: every platform app installs, including `cilium-hubble-relay-traefik`; that app is useless on a Flow cluster (no Hubble relay Service and no Cilium CRDs), so do not diagnose it with `helmreleases`. `kubectl get svc -A | grep hubble` prints nothing, which is the proof."

### L-14 `[fact]` — the workaround that fixes L-07, and its two traps

- `hostPath /etc/hosts` + `echo … >>` is **not safe**: the node file ends without a newline and the entry glues onto `127.0.0.1 localhost …`; containerd then resolves the registry to `127.0.0.1` and fails with `connection refused`. A block that writes a node file must add the missing newline first (`awk`+`print`, or `[ -n "$(tail -c1 f)" ] && echo >> f`) and must write back with a redirection (`cat > f`), never `sed -i` on a bind-mounted file.
- After the hosts entry, the stuck pods must be deleted to retry at once, otherwise the backoff delay hides the fix for minutes.
- With that, this site's Flow CNI cluster installs the whole platform: 19/19 HelmReleases Ready, NKPCluster `Reconciled` 31 min after the apply.
- Whether to keep this DaemonSet permanently is a site decision: it is the only thing that lets the cluster pull new images, and a cluster delete removes it with the cluster.

### L-15 `[nkp-skill nkp-flow-cni/SKILL.md step 4]` — the Done-when of step 4 now passes completely

HCP `Ready=True`, one HelmReleaseProxy with chart `nutanix-flow-cni` READY `True`, 7/7 nodes Ready, `ovnkube-node` 7/7, `ovs-node` 7/7, `flow-cni-system` 12 pods, `flow-cns-system` 1/1, `kube-multus-ds` 7/7, no Cilium DaemonSet, no kube-proxy DaemonSet, `konnector-agent` Running. The only item I cannot check myself is "the user sees the cluster in Prism Central" (no UI in this task).

## Status (round 2)

`done` for the user's points 1–3. `skilltest-flow-a` runs on Ubuntu 24.04 with Flow CNI, all 14 workspace AppDeployments and 19 HelmReleases ready, NKPCluster `Reconciled`, and the day-1 smoke test passed (PVC Bound, LB `<net>.61`, `http=200`) and was removed. D-60 answered: the volume group goes with the PVC. Point 4 (the smoke test on `nkp-mgmt-01` instead) was not needed — the fix worked.
Left in place, as the user asked: the cluster and its local files, plus **one workaround object**: `kube-system/registry-hosts-fix` (the DaemonSet that writes the registry line into the nodes' `/etc/hosts`). It is the only thing that lets this cluster pull new images, and a cluster delete removes it. The delete command, if you want the cluster back in the state that the skills produce: `kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n kube-system delete ds registry-hosts-fix`.
