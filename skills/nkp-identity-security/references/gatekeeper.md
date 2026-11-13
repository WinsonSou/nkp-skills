# Gatekeeper and NKP admission policies

Use this file from skill `nkp-identity-security`.

## G1. Facts

- Gatekeeper 3.23.0 is a platform app in `kommander` on every cluster. Deployments: `gatekeeper-audit` and `gatekeeper-controller-manager` (2 pods). `gatekeeper-proxy-mutations` is a HelmRelease (chart `gatekeeper-3.23.0-proxy-mutations`), not a Deployment. [live 2.19.0]
- It is on by default. Do not disable it: NKP ships constraints that keep projects apart (multi-tenancy). [pdf p.581]
- "Policy control using Gatekeeper" (your own policies) is a Pro and Ultimate feature. [pdf p.28] The app also runs on Starter, for the NKP constraints. [live 2.19.0]
- The Gatekeeper `Config` `kommander/config` excludes the namespace `kommander` from the webhook, audit, and sync. [live 2.19.0]
- The webhook `validation.gatekeeper.sh` checks CREATE and UPDATE of all kinds. [live 2.19.0]
- The proxy mutation (`gatekeeper.d2iq.com/mutate=pod-proxy`) is in skill `nkp-networking`, file `proxy.md`, X4.

NKP constraints on 2.19.0 [live 2.19.0]:

| Constraint (kind `RequiredServiceAccountName`) | Action | Checks | Where |
|---|---|---|---|
| `helmrelease-must-have-sa` | `deny` | Flux `HelmRelease` must have `spec.serviceAccountName` | namespaces with label `kommander.d2iq.io/managed-by-kind=Project` |
| `kustomization-must-have-sa` | `deny` | Flux `Kustomization` must have `spec.serviceAccountName` | same |

The ConstraintTemplate `requiredserviceaccountname` comes from the Flux Kustomization `kommander/gatekeeper-constraint-templates`. Its message: "must have a serviceAccountName set". [live 2.19.0]

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get constrainttemplates
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get constraints
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get requiredserviceaccountname -o custom-columns='NAME:.metadata.name,ACTION:.spec.enforcementAction,KINDS:.spec.match.kinds[*].kinds,NSLABEL:.spec.match.namespaceSelector.matchLabels'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get ns -l kommander.d2iq.io/managed-by-kind=Project
```

## G2. Denied: `helmrelease-must-have-sa` or `kustomization-must-have-sa`

The full message looks like: `admission webhook "validation.gatekeeper.sh" denied the request: [helmrelease-must-have-sa] must have a serviceAccountName set`.

Cause: a Flux HelmRelease or Kustomization in a project namespace has no `spec.serviceAccountName`. The constraint makes sure that tenant Flux objects run with the project service account, not with the Flux controller account (which is `cluster-admin`). [live 2.19.0][pdf p.388]

Fix: add `spec.serviceAccountName` to the object in its source (the Git repository or the file). Do not remove or weaken the constraint. `enforcementAction: warn` or `dryrun` on an NKP constraint is a weakening. It is not allowed, and do not offer it as a choice.

1. Find the service accounts in the project namespace. Project CD makes one with the name of the project. [pdf p.388]

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
ns=''
: "${ns:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" get serviceaccounts
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" get rolebindings -o custom-columns='NAME:.metadata.name,ROLE:.roleRef.name,SUBJECTS:.subjects[*].name'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" get helmreleases,kustomizations -o custom-columns='KIND:.kind,NAME:.metadata.name,SA:.spec.serviceAccountName'
```

2. Tell the user to add this line to the spec of each object that has an empty SA column, in Git:

```yaml
spec:
  serviceAccountName: <project-service-account>
```

3. That service account must have rights for all objects that the release makes, in that namespace only. Project CD gives them. [pdf p.388] A chart that makes cluster-scoped objects (CRDs, ClusterRoles) cannot run from a project namespace. Deploy it as a workspace app instead (skill `nkp-platform-apps-gitops`).

