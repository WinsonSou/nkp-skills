# RBAC, workspaces, projects

Use this file from skill `nkp-identity-security`. All commands run against the management cluster. KubeFed copies the objects to the clusters in scope. [pdf p.228, p.401]

## R1. Subject names

After a Dex login, Kubernetes sees these names. Use them in every binding and VirtualGroup. [pdf p.229, p.233]

| IdP scope | User | Group |
|---|---|---|
| Global (all workspaces) | `<email>` | `oidc:<idp-group>` |
| One workspace | `<workspace-name>:<email>` | `oidc:<workspace-name>:<idp-group>` |

- `<idp-group>` is the group value in the token, as Dex shows it (the Dex log line `login successful ... groups=[...]`, [identity.md](identity.md), I5). [pdf p.230, p.249]
- `<workspace-name>` is the NAME column of `kubectl get workspaces`. [pdf p.233]
- Users and groups from an IdP have no access until you bind them. RBAC is additive. [pdf p.231-232]
- The static admin user is bound to `cluster-admin`. [pdf p.233]

## R2. Which object to use

| Goal | Object | Notes |
|---|---|---|
| UI access | ClusterRoleBinding to `dkp-kommander-view`, `-edit`, or `-admin` (the dashboard) and to `dkp-view`, `-edit`, or `-admin` (all `/dkp/*` paths) | Both are needed. The guide adds the label `workspaces.kommander.mesosphere.io/rbac: ""`. [pdf p.228-229, p.236] |
| One app dashboard | ClusterRoleBinding to `dkp-<app>-view`, `-edit`, or `-admin` (for example `dkp-traefik-view`) | Only for installed apps. [pdf p.234-235][live 2.19.0] |
| Kubernetes access on the management cluster | ClusterRoleBinding or RoleBinding to `cluster-admin`, `admin`, `edit`, `view` | Plain Kubernetes RBAC. [pdf p.232] |
| The same group on many clusters | `VirtualGroup` plus a VirtualGroup binding | R3. KubeFed copies it. [pdf p.399] |
| Project access | `VirtualGroupProjectRoleBinding` | R6 |

- With Starter, the UI offers only `cluster-admin` and `view`. [pdf p.234] Kommander roles in the UI ("NKP RBAC") need Pro or Ultimate. [pdf p.28]
- Built-in ClusterRoles on 2.19.0: `dkp-admin`, `dkp-edit`, `dkp-view`, `dkp-kommander-admin`, `-edit`, `-view`, `dkp-traefik-*`, `kommander-admin`, `-edit`, `-view`, `kommander-federated-*`. More `dkp-*` roles come with the apps of the tier. [live 2.19.0]
- A grant on `/dkp/*` gives the same right to every path under it. [pdf p.234]
- `cluster-admin` has `nonResourceURLs: ["*"]`, so it also gives all `/dkp/*` paths. A subject with `cluster-admin` needs no `dkp-*` binding for the UI. [live 2.19.0]

## R3. Give a group UI and Kubernetes access (global)

