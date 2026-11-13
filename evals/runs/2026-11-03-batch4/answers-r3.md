## nkp-observability B9

### Skill files I read

- `skills/nkp/SKILL.md` (router) — job "Loki storage, S3 or Nutanix Objects" → `nkp-observability`.
- `skills/_shared/RULES.md` (marks, approval, env files, values, secrets, unknowns).
- `skills/nkp-observability/SKILL.md` — step 1 (read the state), step 3 (enable), common failures.
- `skills/nkp-observability/references/logging.md` — L1 (health), **L4 (Loki object storage: Nutanix Objects)**, L3 (retention), D-05, D-33.
- `skills/nkp-platform-apps-gitops/SKILL.md` — step 1 and step 4 (app targets); this skill owns the override steps.
- `skills/nkp-platform-apps-gitops/references/overrides.md` — **O1, O2, O3, O4, O5, O6**.
- `skills/nkp-storage-backup/references/object-storage.md` — read only for the bucket and COSI facts. No bucket work is needed here.

### Two things I will not do as you wrote them

1. **I will not write to the Secret `dkp-loki`.** `dkp-loki` is the Secret that Rook makes for the ObjectBucketClaim `dkp-loki`, the default Ceph bucket. The bucket provisioner owns it. A write to it can make the Ceph bucket lose its credentials (`logging.md` L4 item 2). The `grafana-loki-v3` defaults load `dkp-loki` in seven components, so a write there can also break the parts that still need it. The correct move is a **new** Secret, for example `loki-s3-creds`, and the Loki values then point the seven components at that Secret. The CHANGES block below has a guard that refuses `dkp-loki`.
2. **I will not use the access key and secret key from the chat.** Rule 5. You type them into `~/nkp-site.env` with an editor. You also typed a live-looking access key into this chat, so change it in the Objects bucket after this job. I will only check it with `printenv VAR >/dev/null`.

### I would ask these with the question tool

1. **Cluster and env file.** `app-01` is a workload cluster, so I use `~/nkp-app-01.env`. Is that file there, and is `WORKSPACE_NS` in it the workspace namespace of `app-01`? *(Recommended: yes, use `~/nkp-app-01.env`.)* / No, another name / The file does not exist yet, make it.
2. **Name of the new S3 credentials Secret** on `app-01`, in the namespace of the `grafana-loki-v3` HelmRelease. *(Recommended: `loki-s3-creds`.)* / `loki-objects` / other name. `dkp-loki` is not an option.
3. **TLS and region of the Objects endpoint `objects.site.local`.** Does the certificate come from a private CA? *(Recommended: private CA → set `region: us-east-1` and `http_config: {insecure_skip_verify: true}` [field].)* / Public CA, verify TLS → `region: us-east-1` only and give me the CA file. / HTTP, no TLS → give me the `http://` URL.
4. **Do other clusters share the workspace of `app-01`?** Each cluster needs its own bucket. *(Recommended: `app-01` alone → workspace override, `overrides.md` O3.)* / More clusters → cluster override (`O4`, Ultimate) and the new Secret on each cluster.

I would not continue to the CHANGES steps before your answers to 1, 2, and 4.

### Step 1: Read the state first (READ-ONLY)

Tier first. Starter has no logging apps and no Loki: then I stop.

```bash
# READ-ONLY
source ~/nkp-app-01.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n kommander get licenses.kommander.mesosphere.io -o jsonpath='{.items[*].status.dkpLevel}{"\n"}'
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get appdeployments | grep -E 'NAME|prometheus|grafana|loki|logging|fluent|thanos|karma|insights|rook-ceph'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get helmreleases -A | grep -E 'NAME|prometheus|grafana|loki|logging|fluent|thanos|karma|insights|rook-ceph|object-bucket'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get prometheuses,alertmanagers -A
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get pods -A | grep -E 'prometheus|alertmanager|grafana|loki|fluent|thanos|karma|insights' | grep -v -E 'Running|Completed'
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get loggingstacks
```

