---
name: nkp-upgrade
description: >
  Upgrade NKP: version path and order (Kommander, management cluster, workload clusters), nkp upgrade
  kommander, nkp upgrade cluster, platform apps, non-ClusterClass clusters (AWS, Azure, GCP, vSphere,
  pre-provisioned), GitOps-managed clusters, 2.18 to 2.19 gates (Docker Hub credentials, Prism Central
  project, Flux pruning), air-gapped upgrade, pre-checks, post-checks, an upgrade that fails or stops.
metadata:
  nkp_versions: "2.19"
  last_verified: "2026-11-02"
  sources: "live 2.19.0, pdf 2.19"
---

# NKP upgrade

<!-- RULES:BEGIN -->
## Rules for every NKP skill

1. **Marks.** Line 1 of each command block is `# READ-ONLY`, `# CHANGES`, or `# USER-TERMINAL`. CHANGES: it changes a cluster, the infrastructure, a registry, the container engine, or a file on the operator host. USER-TERMINAL: it shows a secret on the screen, or it runs on another host (the text after the mark names the host). Give it to the user to run in their own terminal. Do not run it.
2. **Approval.** Before a CHANGES block, show the command, the target, and the result. Stop. Run it only after the user types "yes" to that plan. "Just run it" is not "yes". If the user answers with another word (for example "proceed" or "ok"), ask them to type "yes".
3. **Env files.** Run blocks with bash. `~/nkp-site.env` holds the site values and the secrets. `~/nkp-<cluster>.env` holds the values of one cluster. Its first line is `source ~/nkp-site.env 2>/dev/null`. Line 2 of a block is `source ~/nkp-<cluster>.env 2>/dev/null` when the block uses a cluster-file variable. Otherwise line 2 is `source ~/nkp-site.env 2>/dev/null`. Before you run a block, replace `<cluster>` in `~/nkp-<cluster>.env` with the cluster name. If the user has not named the cluster, keep `~/nkp-<cluster>.env` in the block and ask for the name. Do not take a name from an example or another conversation. After the cluster env file exists, use its real name (for example `~/nkp-dev-01.env`) in every block that you show. Commands use the variables as `"$VAR"`.
4. **Values.** When you know a value, append one line to its file: `echo "export VAR='value'" >> ~/nkp-site.env` (CHANGES). Write a line only after the user gives or confirms the value. Ask first, and write the line in a later reply, after the answer. If the user has not given the value, do not show the append block. Do not put an example or a guessed value in it. Never write an empty value or a placeholder such as `<ip>`. A shell value inside a block (for example `obj=''`) stays empty, with its `:?` guard, until the user gives it. Never put `<...>` text in it. To change a value, append a new line. The last line wins. Some skill files add a `| File | Site variables |` table with more variables. For a value with no variable in these tables, make an UPPER_SNAKE name and ask the user. If `~/nkp-site.env` does not exist, make it: `touch ~/nkp-site.env && chmod 600 ~/nkp-site.env` (CHANGES).
5. **Secrets.** The user types the secret lines into `~/nkp-site.env` with an editor. Do not repeat or use a secret from the chat, and do not write it into an example line. Tell the user to put it in the file and to change it. Check a secret only with `printenv VAR >/dev/null` or `[ -n "$(printenv VAR)" ]`. Never print an env file, `env`, `set`, a kubeconfig, or Secret data.
6. **Unknowns.** Use only the UNKNOWN lines in the skills: `UNKNOWN (<id>): <what>. Find out with: <command>`. Run the check or ask the user. For a fact that is not in the skills, say "not in the skills" and give a READ-ONLY check. Never make up an ID or a fact.
7. **Offline.** Use only these skills, the bundle, `--help`, and the cluster. Read versions from the cluster or from `nkp version`.
8. **Tags.** `[live 2.19.0]` live cluster · `[pdf p.N]` NKP 2.19 guide · `[portal]` Nutanix portal · `[field]` not confirmed. Trust them in this order.

