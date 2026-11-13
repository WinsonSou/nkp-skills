# NKP observability — eval replies (batch 4)

Each reply below is a separate new conversation. Each one starts with the skill files I read, then
the questions I would ask with the question tool, then the blocks in the order the skills give them.

Common to every reply:

- I run the blocks with **bash**, not zsh, as rule 3 says. Your login shell is zsh; that does not
  change the blocks.
- Line 1 of each block is the mark. Line 2 sources the env file. I never print an env file, a
  kubeconfig, or Secret data.
- A `# CHANGES` block is shown with the plan first, and it runs only after you type `yes`.
  "Just run it" is not `yes` (rule 2).

---

## nkp-observability B1

**Skill files read:** `skills/nkp/SKILL.md` (router), `skills/_shared/RULES.md`,
`skills/nkp-observability/SKILL.md`, `skills/nkp-observability/references/monitoring.md`,
`skills/nkp-platform-apps-gitops/SKILL.md`,
`skills/nkp-platform-apps-gitops/references/overrides.md`. Router sends "Prometheus, alerts,
Grafana" to `nkp-observability`; the override steps belong to `nkp-platform-apps-gitops`.

You named the cluster, so the cluster env file is `~/nkp-mgmt-01.env`, and on the management
cluster `WORKSPACE_NS` is `kommander`.

**I would ask these with the question tool** (after the read in step 1, because monitoring may not
exist on your tier):

1. Which PromQL expression and threshold? (For a node disk at 90% full the usual shape is
   `node_filesystem_avail_bytes / node_filesystem_size_bytes < 0.10` on the non-tmpfs,
   non-overlay mounts — but the expression is your decision, and I do not put a rule into your
   cluster that you did not confirm.)
2. Severity label: `warning` or `critical`?
3. For how long must it be true before it fires (`for:`, for example `10m`)?
4. Rule and group name to use in the values file?

**Step 1 — read the state first** (observability `SKILL.md` step 1). This tells me the license tier
and whether `kube-prometheus-stack` is really on this cluster:

```bash
# READ-ONLY
source ~/nkp-mgmt-01.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n kommander get licenses.kommander.mesosphere.io -o jsonpath='{.items[*].status.dkpLevel}{"\n"}'
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get appdeployments | grep -E 'NAME|prometheus|grafana|loki|logging|fluent|thanos|karma|insights|rook-ceph'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get helmreleases -A | grep -E 'NAME|prometheus|grafana|loki|logging|fluent|thanos|karma|insights|rook-ceph|object-bucket'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get prometheuses,alertmanagers -A
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get pods -A | grep -E 'prometheus|alertmanager|grafana|loki|fluent|thanos|karma|insights' | grep -v -E 'Running|Completed'
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get loggingstacks
```

**Branch 1 — tier `Starter`, or `prometheuses` is not a resource type.** Then I stop, and I give no
CHANGES block. Starter has none of the observability apps, and no Prometheus Operator API (CRDs):
`get prometheuses` answers `the server doesn't have a resource type`. Prometheus monitoring needs
**Pro** or **Ultimate**. What I would say: monitoring on Starter is not "off", it does not exist —
the app and its CRDs are absent, so a `PrometheusRule` cannot be created and an override has nothing
to override. The workaround would be a Pro or Ultimate license.

**Branch 2 — tier `Pro` or `Ultimate`.** Then the alert goes in as a value of the app, not as an
object I invent: monitoring M2 **way A**, `additionalPrometheusRulesMap` in the
`kube-prometheus-stack` override, applied with gitops `overrides.md` **O3** (workspace) or **O4**
(one cluster).

**Step M0 — read the stack namespace and selectors** (monitoring M0):

```bash
# READ-ONLY
source ~/nkp-mgmt-01.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get helmreleases -A | grep -E 'NAMESPACE|kube-prometheus-stack'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get prometheuses -A -o jsonpath='{range .items[*]}{.metadata.namespace}/{.metadata.name}{"\n"}  serviceMonitorSelector={.spec.serviceMonitorSelector}{"\n"}  serviceMonitorNamespaceSelector={.spec.serviceMonitorNamespaceSelector}{"\n"}  ruleSelector={.spec.ruleSelector}{"\n"}  ruleNamespaceSelector={.spec.ruleNamespaceSelector}{"\n"}  retention={.spec.retention}{"\n"}{end}'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get alertmanagers -A -o jsonpath='{range .items[*]}{.metadata.namespace}/{.metadata.name}{"\n"}  configSelector={.spec.alertmanagerConfigSelector}{"\n"}  configNamespaceSelector={.spec.alertmanagerConfigNamespaceSelector}{"\n"}  matcherStrategy={.spec.alertmanagerConfigMatcherStrategy}{"\n"}{end}'
```

**Step O2 — read the override that the app uses now**, so I do not throw away values that are
already there (the apply replaces the whole ConfigMap). The `awk` mask stays: it hides the value of
every key that ends in `secret`, `password`, `token`, `key`, `hash`, `pw`, or `credentials`.

First I confirm the app ID with you (`kube-prometheus-stack`), then append it to the cluster env
file — rule 4, so that append block is in my **next** reply, after your answer, not in this one.
Then:

```bash
# READ-ONLY
source ~/nkp-mgmt-01.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get appdeployment "$APP_ID" -o jsonpath='app={.spec.appRef.name}{"\n"}workspace-override={.spec.configOverrides.name}{"\n"}{range .spec.clusterConfigOverrides[*]}cluster-override={.configMapName} for {.clusterSelector}{"\n"}{end}'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get helmreleases -A -o custom-columns='NS:.metadata.namespace,NAME:.metadata.name,FROM:.spec.valuesFrom[*].name' | grep -E "NS|$APP_ID"
```

```bash
# READ-ONLY
source ~/nkp-mgmt-01.env 2>/dev/null
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

**Step O3.1 — the values file.** After your answers, the file holds only what changes, and it keeps
any values that O2 showed in the old override. The shape is M2 way A:

```yaml
additionalPrometheusRulesMap:
  node-disk-90:
    groups:
      - name: node_disk
        rules:
          - alert: NodeDiskAlmostFull
            expr: node_filesystem_avail_bytes / node_filesystem_size_bytes < 0.10
            for: 10m
            labels:
              severity: warning
            annotations:
              summary: node disk is 90% full
