# Batch 2 re-run answers

## nkp-upgrade U1

Skill files read: `_shared/RULES.md`, `nkp/SKILL.md`, `nkp-upgrade/SKILL.md`, `nkp-upgrade/references/clusterclass.md`, `nkp-upgrade/references/dockerhub.md`, `nkp-upgrade/references/stopped.md`.

**Skill: `nkp-upgrade`.**

Facts I state:

- 2.18.0 is the only source version for 2.19.0. You can skip patch versions, not minor versions. [pdf p.1011-1012]
- Order: Kommander first, then the management cluster, then the two workload clusters, one cluster at a time. [pdf p.1017-1022]
- An upgrade replaces every node. There is no rollback: an error does not start an automatic repair. [pdf p.1044]
- During the Kommander upgrade the NKP UI and the APIs can be unavailable, and a custom domain can stop for some minutes. [pdf p.1018]
- Connected site with no registry mirror: gate G2 (Docker Hub credentials) applies to you. Air-gapped sites skip it.

### Step 1 (now): versions and paths

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
nkp version
nkp upgrade cluster nutanix --help | head -1
kubectl --kubeconfig "$MGMT_KUBECONFIG" get nkpclusters -A -o custom-columns='NAMESPACE:.metadata.namespace,NAME:.metadata.name,NKP:.status.platformVersion,K8S:.status.kubernetesVersion,PHASE:.status.phase,MGMT:.metadata.labels.kommander\.d2iq\.io/host'
kubectl --kubeconfig "$MGMT_KUBECONFIG" get clusters.cluster.x-k8s.io -A
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n kommander get helmrelease kommander
kubectl --kubeconfig "$MGMT_KUBECONFIG" get workspaces -o custom-columns='WORKSPACE:.metadata.name,NAMESPACE:.status.namespaceRef.name'
```

What each line tells me:

- The `nkp` line of `nkp version` must show `v2.19.0`. The CLI version must be the same as the version that you upgrade to. On a connected site you download the 2.19.0 CLI from the Nutanix portal. [pdf p.1018]
- `nkp upgrade cluster nutanix --help | head -1` prints the target Kubernetes version (1.36.2 for 2.19.0). [live 2.19.0]
- The CLUSTERCLASS column of `get clusters` gives the path of each cluster: a value → ClusterClass path; no value → non-ClusterClass path. AHV clusters from 2.18 do make ClusterClass clusters (`nkp-nutanix-v2.18.0`), but I check, I do not assume (UNKNOWN P-06).
- The last line gives the namespace of workspace `prod`. I need that namespace for every `-n "$WORKSPACE_NS"` block below. [pdf p.489]

### Step 2 (now): gates

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" get nkpclusters -A
kubectl --kubeconfig "$MGMT_KUBECONFIG" get upgradeplans -A
kubectl --kubeconfig "$MGMT_KUBECONFIG" get helmreleases -A | awk 'NR==1 || $4!="True"'
kubectl --kubeconfig "$MGMT_KUBECONFIG" get machines -A | awk 'NR==1 || $0 !~ /Running/'
kubectl --kubeconfig "$MGMT_KUBECONFIG" get nodes | awk 'NR==1 || $2!="Ready"'
kubectl --kubeconfig "$MGMT_KUBECONFIG" get pdb -A | awk 'NR==1 || $(NF-1)=="0"'
kubectl --kubeconfig "$MGMT_KUBECONFIG" get gitrepositories -A
kubectl --kubeconfig "$MGMT_KUBECONFIG" get appdeployments -A | grep -E 'cloudnative-pg|ai-navigator|nkp-insights'
```

- Healthy: PHASE `Reconciled` for every NKPCluster, and only header lines in the other lists. An UpgradePlan that is not `Upgraded` or `Failed` means an upgrade is already running; then we do not start one.
- An AHV 2.18 cluster needs one Prism Central project for the control plane and all pools (gate G3). The block is in the skill; it needs `jq`. I run it after you give me the cluster names.

Docker Hub credentials (gate G2, connected site):

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" get nkpclusters -A -o custom-columns='NAMESPACE:.metadata.namespace,NAME:.metadata.name,MIRROR:.spec.capiCluster.topology.variables[?(@.name=="clusterConfig")].value.globalImageRegistryMirror.url'
kubectl --kubeconfig "$MGMT_KUBECONFIG" get secrets -A | grep dockerhub-nutanix-credentials
for v in NUTANIX_REGISTRY_USERNAME NUTANIX_REGISTRY_TOKEN; do if [ -n "$(printenv "$v")" ]; then echo "set: $v"; else echo "MISSING: $v"; fi; done
```

Without these credentials the Kommander upgrade stops with "docker.io/nutanix credentials are missing for N cluster(s)". [pdf p.1017]

### Questions

1. Do you confirm the target `v2.19.0`? After your "yes" I append `NKP_TARGET_VERSION='v2.19.0'` to `~/nkp-site.env` (rule 4). I show the append block, you approve, then I run it.
2. What are the names of the management cluster and of the two workload clusters in workspace `prod`? I need the cluster env files (`~/nkp-<cluster>.env`), one for each cluster.
3. Does Flux apply the CAPI objects of a workload cluster from a Git repository (gate G4)? If yes, the order changes: turn off Flux pruning **before** the Kommander upgrade. [pdf p.1037]
4. Do any clusters run AI Navigator or NKP Insights (gate G6: CloudNativePG must be on)?
5. Which Prism Central project does each AHV cluster use, and do the control plane and all pools use the same one? [pdf p.1015]
6. Does the Prism Central role that NKP uses have the permissions of 2.18 **and** of 2.19 (gate G8)? [pdf p.1009]
7. Is the 2.19.0 Rocky Linux image for Kubernetes 1.36.2 in Prism Central, with the name from the portal unchanged (gate G7)? [pdf p.1019]

### Plan of the changes (each step stops for your "yes")

| Step | Command | Target | Result |
|---|---|---|---|
| 3 | `nkp update cluster nutanix-registry-credentials --all-namespaces` | management cluster, all clusters | the Docker Hub Secret on every cluster |
| 4 | `nkp upgrade kommander` | management cluster | CAPI, ClusterClasses, platform apps on 2.19.0 |
| 5 | `nkp upgrade cluster nutanix` (management cluster) | management cluster | every management node replaced |
| 6 | `nkp upgrade cluster nutanix` (workload cluster 1, then 2) | each workload cluster | apps first, then Kubernetes and infrastructure |

Step 4 block, for later (it can run more than 1 hour, with no tool time limit):

```bash
# CHANGES  (upgrades Kommander, CAPI, the ClusterClasses, and the platform apps on the management cluster)
source ~/nkp-site.env 2>/dev/null
( set -o pipefail; nkp upgrade kommander --kubeconfig "$MGMT_KUBECONFIG" 2>&1 | tee -a "$HOME/nkp-upgrade-kommander.log" ); echo "exit: $?"
```

I do not start the Docker Hub credential change now. It needs the token: you put `NUTANIX_REGISTRY_USERNAME` and `NUTANIX_REGISTRY_TOKEN` in `~/nkp-site.env` with an editor (rule 5), and the CLI takes the token only as a flag, so other users on the host can see it in the process list.

Not checked: I did not run any command (no cluster is connected), and P-04 says a full 2.18 → 2.19 upgrade was not run in the lab, so the steps come from the guide.

---

## nkp-upgrade U3

Skill files read: `_shared/RULES.md`, `nkp/SKILL.md`, `nkp-upgrade/SKILL.md`, `nkp-airgap/SKILL.md`, `nkp-upgrade/references/dockerhub.md` (to confirm that an air-gapped site skips G2).

**Skill: `nkp-upgrade` (step 3, item 1) with skill `nkp-airgap` (steps 1 and 4).**

Facts I state:

- Air-gapped: push the **target** bundles into Harbor **before** the Kommander upgrade. [pdf p.1012-1015]
- The `nkp` CLI on the bastion must be 2.19.0: the CLI version must be the same as the version that you upgrade to. [pdf p.1018]
- The 2.19.0 Kommander upgrade checks: GitRepository catalog apps (G5), CloudNativePG (G6), new app dependencies, Docker Hub credentials (skipped on an air-gapped site).
- Do not use `--charts-bundle`, `--disallow-charts-download`, or a `.tar.gz` for `--kommander-applications-repository`: those flags are from 2.13-2.17 field notes. In 2.19.0 the repository has the default `v2.19.0`, and the other two flags are not in the help. [live 2.19.0] `--disable-appdeployments` is rejected by the 2.19.0 CLI. Do not use it.
- Add the NDK catalog bundle only if you run NDK on Nutanix. [pdf p.1015]

### Checks first (read-only)

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
nkp version
"$BUNDLE_DIR/cli/nkp" version
ls -l "$BUNDLE_DIR/container-images"
h="${REGISTRY_URL#*://}"; curl -s -o /dev/null -w '%{http_code}\n' --cacert "$REGISTRY_CA_FILE" "https://${h%%/*}/v2/"
for v in REGISTRY_URL REGISTRY_CA_FILE REGISTRY_PUSH_USERNAME REGISTRY_PUSH_PASSWORD; do if [ -n "$(printenv "$v")" ]; then echo "set: $v"; else echo "MISSING: $v"; fi; done
```

- HTTP code `200` or `401`: the mirror answers and the CA is correct.
- `nkp version` must print `v2.19.0` on the `nkp` line. If the installed CLI is 2.18.0, install the bundle CLI first (below).

### The four things to do before `nkp upgrade kommander`

**1. Put the 2.19.0 CLI on the bastion** (airgap step 1). Only if `nkp version` is not 2.19.0.

**2. Set `IMAGE_BUNDLES` for the target version** (airgap step 4). The block stops if a file is missing.

**3. Push the target bundles into Harbor** (airgap step 4A).