1. Read the current state:

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" get clusterroles -o name | grep -E 'dkp-|kommander-'
kubectl --kubeconfig "$MGMT_KUBECONFIG" get clusterrolebindings -o custom-columns='NAME:.metadata.name,ROLE:.roleRef.name,SUBJECTS:.subjects[*].name' | grep -E 'dkp-|oidc:|@'
```

2. Ask the user for: the group or user name (R1), the level (`view`, `edit`, `admin`), and the cluster role for Kubernetes (`view`, `edit`, `admin`, `cluster-admin`). Write the file. Use `kind='User'` for a user.

```bash
# CHANGES  (writes the binding file on the operator host; changes no cluster)
name=''; kind='Group'; subject=''; level=''; k8srole=''
: "${name:?}" "${kind:?}" "${subject:?}" "${level:?}" "${k8srole:?}"
(umask 077 && cat > "$HOME/nkp-rbac-$name.yaml" <<EOF
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: $name-dkp-kommander
  labels:
    workspaces.kommander.mesosphere.io/rbac: ""
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: dkp-kommander-$level
subjects:
- apiGroup: rbac.authorization.k8s.io
  kind: $kind
  name: "$subject"
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: $name-dkp
  labels:
    workspaces.kommander.mesosphere.io/rbac: ""
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: dkp-$level
subjects:
- apiGroup: rbac.authorization.k8s.io
  kind: $kind
  name: "$subject"
---
apiVersion: kommander.mesosphere.io/v1beta1
kind: VirtualGroup
metadata:
  name: $name
spec:
  subjects:
  - apiGroup: rbac.authorization.k8s.io
    kind: $kind
    name: "$subject"
---
apiVersion: kommander.mesosphere.io/v1beta1
kind: VirtualGroupClusterRoleBinding
metadata:
  name: $name-$k8srole
spec:
  clusterRoleRef:
    name: $k8srole
  virtualGroupRef:
    name: $name
EOF
)
```

- The `VirtualGroupClusterRoleBinding` puts the Kubernetes role on all clusters. To limit the clusters, add `spec.placement.clusterSelector` or `spec.placement.clusters[].name`. [live 2.19.0] The UI way: Administration → Identity Providers → Groups tab, then Access Control → Cluster Role Bindings. [pdf p.243-244]
- UNKNOWN (P-43): whether a VirtualGroupClusterRoleBinding without `placement` reaches all attached clusters, or only the management cluster. Find out with: `source ~/nkp-<cluster>.env 2>/dev/null && kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get clusterrolebindings -l kubefed.io/managed=true -o custom-columns=NAME:.metadata.name,ROLE:.roleRef.name`.

3. Dry run. The file is the plan.

```bash
# READ-ONLY  (server dry run: changes nothing)
source ~/nkp-site.env 2>/dev/null
name=''
: "${name:?}"
kubectl --kubeconfig "$MGMT_KUBECONFIG" apply --dry-run=server -f "$HOME/nkp-rbac-$name.yaml"
```

4. After "yes":

```bash
# CHANGES  (adds the bindings and the VirtualGroup; the group gets access)
source ~/nkp-site.env 2>/dev/null
name=''
: "${name:?}"
kubectl --kubeconfig "$MGMT_KUBECONFIG" apply -f "$HOME/nkp-rbac-$name.yaml"
```

5. Check. `kubectl auth can-i` with `--as` asks the API server and changes nothing.

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
user=''; group=''
: "${user:?}" "${group:?}"
kubectl --kubeconfig "$MGMT_KUBECONFIG" auth can-i get /dkp/kommander/dashboard --as "$user" --as-group "$group"
kubectl --kubeconfig "$MGMT_KUBECONFIG" auth can-i list pods -A --as "$user" --as-group "$group"
```

Done when: each `can-i` prints `yes` for the levels that the user asked for. Then the user logs out and logs in again (the TFA cookie holds the old groups). [pdf p.584]

## R4. Namespace access only

A RoleBinding in one namespace to the ClusterRole `view`, `edit`, or `admin`. [pdf p.232] Use the R3 file form with `kind: RoleBinding`, `metadata.namespace`, and `roleRef.kind: ClusterRole`. Only on one cluster: run it with that cluster kubeconfig. For many clusters, use a project (R6).

## R5. Workspaces

- A workspace is a group of clusters and a tenant. Its namespace on the management cluster holds its NKPClusters, AppDeployments, and roles. [pdf p.317, p.366]
- Fresh install: `default-workspace` (namespace `kommander-default-workspace`) and `kommander-workspace` (namespace `kommander`, the management cluster). [live 2.19.0]
- A cluster cannot move to another workspace after the create or attach. [pdf p.318] A workspace can be deleted only when it has no clusters. [pdf p.318]
- Labels on a workspace go to its namespace and to all its KommanderClusters. [pdf p.318]
- Workspace management needs Ultimate. [pdf p.27]

Ask the user for the workspace name (`a-z`, `0-9`, `-`) and the display name. The CLI makes the namespace `<ws>-<5 random characters>` (for example `<ws>-7kr7h`), not `<ws>`. [live 2.19.0] Add `--namespace <name>` to both commands only when the user wants a fixed namespace name. [live 2.19.0] To show the plan as YAML, the user can approve a dry run first. The CLI has `--dry-run` and `-o yaml` [live 2.19.0] (not in the saved help text). After "yes" to "dry run of workspace <ws>":

```bash
# CHANGES  (dry run only: prints the Workspace object; creates nothing)
source ~/nkp-site.env 2>/dev/null
ws=''; display=''
: "${ws:?}" "${display:?}"
nkp create workspace "$ws" --display-name "$display" --kubeconfig "$MGMT_KUBECONFIG" --dry-run -o yaml
```

The plan: the name, the display name, the YAML, and "a cluster cannot move to another workspace later". After "yes":