```

The expression, the names, the `for` and the severity above come from your answers — I show you the
full text and stop for `yes` before I write it. Then:

```bash
# CHANGES  (writes the values file on the operator host; changes no cluster)
source ~/nkp-mgmt-01.env 2>/dev/null
f="$HOME/$CLUSTER_NAME-$APP_ID-values.yaml"
(umask 077 && cat > "$f" <<'VALUES'
# the values that the user confirmed go here, in place of this line
VALUES
)
```

One warning that belongs to this reply: the management-cluster ConfigMap
`kommander/kube-prometheus-stack-mgmt-overrides` holds `prometheus.additionalServiceMonitors` — the
15 NKP ServiceMonitors. Arrays in values are replaced, not appended, so my file must **not** set
`prometheus.additionalServiceMonitors` at all. That is why the alert goes under
`additionalPrometheusRulesMap` and not there. (Whether that ConfigMap is a workspace override, a
cluster override, or slot 2 is UNKNOWN D-30; the O2 read above tells us.)

**Step O3.2 — the mandatory YAML check.** A good file answers `apiVersion not set, kind not set`; a
bad file answers `error converting YAML to JSON` with the line number:

```bash
# READ-ONLY
source ~/nkp-mgmt-01.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" create --dry-run=client -f "$HOME/$CLUSTER_NAME-$APP_ID-values.yaml" 2>&1 | head -3
```

**Step O3.3 — server dry run of the ConfigMap** (`$APP_ID-overrides-ws` for a new one; never
`$APP_ID-overrides`, that is slot 2):

```bash
# READ-ONLY  (server dry run: changes nothing)
source ~/nkp-mgmt-01.env 2>/dev/null
cm=''; : "${cm:?}"
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" create configmap "$cm" --from-file=values.yaml="$HOME/$CLUSTER_NAME-$APP_ID-values.yaml" --dry-run=client -o yaml | kubectl --kubeconfig "$MGMT_KUBECONFIG" apply --dry-run=server -f -
```

**Step O3.4 — the plan, then `yes`, then apply.** The plan I read to you: management cluster
`mgmt-01`, namespace `kommander`, ConfigMap `kube-prometheus-stack-overrides-ws`, app
`kube-prometheus-stack`, every cluster of workspace `kommander-workspace` gets the change, and the
Prometheus/Alertmanager/Grafana pods restart. After `yes`:

```bash
# CHANGES  (creates or replaces the override ConfigMap and sets it on the AppDeployment)
source ~/nkp-mgmt-01.env 2>/dev/null
cm=''; : "${cm:?}"
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" create configmap "$cm" --from-file=values.yaml="$HOME/$CLUSTER_NAME-$APP_ID-values.yaml" --dry-run=client -o yaml | kubectl --kubeconfig "$MGMT_KUBECONFIG" apply -f -
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" patch appdeployment "$APP_ID" --type merge -p "{\"spec\":{\"configOverrides\":{\"name\":\"$cm\"}}}"
```

**Next, and done when:** O6 passes (each cluster `AppDeploymentEnabled=True
AppDeploymentInstanceSynced=True`, HelmRelease READY `True` with a new release number), and the
Prometheus UI Alerts page lists `NodeDiskAlmostFull` — about one minute. A rule with a PromQL error
is not loaded; then I read the log of the `prometheus` container in the Pod.

---

## nkp-observability B2

**Skill files read:** `skills/nkp/SKILL.md`, `skills/_shared/RULES.md`,
`skills/nkp-observability/SKILL.md`, `skills/nkp-observability/references/monitoring.md` (M0, M4 and
the D-31 UNKNOWN), `skills/nkp-platform-apps-gitops/references/overrides.md` (only for the fallback
of a values-based receiver; not used here).

**The webhook.** I will not repeat it, and I will not put it into a command, a file, an `echo`, or a
ConfigMap. It is a secret (rule 5). Please put it into `~/nkp-site.env` yourself, in your own
terminal, as `ALERT_SLACK_WEBHOOK_URL`, and then change it at Slack, because it is now in this chat
transcript:

```bash
# USER-TERMINAL  (operator host; the user writes the webhook line with an editor)
umask 077
vi ~/nkp-site.env
```

The line to type there is `export ALERT_SLACK_WEBHOOK_URL='...'` with your URL. I check only that it
is set, never its value:

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
[ -n "$(printenv ALERT_SLACK_WEBHOOK_URL)" ] && echo "set: ALERT_SLACK_WEBHOOK_URL" || echo "MISSING: ALERT_SLACK_WEBHOOK_URL"
```

**"Just do it" is not `yes`.** Rule 2: I show you the command, the target, and the result, and I run
a CHANGES block only after you type `yes` to that plan. Nothing in this reply runs.

**I would ask these with the question tool:**

1. Which way — **A** (replace the Alertmanager config Secret) or **B** (`AlertmanagerConfig`
   object)? For "**all** alerts" you want **A**. Way B adds a route to the existing config and, with
   `matcherStrategy` empty or `OnNamespace`, the Prometheus Operator injects
   `namespace=<namespace of the object>` into the route, so only alerts that already carry that
   namespace label match. Way A has no such limit — it replaces the whole route tree.
2. Confirm the cluster env file is `~/nkp-app-01.env` (you named cluster `app-01`), and please tell
   me whether `WORKSPACE_NS` in it is the right workspace namespace for `app-01`.
3. Can this cluster reach `hooks.slack.com`? On an air-gapped site, Alertmanager cannot reach Slack
   and an internal receiver is needed.

**Step M0 first — the stack namespace and the selectors** (monitoring M0). Way B only works if the
`AlertmanagerConfig` matches `configSelector` **and** `configNamespaceSelector`; an empty selector
selects nothing. This also confirms the stack namespace, which is the Secret namespace in way A:

```bash
# READ-ONLY
source ~/nkp-app-01.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get helmreleases -A | grep -E 'NAMESPACE|kube-prometheus-stack'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get prometheuses -A -o jsonpath='{range .items[*]}{.metadata.namespace}/{.metadata.name}{"\n"}  serviceMonitorSelector={.spec.serviceMonitorSelector}{"\n"}  serviceMonitorNamespaceSelector={.spec.serviceMonitorNamespaceSelector}{"\n"}  ruleSelector={.spec.ruleSelector}{"\n"}  ruleNamespaceSelector={.spec.ruleNamespaceSelector}{"\n"}  retention={.spec.retention}{"\n"}{end}'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get alertmanagers -A -o jsonpath='{range .items[*]}{.metadata.namespace}/{.metadata.name}{"\n"}  configSelector={.spec.alertmanagerConfigSelector}{"\n"}  configNamespaceSelector={.spec.alertmanagerConfigNamespaceSelector}{"\n"}  matcherStrategy={.spec.alertmanagerConfigMatcherStrategy}{"\n"}{end}'
```

**Way A, step 1 — you write the Alertmanager config** (USER-TERMINAL; the file holds the webhook, so
it is yours to write, mode 077). The file must have a `route` with a default `receiver`, `receivers`
(for example `slack_configs`), and a route that sends `Watchdog` and `InfoInhibitor` to a `"null"`
receiver:

```bash
# USER-TERMINAL  (operator host; the user writes the Alertmanager config, it holds a secret)
umask 077
vi ~/alertmanager.yaml
```

**Way A, step 2 — plan, then `yes`.** Plan: target cluster `app-01`, namespace = the stack namespace
from M0 (`kommander` on a management cluster, usually the workspace namespace on a workload
cluster), the Secret `alertmanager-kube-prometheus-stack-alertmanager` is **replaced**, so **every**
notification route of this cluster changes, not only Slack. Then:

```bash
# CHANGES  (replaces the Alertmanager config Secret of the cluster)
source ~/nkp-app-01.env 2>/dev/null
ns=''; : "${ns:?}"
f=$(test -s "$HOME/alertmanager.yaml" && echo ok); : "${f:?no ~/alertmanager.yaml}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" create secret generic alertmanager-kube-prometheus-stack-alertmanager --from-file=alertmanager.yaml="$HOME/alertmanager.yaml" --dry-run=client --save-config -o yaml | kubectl --kubeconfig "$CLUSTER_KUBECONFIG" apply -f - -o name
```

(The Secret is made from your file on disk, so the webhook never appears in a command line.)

**Way A, step 3 — did Alertmanager load it?** This log line has no secret:

```bash
# READ-ONLY
source ~/nkp-app-01.env 2>/dev/null
ns=''; : "${ns:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" logs alertmanager-kube-prometheus-stack-alertmanager-0 -c alertmanager --since=10m | grep -iE 'config|error' | tail -5
```

A load error shows `error` with the line. The guide also reads
`/etc/alertmanager/config_out/alertmanager.env.yaml` inside the Pod — that file **contains the
secrets**, so that is USER-TERMINAL and you read it, not me.

**D-31 — check after every upgrade.** UNKNOWN (D-31): whether an upgrade of `kube-prometheus-stack`
writes the default Alertmanager Secret again, which would undo way A. Find out with:

```bash
# READ-ONLY
source ~/nkp-app-01.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get secrets -A --show-labels | grep alertmanager-kube-prometheus-stack-alertmanager
```

A Helm label `app.kubernetes.io/managed-by=Helm` means Helm owns the Secret, so the next chart
upgrade can reset it. Re-check the receivers after each upgrade.

**Next, and done when:** the `Watchdog` alert (or a test alert) reaches `#ops-alerts`. Then I would
also set a silence path: silences are done in the Alertmanager UI of the cluster
(`https://<address>/dkp/alertmanager`), not in Karma.

---

## nkp-observability B3

**Skill files read:** `skills/nkp/SKILL.md`, `skills/_shared/RULES.md`,
`skills/nkp-observability/SKILL.md`, `skills/nkp-observability/references/logging.md` (L1, L3, L4
facts), `skills/nkp-platform-apps-gitops/references/overrides.md` (O1, O2, O3, O6),
`skills/nkp-storage-backup/references/object-storage.md` (O2 — read only to point you there, I do
not give those steps).

Cluster `mgmt-01`, so cluster env file `~/nkp-mgmt-01.env`, `WORKSPACE_NS=kommander`. Default store
is a Rook Ceph bucket (HelmRelease `object-bucket-claims`); default retention is one week, and the
minimum is 24h — 720h (30 days) is allowed. [pdf p.560]

**I would ask these with the question tool:**

1. Confirm the new value is exactly 30 days = `720h`.
2. Confirm the app ID `grafana-loki-v3` (I ask before I use it in any block).
3. Is there anything else you want in the same Loki values file (storage, scale)? Loki takes **one**
   workspace override, so retention, store, and scale go into one file.
4. Do you accept that more retention needs more bucket space and more Ceph capacity first? If the
   bucket cap stays as it is, Loki stops taking logs when it fills.

**Step 1 — read the state** (observability `SKILL.md` step 1 / logging L1):

```bash
# READ-ONLY
source ~/nkp-mgmt-01.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n kommander get licenses.kommander.mesosphere.io -o jsonpath='{.items[*].status.dkpLevel}{"\n"}'
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get appdeployments | grep -E 'NAME|prometheus|grafana|loki|logging|fluent|thanos|karma|insights|rook-ceph'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get helmreleases -A | grep -E 'NAME|prometheus|grafana|loki|logging|fluent|thanos|karma|insights|rook-ceph|object-bucket'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get pods -A | grep -E 'prometheus|alertmanager|grafana|loki|fluent|thanos|karma|insights' | grep -v -E 'Running|Completed'
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get loggingstacks
```

**Step O2 — read the override that is there now.** This is mandatory before I write anything: the
apply in O3.4 **replaces** the whole ConfigMap, so any value that is there today must be carried
over. The `awk` mask stays in the block, so secret keys are hidden:

```bash
# READ-ONLY
source ~/nkp-mgmt-01.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get appdeployment "$APP_ID" -o jsonpath='app={.spec.appRef.name}{"\n"}workspace-override={.spec.configOverrides.name}{"\n"}{range .spec.clusterConfigOverrides[*]}cluster-override={.configMapName} for {.clusterSelector}{"\n"}{end}'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get helmreleases -A -o custom-columns='NS:.metadata.namespace,NAME:.metadata.name,FROM:.spec.valuesFrom[*].name' | grep -E "NS|$APP_ID"
```

```bash
# READ-ONLY
source ~/nkp-mgmt-01.env 2>/dev/null
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

If the app already has an override, `cm` is its name and I keep its values. If not, I create one and
`cm` is a **new** name — `grafana-loki-v3-overrides-ws`, per the O3 item 3 name rule. I do not use
`grafana-loki-v3-overrides`: that exact name is slot 2 of `valuesFrom`, it is read even when no
AppDeployment names it, and on the management cluster it lands in two slots at once.

**Step L3 — the values** (logging L3). Only this changes:

```yaml
loki:
  structuredConfig:
    limits_config:
      retention_period: 720h
```

**Step O3.1 — write the file.** I show you the full text first and stop for `yes`; then:

```bash
# CHANGES  (writes the values file on the operator host; changes no cluster)
source ~/nkp-mgmt-01.env 2>/dev/null
f="$HOME/$CLUSTER_NAME-$APP_ID-values.yaml"
(umask 077 && cat > "$f" <<'VALUES'
# the values that the user confirmed go here, in place of this line
VALUES
)
```

**Step O3.2 — the mandatory YAML check:**

```bash
# READ-ONLY
source ~/nkp-mgmt-01.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" create --dry-run=client -f "$HOME/$CLUSTER_NAME-$APP_ID-values.yaml" 2>&1 | head -3
```

**Step O3.3 — server dry run of the ConfigMap** (use the existing name from O2, or the new
`grafana-loki-v3-overrides-ws`):

```bash
# READ-ONLY  (server dry run: changes nothing)
source ~/nkp-mgmt-01.env 2>/dev/null
cm=''; : "${cm:?}"
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" create configmap "$cm" --from-file=values.yaml="$HOME/$CLUSTER_NAME-$APP_ID-values.yaml" --dry-run=client -o yaml | kubectl --kubeconfig "$MGMT_KUBECONFIG" apply --dry-run=server -f -
```

**Step O3.4 — plan, then `yes`, then apply.** Plan: management cluster `mgmt-01`, namespace
`kommander`, ConfigMap `<the name above>`, app `grafana-loki-v3`, all clusters of the workspace get
the change, the Loki pods restart:

```bash
# CHANGES  (creates or replaces the override ConfigMap and sets it on the AppDeployment)
source ~/nkp-mgmt-01.env 2>/dev/null
cm=''; : "${cm:?}"
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" create configmap "$cm" --from-file=values.yaml="$HOME/$CLUSTER_NAME-$APP_ID-values.yaml" --dry-run=client -o yaml | kubectl --kubeconfig "$MGMT_KUBECONFIG" apply -f -
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" patch appdeployment "$APP_ID" --type merge -p "{\"spec\":{\"configOverrides\":{\"name\":\"$cm\"}}}"
```

**Step O6 — check:**

```bash
# READ-ONLY
source ~/nkp-mgmt-01.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get appdeployment "$APP_ID" -o jsonpath='{range .status.clusters[*]}{.name}{"\t"}{range .conditions[*]}{.type}={.status} {end}{"\n"}{end}'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get helmreleases -A | grep -E "NAME|$APP_ID"
```

**The bucket.** 30 days of logs needs 30 days of bucket. Two caps matter, and neither is in this
skill: the Rook Ceph size, and the Loki bucket cap `dkp.grafana-loki.additionalConfig.maxSize` in the
same override. Those steps belong to skill **`nkp-storage-backup`**, file `object-storage.md`, **O2**
(grow Ceph with `storageClassDeviceSets`, and raise the bucket cap). I do not copy those steps into
this answer — you decide the Ceph size there, with the OSD count and node room it needs. Retention
alone, without the cap, only fills the bucket faster.

**Next:** after O6 passes, the `compactor` pod applies the new retention. Old logs are not deleted at
once; the compactor removes them as it runs. Done when O6 passes and the bucket usage stays under
its cap.

---

## nkp-observability B4

**Skill files read:** `skills/nkp/SKILL.md`, `skills/_shared/RULES.md`,
`skills/nkp-observability/SKILL.md`, `skills/nkp-observability/references/insights.md` (Facts, I3),
`skills/nkp-airgap/SKILL.md` (step 4, 4A and 4B "extra bundle"),
`skills/nkp-airgap/references/prestage.md` (P4),
`skills/nkp-platform-apps-gitops/references/overrides.md` (O2, O3, O4).

Cluster `app-02`, workspace name `prod`, workspace namespace `prod-abc12`, so cluster env file
`~/nkp-app-02.env` with `WORKSPACE_NS=prod-abc12`. Note that `nkp` takes the workspace **name**
(`prod`) and `kubectl` takes the **namespace** (`prod-abc12`) — the two are not the same string.

**Why the results look old.** On a connected site NKP Insights gets a fresh Trivy DB before each
scan. On an air-gapped site it uses the DB inside the bundle image, and that DB has the date of the
release build — so it only gets newer when you build and push a newer bundle. [pdf p.1119]
[live 2.19.0] Trivy is also **off by default**; you must have `trivy.enabled: true` for it to scan
at all.

**I would ask these with the question tool:**

1. How are images seeded on this site — a **site registry mirror** (Harbor/Nexus/Artifactory/ECR,
   airgap `SKILL.md` 4A) or the **internal registry mirror** inside the management cluster
   (`--bundle` mode, 4B)? That decides the push block.
2. Which workspace(s) must get the new tag — `prod` only, or every workspace that runs the engine?
   The image value is per workspace.
3. Do you have a connected host with Git, Docker, and `make`? P4 runs **there**, not on this host.

**Step I3.1 — read the image in use now** (READ-ONLY). The tag is `<trivy version>-<DB date>`; the
part before the first `-` is the Trivy version, and that part must stay the same in the new tag:

```bash
# READ-ONLY
source ~/nkp-app-02.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$WORKSPACE_NS" get cronjob nkp-insights-trivy -o jsonpath='{.spec.jobTemplate.spec.template.spec.initContainers[?(@.name=="trivy")].image}{"\n"}'
```

For reference, the 2.19.0 bundle ships `docker.io/mesosphere/trivy-bundles:0.64.1-20260929T031542Z`
[live 2.19.0]. The block above gives the real tag of **your** cluster; I use that value, not the
example.

**Step P4.2 — build the new bundle on the connected host** (USER-TERMINAL; it runs on the other
host, and it needs the internet, which this site does not have). Clone the `trivy-bundles-repo` URL
from `skills/nkp-airgap/assets/download-urls.txt`, then in that folder, with the Trivy version from
the check above in `TRIVY_VERSION`:

```bash
# USER-TERMINAL  (connected host; the user runs it in the trivy-bundles folder. Builds a Trivy bundle tar.gz)
export TRIVY_VERSION=0.64.1
make create-airgapped-image-bundle
sha256sum trivy-bundles-*.tar.gz
```

Move `trivy-bundles-<version>-<date>.tar.gz` (and its `.sha256`) into the air gap, and check it on
this host with `sha256sum -c`. **Never** try to pull the DB from the internet on the site.

**Step P4.3 — push it.** `nkp push bundle` needs the file path in `EXTRA_BUNDLE`, and rule 4 says the
append block to `~/nkp-site.env` comes **after** you give me that value and confirm it — so that one
line is in my next reply, not here. Then the push, for your site mode. Site registry mirror (4A):

```bash
# CHANGES  (pushes the images of one extra bundle file into the site registry)
source ~/nkp-site.env 2>/dev/null
nkp push bundle --bundle "$EXTRA_BUNDLE" --to-registry "$REGISTRY_URL" --to-registry-ca-cert-file "$REGISTRY_CA_FILE" --to-registry-username "$REGISTRY_PUSH_USERNAME" --to-registry-password "$REGISTRY_PUSH_PASSWORD"
```

Internal registry mirror (4B):

```bash
# CHANGES  (pushes the bundles into the internal registry mirror of the management cluster)
source ~/nkp-site.env 2>/dev/null
nkp push bundle --bundle "$EXTRA_BUNDLE" --to-internal-registry-mirror --kubeconfig "$MGMT_KUBECONFIG"
```

`UNAUTHORIZED: project not found, name: mesosphere` from Harbor is a known false positive; the image
is pushed. [pdf p.992] Each of these is CHANGES: plan, then `yes`, then I run it.

**Step I3.2 — the values.** I ask you for the new tag (it is in the file name), and only after your
answer do I write the values file. The shape is:

```yaml
trivy:
  enabled: true
  image:
    imageFull: docker.io/mesosphere/trivy-bundles:0.64.1-20261101T000000Z
```

Your tag replaces the example tag. The registry path stays `docker.io/mesosphere/trivy-bundles` —
the node registry mirror serves it, and I do not move it to another registry. The Trivy version
(before the `-`) must equal the one from the check above, or the job and the DB format disagree.

**Step I3.3 — apply with O3, for each workspace.** Read the old override first (O2, with the `awk`
mask), because the override replaces the old one:

```bash
# READ-ONLY
source ~/nkp-app-02.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get appdeployment "$APP_ID" -o jsonpath='app={.spec.appRef.name}{"\n"}workspace-override={.spec.configOverrides.name}{"\n"}{range .spec.clusterConfigOverrides[*]}cluster-override={.configMapName} for {.clusterSelector}{"\n"}{end}'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get helmreleases -A -o custom-columns='NS:.metadata.namespace,NAME:.metadata.name,FROM:.spec.valuesFrom[*].name' | grep -E "NS|$APP_ID"
```

```bash
# READ-ONLY
source ~/nkp-app-02.env 2>/dev/null
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

then the O3 chain: write the file (`APP_ID=nkp-insights`), the YAML check, the server dry run, the
plan, `yes`, the apply:

```bash
# CHANGES  (writes the values file on the operator host; changes no cluster)
source ~/nkp-app-02.env 2>/dev/null
f="$HOME/$CLUSTER_NAME-$APP_ID-values.yaml"
(umask 077 && cat > "$f" <<'VALUES'
# the values that the user confirmed go here, in place of this line
VALUES
)
```

```bash
# READ-ONLY
source ~/nkp-app-02.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" create --dry-run=client -f "$HOME/$CLUSTER_NAME-$APP_ID-values.yaml" 2>&1 | head -3
```

```bash
# READ-ONLY  (server dry run: changes nothing)
source ~/nkp-app-02.env 2>/dev/null
cm=''; : "${cm:?}"
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" create configmap "$cm" --from-file=values.yaml="$HOME/$CLUSTER_NAME-$APP_ID-values.yaml" --dry-run=client -o yaml | kubectl --kubeconfig "$MGMT_KUBECONFIG" apply --dry-run=server -f -
```

```bash
# CHANGES  (creates or replaces the override ConfigMap and sets it on the AppDeployment)
source ~/nkp-app-02.env 2>/dev/null
cm=''; : "${cm:?}"
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" create configmap "$cm" --from-file=values.yaml="$HOME/$CLUSTER_NAME-$APP_ID-values.yaml" --dry-run=client -o yaml | kubectl --kubeconfig "$MGMT_KUBECONFIG" apply -f -
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" patch appdeployment "$APP_ID" --type merge -p "{\"spec\":{\"configOverrides\":{\"name\":\"$cm\"}}}"
```

For **one cluster only** instead of the whole workspace, use O4 (`clusterConfigOverrides` with a
`kommander.d2iq.io/cluster-name` selector, Ultimate only) with the same values file.

**Next, and done when:** the I3.1 block shows the **new** date on the CronJob. An `ImagePullBackOff`
on the Trivy job means the tag never reached the registry that the nodes pull from — that is
`nkp-airgap` step 5 (node registry files), not an Insights problem.

---

## nkp-observability B5

**Skill files read:** `skills/nkp/SKILL.md`, `skills/_shared/RULES.md`,
`skills/nkp-observability/SKILL.md`, `skills/nkp-observability/references/logging.md` (L1, L8 and
D-06), `skills/nkp-platform-apps-gitops/references/overrides.md` (O1/O2 — read only to explain why I
do **not** use a values override here).

Cluster `app-03`, Pro tier, cluster env file `~/nkp-app-03.env`. "Keep Loki" is the deciding fact:
way A adds a second output and leaves the NKP `loki` output and the `cluster-containers` flow in
place. Way B (the `clusterOutputs`/`clusterFlows` lists in the Logging Operator values) **replaces**
the NKP lists — a field run lost Loki that way — so way B is not an option for you.

**I would ask these with the question tool:**

1. Splunk side: `https` or `http` on port 8088, must the TLS certificate be verified, and which
   `index` (`main` or another)?
2. Which logs? The `ClusterOutput` + `ClusterFlow` I write is cluster-wide (all pod logs, like the
   NKP flow). Do you want all namespaces, or an exclude list?
3. Confirm the token goes into `~/nkp-site.env` as `LOG_SPLUNK_HEC_TOKEN` — I will not accept it in
   the chat.

**Step L1/L8.1 — read the control namespace and the NKP `loki` output** (READ-ONLY). A
`ClusterOutput` is read **only** in the control namespace, and its Secret must be in that same
namespace:

```bash
# READ-ONLY
source ~/nkp-app-03.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" explain clusteroutputs | sed -n 's/^GROUP: *//p'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get loggings -o jsonpath='{range .items[*]}{.spec.controlNamespace}{"\n"}{end}'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get clusteroutputs -A -o jsonpath='{range .items[*]}{.metadata.namespace}/{.metadata.name}: {.spec.loki.url}{"\n"}{end}'
```

and the health line, so we know the stack is not already broken before we add to it:

```bash
# READ-ONLY
source ~/nkp-app-03.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get helmreleases -A | grep -E 'NAME|logging|loki|fluent|rook-ceph|object-bucket'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get clusterflows,clusteroutputs -A
```

**Step 1 — the token (you do it).** Put it into `~/nkp-site.env` with an editor; I only check that it
is set:

```bash
# USER-TERMINAL  (operator host; the user adds the Splunk HEC token with an editor)
umask 077
vi ~/nkp-site.env
```

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
[ -n "$(printenv LOG_SPLUNK_HEC_TOKEN)" ] && echo "set: LOG_SPLUNK_HEC_TOKEN" || echo "MISSING: LOG_SPLUNK_HEC_TOKEN"
```

**Step L8.2 — write the `ClusterOutput` and `ClusterFlow` file** (CHANGES, operator host only; it
changes no cluster). `ns` is the control namespace from L1, `name` is the output name you confirm,
and `out` is the Splunk spec as one line of YAML:

```bash
# CHANGES  (writes the ClusterOutput and ClusterFlow file on the operator host; changes no cluster)
source ~/nkp-app-03.env 2>/dev/null
ns=''; name=''; out=''; : "${ns:?}" "${name:?}" "${out:?}"
grp=$(kubectl --kubeconfig "$CLUSTER_KUBECONFIG" explain clusteroutputs | sed -n 's/^GROUP: *//p'); : "${grp:?}"
cat > "$HOME/$CLUSTER_NAME-logout-$name.yaml" <<EOF
apiVersion: $grp/v1beta1
kind: ClusterOutput
metadata:
  name: $name
  namespace: $ns
spec: $out
---
apiVersion: $grp/v1beta1
kind: ClusterFlow
metadata:
  name: $name-all
  namespace: $ns
spec:
  globalOutputRefs:
    - $name
EOF
```

The `out` line for Splunk HEC, with your host and port and the Secret name `log-splunk` [field]:

```text
{"splunkHec":{"hec_host":"splunk.corp.local","hec_port":8088,"protocol":"https","insecure_ssl":false,"index":"main","hec_token":{"valueFrom":{"secretKeyRef":{"name":"log-splunk","key":"hec_token"}}}}}
```

`protocol`, `insecure_ssl` and `index` are the three answers I asked for above — I do not pick them
for you. The `ClusterFlow` has no `match` section, so Fluentd sends **all** pod logs to it, exactly
like the NKP flow does, and both flows run side by side. The NKP `loki` `ClusterOutput` and the
`cluster-containers` `ClusterFlow` are untouched.

**Step L8.3 — the token Secret in the control namespace** (plan, then `yes`). The token never appears
in the command line: it comes from the env file through the process substitution:

```bash
# CHANGES  (creates the Splunk HEC token Secret in the control namespace)
source ~/nkp-app-03.env 2>/dev/null
ns=''; : "${ns:?}"
k=$(printenv LOG_SPLUNK_HEC_TOKEN >/dev/null && echo ok); : "${k:?LOG_SPLUNK_HEC_TOKEN is not set}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" create secret generic log-splunk --from-file=hec_token=<(printf %s "$(printenv LOG_SPLUNK_HEC_TOKEN)") --dry-run=client -o yaml | kubectl --kubeconfig "$CLUSTER_KUBECONFIG" apply -f - -o name
```

**Step L8.4 — server dry run, then plan, `yes`, apply:**

```bash
# READ-ONLY  (server dry run: changes nothing)
source ~/nkp-app-03.env 2>/dev/null
name=''; : "${name:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" apply --dry-run=server -f "$HOME/$CLUSTER_NAME-logout-$name.yaml"
```

Plan: cluster `app-03`, namespace = the control namespace, one new `ClusterOutput` and one new
`ClusterFlow`; Fluentd then sends all pod logs to Splunk **and** still to Loki. Then:

```bash
# CHANGES  (creates the ClusterOutput and ClusterFlow; Fluentd sends all pod logs to the new target too)
source ~/nkp-app-03.env 2>/dev/null
name=''; : "${name:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" apply -f "$HOME/$CLUSTER_NAME-logout-$name.yaml"
```

**Step L8.5 — check:** `kubectl get clusteroutputs,clusterflows -A` must show ACTIVE `true` and no
PROBLEMS. A field run needed a Fluentd pod restart before logs went out; that is CHANGES, so I ask
you first.

**Honesty about the source.** This recipe is `[field]`, not from the guide — the guide has no
forwarding recipe. UNKNOWN (D-06): whether it works unchanged on 2.19 (the Fluentd 6.7.0 image and
its plugins, the TLS options). Find out with:

```bash
# READ-ONLY
source ~/nkp-app-03.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get clusteroutputs -A
```

plus new lines at the Splunk index, while Grafana Explore (Loki) still gets logs — both, not one.

---

## nkp-observability B6

**Skill files read:** `skills/nkp/SKILL.md`, `skills/_shared/RULES.md`,
`skills/nkp-observability/SKILL.md` (step 1, "Common failures"),
`skills/nkp-observability/references/logging.md` (L1, L9),
`skills/nkp-platform-apps-gitops/references/overrides.md` (O2, O3, O4).

You did not name the cluster in this message, so I keep `~/nkp-<cluster>.env` in the blocks and ask
you for the name before I run anything (rule 3). I do not take a cluster name from an example or
from the earlier conversations.

**Short answer: no, `GrafanaLokiV3Deployed=False` does not mean logging is broken.** On a healthy
2.19.0 cluster the LoggingStack conditions read like this [live 2.19.0]:

```text
LoggingStackVersionReconciled=True ReconciliationSucceeded
GrafanaLokiV3Deployed=False GrafanaLokiV2NotDeployed      (normal: no Loki v2 was there)
LoggingStackAppDeploymentsUpdated=True Succeeded
GrafanaLokiV2Removed=False GrafanaLokiV2NotDeployed        (normal)
```

`False` with reason `GrafanaLokiV2NotDeployed` means "there was no Loki v2 to move", which is
correct. `False` with reason **`Failed`** is the real problem, and that goes to L9. So the first
thing I do is read the **reason**, not the status.

**I would ask these with the question tool:**

1. Which cluster is it — which `~/nkp-<cluster>.env` do I use?
2. Is the whole logging stack otherwise quiet (pod logs arriving in Grafana Explore), or did only
   this condition change?

**Step L1 — the reasons** (READ-ONLY). `WORKSPACE_NS` is `kommander` for the management cluster,
the namespace of its KommanderCluster for a workload cluster:

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get helmreleases -A | grep -E 'NAME|logging|loki|fluent|rook-ceph|object-bucket'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get loggings -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}controlNamespace={.spec.controlNamespace}{"\n"}{end}'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get clusterflows,clusteroutputs -A
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get pods -A | grep -E 'NAME|fluentbit|fluentd|loki|logging-operator'
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get loggingstacks -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{range .status.conditions[*]}  {.type}={.status} {.reason}: {.message}{"\n"}{end}{end}'
```

**Branch A — reason `GrafanaLokiV2NotDeployed`.** Nothing is broken. I tell you so and stop; there is
no CHANGES block. The other conditions must still be checked: the logging HelmReleases
`logging-operator`, `logging-operator-logging`, `grafana-loki-v3`, `grafana-logging`, `rook-ceph`,
`rook-ceph-cluster`, `object-bucket-claims` must be `True`, and the pods must be `Running`.

**Branch B — reason `Failed`.** Then it is L9, and the message names the scopes that failed, for
example `Failed to convert Loki v2 overrides configurations to v3 format for: workspace '...',
project '...', cluster '...' in workspace '...'`. Each name is one override that could not be
converted: a workspace override, a project override, or a cluster override of the Loki
AppDeployment. [pdf p.552-553]

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get events --field-selector reason=GrafanaLokiV3Deployed
```

Then, for **each failed scope**, I write new Loki **v3 chart** values (Helm values of the chart, not
the Loki server config file) and apply them by scope: a workspace scope with gitops `overrides.md`
**O3**, a cluster scope with **O4**, a project scope with logging **L10 item 3**. Before that I read
the old override with O2 and its `awk` mask, because the override replaces the old one. Order
matters: **the overrides are fixed first, and only then** do I ask the controller to try again.

**Step L9.3 — the retry annotate.** CHANGES: plan, then `yes`. `ls` is the LoggingStack name from
L1 (it also takes the cluster env file, because `WORKSPACE_NS` is a cluster-file variable):

```bash
# CHANGES  (asks the LoggingStack controller to reconcile again)
source ~/nkp-<cluster>.env 2>/dev/null
ls=''; : "${ls:?}"
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" annotate loggingstack "$ls" reconcile.loggingstack.nkp.nutanix.com/requestedAt="$(date -u +%Y-%m-%dT%H:%M:%SZ)" --overwrite
```

The annotate passes a server dry run [live 2.19.0]. What I do **not** do: delete the LoggingStack,
delete the Loki AppDeployment, or annotate before the overrides are fixed. Done when the condition
is `GrafanaLokiV3Deployed=True`, reason `Succeeded`, message `Loki v3 deployment completed`
[pdf p.554].

---

## nkp-observability B7

**Skill files read:** `skills/nkp/SKILL.md`, `skills/_shared/RULES.md`,
`skills/nkp-observability/SKILL.md`, `skills/nkp-observability/references/monitoring.md` (M0, M6).

**Both numbers are not in the skills.** I will not give you a number from memory: rule 6 says say "not
in the skills" and give a READ-ONLY check. So: the **default scrape interval** of Prometheus in NKP
2.19 is not in the skills, and the **default retention** of Prometheus in NKP 2.19 is not in the
skills. I have no command output for either, and a remembered "30s" or "10d" would be a guess, not an
NKP fact.

Two related facts *are* in the skills, and they are the reason both values are read from the cluster
instead:

- Retention has no value in the guide. The values key is `prometheus.prometheusSpec.retention`
  (upstream chart) — the key is known, the **value** is not. [field]
- One app can have three different versions, so chart defaults are not NKP defaults; that is why the
  check below reads the ConfigMap the app actually uses.

**I would ask these with the question tool:**

1. Which cluster? (You did not name one, so I keep `~/nkp-<cluster>.env` and ask.) The values are per
   cluster — the management cluster and a workload cluster can differ.
2. Do you want the shipped default, or the value that is **in use now**? The first is in the defaults
   ConfigMap, the second is on the Prometheus object.

**Check 1 — the value in use now** (monitoring M0 prints `retention=` on the Prometheus object):

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get helmreleases -A | grep -E 'NAMESPACE|kube-prometheus-stack'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get prometheuses -A -o jsonpath='{range .items[*]}{.metadata.namespace}/{.metadata.name}{"\n"}  serviceMonitorSelector={.spec.serviceMonitorSelector}{"\n"}  serviceMonitorNamespaceSelector={.spec.serviceMonitorNamespaceSelector}{"\n"}  ruleSelector={.spec.ruleSelector}{"\n"}  ruleNamespaceSelector={.spec.ruleNamespaceSelector}{"\n"}  retention={.spec.retention}{"\n"}{end}'
```

An empty `retention=` means the chart default applies, and then check 2 gives the number.

**Check 2 — the shipped defaults** (monitoring M6 item 1: the defaults ConfigMap in the stack
namespace from M0; `ns` is that namespace):

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
ns=''; : "${ns:?}"
cm=$(kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" get cm -o name | grep 'kube-prometheus-stack-.*-config-defaults'); : "${cm:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" get "$cm" -o jsonpath='{.data.values\.yaml}' | grep -n -E '^ *(retention|retentionSize|storage|cpu|memory):'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" get pvc | grep -E 'NAME|prometheus'
```

**Check 3 — the scrape interval.** M6 item 1 reads the same ConfigMap with another pattern. The
pattern stays anchored and ends in `:`, so a Base64 Secret line can never match it:

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
ns=''; : "${ns:?}"
cm=$(kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" get cm -o name | grep 'kube-prometheus-stack-.*-config-defaults'); : "${cm:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" -n "$ns" get "$cm" -o jsonpath='{.data.values\.yaml}' | grep -n -E '^ *(scrapeInterval|evaluationInterval|scrapeTimeout):'
```

No line in either output means the value is not set in NKP values either, and the upstream chart
default applies — which is upstream Prometheus-Operator documentation, not an NKP fact, and I have no
internet here to read it.

**Next:** paste the output of check 1 and check 3 and I read the numbers from your cluster. If you
want a different retention, M6 gives the way (the value goes into the `kube-prometheus-stack`
override, not onto the object), and the storage table there sizes the PVC.

---

## nkp-observability B8

**Skill files read:** `skills/nkp/SKILL.md`, `skills/_shared/RULES.md`,
`skills/nkp-observability/SKILL.md` (step 1, step 3 and the `clusterapps ... not found` row),
`skills/nkp-observability/references/logging.md` (Facts, L3, L4),
`skills/nkp-platform-apps-gitops/SKILL.md` (step 1, step 2),
`skills/nkp-platform-apps-gitops/references/catalogs.md` (clusterapps annotations),
`skills/nkp-storage-backup/SKILL.md` (step 3, the default StorageClass).

**I will not run the command as you wrote it.** `nkp create appdeployment logging-operator --app
logging-operator-6.4.0` uses a guide version, and on 2.19.0 the ClusterApp is
`logging-operator-6.7.0` [live 2.19.0]. With the guide name the CLI answers
`clusterapps.apps.kommander.d2iq.io "logging-operator-6.4.0" not found`. The app name must come from
your cluster, not from the guide.

Also: you gave the workspace namespace `kommander-dev-x1y2z` (workspace name `dev`) but **no
cluster**, and logging is enabled **per workspace, per cluster** — the apps land on the clusters of
that workspace. So I ask before I run anything.

**I would ask these with the question tool:**

1. Which cluster is the target — which `~/nkp-<cluster>.env` do I use? (`WORKSPACE_NS` must be
   `kommander-dev-x1y2z`, and the derived workspace name must be `dev`.)
2. Is the license **Pro** or **Ultimate**? Starter has none of these apps; the API would still accept
   the AppDeployment and nothing would work.
3. Do the target clusters already have Traefik and cert-manager `True`, and one default
   StorageClass? Rook Ceph needs a default class that can give `volumeMode: Block`.

**Step 1 — read the state and the tier** (READ-ONLY; needs the cluster env file, hence the question
above):

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n kommander get licenses.kommander.mesosphere.io -o jsonpath='{.items[*].status.dkpLevel}{"\n"}'
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get appdeployments | grep -E 'NAME|prometheus|grafana|loki|logging|fluent|thanos|karma|insights|rook-ceph'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get helmreleases -A | grep -E 'NAME|prometheus|grafana|loki|logging|fluent|thanos|karma|insights|rook-ceph|object-bucket'
kubectl --kubeconfig "$MGMT_KUBECONFIG" -n "$WORKSPACE_NS" get loggingstacks
```

**Step 3 — read the exact ClusterApp names** (READ-ONLY, site values only). These names are what I
put into the create command, and nothing else:

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" get clusterapps | grep -E 'NAME|prometheus|grafana|loki|logging|fluent|thanos|karma|insights|rook-ceph|cloudnative-pg'
```

I also read the license and the dependency ("NEEDS") annotations, because a needed app that fails
makes the app fail too:

```bash
# READ-ONLY
source ~/nkp-site.env 2>/dev/null
kubectl --kubeconfig "$MGMT_KUBECONFIG" get clusterapps -o custom-columns='NAME:.metadata.name,LICENSE:.metadata.annotations.apps\.kommander\.d2iq\.io/licensing,SCOPE:.metadata.annotations.apps\.kommander\.d2iq\.io/scope,NEEDS:.metadata.annotations.apps\.kommander\.d2iq\.io/dependencies'
```

I do not put a ClusterApp name into a command before you confirm that list (rule 4 style).

**Preconditions on the target cluster** (READ-ONLY). Traefik and cert-manager, or the logging
Grafana does not load [pdf p.563], and exactly one default StorageClass [pdf p.557]:

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get helmreleases -A | grep -E 'NAME|traefik|cert-manager'
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get storageclass -o custom-columns='NAME:.metadata.name,DEFAULT:.metadata.annotations.storageclass\.kubernetes\.io/is-default-class,PROVISIONER:.provisioner,BINDING:.volumeBindingMode,EXPAND:.allowVolumeExpansion'
```

**The order** (observability step 3, workspace logging row). Five AppDeployments, in this order, each
one with its own dry run, plan, `yes`, create:

`rook-ceph` → `rook-ceph-cluster` → `logging-operator` → `grafana-loki-v3` → `grafana-logging`
[pdf p.558-559]

Why Rook Ceph is in the list and is not optional: Loki's default store is a Rook Ceph bucket
(HelmRelease `object-bucket-claims`). Without `rook-ceph` + `rook-ceph-cluster` there is no bucket for
Loki to write to. If you plan an external store (S3 or Nutanix Objects) instead, that changes the
order in `logging.md` L4 — and UNKNOWN D-33 says **do not** drop Rook Ceph for Loki without a lab
test.

For each app, through gitops `SKILL.md` step 2. The dry run is marked CHANGES because the same
command without `--dry-run` creates the app — so it also needs `yes`:

```bash
# CHANGES  (client dry run only: prints the AppDeployment; creates nothing)
source ~/nkp-<cluster>.env 2>/dev/null
name=''; app=''; ws=$(kubectl --kubeconfig "$MGMT_KUBECONFIG" get workspaces -o jsonpath="{.items[?(@.status.namespaceRef.name==\"$WORKSPACE_NS\")].metadata.name}")
: "${name:?}" "${app:?}" "${ws:?}"
nkp create appdeployment "$name" --app "$app" --workspace "$ws" --kubeconfig "$MGMT_KUBECONFIG" --dry-run
```

`name` is the app ID (`rook-ceph`, `rook-ceph-cluster`, `logging-operator`, `grafana-loki-v3`,
`grafana-logging`); `app` is the ClusterApp name from the step 3 read, for that app and that catalog
version. `ws` is derived from `WORKSPACE_NS=kommander-dev-x1y2z`, so it is `dev` — I never pass the
namespace where a workspace name is expected. The plan I read to you each time: the app, workspace
`dev`, and every cluster of it.

Then the create without `--dry-run`, CHANGES, after `yes`:

```bash
# CHANGES  (creates the AppDeployment; NKP installs the app on the target clusters)
source ~/nkp-<cluster>.env 2>/dev/null
name=''; app=''; ws=$(kubectl --kubeconfig "$MGMT_KUBECONFIG" get workspaces -o jsonpath="{.items[?(@.status.namespaceRef.name==\"$WORKSPACE_NS\")].metadata.name}")
: "${name:?}" "${app:?}" "${ws:?}"
nkp create appdeployment "$name" --app "$app" --workspace "$ws" --kubeconfig "$MGMT_KUBECONFIG"
```

**Check after each app** (READ-ONLY):

```bash
# READ-ONLY
source ~/nkp-<cluster>.env 2>/dev/null
name=''; : "${name:?}"
kubectl --kubeconfig "$CLUSTER_KUBECONFIG" get helmreleases -A | grep -E "NAME|$name"
```

**Done when** step 1 shows the logging HelmReleases `True` on every target cluster —
`rook-ceph`, `rook-ceph-cluster`, `logging-operator`, `logging-operator-logging`, `grafana-loki-v3`,
`grafana-logging`, `object-bucket-claims` — and the LoggingStack shows no reason `Failed`. Then I
give you the logging Grafana URL for `/explore` with the Loki data source (observability step 2).

**Not Ready after 15 minutes:** skill `nkp-troubleshooting` (`flux.md`), then `overrides.md` O5. The
usual first failure here is Rook Ceph with OSD PVCs `Pending` — the default StorageClass cannot give
`volumeMode: Block`, or fewer than 4 nodes have room (storage skill, O2/O3).

---

Skipped in this run: I executed no `kubectl` and no `nkp` command, so every branch above is written
from the skills and not from live output; the real tier, ClusterApp versions, control namespace, and
existing overrides must come from the blocks shown. Risk to know: the Splunk `ClusterOutput` recipe
(B5) is `[field]` with UNKNOWN D-06 open, and D-31 means the Alertmanager Secret (B2) can be reset by
an app upgrade.
