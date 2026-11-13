# T6 — `t6-flow-b`: workload cluster `skilltest-flow-b` with Flow CNI as the cluster CNI provider (path B)

Executor `lt2-build-4`. Date 2026-11-04. NKP 2.19.0. Task `t6-flow-b`.
Site user's words: create workload cluster `skilltest-flow-b` in workspace `skilltest-flow` on `nkp-mgmt-01`, with Flow CNI as the CNI provider of the cluster itself (`addons.cni`), **not** a separate HelmChartProxy. Ubuntu 24.04 (accepted unsupported), Flow CNI images already in the site Harbor, default node sizes, same subnet and default networks, CP VIP `<net>.70`, LB `<net>.71-<net>.75`. If this way does not work, tell exactly why and what I saw; do not fall back to path A without asking. The node name-resolution fix of the last cluster may be used on this cluster's nodes only. Standing order: plans are approved; write each plan in this log before the block runs.

Skills used, in order: router `skills/nkp/SKILL.md` → `nkp-flow-cni` step 1, step 2 (already done for this site in `t3-flow-a`), step 3 **path B**, `nkp-install` N5 (workload create), N4D (dry run), `nkp-cluster-lifecycle` (kubeconfig, verify).
Earlier notes of this site: `t1-preflight.md`, `t2-mgmt.md`, `t3-flow-a.md`, `t5-delete-flow-a.md`.

Hard rules applied: `timeout` + keepalive flags on every ssh; `--request-timeout=30s` on every kubectl read; `sleep` as its own call (≤120 s); the create runs in tmux with a log; no secret printed; no finalizer removed.

## What the skills say about path B (read first, before any block)

- `nkp-flow-cni` step 3, table: path **B** = `clusterConfig.addons.cni.provider: Flow` in the cluster YAML, with `strategy: HelmAddon`, `values.sourceRef` (a ConfigMap) and `imagePullCredentials.secretRef.name` (a Secret that CAREN copies to the cluster). Marked **"Not tested, no Nutanix support statement. Not in the skills."**
- UNKNOWN (F-02) asks exactly this task's question; its find-out command is the CAREN ConfigMap `default-nutanix-flow-cni-helm-values-template`. The skill says "Use path A until a lab test or Nutanix confirms path B."
- The user asks for path B, so this task is the lab test of F-02. The skill's "use path A" line is answered by the user's request; I log that deviation here.

## Preflight (READ-ONLY) — blocks 01–05

Block 01 (`01-preflight.sh`), block 02 (`02-fix-probe.sh`, my two probe bugs), 03/04/05 (schema shape). Key output:

```
nkpclusters: kommander/nkp-mgmt-01 v2.19.0 v1.36.2 Reconciled (102m), 7 nodes Ready
workspaces: default-workspace, kommander-workspace, skilltest-flow -> skilltest-flow-dw97w
clusterclass in skilltest-flow-dw97w: nkp-aws, nkp-eks, nkp-host-agent, nkp-nutanix-v2.19.0
caren default-helm-addons-config nutanix-flow-cni: ChartName nutanix-flow-cni / ChartVersion 1.1.0 /
      RepositoryURL oci://helm-repository.caren-system.svc/charts
caren configmap default-nutanix-flow-cni-helm-values-template: present
VM_IMAGE=nkp-ubuntu-24.04-release-cis-1.36.2-20261014170313
leftovers of skilltest-flow-a in the workspace ns: none
IPs .70 and .71-.75: no ping answer, no ARP (lladdr) -> free
```

The CNI schema of the AHV ClusterClass (from `status.variables[clusterConfig].definitions[0].schema`):

```
cni.required: ['provider']                       <- imagePullCredentials is OPTIONAL
cni.properties: [imagePullCredentials, provider, strategy, values]
provider.enum: [Calico, Cilium, Flow]
strategy: enum [ClusterResourceSet, HelmAddon], default HelmAddon
imagePullCredentials: object, required ['secretRef'] when present
values.sourceRef: ConfigMap in the same namespace (inline YAML values for the Helm chart)
```

Mirror (this site is a dark site; the images were pushed in `t3-flow-a` step 2, nothing to push now):

```
nutanix/nutanix/flow-cni            200 tags ["1.1.0"]
nutanix/nutanix/flow-container-security 200 ["1.1.0"]
nutanix/nutanix/flow-ovn-kubernetes 200 ["1.1.1"]
nutanix/nutanix-flow-cni (chart)    200 ["1.1.0"]
nutanix/natsio/nats-box             200 ["0.14.1"]
```

So the minimum path B on this site is `addons.cni: {provider: Flow, strategy: HelmAddon}`: no pull secret (the nodes pull through the mirror), no `values.sourceRef` unless the CAREN values template is wrong for this site.

Known risk to watch (from `research/raw/live/2.19/flow-cni.txt`): the CAREN Flow values template sets `podNetwork: "{{ .PodCIDR }}"` — **without** the `/<hostprefix>` suffix that the Flow guide (and path A, `192.168.0.0/16/24`) uses. If the chart rejects or mis-sizes the pod network, the fix inside path B is `addons.cni.values.sourceRef` (a ConfigMap with the full values), which keeps the CNI in the cluster config and adds no HelmChartProxy.

## Plan (written before the block runs)

