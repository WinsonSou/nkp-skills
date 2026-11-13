---
name: kubernetes-core
description: >
  Plain Kubernetes with kubectl, not NKP-specific: pod Pending, CrashLoopBackOff, OOMKilled, probes,
  logs --previous, events, kubectl debug, kubectl explain; taints, affinity, resources, PodDisruptionBudget
  blocks a drain; Deployment, StatefulSet, DaemonSet, Job rollout, scale, rollback; Service, DNS,
  NetworkPolicy, Ingress basics; PVC basics; RBAC and auth can-i.
metadata:
  nkp_versions: "2.19"
  last_verified: "2026-11-03"
  sources: "live 2.19.0"
---

# Kubernetes core

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

## What this skill does

This skill reads and fixes plain Kubernetes objects in one cluster: pods, workloads, Services, NetworkPolicies, PVCs, and RBAC. The target agent has no internet. `kubectl explain` and `kubectl <command> --help` are the reference. The cluster is the truth.

Facts of the reference cluster [live 2.19.0]: Kubernetes v1.36.2, client `kubectl` v1.37.2 (in the bundle root). Every flag in this skill is in the `--help` of that client.

Not in this skill (use the NKP skill):
- Nodes, node pools, labels and taints of pools, cluster scale: skill `nkp-cluster-lifecycle`. Something broken and the layer is not known: skill `nkp-troubleshooting` (the debug ladder).
- CNI (Cilium, Hubble), `LoadBalancer` IPs (MetalLB), Traefik, certificates, proxy: skill `nkp-networking`.
- StorageClasses, CSI, PVC provisioning errors, snapshots, Velero: skill `nkp-storage-backup`.
- Image pulls, registry, `x509` from a registry: skill `nkp-airgap`.
- Dex users and groups, workspace and project roles, Gatekeeper, Pod Security Admission for the cluster: skill `nkp-identity-security`.
- Platform apps, HelmReleases, Flux, AppDeployment overrides: skill `nkp-platform-apps-gitops`.

## Job → section

| Job | Where |
|---|---|
| Find what is wrong with a pod or a namespace | step 1 |
| Look up a field or a flag | step 2 |
| Before any change: who owns the object | step 3 |
| Apply a YAML file | step 4 |
| `CrashLoopBackOff`, `OOMKilled`, `Error`, exit codes, probes, logs, `CreateContainerConfigError`, `Terminating`, `kubectl debug` | [references/pods.md](references/pods.md) |
| Pod `Pending`, `FailedScheduling`, taints, tolerations, affinity, topology spread, requests, PDB blocks a drain, drain, priority | [references/scheduling.md](references/scheduling.md) |
| Deployment, StatefulSet, DaemonSet, Job, CronJob: rollout, restart, rollback, scale; StatefulSet and PVC basics | [references/workloads.md](references/workloads.md) |
| Service has no endpoints, DNS, NetworkPolicy, Ingress | [references/networking.md](references/networking.md) |
| RBAC: "forbidden", what can a user or ServiceAccount do | step 5 |

## Step 1: Read the state

Ask the user for the cluster and the namespace. On NKP, the cluster env file has `CLUSTER_KUBECONFIG` (skill `nkp-cluster-lifecycle`, step 1, makes the file). For the management cluster, `CLUSTER_KUBECONFIG` is the same file as `MGMT_KUBECONFIG`.

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
ns=''
: "${ns:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" get pods -o wide
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" get deploy,sts,ds,jobs,svc,pvc
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" events --types=Warning
```

Then, for each pod that is not `Running` with all containers ready, or not `Completed`:

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
ns=''; pod=''
: "${ns:?}" "${pod:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" describe pod "$pod"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" logs "$pod" --all-containers --previous --tail=50
```

- Read the `describe` output in this order: `Status` and `Reason`, each container `State` and `Last State` (with `Exit Code`), `Conditions`, then `Events` at the end.
- `--previous` fails with "previous terminated container not found" when no container restarted. Then run the line without `--previous`.
- `kubectl events` [live 2.19.0] takes `--for <kind>/<name>`, `--types=Warning`, `-A`, `-w`. Events are kept for 1 hour (the API server default; NKP does not set `--event-ttl`). [live 2.19.0] "No events found" does not mean that all is well.
- All namespaces: `kubectl get pods -A --field-selector=status.phase=Pending` lists only `Pending` pods. [live 2.19.0]