**4. Run the gates that still apply** (step 2 of the skill): G1 health, G3 one Prism Central project, G5 OCI catalogs only, G6 CloudNativePG, G7 the 2.19.0 OS image in Prism Central, G8 the Prism Central role, G9 room for one more VM in each pool. G2 is skipped (air-gapped). G4 applies only if Flux applies the cluster objects from Git.

### Plans (each stops for your "yes")

Plan 1 — CLI from the bundle:

```bash
# CHANGES  (copies nkp and kubectl from the bundle into /usr/local/bin)
source ~/nkp-site.env 2>/dev/null
sudo -n install -m 0755 "$BUNDLE_DIR/cli/nkp" "$BUNDLE_DIR/kubectl" /usr/local/bin/
```

Target: the bastion. Result: `/usr/local/bin/nkp` is 2.19.0. Also tell me whether `sha256sum -c nkp-bundle.sha256` printed OK for the tarball before it was extracted (step 1 of the airgap skill).

Plan 2 — the three always-needed bundles:

```bash
# CHANGES  (appends IMAGE_BUNDLES to ~/nkp-site.env)
source ~/nkp-site.env 2>/dev/null
b="$BUNDLE_DIR/container-images"; k="$(ls "$b"/konvoy-image-bundle-*.tar)"; m="$(ls "$b"/kommander-image-bundle-*.tar)"; r="$(ls "$b"/nkp-release-specs-*.tar)"; test -f "$k" && test -f "$m" && test -f "$r" && echo "export IMAGE_BUNDLES='$k,$m,$r'" >> ~/nkp-site.env
```

Target: `~/nkp-site.env`. Result: `IMAGE_BUNDLES` names the konvoy, kommander, and release-specs bundles of 2.19.0. Nothing is pushed to the registry yet.

Plan 3 — push into Harbor:

```bash
# CHANGES  (pushes all images in IMAGE_BUNDLES into the site registry)
source ~/nkp-site.env 2>/dev/null
nkp push bundle --bundle "$IMAGE_BUNDLES" --to-registry "$REGISTRY_URL" --to-registry-ca-cert-file "$REGISTRY_CA_FILE" --to-registry-username "$REGISTRY_PUSH_USERNAME" --to-registry-password "$REGISTRY_PUSH_PASSWORD"
```

Target: the Harbor mirror, project `mesosphere` (the first path part of `REGISTRY_URL` is the Harbor project; the Harbor admin makes it first). Result: the 2.19.0 images are in the mirror before any cluster pulls them. `nkp push bundle` needs much free space in `${TMPDIR:-/tmp}`. Harbor can print `UNAUTHORIZED: project not found, name: mesosphere`: that is a false positive. [pdf p.992] If a push fails, add `--on-existing-tag skip` to run it again.

### Questions

1. What is the full path of the extracted 2.19.0 bundle (`BUNDLE_DIR`)? I expect `.../nkp-v2.19.0`.
2. What is the exact `REGISTRY_URL` (scheme, host, port, project path) and the CA file path? Are `REGISTRY_PUSH_USERNAME` and `REGISTRY_PUSH_PASSWORD` in `~/nkp-site.env` already?
3. Do you run NDK on Nutanix (then the NDK catalog bundle goes into `EXTRA_BUNDLE`) or AI catalog apps?
4. Does Flux apply the cluster objects of a workload cluster from Git (gate G4)?
5. Do any clusters run AI Navigator or NKP Insights (gate G6)?
6. Is the 2.19.0 AHV OS image for Kubernetes 1.36.2 already in Prism Central (gate G7)? Its name must have the target Kubernetes version; the preflight check finds the image by name. [pdf p.726]

### After the push

Then step 4 of `nkp-upgrade` (the Kommander upgrade), one command, then step 5 (management cluster), then step 6 (each workload cluster):

```bash
# CHANGES  (upgrades Kommander, CAPI, the ClusterClasses, and the platform apps on the management cluster)
source ~/nkp-site.env 2>/dev/null
( set -o pipefail; nkp upgrade kommander --kubeconfig "$MGMT_KUBECONFIG" 2>&1 | tee -a "$HOME/nkp-upgrade-kommander.log" ); echo "exit: $?"
```

Done when: `exit: 0`, the ManagementPlane shows the target version in VERSION and CURRENT VERSION, and `kubectl -n kommander get helmreleases` has only the header line.

UNKNOWN (P-21): with a registry mirror, whether each workload cluster also needs its own push with its own kubeconfig, or only the management cluster. I check it with the check line in the skill after the push. Not in the skills: the answer for your site.

---

## nkp-upgrade U6

Skill files read: `_shared/RULES.md`, `nkp/SKILL.md`, `nkp-upgrade/SKILL.md`, `nkp-upgrade/references/non-clusterclass.md`, `nkp-upgrade/references/clusterclass.md`, `nkp-install/references/cloud.md` (the vSphere create script, to confirm the provider name).

**Skill: `nkp-upgrade`, step 6, and its file `non-clusterclass.md` (vSphere).**

Facts I state:

- The management cluster and Kommander must be on 2.19.0 first. That is your state now.
- The guide lists vSphere as a non-ClusterClass provider [pdf p.1025], so the upgrade has separate commands: platform apps, core addons, control plane, then each pool. I still read the CLUSTERCLASS column first: a value there sends us to the ClusterClass path instead (UNKNOWN P-06).
- Clusters in one workspace can have different versions. [pdf p.1019]
- The namespace `apps-x7k2p` is the workspace namespace. `nkp upgrade platform-apps --workspace` takes the workspace **name** (`apps`), not the namespace. [live 2.19.0]

### Step 1 (now): select the cluster and the provider (N1)

```bash
# READ-ONLY
source ~/nkp-web-01.env 2>/dev/null
for v in CLUSTER_NAME WORKSPACE_NS CLUSTER_KUBECONFIG MGMT_KUBECONFIG; do if [ -n "$(printenv "$v")" ]; then echo "set: $v"; else echo "MISSING: $v"; fi; done
nkp version
nkp upgrade cluster nutanix --help | head -1
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get nkpcluster "$CLUSTER_NAME" -o custom-columns='CAPI:.status.capiClusterRef.name,CAPI_NS:.status.capiClusterRef.namespace,K8S:.status.kubernetesVersion,CLASS:.spec.capiCluster.topology.classRef.name'
kubectl --kubeconfig "$MGMT_KUBECONFIG" get clusters.cluster.x-k8s.io -A
kubectl --kubeconfig "$MGMT_KUBECONFIG" get workspaces -o custom-columns='WORKSPACE:.metadata.name,NAMESPACE:.status.namespaceRef.name'
nkp get nodepools --cluster-name "$CLUSTER_NAME" --namespace "$WORKSPACE_NS" --kubeconfig "$MGMT_KUBECONFIG"
```

- `nkp upgrade cluster nutanix --help | head -1` prints the target Kubernetes version of 2.19.0 (1.36.2). [live 2.19.0] The value goes into `TARGET_K8S_VERSION`; confirm it against the release notes.
- `CAPI` and `CAPI_NS` are the values for `capi` and `capins` in every block below. Always give the namespace: the CLI default `default` is wrong. [pdf p.1030]
- `CLASS` empty → non-ClusterClass path (what I expect for vSphere). A value → stop, use `clusterclass.md`.
- The WORKSPACE column must show `apps` for NAMESPACE `apps-x7k2p`.

Health check before any change (gates G1, G9):

```bash
# READ-ONLY
source ~/nkp-web-01.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get nkpcluster "$CLUSTER_NAME"
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get upgradeplans
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get machines -l "cluster.x-k8s.io/cluster-name=$CLUSTER_NAME"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get nodes | awk 'NR==1 || $2!="Ready"'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get pdb -A | awk 'NR==1 || $(NF-1)=="0"'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get helmreleases -A | awk 'NR==1 || $4!="True"'
```

### Questions

1. Is `web-01` the cluster name, and is `apps-x7k2p` its NAMESPACE in `get nkpclusters`? If the cluster env file `~/nkp-web-01.env` does not exist, I make it first (skill `nkp-cluster-lifecycle`, step 1).
2. What is the new vSphere template name for Kubernetes 1.36.2 (`VSPHERE_TEMPLATE`)? It must be built with NIB and the 2.19.0 CLI for the target Kubernetes version. [pdf p.1028]
3. Which pools does `nkp get nodepools` show? I do one pool at a time, in that order.
4. Do you confirm workspace name `apps` for the platform-apps step?

### Order of the changes (each step stops for your "yes")

| Step | What | Command |
|---|---|---|
| N2 | platform apps of web-01 | `nkp upgrade platform-apps` (server dry run first) |
| N3 | core addons (CSI, CNI, autoscaler, NFD) | `nkp upgrade addons vsphere` |
| N4 | control plane | `nkp update controlplane vsphere` |
| N5 | each node pool, one at a time | `nkp update nodepool vsphere <pool>` |

N2 dry run, for later:

```bash
# CHANGES  (server dry run only: prints the UpgradePlan; creates nothing)
source ~/nkp-web-01.env 2>/dev/null
ws='apps'
: "${ws:?}"
nkp upgrade platform-apps --cluster-name "$CLUSTER_NAME" --workspace "$ws" --version "$NKP_TARGET_VERSION" --kubeconfig "$MGMT_KUBECONFIG" --dry-run
```

Warning for N3: NKP replaces the global ClusterResourceSets with one set for each cluster, and changes that you made to a ClusterResourceSet are lost. [pdf p.1026-1027] Tell me now if you changed the addon sets by hand; the dry run writes the new objects to a file so that we can re-apply your changes after the upgrade.

Not in the skills: the AKS steps, and an upgrade of an attached cluster (the tool that made it upgrades it [pdf p.1035]).

---

## nkp-troubleshooting T1