1. Block 06 (`06-cluster-env.sh`, CHANGES, operator host): write `~/nkp-skilltest-flow-b.env` with `CLUSTER_NAME=skilltest-flow-b`, `CP_VIP` = `<net>.70`, `LB_IP_RANGE` = `<net>.71-<net>.75`, `WORKSPACE_NS=skilltest-flow-dw97w`. `<net>` is read from the management cluster env file, so no site IP goes into a tracked file. Result: the cluster env file exists, mode 600, namespace Active.
2. Block 07 (`07-create-script.sh`, CHANGES, operator host): write `~/nkp-skilltest-flow-b-create.sh` from N5 step 3, plus `--insecure` (the site PC certificate has no SAN; same gap as t2 M-01 / t3 L-10). Do not run it. Result: the script exists, `bash -n` clean.
3. Block 08 (`08-dryrun.sh`, CHANGES, management cluster: server-side dry run, changes nothing): `nkp create cluster nutanix ... --dry-run -o yaml > ~/skilltest-flow-b-dryrun.yaml`. Result: the file exists, mode 600, one NKPCluster.
4. Block 09 (`09-cni-path-b.sh`, CHANGES on the local file only): set `addons.cni = {provider: Flow, strategy: HelmAddon}` in the `clusterConfig` variable of the dry-run file (path B). Keep the `.orig` copy. Print only kinds, addon keys, the CNI block, and the CIDRs. Result: the CNI block shows `provider: Flow`.
5. Block 10 (`10-server-dryrun.sh`, READ-ONLY, server dry run): dry run the edited NKPCluster to see the webhook result and the object **after** the CAREN defaulting webhooks. Result: `provider: Flow` survives, no `cilium` addon is added, no error.
6. Block 11 (`11-create.sh`, CHANGES, management cluster): apply the NKPCluster in tmux, log `~/nkp-skilltest-flow-b-create.log`. Result: the cluster is created; Prism Central makes 7 VMs.
7. Then SKILL.md step 4 / `nkp-install` verify: kubeconfig, nodes, Flow CNI pods, `ovn-config`, no Cilium, no kube-proxy, and the L-07 resolver check (`kubectl get events -A | grep -i 'server misbehaving'`). If that break comes back, apply the same `/etc/hosts` DaemonSet as `t3-flow-a` on **this cluster's nodes only**, with the trailing-newline-safe writer (t3 L-14).
8. Report: does path B work, what CAREN rendered, what broke, and the answer to F-02.

Nothing outside the hard limits: only `skilltest-flow-b`, its workspace namespace, its PC objects, and (if needed) the one DaemonSet on its nodes.

### Plan addendum (written after the first server dry run, before the extra blocks ran)

The `nkp-flow-cni` I5 order (`t3-flow-a` L-05) applies to path B too: the CAREN `cluster-defaulter` webhook reads the **persisted** PC credentials Secret, so a server dry run of the NKPCluster before the Secrets exist fails with `prism credentials secret "skilltest-flow-b-pc-credentials" not found` (block 10, seen). Extra blocks:

- Block 11 (`11-webhook-gate.sh`, READ-ONLY): the lab rule — every webhook that matches `nkpclusters` or `secrets` must have `sideEffects: None`/`NoneOnDryRun` before a server dry run. Result: all do.
- Block 12 (`12-secrets.sh`, CHANGES, management cluster): create the 5 Secrets of the dry-run file in `skilltest-flow-dw97w` (`yq 'select(.kind == "Secret")'`). They are inert and the create needs them. Result: 5 Secrets exist.
- Block 13 (`13-server-dryrun.sh`, READ-ONLY): server dry run of the NKPCluster **after** the webhooks, printing only the addon keys and the CNI block. Result: `provider: Flow` survives, no `cilium` value is added, no error.
- Block 14 (`14-create.sh`, CHANGES): the create (plan in step 6 above).

## Blocks and key output

### 06 — `06-cluster-env.sh`

```
written: ~/nkp-skilltest-flow-b.env (mode 600, syntax ok)
set: CLUSTER_NAME CP_VIP LB_IP_RANGE WORKSPACE_NS
skilltest-flow-dw97w   Active   84m
```

### 07 — `07-create-script.sh` (N5 step 3 + `--insecure`)

`~/nkp-skilltest-flow-b-create.sh`, mode 600, `bash -n` ok, 17 flag lines. Defaults kept (3 control planes 4 vCPU/16 GiB/80 GiB, 4 workers 8 vCPU/32 GiB/80 GiB) — the user asked for default node sizes.

### 08 — `08-dryrun.sh` (N4D dry run, workload)

```
RC=0  bytes=10924  mode=-rw-------
kinds: 1 NKPCluster + 5 Secrets, no kind: Cluster (same as t3: N-31 answered)
addressRanges <net>.71-75, control-plane host <net>.70, insecure: true
control plane 4 vCPU / 16Gi / 80Gi, worker 8 vCPU / 32Gi / 80Gi
registry mirror url https://<registry-host>/nutanix
cni as the CLI makes it: provider: Cilium / strategy: HelmAddon
```

### 09 — `09-cni-path-b.sh` — **my block broke the file, twice** (see L-01)

First attempt used `yq -i 'select(.kind == "NKPCluster") | (…path…) = "Flow"'`. In yq a top-level `select` **filters the document stream**, so the 5 Secret documents were dropped (10924 → 6182 bytes) and the CNI edit was the only change left.

### 10 — `10-server-dryrun.sh` (server dry run, NKPCluster alone)

```
denied: webhook.nkpcluster… -> cluster-defaulter.caren.nutanix.com -> cluster project policy defaulting:
        failed to resolve Prism Central version … prism credentials secret "skilltest-flow-b-pc-credentials" not found
```

The `nkp-flow-cni` I5 gap of `t3-flow-a` L-05 repeats for path B, as expected.

### 11 — `11-webhook-gate.sh` (lab rule)

```
Val kommander-validating/secrets.webhook.federation.kommander.mesosphere.io sideEffects=NoneOnDryRun
Val nkp-cluster-validating/webhook.nkpcluster.kommander.mesosphere.io sideEffects=None
Mut nkp-cluster-defaulting/webhook.nkpcluster.kommander.mesosphere.io sideEffects=None
(+ the azure/gatekeeper ones, sideEffects=None)
```

### 12 + 13 + 16 — the yq trap and the doc shape

`12-secrets.sh` failed: `failed to create typed patch object … .spec: field not declared in schema`. Block 16 showed why: **every Secret document had gained an empty `spec:`** from the second edit form (`16-cni-path-b-v2.sh`, the `?` on the array iterator does not stop yq from creating the `.spec` parent). The `.orig` file was clean (Secrets = `apiVersion,data,kind,metadata,type`).

### 17 — `17-cni-edit-safe.sh` (the form that works)

The `del`-style **path filter** form, tested on a scratch copy before the real file:

```bash
yq -i '(select(.kind == "NKPCluster") | .spec.capiCluster.topology.variables[] | select(.name == "clusterConfig") | .value.addons.cni.provider) = "Flow"' "$f"
```

```
yq RC=0 ; 6 docs ; Secrets keep apiVersion,data,kind,metadata,type (no spec)
cni: provider: Flow / strategy: HelmAddon
applied to ~/skilltest-flow-b-dryrun.yaml (11274 bytes, mode 600)
```

### 15 (re-run after 17) — `15-secrets.sh`

```
secret/skilltest-flow-b-pc-credentials … -for-konnector-agent, -image-registry-mirror-credentials   RC=0
```

### 18 — `18-server-dryrun.sh` (server dry run of the path-B NKPCluster)

