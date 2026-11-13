---
name: nkp-platform-apps-gitops
description: >
  NKP platform apps and catalog apps: enable or disable an app, AppDeployment overrides (values
  ConfigMaps, per workspace or per cluster), a bad override, HelmRelease exhausted or stuck (suspend
  reset), OCI catalogs, GitRepository catalog migration, CloudNativePG gate, Flux in NKP, workspaces
  and attached clusters as app targets, KommanderCluster not Joined, projects, project CD (GitOps
  source), Sealed Secrets and kubeseal.
metadata:
  nkp_versions: "2.19"
  last_verified: "2026-11-03"
  sources: "live 2.19.0, pdf 2.19, field"
---

# NKP platform apps and GitOps

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

This skill owns the app layer of NKP: platform apps and catalog apps, their overrides, catalogs, the Flux objects that NKP makes, and project CD. Diagnosis (which object fails, and its message) is in skill `nkp-troubleshooting` (its file `flux.md`). The upgrade order and the `nkp upgrade kommander` and `nkp upgrade platform-apps` commands are in skill `nkp-upgrade`.

## How an app gets to a cluster [live 2.19.0][pdf p.271, p.1059]

`AppDeployment` (workspace or project namespace, management cluster) → `ClusterApp` (platform app, cluster-scoped) or `App` (catalog app, namespaced) → `AppDeploymentInstance` (one for each target cluster) → Flux `Kustomization` → `HelmRelease` → chart source (`OCIRepository` by `spec.chartRef`, or `HelmChart`).

- The AppDeployments are on the management cluster. The HelmReleases, the Kustomizations, and their sources are on the **target** cluster: in `kommander` on the management cluster, in the workspace namespace on a workload cluster. [pdf p.1047][live 2.19.0]
- A ClusterApp name is `<app-id>-<catalog version>` (for example `traefik-39.0.7`). The catalog version, the chart version, and the image version can all differ (Dex: catalog 2.14.5, chart 2.14.2, image v2.42.0). [live 2.19.0]
- A workspace name and its namespace are different. `nkp` commands take the **name** (`--workspace`). `kubectl` takes the **namespace**. The management cluster is in workspace `kommander-workspace`, namespace `kommander`. [live 2.19.0]
- Platform apps of a workspace come as one set. You upgrade them together, for each workspace or cluster (skill `nkp-upgrade`). A catalog app upgrades alone. [pdf p.305, p.350]
- The apps of a workspace go to every cluster in it, also to a cluster that you attach later. [pdf p.320] A cluster cannot move to another workspace. [pdf p.318]
- Foundational apps: `kommander-flux`, `reloader`, `traefik`. Do not disable them. [pdf p.299]

## Job → section

| Job | Where |
|---|---|
| Read the apps, versions, and license of a workspace or cluster | step 1 |
| Enable or disable an app (platform or catalog) | step 2 |
| Change the values of an app (override ConfigMap), per workspace or per cluster; remove an override | [references/overrides.md](references/overrides.md) |
| Traefik NodePort for an external load balancer, Traefik external-dns name, external-dns values | [references/overrides.md](references/overrides.md), O8 |
| HelmRelease `exhausted`, `another rollback/release in progress`, `upgrade retries exhausted` | step 3 |
| Bad override: `values` or schema error in the HelmRelease message | [references/overrides.md](references/overrides.md), O5 |
| AppDeployment is fine, but no HelmRelease on the cluster; KommanderCluster not `Joined`; attach a cluster | step 4 |
| Catalogs: list, add an OCI catalog, upgrade a catalog app, build your own catalog | [references/catalogs.md](references/catalogs.md) |
| Upgrade gate G5 (GitRepository catalog apps) and gate G6 (CloudNativePG) | [references/catalogs.md](references/catalogs.md), K4 and K5 |
| Project CD: a GitOps source (Git repository) for a project; Sealed Secrets and `kubeseal` | [references/project-cd.md](references/project-cd.md) |
| Flux in NKP: what you can change, and what NKP owns | step 5 |
| Make a workspace or a project, roles and RBAC, Gatekeeper constraints | skill `nkp-identity-security` |
| Offline catalog bundles, push a bundle, the Sealed Secrets files for an air-gapped site | skill `nkp-airgap` |

## Step 1: Read the apps