| Pod `STATUS` | Go to |
|---|---|
| `Pending` | [references/scheduling.md](references/scheduling.md), S1 |
| `CrashLoopBackOff`, `Error`, `OOMKilled`, `Init:*`, `CreateContainerConfigError`, `Running` but `0/1` | [references/pods.md](references/pods.md), P1 |
| `ImagePullBackOff`, `ErrImagePull` | skill `nkp-airgap` |
| `ContainerCreating` for more than 2 minutes | [references/pods.md](references/pods.md), P1 (the events name volume or network) |
| `Terminating` for more than 5 minutes | [references/pods.md](references/pods.md), P6 |
| No pod, but a Deployment or Job exists | [references/workloads.md](references/workloads.md), W1 |
| `Evicted` | `describe pod` gives the node pressure (memory, disk). Many: the node is short of resources (skill `nkp-troubleshooting`, rung 6). |

Done when: for each bad pod you know its status, the reason line, and the file to use.

## Step 2: Look up a field or a flag (offline)

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" explain pod.spec.tolerations
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" explain deployment.spec.strategy --recursive
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" api-resources --api-group=policy
kubectl debug --help
```

- `explain` reads the schema from the API server, so it matches the cluster version. It shows the type, the `enum` values, and `-required-` fields. [live 2.19.0] It also works for CRDs (for example `helmreleases.spec`). [live 2.19.0]
- `--recursive` prints the whole tree. A big object (for example `deployment.spec`, more than 1000 lines) is too long: go one level at a time.
- `api-resources` gives the short names (`deploy`, `sts`, `ds`, `pvc`, `pdb`, `netpol`, `cj`, `hpa`) and the API group and version.
- Change the first word of the `explain` path and the field path to the object that you need. Use this before you write a YAML field from memory.

## Step 3: Who owns the object? (before every change)

A change to an object that a controller owns is undone at the next reconcile, or it breaks the platform.

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
ns=''; obj=''
: "${ns:?}" "${obj:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" get "$obj" -o jsonpath='owners={.metadata.ownerReferences[*].kind}/{.metadata.ownerReferences[*].name}{"\n"}managed-by={.metadata.labels.app\.kubernetes\.io/managed-by}{"\n"}helm-release={.metadata.annotations.meta\.helm\.sh/release-name}{"\n"}flux-helm={.metadata.labels.helm\.toolkit\.fluxcd\.io/name}{"\n"}flux-kustomization={.metadata.labels.kustomize\.toolkit\.fluxcd\.io/name}{"\n"}'
```

`obj` has the form `deployment/web`. Read the result:

| Result | Owner | Where to change |
|---|---|---|
| `owners=ReplicaSet/...`, `StatefulSet/...`, `DaemonSet/...`, `Job/...` | the workload | Change the workload, not the pod. |
| `flux-helm` or `helm-release` is set | a HelmRelease | Change the Helm values: skill `nkp-platform-apps-gitops`. |
| `flux-kustomization` is set | a Flux Kustomization (Git) | Change Git: skill `nkp-platform-apps-gitops`. |
| The namespace is an NKP namespace (`kube-system`, `kommander*`, `caren-system`, `cap*-system`, `metallb-system`, `ntnx-system`, `cert-manager`, `git-operator-system`, `kube-federation-system`) | NKP | Do not change. Use the owner NKP skill (skill `nkp` names it). |
| All empty, user namespace | the user (`kubectl apply`) | This skill. |

- Flux reconciles HelmReleases on the NKP management cluster every 15 s to 6 h. [live 2.19.0] A manual edit can live for a short time only.
- Done when: you know the owner and you told the user where the change goes.

## Step 4: Apply a change

1. Write the file on the operator host (CHANGES, the file only). Get each field from `kubectl explain` (step 2).
2. Server dry run and diff. They change nothing. The API server and the admission webhooks check the object. Gatekeeper `denied` messages show here. [live 2.19.0]

```bash
# READ-ONLY  (server dry run and diff: change nothing)
source ~/nkp-<cluster>.env 2>/dev/null
f=''
: "${f:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" apply --dry-run=server -f "$f"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" diff -f "$f"; echo "diff_rc=$?"
```