```
-o name: nkpcluster.clusters.nkp.nutanix.com/skilltest-flow-b
after the webhooks: addons: ccm,clusterAutoscaler,cni,cosi,csi,konnectorAgent,nfd,serviceLoadBalancer
                    cni: Flow/HelmAddon   kubeProxy: disabled
cilium mentions in the object: 0
```

So the CAREN defaulting webhooks **accept `provider: Flow`** and do not add a Cilium value. The create gate is green.

### Plan for the create (written before the block runs)

- Block 19 (`19-create.sh`, CHANGES): run the create in tmux `nkp-skilltest-flow-b`, log `~/nkp-skilltest-flow-b-create.log`, applying **only the NKPCluster** (the Secrets already exist). Target: workspace namespace `skilltest-flow-dw97w` on `nkp-mgmt-01`; Prism Central makes 7 VMs; the CP VIP is `<net>.70`.
- Then the kubeconfig block of `nkp-install` SKILL "Set the kubeconfig variables" (workload), and the verify blocks.
- Expected duration: 3–13 min; the Flow CNI chart installs from the CAREN chart server through the CAREN Flow addon, not from a user HelmChartProxy.

### 19 — `19-create.sh` (the create)

```
nkpcluster.clusters.nkp.nutanix.com/skilltest-flow-b   RC_apply=0   16:10:15
5s: NKPCluster Reconciled, CAPI Cluster nkp-nutanix-v2.19.0, 1 machine
31s: 3 control-plane machines + 4 worker machines
```

The create is fast; `nkpclusters` shows `Reconciled` within seconds (the phase of the NKPCluster object, not the cluster).

### 20 + 21 — `20-status.sh`, `21-flow-addon.sh` (what CAREN renders for path B)

CAREN's addon controller makes the Flow HelmChartProxy **itself** — no user HCP, no `addons.cni` removal:

```
helmchartproxies in skilltest-flow-dw97w (all owned by Cluster/skilltest-flow-b):
  cosi-controller-<uid>  cosi 0.2.2                    container-object-storage-system
  flow-cni-<uid>         nutanix-flow-cni 1.1.0        kube-system          <- the Flow CNI addon of path B
  konnector-agent-<uid>  konnector-agent 1.4.2         ntnx-system
  metallb-<uid>          metallb 0.15.3                metallb-system
  multus-<uid>           multus 0.1.1                  kube-system
  node-feature-discovery-<uid>                          node-feature-discovery

flow-cni HCP spec:
  repoURL oci://helm-repository.caren-system.svc/charts
  chartName nutanix-flow-cni   version 1.1.0   namespace kube-system     <-- NOT flow-cni-system
  selector cluster.x-k8s.io/cluster-name=skilltest-flow-b
  options: install.createNamespace=true, takeOwnership=true, timeout 10m, upgrade.maxHistory 10
  valuesTemplate (the CAREN Flow template, rendered):
    nutanix-core-flow-ovn-kubernetes:
      k8sAPIServer: "https://<net>.70:6443"
      podNetwork: "192.168.0.0/16"        <-- NO /24 host prefix (path A / the guide use 192.168.0.0/16/24)
      serviceNetwork: "10.96.0.0/12"
  (no pull secret: dark site, the template adds one only when ImagePullSecretName is set)
```

**The path B failure:**

```
HRP nutanix-flow-cni-skilltest-flow-b-9724t  READY False
  HelmReleaseReady: pre-upgrade hooks failed: warning: Hook pre-upgrade
  nutanix-flow-cni/templates/crd-upgrade-serviceaccount.yaml failed: 1 error occurred:
        * namespaces "flow-cni-system" not found
```

Other HRPs at the same moment: cosi True, metallb True, multus True, nkp-cloud-provider-nutanix True, node-feature-discovery True, snapshot-controller True; `konnector-agent` and `nutanix-csi-storage` False (both need a working node/network); flow-cni False.

### 22 — `22-kubeconfig.sh` (nkp-install "Set the kubeconfig variables", workload)

```
~/skilltest-flow-b.conf (mode 600, 5602 B), CLUSTER_KUBECONFIG appended
mgmt kubeconfig ok
7 nodes, all NotReady, Ubuntu 24.04.5 LTS, containerd 2.3.1-d2iq.1
flow/ovn namespaces on the cluster: none
kube-system: control plane static pods Running, coredns 0/1 Pending, multus Init:0/1 (no CNI yet)
```

### 23 + 24 + 25 + 26 — the chart, read from the site mirror (read-only GET, in memory)

The CAREN chart-server manifest needs an `Accept: application/vnd.oci.image.manifest.v1+json` header, which `kubectl get --raw` cannot send (only `tags/list` works there). So I read the **same chart** `nutanix-flow-cni:1.1.0` from the site mirror (pushed in `t3-flow-a` step 2), through the Harbor token flow, and untarred it from a pipe.

```
chart has NO Namespace object for flow-cni-system
templates/_helpers.tpl:  define "flow-cni.namespace" -> {{ default "flow-cni-system" .Values.namespaceOverride | trunc 63 }}
templates/crd-upgrade-serviceaccount.yaml:  namespace: {{ include "flow-cni.namespace" . }}  + helm.sh/hook: pre-upgrade
values.yaml line 92-101:
  "# The chart does NOT ship a Namespace object: Helm owns the release namespace
   (created via `helm install --create-namespace` or pre-existing) ...
   NOTE: install with `--create-namespace` (or pre-create the namespace) so the
   namespace exists before the hook runs."
values.yaml: namespaceOverride: "" (default), nats.namespaceOverride: flow-cni-system,
             nutanix-core-flow-container-security.namespaceOverride: flow-cns-system,
             defaultMTU: 1400, crdUpgrade.enabled (block at line 73)
subchart charts/nutanix-core-flow-container-security/templates/namespace.yaml creates flow-cns-system
```

**So the cause is exact and is a namespace mismatch, not a CNI problem:** path A sets the Helm release namespace to `flow-cni-system` with `createNamespace: true`, so Helm creates the namespace **before** the chart's pre-upgrade hook runs (the hook's ServiceAccount lives in `flow-cni-system`). CAREN (path B) sets the release namespace to **`kube-system`** — which exists, so `createNamespace` does nothing — and does not set `namespaceOverride`; the hook then looks for `flow-cni-system`, which nothing creates. The chart's own values file names the requirement: "install with `--create-namespace` (or pre-create the namespace)".

### Plan for the fix attempt (written before the blocks run)