Done when: the Flux object is Ready (skill `nkp-troubleshooting`, file `flux.md`, F2), and `kubectl get constraints` shows `TOTAL-VIOLATIONS` `0`.

## G3. Add a library policy (air-gapped too)

The guide applies the Gatekeeper library files from GitHub. [pdf p.581-582] That does not work on an air-gapped site. Use the pinned files in skill `nkp-airgap`, its folder `assets/` (P1 in its file `prestage.md`):

| Asset | Kind |
|---|---|
| `gatekeeper-privileged-containers-template.yaml` | ConstraintTemplate `k8spspprivilegedcontainer` |
| `gatekeeper-privileged-containers-constraint.yaml` | Constraint `psp-privileged-container` (kind `K8sPSPPrivilegedContainer`, Pods, all namespaces except `kube-system`; one upstream example entry in `parameters.exemptImages`) |
| `gatekeeper-host-filesystem-template.yaml` | ConstraintTemplate `k8spsphostfilesystem` |

1. Check the SHA-256 of the assets with skill `nkp-airgap`, file `prestage.md`, section "Use an asset". Every line must start with `OK`. Then set `dir` below to the same nkp-airgap folder. Other library policies: the user gets them on a connected host (same file, `gatekeeper-library-repo`).
2. Before a `deny` policy, find the pods that it blocks. On 2.19.0, `kube-system` and `ntnx-system` run privileged pods, and `kube-system`, `ntnx-system`, `node-feature-discovery` use hostPath volumes. [live 2.19.0] The library constraint excludes only `kube-system`. A `deny` constraint stops new pods of the CSI driver in `ntnx-system` and of NFD. So first use `enforcementAction: dryrun` (audit only), or add these namespaces to `spec.match.excludedNamespaces`.

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get pods -A -o json | jq -r '.items[] | select(any(.spec.containers[]; .securityContext.privileged == true)) | .metadata.namespace' | sort | uniq -c
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get pods -A -o json | jq -r '.items[] | select(any(.spec.volumes[]?; .hostPath != null)) | .metadata.namespace' | sort | uniq -c
```

3. Dry run the template:

```bash
# READ-ONLY  (server dry run: changes nothing)
source ~/nkp-<cluster>.env 2>/dev/null
dir=''
: "${dir:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" apply --dry-run=server -f "$dir/assets/gatekeeper-privileged-containers-template.yaml"
```

A constraint dry run fails until its template is in the cluster: `no matches for kind "K8sPSPPrivilegedContainer"`. [live 2.19.0] This is normal.

4. The plan: the template, the constraint, the action, and the namespaces that step 2 found. After "yes", apply the template and wait for its CRD:

```bash
# CHANGES  (adds the ConstraintTemplate; Gatekeeper makes its constraint CRD)
source ~/nkp-<cluster>.env 2>/dev/null
dir=''
: "${dir:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" apply -f "$dir/assets/gatekeeper-privileged-containers-template.yaml"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" wait constrainttemplate k8spspprivilegedcontainer --for=jsonpath='{.status.created}'=true --timeout=2m
```

5. The asset constraint has `deny` and excludes only `kube-system`. Write a local copy with the action and the namespaces from the plan. Do not edit the asset.

```bash
# CHANGES  (writes the constraint file on the operator host; changes no cluster)
dir=''; action='dryrun'
: "${dir:?}" "${action:?}"
(umask 077 && awk -v a="$action" '{print} /^spec:$/{print "  enforcementAction: " a}' "$dir/assets/gatekeeper-privileged-containers-constraint.yaml" | sed 's/excludedNamespaces: \["kube-system"\]/excludedNamespaces: ["kube-system","ntnx-system","node-feature-discovery"]/' > "$HOME/nkp-gk-privileged.yaml")
grep -nE '^ +(enforcementAction|excludedNamespaces):' "$HOME/nkp-gk-privileged.yaml"
```

`action` is `dryrun`, `warn`, or `deny`. The `grep` must show both lines with the new values. The `exemptImages` entry is an upstream example. It exempts no image of the site. Then dry run it (READ-ONLY, `apply --dry-run=server -f "$HOME/nkp-gk-privileged.yaml"`), and apply it after "yes" (CHANGES, `apply -f`).

6. Check:

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get k8spspprivilegedcontainer psp-privileged-container -o jsonpath='action={.spec.enforcementAction} violations={.status.totalViolations}{"\n"}{range .status.violations[*]}{.namespace}/{.name}: {.message}{"\n"}{end}'
```

