# App overrides (values ConfigMaps)

Use this file from skill `nkp-platform-apps-gitops`. An override changes the Helm values of one app. You never edit the HelmRelease or the defaults ConfigMap. NKP applies them again. [pdf p.276][live 2.19.0]

| File | Site variables |
|---|---|
| `~/nkp-<cluster>.env` | `APP_ID` |

`APP_ID` is the app ID of the AppDeployment (for example `traefik`). Ask the user to confirm the app ID. Show the append block (rule 4) only in the next reply, after the user confirms. Ask again for each app.

## O1. How the values are merged [live 2.19.0][pdf p.278, p.1066]

The HelmRelease on the target cluster reads `spec.valuesFrom` in this order. A later entry wins.

| Order | ConfigMap | Who writes it |
|---|---|---|
| 1 | `<app-id>-<version>-config-defaults` | NKP. Never edit. |
| 2 | `<app-id>-overrides` (optional), in the namespace of the HelmRelease. Only for apps whose HelmRelease lists that name (check with O2). Some apps read another name or none [live 2.19.0] | the Kommander installer file (`apps.<app>.values`), or by hand as the guide does for `gatekeeper-overrides` [pdf p.982] |
| 3 | `<app-id>-cluster-overrides` (only when the AppDeployment has an override) | Kommander: it copies the override ConfigMap of the AppDeployment to the target cluster under this name [live 2.19.0] |

- **Slot 2 is read directly.** When the HelmRelease lists it (O2), a ConfigMap with the exact name `<app-id>-overrides` in the namespace of the HelmRelease goes into the values also when no AppDeployment names it (`valuesFrom` entry with `optional: true`). [live 2.19.0] So do not give a new O3 or O4 override ConfigMap the name `<app-id>-overrides`. On the management cluster, the workspace namespace and the HelmRelease namespace are both `kommander`: that name then goes in two slots, and O5 item 5 (remove `configOverrides`) does not remove it from slot 2. Exception: the guide names the Velero override `velero-overrides` and checks it in `valuesFrom` [pdf p.513-515] (skill `nkp-storage-backup`). Use that name for Velero. Then only a delete of the ConfigMap (plan and "yes") removes the values. Second exception: the `nvidia-dra-driver` HelmRelease reads `nvidia-gpu-operator-config-overrides` by name (skill `nkp-gpu-ai`). [live 2.19.0] On the management cluster that ConfigMap is in `kommander`, which is also the HelmRelease namespace. So O5 item 5 does not remove its values from the DRA driver. Only a delete of the ConfigMap does. Third exception: the `logging-operator-logging` HelmRelease reads `logging-operator-logging-overrides` by name on the target cluster (skill `nkp-observability`, `logging.md` L2). [live 2.19.0]
- **Slot 3 can hold NKP values.** On the management cluster, NKP sets its own cluster overrides, for example `dex-kommander-overrides` with `config.issuer`. Kommander copies it to `dex-cluster-overrides`. [live 2.19.0] A new `configOverrides` on such an app can change slot 3 (P-33). Skill `nkp-identity-security` (file `identity.md`, I7) relies on this: after a change to the `dex` AppDeployment, `dex-cluster-overrides` must still have one `issuer:` line. Before you change an app with an NKP cluster override (O2 shows `cluster-override=<app-id>-kommander-overrides`), tell the user.

- **Workspace override**: `spec.configOverrides.name` of the AppDeployment. It applies to every cluster in the workspace. [pdf p.272]
- **Cluster override**: `spec.clusterConfigOverrides[]` (`configMapName` plus `clusterSelector`). Ultimate only. [pdf p.321] Cluster values win over the workspace values. [pdf p.278] Only one cluster override is used for each cluster. [pdf p.1066]
UNKNOWN (P-33): how Kommander combines a workspace override and a cluster override in `<app-id>-cluster-overrides` (one merged ConfigMap or two `valuesFrom` entries), and if the NKP cluster override (for example the Dex issuer) stays. Find out with: `source ~/nkp-<cluster>.env 2>/dev/null && kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get helmreleases -A -o custom-columns='NAME:.metadata.name,FROM:.spec.valuesFrom[*].name' | grep "$APP_ID"` after O3 and O4. The guide says that cluster values win. [pdf p.278]

- The override ConfigMaps are on the **management cluster**, in the workspace (or project) namespace. [pdf p.322, p.1066] Kommander copies them to the target cluster. [live 2.19.0]
- The data key is `values.yaml`. Its text is Helm values for the chart of the app (the chart, not the catalog version). [pdf p.272]
- Starter: the guide says that AppDeployments allow no customization. [pdf p.273] The API accepts the patch on a Starter cluster. [live 2.19.0] Tell the user that it is not supported on Starter before you continue.
- **Before Kommander is installed**: put the values in `kommander.yaml` under `apps.<app>.values` (skill `nkp-install`, file `kommander.md`, K1-K2). [pdf p.959] **After the install**: use O3 or O4. Use one of the two ways for one app, not both.