Ask the user for the cluster. A block that uses `WORKSPACE_NS` sources the cluster env file. For the management cluster, `WORKSPACE_NS` is `kommander`.

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n kommander get licenses.kommander.mesosphere.io -o jsonpath='{.items[*].status.dkpLevel}{"\n"}'
kubectl --kubeconfig "$MGMT_KUBECONFIG" get workspaces
nkp get clusters -A --kubeconfig "$MGMT_KUBECONFIG"
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get appdeployments -o custom-columns='NAME:.metadata.name,APP:.spec.appRef.name,KIND:.spec.appRef.kind,WS-OVERRIDE:.spec.configOverrides.name,CLUSTER-OVERRIDES:.spec.clusterConfigOverrides[*].configMapName'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get helmreleases -A
```

- The first line is the license tier (`Starter`, `Pro`, `Ultimate`). [live 2.19.0]
- `workspaces` shows NAME and WORKSPACE NAMESPACE. Use them as the note above says.
- `nkp get appdeployments -w <workspace name>` gives the same list with a CLUSTERS column. [live 2.19.0]

Which apps can the workspace use? A ClusterApp has the license tier, the scope (`workspace` or `project`), and the apps that it needs in its annotations. [live 2.19.0]

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" get clusterapps -o custom-columns='NAME:.metadata.name,LICENSE:.metadata.annotations.apps\.kommander\.d2iq\.io/licensing,SCOPE:.metadata.annotations.apps\.kommander\.d2iq\.io/scope,NEEDS:.metadata.annotations.apps\.kommander\.d2iq\.io/dependencies'
kubectl --kubeconfig "$MGMT_KUBECONFIG" get apps -A
```

- An app that does not list the tier of the site is not for this site. The API does not stop it. [live 2.19.0] Tell the user.
- `apps -A`: the catalog apps (namespaced). On a fresh 2.19.0 Starter install, the list is empty. [live 2.19.0]
- For the target cluster of each app, read the AppDeployment status:

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
app=''; : "${app:?}"
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get appdeployment "$app" -o jsonpath='{range .status.clusters[*]}{.name}{"\t"}{range .conditions[*]}{.type}={.status} {.message}; {end}{"\n"}{end}'
```

Done when: you know the tier, the workspace name and namespace, the AppDeployments, and the HelmReleases of the cluster. A healthy app shows `AppDeploymentEnabled=True AppDeploymentInstanceSynced=True` and a Ready HelmRelease. [live 2.19.0]

## Step 2: Enable or disable an app

1. Find the exact ClusterApp or App name in step 1 (`<app-id>-<version>`). Check its license and the apps in NEEDS. Enable the needed apps first. If a needed app fails, the app fails too. [pdf p.298]
2. Ask the user: the workspace, and all clusters or some clusters. Some clusters (`--clusters`) is Ultimate only. [pdf p.321] Never use workspace `kommander-workspace` for a workload cluster. [pdf p.428] A project app also needs `--project`. [pdf p.373]
3. Preview. `--dry-run` prints the YAML. It then prints an `INF ... created` line, but it creates nothing. [live 2.19.0] The block is marked CHANGES, because the same command without `--dry-run` creates the app. Show the plan and get "yes" for the preview too.

```bash
# CHANGES  (client dry run only: prints the AppDeployment; creates nothing)
source ~/nkp-<cluster>.env 2>/dev/null
name=''; app=''; ws=$(kubectl --kubeconfig "$MGMT_KUBECONFIG" get workspaces -o jsonpath="{.items[?(@.status.namespaceRef.name==\"$WORKSPACE_NS\")].metadata.name}")
: "${name:?}" "${app:?}" "${ws:?}"
nkp create appdeployment "$name" --app "$app" --workspace "$ws" --kubeconfig "$MGMT_KUBECONFIG" --dry-run
```

- `name` is the app ID (for example `velero`). `app` is the ClusterApp or App name (for example `velero-12.0.0`). [pdf p.298][live 2.19.0]
- Optional flags [live 2.19.0]: `--clusters c1,c2` (KommanderCluster names; the CLI checks that they exist), `--config-overrides <ConfigMap>` (make the ConfigMap first: [references/overrides.md](references/overrides.md)), `--project <name>`.

4. Show the plan (the app, the workspace, the clusters). Stop for "yes". Then run the same block without `--dry-run`, as CHANGES:

```bash
# CHANGES  (creates the AppDeployment; NKP installs the app on the target clusters)
source ~/nkp-<cluster>.env 2>/dev/null
name=''; app=''; ws=$(kubectl --kubeconfig "$MGMT_KUBECONFIG" get workspaces -o jsonpath="{.items[?(@.status.namespaceRef.name==\"$WORKSPACE_NS\")].metadata.name}")
: "${name:?}" "${app:?}" "${ws:?}"
nkp create appdeployment "$name" --app "$app" --workspace "$ws" --kubeconfig "$MGMT_KUBECONFIG"
```

5. Check. Kommander waits for an override ConfigMap before it deploys. [pdf p.350]

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
name=''; : "${name:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get helmreleases -A | grep -E "NAME|$name"
```