| File | Site variables |
|---|---|
| `~/nkp-site.env` | `MGMT_KUBECONFIG` `BUNDLE_DIR` `IMAGE_BUNDLES` `REGISTRY_URL` `REGISTRY_CA_FILE` `PC_ENDPOINT` `PC_CA_FILE` `PC_PROJECT` `PE_CLUSTER` `SUBNET` `STORAGE_CONTAINER` `VM_IMAGE` `SSH_PUBKEY_FILE` `NTP_SERVERS` `NKP_HTTP_PROXY` `NKP_HTTPS_PROXY` |
| `~/nkp-site.env` secrets | `NUTANIX_USER` `NUTANIX_PASSWORD` `REGISTRY_MIRROR_USERNAME` `REGISTRY_MIRROR_PASSWORD` `NUTANIX_REGISTRY_USERNAME` `NUTANIX_REGISTRY_TOKEN` |
| `~/nkp-<cluster>.env` | `CLUSTER_NAME` `CP_VIP` `LB_IP_RANGE` `WORKSPACE_NS` `CLUSTER_KUBECONFIG` `NO_PROXY_LIST` |
<!-- RULES:END -->

Site variables of this skill (rule 4; same use as the rules table):

| File | Site variables |
|---|---|
| `~/nkp-site.env` | `NKP_TARGET_VERSION` |
| `~/nkp-<cluster>.env` | `CP_VM_IMAGE` `WORKER_VM_IMAGES` |

- `NKP_TARGET_VERSION`: the NKP version to go to, with a `v`, for example `v2.19.0`.
- `VM_IMAGE` (rules table): during an upgrade, the name of the **target** OS image in Prism Central. Append the new name (rule 4).
- `CP_VM_IMAGE`, `WORKER_VM_IMAGES`: only for a cluster whose pools use different images. `WORKER_VM_IMAGES` has the form `md-0=image-a,gpu=image-b` and must name **every** worker pool. [live 2.19.0]

Do the steps in order. Start a step only after the "Done when" check of the step before it passes. An upgrade replaces every node. There is no rollback: an error does not start an automatic repair or rollback. [pdf p.1044]