## O2. Read the values that the app uses now

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
: "${APP_ID:?}"
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get appdeployment "$APP_ID" -o jsonpath='app={.spec.appRef.name}{"\n"}workspace-override={.spec.configOverrides.name}{"\n"}{range .spec.clusterConfigOverrides[*]}cluster-override={.configMapName} for {.clusterSelector}{"\n"}{end}'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get helmreleases -A -o custom-columns='NS:.metadata.namespace,NAME:.metadata.name,FROM:.spec.valuesFrom[*].name' | grep -E "NS|$APP_ID"
```

The second command shows the ConfigMap names and the namespace of the HelmRelease. Set `ns` to that namespace and `cm` to one name, then read it:

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
ns=''; cm=''; : "${ns:?}" "${cm:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" get configmap "$cm" -o jsonpath='{.data.values\.yaml}' | awk 'BEGIN { hi = -1 }
/^[[:space:]]*$/ { if (hi == -1) print; next }
{ ind = match($0, /[^ -]/) - 1 }
hi != -1 && hi < ind { next }
{ hi = -1; l = tolower($0) }
l ~ /[{,].*(secret|password|token|key|hash)/ { print "[hidden line]"; next }
match(l, /^[ -]*[a-z0-9_.-]+:/) && substr(l, 1, RLENGTH - 1) ~ /(secret|password|passwd|token|key|keyid|hash|pw|credentials?)$/ { print substr($0, 1, RLENGTH) " [hidden]"; hi = ind; next }
{ print }'
```

The `awk` prints `[hidden]` for the value of each key that ends in `secret`, `password`, `token`, `key`, `hash`, `pw`, or `credentials`, and for the lines below it. Never remove the `awk`. [live 2.19.0]

- Read the `config-defaults` ConfigMap to find the value names. Copy a full list (for example `storageClassDeviceSets`) into the override when you change it. Helm replaces a list, it does not merge it. [pdf p.276]
- The `dex-*`, `dex-k8s-authenticator-*`, `traefik-forward-auth-*`, and `kube-oidc-proxy-*` ConfigMaps hold client secrets and CA certificates. [live 2.19.0] The `awk` hides the secret keys. A secret under another key name can still show. If the user says that a value is a secret, give the block without the `awk` to the user as USER-TERMINAL, or do not read it.
- An empty `configMapName: ""` in a cluster override is normal on NKP apps. [live 2.19.0]

## O3. Make or change a workspace override

1. Write the values file. Ask the user for the values. The file holds only the values that change. Use the value names of the defaults ConfigMap (O2). If the old override (O2) has values, keep them in the file: the apply in item 4 replaces all of the ConfigMap. Show the full text to the user and stop for "yes". Then write it: put the confirmed text in place of the comment line.

```bash
# CHANGES  (writes the values file on the operator host; changes no cluster)
source ~/nkp-<cluster>.env 2>/dev/null
: "${APP_ID:?}"
f="$HOME/$CLUSTER_NAME-$APP_ID-values.yaml"
(umask 077 && cat > "$f" <<'VALUES'
# the values that the user confirmed go here, in place of this line
VALUES
)
```

If the values hold a secret (a password, a key), the user writes the file with an editor (rule 5). The file stays on the operator host, mode 600.