Goal: keep the CNI declared **in the cluster config** (path B) and give the chart the namespace its hook needs. No HelmChartProxy from me.

1. Block 27 (`27-ns.sh`, CHANGES, the **workload** cluster only): create namespace `flow-cni-system`. Nothing else. This is the condition the chart documents.
2. Block 28 (`28-watch.sh`, READ-ONLY): watch the `flow-cni` HCP/HRP for 2–3 min. Flux retries a failed release, so the HRP may recover with no further action.
3. If it does not retry: block 29 (`29-hrp-reset.sh`, CHANGES, workload cluster namespace only) deletes the `HelmReleaseProxy nutanix-flow-cni-…`; CAAPH recreates it from the HCP (the HCP is unchanged).
4. Then the remaining check of the values template: `podNetwork: 192.168.0.0/16` without the `/24` host prefix. If the chart's `ovn-config` ends up with a wrong per-node size, the fix stays inside path B: `addons.cni.values.sourceRef` → a ConfigMap with the full Flow values (including `podNetwork: 192.168.0.0/16/24`). Plan written here; block only if needed.
5. Report to the user either way: path B works with a namespace prerequisite, or it does not (with the exact evidence above).

### 27 + 28 — the namespace chain

Block 27 created `flow-cni-system` on the workload cluster. Block 28 (after ~100 s) shows Flux **did** retry the release, and it moved one step further:

```
Ready=False * HelmReleaseReady:
  * pre-upgrade hooks failed: warning: Hook pre-upgrade
    nutanix-flow-cni/charts/nutanix-core-flow-ovn-kubernetes/templates/crd-upgrade-serviceaccount.yaml failed:
    1 error occurred: * namespaces "ovn-kubernetes" not found
workload namespaces: flow-cni-system Active (created by me); no ovn-kubernetes, no flow-cns-system
nodes: 7 NotReady
```

So the chart's hooks need a **chain** of namespaces, and CAREN's release namespace (`kube-system`) creates none of them:

| Subchart | Hook namespace | Who creates it in path A |
|---|---|---|
| `nutanix-flow-cni` | `flow-cni-system` | the HCP namespace + `install.createNamespace: true` |
| `nutanix-core-flow-ovn-kubernetes` | `ovn-kubernetes` | ? (not created by any Namespace template of the chart — see below) |
| `nutanix-core-flow-container-security` | `flow-cns-system` | its own `templates/namespace.yaml` |

### Plan addendum 2 (written before the block runs)

- Block 29 (`29-ns2.sh`, CHANGES, workload cluster only): create `ovn-kubernetes` and `flow-cns-system` as well, then watch the release retry. Rationale: the chart's hooks run before any normal resource, so a Namespace object inside the chart cannot satisfy them; only pre-existing namespaces can.
- If the release then installs, check the resulting namespaces placement (release resources land in `kube-system` for path B, `flow-cni-system` for path A) and the `ovn-config` CIDR/MTU (the `/24` host-prefix question).

### 29 + 30 + 31 — the second wall, and the chart's hook model

Block 29 created `ovn-kubernetes` and `flow-cns-system`; the retry then got past the ServiceAccount hooks and stopped on the next hook:

```
pod/flow-cni-crd-hook-r5j8p  Pending 2m  (flow-cni-system)
event: 0/7 nodes are available: 7 node(s) had untolerated taint(s)
node taints: node.kubernetes.io/not-ready:NoSchedule on all 7 (+ control-plane on the 3 CPs)
job tolerations (chart values crdUpgrade.tolerations): ONLY node-role.kubernetes.io/control-plane
```

Reading the chart's hook annotations (block 31, chart from the mirror):

```
namespace-labeler-hook.yaml       : pre-install, pre-upgrade   (values: "always tolerates any taint")
crd-upgrade-{serviceaccount,rbac,secret,configmap,job}.yaml : pre-upgrade ONLY, for the 3 subcharts
ovs-node prepull-{ds,job}.yaml     : pre-upgrade ONLY
```

So a **clean install** runs only the namespace-labeler hook, which tolerates every taint. The CRD-upgrade hooks (which need a Ready node) run only on **upgrade**. The deadlock here is a consequence of the **first** attempt failing: every later attempt is an `upgrade`, so it now needs a schedulable node, and a node is only Ready after the CNI is installed.

The first attempt failed on the namespace chain (the messages we saw). Cause confirmed: CAREN releases the chart into `kube-system`, and the chart needs `flow-cni-system`, `ovn-kubernetes`, `flow-cns-system` to exist before its hooks.

### Plan addendum 3 (written before the block runs)

