# Catalogs and catalog apps

Use this file from skill `nkp-platform-apps-gitops`. A catalog is a source of catalog apps (`App` objects) for a workspace or project. In 2.19, a catalog is an OCI artifact in a registry, and Flux reads it as an `OCIRepository`. [pdf p.357][live 2.19.0] The air-gapped steps (catalog bundles, `nkp push bundle`) are in skill `nkp-airgap` (its file `catalogs.md`).

| App type | Object | Scope | Upgrade |
|---|---|---|---|
| Platform app | `ClusterApp` (cluster-scoped), from `kommander-flux/management` | all workspaces | with the platform-apps set (skill `nkp-upgrade`) |
| Catalog app (NKP, partner, product such as NDK, your own) | `App` (namespaced), from a catalog `OCIRepository` | the workspace or project of the catalog | one app at a time (K3) |

Catalog apps and custom apps need Pro or Ultimate. Custom apps need Ultimate. [pdf p.26]

## K1. Read the catalogs and the catalog apps

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" get ocirepositories -A -l catalog.nkp.nutanix.com/catalog-source-artifact=true
kubectl --kubeconfig "$MGMT_KUBECONFIG" get gitrepositories -A
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get apps -o custom-columns='NAME:.metadata.name,APP-ID:.spec.appId,VERSION:.spec.version,SOURCE:.spec.sourceRef.kind'
```

- `nkp create catalog-app` puts the label `catalog.nkp.nutanix.com/catalog-source-artifact: "true"` on the `OCIRepository`. [live 2.19.0] The NKP OCIRepositories in `kommander` (charts, `kommander-applications`) are not catalogs. Do not change them.
- `gitrepositories`: in 2.19 the only one is `kommander-flux/management` (NKP). [live 2.19.0] Any other GitRepository with the label `kommander.d2iq.io/gitrepository-type: catalog` is an old Git catalog (K4). [field]
- On a fresh Starter install, both catalog lists are empty. [live 2.19.0]

## K2. Add an OCI catalog

1. The catalog artifact must be in a registry that the cluster can reach. Air-gapped: push the catalog bundle first (skill `nkp-airgap`, its file `catalogs.md`, C1 or C2). The URL is `oci://<registry host>/<repository>`. A collection (many apps) ends in `/collection`; one app ends in the app name. [pdf p.357]
2. Choose the scope. A catalog in workspace `kommander-workspace` goes to all workspaces and projects. `--workspace <name>` limits it to one workspace. `--project <name>` with `--workspace` limits it to one project. [pdf p.357][live 2.19.0]
3. Ask the user for the URL, the tag, and the scope. Preview (creates nothing; it prints the `OCIRepository`). [live 2.19.0]

```bash
# CHANGES  (client dry run only: prints the OCIRepository; creates nothing)
source ~/nkp-site.env 2>/dev/null
url=''; tag=''; ws=''; : "${url:?}" "${tag:?}" "${ws:?}"
nkp create catalog-app --url "$url" --tag "$tag" --workspace "$ws" --kubeconfig "$MGMT_KUBECONFIG" --dry-run
```

4. Show the plan (the URL, the tag, the namespace in the output). Stop for "yes". Then run the same block without `--dry-run`.

- Registry credentials: NKP adds the registry credentials of the CAPI cluster to the `OCIRepository`. `--secret-ref` (a `kubernetes.io/dockerconfigjson` Secret), `--cert-ref` (a TLS Secret), `--proxy-secret-ref`, and `--service-account` give other ones and turn that off. `--insecure` is for a plain-HTTP registry only. [live 2.19.0]
- `--interval` (default 6h) is how often Flux checks the catalog for new versions. [live 2.19.0]
- The aliases `catalog-collection` and `catalog-application` in the guide are the same command. [pdf p.357][live 2.19.0]

5. Check: the `OCIRepository` (K1) shows READY `True` and the apps of the catalog are in `get apps`. An error: read the message (skill `nkp-troubleshooting`, its file `flux.md`, F2). The message → owner table is in that file, F3.

Then enable a catalog app as a platform app (SKILL.md step 2), with the `App` name (for example `operator-0.25.1`). [pdf p.349] The AppDeployment has `appRef.kind: App`.

## K3. Upgrade a catalog app

Platform apps cannot use this command: it gives an error. [pdf p.351] The command takes the workspace **name**. [pdf p.351]