2. Check the YAML syntax. A good values file gives `apiVersion not set, kind not set`. A bad file gives `error converting YAML to JSON` and the line. [live 2.19.0]

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
: "${APP_ID:?}"
kubectl --kubeconfig "$MGMT_KUBECONFIG" create --dry-run=client -f "$HOME/$CLUSTER_NAME-$APP_ID-values.yaml" 2>&1 | head -3
```

`no objects passed to create`: the file has no values. The API accepts a ConfigMap with bad YAML. The HelmRelease then fails. [live 2.19.0] So this check is mandatory. It does not check the value names. A wrong name is ignored by most charts.

3. Preview the ConfigMap (server dry run). The webhooks that match ConfigMaps have `sideEffects` `None` or `NoneOnDryRun`. [live 2.19.0] Use the existing override name from O2, or `$APP_ID-overrides-ws` for a new one. Do not use `$APP_ID-overrides` (O1, slot 2; the exceptions are `velero-overrides`, `nvidia-gpu-operator-config-overrides`, and `logging-operator-logging-overrides`).

```bash
# READ-ONLY  (server dry run: changes nothing)
source ~/nkp-<cluster>.env 2>/dev/null
cm=''; : "${cm:?}" "${APP_ID:?}"
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" create configmap "$cm" --from-file=values.yaml="$HOME/$CLUSTER_NAME-$APP_ID-values.yaml" --dry-run=client -o yaml | kubectl --kubeconfig "$MGMT_KUBECONFIG" apply --dry-run=server -f -
```

The output is `configmap/<name> created (server dry run)` or `configured (server dry run)`. [live 2.19.0]

4. Show the plan (the management cluster, the namespace, the ConfigMap, the app, all clusters of the workspace get the change; the pods of the app restart). Stop for "yes". Then apply the ConfigMap and point the AppDeployment to it:

```bash
# CHANGES  (creates or replaces the override ConfigMap and sets it on the AppDeployment)
source ~/nkp-<cluster>.env 2>/dev/null
cm=''; : "${cm:?}" "${APP_ID:?}"
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" create configmap "$cm" --from-file=values.yaml="$HOME/$CLUSTER_NAME-$APP_ID-values.yaml" --dry-run=client -o yaml | kubectl --kubeconfig "$MGMT_KUBECONFIG" apply -f -
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" patch appdeployment "$APP_ID" --type merge -p "{\"spec\":{\"configOverrides\":{\"name\":\"$cm\"}}}"
```

The guide applies the full AppDeployment YAML with `kubectl apply` [pdf p.272]. The merge patch changes only `configOverrides` and keeps the other fields. [live 2.19.0]

5. Done when: O6 passes.

## O4. Cluster override and cluster selection (Ultimate)

Use this when only some clusters of a workspace get other values, or only some clusters get the app. [pdf p.321-326]

1. Make the ConfigMap as in O3 items 1-3, with a name for the cluster (for example `$APP_ID-overrides-<cluster>`). It goes in the workspace namespace on the management cluster.
2. Read the AppDeployment (O2). Then choose:
   - The AppDeployment has `clusterConfigOverrides` with an entry for this cluster: replace its `configMapName`. Set `i` to the index of the entry (0 is the first). The patch has a `test` op: if entry `i` is not for `target`, the API refuses the patch and changes nothing.
   - It has entries, but none for this cluster: add one (`/spec/clusterConfigOverrides/-`).
   - It has no `clusterConfigOverrides`: add the list (`/spec/clusterConfigOverrides`).

`target` is the KommanderCluster name (step 4 of SKILL.md). Set `mode` to `replace` (and `i`), `add`, or `list`. The three patches were accepted by a server dry run. [live 2.19.0] Show the plan, stop for "yes", then run:

```bash
# CHANGES  (sets the cluster override of one cluster on the AppDeployment)
source ~/nkp-<cluster>.env 2>/dev/null
cm=''; target=''; mode=''; i=''
: "${cm:?}" "${target:?}" "${mode:?}" "${APP_ID:?}"
sel="{\"matchExpressions\":[{\"key\":\"kommander.d2iq.io/cluster-name\",\"operator\":\"In\",\"values\":[\"$target\"]}]}"
case "$mode" in
  replace) v="matchExpressions/0/values/0"; p="[{\"op\":\"test\",\"path\":\"/spec/clusterConfigOverrides/${i:?}/clusterSelector/$v\",\"value\":\"$target\"},{\"op\":\"replace\",\"path\":\"/spec/clusterConfigOverrides/$i/configMapName\",\"value\":\"$cm\"}]";;
  add) p="[{\"op\":\"add\",\"path\":\"/spec/clusterConfigOverrides/-\",\"value\":{\"configMapName\":\"$cm\",\"clusterSelector\":$sel}}]";;
  list) p="[{\"op\":\"add\",\"path\":\"/spec/clusterConfigOverrides\",\"value\":[{\"configMapName\":\"$cm\",\"clusterSelector\":$sel}]}]";;
  *) p='';;
esac
: "${p:?mode must be replace, add, or list}"
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" patch appdeployment "$APP_ID" --type json -p "$p"
```

- **Only some clusters get the app**: `spec.clusterSelector` lists the clusters. [pdf p.323] Without it, the app goes to all clusters of the workspace. `nkp create appdeployment --clusters c1,c2 --add-cluster-config-overrides c1:cm1` sets both at create time. [live 2.19.0] To change it later, edit the list with the user: `kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" edit appdeployment "$APP_ID"` (CHANGES; the guide uses `nkp edit appdeployment` [pdf p.1062]). The API accepts a cluster name that does not exist [live 2.19.0]: check each name in `get kommanderclusters` first.
- **A cluster that is not attached yet**: add its cluster override before the attach. Then the app starts with the right values and does not deploy two times. [pdf p.324-325]
- **Remove a cluster override**: delete its entry from `clusterConfigOverrides` (edit, as above). [pdf p.326] Then delete the ConfigMap only if no AppDeployment uses it. You cannot delete a ConfigMap that an AppDeployment uses, and a deleted ConfigMap cannot come back. [pdf p.327]