Skill files read: `_shared/RULES.md`, `nkp/SKILL.md`, `nkp-troubleshooting/SKILL.md`, `nkp-troubleshooting/references/flux.md`, `nkp-troubleshooting/references/rollouts.md`.

**Skill: `nkp-troubleshooting` (step 1, then the debug ladder).**

A red Apps tab is the platform-apps layer of the cluster. The app objects live in two places: `AppDeployment` objects in the workspace namespace on the management cluster, and the Flux `Kustomization` and `HelmRelease` objects on `dev-01` itself. [pdf p.1047, p.1059] So I start there, not with the nodes.

### Questions (the skill asks these first)

1. What changed last on `dev-01`: a create, an upgrade, a scale, an app change, an infrastructure change?
2. When did it start?
3. Does `kubectl` to the workload cluster work? (If yes, the workload API is healthy and the problem is in the app layer or the management cluster.)

### Step 1 (now): select the cluster

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" get nodes
kubectl --kubeconfig "$MGMT_KUBECONFIG" get nkpclusters -A -o custom-columns='NAMESPACE:.metadata.namespace,NAME:.metadata.name,PHASE:.status.phase,K8S:.status.kubernetesVersion,PLATFORM:.status.platformVersion'
```

The `default` workspace namespace is `kommander-default-workspace` on a standard install [pdf p.489], but I read the real NAMESPACE from that output and use it. Then:

```bash
# READ-ONLY
source ~/nkp-dev-01.env 2>/dev/null
for v in CLUSTER_NAME WORKSPACE_NS CLUSTER_KUBECONFIG MGMT_KUBECONFIG; do if [ -n "$(printenv "$v")" ]; then echo "set: $v"; else echo "MISSING: $v"; fi; done
```

If `~/nkp-dev-01.env` does not exist, I make it first (skill `nkp-cluster-lifecycle`, step 1) before I run this block.

- `get nodes` fails or times out: the management API does not answer. Then `nkp diagnose`, section "API server down".
- PHASE other than `Reconciled`: `Reconciling Platform Applications` or `Reconciling Kubernetes and Cluster Infrastructure`.

### Rung 1: the NKPCluster conditions

```bash
# READ-ONLY
source ~/nkp-dev-01.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get nkpcluster "$CLUSTER_NAME" -o jsonpath='phase={.status.phase}{"\n"}{range .status.conditions[*]}NKP {.type}={.status} {.reason}: {.message}{"\n"}{end}{range .status.capiCluster.conditions[*]}CAPI {.type}={.status} {.reason}: {.message}{"\n"}{end}' \
  | awk -F'[= ]' 'NR==1 || (($2 ~ /^(RollingOut|ScalingUp|ScalingDown|Remediating|Paused|Deleting)$/) ? $3!="False" : $3!="True")'
```

Healthy: only the `phase=Reconciled` line. Every other line is a problem, and the message names the part. A `PlatformAppsReconciled` or `KommanderClusterReady` line that is not `True` puts us in the app layer.

### Rung 4: platform apps (my main suspect for a red Apps tab)

```bash
# READ-ONLY
source ~/nkp-dev-01.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get appdeployments
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get nkpcluster "$CLUSTER_NAME" -o jsonpath='{range .status.kommanderCluster.conditions[?(@.status!="True")]}{.type}={.status} {.reason}: {.message}{"\n"}{end}'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get helmreleases -A -o custom-columns='NAMESPACE:.metadata.namespace,NAME:.metadata.name,READY:.status.conditions[?(@.type=="Ready")].status,REASON:.status.conditions[?(@.type=="Ready")].reason,SUSPEND:.spec.suspend' | grep -v -w True
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get kustomizations -A | grep -v -w True
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get ocirepositories,gitrepositories,helmcharts -A | grep -v -w True
```

- Healthy: the first two commands print the object list and nothing after it, and the other three print only the header line.
- Start with the lowest failing link: source (`OCIRepository`, `GitRepository`) → `HelmChart` (if any) → `HelmRelease` → `Kustomization`. A failed source makes every link above it fail.
- `SUSPEND true`: someone suspended the HelmRelease. Tell me why before we continue.
- Then I read the message of that object and the events of that object (flux.md F2), and the helm-controller log.

The fix belongs to skill `nkp-platform-apps-gitops`. This skill only finds the object and the message.

### Then, if the app layer is healthy

Rung 2 (CAPI objects and machines), rung 3 (`helmreleaseproxies` = the cluster addons), rung 5 (nodes, pods, events). I run them in that order and stop at the first rung that is not healthy.

Not checked: no cluster is connected, so I ran nothing. I cannot name the failing object before I see the output of the blocks above.

---

## nkp-troubleshooting T4

Skill files read: `_shared/RULES.md`, `nkp/SKILL.md`, `nkp-troubleshooting/SKILL.md`, `nkp-troubleshooting/references/diagnose.md`, `nkp-airgap/SKILL.md`, `nkp-airgap/references/prestage.md` (item P5).

**Skills: `nkp-troubleshooting` (diagnose.md) and `nkp-airgap` (prestage.md, P5).**

Facts I state, before any command:

- `nkp diagnose` is **not** read-only. It is a CHANGES command. It starts a privileged pod on every node (also the control plane, with host network, PID, and IPC), and it writes a file. [live 2.19.0]
- The bundle holds all ConfigMap data of all namespaces, all pod logs, host names, and IPs. Secret values are not in it, only the names and metadata. [pdf p.1049-1050]
- **Air-gapped first:** the node collector image that `nkp diagnose` in the 2.19.0 bundle asks for is `dkp-diagnostics-node-collector:v0.14.0`. The image bundles have only `v0.12.0`. So on your site the node collection pulls nothing and fails. This is P5 in skill `nkp-airgap`. [live 2.19.0]

### Checks first (read-only)

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
nkp version
df -h "${DIAG_DIR:-$PWD}"
nkp diagnose default-config | grep -n -E 'image:|pauseImage:|timeout:'
```

The last line shows the tag that your CLI asks for. Use it; do not trust my quote.

### P5: two choices for the node collector

- **A (recommended).** Make a one-image bundle on a connected host and push it into Harbor:

```bash
# USER-TERMINAL  (connected host; you run it. Writes diagnose-images.txt and diagnose-collector.tar)
echo 'docker.io/mesosphere/dkp-diagnostics-node-collector:v0.14.0' > diagnose-images.txt
nkp create bundle --images-file diagnose-images.txt --output-file diagnose-collector.tar
```

Then move the file into the air gap, and I push it with the "extra bundle" block of skill `nkp-airgap`, step 4.

- **B (not tested).** Make a config file that uses the `v0.12.0` image from the bundle. UNKNOWN (A-08): whether the `v0.12.0` collector works with `nkp diagnose` v0.14.0. Only a lab test answers that.
- Or: no node data at all. I make a config file without the `execCopyFromHost` collector, and the bundle then has no `node-diagnostics` folder. Nutanix support gets less data.

### Questions

1. Which choice: A, B, or no node data?
2. Which folder for the bundle (`DIAG_DIR`)? It needs free space for a `.tar.gz` per cluster, and I must not print the files.
3. Do you want `--since 6h` to limit the pod logs? Without it the guide says the bundle has 48 h. [pdf p.1049]
4. Which cluster? Your management cluster kubeconfig is the target; for a workload cluster problem I run it twice, also on the management cluster (the CAPI objects and controller logs are there).

### Plan, after your "yes"

Plan: target = the management cluster; `nkp diagnose` runs a privileged collector pod on each node for up to 600 s and writes `support-bundle-*.tar.gz` in `DIAG_DIR`; the bundle holds all ConfigMap data, all pod logs, and host names and IPs. Block A (default collectors, after P5 choice A):

```bash
# CHANGES  (runs collector pods on every node; writes support-bundle-*.tar.gz in DIAG_DIR)
source ~/nkp-<cluster>.env 2>/dev/null
cd "${DIAG_DIR:?}" && nkp diagnose --kubeconfig "$CLUSTER_KUBECONFIG" --bundle-name-prefix "$CLUSTER_NAME"
```

Replace `<cluster>` with the name of your management cluster before I run it. On the management cluster, `CLUSTER_KUBECONFIG` is the same file as `MGMT_KUBECONFIG`, and `WORKSPACE_NS` is `kommander`.

Block B (with a config file, P5 choice B or a D5 file):

```bash
# CHANGES  (runs the collectors of the file; writes support-bundle-*.tar.gz in DIAG_DIR)
source ~/nkp-<cluster>.env 2>/dev/null
cfg=''
: "${cfg:?}"
cd "${DIAG_DIR:?}" && nkp diagnose "$cfg" --kubeconfig "$CLUSTER_KUBECONFIG" --bundle-name-prefix "$CLUSTER_NAME"
```

Then the check (read-only): the expected top folders are `cluster-info`, `cluster-resources`, `configmaps`, `node-diagnostics`, `pod-logs`, `secrets`, and `version.yaml`. I read only the `*-error.txt` and `pod-collector.log` files, and I never print the bundle.

I do not run it now: it is not read-only, and you did not approve the plan.

---

## nkp-troubleshooting T6

Skill files read: `_shared/RULES.md`, `nkp/SKILL.md`, `nkp-troubleshooting/SKILL.md`, `nkp-troubleshooting/references/rollouts.md` (R5), `nkp-airgap/SKILL.md` (step 5), `nkp-airgap/references/nodes.md`, `nkp-cluster-lifecycle/references/variables.md` (V8).

**Skills: `nkp-troubleshooting` (symptom: `x509` from a registry) → `nkp-airgap` (nodes.md) → `nkp-cluster-lifecycle` (variables.md, V8).**

Why this happens, as the skills state it:

- CAREN writes the registry files on each node at bootstrap (`preKubeadmCommands`). The files are `/etc/containerd/certs.d/_default/hosts.toml`, `/etc/containerd/certs.d/<registry-host>/ca.crt`, and `/etc/caren/containerd/patches/registry-config.toml`. [live 2.19.0]
- So a registry change reaches **only new machines**. Your old workers kept the CA that they got at their own bootstrap. Your new pool nodes got the CA that the cluster config and the CA Secret hold **now**.
- `x509: certificate signed by unknown authority` on the new nodes means: the `ca.crt` that those nodes got does not match the certificate that the registry (Harbor) serves. Two causes fit the skills:
  1. The CA in the registry credentials Secret is old, wrong, or a chain without the right root. Old nodes still hold the CA from their bootstrap.
  2. The registry address that the new nodes use is not the address that the CA belongs to (a changed mirror URL, or an IP instead of a name).

The checks tell which one it is. I do not guess.

### Check 1 (read-only): the config and the files that CAREN writes

```bash
# READ-ONLY
source ~/nkp-edge-02.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get nkpclusters "$CLUSTER_NAME" -o jsonpath='{..globalImageRegistryMirror.url}{"\n"}{..imageRegistries[*].url}{"\n"}'
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get nkpcluster "$CLUSTER_NAME" -o jsonpath='{range .spec.capiCluster.topology.variables[?(@.name=="clusterConfig")].value}mirror={.globalImageRegistryMirror.url} secret={.globalImageRegistryMirror.credentials.secretRef.name}{"\n"}{range .imageRegistries[*]}registry={.url} secret={.credentials.secretRef.name}{"\n"}{end}{end}'
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get kubeadmcontrolplane -l cluster.x-k8s.io/cluster-name="$CLUSTER_NAME" -o jsonpath='{range .items[*].spec.kubeadmConfigSpec.files[*]}{.path}{"\n"}{end}'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get pods -A | grep -E 'ImagePullBackOff|ErrImagePull' || echo "no image pull errors"
```

- Line 1 and 2: the mirror URL and the name of the Secret that holds the CA (column `secret=`). An empty line 1 means no mirror.
- Line 3 must list the `hosts.toml` and `ca.crt` paths above.
- Line 4 shows which pods still fail. Compare a failing pod on a **new** node with a working pod on an **old** node.

### Check 2 (USER-TERMINAL, on a node): compare a new node with an old node

Run this on one **new** pool node and on one **old** worker, over SSH as user `konvoy` with the key of `SSH_PUBKEY_FILE`.

```bash
# USER-TERMINAL  (on a node; you run it over SSH, once on a new node and once on an old node)
sudo cat /etc/containerd/certs.d/_default/hosts.toml
sudo ls /etc/containerd/certs.d/
sudo cat /etc/containerd/certs.d/*/ca.crt | openssl x509 -noout -subject -issuer -fingerprint -sha256
sudo cat /etc/caren/containerd/patches/registry-config.toml
sudo journalctl -u containerd --since "30 min ago" | grep -i -E 'pull|x509|401|403' | tail -20
```

- The `hosts.toml` must have `[host."https://<registry-host>/v2/<path>"]`, the `ca` path, `capabilities = ["pull","resolve"]`, and `override_path = true` when the mirror URL has a path. [live 2.19.0]
- Compare the fingerprints of the `ca.crt` on both nodes, and compare them with the certificate that the registry serves. Never print `/etc/kubernetes/static-image-credentials.json`: it holds credentials.

### The fix, in the owner skill

If the CA is wrong, the owner of the fix is skill `nkp-cluster-lifecycle`, variables.md, **V8 case B** (new CA, same URL). The plan would be: replace the key `ca.crt` of that Secret with the CA file that the registry admin gives you (`REGISTRY_CA_FILE`); the username and the password stay; running nodes keep their old CA.

**Important limit:** UNKNOWN (P-27): whether a change to the Secret only rolls the nodes. New machines get the new CA at bootstrap. So after the change:
- The new pool nodes must come again to get the new CA. If a machine is not replaced within about 10 minutes, the last resort is the rollout in `rollouts.md` R9.
- If the mirror **URL** is also wrong, that is V8 case A: a change of the image registry configuration replaces **all** nodes of the cluster. [pdf p.287] That is a much larger change, and we plan it separately.

I do not change anything yet. Tell me the outputs of check 1 (the `secret=` name and the URL), and of check 2 on both nodes; then I show the exact patch with its plan and stop for your "yes".

Not in the skills: which specific `ca.crt` your Harbor serves, and whether your new pool was made with a different pool image from a different registry path. Check 2 answers the first, `nkp get nodepools` and the pool `workerConfig` answer the second.

---

## nkp-troubleshooting T7

Skill files read: `_shared/RULES.md`, `nkp/SKILL.md`, `nkp-cluster-lifecycle/references/variables.md` (V2, V8), `nkp-troubleshooting/references/rollouts.md` (R1, R9), `nkp-airgap/references/nodes.md`.

**Skills: `nkp-cluster-lifecycle` (variables.md, V8) and `nkp-troubleshooting` (rollouts.md, R9).**

Two facts first:

- **`spec.rolloutAfter` is gone.** The old name is dropped in this CAPI API version and has no effect. The field is `spec.rollout.after` (an RFC3339 time). [live 2.19.0]
- The NKPCluster controller **drops** `rollout.after` from a pool, so a value that you put into the topology does nothing. The only way the skills give is a direct patch of the topology-owned `MachineDeployment`, and that is the last resort (R9). [live 2.19.0]

The correct order is: owner fix first, R9 only if the machines do not roll.

### Step 1 (now): did the nodes roll already?

A registry CA change in the Secret (V8 case B) may or may not roll the machines (UNKNOWN P-27). Wait about 10 minutes after your change, then check:

```bash
# READ-ONLY
source ~/nkp-prod-01.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get machines -l "cluster.x-k8s.io/cluster-name=$CLUSTER_NAME" -o custom-columns='NAME:.metadata.name,PHASE:.status.phase,READY:.status.conditions[?(@.type=="Ready")].status,UPTODATE:.status.conditions[?(@.type=="UpToDate")].status,AGE:.metadata.creationTimestamp'
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get kubeadmcontrolplanes,machinedeployments,machinesets -l "cluster.x-k8s.io/cluster-name=$CLUSTER_NAME"
```

- A new AGE on every machine = the roll is running or done. Then we only watch (skill `nkp-cluster-lifecycle`, step 3d).
- Same AGE on the old workers = they did not roll. Continue with step 2.

Also confirm the CA on an old worker, so that we know the change is right before we roll every node:

```bash
# USER-TERMINAL  (on one old worker; you run it over SSH as user konvoy)
sudo cat /etc/containerd/certs.d/*/ca.crt | openssl x509 -noout -subject -issuer -fingerprint -sha256
sudo journalctl -u containerd --since "30 min ago" | grep -i -E 'x509|pull' | tail -20
```

`sudo journalctl` may show the old CA in use until the node is replaced. That is the expected state, not a new fault.

### Step 2: find the MachineDeployment of md-0

```bash
# READ-ONLY
source ~/nkp-prod-01.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get machinedeployments -l "cluster.x-k8s.io/cluster-name=$CLUSTER_NAME" -o custom-columns='NAME:.metadata.name,AFTER:.spec.rollout.after,DESIRED:.spec.replicas,READY:.status.readyReplicas'
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get pdb -A 2>/dev/null | awk 'NR==1 || $(NF-1)=="0"'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get pdb -A | awk 'NR==1 || $(NF-1)=="0"'
```

The name is usually `<cluster>-md-0`. I confirm it in the output; I do not assume it. A PDB with ALLOWED `0` stops the drain of that node for ever (a pool has no drain timeout by default).

### Step 3: preview (read-only, server dry run)

```bash
# READ-ONLY  (server dry run: the API server checks the patch and changes nothing)
source ~/nkp-prod-01.env 2>/dev/null
obj='machinedeployment/<name from step 2>'
: "${obj:?}"
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" patch "$obj" --type merge -p "{\"spec\":{\"rollout\":{\"after\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}}}" --dry-run=server -o jsonpath='{.spec.rollout}{"\n"}'
```

The output must contain `"after"`. Anything else: stop.

### Step 4: the plan (I stop here for your "yes")

- Target: `machinedeployment/<name>` of pool md-0 in namespace `$WORKSPACE_NS` on the management cluster of `prod-01`.
- Result: CAPI replaces **every** machine of md-0, one by one (`maxSurge: 1`, `maxUnavailable: 0`). Each new node needs one free IP and the resources of one more VM. A PDB with ALLOWED 0 stops the drain; workloads with one replica stop for a short time.
- Also: UNKNOWN (A-20): whether the topology controller keeps a `rollout.after` that we set on a topology-owned MachineDeployment. I check it right after the patch with the command below.

```bash
# CHANGES  (sets spec.rollout.after: CAPI replaces every machine of this object, one by one)
source ~/nkp-prod-01.env 2>/dev/null
obj='machinedeployment/<name from step 2>'
: "${obj:?}"
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" patch "$obj" --type merge -p "{\"spec\":{\"rollout\":{\"after\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}}}"
```

Then watch (read-only), and check A-20:

```bash
# READ-ONLY
source ~/nkp-prod-01.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get machinedeployments,kubeadmcontrolplanes -l "cluster.x-k8s.io/cluster-name=$CLUSTER_NAME" -o custom-columns=NAME:.metadata.name,AFTER:.spec.rollout.after
```

### Questions

1. Is `prod-01` the cluster name, and what is its workspace namespace? I need `~/nkp-prod-01.env`, or I make it first.
2. Which pool name is exactly `md-0` in `get machinedeployments`?
3. Is the CA change already done (V8 case B, the Secret `ca.crt`), and did you change only the CA, or also the mirror URL? A URL change replaces all nodes by itself (V8 case A) and R9 is then wrong.
4. Are there PDBs with ALLOWED 0 on this cluster?