## Step 1: Find the versions and the upgrade path

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
nkp version
kubectl --kubeconfig "$MGMT_KUBECONFIG" get nkpclusters -A -o custom-columns='NAMESPACE:.metadata.namespace,NAME:.metadata.name,NKP:.status.platformVersion,K8S:.status.kubernetesVersion,PHASE:.status.phase,MGMT:.metadata.labels.kommander\.d2iq\.io/host'
kubectl --kubeconfig "$MGMT_KUBECONFIG" get clusters.cluster.x-k8s.io -A
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n kommander get helmrelease kommander
```

- The `kommander` HelmRelease status text names the platform version (`kommander-chart@v2.19.0`). [live 2.19.0] A ClusterClass name has the NKP version of the cluster (`nkp-nutanix-v2.19.0`). [live 2.19.0]
- **Version path.** Go through each minor version in order. You can skip patch versions. [pdf p.1011] The only source version for 2.19.0 is 2.18.0. [pdf p.1011-1012] Is a cluster on 2.17 or older? Then stop: first upgrade to 2.18 with the 2.18 CLI. The 2.18 steps are not in the skills.
- **CLI.** The `nkp` line of `nkp version` must show the target version. A different CLI version can make the upgrade fail. [pdf p.1018] If not, install the target CLI first, then do step 1 again. Air-gapped: skill `nkp-airgap`, steps 1 and 2, with the target bundle. Connected: the user downloads it from the Nutanix portal. [pdf p.1018] The target CLI prints the target Kubernetes version: `nkp upgrade cluster nutanix --help | head -1` shows `1.36.2` for 2.19.0. [live 2.19.0]
- **Path for each cluster.** The CLUSTERCLASS column of `get clusters` works on each CAPI API version. A value in CLUSTERCLASS: the ClusterClass path ([references/clusterclass.md](references/clusterclass.md)). No value: the non-ClusterClass path ([references/non-clusterclass.md](references/non-clusterclass.md)). `nkp upgrade cluster` has only `eks`, `metal`, and `nutanix`. [live 2.19.0] The guide names AHV and EKS as ClusterClass providers, and AWS, Azure, GCP, vSphere, and pre-provisioned as non-ClusterClass. [pdf p.1018, p.1025]
- UNKNOWN (P-06): which providers make ClusterClass clusters in 2.19. Find out with: `source ~/nkp-site.env 2>/dev/null && kubectl --kubeconfig "$MGMT_KUBECONFIG" get clusters -A` (column CLUSTERCLASS).
- **GitOps.** Does Flux apply the cluster objects of a workload cluster from a Git repository? Ask the user. If yes, follow [references/gitops.md](references/gitops.md) for the whole upgrade.
- UNKNOWN (P-04): a full 2.18 → 2.19 upgrade was not run in the lab. The steps come from the guide. Find out with: `source ~/nkp-site.env 2>/dev/null && kubectl --kubeconfig "$MGMT_KUBECONFIG" get nkpclusters -A` after each step.

Ask the user for the target version. Append `NKP_TARGET_VERSION` (rule 4). For each cluster, check the cluster env file as in skill `nkp-cluster-lifecycle`, step 1.

Done when: the CLI shows the target version, every cluster is on the source version, and each cluster has a path.

## Step 2: Gates (pre-checks)

Do every gate that matches the site. A gate that fails stops the upgrade.

| Gate | Applies to | Check | Fix |
|---|---|---|---|
| G1 Health | all clusters | block A: PHASE `Reconciled`, no rows in the other lists | skill `nkp-troubleshooting` |
| G2 Docker Hub credentials | connected site (not air-gapped) | [references/dockerhub.md](references/dockerhub.md) | same |
| G3 One Prism Central project | AHV ClusterClass clusters from 2.18 | block B | section "Gate: one Prism Central project" |
| G4 Flux pruning off | GitOps-managed workload clusters | [references/gitops.md](references/gitops.md), F1 | same |
| G5 OCI catalogs only | all | block C; the Kommander upgrade does the real check | skill `nkp-platform-apps-gitops`, file `catalogs.md` K4 |
| G6 CloudNativePG | clusters that run AI Navigator or NKP Insights | block C: `cloudnative-pg` is in the list | skill `nkp-platform-apps-gitops`, file `catalogs.md` K5 (also Harbor; check each namespace) |
| G7 OS image | each cluster | the user confirms the image (step 3) | step 3 |
| G8 Prism Central roles | Nutanix | the user confirms: the role has the permissions of the old **and** the new version [pdf p.1009] | the PC admin |
| G9 Room for new nodes | each pool | each pool needs room for one more VM (skill `nkp-cluster-lifecycle`, V2) | the infrastructure admin |

- G5: 2.19 has only `kommander-flux/management` [live 2.19.0]; 2.18 can have more. The Kommander upgrade stops on GitRepository-based catalog apps. `--allow-gitrepository-catalog-apps` skips this check. [pdf p.1018][live 2.19.0] Use it only when the user decides so.
- G6: the Kommander upgrade checks that CloudNativePG is on where AI Navigator or NKP Insights runs. [pdf p.1018]
- Flow CNI workload cluster: before the upgrade, do the pre-upgrade read of skill `nkp-flow-cni` (section "What changes on a Flow CNI cluster", N-34).
- Optional: a Velero backup before the upgrade (skill `nkp-storage-backup`, file `velero.md` B3). [pdf p.1010] Pod Disruption Budgets keep apps up during the node drain. [pdf p.1010] The node OS image must boot with cgroups v2. NKP does not support cgroups v1 nodes. [pdf p.1009]

Block A (health), then block A2 for each workload cluster:

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" get nkpclusters -A
kubectl --kubeconfig "$MGMT_KUBECONFIG" get upgradeplans -A
kubectl --kubeconfig "$MGMT_KUBECONFIG" get helmreleases -A | awk 'NR==1 || $4!="True"'
kubectl --kubeconfig "$MGMT_KUBECONFIG" get machines -A | awk 'NR==1 || $0 !~ /Running/'
kubectl --kubeconfig "$MGMT_KUBECONFIG" get nodes | awk 'NR==1 || $2!="Ready"'
kubectl --kubeconfig "$MGMT_KUBECONFIG" get pdb -A | awk 'NR==1 || $(NF-1)=="0"'
```

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get nodes | awk 'NR==1 || $2!="Ready"'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get pdb -A | awk 'NR==1 || $(NF-1)=="0"'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get helmreleases -A | awk 'NR==1 || $4!="True"'
```

- `upgradeplans`: an UpgradePlan that is not `Upgraded` or `Failed` is an upgrade in progress. Do not start another one. [live 2.19.0] `Failed`: go to [references/stopped.md](references/stopped.md), S1. `pdb`: a PDB with 0 allowed disruptions stops the node drain. Tell the user.

Block B (Prism Central projects, AHV) [pdf p.1015, adapted]. It selects the clusters by the label `cluster.x-k8s.io/provider=nutanix` [live 2.19.0]. Each AHV cluster must have one line with one project. No line for an AHV cluster: stop. The 2.18 field names are not confirmed (P-04).

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" get nkpclusters -A -l cluster.x-k8s.io/provider=nutanix -o json | jq -r '.items[] | .spec.capiCluster.topology as $t | [.metadata.namespace, .metadata.name,
  ([($t.variables[]? | select(.name=="clusterConfig") | (.value.controlPlane.nutanix.machineDetails.project.name // "_internal")), ($t.workers.machineDeployments[]?.variables.overrides[]? | select(.name=="workerConfig") | (.value.nutanix.machineDetails.project.name // "_internal"))] | unique | join(","))] | @tsv'
```