## O5. A bad override (values or schema error)

Symptom: the HelmRelease message (skill `nkp-troubleshooting`, its file `flux.md`, F2) has `values`, `yaml:`, `schema`, `cannot unmarshal`, `values don't meet the specifications of the schema`, or the app pods start with wrong settings. [field]

1. O2: find the override ConfigMaps of the app and read them.
2. Check the text with the O3 item 2 check (save the text to a file first). Common errors: a tab instead of spaces, a list where the chart wants a map, a value at the wrong level, or a value for the catalog version instead of the chart version.
3. Fix the file, then do O3 items 3-4 (workspace) or O4 (cluster) again with the same ConfigMap name.
4. The HelmRelease can stay at `exhausted` after the fix. Then do the reset in SKILL.md step 3.
5. To go back to the defaults: remove `spec.configOverrides` (and the cluster entry). Show the plan, stop for "yes":

```bash
# CHANGES  (removes the workspace override from the AppDeployment; the app goes back to the default values)
source ~/nkp-<cluster>.env 2>/dev/null
: "${APP_ID:?}"
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" patch appdeployment "$APP_ID" --type json -p '[{"op":"remove","path":"/spec/configOverrides"}]'
```

- An AppDeployment that names a ConfigMap that does not exist waits. Kommander deploys only after the ConfigMap is there. [pdf p.350] The API does not check the name. [live 2.19.0]

## O6. Check

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
: "${APP_ID:?}"
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get appdeployment "$APP_ID" -o jsonpath='{range .status.clusters[*]}{.name}{"\t"}{range .conditions[*]}{.type}={.status} {end}{"\n"}{end}'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get helmreleases -A | grep -E "NAME|$APP_ID"
```

Done when: each target cluster shows `AppDeploymentEnabled=True AppDeploymentInstanceSynced=True`, and the HelmRelease shows READY `True` with a new release number (`.v2`, `.v3`) in its status. Reconcile can take a few minutes. [pdf p.317] Then check the setting on the app itself (for example the pod resources or the PVC size).

## O7. Overrides and upgrades

- Before a platform-apps upgrade, check each override for the new chart version (the value names can change). [pdf p.1031] Read the new defaults ConfigMap after the upgrade, then fix the override (O5).
- A cluster override entry has `appVersion` [live 2.19.0]. NKP sets it. Do not set it by hand.

## O8. Overrides that other skills point to

Do each one with O3 (workspace) or O4 (one cluster). The values are from the guide.

**Traefik NodePort: order and plan.** After the change, the Traefik Service has no LoadBalancer IP. Then the UI, `/dex`, and `/token` work only through the external load balancer, and the KommanderCluster condition `IngressAddressReady` can go `False` (SKILL.md step 4). [pdf p.978][live 2.19.0]
1. First, set up the external load balancer and `clusterHostname` (skill `nkp-networking`, file `ingress-certs.md`, I7). The guide sets `clusterHostname` before NodePort. [pdf p.978]
2. The plan must say: "The Traefik LoadBalancer IP goes away. The UI and the login then work only through the external load balancer."
3. Do the workload clusters first. Do the management cluster last.

| App (`APP_ID`) | Values | Note |
|---|---|---|
| `traefik`: NodePort for an external load balancer | `service.type: NodePort`, `ports.web.nodePort`, `ports.websecure.nodePort` (also `ports.registry.nodePort`, `ports.external-ceph.nodePort` when used) [pdf p.978] | Node ports must be in 30000-32768. Without a value, Kubernetes picks a port. [pdf p.978] The load balancer side (TLS, targets): skill `nkp-networking`, file `ingress-certs.md`, I7. |
| `traefik`: a DNS name for external-dns | `service.annotations` with `external-dns.alpha.kubernetes.io/hostname: <name>` [pdf p.973] | Needs the `external-dns` app. |
| `external-dns` (Pro or Ultimate) | the provider block (for example `aws:` or `azure:`), `domainFilters`, `policy`, `txtPrefix` [pdf p.972-974] | The provider block holds cloud credentials. The user writes the values file with an editor (rule 5). The agent does not show the ConfigMap. Log: `kubectl logs -n kommander deployment/external-dns` on the target cluster. [pdf p.977] |

On the management cluster, the guide sets these values in the Kommander installer file (`apps.traefik.values`, then `nkp install kommander --installer-config`). [pdf p.973, p.978] The override in O3 gives the same values to the HelmRelease. Use one way for one app (O1).