Do not run the old `rolloutAfter` patch: it silently does nothing on this CAPI API version, so you would think a roll started when nothing did.

---

## nkp-install E13

Skill files read: `_shared/RULES.md`, `nkp/SKILL.md`, `nkp-install/SKILL.md`, `nkp-install/references/preprovisioned.md`, `nkp-airgap/SKILL.md`, `nkp-airgap/references/prestage.md` (P9: OS packages).

**Skill: `nkp-install`, its file `preprovisioned.md`, with skill `nkp-airgap` for the dark site.**

Facts I state:

- Pre-provisioned hosts need **Pro or Ultimate**. Starter is AHV only. [pdf p.27-28]
- The default storage is `localvolumeprovisioner`, which is not for production. Plan a CSI driver. [pdf p.766]
- The CNI on pre-provisioned clusters is Calico in the guide. [pdf p.765]
- On this provider, the management cluster uses `WORKSPACE_NS='default'`, **not** `kommander`. [live 2.19.0][pdf p.768]
- `nkp create cluster preprovisioned` has no `--bundle` and no `--airgapped` flag. The mirror must already have the NKP images. [live 2.19.0]
- The OS packages are **not** in the 2.19.0 bundle. You need the OS package bundle for your host OS, made on a connected host with `nkp create package-bundle`, in `$BUNDLE_DIR/image-artifacts`. [pdf p.73]
- `nkp create cluster preprovisioned` has no `--ntp-servers` flag: the hosts get time from the OS. [live 2.19.0]

### Checks first (read-only)

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
nkp version
docker version --format '{{.Server.Version}}'
kubectl version --client
stat -fc %T /sys/fs/cgroup
nproc; free -g; df -h "${TMPDIR:-/tmp}"
```

Then the bundle and the host list:

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
ls "$BUNDLE_DIR" "$BUNDLE_DIR/container-images" "$BUNDLE_DIR/image-artifacts" "$BUNDLE_DIR/image-artifacts/images"
for v in BUNDLE_DIR REGISTRY_URL REGISTRY_CA_FILE SSH_USER SSH_PRIVATE_KEY_FILE REGISTRY_MIRROR_USERNAME REGISTRY_MIRROR_PASSWORD; do if [ -n "$(printenv "$v")" ]; then echo "set: $v"; else echo "MISSING: $v"; fi; done
```

Before you approve that block, replace `<cluster>` in `~/nkp-<cluster>.env` with the cluster name that you give me. I use the same name in the inventory file and the create script.

### Questions (I need these before I write any value)

0. What is the cluster name? It uses only `a-z`, `0-9`, `.`, and `-`, and the inventory uses the same name. [pdf p.777]
1. The 7 host addresses: 3 control-plane IPs (`CP_HOSTS`) and 4 worker IPs (`WORKER_HOSTS`).
2. `CP_VIP`: the free static IPv4 for the API endpoint. The interface on all three control-plane hosts is `ens192` (`VIP_INTERFACE=ens192`), as you said.
3. `LB_IP_RANGE`: a range in the host subnet for MetalLB (`<first-ip>-<last-ip>`). This provider has no load-balancer range flag, so I make the MetalLB pool after the create. [pdf p.83-84]
4. `REGISTRY_URL` (Harbor project path) and `REGISTRY_CA_FILE` for the seeded mirror, and whether `REGISTRY_MIRROR_USERNAME`/`REGISTRY_MIRROR_PASSWORD` are in `~/nkp-site.env` already.
5. Is the OS package bundle for **Rocky 9.8** in `"$BUNDLE_DIR/image-artifacts"`? It is not in the bundle, and the hosts cannot download packages. [pdf p.73] If it is missing, the host preparation fails.
6. Is Rocky Linux 9.8 a supported host OS for pre-provisioned hosts in 2.19.0? That list is not in the skills. Check it in the 2.19 release notes before we start.
7. Which disks may Rook Ceph use on the workers? Ceph **deletes** the data on them. [pdf p.85-86]
8. Do you confirm the tier is Pro or Ultimate?

### Plan of the steps

| Step | What | Mark |
|---|---|---|
| P2 | values into `~/nkp-site.env` and `~/nkp-<cluster>.env`, then the SSH check to all 7 hosts | CHANGES, then READ-ONLY |
| P3 | `nkp upload image-artifacts` to all 7 hosts over SSH | CHANGES |
| P4 | write the inventory file `$HOME/nkp-<cluster>-inventory.yaml` | CHANGES |
| P5 | write the create script `$HOME/nkp-<cluster>-create.sh` | CHANGES |
| P6 | dry run, then the create with `--self-managed` | CHANGES |
| then | kubeconfig, Kommander with the Rook Ceph override, MetalLB pool, verify | CHANGES and READ-ONLY |

The values you already gave me, for the two env files (I run this **after** you confirm the names and addresses — I stop here):

```bash
# CHANGES  (appends the site and cluster values to the two env files)
source ~/nkp-<cluster>.env 2>/dev/null
test -e ~/nkp-site.env || { touch ~/nkp-site.env && chmod 600 ~/nkp-site.env; }
test -e ~/nkp-<cluster>.env || { (umask 077 && echo 'source ~/nkp-site.env 2>/dev/null' > ~/nkp-<cluster>.env); }
echo "export SSH_USER='nkpadmin'" >> ~/nkp-site.env
echo "export SSH_PRIVATE_KEY_FILE='/home/ops/.ssh/nkp'" >> ~/nkp-site.env
echo "export VIP_INTERFACE='ens192'" >> ~/nkp-<cluster>.env
echo "export WORKSPACE_NS='default'" >> ~/nkp-<cluster>.env
```

Not in that block: `CP_HOSTS`, `WORKER_HOSTS`, `CP_VIP`, `LB_IP_RANGE`, `BUNDLE_DIR`, `REGISTRY_URL`, `REGISTRY_CA_FILE`. You did not give those values, so I do not write them and I do not put a placeholder in a line (rule 4).