Done when: the constraint exists and the audit shows only the violations that the user accepts. Change to `deny` only after that, with a new plan.

The host-filesystem template has no constraint asset. The guide constraint `psp-host-filesystem` (kind `K8sPSPHostFilesystem`, `parameters.allowedHostPaths` with `pathPrefix` and `readOnly`) is a short YAML file. Write it with the user's paths, in the same way. [pdf p.582]

## G4. Denied by another constraint

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get constraints
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get constrainttemplates
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$WORKSPACE_NS" logs deploy/gatekeeper-controller-manager --tail=50
```

The text in `[...]` after `denied the request:` is the constraint name. [pdf p.582] Run `kubectl describe` on that constraint. Then fix the object, or ask the owner of the policy. Do not delete a constraint without a plan and "yes".

If every request to the API server fails with a Gatekeeper timeout, the Gatekeeper pods do not run. Use skill `nkp-troubleshooting` (rung 5).

## G5. Denied by ValidatingAdmissionPolicy `nkp-deletion-protection`

This is not Gatekeeper. It is a built-in Kubernetes ValidatingAdmissionPolicy that NKP ships (Flux Kustomization `kommander/cluster`). [live 2.19.0]

Facts [live 2.19.0]:
- It checks CREATE, UPDATE, and DELETE of all kinds in all namespaces, but only objects that have the label `nkp.nutanix.com/deletion-protection`. `failurePolicy: Fail`. The binding `nkp-deletion-protection` has the actions `Deny` and `Audit`.
- Values: `standard`, `strict`, `revoked`. A delete passes only when the value is `revoked`.
- `strict` can never change and cannot be removed. So a `strict` object can never be deleted.
- `standard` cannot be removed. It can change to `revoked` or `strict`.
- Only a user whose name does not start with `system:` can change `standard` to `revoked`. A controller or Flux cannot.
- No object had the label on the 2.19.0 lab (the batch 4 review checked 360 listable resource types).

Messages: `Deletion denied: resource is protected by nkp.nutanix.com/deletion-protection=...`, `...=strict is immutable`, `...=standard cannot be removed. Set the label to revoked instead.`

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
kind=''; name=''; ns=''; where='cluster'; case "$where" in mgmt) kc="$MGMT_KUBECONFIG";; cluster) kc="$CLUSTER_KUBECONFIG";; *) kc='';; esac
: "${kind:?}" "${name:?}" "${ns:?}" "${kc:?}"
kubectl --kubeconfig "$kc" get validatingadmissionpolicy,validatingadmissionpolicybinding nkp-deletion-protection
kubectl --kubeconfig "$kc" -n "$ns" get "$kind" "$name" -L nkp.nutanix.com/deletion-protection
```

- For a cluster-scoped kind, `-n` has no effect.
- `strict`: stop. The object cannot be deleted. Tell the user.
- `standard`: NKP protects this object for a reason. Do not change the label to make a delete work. Ask the user which NKP skill owns the object (skill `nkp`) and if the delete is really wanted. A change to `revoked` is CHANGES with a plan, done by a user (not a `system:` account): `kubectl label --overwrite` with the value `revoked`, then the delete.
- Do not delete or edit the policy or its binding.