```bash
# CHANGES  (creates the workspace and its namespace)
source ~/nkp-site.env 2>/dev/null
ws=''; display=''
: "${ws:?}" "${display:?}"
nkp create workspace "$ws" --display-name "$display" --kubeconfig "$MGMT_KUBECONFIG"
kubectl --kubeconfig "$MGMT_KUBECONFIG" get workspace "$ws"
```

Done when: the workspace shows a WORKSPACE NAMESPACE. Use that column as `WORKSPACE_NS`. Never put the workspace name in `WORKSPACE_NS`. To put a new cluster in it, use skill `nkp-install` with that namespace as `WORKSPACE_NS`.

**Delete a workspace.** There is no `nkp delete workspace` in 2.19.0. [live 2.19.0] Use the UI path [pdf p.318-319]:

1. Make sure that the workspace has no clusters. Delete or detach them first (skill `nkp-cluster-lifecycle`). You cannot delete `kommander-workspace` (the management cluster is in it). [pdf p.497]
2. The plan: the workspace, its namespace, "the delete removes the namespace and every object in it". After "yes", the user does this: Global → Workspaces → the three-dot button of the workspace → Delete → confirm in the Delete Workspace dialog.

```bash
# READ-ONLY  (before the delete: no cluster in the workspace; after the delete: what still blocks the namespace)
source ~/nkp-site.env 2>/dev/null
ws=''; wsns=''
: "${ws:?}" "${wsns:?}"
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$wsns" get nkpclusters,kommanderclusters
kubectl --kubeconfig "$MGMT_KUBECONFIG" get workspace "$ws" -o jsonpath='{.metadata.deletionTimestamp} {.metadata.finalizers}{"\n"}'
kubectl --kubeconfig "$MGMT_KUBECONFIG" get namespace "$wsns" -o jsonpath='{.status.phase}{"\n"}{range .status.conditions[*]}{.type}={.status} {.message}{"\n"}{end}'
```

Done when: `get workspace` and `get namespace` give `NotFound`.

If the namespace stays `Terminating`: the conditions `NamespaceContentRemaining` and `NamespaceFinalizersRemaining` name the objects that keep it. Lab test 1 (`kubectl delete workspace`) saw 27 `workspaceroles`, 7 kubefed `federated*` objects, and 2 `helm*proxies` with finalizers. [live 2.19.0] Do not remove finalizers: that skips the cleanup of the controllers. Show the conditions to the user and stop. UNKNOWN (P-55): whether a workspace delete finishes by itself after its clusters are deleted, and whether the finalizer removal is safe. Find out with: `source ~/nkp-site.env 2>/dev/null && kubectl --kubeconfig "$MGMT_KUBECONFIG" get namespaces --field-selector status.phase=Terminating`.

**Workspace roles.** Each workspace has `KommanderWorkspaceRole` objects `kommander-workspace-admin`, `-edit`, `-view`. By default these three also give the same project role in every project of the workspace. The annotation `workspace.kommander.mesosphere.io/sync-to-project` (`true` or `false`) on the role turns this on or off. [pdf p.230-231] Bind a VirtualGroup to a workspace role with a `VirtualGroupWorkspaceRoleBinding` (`spec.workspaceRoleRef.name`, `spec.virtualGroupRef.name`) in the workspace namespace. For a `KommanderWorkspaceRole`, the Kommander form of this kind has the field `spec.kommanderWorkspaceRoleRef.name`. [live 2.19.0] The VirtualGroup is cluster-scoped. The role and its binding must be in the same namespace. [pdf p.399][live 2.19.0]

## R6. Projects

- A project is a namespace with the same name on a set of clusters of one workspace (a KubeFed namespace). It holds project roles, ConfigMaps, Secrets, quotas, network policies, and project CD. [pdf p.369-370]
- Projects need Ultimate. [pdf p.27]
- The namespace name is the project name (first 57 characters) plus 5 random characters, or a name that you give. It cannot change later. It must not exist on the clusters. [pdf p.369][live 2.19.0]
- Clusters: select them by label (recommended: new clusters with the label join), or by name. [pdf p.369]
- Gatekeeper protects project namespaces ([gatekeeper.md](gatekeeper.md), G2). Project CD makes a service account with the project name. [pdf p.388]

`nkp create project <name> --workspace <ws>` makes a project with an empty `placement` (no clusters). [live 2.19.0] So use a project file. Write it after the user gives the label (`key`, `value`) of the clusters:

```bash
# CHANGES  (writes the project file on the operator host; changes no cluster)
source ~/nkp-site.env 2>/dev/null
pj=''; ws=''; wsns=''; key=''; value=''
: "${pj:?}" "${ws:?}" "${wsns:?}" "${key:?}" "${value:?}"
(umask 077 && cat > "$HOME/nkp-project-$pj.yaml" <<EOF
apiVersion: workspaces.kommander.mesosphere.io/v1alpha1
kind: Project
metadata:
  name: $pj
  namespace: $wsns
spec:
  workspaceRef:
    name: $ws
  placement:
    clusterSelector:
      matchLabels:
        $key: "$value"
EOF
)
kubectl --kubeconfig "$MGMT_KUBECONFIG" apply --dry-run=server -f "$HOME/nkp-project-$pj.yaml"
```

`wsns` is the workspace namespace. After "yes":

```bash
# CHANGES  (creates the project; NKP makes its namespace on the selected clusters)
source ~/nkp-site.env 2>/dev/null
pj=''
: "${pj:?}"
kubectl --kubeconfig "$MGMT_KUBECONFIG" apply -f "$HOME/nkp-project-$pj.yaml"
```

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
wsns=''
: "${wsns:?}"
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$wsns" get projects.workspaces.kommander.mesosphere.io -o custom-columns='NAME:.metadata.name,NAMESPACE:.status.namespaceRef.name'
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$wsns" get projectroles,kommanderprojectroles
```

Done when: the project has a NAMESPACE. Write down `projectns` (that namespace).

**Project role binding.** Each project gets admin, edit, and view roles (`kommander-project-admin-<suffix>` and others). [pdf p.231] Bind a VirtualGroup (R3) to one. The binding is in the project namespace. Set exactly one of `projectRoleRef` and `workspaceRoleRef`; both together is an error. [pdf p.397-398]

```bash
# CHANGES  (with dry='': binds a VirtualGroup to a project role; KubeFed makes a RoleBinding on the project clusters. With dry='1': server dry run, no change)
source ~/nkp-site.env 2>/dev/null
projectns=''; projectrole=''; vg=''; dry='1'
: "${projectns:?}" "${projectrole:?}" "${vg:?}"
kubectl --kubeconfig "$MGMT_KUBECONFIG" create ${dry:+--dry-run=server} -o name -f - <<EOF
apiVersion: workspaces.kommander.mesosphere.io/v1alpha1
kind: VirtualGroupProjectRoleBinding
metadata:
  generateName: projectpolicy-
  namespace: $projectns
spec:
  projectRoleRef:
    name: $projectrole
  virtualGroupRef:
    name: $vg
EOF
```

Run it first with `dry='1'`: that is a server dry run, and it changes nothing. After "yes", run it again with `dry=''`. Done when: on a project cluster, `kubectl -n "$projectns" get rolebindings -l kubefed.io/managed=true` shows the new binding. [pdf p.398]

## R7. 403 Forbidden

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
user=''; group=''
: "${user:?}"
kubectl --kubeconfig "$MGMT_KUBECONFIG" auth can-i get /dkp/kommander/dashboard --as "$user" ${group:+--as-group "$group"}
kubectl --kubeconfig "$MGMT_KUBECONFIG" get clusterrolebindings,rolebindings -A -o custom-columns='NS:.metadata.namespace,NAME:.metadata.name,ROLE:.roleRef.name,SUBJECTS:.subjects[*].name' | grep -F -e "$user" ${group:+-e "$group"}
kubectl --kubeconfig "$MGMT_KUBECONFIG" get virtualgroups -o custom-columns='NAME:.metadata.name,SUBJECTS:.spec.subjects[*].name'
```

Check in this order:
1. The name. Compare the subject with the Dex log (`login successful ... email=... groups=[...]`). Groups need `oidc:`. A workspace IdP needs the workspace prefix (R1). [pdf p.233]
2. The UI needs both `dkp-kommander-*` and `dkp-*` (R2), unless the subject has `cluster-admin` (R2). [pdf p.236][live 2.19.0]
3. No groups in the Dex log: the connector does not send groups (LDAP `groupSearch`, OIDC `insecureEnableGroups` and the scope, SAML `groupsAttr`). Use [identity.md](identity.md).
4. A workload cluster: check the binding there with its kubeconfig. KubeFed copies take some time. Use `kubectl auth can-i` with `--kubeconfig "$CLUSTER_KUBECONFIG"`.
5. After a fix, the user logs out and logs in again.

Done when: `can-i` prints `yes`.