1. Read the versions: K1 (`get apps`, the APP-ID and VERSION columns), and the AppDeployment (`nkp get appdeployments -w <workspace>`). [pdf p.351][live 2.19.0]
2. Check the new version for the Kubernetes version of the cluster (the app `metadata.yaml`, field `k8sVersionSupport`). [pdf p.358] Check the app overrides for the new chart ([overrides.md](overrides.md), O7).
3. Show the plan (the app, the old and new version, the workspace or project). Stop for "yes".

```bash
# CHANGES  (upgrades one catalog app to a new version)
source ~/nkp-site.env 2>/dev/null
name=''; ver=''; ws=''; : "${name:?}" "${ver:?}" "${ws:?}"
nkp upgrade catalog-app "$name" --to-version "$ver" --workspace "$ws" --kubeconfig "$MGMT_KUBECONFIG"
```

- `name` is the AppDeployment name. `ver` is the version only (for example `0.25.2`). For a project app, add `--project <name>`. [pdf p.351][live 2.19.0]
- The command stops on GitRepository catalog apps (K4). `--allow-gitrepository-catalog-apps` skips that check. [live 2.19.0]

Done when: the AppDeployment shows the new `appRef.name` and the HelmRelease is Ready (SKILL.md step 2, item 5).

## K4. GitRepository catalogs → OCI catalogs (upgrade gate G5)

Before 2.19, a catalog could be a Flux `GitRepository` with the labels `kommander.d2iq.io/gitrepository-type: catalog` and `kommander.d2iq.io/gitapps-gitrepository-type: catalog`. [field] 2.19 deprecates these "GitRepository-based catalog apps". `nkp upgrade kommander`, `nkp upgrade platform-apps`, and `nkp upgrade catalog-app` check for them and stop. `--allow-gitrepository-catalog-apps` lets the upgrade continue. [pdf p.1018][live 2.19.0]

1. Find them (on the version before the upgrade):

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" get gitrepositories -A --show-labels | grep -v -E '^kommander-flux +management '
kubectl --kubeconfig "$MGMT_KUBECONFIG" get apps -A -o custom-columns='NS:.metadata.namespace,NAME:.metadata.name,SOURCE-KIND:.spec.sourceRef.kind,SOURCE:.spec.sourceRef.name' | grep -E 'NS|GitRepository'
kubectl --kubeconfig "$MGMT_KUBECONFIG" get appdeployments -A -o custom-columns='NS:.metadata.namespace,NAME:.metadata.name,APP:.spec.appRef.name,KIND:.spec.appRef.kind' | grep -E 'NS| App$'
```

   - No rows after the header lines: gate G5 passes. Go back to skill `nkp-upgrade`.
   - An `App` with SOURCE-KIND `GitRepository` and an AppDeployment that uses it: that app must move.

2. For each Git catalog, choose with the user:
   - **A. The same app exists in an OCI catalog** (NKP catalog, partner catalog, product catalog). Add that OCI catalog (K2) in the same workspace or project. [pdf p.357]
   - **B. Your own Git catalog.** Rebuild it as an OCI catalog: K6 (`nkp generate catalog-repository`, `nkp validate catalog-repository`, `nkp create catalog-bundle`), push it, then K2. The old layout (`helm-repositories/`, `services/<app>/<version>/`) does not work. The 2.19 layout is `applications/<app>/<version>/`. [pdf p.355][field]
   - **C. Keep it for now.** The user decides to run the upgrade with `--allow-gitrepository-catalog-apps` (skill `nkp-upgrade`). Record the decision. The apps stay on the Git catalog.

3. Move each AppDeployment to the OCI `App`. The App name must be the same `<app-id>-<version>` or a newer version.

UNKNOWN (P-30): how an AppDeployment moves from an App of a Git catalog to the same app in an OCI catalog: whether Kommander uses a new `App` with the same name without a reinstall, or the old catalog must go first. Find out with: `source ~/nkp-site.env 2>/dev/null && kubectl --kubeconfig "$MGMT_KUBECONFIG" get apps -A -o custom-columns='NS:.metadata.namespace,NAME:.metadata.name,SOURCE:.spec.sourceRef.name'` after K2 (two Apps with the same name in one namespace cannot exist).

   Until P-30 is closed, the agent does not delete the old Git catalog or the AppDeployment. Give the user the facts: the app keeps its data only if the HelmRelease name and namespace stay the same. Ask the user to test the move on a test workspace first.

4. Done when: item 1 shows no Git catalog apps, or the user chose C.

## K5. CloudNativePG (upgrade gate G6)

The 2.19 Kommander upgrade checks "that CloudNativePG is enabled on clusters that run NKP AI Navigator or NKP Insights". [pdf p.1018] NKP Insights needs `kube-prometheus-stack` and `cloudnative-pg`. [pdf p.307] AI Navigator Cluster Info Agent and AI Navigator RAG need `cloudnative-pg`. [pdf p.307] Harbor needs it too. [pdf p.308]

1. Read (all workspaces):

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" get appdeployments -A -o custom-columns='NS:.metadata.namespace,NAME:.metadata.name,APP:.spec.appRef.name' | grep -E 'NS|cloudnative-pg|ai-navigator|nkp-insights|harbor'
kubectl --kubeconfig "$MGMT_KUBECONFIG" get clusterapps | grep -E 'NAME|cloudnative-pg'
```