Block C (catalogs and apps):

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" get gitrepositories -A
kubectl --kubeconfig "$MGMT_KUBECONFIG" get appdeployments -A | grep -E 'cloudnative-pg|ai-navigator|nkp-insights'
```

Done when: every gate that applies passes, and the user confirms G7 and G8.

### Gate: one Prism Central project

NKP 2.19 needs one Prism Central project for the control plane and all node pools of a cluster. [pdf p.1015] If block B shows two projects for a cluster, the user moves the pools that differ from the control plane into its project with the NKP UI (edit the node pool). [pdf p.1016] The agent does not patch the project (skill `nkp-cluster-lifecycle`, V7). `nkp update nodepool` does not change the project. [pdf p.1016] After this, you cannot change the project of the cluster again. [pdf p.1016] Done when: block B shows one project for each cluster.

## Step 3: Prepare the CLI, the images, and the OS images

1. **Air-gapped site.** Do skill `nkp-airgap`, step 4, with the target bundle (step 1 installed the CLI): push the target bundles into the registry **before** the Kommander upgrade. [pdf p.1012-1015] Add the NDK catalog bundle only for NDK on Nutanix. [pdf p.1015]
   - UNKNOWN (P-21): with the internal registry mirror, whether each workload cluster also needs the push (with its own kubeconfig), or only the management cluster. Find out with: `source ~/nkp-site.env 2>/dev/null && kubectl --kubeconfig "$MGMT_KUBECONFIG" get nkpclusters -A -o custom-columns='NAME:.metadata.name,MIRROR:.spec.capiCluster.topology.variables[?(@.name=="clusterConfig")].value.globalImageRegistryMirror.url'`.
2. **Pre-provisioned hosts.** Upload the target artifacts to the hosts before the addon upgrade. [pdf p.1014, p.1026] Use skill `nkp-airgap`, section "Pre-provisioned hosts" (O4) of its OS image file.
3. **OS image (G7).** AHV: the target image is in Prism Central, with the name from the Nutanix portal unchanged. [pdf p.1019] Its name has the target Kubernetes version (step 1). The preflight check finds the image by name. [pdf p.726] A custom image is built with the target CLI (skill `nkp-airgap`, OS images and NIB). [pdf p.1019] Other providers: a new image for each provider ([references/non-clusterclass.md](references/non-clusterclass.md)). Append the image name as `VM_IMAGE` (rule 4).
   - The image must have the target Kubernetes version (the line that the target CLI prints). [live 2.19.0] The guide also says "current" (p.1019, p.1039); P-23.

Done when: the push ended without an error (air-gapped), and the user confirms the image names.

## Step 4: Upgrade Kommander (management cluster)

The Kommander upgrade comes first. It upgrades the management plane (the CAPI components and the ClusterClasses) and the platform apps of the management cluster. [pdf p.1017] From 2.18 to 2.19, use the CLI for this step and for step 5. [pdf p.1019]

- During the upgrade, the NKP UI and the APIs can be unavailable, and a custom domain can stop for some minutes. [pdf p.1018] Tell the user.
- Users of attached clusters are logged out. After the upgrade, they get a new kubeconfig (step 7). [pdf p.1017]
- This command and `nkp upgrade cluster` can run for more than 1 hour. Run them with no tool time limit. If your tool cannot do that, the user runs the block in their own terminal, and you watch with the READ-ONLY checks.
- Optional flags: `--core-app-timeout` (default 20m) and `--platform-apps-timeout` (default 1h). [live 2.19.0] The guide names `--disable-appdeployments` [pdf p.1018]. The 2.19.0 CLI rejects it (unknown flag) [live 2.19.0]. Do not use it.

```bash
# CHANGES  (upgrades Kommander, CAPI, the ClusterClasses, and the platform apps on the management cluster)
source ~/nkp-site.env 2>/dev/null
( set -o pipefail; nkp upgrade kommander --kubeconfig "$MGMT_KUBECONFIG" 2>&1 | tee -a "$HOME/nkp-upgrade-kommander.log" ); echo "exit: $?"
```

The output lists the checks: GitRepository catalog apps, CloudNativePG, new app dependencies, Docker Hub credentials, then "Upgrading ManagementPlane nkp-platform" and the platform apps. [pdf p.1018]

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" get managementplanes
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n kommander get helmreleases | awk 'NR==1 || $3!="True"'
```