Done when: the HelmRelease of the app shows READY `True`. Not Ready after 15 minutes: skill `nkp-troubleshooting`, its file `flux.md`.

**Disable.** The guide disables an app in the UI (Applications, the app card, Disable). [pdf p.280] The CLI way is to delete the AppDeployment. [field] First check that no other enabled app has this app in NEEDS (step 1). Data of the app (PVCs) can be lost. Show the plan, stop for "yes":

```bash
# CHANGES  (deletes the AppDeployment; NKP removes the app from all its clusters)
source ~/nkp-<cluster>.env 2>/dev/null
name=''; : "${name:?}"
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" delete appdeployment "$name"
```

To disable an app on one cluster only, remove the cluster from `spec.clusterSelector` ([references/overrides.md](references/overrides.md), O4).

## Step 3: Reset a stuck HelmRelease

Use this when the HelmRelease message has `exhausted`, `another rollback/release in progress`, or `upgrade retries exhausted`. [pdf p.1047] NKP HelmReleases retry 30 times, then stop. [live 2.19.0]

1. Fix the cause first: read the message (skill `nkp-troubleshooting`, its file `flux.md`, F2). A bad override: [references/overrides.md](references/overrides.md), O5. A missing image: skill `nkp-airgap`. A reset without a fix fails again.
2. During an upgrade (`nkp upgrade` runs, or an UpgradePlan is not `Upgraded`), ask the user before the reset. Use skill `nkp-upgrade`, its file `stopped.md`.
3. Set `hr` to the HelmRelease name and `ns` to its namespace on the target cluster (`kommander` on the management cluster, the workspace namespace on a workload cluster). [pdf p.1047]

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
hr=''; ns=''; : "${hr:?}" "${ns:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" get helmrelease "$hr" -o jsonpath='suspend={.spec.suspend}{"\n"}{range .status.conditions[*]}{.type}={.status} {.reason}: {.message}{"\n"}{end}'
```

`suspend=true` before the reset: someone suspended it. Ask the user why, and do not continue without an answer.

4. Show the plan (the cluster, `hr`, `ns`; Helm tries the release again). Stop for "yes". Then:

```bash
# CHANGES  (suspends and resumes one HelmRelease; the helm-controller starts a new reconcile)
source ~/nkp-<cluster>.env 2>/dev/null
hr=''; ns=''; : "${hr:?}" "${ns:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" patch helmrelease "$hr" --type=json -p='[{"op":"replace","path":"/spec/suspend","value":true}]'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" patch helmrelease "$hr" --type=json -p='[{"op":"replace","path":"/spec/suspend","value":false}]'
```

5. Run the step 3.3 block again every minute for up to 10 minutes. Done when: `Ready=True`. If it fails again with the same message, stop and go back to item 1.

## Step 4: Clusters as app targets

An app reaches a cluster only when its KommanderCluster is `Joined`. [live 2.19.0][pdf p.432]

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" get kommanderclusters -A
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get kommanderclusters -o go-template='{{range .items}}{{.metadata.name}}: {{.status.phase}}{{"\n"}}{{range .status.conditions}}  {{.type}}={{.status}} {{.reason}}: {{.message}}{{"\n"}}{{end}}{{end}}'
```

On a healthy cluster, all conditions are `True`: `IngressAddressReady`, `IngressCertificateReady`, `PlatformAppDeploymentsReady`, `LoggingStackVersionReconciled`, `PlatformVersionReconciled`, `OCIRegistryConfigSynced`, `AttachmentCompleted`, `WorkspaceKustomizationCreated`, `ClusterKustomizationCreated`. [live 2.19.0] The first `False` condition is the cause:

| Condition `False` | Cause | Fix |
|---|---|---|
| `IngressAddressReady` (`IngressServiceNotFound`, no address) | Traefik has no LoadBalancer IP on the target cluster [pdf p.487] | skill `nkp-networking` (MetalLB) |
| `IngressCertificateReady` | The ingress certificate is not ready | skill `nkp-networking` (cert-manager) |
| `AttachmentCompleted` (`FailedToIdentifyCAPIResources`) | `spec.kubeconfigRef` names a wrong kubeconfig Secret [pdf p.488] | ask the user; attach again (below) |
| `OCIRegistryConfigSynced` | The registry settings for Flux on the target cluster | skill `nkp-airgap` |
| `PlatformAppDeploymentsReady` | A platform app failed | step 1, then skill `nkp-troubleshooting` |

- A managed cluster (NKP made it): also read the NKPCluster condition `KommanderClusterReady` (all NKPCluster conditions: skill `nkp-upgrade`, file `stopped.md`):

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get nkpcluster "$CLUSTER_NAME" -o jsonpath='{.status.conditions[?(@.type=="KommanderClusterReady")]}{"\n"}'
```

- A new cluster shows `Pending` until it joins. Wait 10 minutes. [pdf p.426]
- The controller is `kommander/kommander-cm`. Read its log with skill `nkp-troubleshooting` (its file `controllers.md`). [pdf p.1058]

**Attach an existing cluster** (Ultimate only). [pdf p.27] The target cluster needs a default StorageClass, x86-64 nodes, and reach from the management cluster to its API server. [pdf p.427] An existing cert-manager makes the NKP cert-manager HelmRelease fail; NKP says that you can ignore it. [pdf p.428] The kubeconfig file must not call a cloud CLI (EKS, AKS, GKE): the guide makes a service-account kubeconfig. [pdf p.428-430] That procedure is not in the skills. Ask the user for the file path and the cluster name. Show the plan, stop for "yes":

```bash
# CHANGES  (attaches a cluster into a workspace; NKP installs the workspace apps on it)
source ~/nkp-site.env 2>/dev/null
name=''; kcfg=''; ws=''; : "${name:?}" "${kcfg:?}" "${ws:?}"
nkp attach cluster --name "$name" --attached-kubeconfig "$kcfg" --workspace "$ws" --kubeconfig "$MGMT_KUBECONFIG"
```

`ws` is the workspace **name**, never `kommander-workspace`. [pdf p.428] Done when: `get kommanderclusters -A` shows `Joined` for it. [pdf p.432] To remove an attached cluster from NKP: `nkp detach cluster` (skill `nkp-cluster-lifecycle`, its file `delete.md`).

## Step 5: Flux in NKP

- Flux runs in `kommander-flux` on every cluster: `source-controller`, `kustomize-controller`, `helm-controller`, and `flux-oci-mirror`. [live 2.19.0] Versions in 2.19.0: chart `flux2` 2.18.3; source-controller v1.8.2, kustomize-controller v1.8.3, helm-controller v1.5.4. [live 2.19.0] The bundle has no `flux` CLI. Use `kubectl`. [live 2.19.0]
- NKP makes its own Flux objects from the GitRepository `kommander-flux/management` (the internal git-operator repository). Their Kustomizations have `prune: true`. [live 2.19.0] Do not edit or delete NKP HelmReleases or Kustomizations, except the step 3 reset. NKP applies them again. Change the values with an override.
- The chart sources (`OCIRepository`, `HelmChart`): skill `nkp-troubleshooting`, file `flux.md`.
- For your own apps from Git, use project CD ([references/project-cd.md](references/project-cd.md)). GitOps for the cluster objects (NKPCluster in Git, pruning) is in skill `nkp-upgrade` (its file `gitops.md`).
- In a project namespace, a HelmRelease or Kustomization needs `spec.serviceAccountName`, or Gatekeeper denies it: skill `nkp-identity-security`, file `gatekeeper.md`, G1.

## Related skills

Diagnosis: skill `nkp-troubleshooting`. Upgrades and the platform-apps upgrade: skill `nkp-upgrade`. Bundles, catalogs in an air gap, Sealed Secrets files: skill `nkp-airgap`. Traefik and cert-manager settings: skill `nkp-networking`. Workspaces, projects, RBAC, Gatekeeper: skill `nkp-identity-security`. App-specific values: skill `nkp-observability`, skill `nkp-storage-backup`, skill `nkp-gpu-ai`.