- `diff` exit code: 0 no difference, 1 differences, more than 1 an error. [live 2.19.0] Read `$?` directly after `diff`. Do not pipe `diff` (for example `diff ... | head`): then `$?` is the exit code of the last command in the pipe. It printed `diff_rc=0` while the API server returned `NotFound`. [live 2.19.0]
- A new namespace: when the file has a `Namespace` that is not on the cluster yet, the dry run and `diff` fail for the objects in it: `Error from server (NotFound): ... namespaces "<ns>" not found`. [live 2.19.0] This is not an error in the file. Make the namespace first (CHANGES, after "yes"), then do the dry run and `diff` of the file again:

```bash
# CHANGES  (creates one empty namespace)
source ~/nkp-<cluster>.env 2>/dev/null
ns=''
: "${ns:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" create namespace "$ns"
```

If the `Namespace` in the file has labels or annotations (for example Pod Security labels), put it in its own file and apply that file first (sub-step 3), not `create namespace`.

Show the diff to the user in the plan. `diff` hides Secret data by default (`--show-secrets=false`). [live 2.19.0] Never add `--show-secrets`.

3. Apply after "yes", then watch:

```bash
# CHANGES  (applies the file to the cluster)
source ~/nkp-<cluster>.env 2>/dev/null
f=''
: "${f:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" apply -f "$f"
```

Done when: the apply prints `created` or `configured` and step 1 shows the new state (for a workload: `rollout status`, [references/workloads.md](references/workloads.md), W1).

## Step 5: RBAC basics

`kubectl auth can-i` asks the API server and changes nothing. `--as` and `--as-group` impersonate a subject (the admin kubeconfig can do this).

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
ns=''; who=''
: "${ns:?}" "${who:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" auth whoami
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" auth can-i --list --as="$who"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get rolebindings -n "$ns" -o custom-columns='NAME:.metadata.name,ROLE:.roleRef.kind/.roleRef.name,SUBJECTS:.subjects[*].name'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get clusterrolebindings -o custom-columns='NAME:.metadata.name,ROLE:.roleRef.name,SUBJECTS:.subjects[*].name' | grep -F -e "${who##*:}"
```

- A ServiceAccount is `system:serviceaccount:<ns>:<name>` in `who`. The binding lists show only `<name>`, so the last `grep` uses the part after the last `:`. One action: `kubectl auth can-i create deployments -n <ns> --as=system:serviceaccount:<ns>:<name>` prints `yes` or `no`. [live 2.19.0]
- The error text `User "x" cannot list resource "pods" in API group "" in the namespace "y"` names the subject, the verb, the resource, the API group, and the namespace. A Role needs exactly these.
- Role (one namespace) + RoleBinding; ClusterRole (all namespaces or cluster objects) + ClusterRoleBinding. A RoleBinding to a ClusterRole gives its rights in one namespace only.
- Built-in ClusterRoles for people: `view`, `edit`, `admin`, `cluster-admin`. Prefer them to a new Role.
- RBAC only adds rights. There is no deny rule.
- A new binding is CHANGES. Show the plan, then (one namespace, ServiceAccount example):

```bash
# CHANGES  (gives one ServiceAccount the "edit" rights in one namespace)
source ~/nkp-<cluster>.env 2>/dev/null
ns=''; sa=''
: "${ns:?}" "${sa:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" create rolebinding "$sa-edit" --clusterrole=edit --serviceaccount="$ns:$sa"
```

For a Dex user or group, the subject names (`oidc:` prefix), the UI roles, workspaces, and projects: skill `nkp-identity-security`, file `rbac.md`.

Done when: `auth can-i` prints the expected `yes` or `no`.

## Rules for this skill

- Never print Secret data: no `get secret -o yaml` or `-o json`, no `exec ... env`, no `describe` of a ConfigMap that holds credentials. `kubectl describe secret` prints only key names and sizes.
- Do not use `-it` or an interactive shell. The agent cannot type into it. Run one command with `-- <command>` and read the output.
- Do not delete pods or objects to "try" a fix. A delete is CHANGES with a plan.
- `kubectl top` needs the Metrics API. It is not on the Starter lab. [live 2.19.0] See [references/pods.md](references/pods.md), P4.
- A delete or label change denied by `validatingadmissionpolicy/nkp-deletion-protection` (label `nkp.nutanix.com/deletion-protection`): do not change that label. Use skill `nkp-identity-security` (`gatekeeper.md` G5).

## Related skills

Router and NKP names: skill `nkp`. Debug ladder and stuck deletes: skill `nkp-troubleshooting`. NKP RBAC and Gatekeeper: skill `nkp-identity-security`.