Done when: `exit: 0`, VERSION and CURRENT VERSION of the ManagementPlane show the target version [live 2.19.0], and the HelmRelease list has only the header line. If not, go to "If the upgrade stops".

## Step 5: Upgrade the management cluster

Upgrade the management cluster before any workload cluster. [pdf p.1018] Use the cluster env file of the management cluster (`WORKSPACE_NS` is `kommander`). Follow the path from step 1: [references/clusterclass.md](references/clusterclass.md) section "Upgrade one cluster", or [references/non-clusterclass.md](references/non-clusterclass.md) section "Management cluster".

Done when: the check at the end of that section passes.

## Step 6: Upgrade the workload clusters

Do one cluster at a time, with its cluster env file. The management cluster must be on the target version first. [pdf p.1022] Clusters in one workspace can have different versions. [pdf p.1019]

- ClusterClass: [references/clusterclass.md](references/clusterclass.md), section "Upgrade one cluster". One command upgrades the platform apps, then Kubernetes and the infrastructure. [pdf p.1019] The user can also use the NKP UI, Administration > Upgrades. [pdf p.1022]
- Non-ClusterClass: [references/non-clusterclass.md](references/non-clusterclass.md), section "Workload cluster".
- Attached clusters: NKP does not upgrade them. The tool that made them upgrades them. [pdf p.1035]

Done when: step 7 passes for each upgraded cluster.

## Step 7: Post-checks

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get nkpcluster "$CLUSTER_NAME" -o custom-columns='NKP:.status.platformVersion,K8S:.status.kubernetesVersion,PHASE:.status.phase,CLASS:.spec.capiCluster.topology.classRef.name'
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get nkpcluster "$CLUSTER_NAME" -o jsonpath='{range .status.history[*]}{.platform.version} {.platform.completedAt} {.kubernetes.version} {.kubernetes.completedAt}{"\n"}{end}'
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get machines -l "cluster.x-k8s.io/cluster-name=$CLUSTER_NAME"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get nodes
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get pods -A | awk 'NR==1 || ($4!="Completed" && ($4!="Running" || substr($3,1,index($3,"/")-1)!=substr($3,index($3,"/")+1)))'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get helmreleases -A | awk 'NR==1 || $4!="True"'
```

Done when all these are true [pdf p.1044-1047][live 2.19.0]:
- NKP and K8S show the target versions, PHASE is `Reconciled`, and CLASS ends in the target version (ClusterClass).
- The last `history` line has the target versions and two times.
- All machines are `Running` with the target version. All nodes are `Ready` with the target version.
- The pod list has only the header line, or only old `Error` pods of a Job that the user accepts. (It shows `CrashLoopBackOff`, `ImagePullBackOff`, and READY `0/1`.)
- The HelmRelease list has only the header line.

Then, after the management cluster upgrade, give the users of attached clusters the URL of the new kubeconfig [pdf p.1018]:

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n kommander get svc kommander-traefik -o go-template='https://{{with index .status.loadBalancer.ingress 0}}{{or .hostname .ip}}{{end}}/token/plugin/kubeconfig{{"\n"}}'
```

## If the upgrade stops

Do not run the command again at once, and do not delete objects. Do the READ-ONLY checks in [references/stopped.md](references/stopped.md). They find the stage and the owner skill of the fix. The debug ladder and `nkp diagnose` are in skill `nkp-troubleshooting`.

## Changes from earlier versions

- 2.18: the NKPCluster object and its webhook came [field]. The management cluster moved to namespace `kommander`. [pdf p.1030] `nkp upgrade workspace` is deprecated: use `nkp upgrade platform-apps` for each non-ClusterClass cluster. [pdf p.1032]
- 2.19: one command upgrades a ClusterClass workload cluster (apps, Kubernetes, infrastructure). [pdf p.1019] Catalogs are OCI only (gate G5). One Prism Central project for each cluster (gate G3). [pdf p.1015]
- Field notes for 2.13 to 2.17 use `--charts-bundle`, `--disallow-charts-download`, and a `.tar.gz` for `--kommander-applications-repository`. [field] In 2.19.0 the flag `--kommander-applications-repository` has the default `v2.19.0`, and the other two flags are not in the help. [live 2.19.0] Do not use them.