The SSH check after the values are in (read-only):

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
for h in ${CP_HOSTS//,/ } ${WORKER_HOSTS//,/ }; do ssh -i "$SSH_PRIVATE_KEY_FILE" -o BatchMode=yes "$SSH_USER@$h" 'hostname; sudo -n true && echo sudo-ok; swapon --show | wc -l'; done
```

Each host must print its name, `sudo-ok`, and `0` (no swap). `Host key verification failed` means the host key is not in `~/.ssh/known_hosts`; you add it (for example with `ssh-keyscan`), then I run the block again. The key must be **unencrypted** and the user needs passwordless `sudo`. [pdf p.766]

Two more things that will stop the create if we skip them:

- The pod CIDR (`192.168.0.0/16`) and the service CIDR (`10.96.0.0/12`) must not overlap your host subnet. [pdf p.788] Tell me your host subnet and I check it.
- Each control-plane host: 4 cores, 16 GB, about 80 GB free. Each worker: 8 cores, 32 GiB. Swap off, `firewalld` stopped, the NKP ports open. [pdf p.767]

Not checked: no host is reachable from here, so I ran nothing.

---

## nkp-networking W1

Skill files read: `_shared/RULES.md`, `nkp/SKILL.md`, `nkp-networking/SKILL.md`, `nkp-networking/references/proxy.md`.

**Skill: `nkp-networking`, its file `proxy.md` (X0, X2, X3, X4), and skill `nkp-install` for the create script.**

The proxy goes in three places, and you need all three: [pdf p.666, p.980]
1. the nodes (kubelet and containerd image pulls),
2. the CAPI controllers on the management cluster (calls to Prism Central and chart pulls),
3. the platform-app pods (Gatekeeper pod mutation, after the create).

On Nutanix AHV, the create flags set the first two; the third is a separate change after the create.

### Check 0 (now): credentials in the URL

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
case "$NKP_HTTP_PROXY $NKP_HTTPS_PROXY" in *@*) echo "proxy URL has a user or password";; *) echo "no credentials in the proxy URL";; esac
```

If that prints `has a user or password`, some blocks print the URL and become USER-TERMINAL, and I tell you what NKP stores as plain text.

### Build the no-proxy list (X2)

Your cluster env file `~/nkp-nkp-mgmt.env` already has `CP_VIP` and `LB_IP_RANGE`, so the block works as it is. First the preview:

```bash
# READ-ONLY  (prints the list; changes nothing)
source ~/nkp-nkp-mgmt.env 2>/dev/null
extra=''; aws=''; pods='192.168.0.0/16'; svcs='10.96.0.0/12'
: "${CP_VIP:?}" "${LB_IP_RANGE:?}"
base='localhost,127.0.0.1,kubernetes,kubernetes.default,kubernetes.default.svc,kubernetes.default.svc.cluster,kubernetes.default.svc.cluster.local,.svc,.svc.cluster,.svc.cluster.local,svc.,.svc.cluster.,.svc.cluster.local.,169.254.169.254,169.254.0.0/24'
echo "$base${aws:+,10.0.0.0/16,.elb.amazonaws.com},$pods,$svcs,$CP_VIP,${LB_IP_RANGE%%-*}${extra:+,$extra}"
```

`extra` must name the internal hosts that are not on the internet: the host of `PC_ENDPOINT` (Prism Central), the host of `REGISTRY_URL` (your mirror), the identity provider, and internal domain suffixes with a leading dot. [pdf p.669, p.980] Entries are comma-separated with no space. [pdf p.667] Your defaults `192.168.0.0/16` and `10.96.0.0/12` are correct unless the create changes the CIDRs.

Then I count the items (maximum 128 for `clusterConfig.proxy.additionalNo`), and check that the proxy answers from the operator host:

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
curl -sS -o /dev/null -w '%{http_code}\n' --proxy "$NKP_HTTPS_PROXY" https://registry.k8s.io/v2/
```

### The three flags in the create script (X3, Nutanix)

Add these lines before `"$@"` in `~/nkp-nkp-mgmt-create.sh`:

```text
  --http-proxy "$NKP_HTTP_PROXY" \
  --https-proxy "$NKP_HTTPS_PROXY" \
  --no-proxy "$NO_PROXY_LIST" \
```

UNKNOWN (N-23): on Nutanix, whether `--http-proxy` sets both `clusterConfig.proxy` and the CAPI controllers. The dry run only answers the node part. I check the controller part after the real create:

```bash
# READ-ONLY
source ~/nkp-nkp-mgmt.env 2>/dev/null
grep -n -E '^kind:|^ +(http|https|additionalNo):' "$PWD/$CLUSTER_NAME-dryrun.yaml"
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n capx-system get deploy capx-controller-manager -o jsonpath='{.spec.template.spec.containers[0].env[*].name}'
```

(The `grep` prints only lines that end in `:` from the dry-run file, so it cannot print a Secret value.)

### Plans, in order (each stops for your "yes")

Plan 1 — append the no-proxy list to the cluster env file:

```bash
# CHANGES  (appends NO_PROXY_LIST to the cluster env file)
source ~/nkp-nkp-mgmt.env 2>/dev/null
extra=''; aws=''; pods='192.168.0.0/16'; svcs='10.96.0.0/12'
: "${CP_VIP:?}" "${LB_IP_RANGE:?}" "${CLUSTER_NAME:?}"
base='localhost,127.0.0.1,kubernetes,kubernetes.default,kubernetes.default.svc,kubernetes.default.svc.cluster,kubernetes.default.svc.cluster.local,.svc,.svc.cluster,.svc.cluster.local,svc.,.svc.cluster.,.svc.cluster.local.,169.254.169.254,169.254.0.0/24'
echo "export NO_PROXY_LIST='$base${aws:+,10.0.0.0/16,.elb.amazonaws.com},$pods,$svcs,$CP_VIP,${LB_IP_RANGE%%-*}${extra:+,$extra}'" >> "$HOME/nkp-$CLUSTER_NAME.env"
```

Result: `NO_PROXY_LIST` is in `~/nkp-nkp-mgmt.env`, 128 items or fewer. Nothing changes in the cluster.

Plan 2 — the create script, with the three proxy lines added. Result: the dry run and the create send the nodes and the CAPI controllers through `proxy.corp.example.com:3128`, and no cluster-internal or internal-host traffic goes to the proxy.

Plan 3 (after the create) — the platform-app pods: `gatekeeper-overrides` ConfigMap with `mutations.enablePodProxy: true`, then label `kommander` and `kommander-flux` with `gatekeeper.d2iq.com/mutate=pod-proxy`, then verify with the server dry run that shows `["HTTP_PROXY","HTTPS_PROXY","NO_PROXY"]`. [pdf p.981-983]

### Questions

1. Which local entries go in `extra`: the Prism Central host, the mirror host, other internal hosts, and internal domains? I can read the hosts from `PC_ENDPOINT` and `REGISTRY_URL` if they are in `~/nkp-site.env`.
2. Does the proxy URL hold a user and a password? (I do not repeat it. If yes, it is a secret and it goes into `~/nkp-site.env` with your editor.)
3. Is `10.96.0.0/12` still the service CIDR and `192.168.0.0/16` the pod CIDR for this cluster? [pdf p.670]
4. Do the nodes reach Prism Central directly or through the proxy? (The PC host must be in no-proxy if it is internal.)

I do not run any CHANGES block now.

---

## nkp-networking W2

Skill files read: `_shared/RULES.md`, `nkp/SKILL.md`, `nkp-networking/SKILL.md`, `nkp-networking/references/proxy.md` (X0, X4, X5, X6), `nkp-cluster-lifecycle/SKILL.md` (step 3, the JSON patch), `nkp-cluster-lifecycle/references/variables.md` (V2, V5).

**Skills: `nkp-networking` (proxy.md, X5) and `nkp-cluster-lifecycle` (step 3) for the node part.**

The full plan first, because Part C replaces **all nodes** of `dev-mgmt`: [pdf p.670-672]

| Part | What changes | Restarts or replaces |
|---|---|---|
| A | the proxy variables on the CAPI controllers and `git-operator` | the controller pods restart |
| B | the `gatekeeper-overrides` ConfigMap (platform-app pods) | only pods made after the change; restart the core ones |
| C | `clusterConfig.proxy` in the NKPCluster | **all nodes of the cluster, one by one** |

### Checks first (read-only)

```bash
# READ-ONLY
source ~/nkp-dev-mgmt.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get nkpcluster "$CLUSTER_NAME" -o json | jq -c '.spec.capiCluster.topology.variables[] | select(.name=="clusterConfig") | .value.proxy // {} | {http: ((.http // "") | length), https: ((.https // "") | length), additionalNo}'
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n capx-system get deploy capx-controller-manager -o jsonpath='{.spec.template.spec.containers[0].env[*].name}{"\n"}'
kubectl --kubeconfig "$MGMT_KUBECONFIG" get kustomizations -A | awk 'NR==1 || $4!="True"'
```

- Line 1 prints only the **lengths** of the URLs, not the URLs: a proxy URL can hold a password.
- Line 2 shows whether the controllers already have `HTTP_PROXY HTTPS_PROXY NO_PROXY`.
- Line 3: a Kustomization that is not ready can put the controllers back (UNKNOWN N-22). Tell me if one is not ready before we change them.

Check that the new proxy answers (read-only). Do this **after** you put the new URL in the env file; if the URL holds a user and a password it is a secret (X0), and the block is USER-TERMINAL.

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
case "$NKP_HTTP_PROXY $NKP_HTTPS_PROXY" in *@*) echo "proxy URL has a user or password";; *) echo "no credentials in the proxy URL";; esac
curl -sS -o /dev/null -w '%{http_code}\n' --proxy "$NKP_HTTPS_PROXY" https://registry.k8s.io/v2/
```

### What you must do first

The new address goes into `~/nkp-site.env` as **new lines** (the last line wins, rule 4): `NKP_HTTP_PROXY` and `NKP_HTTPS_PROXY`. Then I append a new `NO_PROXY_LIST` to `~/nkp-dev-mgmt.env` if the no-proxy entries change. Until those lines are in, my blocks use the old values.

### Plans (each stops for your "yes")

Plan A — controllers (management cluster only). Target: every CAPI controller Deployment that exists, plus `git-operator`. Result: the controller pods restart and use the new proxy. Unknown N-22: whether the CAPI operator reverts it; I check afterwards with the line 2 command above.

```bash
# CHANGES  (sets the proxy variables on the CAPI controllers and git-operator; the pods restart)
source ~/nkp-dev-mgmt.env 2>/dev/null
for d in caaph-system/caaph-controller-manager capa-system/capa-controller-manager capg-system/capg-controller-manager capi-kubeadm-bootstrap-system/capi-kubeadm-bootstrap-controller-manager capi-kubeadm-control-plane-system/capi-kubeadm-control-plane-controller-manager capi-system/capi-controller-manager cappp-system/cappp-controller-manager capv-system/capv-controller-manager capx-system/capx-controller-manager capz-system/capz-controller-manager caren-system/cluster-api-runtime-extensions-nutanix; do kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "${d%/*}" get deploy "${d#*/}" >/dev/null 2>&1 && kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "${d%/*}" set env "deployment/${d#*/}" HTTP_PROXY="$NKP_HTTP_PROXY" HTTPS_PROXY="$NKP_HTTPS_PROXY" NO_PROXY="$NO_PROXY_LIST"; done
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n git-operator-system set env statefulset/git-operator-git HTTP_PROXY="$NKP_HTTP_PROXY" HTTPS_PROXY="$NKP_HTTPS_PROXY" NO_PROXY="$NO_PROXY_LIST"
```

Plan B — platform apps (X4): write `dev-mgmt-gatekeeper-proxy.yaml`, merge the old values if the ConfigMap exists, preview with a server dry run, then apply and label the namespaces. Result: new pods in the labeled namespaces get `HTTP_PROXY`, `HTTPS_PROXY`, `NO_PROXY`. Old pods keep the old values until you restart them.

Plan C — nodes (X5 C). Target: the NKPCluster of `dev-mgmt`. Result: **all nodes replaced**, control plane first. One more VM and one more IP per pool during the roll. Only 128 entries in `additionalNo`. The value is built by the shell from the env files, so no URL is typed into the block:

```text
value="$(jq -nc --arg h "$NKP_HTTP_PROXY" --arg s "$NKP_HTTPS_PROXY" --arg n "$NO_PROXY_LIST" '{http:$h,https:$s,additionalNo:($n|split(","))}')"
```

That value goes into the `nkp-cluster-lifecycle` step 3 "Cluster field" patch with `field='proxy'`, then the server dry run (step 3b), then the apply (step 3c) after your "yes", then the rollout watch (step 3d).

Not in the skills: how to **remove** a proxy fully. Tell me if you want that instead.

### Questions

1. What are the new proxy URLs? Do not paste them into the chat if they hold a user and a password: put them in `~/nkp-site.env` with your editor and tell me only that they are set.
2. Does the no-proxy list change (the new proxy is in another network)?
3. Does the new proxy need the old one's bypass list, and is a restart of core services in the labeled namespaces acceptable (Plan B)?
4. Is a full node replace of the management cluster acceptable now (Plan C)? If not, we can do A and B now and C in a maintenance window; the nodes keep the old proxy until then.

---

## nkp-networking W3

Skill files read: `_shared/RULES.md`, `nkp/SKILL.md`, `nkp-networking/SKILL.md`, `nkp-networking/references/metallb.md` (M3, M2).

**Skill: `nkp-networking`, its file `metallb.md`, section M3 (BGP mode).**

I must stop on the first step. The skill says: on NKP 2.19.0 the API server rejects **every** `BGPPeer`, also the guide example, with "Maximum boundary value must be of type integer with format int32 in spec.myASN". The pool and the BGPAdvertisement pass; the peer does not. [live 2.19.0] UNKNOWN (N-20) covers whether a fix exists.

So the first command is the check, and I do not ask you for the BGP values until it passes:

```bash
# READ-ONLY
source ~/nkp-dev-01.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get crd bgppeers.metallb.io -o jsonpath='{.spec.versions[?(@.name=="v1beta2")].schema.openAPIV3Schema.properties.spec.properties.myASN}{"\n"}'
```

- If it prints `"format":"int32"` and `"maximum":4294967295`: the rejection is still there. **Stop.** I do not write a file, I do not ask for the ASNs, and I do not change the MetalLB CRD (that is not a supported fix).
- If the schema is different: I ask for the four values and continue.

Current state of the load balancers, so that we know what we would add to:

```bash
# READ-ONLY
source ~/nkp-dev-01.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n metallb-system get ipaddresspools,l2advertisements,bgpadvertisements
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get svc -A --field-selector spec.type=LoadBalancer
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n metallb-system get pods -o wide
```

Facts for the alternative and for the network team:

- BGP is for a site where the pool is not in the node subnet, or where the network team wants routes. MetalLB peers from **every** speaker node, so the router must accept a BGP session from each node address with our AS. [pdf p.673, p.783]
- If the schema check stops us, the supported alternative is a **new Layer 2 pool** (M2), not an edit of the default pool `metallb`. An edit of the default pool or the default L2Advertisement makes the next cluster upgrade stall and fail. [pdf p.672]
- Do not put `CP_VIP` in a MetalLB pool; kube-vip owns it.

### Questions

1. Do you want me to run the N-20 check now and report? (It is read-only, so yes is enough.)
2. If BGP is blocked: is a Layer 2 pool acceptable, or do you wait for a fix from Nutanix support? For Layer 2, the range must be in the node primary subnet. [pdf p.672]
3. If the check passes: is the range `203.0.113.0/27` the **announced prefix** that the network team routes to the node addresses, and is 198.51.100.1 the only peer? I do not append the values until the check passes.

Not in the skills: a workaround for N-20, and whether a later 2.19 patch fixes it.

---

## nkp-networking W5

Skill files read: `_shared/RULES.md`, `nkp/SKILL.md`, `nkp-networking/SKILL.md`, `nkp-networking/references/metallb.md` (M1, M2).

**Skill: `nkp-networking`, its file `metallb.md`, section M2.**

Two facts first:

- I do not edit the default pool `metallb` or the default L2Advertisement `metallb`. That is the pool that CAREN made from the create flag. An edit of it makes the next cluster upgrade stall and fail. [pdf p.672] I make a **new pool** and a **new advertisement**.
- "Just run it" is not approval. I show you the plan, the target, and the result, and I run it after you type "yes". Rule 2 applies to every CHANGES command.

Also: `192.0.2.50-192.0.2.59` must be in the node primary subnet of `dev-01` and must not overlap another pool, the pod CIDR, or the service CIDR. [pdf p.672] The `192.0.2.0/24` range is a documentation range; if that is really your address range, fine; if you typed an example, give me the real one. The MetalLB webhook rejects an overlap and the server dry run shows it.

### Checks first (read-only)

```bash
# READ-ONLY
source ~/nkp-dev-01.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n metallb-system get ipaddresspools,l2advertisements
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get svc -A --field-selector spec.type=LoadBalancer
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get events -A --field-selector reason=AllocationFailed
```

I need the pool list to show that the new range is free, and the Service list to show how full the current pool is.

### The plan (I stop here for your "yes")

- File: `$PWD/dev-01-metallb-apps.yaml`
- Objects: `IPAddressPool` `apps` with addresses `192.0.2.50-192.0.2.59` and `L2Advertisement` `apps`, both in `metallb-system` on `dev-01`.
- Result: 10 more LoadBalancer IPs. They are not given to a Service by itself if `autoAssign: false`: a Service asks for the pool with `metallb.io/address-pool: apps`, or for one IP with `metallb.io/loadBalancerIPs: <ip>`. [field]
- Nothing else changes. The default pool and its advertisement stay as they are.

Step 1 — write the file (CHANGES on the operator host, nothing in the cluster):

```bash
# CHANGES  (writes the pool file on the operator host; changes no cluster)
source ~/nkp-dev-01.env 2>/dev/null
pool='apps'; auto='false'
: "${APP_LB_RANGE:?}"
printf -- 'apiVersion: metallb.io/v1beta1\nkind: IPAddressPool\nmetadata:\n  name: %s\n  namespace: metallb-system\nspec:\n  autoAssign: %s\n  addresses:\n  - %s\n---\napiVersion: metallb.io/v1beta1\nkind: L2Advertisement\nmetadata:\n  name: %s\n  namespace: metallb-system\nspec:\n  ipAddressPools:\n  - %s\n' "$pool" "$auto" "$APP_LB_RANGE" "$pool" "$pool" > "$PWD/$CLUSTER_NAME-metallb-$pool.yaml"
```

That block needs `APP_LB_RANGE` in `~/nkp-dev-01.env`. You gave the range, so after you confirm it I append it (rule 4):

```bash
# CHANGES  (appends APP_LB_RANGE to the cluster env file)
source ~/nkp-dev-01.env 2>/dev/null
echo "export APP_LB_RANGE='192.0.2.50-192.0.2.59'" >> "$HOME/nkp-$CLUSTER_NAME.env"
```

Step 2 — preview (read-only):

```bash
# READ-ONLY  (server dry run: the API server and the MetalLB webhook check the objects and change nothing)
source ~/nkp-dev-01.env 2>/dev/null
pool='apps'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" apply --dry-run=server -f "$PWD/$CLUSTER_NAME-metallb-$pool.yaml"
```

`created (server dry run)` for both objects: good. `overlaps with already defined CIDR`: the range is in another pool; give me a new range.

Step 3 — apply, after your "yes":

```bash
# CHANGES  (creates the MetalLB pool and its L2Advertisement)
source ~/nkp-dev-01.env 2>/dev/null
pool='apps'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" apply -f "$PWD/$CLUSTER_NAME-metallb-$pool.yaml"
```

### Questions

1. Do you confirm the range `192.0.2.50-192.0.2.59`, and is it a real free range in the node subnet of `dev-01`?
2. Pool name: `apps`? Or another name?
3. `autoAssign: false` (Services must ask for the pool) or `true` (MetalLB may use these IPs for any Service)? Default in the block is `false`.
4. If the site has a proxy: must these 10 IPs go into `NO_PROXY_LIST`? Add them when a Service behind them must be reached without the proxy. [pdf p.980]

I run nothing before your "yes".

---

## nkp-networking W7

Skill files read: `_shared/RULES.md`, `nkp/SKILL.md`, `nkp-networking/SKILL.md`, `nkp-networking/references/cni.md` (C3, C4), `nkp-networking/references/metallb.md` (M1).

**Skill: `nkp-networking`, its file `cni.md`, section C4.**

Why it happens, as the skill states it:

- On AHV the default Cilium datapath uses `bpf-lb-mode: dsr` (Direct Server Return) with Geneve dispatch. [live 2.19.0]
- With DSR, a node that does **not** own the Service IP can send the reply. On subnets that the AHV Network Controller manages (a Network Controller VLAN) and on VPC overlay subnets, the network drops that reply. Small requests from inside the node subnet can still work, so `kubectl` to the VIP answers while the UI IP does not. [field]
- The API VIP is kube-vip, not MetalLB, so it is not affected by the DSR path. That is exactly your symptom: the VIP answers, the UI LoadBalancer IP does not.
- The field fix is `loadBalancer.mode: snat` in the Cilium Helm values. UNKNOWN (N-01): whether the default DSR mode is the cause on Network Controller VLANs, and whether SNAT is the fix. That is not proven in the lab.

The limit that matters: a running cluster ignores new Cilium values. The values reach Cilium only when the cluster uses them from the create. [pdf p.727] So a fix needs a **new cluster** with SNAT, or a change of the values ConfigMap before the create (C3). For a **management** cluster, the skills do not have the fix. I do not offer NodePort plus an external load balancer as a fix for this. [field]

### Checks first (read-only)

```bash
# READ-ONLY
source ~/nkp-dev-01.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n kube-system get configmap cilium-config -o jsonpath='{.data.bpf-lb-mode}{"\n"}'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get svc -A --field-selector spec.type=LoadBalancer
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n metallb-system get ipaddresspools,l2advertisements
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n metallb-system get pods -o wide
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n kube-system exec ds/cilium -c cilium-agent -- cilium-dbg status --brief
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n kube-system exec ds/cilium -c cilium-agent -- ip -o link show | awk '{print $2, $4, $5}'
```

- `cilium-config` `bpf-lb-mode` value `dsr` confirms the default datapath.
- A LoadBalancer Service with an EXTERNAL-IP and a healthy speaker set rules out M1 (a Service with no IP).
- All `cilium-dbg status --brief` lines print `OK`? Then the CNI is healthy and this is a return-path problem, not a broken pod.
- The NIC MTU must be the same on all nodes (C5). A Network Controller VLAN with a wrong MTU gives other symptoms (large packets hang), so check it while we are here.

Then one test that settles it (USER-TERMINAL, from a host **outside** the node subnet, and from a host **inside** it, for example a control-plane node):

```bash
# USER-TERMINAL  (outside host; you run it. Use the UI IP from the Service list above)
curl -sS -o /dev/null -w '%{http_code}\n' -m 5 https://<ui-ip>/
ping -c 3 <ui-ip>
```

- Works from inside the subnet, fails from outside, and ARP for the IP resolves to a node MAC: that is the DSR return-path signature.
- Fails from both: not this problem. Then check MetalLB (M1) and Traefik.

### Questions

1. Is this the **management** cluster or a workload cluster? For a management cluster the fix is not in the skills, and I will say so plainly.
2. Did it ever work from outside the subnet, and what changed (a subnet move to a Network Controller VLAN, a VPC change, an AHV upgrade)?
3. Do you have the option of a new cluster with `loadBalancer.mode: snat` in the Cilium values ConfigMap before the create (C3)? That is the only fix the skills give.
4. Does the AHV subnet have `advanced` or VPC settings, and what is its MTU? [pdf p.711]

Not in the skills: an in-place change from DSR to SNAT on a running AHV cluster, and a fix for the management cluster. If you need either, it is a Nutanix support case; I do not invent a procedure.

---

## nkp-networking W9

Skill files read: `_shared/RULES.md`, `nkp/SKILL.md`, `nkp-networking/SKILL.md`, `nkp-networking/references/proxy.md` (X0, X2, X3), `nkp-install/references/cloud.md` (C8, the vSphere create script).

**Skill: `nkp-networking`, its file `proxy.md`, section X3 (vSphere row) with skill `nkp-install`.**

The rule for vSphere: `--http-proxy`, `--https-proxy`, `--no-proxy` alone set the **CAPI controllers** and give **nodes with no proxy**. So a vSphere cluster needs all nine flags. [live 2.19.0][pdf p.668-669]

Your create script is `~/nkp-vs-01-create.sh` (the name pattern of `nkp-install`; tell me if yours differs). Add these nine lines before `"$@"`:

```text
  --control-plane-http-proxy "$NKP_HTTP_PROXY" \
  --control-plane-https-proxy "$NKP_HTTPS_PROXY" \
  --control-plane-no-proxy "$NO_PROXY_LIST" \
  --worker-http-proxy "$NKP_HTTP_PROXY" \
  --worker-https-proxy "$NKP_HTTPS_PROXY" \
  --worker-no-proxy "$NO_PROXY_LIST" \
  --http-proxy "$NKP_HTTP_PROXY" \
  --https-proxy "$NKP_HTTPS_PROXY" \
  --no-proxy "$NO_PROXY_LIST" \
```

### Checks first (read-only)

```bash
# READ-ONLY
source ~/nkp-vs-01.env 2>/dev/null
tr ',' '\n' <<< "$NO_PROXY_LIST" | wc -l
case "$NKP_HTTP_PROXY $NKP_HTTPS_PROXY" in *@*) echo "proxy URL has a user or password";; *) echo "no credentials in the proxy URL";; esac
curl -sS -o /dev/null -w '%{http_code}\n' --proxy "$NKP_HTTPS_PROXY" https://registry.k8s.io/v2/
ls -l "$HOME/nkp-$CLUSTER_NAME-create.sh"
grep -c 'proxy' "$HOME/nkp-$CLUSTER_NAME-create.sh"
```

- The item count must be 128 or fewer (`additionalNo` maximum). [live 2.19.0]
- The proxy must answer with an HTTP code that is not `000`.
- `grep -c 'proxy'` prints `0` if the script has no proxy lines yet.

Two things to confirm about your `NO_PROXY_LIST`, because a workload cluster's list must also name the management cluster API VIP as a **single IP** (the Kommander UI does not read a CIDR in no-proxy): [pdf p.979]
- the management cluster `CP_VIP`,
- the first IP of `LB_IP_RANGE` (the `kommander-traefik` address),
- the Prism Central host and the mirror host, if this site has them in the list.

Read the current list without printing secrets — the list itself is not a secret, but I show only the entries:

```bash
# READ-ONLY
source ~/nkp-vs-01.env 2>/dev/null
tr ',' '\n' <<< "$NO_PROXY_LIST" | grep -v -E '^(localhost|127\.0\.0\.1|kubernetes|\.svc|svc\.)' | head -40
```

### Plan (I stop for your "yes")

- Target: `~/nkp-vs-01-create.sh` on the operator host.
- Result: the new cluster's nodes (control plane and workers) and the CAPI controllers use `proxy.corp.example.com`; the entries in `NO_PROXY_LIST` bypass it.
- Then: the dry run (CHANGES, writes the objects to a local file), the check of the dry-run lines, then the create. UNKNOWN (N-23): whether the three `--*-proxy` controller flags also reach `clusterConfig.proxy` on every provider. I check the controller env after the create.

### Questions

1. Does `~/nkp-vs-01.env` hold `NO_PROXY_LIST` for **this** cluster, or the list of another cluster? The list must name the API VIP of the management cluster and the first LB IP. [pdf p.979]
2. Does the proxy URL hold a user and a password? If yes: it is a secret; you write `NKP_HTTP_PROXY` and `NKP_HTTPS_PROXY` in `~/nkp-site.env` with your editor (rule 5), and some blocks become USER-TERMINAL.
3. Is `nkp-vs-01` the cluster name, and is the script path `~/nkp-vs-01-create.sh`?
4. After the create: do you want the platform-app pods behind the proxy too (the `gatekeeper-overrides` change and the namespace labels)? That is a separate step, X4.

I do not edit the script now.

---

## nkp-networking W10

Skill files read: `_shared/RULES.md`, `nkp/SKILL.md`, `nkp-networking/SKILL.md`, `nkp-networking/references/proxy.md` (X0, X4, X5, X6), `nkp-cluster-lifecycle/references/variables.md` (V2, V5).

**Skills: `nkp-networking` (proxy.md, X0 and X5) and `nkp-cluster-lifecycle` (step 3) for the node part.**

First the rule for the credentials: a proxy URL with a user and a password **is a secret**. I do not repeat it, I do not put it in a command in the chat, and I do not write it into an example line. You write the two lines in `~/nkp-site.env` with your editor:

```bash
# USER-TERMINAL  (operator host; you add NKP_HTTP_PROXY and NKP_HTTPS_PROXY with an editor)
vi ~/nkp-site.env
```

Two facts to know before we start:

- NKP keeps the proxy URL **as plain text** in the NKPCluster and in the ConfigMap `gatekeeper-overrides`. Anyone who can read those objects reads the password. Change the password if that is not acceptable, and consider a dedicated account for NKP (yours is `svc-nkp`).
- Part C of the change replaces **all nodes** of `nkp-mgmt`. [pdf p.672]

### Checks first (read-only)

```bash
# READ-ONLY
source ~/nkp-nkp-mgmt.env 2>/dev/null
case "$NKP_HTTP_PROXY $NKP_HTTPS_PROXY" in *@*) echo "proxy URL has a user or password";; *) echo "no credentials in the proxy URL";; esac
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get nkpcluster "$CLUSTER_NAME" -o json | jq -c '.spec.capiCluster.topology.variables[] | select(.name=="clusterConfig") | .value.proxy // {} | {http: ((.http // "") | length), https: ((.https // "") | length)}'
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n capx-system get deploy capx-controller-manager -o jsonpath='{.spec.template.spec.containers[0].env[*].name}{"\n"}'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n kommander get configmap gatekeeper-overrides -o jsonpath='{.metadata.name}{"\n"}' 2>/dev/null || echo "no gatekeeper-overrides ConfigMap"
```

- The first block prints only the lengths of the URLs, never the URLs.
- The `gatekeeper-overrides` **content** prints the URL with the password. So that command prints only the object name. You read the values yourself if you need them.

I also need a positive test that the authenticated proxy works before we change the cluster. That block prints a URL on the command line, so it is USER-TERMINAL (X0):

```bash
# USER-TERMINAL  (operator host; you run it. It uses the proxy URL from the env file)
source ~/nkp-site.env 2>/dev/null
curl -sS -o /dev/null -w '%{http_code}\n' --proxy "$NKP_HTTPS_PROXY" https://registry.k8s.io/v2/
```

`200` or `204`: the credentials work. `407`: the proxy rejects them; fix that first.

### The plan, in three parts (each stops for your "yes")

| Part | Target | Result |
|---|---|---|
| A | the CAPI controllers and `git-operator` on `nkp-mgmt` | the pods restart and use the authenticated proxy |
| B | the `gatekeeper-overrides` ConfigMap and the namespace labels | new pods get `HTTP_PROXY`, `HTTPS_PROXY`, `NO_PROXY` |
| C | `clusterConfig.proxy` in the NKPCluster | **all nodes replaced**, control plane first |

Part A uses the X5 block (it reads `NKP_HTTP_PROXY` and `NKP_HTTPS_PROXY` from the env file, so the password is not typed into the command). Part B is X4: write the values file with mode 600, merge the old values, preview with a server dry run, apply, then label `kommander` and `kommander-flux`. Part C builds the value in the shell:

```text
value="$(jq -nc --arg h "$NKP_HTTP_PROXY" --arg s "$NKP_HTTPS_PROXY" --arg n "$NO_PROXY_LIST" '{http:$h,https:$s,additionalNo:($n|split(","))}')"
```

then the step 3 cluster-field patch with `field='proxy'`, the server dry run, the apply, and the rollout watch.

Verify at the end: the length check shows `http` and `https` longer than 0, the controller env lists `HTTP_PROXY HTTPS_PROXY NO_PROXY`, and the Gatekeeper mutation prints `["HTTP_PROXY","HTTPS_PROXY","NO_PROXY"]`. Do not use the Flux pod env as proof: the Flux chart always sets these variables. [live 2.19.0]

### Questions

1. Are `NKP_HTTP_PROXY` and `NKP_HTTPS_PROXY` in `~/nkp-site.env` now, with the account and password? (`printenv` check only; I never print the value.)
2. Does `NO_PROXY_LIST` need new entries for the internal hosts?
3. Is a full node replace of `nkp-mgmt` acceptable now (part C)? If not, A and B can run first; the nodes keep the old proxy until C.
4. Is `svc-nkp` a dedicated account, or a person's account? A dedicated account is better: the password sits in plain text in the cluster.

I run nothing before your "yes", and I never put the password in a command in this chat.