- Block 32 (`32-hrp-reset.sh`, CHANGES, management cluster, `skilltest-flow-dw97w` only): delete `helmreleaseproxy nutanix-flow-cni-skilltest-flow-b-9724t`. The HCP stays (it is CAREN's, unchanged). CAAPH recreates the HRP from the HCP, and that is a **fresh install**: only the taint-tolerant labeler hook runs, then the chart's normal resources install OVN on hostNetwork, the nodes go Ready, and no CRD-upgrade hook is needed on install.
- Block 33 (READ-ONLY): watch the HRP, nodes, and the flow pods.
- The three namespaces stay pre-created (that is path B's prerequisite; it cannot be expressed in `addons.cni`, whose schema has only provider/strategy/values/imagePullCredentials).

### 32 + 33 + 34 — the HRP delete left a terminating object (my mistake, recorded)

`kubectl delete helmreleaseproxy nutanix-flow-cni-…` returned "deleted", but CAAPH uses a finalizer:

```
nutanix-flow-cni-skilltest-flow-b-9724t  created=16:11:23Z  deleting=16:19:05Z
finalizers=["helmreleaseproxy.addons.cluster.x-k8s.io"]
HCP flow-cni-<uid> still there, condition False/IssuesReported
workload: job flow-cni-crd-hook Running 0/1 (5m31s) in flow-cni-system
```

So the HRP is in `Terminating`; the rule is not to remove a finalizer. The pending **hook Job** of the failed upgrade is the likely blocker of the remote uninstall (Helm's uninstall waits for release resources, including this hook resource).

### Plan addendum 4 (written before the block runs)

- Block 35 (`35-hook-job-cleanup.sh`, CHANGES, **workload** cluster, namespace `flow-cni-system` only): delete the Job `flow-cni-crd-hook` (its pod is Pending and unschedulable; it is the artifact of one failed upgrade attempt, not a cluster object). This is the standard cleanup of a failed Helm hook, not a finalizer removal.
- Block 36 (READ-ONLY): watch the HRP finalizer and CAAPH. If the HRP clears and CAAPH makes a new HRP, that attempt is a **fresh install** (labeler hook only) and the chart should install.
- If the HRP stays terminating: read the CAAPH controller log (read-only) and stop before anything else; report the state rather than force it.

### 35 + 36 — the deadlock is permanent in the current cluster state

Block 35 (read-only part): CAAPH does **in-process Helm**, not Flux — the controller log says

```
"Release is in failed state, attempting upgrade to fix it" … "Upgrading with Helm" (helm_client.go:472/436)
```

and the workload cluster now holds **release versions v39 … v47+** of `flow-cni` in `kube-system` (about 40 failed upgrade attempts in 10 min). Block 36 deleted the pending `flow-cni-crd-hook` Job; CAAPH recreated the hook and started `ovn-k8s-crd-hook` in `ovn-kubernetes` on the next attempt. The HRP stays `Terminating` (deletionTimestamp 16:19:05Z, finalizer held by the controller; I do not remove it).

Also read: the **namespace-labeler** hook is `hostNetwork: true` (so it can run before any CNI). The CRD-upgrade hook Jobs are not hostNetwork and have only the control-plane toleration, so they can never schedule while the nodes are `NotReady` — and the nodes are NotReady exactly because the CNI is not installed. **Every attempt after a failed first install is an upgrade, so path B cannot recover by itself.**

### Plan addendum 5 (written before the blocks run): one honest re-test of path B with its prerequisite met

The remaining question is whether path B works when its namespace prerequisite is satisfied **before** CAAPH's first attempt. Re-create the cluster once and pre-create the three namespaces as early as the workload API answers.

1. Block 37 (`37-delete.sh`, CHANGES, my cluster only): `nkp delete cluster skilltest-flow-b` in tmux, log `~/nkp-skilltest-flow-b-delete.log`. Then verify: no NKPCluster/CAPI Cluster, VIP and LB free, PC VMs gone, the CAREN HCP and HRPs gone.
2. Block 38 (`38-apply-and-watch.sh`, CHANGES): re-apply the 5 Secrets and the NKPCluster (same dry-run file, unchanged), and start a tmux watcher on the operator host that, every 5 s for up to 10 min, runs `nkp get kubeconfig` and creates `flow-cni-system`, `ovn-kubernetes`, `flow-cns-system` on the workload cluster as soon as the API answers; the watcher logs which namespace it created and when.
3. Block 39 (READ-ONLY): the result — flow HCP/HRP conditions, nodes, flow pods, `ovn-config`.
4. Report either way. If the first install succeeds, path B works **with three pre-created namespaces** and CAREN's `podNetwork` value still needs the `/24` check. If it fails again, path B is not usable as shipped, and I say that with the evidence.

### 37 + 38 + 39 — delete of the wedged cluster

```
16:25:06 delete started (tmux), 16:25:17 RC=0   -> 11 s, 7 VMs
after: no NKPCluster, no CAPI Cluster, no Machines, no HCP with the name; CP VIP 000, LB first IP 000
the 3 terminating HRPs of the deleted cluster still show (deleting=16:25:17Z), the flow one from 16:19:05Z
```

### 40 — re-create with the three namespaces pre-created as early as possible

Plan as written above. The watcher script (`~/nkp-skilltest-flow-b-nswatch.sh`, tmux `nkp-skilltest-flow-b-ns`) polls `nkp get kubeconfig` every 4 s and creates `flow-cni-system`, `ovn-kubernetes`, `flow-cns-system` as soon as the workload API answers.

```
16:27:27 watcher started ; 16:27:29 applied (5 Secrets + NKPCluster)
```

### 41 + 42 — **path B installs**

```
flow HCP flow-cni-<new uid>            : (see block 42) 
flow HRP nutanix-flow-cni-…-qqrt7      : READY True           <-- the new one
helm release versions of flow-cni      : 1                     <-- one successful install, no failed upgrades
nodes: 6 of 7 Ready (1 control plane NotReady at that moment)
flow-cni-system: flow-cni-<pod> Running, nats-0/1/2, conntrack-collector DS 7/7
flow-cns-system: flow-cni-flow-processor ImagePullBackOff
ovn-kubernetes: ovnkube-node 7 desired / 6 ready, ovs-node 7 desired / 6 ready
kube-multus-ds 7/7, multus 7/7, no cilium DaemonSet, no kube-proxy DaemonSet
ovn-config: k8s_apiserver https://<net>.70:6443, mtu 1400, net_cidr 192.168.0.0/16, svc_cidr 10.96.0.0/12,
            host_network_namespace ovn-host-network
```

So: **path B works when the three namespaces exist before CAAPH's first attempt.** The chart installs, OVN comes up, the nodes go Ready.

Two facts to record from this run:
- `net_cidr: 192.168.0.0/16` — CAREN's `podNetwork` value carries **no `/24` host prefix** (path A had `192.168.0.0/16/24`). Everything else in `ovn-config` is identical. Watch the pod IPs for the per-node size.
- The `t3-flow-a` L-07 resolver break came back, unchanged and with the same signature:

```
flow-cns-system flow-cni-flow-processor: Failed to pull "nutanix/flow-container-security:1.1.0" …
  dial tcp: lookup <registry-host> on 127.0.0.53:53: server misbehaving
kommander-flux prereq-wait-…, flux-oci-mirror-cert-gen: same error for mesosphere/kommander2-kubetools
```

### Plan for the resolver fix (written before the block runs; the user allowed this fix on this cluster's nodes only)

- Block 43 (READ-ONLY): the registry IP as the nodes see it (from the operator host) and whether `natsio/nats-box:0.14.1` is already on the nodes (a pod that uses it in `flow-cni-system`).
- Block 44 (`44-hosts-fix.sh`, CHANGES, **this cluster only**): DaemonSet `kube-system/registry-hosts-fix` with `hostPath /etc/hosts`, privileged, image `natsio/nats-box:0.14.1` (already on the nodes, so it does not need a working pull), which writes ONE line `<registry-ip> <registry-host>` into the node's `/etc/hosts` using the trailing-newline-safe writer of `t3-flow-a` L-14 (`awk` prints the missing newline, append only when absent, write back with `cat >`, never `sed -i`).
- Block 45 (READ-ONLY): prove the node resolver works again (the same `dnsPolicy: None` + `127.0.0.53` hostNetwork probe as `t3-flow-a`), then delete the stuck pods so the controllers retry at once.
- Block 46 (READ-ONLY): the platform: HelmReleases, KommanderCluster, NKPCluster phase, nodes.

### 43 + 44 — the hosts fix, and then the node network died

Block 43b (after fixing my own missing `source ~/nkp-skilltest-flow-b.env`): registry IP `<registry-ip>`, `natsio/nats-box:0.14.1` already running in `flow-cni-system`, 0 nodes NotReady at that moment.

Block 44 created the DaemonSet `kube-system/registry-hosts-fix` (privileged, `hostPath /etc/hosts`, nats-box image, trailing-newline-safe writer). The apply returned RC=0; 25 s later **every** kubectl call from the operator host failed with `Unable to connect to the server`.

```
from the operator host:  vip https=000, ping of all 7 node IPs fails
ip neigh: <net>.81 REACHABLE (the one worker whose ovnkube-node was not ready yet)
          <net>.86 .89 .92 .95 .101 .102 FAILED (all the other nodes)
gateway .1 ok, Prism Central .39 ok, management VIP ok  -> the operator host's own network is fine
from the management cluster: all 7 Machines Ready=True, NodeHealthy=True, APIServerPodHealthy=True
```

So the nodes are alive and their kubelets talk to the API (CAPI's remote probe succeeds), but they **stop answering ARP on their VLAN address** as soon as `ovnkube-node` comes up — exactly the nodes where OVN took the uplink, and not the one where it had not yet.

Correlation with the value difference:

```
path A (skilltest-flow-a): ovn-config net_cidr = 192.168.0.0/16/24     nodes stayed reachable from the operator host
path B (skilltest-flow-b): ovn-config net_cidr = 192.168.0.0/16        nodes became unreachable
chart: charts/nutanix-core-flow-ovn-kubernetes/templates/ovn-setup.yaml:  net_cidr: {{ .Values.podNetwork }}
       chart default values: podNetwork: 10.244.0.0/16/24   <- the chart expects CIDR/hostPrefix
       CAREN values template: podNetwork: "{{ .PodCIDR }}"  -> renders the plain cluster CIDR
```

I do **not** claim this is proven: the hosts-fix DaemonSet was created 25 s before the network died, so it is the other candidate. The evidence for the value difference: only the nodes with a ready `ovnkube-node` lost ARP, and .81 (not ready) kept it; the DaemonSet wrote one line into `/etc/hosts` on all 7 nodes including .81, which stayed reachable.

### Plan for the last experiment (written before the blocks run)

Test path B once more with the value the chart expects, supplied **inside the cluster config** (`addons.cni.values.sourceRef`, no HelmChartProxy):

1. Block 46 (`46-cleanup-44.sh`, CHANGES, this cluster only): delete the `registry-hosts-fix` DaemonSet if the API answers; if not, it goes with the cluster delete (it is in `kube-system`).
2. Block 47 (`47-delete.sh`, CHANGES): `nkp delete cluster skilltest-flow-b` (works through the management cluster, as the first delete did).
3. Block 48 (`48-values-source.sh`, CHANGES, management cluster): create ConfigMap `skilltest-flow-b-flow-values` in `skilltest-flow-dw97w` with the full Flow values (`k8sAPIServer`, `podNetwork: "192.168.0.0/16/24"`, `serviceNetwork`), and put `addons.cni.values.sourceRef` (kind ConfigMap, that name) into the dry-run file.
4. Block 49 (`49-recreate.sh`, CHANGES): re-apply Secrets + NKPCluster and start the namespace watcher again.
5. Block 50 (READ-ONLY): the result — if the nodes stay reachable and `net_cidr` carries `/24`, path B works with two documented prerequisites; if the network dies again, the cause is elsewhere and path B is not usable here. Either way, report and stop.

### 46 + 47 — cleanup and the second delete

`registry-hosts-fix` could not be deleted (the API was unreachable); it went with the cluster. The delete through the management cluster worked (`16:38:32 → 16:39:52`, RC=0, 80 s). After it: only the 2 mirror Secrets stayed (`-oci-cert`, `-oci-creds`), VIP and LB free.

### 48 + 49 — path B with `addons.cni.values.sourceRef`

```
ConfigMap skilltest-flow-dw97w/skilltest-flow-b-flow-values:
  nutanix-core-flow-ovn-kubernetes:
    k8sAPIServer: "https://<net>.70:6443"
    podNetwork: "192.168.0.0/16/24"
    serviceNetwork: "10.96.0.0/12"
NKPCluster addons.cni: provider Flow / strategy HelmAddon /
  values.sourceRef {kind: ConfigMap, name: skilltest-flow-b-flow-values}
re-create 16:40:53, namespaces watcher started before the apply
```

### 50 — the decisive result: **path B works**

```
flow HRP nutanix-flow-cni-…-hvgst : Ready=True, ClusterAvailable=True, HelmReleaseReady=True
helm release versions of flow-cni: 1                       <- one clean install
nodes: 7/7 Ready
ovn-config: mtu 1400, net_cidr 192.168.0.0/16/24, svc_cidr 10.96.0.0/12, k8s_apiserver https://<net>.70:6443
daemonsets: ovnkube-node 7/7, ovs-node 7/7, flow-cni-conntrack-collector 7/7, kube-multus-ds 7/7, multus 7/7
            (no cilium, no kube-proxy)
all 7 nodes answer ping AND ARP from the operator host (the earlier break is gone)
```

**Cause of the earlier node-network break is proven:** the only difference between that run and this one is `podNetwork` (`192.168.0.0/16` → `192.168.0.0/16/24`). With the plain CIDR, all nodes whose `ovnkube-node` was ready stopped answering ARP; with the chart's expected `CIDR/hostPrefix` form, the host network stays intact. The hosts-fix DaemonSet is not implicated (it was created in the broken run 25 s before, and the same fix ran on all 7 nodes including the one that kept answering).

The `t3-flow-a` L-07 resolver break came back, same signature (11 events with `server misbehaving`, `flow-cns-system/flow-cni-flow-processor` + the whole `kommander-flux` namespace in `ImagePullBackOff` + `ErrImagePull`).

### Plan for the resolver fix on this cluster (already approved by the user)

Same DaemonSet as `t3-flow-a` (block 44 of this task, which is proven to write the line correctly), on **this** cluster's nodes only; then delete the stuck pods so the controllers retry; then the `nkp-flow-cni` step 4 checks and the platform check.

### 44 (re-run) + 51 — the resolver fix, on this cluster only

DaemonSet `kube-system/registry-hosts-fix` created; 7/7 pods Running; one node's `/etc/hosts` after the write (from the pod's own log):

```
::1 ipv6-localhost ipv6-loopback
127.0.0.1 localhost
127.0.0.1 skilltest-flow-b-<node>
127.0.0.1 kubernetes
<net>.4 <registry-host>
```

`written: <registry-ip> <registry-host>` — the file kept its other lines (the `t3-flow-a` L-14 traps do not come back with the `awk` + `cat >` writer). Then the 8 stuck pods were deleted; 20 s later `flow-cns-system/flow-cni-flow-processor` 1/1 and 9 of 12 `kommander-flux` pods 1/1.

### 52 — the `nkp-flow-cni` step 4 Done-when and `nkp-install` verify

```
HCP flow-cni-<uid>       Ready=True, HelmReleaseProxiesReady=True, HelmReleaseProxySpecsUpToDate=True
HRP nutanix-flow-cni-…-hvgst  READY True
nodes 7/7 Ready
flow-cni-system: flow-cni 1/1, nats-0/1/2 2/2, nats-box 1/1, conntrack-collector 7/7
flow-cns-system: flow-cni-flow-processor 1/1
kube-system: kube-multus-ds 7/7, multus 7/7 ; ovn-kubernetes: ovnkube-node 7/7, ovs-node 7/7
no cilium DaemonSet, no kube-proxy DaemonSet
ntnx-system: konnector-agent 1/1 Running, nutanix-csi-controller 8/8
KommanderCluster skilltest-flow-b: Joined, FluxInstalled=True, AttachmentCompleted=True, LoggingStackVersionReconciled=True
StorageClass nutanix-volume (default); metallb IPAddressPool present
7 nodes Ready, 111 pods Running
```

Then the platform apps: `helmreleases` on the cluster go 4/12 Ready in the first minutes (cert-manager True, gatekeeper in progress); the NKPCluster sits in `Reconciling Platform Applications`, which is the same phase `skilltest-flow-a` (path A) had for 30 minutes. The remaining wait is the platform, not the CNI.

### Final state (16:59, ~19 min after the apply)

```
helmreleases on the cluster: 19, all READY True
HRPs: 9, all Ready True (cosi, konnector-agent, metallb, multus, nkp-cloud-provider-nutanix,
      node-feature-discovery, nutanix-csi-storage, nutanix-flow-cni, snapshot-controller)
KommanderCluster: Joined, FluxInstalled=True, IngressAddressReady=True, IngressCertificateReady=True
                  PlatformAppDeploymentsReady=False / PlatformVersionReconciled=False (still converging)
NKPCluster: Reconciling Platform Applications (the same phase path A held for ~30 min)
service kommander-traefik: EXTERNAL-IP <net>.71 (first IP of the LB range) -> MetalLB L2 works
http :80 = 301, https :443 = 404 (Traefik answers) -> the pod/service/LB data plane works through Flow CNI
cp vip :6443 = 200
pods with ImagePullBackOff: 0 ; 7/7 nodes Ready
left in place: kube-system/registry-hosts-fix (the name-resolution fix; remove with
               kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n kube-system delete ds registry-hosts-fix
               — but then the cluster cannot pull a new image)
```

## Learnings

### L-01 `[nkp-skill nkp-flow-cni/SKILL.md step 3, path B]` — **F-02 is answered: path B works, with three prerequisites that the skill does not know**

The answer, measured on 2.19.0 + chart `nutanix-flow-cni` 1.1.0:

1. `addons.cni: {provider: Flow, strategy: HelmAddon}` in the `clusterConfig` variable is accepted by the schema **and** by the CAREN defaulting webhooks. CAREN then creates its own `HelmChartProxy flow-cni-<uid>` (namespace `kube-system`, chart 1.1.0, no pull secret on a dark site) and a `HelmReleaseProxy`. No user HCP, no `addons.cni` deletion.
2. **Three namespaces must exist on the workload cluster before CAAPH's first Helm attempt:** `flow-cni-system`, `ovn-kubernetes`, `flow-cns-system`. CAREN releases the chart into `kube-system`, and the chart ships **no Namespace object** for `flow-cni-system` (its own `values.yaml` says "install with `--create-namespace` (or pre-create the namespace)"). Without them the install fails with `Hook pre-upgrade …crd-upgrade-serviceaccount.yaml failed: namespaces "flow-cni-system" not found`, then `…nutanix-core-flow-ovn-kubernetes…: namespaces "ovn-kubernetes" not found`.
3. **`podNetwork` must carry the per-node prefix.** CAREN's values template renders `podNetwork: "{{ .PodCIDR }}"` → `192.168.0.0/16`, while the chart/guide expect `CIDR/hostPrefix` (`192.168.0.0/16/24`). With the plain CIDR the install **succeeds** but the nodes stop answering ARP on their VLAN address as soon as `ovnkube-node` is ready (7 nodes: 6 lost ARP, the one whose ovnkube-node was not ready kept it) — the cluster becomes unreachable from outside while CAPI still reports the Machines healthy. With `addons.cni.values.sourceRef` → ConfigMap `{nutanix-core-flow-ovn-kubernetes: {k8sAPIServer, podNetwork: "192.168.0.0/16/24", serviceNetwork}}` everything is green.

And the reason the order is not optional: **any** failure puts the Helm release in `failed`, and CAAPH then retries with `helm upgrade`, whose CRD-upgrade hooks (pre-upgrade only) need a schedulable pod, tolerating only the control-plane taint — impossible while the nodes are `NotReady` for lack of a CNI. That deadlock is permanent (40+ failed release versions in 10 min), and deleting the `HelmReleaseProxy` does **not** reset it (finalizer + the controller keeps retrying). The only reset is a cluster delete and re-create.

Proposed text for step 3 (replaces the one-line path B cell):

> **B (works, with prerequisites).** Set `addons.cni: {provider: Flow, strategy: HelmAddon}` in the `clusterConfig` variable of the `NKPCluster`. CAREN then installs chart `nutanix-flow-cni` from the CAREN chart server into namespace `kube-system` and makes its own HelmChartProxy. Before its first attempt, three things must be true, or the release fails once and can never recover:
> 1. Namespaces `flow-cni-system`, `ovn-kubernetes`, `flow-cns-system` exist on the new cluster. Create them as soon as the workload API answers (`nkp get kubeconfig` then `kubectl create namespace`), in a loop that runs while the cluster is created.
> 2. `addons.cni.values.sourceRef` points at a ConfigMap in the cluster namespace with the full Flow values, including `podNetwork: "<podCIDR>/<hostPrefix>"` (for example `192.168.0.0/16/24`). CAREN's template passes the plain CIDR and the nodes then lose the host network.
> 3. Do not retry by deleting the HelmReleaseProxy: it has a finalizer and CAAPH keeps upgrading a failed release. If the first install fails, delete the cluster and create it again.
>
> Path A needs none of this; it costs one HelmChartProxy file.

### L-02 `[nkp-skill nkp-flow-cni/SKILL.md "Common failures"]` — two new rows

| Symptom | Cause | Fix |
|---|---|---|
| `pre-upgrade hooks failed … namespaces "flow-cni-system" / "ovn-kubernetes" not found` | The Helm release namespace is `kube-system` (CAREN) and the chart's hooks put their ServiceAccounts in those namespaces; no Namespace object exists for them | Pre-create the three namespaces **before** the first install (path B, L-01). After a failure this cannot be repaired: delete and re-create the cluster |
| The node VLAN address stops answering ARP/ping right after `ovnkube-node` becomes ready (CAPI still shows the Machines healthy) | `podNetwork` without the `/hostPrefix` (`192.168.0.0/16` instead of `192.168.0.0/16/24`) — CAREN's value template passes `.PodCIDR` verbatim | `addons.cni.values.sourceRef` ConfigMap with the full values; check `net_cidr` in `ovn-kubernetes/ovn-config`: it must carry three parts |

### L-03 `[nkp-skill nkp-flow-cni/references/install.md]` + `[fact]` — the `yq` write form for a multi-document dry-run file

Both of these are wrong and cost me two blocks:

```bash
# WRONG 1: a top-level select filters the document stream -> the 5 Secret documents disappear
yq -i 'select(.kind == "NKPCluster") | (…path…) = "Flow"' f.yaml
# WRONG 2: the ? on the iterator does not stop yq from creating .spec in every Secret document,
#          and the server then rejects them: ".spec: field not declared in schema"
yq -i '(.spec.capiCluster.topology.variables[]? | select(…) | .value.addons.cni.provider) = "Flow"' f.yaml
# RIGHT: the path-filter form (the same shape as the I3 del() block)
yq -i '(select(.kind == "NKPCluster") | .spec.capiCluster.topology.variables[] | select(.name == "clusterConfig") | .value.addons.cni.provider) = "Flow"' f.yaml
```

Add to I3: "check `grep -c '^kind:'` before and after the edit (6 documents) and that no Secret document has a `spec:` line".

### L-04 `[fact]` — read the chart from the site mirror, not from the CAREN chart server

`kubectl get --raw` cannot send `Accept: application/vnd.oci.image.manifest.v1+json`, so `…/v2/charts/<chart>/manifests/<ver>` returns `NotFound` (only `tags/list` works). The same chart is in the site mirror (`<project>/nutanix-flow-cni:1.1.0`) and can be read with the Harbor token flow and untarred from a pipe — that is how the hook and values facts of this task were measured. Worth one line in `nkp-airgap` (A-30 area) and in `nkp-troubleshooting` ("read a chart without a cluster").

### L-05 `[nkp-skill nkp-install/references/nutanix.md N5]` — `--insecure` is missing (repeat of `t3-flow-a` L-10)

The N5 body has no `--insecure` and this site's PC certificate has no SAN, so the create as written fails on a certificate error. I added it again. One line in N5 and a `${PC_CA_FILE:+…}` guard would remove the improvisation.

### L-06 `[fact]` — the `t3-flow-a` L-07 resolver break is path-independent, and the same fix works

Path B shows the identical signature (`lookup <registry-host> on 127.0.0.53:53: server misbehaving` for `flow-cns-system/flow-cni-flow-processor` and the whole `kommander-flux` namespace). The `/etc/hosts` DaemonSet fixes it on this cluster in under a minute (8 pods deleted, 20 s later `flow-cni-flow-processor` 1/1 and 9 of 12 Flux pods 1/1). This confirms that the break is Flow CNI's host-network takeover, not the CNI install method, and it strengthens the proposal of `t3-flow-a` L-07 (one bullet in `nkp-flow-cni` step 4 and one row in "Common failures").

### L-07 `[fact]` — timings for path B

- create → flow HRP Ready with a single release version: **~3 min** (the CNI itself).
- create → all 19 platform HelmReleases Ready: **~19 min**; the NKPCluster phase `Reconciling Platform Applications` lasts about the same as path A (~19+ min against 31 min).
- one failed first install costs ~10 min and a cluster delete: there is no faster reset (see L-01 point 3).

## Status

`done` for the user's request. **Path B works** on NKP 2.19.0: `skilltest-flow-b` is in workspace `skilltest-flow` (`skilltest-flow-dw97w`) on `nkp-mgmt-01`, with Flow CNI declared in the cluster's own `clusterConfig` (`addons.cni.provider: Flow`) and **no user HelmChartProxy**; CAREN's own HCP installs chart `nutanix-flow-cni` 1.1.0. 7/7 nodes Ready, all 9 CAREN HRPs Ready, 19/19 platform HelmReleases Ready, MetalLB gives Traefik `<net>.71`, Traefik answers on :80/:443, no Cilium and no kube-proxy.

But it does **not** work out of the box, and the extra work is not cosmetic:
1. three namespaces must be pre-created on the workload cluster before CAREN's first install (otherwise: hook failure, then a permanent failed-release deadlock that only a cluster delete clears);
2. `addons.cni.values.sourceRef` must supply `podNetwork: "<podCIDR>/24"` (otherwise the nodes lose their host network as soon as OVN is up);
3. the site's node resolver problem (open item of `t3-flow-a`, L-07 there) is unchanged and needed the same `/etc/hosts` DaemonSet, left in place on this cluster.

Left behind, as usual and allowed: the cluster, its 5 Secrets + 2 mirror Secrets, the CAREN HCP/HRPs, the values ConfigMap `skilltest-flow-b-flow-values`, the operator-host files (create script, dry-run + `.orig`, `.conf`, delete/ns logs, watcher script), and `kube-system/registry-hosts-fix` on the cluster. No skill file edited, nothing committed, no secret printed, no finalizer removed.