Then L1 and the defaults of the Loki chart. The second block gives me the reloader annotation key (`ann`), and it shows that the seven components load `dkp-loki`.

```bash
# READ-ONLY
source ~/nkp-app-01.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get helmreleases -A | grep -E 'NAME|logging|loki|fluent|rook-ceph|object-bucket'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get loggings -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}controlNamespace={.spec.controlNamespace}{"\n"}{end}'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get clusterflows,clusteroutputs -A
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get pods -A | grep -E 'NAME|fluentbit|fluentd|loki|logging-operator'
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get loggingstacks -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{range .status.conditions[*]}  {.type}={.status} {.reason}: {.message}{"\n"}{end}{end}'
```

```bash
# READ-ONLY
source ~/nkp-app-01.env 2>/dev/null
ns="$WORKSPACE_NS"; : "${ns:?}"
cm=$(kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" get cm -o name | grep 'grafana-loki-v3-.*-config-defaults'); : "${cm:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" get "$cm" -o jsonpath='{.data.values\.yaml}' | grep -n -E 'secretRef:|name: dkp-loki|reloader|s3:'
```

Then the current overrides (`overrides.md` O2). Loki takes **one** workspace override, so if one exists I copy its values into the new file: the apply replaces the whole ConfigMap.

```bash
# READ-ONLY
source ~/nkp-app-01.env 2>/dev/null
: "${APP_ID:?}"
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get appdeployment "$APP_ID" -o jsonpath='app={.spec.appRef.name}{"\n"}workspace-override={.spec.configOverrides.name}{"\n"}{range .spec.clusterConfigOverrides[*]}cluster-override={.configMapName} for {.clusterSelector}{"\n"}{end}'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get helmreleases -A -o custom-columns='NS:.metadata.namespace,NAME:.metadata.name,FROM:.spec.valuesFrom[*].name' | grep -E "NS|$APP_ID"
```

The `awk` read of the old override (O2, second block, with the `awk` mask — I keep it, it hides secret keys) follows when O2 shows a ConfigMap name.

### Your action before the CHANGES steps (USER-TERMINAL: your terminal)

Put the two secret lines in `~/nkp-site.env` with an editor. Do not paste them in the chat.

- `export LOKI_S3_ACCESS_KEY='...'`
- `export LOKI_S3_SECRET_KEY='...'`

I check them only like this:

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
printenv LOKI_S3_ACCESS_KEY >/dev/null && echo LOKI_S3_ACCESS_KEY=set || echo LOKI_S3_ACCESS_KEY=missing
printenv LOKI_S3_SECRET_KEY >/dev/null && echo LOKI_S3_SECRET_KEY=set || echo LOKI_S3_SECRET_KEY=missing
```

In my next reply, after your answers to the questions above, I append the two confirmed values to `~/nkp-app-01.env` (`LOKI_S3_URL` with the URL you gave, `APP_ID='grafana-loki-v3'`), as a CHANGES block, one line for each value (rule 4).

### Plan for the change (target: cluster `app-01`, via management cluster)

Three changes, each with its own stop for "yes":

1. **New Secret** on `app-01`, namespace of the `grafana-loki-v3` HelmRelease. Result: a Secret with keys `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`. `dkp-loki` is not touched.
2. **Values file** on the operator host. Result: one Loki values file with the new Secret, the Objects URL, region `us-east-1`, and the current override values if any. No cluster changes.
3. **Workspace override** (`O3`): a ConfigMap `grafana-loki-v3-overrides-ws` in `$WORKSPACE_NS` on the management cluster, plus `spec.configOverrides` on the AppDeployment `grafana-loki-v3`. Result: every cluster of the workspace gets the new values and the Loki pods restart (the Reloader annotation points at the new Secret).

What this does not do: it does not copy old logs (they stay in the old Ceph bucket). It does not delete Rook Ceph: `grafana-loki-v3` lists `rook-ceph-cluster` as a dependency (UNKNOWN D-33), so keep it.

**Gate 1 — plan: create the S3 credentials Secret on `app-01`.**

```bash
# CHANGES  (creates or updates the new S3 credentials Secret for Loki; never dkp-loki)
source ~/nkp-app-01.env 2>/dev/null
ns=''; secret=''; : "${ns:?}"
[ "$secret" = dkp-loki ] && secret=''; : "${secret:?set a new Secret name, not dkp-loki}"
k=$(printenv LOKI_S3_ACCESS_KEY >/dev/null && printenv LOKI_S3_SECRET_KEY >/dev/null && echo ok); : "${k:?LOKI_S3_ACCESS_KEY or LOKI_S3_SECRET_KEY is not set}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" create secret generic "$secret" --from-file=AWS_ACCESS_KEY_ID=<(printf %s "$(printenv LOKI_S3_ACCESS_KEY)") --from-file=AWS_SECRET_ACCESS_KEY=<(printf %s "$(printenv LOKI_S3_SECRET_KEY)") --dry-run=client -o yaml | kubectl --kubeconfig "$CLUSTER_KUBECONFIG" apply -f - -o name
```

I write the plan, then I stop for "yes", then I set `ns` and `secret` from your answers and run it.

**Gate 2 — plan: write the values file on the operator host.** The file text that I show you in the plan (Helm values of the `grafana-loki-v3` chart, not the Loki server config file):

```yaml
loki:
  annotations:
    "<the annotation key from the defaults>": loki-s3-creds
  structuredConfig:
    storage_config:
      aws:
        s3: "https://objects.site.local/loki-app-01"
        region: us-east-1
        http_config:
          insecure_skip_verify: true