2. For each namespace (NS) that has `ai-navigator-*`, `nkp-insights`, or `harbor`, there must be a `cloudnative-pg` row in the same NS.
   If not, enable it there (SKILL.md step 2, `name=cloudnative-pg`, `app` = the ClusterApp name from the second command, for example `cloudnative-pg-0.29.0` [live 2.19.0]). It needs Pro or Ultimate. [live 2.19.0]
3. With cluster selection (Ultimate, `spec.clusterSelector`), the clusters of `cloudnative-pg` must include the clusters of the app that needs it. Compare the CLUSTERS column of `nkp get appdeployments -w <workspace>`. [live 2.19.0]
4. Do this **before** `nkp upgrade kommander`, on the source version. Wait until its HelmRelease is Ready on each cluster.

UNKNOWN (P-31): if the 2.18 ClusterApp name of CloudNativePG is the same as in 2.19 (`cloudnative-pg-0.29.0` is the 2.19.0 name). Find out with: `source ~/nkp-site.env 2>/dev/null && kubectl --kubeconfig "$MGMT_KUBECONFIG" get clusterapps | grep cloudnative-pg` on the source version.

Done when: each workspace that runs AI Navigator, NKP Insights, or Harbor has a Ready `cloudnative-pg`.

## K6. Build your own catalog

The tools run on any host with `nkp`. `nkp create catalog-bundle --airgapped` pulls images, so it needs internet (skill `nkp-airgap`, its file `catalogs.md`, C2). [pdf p.357][live 2.19.0]

Layout for each app version [pdf p.355-356]:

```text
applications/<app-name>/<app-version>/
  helmrelease/cm.yaml            default values ConfigMap
  helmrelease/helmrelease.yaml   OCIRepository + HelmRelease (spec.chartRef)
  helmrelease/kustomization.yaml
  helmrelease.yaml               Flux Kustomization
  kustomization.yaml
  metadata.yaml                  UI data: displayName, description, category, scope, licensing, k8sVersionSupport, ...
```

1. Make the files (CHANGES: writes files in the repository folder):

```bash
# CHANGES  (writes the layout of one app version in the catalog repository folder)
name=''; ver=''; dir=''; : "${name:?}" "${ver:?}" "${dir:?}"
nkp generate catalog-repository --apps "$name=$ver" --repo-dir "$dir"
```

2. The user edits the files: the chart URL in the `OCIRepository`, the default values in `cm.yaml`, and `metadata.yaml`. [pdf p.354]
   - Use the substitution variables `${releaseName}`, `${releaseNamespace}`, `${workspaceName}`, `${workspaceNamespace}`, `${appName}`, `${appVersion}`, `${clusterName}`, `${clusterType}`, `${clusterUUID}`. `${projectName}` and `${projectNamespace}` are set only in a project. Cluster labels are not available. [pdf p.356]
   - Put `${releaseName}` in resource names, so that two instances of the app can run in one namespace. [pdf p.356]
   - For a project app, the HelmRelease and the Kustomization must have a service account (Gatekeeper, skill `nkp-identity-security`). [live 2.19.0]
3. Validate (writes nothing):

```bash
# READ-ONLY
dir=''; : "${dir:?}"
nkp validate catalog-repository --repo-dir "$dir"
```

   `--apps name=version` validates one app. `--config` takes a validation config file; a `.bloodhound.yaml` file in the repository also works. [pdf p.354][live 2.19.0]

4. Bundle and push: skill `nkp-airgap`, its file `catalogs.md`, C2 (`nkp create catalog-bundle`, `--collection-tag` for more than one app). Then K2.

Done when: the new apps are in `get apps` (K1) of the target workspace.