ingester: {extraEnvFrom: [{secretRef: {name: loki-s3-creds}}]}
distributor: {extraEnvFrom: [{secretRef: {name: loki-s3-creds}}]}
querier: {extraEnvFrom: [{secretRef: {name: loki-s3-creds}}]}
queryFrontend: {extraEnvFrom: [{secretRef: {name: loki-s3-creds}}]}
indexGateway: {extraEnvFrom: [{secretRef: {name: loki-s3-creds}}]}
compactor: {extraEnvFrom: [{secretRef: {name: loki-s3-creds}}]}
ruler: {extraEnvFrom: [{secretRef: {name: loki-s3-creds}}]}
```

`loki-s3-creds` is the name from your answer to question 2. The annotation key and the `insecure_skip_verify` line come from step 1 and your answer to question 3. If O2 shows an existing override, its values go into this same file before the apply.

```bash
# CHANGES  (writes the Loki values file on the operator host; changes no cluster)
source ~/nkp-app-01.env 2>/dev/null
secret=''; ann=''
[ "$secret" = dkp-loki ] && secret=''; : "${secret:?set a new Secret name, not dkp-loki}" "${ann:?}" "${LOKI_S3_URL:?}"
f="$HOME/$CLUSTER_NAME-grafana-loki-v3-values.yaml"
(umask 077 && cat > "$f" <<VALUES
loki:
  annotations:
    "$ann": $secret
  structuredConfig:
    storage_config:
      aws:
        s3: "$LOKI_S3_URL"
        region: us-east-1
ingester: {extraEnvFrom: [{secretRef: {name: $secret}}]}
distributor: {extraEnvFrom: [{secretRef: {name: $secret}}]}
querier: {extraEnvFrom: [{secretRef: {name: $secret}}]}
queryFrontend: {extraEnvFrom: [{secretRef: {name: $secret}}]}
indexGateway: {extraEnvFrom: [{secretRef: {name: $secret}}]}
compactor: {extraEnvFrom: [{secretRef: {name: $secret}}]}
ruler: {extraEnvFrom: [{secretRef: {name: $secret}}]}
VALUES
)
```

I stop for "yes" before I write the file.

**Checks before gate 3 (READ-ONLY).** The YAML check is mandatory: a bad file makes the HelmRelease fail.

```bash
# READ-ONLY
source ~/nkp-app-01.env 2>/dev/null
: "${APP_ID:?}"
kubectl --kubeconfig "$MGMT_KUBECONFIG" create --dry-run=client -f "$HOME/$CLUSTER_NAME-$APP_ID-values.yaml" 2>&1 | head -3
```

```bash
# READ-ONLY  (server dry run: changes nothing)
source ~/nkp-app-01.env 2>/dev/null
cm=''; : "${cm:?}" "${APP_ID:?}"
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" create configmap "$cm" --from-file=values.yaml="$HOME/$CLUSTER_NAME-$APP_ID-values.yaml" --dry-run=client -o yaml | kubectl --kubeconfig "$MGMT_KUBECONFIG" apply --dry-run=server -f -
```

A good file gives `apiVersion not set, kind not set`. `no objects passed to create` means the file is empty.

**Gate 3 — plan: set the workspace override.** Target: the management cluster, namespace `$WORKSPACE_NS`, ConfigMap `grafana-loki-v3-overrides-ws`, app `grafana-loki-v3`. Result: all clusters of the workspace get the new values, and the Loki pods of `app-01` restart.

```bash
# CHANGES  (creates or replaces the override ConfigMap and sets it on the AppDeployment)
source ~/nkp-app-01.env 2>/dev/null
cm=''; : "${cm:?}" "${APP_ID:?}"
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" create configmap "$cm" --from-file=values.yaml="$HOME/$CLUSTER_NAME-$APP_ID-values.yaml" --dry-run=client -o yaml | kubectl --kubeconfig "$MGMT_KUBECONFIG" apply -f -
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" patch appdeployment "$APP_ID" --type merge -p "{\"spec\":{\"configOverrides\":{\"name\":\"$cm\"}}}"
```

If your answer to question 4 is "more clusters share the workspace", gate 3 is `O4` (cluster override for `app-01` only, Ultimate), and the new Secret goes on each cluster that wins the values.

### After gate 3 (READ-ONLY checks)

```bash
# READ-ONLY
source ~/nkp-app-01.env 2>/dev/null
: "${APP_ID:?}"
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get appdeployment "$APP_ID" -o jsonpath='{range .status.clusters[*]}{.name}{"\t"}{range .conditions[*]}{.type}={.status} {end}{"\n"}{end}'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get helmreleases -A | grep -E "NAME|$APP_ID"
```

```bash
# READ-ONLY
source ~/nkp-app-01.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get pods -A | grep -E 'loki.*(ingester|compactor)'
```

Done when: each target cluster shows `AppDeploymentEnabled=True AppDeploymentInstanceSynced=True`, the HelmRelease shows READY `True` with a new release number, and the `compactor` and `ingester` logs show no `S3` or `AccessDenied` errors. Then UNKNOWN (D-05) is closed for this site: the compactor log is the check for path-style access and the private CA.

### If it fails

- `AccessDenied`, `S3`, or `no such host` in the compactor log: the keys or the URL or DNS of `objects.site.local` in the cluster. The Objects host name must resolve in the cluster.
- HelmRelease not `True`, or a values error: `overrides.md` O5, then the reset in `nkp-platform-apps-gitops` step 3.
- `AppDeployment ... "grafana-loki-v3-3.6.x" not found`: use the ClusterApp name that step 3 of `nkp-observability` prints, not a name from the guide.

### What I would do next

1. Run the READ-ONLY blocks of step 1 and L4 item 2. Report the tier, the Loki HelmRelease namespace, the reloader annotation key, and whether an override already exists.
2. Report the answers as an explicit plan: Secret name, values file text, ConfigMap name, target namespace, all clusters of the workspace, the pods that restart.
3. Stop. Run gate 1 only after "yes". Then the same for gates 2 and 3.
4. Ask you to change the access key that you typed in the chat.

Not touched: Loki retention (still the default 168h), the index (`boltdb-shipper`), Fluent Bit/Fluentd, and Rook Ceph. Tell me if you want retention or the TSDB index (`L3`, `L5`) in the same values file — Loki takes one override, so it would go in the same file now, not in a second one.

Not checked: your Objects bucket name and its policy, and whether the keys have read-write on it. That is outside the skills; the bucket must exist before this change and one bucket serves one cluster.
